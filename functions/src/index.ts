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
  submitForReview,
  recordUse,
  getFilterDetail,
  reportFilter,
} from "./http/filters.js";

export { approveFilter, rejectFilter } from "./http/moderation.js";
export { setHandle, deleteAccount } from "./http/identity.js";

// Phase 6 — Coin wallet (CURRENCY_DESIGN.md). Stubs; not wired until Phase 6.
export {
  getWallet,
  topupInit,
  topupFinalize,
  purchaseFilter,
  listTransactions,
  requestWithdraw,
} from "./http/wallet.js";

// Firestore triggers — counters, notifications, denormalized writes.
export { onFilterPublished, onReportCreated } from "./triggers/index.js";
