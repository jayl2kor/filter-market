/**
 * Filter lifecycle endpoints. See API_SPEC.md §5 for full contract.
 *
 * Endpoints:
 *   POST  /uploadInit               §5.1  upload init
 *   POST  /uploadFinalize           §5.2  upload finalize
 *   POST  /submitForReview          §5.3  submit for review
 *   POST  /use                      §5.7  idempotent use counter
 *   POST  /download                 §5.9  idempotent download counter
 *   GET   /getFilterDetail/:id      §5.8  detail with signed CDN URL
 *   POST  /report                   §5.6  user report
 */
import { onCall, HttpsError } from "firebase-functions/v2/https";
import type { CallableRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { getFirestore, FieldValue, type Firestore } from "firebase-admin/firestore";
import { randomUUID } from "node:crypto";
import { z } from "zod";
import { requireAuth } from "../lib/auth.js";
import { loadR2Config, presignPut, presignGet, headWithChecksum } from "../lib/r2.js";
import { isValidPriceTier } from "../lib/pricing.js";

// region: kept consistent across all functions for low cross-region latency.
const region = "asia-northeast3";

// R2 secrets — declared once and attached to functions that touch R2 so
// `process.env.R2_*` is populated at runtime. Bind via the `secrets:` option
// on each callable that needs them.
const R2_ENDPOINT = defineSecret("R2_ENDPOINT");
const R2_ACCESS_KEY_ID = defineSecret("R2_ACCESS_KEY_ID");
const R2_SECRET_ACCESS_KEY = defineSecret("R2_SECRET_ACCESS_KEY");
const R2_BUCKET = defineSecret("R2_BUCKET");
const R2_PUBLIC_BASE_URL = defineSecret("R2_PUBLIC_BASE_URL");

const r2Secrets = [R2_ENDPOINT, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_BUCKET];
const r2PublicSecrets = [...r2Secrets, R2_PUBLIC_BASE_URL];

/** Cooldown for /filters/{id}/use to count once per (uid, filter) per window. */
export const RECORD_USE_COOLDOWN_MS = 60 * 60 * 1000; // 1 hour

const recordUseSchema = z.object({
  filterId: z.string().min(1).max(128),
});

const recordDownloadSchema = z.object({
  filterId: z.string().min(1).max(128),
});

export interface RecordUseDeps {
  firestore?: Firestore;
  now?: () => Date;
}

export interface RecordUseResult {
  filterId: string;
  useCount: number;
  counted: boolean;
}

export interface RecordDownloadDeps {
  firestore?: Firestore;
  now?: () => Date;
}

export interface RecordDownloadResult {
  filterId: string;
  downloadCount: number;
  counted: boolean;
}

/**
 * Idempotent counter increment for a (uid, filter) pair.
 * Pure logic — exported so unit tests can drive it with a mock Firestore.
 */
export async function applyRecordUse(
  uid: string,
  rawData: unknown,
  deps: RecordUseDeps = {},
): Promise<RecordUseResult> {
  const parsed = recordUseSchema.safeParse(rawData);
  if (!parsed.success) {
    throw new HttpsError("invalid-argument", parsed.error.message);
  }
  const { filterId } = parsed.data;

  const db = deps.firestore ?? getFirestore();
  const now = (deps.now ?? (() => new Date()))();
  const filterRef = db.collection("filters").doc(filterId);
  const useRef = filterRef.collection("uses").doc(uid);

  return db.runTransaction(async (tx) => {
    const filterSnap = await tx.get(filterRef);
    if (!filterSnap.exists) {
      throw new HttpsError("not-found", `filter ${filterId} not found`);
    }

    const useSnap = await tx.get(useRef);
    const lastUseAtMs = readMillis(useSnap.get("lastUseAt"));
    const previousCount = (filterSnap.get("useCount") as number | undefined) ?? 0;

    if (lastUseAtMs !== null && now.getTime() - lastUseAtMs < RECORD_USE_COOLDOWN_MS) {
      return { filterId, useCount: previousCount, counted: false };
    }

    // Counter and cooldown row are written in the same transaction — atomic with the
    // initial reads above, so two concurrent calls cannot both pass the cooldown gate.
    tx.update(filterRef, { useCount: previousCount + 1 });
    tx.set(useRef, { lastUseAt: now }, { merge: true });

    return { filterId, useCount: previousCount + 1, counted: true };
  });
}

/**
 * Idempotent download counter for a (uid, filter) pair.
 *
 * Download count is a marketplace metric and must not fall back to useCount.
 * The per-user ledger prevents repeated saves or retries from inflating the
 * public "downloads" label.
 */
export async function applyRecordDownload(
  uid: string,
  rawData: unknown,
  deps: RecordDownloadDeps = {},
): Promise<RecordDownloadResult> {
  const parsed = recordDownloadSchema.safeParse(rawData);
  if (!parsed.success) {
    throw new HttpsError("invalid-argument", parsed.error.message);
  }
  const { filterId } = parsed.data;

  const db = deps.firestore ?? getFirestore();
  const now = (deps.now ?? (() => new Date()))();
  const filterRef = db.collection("filters").doc(filterId);
  const downloadRef = filterRef.collection("downloads").doc(uid);

  return db.runTransaction(async (tx) => {
    const filterSnap = await tx.get(filterRef);
    if (!filterSnap.exists) {
      throw new HttpsError("not-found", `filter ${filterId} not found`);
    }

    const downloadSnap = await tx.get(downloadRef);
    const previousCount = (filterSnap.get("downloadCount") as number | undefined) ?? 0;
    if (downloadSnap.exists) {
      return { filterId, downloadCount: previousCount, counted: false };
    }

    tx.update(filterRef, { downloadCount: previousCount + 1 });
    tx.set(downloadRef, { downloadedAt: now }, { merge: true });

    return { filterId, downloadCount: previousCount + 1, counted: true };
  });
}

function readMillis(value: unknown): number | null {
  if (value instanceof Date) return value.getTime();
  if (typeof value === "number") return value;
  if (
    value !== null &&
    typeof value === "object" &&
    "toMillis" in value &&
    typeof (value as { toMillis: unknown }).toMillis === "function"
  ) {
    return (value as { toMillis: () => number }).toMillis();
  }
  return null;
}

const uploadInitSchema = z.object({
  name: z.string().min(1).max(60),
  category: z.string().min(1).max(40),
  tags: z.array(z.string().max(24)).max(12).optional(),
  packageBytes: z.number().int().min(1).max(5_000_000), // 5 MB cap
  contentSha256: z.string().regex(/^[A-Za-z0-9+/=]+$/).optional(), // base64
  signatureSampleURL: z.string().url().optional(),
});

/**
 * POST /filters — see API_SPEC.md §5.1.
 *
 * Reserves a filter ID, creates the Firestore `/filters/{id}` draft, and returns
 * a presigned PUT URL the client uploads the `.fmpkg` to directly.
 */
export const uploadInit = onCall(
  { region, cors: true, secrets: r2Secrets, enforceAppCheck: true },
  async (req: CallableRequest) => {
    const uid = requireAuth(req);

    const parsed = uploadInitSchema.safeParse(req.data);
    if (!parsed.success) {
      throw new HttpsError("invalid-argument", parsed.error.message);
    }
    const { name, category, tags, packageBytes, contentSha256, signatureSampleURL } = parsed.data;

    let cfg;
    try {
      cfg = loadR2Config();
    } catch (error) {
      throw new HttpsError("internal", (error as Error).message);
    }

    const db = getFirestore();
    const filterRef = db.collection("filters").doc();
    const filterId = filterRef.id;
    const objectKey = `filters/${uid}/${filterId}.fmpkg`;

    await filterRef.set({
      authorUid: uid,
      title: name,
      category,
      tags: tags ?? [],
      status: "uploading",
      version: "0.0.1",
      packageBytes,
      objectKey,
      signatureSampleURL: signatureSampleURL ?? null,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    const presigned = await presignPut(cfg, objectKey, {
      expiresSeconds: 600,
      contentType: "application/x-moodit-package",
      contentSha256,
    });

    return {
      id: filterId,
      uploadUrl: presigned.url,
      uploadHeaders: presigned.headers,
      expiresAt: presigned.expiresAt,
      objectKey,
    };
  },
);

const uploadFinalizeSchema = z.object({
  filterId: z.string().min(1).max(128),
});

/**
 * POST /filters/{id}/finalize — see API_SPEC.md §5.2.
 *
 * Verifies the uploaded object exists in R2 and that its size matches what was
 * declared at uploadInit. Transitions the filter status: `uploading` →
 * `pending_review_pre`.
 */
export const uploadFinalize = onCall(
  { region, cors: true, secrets: r2Secrets, enforceAppCheck: true },
  async (req: CallableRequest) => {
    const uid = requireAuth(req);

    const parsed = uploadFinalizeSchema.safeParse(req.data);
    if (!parsed.success) {
      throw new HttpsError("invalid-argument", parsed.error.message);
    }
    const { filterId } = parsed.data;

    let cfg;
    try {
      cfg = loadR2Config();
    } catch (error) {
      throw new HttpsError("internal", (error as Error).message);
    }

    const db = getFirestore();
    const filterRef = db.collection("filters").doc(filterId);
    const snap = await filterRef.get();
    if (!snap.exists) {
      throw new HttpsError("not-found", `filter ${filterId} not found`);
    }
    const data = snap.data();
    if (data?.authorUid !== uid) {
      throw new HttpsError("permission-denied", "not the filter owner");
    }
    if (data?.status !== "uploading") {
      throw new HttpsError("failed-precondition", `filter status is ${data?.status}, expected "uploading"`);
    }
    const objectKey = data?.objectKey as string | undefined;
    if (!objectKey) {
      throw new HttpsError("internal", "filter has no objectKey");
    }

    const head = await headWithChecksum(cfg, objectKey);
    if (head.contentLength == null) {
      throw new HttpsError("not-found", "uploaded object missing on R2");
    }
    const declared = data?.packageBytes as number | undefined;
    if (declared && head.contentLength !== declared) {
      throw new HttpsError(
        "data-loss",
        `size mismatch: declared=${declared} actual=${head.contentLength}`,
      );
    }

    await filterRef.update({
      status: "pending_review_pre",
      uploadedAt: FieldValue.serverTimestamp(),
      sha256: head.sha256 ?? null,
      updatedAt: FieldValue.serverTimestamp(),
    });

    return { ok: true, filterId, sha256: head.sha256 };
  },
);

const reviewImageUploadInitSchema = z.object({
  filterId: z.string().min(1).max(128),
  contentType: z.enum(["image/jpeg", "image/png"]),
  imageBytes: z.number().int().min(1).max(2_500_000),
});

const submitReviewSchema = z.object({
  filterId: z.string().min(1).max(128),
  stars: z.number().int().min(1).max(5),
  body: z.string().trim().min(5).max(500),
  photoUrl: z.string().url().optional(),
  photoObjectKey: z.string().min(1).max(512).optional(),
});

const sampleImageUploadInitSchema = z.object({
  filterId: z.string().min(1).max(128),
  contentType: z.enum(["image/jpeg", "image/png"]),
  imageBytes: z.number().int().min(1).max(4_000_000),
});

const addUserSampleSchema = z.object({
  filterId: z.string().min(1).max(128),
  objectKey: z.string().min(1).max(512),
  publicURL: z.string().url(),
  categoryHint: z.string().trim().min(1).max(40).optional(),
});

export interface ReviewImageUploadInitDeps {
  firestore?: Firestore;
  publicBaseURL?: string;
  now?: () => number;
  uuid?: () => string;
  presignPutURL?: (
    key: string,
    options: { expiresSeconds?: number; contentType?: string },
  ) => Promise<{ url: string; headers?: Record<string, string>; expiresAt: number }>;
}

export interface ReviewImageUploadInitResult {
  filterId: string;
  objectKey: string;
  uploadUrl: string;
  uploadHeaders: Record<string, string>;
  publicURL: string;
  expiresAt: number;
}

function publicR2URL(baseURL: string, objectKey: string): string {
  const base = baseURL.replace(/\/+$/, "");
  const encodedKey = objectKey.split("/").map(encodeURIComponent).join("/");
  return `${base}/${encodedKey}`;
}

export async function applyReviewImageUploadInit(
  uid: string,
  rawData: unknown,
  deps: ReviewImageUploadInitDeps = {},
): Promise<ReviewImageUploadInitResult> {
  const parsed = reviewImageUploadInitSchema.safeParse(rawData);
  if (!parsed.success) {
    throw new HttpsError("invalid-argument", parsed.error.message);
  }
  const { filterId, contentType } = parsed.data;

  const db = deps.firestore ?? getFirestore();
  const filterSnap = await db.collection("filters").doc(filterId).get();
  if (!filterSnap.exists) {
    throw new HttpsError("not-found", `filter ${filterId} not found`);
  }

  const publicBaseURL = deps.publicBaseURL ?? process.env.R2_PUBLIC_BASE_URL;
  if (!publicBaseURL) {
    throw new HttpsError("internal", "R2_PUBLIC_BASE_URL is not configured");
  }

  const extension = contentType === "image/png" ? "png" : "jpg";
  const now = deps.now ?? Date.now;
  const uuid = deps.uuid ?? randomUUID;
  const objectKey = `reviews/${filterId}/${uid}/${now()}-${uuid()}.${extension}`;
  const signer = deps.presignPutURL ?? (async (key, options) => {
    const cfg = loadR2Config();
    const presigned = await presignPut(cfg, key, {
      expiresSeconds: options.expiresSeconds,
      contentType: options.contentType,
    });
    return { url: presigned.url, headers: presigned.headers, expiresAt: presigned.expiresAt };
  });
  const presigned = await signer(objectKey, { expiresSeconds: 600, contentType });

  return {
    filterId,
    objectKey,
    uploadUrl: presigned.url,
    uploadHeaders: presigned.headers ?? {},
    publicURL: publicR2URL(publicBaseURL, objectKey),
    expiresAt: presigned.expiresAt,
  };
}

export const reviewImageUploadInit = onCall(
  { region, cors: true, secrets: r2PublicSecrets, enforceAppCheck: true },
  async (req: CallableRequest) => {
    const uid = requireAuth(req);
    return applyReviewImageUploadInit(uid, req.data);
  },
);

export interface SubmitReviewDeps {
  firestore?: Firestore;
}

export interface SubmitReviewResult {
  ok: true;
  filterId: string;
  reviewId: string;
  isVerifiedDownload: boolean;
}

async function hasReviewEntitlement(db: Firestore, uid: string, filterId: string): Promise<boolean> {
  const [savedSnap, entitlementSnap, proSnap] = await Promise.all([
    db.collection("users").doc(uid).collection("savedFilters").doc(filterId).get(),
    db.collection("users").doc(uid).collection("entitlements").doc(filterId).get(),
    db.collection("users").doc(uid).collection("proStatus").doc("status").get(),
  ]);
  return savedSnap.exists ||
    entitlementSnap.exists ||
    (proSnap.data()?.active as boolean | undefined) === true;
}

function filterAuthorUid(data: Record<string, unknown>): string | null {
  const direct = data.authorUid;
  if (typeof direct === "string" && direct.length > 0) return direct;
  const author = data.author as { uid?: unknown } | undefined;
  return typeof author?.uid === "string" && author.uid.length > 0 ? author.uid : null;
}

export async function applySubmitReview(
  uid: string,
  rawData: unknown,
  deps: SubmitReviewDeps = {},
): Promise<SubmitReviewResult> {
  const parsed = submitReviewSchema.safeParse(rawData);
  if (!parsed.success) {
    throw new HttpsError("invalid-argument", parsed.error.message);
  }
  const { filterId, stars, body, photoUrl, photoObjectKey } = parsed.data;
  const db = deps.firestore ?? getFirestore();
  const filterRef = db.collection("filters").doc(filterId);
  const filterSnap = await filterRef.get();
  if (!filterSnap.exists) {
    throw new HttpsError("not-found", `filter ${filterId} not found`);
  }
  const filterData = filterSnap.data() ?? {};
  if (filterData.status !== "approved") {
    throw new HttpsError("failed-precondition", "filter_not_available");
  }
  if (filterAuthorUid(filterData) === uid) {
    throw new HttpsError("failed-precondition", "maker_cannot_review_own_filter");
  }
  const isVerifiedDownload = await hasReviewEntitlement(db, uid, filterId);
  if (!isVerifiedDownload) {
    throw new HttpsError("failed-precondition", "download_required");
  }

  const profileSnap = await db.collection("users").doc(uid).get();
  const profile = profileSnap.data() ?? {};
  const handle = typeof profile.handle === "string" && profile.handle.length > 0
    ? `@${profile.handle.replace(/^@+/, "")}`
    : `@${uid.slice(0, 8)}`;
  const displayName = typeof profile.displayName === "string" && profile.displayName.length > 0
    ? profile.displayName
    : handle;

  const reviewRef = filterRef.collection("reviews").doc(uid);
  const reviewSnap = await reviewRef.get();
  const basePayload: Record<string, unknown> = {
    body,
    stars,
    updatedAt: FieldValue.serverTimestamp(),
  };
  if (photoUrl) basePayload.photoUrl = photoUrl;
  if (photoObjectKey) basePayload.photoObjectKey = photoObjectKey;

  if (reviewSnap.exists) {
    await reviewRef.update(basePayload);
  } else {
    await reviewRef.set({
      ...basePayload,
      filterId,
      authorUid: uid,
      authorHandle: handle,
      authorDisplayName: displayName,
      authorName: displayName,
      status: "active",
      isVerifiedDownload: true,
      helpfulCount: 0,
      flagCount: 0,
      createdAt: FieldValue.serverTimestamp(),
    });
  }

  return { ok: true, filterId, reviewId: uid, isVerifiedDownload };
}

export const submitReview = onCall(
  { region, cors: true, enforceAppCheck: true },
  async (req: CallableRequest) => {
    const uid = requireAuth(req);
    return applySubmitReview(uid, req.data);
  },
);

export interface SampleImageUploadInitResult {
  filterId: string;
  objectKey: string;
  uploadUrl: string;
  uploadHeaders: Record<string, string>;
  publicURL: string;
  expiresAt: number;
}

export interface SampleImageUploadInitDeps {
  firestore?: Firestore;
  publicBaseURL?: string;
  now?: () => number;
  uuid?: () => string;
  presignPutURL?: (
    key: string,
    options: { expiresSeconds?: number; contentType?: string },
  ) => Promise<{ url: string; headers?: Record<string, string>; expiresAt: number }>;
}

export async function applySampleImageUploadInit(
  uid: string,
  rawData: unknown,
  deps: SampleImageUploadInitDeps = {},
): Promise<SampleImageUploadInitResult> {
  const parsed = sampleImageUploadInitSchema.safeParse(rawData);
  if (!parsed.success) {
    throw new HttpsError("invalid-argument", parsed.error.message);
  }
  const { filterId, contentType } = parsed.data;
  const db = deps.firestore ?? getFirestore();
  const filterSnap = await db.collection("filters").doc(filterId).get();
  if (!filterSnap.exists) {
    throw new HttpsError("not-found", `filter ${filterId} not found`);
  }
  const filterData = filterSnap.data() ?? {};
  if (filterData.status !== "approved") {
    throw new HttpsError("failed-precondition", "filter_not_available");
  }
  if (!(await hasReviewEntitlement(db, uid, filterId))) {
    throw new HttpsError("failed-precondition", "download_required");
  }

  const publicBaseURL = deps.publicBaseURL ?? process.env.R2_PUBLIC_BASE_URL;
  if (!publicBaseURL) {
    throw new HttpsError("internal", "R2_PUBLIC_BASE_URL is not configured");
  }
  const extension = contentType === "image/png" ? "png" : "jpg";
  const now = deps.now ?? Date.now;
  const uuid = deps.uuid ?? randomUUID;
  const objectKey = `samples/${filterId}/${uid}/${now()}-${uuid()}.${extension}`;
  const signer = deps.presignPutURL ?? (async (key, options) => {
    const cfg = loadR2Config();
    const presigned = await presignPut(cfg, key, {
      expiresSeconds: options.expiresSeconds,
      contentType: options.contentType,
    });
    return { url: presigned.url, headers: presigned.headers, expiresAt: presigned.expiresAt };
  });
  const presigned = await signer(objectKey, { expiresSeconds: 600, contentType });

  return {
    filterId,
    objectKey,
    uploadUrl: presigned.url,
    uploadHeaders: presigned.headers ?? {},
    publicURL: publicR2URL(publicBaseURL, objectKey),
    expiresAt: presigned.expiresAt,
  };
}

export interface AddUserSampleResult {
  ok: true;
  filterId: string;
  sampleId: string;
  coverURL: string;
}

export interface AddUserSampleDeps {
  firestore?: Firestore;
  publicBaseURL?: string;
  uuid?: () => string;
}

export async function applyAddUserSample(
  uid: string,
  rawData: unknown,
  deps: AddUserSampleDeps = {},
): Promise<AddUserSampleResult> {
  const parsed = addUserSampleSchema.safeParse(rawData);
  if (!parsed.success) {
    throw new HttpsError("invalid-argument", parsed.error.message);
  }
  const { filterId, objectKey, publicURL, categoryHint } = parsed.data;
  const db = deps.firestore ?? getFirestore();
  const filterSnap = await db.collection("filters").doc(filterId).get();
  if (!filterSnap.exists) {
    throw new HttpsError("not-found", `filter ${filterId} not found`);
  }
  const filterData = filterSnap.data() ?? {};
  if (filterData.status !== "approved") {
    throw new HttpsError("failed-precondition", "filter_not_available");
  }
  if (!(await hasReviewEntitlement(db, uid, filterId))) {
    throw new HttpsError("failed-precondition", "download_required");
  }
  const expectedPrefix = `samples/${filterId}/${uid}/`;
  if (!objectKey.startsWith(expectedPrefix)) {
    throw new HttpsError("permission-denied", "sample_object_owner_mismatch");
  }
  const publicBaseURL = deps.publicBaseURL ?? process.env.R2_PUBLIC_BASE_URL;
  if (!publicBaseURL) {
    throw new HttpsError("internal", "R2_PUBLIC_BASE_URL is not configured");
  }
  const expectedURL = publicR2URL(publicBaseURL, objectKey);
  if (publicURL !== expectedURL) {
    throw new HttpsError("permission-denied", "sample_url_mismatch");
  }

  const sampleId = (deps.uuid ?? randomUUID)();
  await db.collection("filters").doc(filterId).collection("samples").doc(sampleId).set({
    id: sampleId,
    kind: "user",
    authorUid: uid,
    categoryHint: categoryHint ?? "user",
    coverURL: publicURL,
    thumbnailURL: publicURL,
    objectKey,
    featured: false,
    createdAt: FieldValue.serverTimestamp(),
  });

  return { ok: true, filterId, sampleId, coverURL: publicURL };
}

export const sampleImageUploadInit = onCall(
  { region, cors: true, secrets: r2PublicSecrets, enforceAppCheck: true },
  async (req: CallableRequest) => {
    const uid = requireAuth(req);
    return applySampleImageUploadInit(uid, req.data);
  },
);

export const addUserSample = onCall(
  { region, cors: true, secrets: [R2_PUBLIC_BASE_URL], enforceAppCheck: true },
  async (req: CallableRequest) => {
    const uid = requireAuth(req);
    return applyAddUserSample(uid, req.data);
  },
);

const submitForReviewSchema = z.object({
  filterId: z.string().min(1).max(128),
  tosOriginal: z.boolean(),
  tosPolicy: z.boolean(),
  tosCommercial: z.boolean(),
});

export interface SubmitForReviewDeps {
  firestore?: Firestore;
}

export interface SubmitForReviewResult {
  ok: true;
  filterId: string;
  status: "pending_review";
}

/** Pure logic — exported for tests. */
export async function applySubmitForReview(
  uid: string,
  rawData: unknown,
  deps: SubmitForReviewDeps = {},
): Promise<SubmitForReviewResult> {
  const parsed = submitForReviewSchema.safeParse(rawData);
  if (!parsed.success) {
    throw new HttpsError("invalid-argument", parsed.error.message);
  }
  const { filterId, tosOriginal, tosPolicy, tosCommercial } = parsed.data;
  if (!tosOriginal || !tosPolicy || !tosCommercial) {
    throw new HttpsError("failed-precondition", "tos_not_accepted");
  }
  const db = deps.firestore ?? getFirestore();
  const ref = db.collection("filters").doc(filterId);
  const snap = await ref.get();
  if (!snap.exists) {
    throw new HttpsError("not-found", `filter ${filterId} not found`);
  }
  const data = snap.data() ?? {};
  if (data.authorUid !== uid) {
    throw new HttpsError("permission-denied", "not the filter owner");
  }
  if (data.status !== "pending_review_pre") {
    throw new HttpsError("failed-precondition", `expected pending_review_pre, got ${data.status}`);
  }
  const price = (data.priceCoins as number | undefined) ?? 0;
  if (!isValidPriceTier(price)) {
    throw new HttpsError("internal", `invalid priceCoins tier: ${price}`);
  }
  await ref.update({
    status: "pending_review",
    tosOriginal,
    tosPolicy,
    tosCommercial,
    submittedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  return { ok: true, filterId, status: "pending_review" };
}

/** POST /filters/{id}/submitForReview — see API_SPEC.md §5.3. */
export const submitForReview = onCall({ region, cors: true, enforceAppCheck: true }, async (req: CallableRequest) => {
  const uid = requireAuth(req);
  return applySubmitForReview(uid, req.data);
});

/** POST /filters/{id}/use — see API_SPEC.md §5.7. Cooldown enforced (1h) per (uid, filter). */
export const recordUse = onCall({ region, cors: true, enforceAppCheck: true }, async (req: CallableRequest) => {
  const uid = requireAuth(req);
  return applyRecordUse(uid, req.data);
});

/** POST /filters/{id}/download — idempotent per (uid, filter). */
export const recordDownload = onCall({ region, cors: true, enforceAppCheck: true }, async (req: CallableRequest) => {
  const uid = requireAuth(req);
  return applyRecordDownload(uid, req.data);
});

const getFilterDetailSchema = z.object({
  filterId: z.string().min(1).max(128),
});

const listReviewsSchema = z.object({
  filterId: z.string().min(1).max(128),
  limit: z.number().int().min(1).max(20).default(20),
  cursor: z.string().min(1).max(512).optional(),
});

const listSamplesSchema = z.object({
  filterId: z.string().min(1).max(128),
  limit: z.number().int().min(1).max(24).default(12),
  cursor: z.string().min(1).max(512).optional(),
});

const reviewActionSchema = z.object({
  filterId: z.string().min(1).max(128),
  reviewId: z.string().min(1).max(128),
});

const markReviewHelpfulSchema = reviewActionSchema.extend({
  helpful: z.boolean(),
});

const removeSampleSchema = z.object({
  filterId: z.string().min(1).max(128),
  sampleId: z.string().min(1).max(128),
});

const toggleFilterLikeSchema = z.object({
  filterId: z.string().min(1).max(128),
  liked: z.boolean(),
});

export interface GetFilterDetailDeps {
  firestore?: Firestore;
  presignGetURL?: (objectKey: string) => Promise<{ url: string; expiresAt: number }>;
  uid?: string;
}

export interface FilterDetailResponse {
  filter: {
    id: string;
    title: string;
    description: string;
    version: string;
    category: string;
    status: string;
    useCount: number;
    downloadCount: number;
    priceCoins: number;
    coverURL: string | null;
    signatureSampleURL: string | null;
    ratingAvg: number | null;
    reviewCount: number;
    likeCount: number;
    sampleCount: number;
    tags: string[];
    createdAt: number | null;
    author: { uid: string; displayName: string; avatarURL: string | null; photoURL: string | null };
  };
  samples: Array<{
    id: string;
    kind: string;
    categoryHint: string | null;
    coverURL: string | null;
    thumbnailURL: string | null;
  }>;
  reviews: Array<{
    id: string;
    authorUid: string;
    authorDisplayName: string;
    stars: number;
    body: string;
    photoUrl: string | null;
    isVerifiedDownload: boolean;
    helpfulCount: number;
    createdAt: number | null;
  }>;
  userHasLiked: boolean;
  signedDownloadURL?: string;
  expiresAt?: number;
  paywall: boolean;
}

export interface ListReviewsDeps {
  firestore?: Firestore;
}

export interface ListReviewsResult {
  filterId: string;
  reviews: FilterDetailResponse["reviews"];
  nextCursor: string | null;
}

export interface ListSamplesDeps {
  firestore?: Firestore;
}

export interface ListSamplesResult {
  filterId: string;
  samples: FilterDetailResponse["samples"];
  nextCursor: string | null;
}

export interface ReviewActionResult {
  ok: true;
  filterId: string;
  reviewId: string;
}

export interface MarkReviewHelpfulResult extends ReviewActionResult {
  helpful: boolean;
}

export interface RemoveSampleResult {
  ok: true;
  filterId: string;
  sampleId: string;
}

export interface ToggleFilterLikeResult {
  ok: true;
  filterId: string;
  liked: boolean;
}

interface PageCursor {
  id: string;
  createdAt: number | null;
}

function encodePageCursor(cursor: PageCursor): string {
  return Buffer.from(JSON.stringify(cursor), "utf8").toString("base64url");
}

function decodePageCursor(rawCursor?: string): PageCursor | null {
  if (!rawCursor) return null;
  try {
    const decoded = JSON.parse(Buffer.from(rawCursor, "base64url").toString("utf8")) as Partial<PageCursor>;
    if (typeof decoded.id !== "string" || decoded.id.length === 0) return null;
    return {
      id: decoded.id,
      createdAt: typeof decoded.createdAt === "number" ? decoded.createdAt : null,
    };
  } catch {
    throw new HttpsError("invalid-argument", "invalid cursor");
  }
}

async function requireApprovedFilter(db: Firestore, filterId: string) {
  const snap = await db.collection("filters").doc(filterId).get();
  if (!snap.exists || snap.data()?.status !== "approved") {
    throw new HttpsError("not-found", `filter ${filterId} is not available`);
  }
  return snap;
}

function compareCreatedAtDesc(
  lhs: { id: string; createdAt: number | null },
  rhs: { id: string; createdAt: number | null },
): number {
  const lhsCreatedAt = lhs.createdAt ?? 0;
  const rhsCreatedAt = rhs.createdAt ?? 0;
  if (lhsCreatedAt !== rhsCreatedAt) {
    return rhsCreatedAt - lhsCreatedAt;
  }
  return rhs.id.localeCompare(lhs.id);
}

function pageStartIndex<T extends { id: string }>(items: T[], cursor: PageCursor | null): number {
  if (!cursor) return 0;
  const index = items.findIndex((item) => item.id === cursor.id);
  return index >= 0 ? index + 1 : 0;
}

function stableEdgeID(...parts: string[]): string {
  return parts.join("_")
    .replace(/[^A-Za-z0-9_-]/g, "_")
    .slice(0, 256);
}

function nextPageCursor<T extends { id: string; createdAt: number | null }>(
  items: T[],
  startIndex: number,
  limit: number,
): string | null {
  if (startIndex + limit >= items.length) return null;
  const last = items[startIndex + limit - 1];
  return encodePageCursor({ id: last.id, createdAt: last.createdAt });
}

/**
 * Pure logic — exported for unit tests with mock Firestore + R2.
 * Returns the filter detail bundle including a presigned download URL.
 */
export async function applyGetFilterDetail(
  rawData: unknown,
  deps: GetFilterDetailDeps = {},
): Promise<FilterDetailResponse> {
  const parsed = getFilterDetailSchema.safeParse(rawData);
  if (!parsed.success) {
    throw new HttpsError("invalid-argument", parsed.error.message);
  }
  const { filterId } = parsed.data;

  const db = deps.firestore ?? getFirestore();
  const snap = await db.collection("filters").doc(filterId).get();
  if (!snap.exists) {
    throw new HttpsError("not-found", `filter ${filterId} not found`);
  }
  const data = snap.data() ?? {};
  if (data.status !== "approved") {
    throw new HttpsError("not-found", `filter ${filterId} is not available (status=${data.status})`);
  }
  const objectKey = data.objectKey as string | undefined;
  if (!objectKey) {
    throw new HttpsError("internal", "filter has no objectKey");
  }
  const priceCoins = (data.priceCoins as number | undefined) ?? 0;
  const requiresEntitlement = priceCoins > 0;
  let paywall = false;
  if (requiresEntitlement) {
    if (!deps.uid) {
      paywall = true;
    } else {
      const entitlementSnap = await db.collection("users").doc(deps.uid)
        .collection("entitlements").doc(filterId)
        .get();
      const proSnap = await db.collection("users").doc(deps.uid)
        .collection("proStatus").doc("status")
        .get();
      const hasActivePro = (proSnap.data()?.active as boolean | undefined) === true;
      if (!entitlementSnap.exists && !hasActivePro) {
        throw new HttpsError("permission-denied", "not_entitled");
      }
    }
  }

  const presigned = paywall
    ? undefined
    : await (deps.presignGetURL ??
      (async (key: string) => {
        const cfg = loadR2Config();
        const result = await presignGet(cfg, key, 600);
        return { url: result.url, expiresAt: result.expiresAt };
      }))(objectKey);

  const author = (data.author as { uid?: string; displayName?: string } | undefined) ?? {};
  const authorUid = author.uid ?? (data.authorUid as string | undefined) ?? "unknown";
  let authorProfile: Record<string, unknown> = {};
  if (authorUid !== "unknown") {
    try {
      const authorSnap = await db.collection("users").doc(authorUid).get();
      authorProfile = authorSnap.data() ?? {};
    } catch {
      authorProfile = {};
    }
  }
  const authorDisplayName =
    (authorProfile.displayName as string | undefined) ??
    (authorProfile.handle as string | undefined) ??
    author.displayName ??
    "Unknown";
  const authorAvatarURL =
    (authorProfile.avatarURL as string | undefined) ??
    (authorProfile.photoURL as string | undefined) ??
    (author as { avatarURL?: string; photoURL?: string }).avatarURL ??
    (author as { avatarURL?: string; photoURL?: string }).photoURL ??
    (data.authorAvatarURL as string | undefined) ??
    (data.authorPhotoURL as string | undefined) ??
    null;
  const createdAtRaw = data.createdAt;
  const createdAt =
    createdAtRaw && typeof createdAtRaw === "object" && "toMillis" in createdAtRaw &&
      typeof (createdAtRaw as { toMillis: unknown }).toMillis === "function"
      ? (createdAtRaw as { toMillis: () => number }).toMillis()
      : null;
  const samplesSnap = await snap.ref.collection("samples")
    .orderBy("featured", "desc")
    .orderBy("createdAt", "desc")
    .limit(12)
    .get();
  const reviewsSnap = await snap.ref.collection("reviews")
    .where("status", "in", ["active", "published"])
    .orderBy("createdAt", "desc")
    .limit(3)
    .get();
  const userHasLiked = deps.uid
    ? (await snap.ref.collection("likes").doc(deps.uid).get()).exists
    : false;

  return {
    filter: {
      id: filterId,
      title: (data.title as string) ?? "",
      description: (data.description as string) ?? "",
      version: (data.version as string) ?? "1.0.0",
      category: (data.category as string) ?? "cinematic",
      status: (data.status as string) ?? "approved",
      useCount: (data.useCount as number) ?? 0,
      downloadCount: (data.downloadCount as number) ?? 0,
      priceCoins,
      coverURL: (data.coverURL as string | null) ?? null,
      signatureSampleURL: (data.signatureSampleURL as string | null) ?? null,
      ratingAvg: (data.ratingAvg as number | null) ?? null,
      reviewCount: (data.reviewCount as number) ?? 0,
      likeCount: (data.likeCount as number) ?? 0,
      sampleCount: (data.sampleCount as number) ?? samplesSnap.size,
      tags: Array.isArray(data.tags) ? data.tags.filter((tag): tag is string => typeof tag === "string") : [],
      createdAt,
      author: {
        uid: authorUid,
        displayName: authorDisplayName,
        avatarURL: authorAvatarURL,
        photoURL: authorAvatarURL,
      },
    },
    samples: samplesSnap.docs.map((sample) => {
      const s = sample.data();
      return {
        id: sample.id,
        kind: (s.kind as string | undefined) ?? "user",
        categoryHint: (s.categoryHint as string | null) ?? null,
        coverURL: (s.coverURL as string | null) ?? null,
        thumbnailURL: (s.thumbnailURL as string | null) ?? null,
      };
    }),
    reviews: reviewsSnap.docs.map((review) => {
      const r = review.data();
      const reviewCreatedAt = readMillis(r.createdAt);
      return {
        id: review.id,
        authorUid: (r.authorUid as string | undefined) ?? review.id,
        authorDisplayName: (r.authorDisplayName as string | undefined)
          ?? (r.authorHandle as string | undefined)
          ?? "사용자",
        stars: (r.stars as number | undefined) ?? 0,
        body: (r.body as string | undefined) ?? "",
        photoUrl: (r.photoUrl as string | null) ?? null,
        isVerifiedDownload: (r.isVerifiedDownload as boolean | undefined) ?? false,
        helpfulCount: (r.helpfulCount as number | undefined) ?? 0,
        createdAt: reviewCreatedAt,
      };
    }),
    userHasLiked,
    signedDownloadURL: presigned?.url,
    expiresAt: presigned?.expiresAt,
    paywall,
  };
}

/** GET /filters/{id} — see API_SPEC.md §5.8. Returns signed download URL. */
export const getFilterDetail = onCall(
  { region, cors: true, secrets: r2Secrets, enforceAppCheck: true },
  async (req: CallableRequest) => {
    // 무료 필터는 공개 열람/다운로드를 허용하되, 유료 필터 URL은 entitlement 확인 후에만 발급한다.
    return applyGetFilterDetail(req.data, { uid: req.auth?.uid });
  },
);

export async function applyListReviews(
  rawData: unknown,
  deps: ListReviewsDeps = {},
): Promise<ListReviewsResult> {
  const parsed = listReviewsSchema.safeParse(rawData);
  if (!parsed.success) {
    throw new HttpsError("invalid-argument", parsed.error.message);
  }
  const { filterId, limit, cursor: rawCursor } = parsed.data;
  const cursor = decodePageCursor(rawCursor);
  const db = deps.firestore ?? getFirestore();
  const filterSnap = await requireApprovedFilter(db, filterId);
  const reviewsSnap = await filterSnap.ref.collection("reviews").get();
  const reviews = reviewsSnap.docs
    .map((review) => {
      const r = review.data();
      return {
        id: review.id,
        authorUid: (r.authorUid as string | undefined) ?? review.id,
        authorDisplayName: (r.authorDisplayName as string | undefined)
          ?? (r.authorHandle as string | undefined)
          ?? "사용자",
        stars: (r.stars as number | undefined) ?? 0,
        body: (r.body as string | undefined) ?? "",
        photoUrl: (r.photoUrl as string | null) ?? null,
        isVerifiedDownload: (r.isVerifiedDownload as boolean | undefined) ?? false,
        helpfulCount: (r.helpfulCount as number | undefined) ?? 0,
        createdAt: readMillis(r.createdAt),
        status: (r.status as string | undefined) ?? "active",
      };
    })
    .filter((review) => review.status === "active" || review.status === "published")
    .sort((lhs, rhs) => {
      const helpfulDelta = rhs.helpfulCount - lhs.helpfulCount;
      return helpfulDelta !== 0 ? helpfulDelta : compareCreatedAtDesc(lhs, rhs);
    });
  const startIndex = pageStartIndex(reviews, cursor);
  const page = reviews.slice(startIndex, startIndex + limit);
  return {
    filterId,
    reviews: page.map(({ status: _status, ...review }) => review),
    nextCursor: nextPageCursor(reviews, startIndex, limit),
  };
}

export const listReviews = onCall(
  { region, cors: true, enforceAppCheck: true },
  async (req: CallableRequest) => applyListReviews(req.data),
);

export async function applyListSamples(
  rawData: unknown,
  deps: ListSamplesDeps = {},
): Promise<ListSamplesResult> {
  const parsed = listSamplesSchema.safeParse(rawData);
  if (!parsed.success) {
    throw new HttpsError("invalid-argument", parsed.error.message);
  }
  const { filterId, limit, cursor: rawCursor } = parsed.data;
  const cursor = decodePageCursor(rawCursor);
  const db = deps.firestore ?? getFirestore();
  const filterSnap = await requireApprovedFilter(db, filterId);
  const samplesSnap = await filterSnap.ref.collection("samples").get();
  const samples = samplesSnap.docs
    .map((sample) => {
      const s = sample.data();
      return {
        id: sample.id,
        kind: (s.kind as string | undefined) ?? "user",
        categoryHint: (s.categoryHint as string | null) ?? null,
        coverURL: (s.coverURL as string | null) ?? null,
        thumbnailURL: (s.thumbnailURL as string | null) ?? null,
        featured: (s.featured as boolean | undefined) ?? false,
        status: (s.status as string | undefined) ?? "active",
        createdAt: readMillis(s.createdAt),
      };
    })
    .filter((sample) => sample.status !== "hidden" && sample.status !== "removed")
    .sort((lhs, rhs) => {
      if (lhs.featured !== rhs.featured) return lhs.featured ? -1 : 1;
      return compareCreatedAtDesc(lhs, rhs);
    });
  const startIndex = pageStartIndex(samples, cursor);
  const page = samples.slice(startIndex, startIndex + limit);
  return {
    filterId,
    samples: page.map(({ featured: _featured, status: _status, createdAt: _createdAt, ...sample }) => sample),
    nextCursor: nextPageCursor(samples, startIndex, limit),
  };
}

export const listSamples = onCall(
  { region, cors: true, enforceAppCheck: true },
  async (req: CallableRequest) => applyListSamples(req.data),
);

export async function applyDeleteReview(
  uid: string,
  rawData: unknown,
  deps: { firestore?: Firestore } = {},
): Promise<ReviewActionResult> {
  const parsed = reviewActionSchema.safeParse(rawData);
  if (!parsed.success) {
    throw new HttpsError("invalid-argument", parsed.error.message);
  }
  const { filterId, reviewId } = parsed.data;
  const db = deps.firestore ?? getFirestore();
  const filterSnap = await requireApprovedFilter(db, filterId);
  const reviewRef = filterSnap.ref.collection("reviews").doc(reviewId);
  const reviewSnap = await reviewRef.get();
  if (!reviewSnap.exists) {
    throw new HttpsError("not-found", "review_not_found");
  }
  if (reviewSnap.data()?.authorUid !== uid) {
    throw new HttpsError("permission-denied", "not_review_owner");
  }
  await reviewRef.delete();
  return { ok: true, filterId, reviewId };
}

export const deleteReview = onCall(
  { region, cors: true, enforceAppCheck: true },
  async (req: CallableRequest) => {
    const uid = requireAuth(req);
    return applyDeleteReview(uid, req.data);
  },
);

export async function applyMarkReviewHelpful(
  uid: string,
  rawData: unknown,
  deps: { firestore?: Firestore } = {},
): Promise<MarkReviewHelpfulResult> {
  const parsed = markReviewHelpfulSchema.safeParse(rawData);
  if (!parsed.success) {
    throw new HttpsError("invalid-argument", parsed.error.message);
  }
  const { filterId, reviewId, helpful } = parsed.data;
  const db = deps.firestore ?? getFirestore();
  const filterSnap = await requireApprovedFilter(db, filterId);
  const reviewRef = filterSnap.ref.collection("reviews").doc(reviewId);
  const reviewSnap = await reviewRef.get();
  if (!reviewSnap.exists) {
    throw new HttpsError("not-found", "review_not_found");
  }
  const reviewData = reviewSnap.data() ?? {};
  const status = (reviewData.status as string | undefined) ?? "active";
  if (status !== "active" && status !== "published") {
    throw new HttpsError("failed-precondition", "review_not_visible");
  }
  if (reviewData.authorUid === uid) {
    throw new HttpsError("failed-precondition", "cannot_mark_own_review_helpful");
  }

  const edgeID = stableEdgeID(filterId, reviewId);
  const edgeRef = db.collection("users").doc(uid).collection("reviewHelpful").doc(edgeID);
  const edgeSnap = await edgeRef.get();
  if (helpful && !edgeSnap.exists) {
    await reviewRef.update({ helpfulCount: FieldValue.increment(1) });
    await edgeRef.set({
      filterId,
      reviewId,
      createdAt: FieldValue.serverTimestamp(),
    });
  } else if (!helpful && edgeSnap.exists) {
    await reviewRef.update({ helpfulCount: FieldValue.increment(-1) });
    await edgeRef.delete();
  }
  return { ok: true, filterId, reviewId, helpful };
}

export const markReviewHelpful = onCall(
  { region, cors: true, enforceAppCheck: true },
  async (req: CallableRequest) => {
    const uid = requireAuth(req);
    return applyMarkReviewHelpful(uid, req.data);
  },
);

export async function applyRemoveSample(
  uid: string,
  rawData: unknown,
  deps: { firestore?: Firestore } = {},
): Promise<RemoveSampleResult> {
  const parsed = removeSampleSchema.safeParse(rawData);
  if (!parsed.success) {
    throw new HttpsError("invalid-argument", parsed.error.message);
  }
  const { filterId, sampleId } = parsed.data;
  const db = deps.firestore ?? getFirestore();
  const filterSnap = await requireApprovedFilter(db, filterId);
  const filterData = filterSnap.data() ?? {};
  const sampleRef = filterSnap.ref.collection("samples").doc(sampleId);
  const sampleSnap = await sampleRef.get();
  if (!sampleSnap.exists) {
    throw new HttpsError("not-found", "sample_not_found");
  }
  const sampleAuthorUid = sampleSnap.data()?.authorUid;
  if (sampleAuthorUid !== uid && filterAuthorUid(filterData) !== uid) {
    throw new HttpsError("permission-denied", "not_sample_owner_or_filter_owner");
  }
  await sampleRef.delete();
  return { ok: true, filterId, sampleId };
}

export const removeSample = onCall(
  { region, cors: true, enforceAppCheck: true },
  async (req: CallableRequest) => {
    const uid = requireAuth(req);
    return applyRemoveSample(uid, req.data);
  },
);

export async function applyToggleFilterLike(
  uid: string,
  rawData: unknown,
  deps: { firestore?: Firestore } = {},
): Promise<ToggleFilterLikeResult> {
  const parsed = toggleFilterLikeSchema.safeParse(rawData);
  if (!parsed.success) {
    throw new HttpsError("invalid-argument", parsed.error.message);
  }
  const { filterId, liked } = parsed.data;
  const db = deps.firestore ?? getFirestore();
  const filterSnap = await requireApprovedFilter(db, filterId);
  const likeRef = filterSnap.ref.collection("likes").doc(uid);
  if (liked) {
    await likeRef.set({ uid, createdAt: FieldValue.serverTimestamp() }, { merge: true });
  } else {
    await likeRef.delete();
  }
  return { ok: true, filterId, liked };
}

export const toggleFilterLike = onCall(
  { region, cors: true, enforceAppCheck: true },
  async (req: CallableRequest) => {
    const uid = requireAuth(req);
    return applyToggleFilterLike(uid, req.data);
  },
);

/** POST /filters/{id}/report — see API_SPEC.md §5.6. */
export const reportFilter = onCall({ region, cors: true, enforceAppCheck: true }, async (req: CallableRequest) => {
  const uid = requireAuth(req);
  const { applyReportFilter } = await import("./moderation.js");
  return applyReportFilter(uid, req.data);
});
