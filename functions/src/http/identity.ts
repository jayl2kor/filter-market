/**
 * Identity / profile endpoints. See API_SPEC.md §4.2 (Identity / Profile).
 *
 * Most profile reads go directly to Firestore via security rules. Only flows
 * needing server-side validation (handle uniqueness, account deletion) live here.
 */
import { onCall, HttpsError } from "firebase-functions/v2/https";
import type { CallableRequest } from "firebase-functions/v2/https";
import { requireAuth } from "../lib/auth.js";

const region = "asia-northeast3";

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
