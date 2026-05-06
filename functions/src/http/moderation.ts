/**
 * Moderator-only endpoints. See API_SPEC.md §5.4 / §5.5.
 *
 * Authorization requires the `moderator: true` custom claim on the user's
 * Firebase ID Token. Set via Admin SDK during onboarding.
 */
import { onCall, HttpsError } from "firebase-functions/v2/https";
import type { CallableRequest } from "firebase-functions/v2/https";
import { requireModerator } from "../lib/auth.js";

const region = "asia-northeast3";

/** POST /moderation/{filterId}/approve — API_SPEC.md §5.4. */
export const approveFilter = onCall({ region, cors: true }, async (req: CallableRequest) => {
  requireModerator(req);
  // TODO:
  // 1. Validate filterId param.
  // 2. Transaction: load /filters/{id} where status == pending_review.
  // 3. Update status → published, publishedAt = now.
  // 4. Append /filters/{id}/moderation/{auto} decision record.
  // 5. Notify owner (FCM).
  throw new HttpsError("unimplemented", "approveFilter not implemented");
});

/** POST /moderation/{filterId}/reject — API_SPEC.md §5.5. */
export const rejectFilter = onCall({ region, cors: true }, async (req: CallableRequest) => {
  requireModerator(req);
  // TODO: similar to approve but with rejection reason + notify owner.
  throw new HttpsError("unimplemented", "rejectFilter not implemented");
});
