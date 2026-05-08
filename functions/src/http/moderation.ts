/**
 * Moderator-only endpoints.
 *
 * Authorization requires the `moderator: true` custom claim on the user's
 * Firebase ID Token. Set via Admin SDK during onboarding.
 */
import { onCall, HttpsError } from "firebase-functions/v2/https";
import type { CallableRequest } from "firebase-functions/v2/https";
import { getFirestore, FieldValue, type Firestore } from "firebase-admin/firestore";
import { z } from "zod";
import { requireModerator } from "../lib/auth.js";

const region = "asia-northeast3";

const approveSchema = z.object({
  filterId: z.string().min(1).max(128),
});
const rejectSchema = z.object({
  filterId: z.string().min(1).max(128),
  reason: z.string().min(1).max(2000),
});
const undoSchema = z.object({
  filterId: z.string().min(1).max(128),
});

export interface ModerationDeps {
  firestore?: Firestore;
}

export interface ApproveResult { ok: true; filterId: string; status: "approved" }
export interface RejectResult { ok: true; filterId: string; status: "rejected" }
export interface UndoModerationResult { ok: true; filterId: string; status: "pending_review" }

/** Pure logic — exported for unit tests. */
export async function applyApproveFilter(
  rawData: unknown,
  deps: ModerationDeps = {},
): Promise<ApproveResult> {
  const parsed = approveSchema.safeParse(rawData);
  if (!parsed.success) {
    throw new HttpsError("invalid-argument", parsed.error.message);
  }
  const { filterId } = parsed.data;
  const db = deps.firestore ?? getFirestore();
  const ref = db.collection("filters").doc(filterId);
  const snap = await ref.get();
  if (!snap.exists) {
    throw new HttpsError("not-found", `filter ${filterId} not found`);
  }
  const status = snap.data()?.status;
  if (status !== "pending_review" && status !== "pending_review_pre") {
    throw new HttpsError("failed-precondition", `not in review queue (status=${status})`);
  }
  await ref.update({
    status: "approved",
    publishedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  return { ok: true, filterId, status: "approved" };
}

export async function applyRejectFilter(
  rawData: unknown,
  deps: ModerationDeps = {},
): Promise<RejectResult> {
  const parsed = rejectSchema.safeParse(rawData);
  if (!parsed.success) {
    throw new HttpsError("invalid-argument", parsed.error.message);
  }
  const { filterId, reason } = parsed.data;
  const db = deps.firestore ?? getFirestore();
  const ref = db.collection("filters").doc(filterId);
  const snap = await ref.get();
  if (!snap.exists) {
    throw new HttpsError("not-found", `filter ${filterId} not found`);
  }
  const status = snap.data()?.status;
  if (status !== "pending_review" && status !== "pending_review_pre") {
    throw new HttpsError("failed-precondition", `not in review queue (status=${status})`);
  }
  await ref.update({
    status: "rejected",
    rejectionReason: reason,
    rejectedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  return { ok: true, filterId, status: "rejected" };
}

export async function applyUndoModerationDecision(
  rawData: unknown,
  deps: ModerationDeps = {},
): Promise<UndoModerationResult> {
  const parsed = undoSchema.safeParse(rawData);
  if (!parsed.success) {
    throw new HttpsError("invalid-argument", parsed.error.message);
  }
  const { filterId } = parsed.data;
  const db = deps.firestore ?? getFirestore();
  const ref = db.collection("filters").doc(filterId);
  const snap = await ref.get();
  if (!snap.exists) {
    throw new HttpsError("not-found", `filter ${filterId} not found`);
  }
  const status = snap.data()?.status;
  if (status !== "approved" && status !== "rejected") {
    throw new HttpsError("failed-precondition", `no completed moderation decision to undo (status=${status})`);
  }
  await ref.update({
    status: "pending_review",
    publishedAt: FieldValue.delete(),
    rejectedAt: FieldValue.delete(),
    rejectionReason: FieldValue.delete(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  return { ok: true, filterId, status: "pending_review" };
}

const reportSchema = z.object({
  filterId: z.string().min(1).max(128),
  reasonCode: z.string().min(1).max(64),
  detail: z.string().max(2000).optional(),
});

export async function applyReportFilter(
  uid: string,
  rawData: unknown,
  deps: ModerationDeps = {},
): Promise<{ ok: true; reportId: string }> {
  const parsed = reportSchema.safeParse(rawData);
  if (!parsed.success) {
    throw new HttpsError("invalid-argument", parsed.error.message);
  }
  const { filterId, reasonCode, detail } = parsed.data;
  const db = deps.firestore ?? getFirestore();
  const filterRef = db.collection("filters").doc(filterId);
  const filterSnap = await filterRef.get();
  if (!filterSnap.exists) {
    throw new HttpsError("not-found", `filter ${filterId} not found`);
  }
  const reportRef = filterRef.collection("reports").doc();
  await reportRef.set({
    reporterUid: uid,
    reasonCode,
    detail: detail ?? null,
    createdAt: FieldValue.serverTimestamp(),
  });
  await filterRef.update({
    reportCount: FieldValue.increment(1),
    updatedAt: FieldValue.serverTimestamp(),
  });
  return { ok: true, reportId: reportRef.id };
}

export const approveFilter = onCall({ region, cors: true, enforceAppCheck: true }, async (req: CallableRequest) => {
  requireModerator(req);
  return applyApproveFilter(req.data);
});

export const rejectFilter = onCall({ region, cors: true, enforceAppCheck: true }, async (req: CallableRequest) => {
  requireModerator(req);
  return applyRejectFilter(req.data);
});

export const undoModerationDecision = onCall({ region, cors: true, enforceAppCheck: true }, async (req: CallableRequest) => {
  requireModerator(req);
  return applyUndoModerationDecision(req.data);
});
