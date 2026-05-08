/**
 * Identity / profile endpoints. See API_SPEC.md §4.2 (Identity / Profile).
 *
 * Most profile reads go directly to Firestore via security rules. Only flows
 * needing server-side validation (handle uniqueness, account deletion) live here.
 */
import { onCall, HttpsError } from "firebase-functions/v2/https";
import type { CallableRequest } from "firebase-functions/v2/https";
import { getAuth } from "firebase-admin/auth";
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
 * Bootstrap: the FIRST admin must be set via `tools/bootstrap-admin.mjs`
 * (Firebase Admin SDK service account) since this function requires the caller
 * to already be admin. After that, this function is the standard path.
 *
 * Effect: clients pick up the new claim on next ID token refresh
 * (`getIDToken(forcingRefresh: true)` for immediate effect).
 */
export const setRole = onCall({ region, cors: true }, async (req: CallableRequest) => {
  requireAdmin(req);

  const parsed = setRoleSchema.safeParse(req.data);
  if (!parsed.success) {
    throw new HttpsError("invalid-argument", parsed.error.message);
  }
  const { targetUid, role } = parsed.data;

  // Setting claims to {} clears them; null role means "demote to default user".
  const claims: { role?: Role } = {};
  if (role !== null) {
    claims.role = role;
  }

  await getAuth().setCustomUserClaims(targetUid, claims);
  return { ok: true, targetUid, role };
});

/** POST /me/handle — set or change unique handle. */
export const setHandle = onCall({ region, cors: true }, async (req: CallableRequest) => {
  requireAuth(req);
  // TODO:
  // 1. Validate handle (regex, length, reserved words).
  // 2. Transaction: claim /handles/{handle} → uid, fail with already-exists on conflict.
  // 3. Update /users/{uid}.handle.
  throw new HttpsError("unimplemented", "setHandle not implemented");
});

/** DELETE /me — full account deletion (GDPR / Apple guideline 5.1.1(v)). */
export const deleteAccount = onCall({ region, cors: true }, async (req: CallableRequest) => {
  requireAuth(req);
  // TODO:
  // 1. Require recent re-auth (claims.auth_time within last 5 min).
  // 2. Soft-delete /users/{uid}, anonymize public references.
  // 3. Schedule async R2 asset cleanup task.
  // 4. Delete Firebase Auth user via Admin SDK.
  throw new HttpsError("unimplemented", "deleteAccount not implemented");
});
