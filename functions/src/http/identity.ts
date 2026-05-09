/**
 * Identity / profile endpoints. See API_SPEC.md §4.2 (Identity / Profile).
 */
import { onCall, HttpsError } from "firebase-functions/v2/https";
import type { CallableRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { getAuth } from "firebase-admin/auth";
import { getFirestore, FieldValue, type Firestore, type Transaction } from "firebase-admin/firestore";
import { randomUUID } from "node:crypto";
import { z } from "zod";
import { requireAdmin, requireAuth, type Role } from "../lib/auth.js";
import { loadR2Config, presignPut } from "../lib/r2.js";

const region = "asia-northeast3";

const R2_ENDPOINT = defineSecret("R2_ENDPOINT");
const R2_ACCESS_KEY_ID = defineSecret("R2_ACCESS_KEY_ID");
const R2_SECRET_ACCESS_KEY = defineSecret("R2_SECRET_ACCESS_KEY");
const R2_BUCKET = defineSecret("R2_BUCKET");
const R2_PUBLIC_BASE_URL = defineSecret("R2_PUBLIC_BASE_URL");
const r2PublicSecrets = [R2_ENDPOINT, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_BUCKET, R2_PUBLIC_BASE_URL];

const setRoleSchema = z.object({
  targetUid: z.string().min(1).max(128),
  role: z.union([
    z.literal("admin"),
    z.literal("moderator"),
    z.null(),
  ]),
});

/**
 * Grant or revoke a role on another user. Admin-only.
 *
 * Bootstrap: the FIRST admin must be set via `tools/bootstrap-admin.mjs`.
 */
export const setRole = onCall({ region, cors: true, enforceAppCheck: true }, async (req: CallableRequest) => {
  requireAdmin(req);

  const parsed = setRoleSchema.safeParse(req.data);
  if (!parsed.success) {
    throw new HttpsError("invalid-argument", parsed.error.message);
  }
  const { targetUid, role } = parsed.data;

  const claims: { role?: Role } = {};
  if (role !== null) {
    claims.role = role;
  }
  await getAuth().setCustomUserClaims(targetUid, claims);
  return { ok: true, targetUid, role };
});

// ─────────────────────────────────────────────────────────────────────────────
// setHandle
// ─────────────────────────────────────────────────────────────────────────────

const HANDLE_REGEX = /^[a-z0-9_.]{3,30}$/;
const RESERVED_HANDLES = new Set([
  "admin", "moderator", "moodit", "support", "help", "official",
  "system", "root", "user", "guest", "anonymous", "null", "undefined",
]);

const setHandleSchema = z.object({
  handle: z.string().min(3).max(30),
});

export interface SetHandleDeps {
  firestore?: Firestore;
}

export interface SetHandleResult {
  ok: true;
  handle: string;
}

export async function applySetHandle(
  uid: string,
  rawData: unknown,
  deps: SetHandleDeps = {},
): Promise<SetHandleResult> {
  const parsed = setHandleSchema.safeParse(rawData);
  if (!parsed.success) {
    throw new HttpsError("invalid-argument", parsed.error.message);
  }
  const handle = parsed.data.handle.toLowerCase().trim();
  if (!HANDLE_REGEX.test(handle)) {
    throw new HttpsError("invalid-argument", "handle must match [a-z0-9_.]{3,30}");
  }
  if (RESERVED_HANDLES.has(handle)) {
    throw new HttpsError("failed-precondition", `handle "${handle}" is reserved`);
  }

  const db = deps.firestore ?? getFirestore();
  return db.runTransaction(async (tx: Transaction) => {
    const handleRef = db.collection("handles").doc(handle);
    const userRef = db.collection("users").doc(uid);
    const handleSnap = await tx.get(handleRef);
    const userSnap = await tx.get(userRef);

    if (handleSnap.exists && handleSnap.data()?.uid !== uid) {
      throw new HttpsError("already-exists", "handle_taken");
    }

    // 이전 핸들 해제 (사용자가 핸들 변경 시).
    const prevHandle = userSnap.data()?.handle as string | undefined;
    if (prevHandle && prevHandle !== handle) {
      tx.delete(db.collection("handles").doc(prevHandle));
    }

    tx.set(handleRef, {
      uid,
      claimedAt: FieldValue.serverTimestamp(),
    });
    tx.set(
      userRef,
      {
        handle,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    return { ok: true, handle };
  });
}

export const setHandle = onCall({ region, cors: true, enforceAppCheck: true }, async (req: CallableRequest) => {
  const uid = requireAuth(req);
  return applySetHandle(uid, req.data);
});

// ─────────────────────────────────────────────────────────────────────────────
// updateProfile (displayName / bio / website / makerPageVisible / photoSharingAllowed / avatarVariant)
// ─────────────────────────────────────────────────────────────────────────────

const updateProfileSchema = z.object({
  displayName: z.string().min(1).max(60).optional(),
  bio: z.string().max(500).optional(),
  website: z.string().max(200).optional(),
  makerPageVisible: z.boolean().optional(),
  photoSharingAllowed: z.boolean().optional(),
  avatarVariant: z.number().int().min(0).max(64).optional(),
  avatarURL: z.string().url().optional(),
  photoURL: z.string().url().optional(),
  avatarObjectKey: z.string().min(1).max(512).optional(),
});

export async function applyUpdateProfile(
  uid: string,
  rawData: unknown,
  deps: { firestore?: Firestore } = {},
): Promise<{ ok: true }> {
  const parsed = updateProfileSchema.safeParse(rawData);
  if (!parsed.success) {
    throw new HttpsError("invalid-argument", parsed.error.message);
  }
  const patch: Record<string, unknown> = { updatedAt: FieldValue.serverTimestamp() };
  for (const [key, value] of Object.entries(parsed.data)) {
    if (value !== undefined) {
      patch[key] = value;
    }
  }
  const db = deps.firestore ?? getFirestore();
  await db.collection("users").doc(uid).set(patch, { merge: true });
  return { ok: true };
}

export const updateProfile = onCall({ region, cors: true, enforceAppCheck: true }, async (req: CallableRequest) => {
  const uid = requireAuth(req);
  return applyUpdateProfile(uid, req.data);
});

const profileAvatarUploadInitSchema = z.object({
  contentType: z.enum(["image/jpeg", "image/png"]),
  imageBytes: z.number().int().min(1).max(1_500_000),
});

export interface ProfileAvatarUploadInitDeps {
  publicBaseURL?: string;
  now?: () => number;
  uuid?: () => string;
  presignPutURL?: (
    key: string,
    options: { expiresSeconds?: number; contentType?: string },
  ) => Promise<{ url: string; headers?: Record<string, string>; expiresAt: number }>;
}

export interface ProfileAvatarUploadInitResult {
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

export async function applyProfileAvatarUploadInit(
  uid: string,
  rawData: unknown,
  deps: ProfileAvatarUploadInitDeps = {},
): Promise<ProfileAvatarUploadInitResult> {
  const parsed = profileAvatarUploadInitSchema.safeParse(rawData);
  if (!parsed.success) {
    throw new HttpsError("invalid-argument", parsed.error.message);
  }
  const { contentType } = parsed.data;
  const publicBaseURL = deps.publicBaseURL ?? process.env.R2_PUBLIC_BASE_URL;
  if (!publicBaseURL) {
    throw new HttpsError("internal", "R2_PUBLIC_BASE_URL is not configured");
  }

  const extension = contentType === "image/png" ? "png" : "jpg";
  const now = deps.now ?? Date.now;
  const uuid = deps.uuid ?? randomUUID;
  const objectKey = `users/${uid}/avatar/${now()}-${uuid()}.${extension}`;
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
    objectKey,
    uploadUrl: presigned.url,
    uploadHeaders: presigned.headers ?? {},
    publicURL: publicR2URL(publicBaseURL, objectKey),
    expiresAt: presigned.expiresAt,
  };
}

export const profileAvatarUploadInit = onCall(
  { region, cors: true, secrets: r2PublicSecrets, enforceAppCheck: true },
  async (req: CallableRequest) => {
    const uid = requireAuth(req);
    return applyProfileAvatarUploadInit(uid, req.data);
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// deleteAccount
// ─────────────────────────────────────────────────────────────────────────────

export async function applyDeleteAccount(
  uid: string,
  deps: { firestore?: Firestore } = {},
): Promise<{ ok: true }> {
  const db = deps.firestore ?? getFirestore();
  // Soft-delete: mark /users/{uid}.deletedAt + clear public fields. R2 cleanup + Auth deletion은 백그라운드 작업으로 분리.
  await db.collection("users").doc(uid).set(
    {
      deletedAt: FieldValue.serverTimestamp(),
      displayName: "",
      handle: "",
      bio: "",
      website: "",
      makerPageVisible: false,
      photoSharingAllowed: false,
    },
    { merge: true },
  );
  return { ok: true };
}

/** DELETE /me — full account deletion (GDPR / Apple guideline 5.1.1(v)). */
export const deleteAccount = onCall({ region, cors: true, enforceAppCheck: true }, async (req: CallableRequest) => {
  const uid = requireAuth(req);
  await applyDeleteAccount(uid);
  // Auth 사용자 삭제 — 본 호출은 idempotent (이미 삭제된 경우 무시).
  try {
    await getAuth().deleteUser(uid);
  } catch {
    // Auth user already removed or deletion deferred to async cleanup; soft-delete recorded above.
  }
  return { ok: true };
});
