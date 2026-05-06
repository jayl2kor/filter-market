/**
 * Filter lifecycle endpoints. See API_SPEC.md §5 for full contract.
 *
 * Endpoints:
 *   POST  /uploadInit               §5.1  upload init
 *   POST  /uploadFinalize           §5.2  upload finalize
 *   POST  /submitForReview          §5.3  submit for review
 *   POST  /use                      §5.7  idempotent use counter
 *   GET   /getFilterDetail/:id      §5.8  detail with signed CDN URL
 *   POST  /report                   §5.6  user report
 */
import { onCall, HttpsError } from "firebase-functions/v2/https";
import type { CallableRequest } from "firebase-functions/v2/https";
import { requireAuth } from "../lib/auth.js";

// region: kept consistent across all functions for low cross-region latency.
const region = "asia-northeast3";

/** POST /filters — see API_SPEC.md §5.1. */
export const uploadInit = onCall({ region, cors: true }, async (req: CallableRequest) => {
  const uid = requireAuth(req);
  // TODO:
  // 1. Validate body via zod (name, category, tags, packageBytes).
  // 2. Reserve filter ID, create Firestore /filters/{id} draft.
  // 3. Generate R2 presigned PUT URL via lib/r2.
  // 4. Return { id, uploadUrl, uploadHeaders, expiresAt }.
  throw new HttpsError("unimplemented", "uploadInit not implemented");
});

/** POST /filters/{id}/finalize — see API_SPEC.md §5.2. */
export const uploadFinalize = onCall({ region, cors: true }, async (req: CallableRequest) => {
  requireAuth(req);
  // TODO: verify SHA256, transition status: uploading → pending_review_pre.
  throw new HttpsError("unimplemented", "uploadFinalize not implemented");
});

/** POST /filters/{id}/submitForReview — see API_SPEC.md §5.3. */
export const submitForReview = onCall({ region, cors: true }, async (req: CallableRequest) => {
  requireAuth(req);
  // TODO: validate ToS acceptance, transition status → pending_review.
  throw new HttpsError("unimplemented", "submitForReview not implemented");
});

/** POST /filters/{id}/use — see API_SPEC.md §5.7. Idempotent via Idempotency-Key. */
export const recordUse = onCall({ region, cors: true }, async (req: CallableRequest) => {
  requireAuth(req);
  // TODO: idempotent counter increment with idempotency-key replay protection.
  throw new HttpsError("unimplemented", "recordUse not implemented");
});

/** GET /filters/{id} — see API_SPEC.md §5.8. Returns signed download URL. */
export const getFilterDetail = onCall({ region, cors: true }, async (req: CallableRequest) => {
  // Public — no auth required.
  void req;
  // TODO: fetch /filters/{id}, generate signed download URL via lib/r2.
  throw new HttpsError("unimplemented", "getFilterDetail not implemented");
});

/** POST /filters/{id}/report — see API_SPEC.md §5.6. */
export const reportFilter = onCall({ region, cors: true }, async (req: CallableRequest) => {
  requireAuth(req);
  // TODO: append to /filters/{id}/reports/{auto}, increment counter.
  throw new HttpsError("unimplemented", "reportFilter not implemented");
});
