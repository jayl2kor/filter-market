/**
 * Auth helpers built on top of Firebase ID Token claims provided by
 * `onCall` / `onRequest` v2 handlers. See API_SPEC.md §2.
 *
 * Role contract: custom claim `role` ∈ {"admin", "moderator"} (or absent).
 * Aligned with `firestore.rules` `isAdmin()` / `isModerator()` helpers.
 */
import { HttpsError } from "firebase-functions/v2/https";
import type { CallableRequest } from "firebase-functions/v2/https";

export type Role = "admin" | "moderator";

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

function callerRole(req: CallableRequest): Role | null {
  const role = req.auth?.token?.role;
  if (role === "admin" || role === "moderator") return role;
  return null;
}

/**
 * Asserts the caller has admin role. Returns their UID on success.
 */
export function requireAdmin(req: CallableRequest): string {
  const uid = requireAuth(req);
  if (callerRole(req) !== "admin") {
    throw new HttpsError("permission-denied", "admin role required");
  }
  return uid;
}

/**
 * Asserts the caller has moderator OR admin role. Returns their UID on success.
 */
export function requireModerator(req: CallableRequest): string {
  const uid = requireAuth(req);
  if (callerRole(req) === null) {
    throw new HttpsError("permission-denied", "moderator role required");
  }
  return uid;
}
