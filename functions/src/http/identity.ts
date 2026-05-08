/**
 * Identity / profile endpoints. See API_SPEC.md §4.2 (Identity / Profile).
 */
import { onCall, HttpsError } from "firebase-functions/v2/https";
import type { CallableRequest } from "firebase-functions/v2/https";
import { getAuth } from "firebase-admin/auth";
import { getFirestore, FieldValue, type Firestore, type Transaction } from "firebase-admin/firestore";
import { z } from "zod";
import { requireAdmin, requireAuth, type Role } from "../lib/auth.js";

const region = "asia-northeast3";

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
