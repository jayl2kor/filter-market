/**
 * Cloud Functions entry point.
 *
 * Each export becomes an independently-deployable function. We group them by
 * concern (http/* for REST, triggers/* for Firestore triggers) and re-export
 * here so `firebase deploy --only functions:<name>` works.
 *
 * See ../docs/API_SPEC.md for the contract.
 */
import { initializeApp } from "firebase-admin/app";

initializeApp();

// HTTPS Callable / REST endpoints — see API_SPEC.md §4.
export {
  uploadInit,
  uploadFinalize,
  reviewImageUploadInit,
  submitReview,
  submitForReview,
  recordUse,
  getFilterDetail,
  reportFilter,
} from "./http/filters.js";

export { approveFilter, rejectFilter, undoModerationDecision, reportReview, reportUser } from "./http/moderation.js";
export { setHandle, deleteAccount, setRole, updateProfile, profileAvatarUploadInit } from "./http/identity.js";

// Wallet — closed-loop coin (ADR-0006). Sprint 2 wiring of purchase + IAP credit + Pro subscription + refund.
export {
  purchaseFilter,
  creditCoinsFromIAP,
  proSubscriptionUpdate,
  refundRequest,
} from "./http/wallet.js";

// Firestore triggers — counters, notifications, denormalized writes.
export {
  onFilterPublished,
  onReportCreated,
  onFollowCreated,
  onFollowDeleted,
  onReviewCreated,
  onReviewUpdated,
  onReviewDeleted,
  onSampleCreated,
  onSampleDeleted,
  onFilterLikeCreated,
  onFilterLikeDeleted,
} from "./triggers/index.js";
