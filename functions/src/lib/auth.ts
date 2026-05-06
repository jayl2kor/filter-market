/**
 * Auth helpers built on top of Firebase ID Token claims provided by
 * `onCall` / `onRequest` v2 handlers. See API_SPEC.md §2.
 */
import { HttpsError } from "firebase-functions/v2/https";
import type { CallableRequest } from "firebase-functions/v2/https";

/**
 * Asserts an authenticated caller and returns their UID.
 * Throws HttpsError("unauthenticated") otherwise.
 */
export function requireAuth(req: CallableRequest): string {
  const uid = req.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "missing or invalid Firebase ID Token");
  }
  return uid;
}

/**
 * Asserts the caller has the `moderator: true` custom claim.
 * Throws HttpsError("permission-denied") otherwise.
 */
export function requireModerator(req: CallableRequest): string {
  const uid = requireAuth(req);
  const isModerator = req.auth?.token?.moderator === true;
  if (!isModerator) {
    throw new HttpsError("permission-denied", "moderator role required");
  }
  return uid;
}
