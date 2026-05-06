/**
 * Wallet + Coin endpoints. See:
 *   - docs/CURRENCY_DESIGN.md §3 / §9 (UX policy + endpoint catalog)
 *   - docs/API_SPEC.md §5 (request/response envelope)
 *
 * All wallet mutations happen here on the server inside Firestore transactions.
 * Clients can read /wallets/{uid} and /transactions/* via security rules but
 * cannot write — the rules enforce server-only writes.
 */
import { onCall, HttpsError } from "firebase-functions/v2/https";
import type { CallableRequest } from "firebase-functions/v2/https";
import { requireAuth } from "../lib/auth.js";

const region = "asia-northeast3";

/** GET /me/wallet — balance + Pro status + recent transactions snapshot. */
export const getWallet = onCall({ region, cors: true }, async (req: CallableRequest) => {
  const uid = requireAuth(req);
  void uid;
  // TODO:
  // 1. Read /wallets/{uid}; create empty doc on first call.
  // 2. Return { balance, earnedCoins, pendingEarnings, proUntil, recentTransactions[] }.
  throw new HttpsError("unimplemented", "getWallet not implemented");
});

/** POST /wallet/topup/init — issue a server token bound to a coin package SKU. */
export const topupInit = onCall({ region, cors: true }, async (req: CallableRequest) => {
  requireAuth(req);
  // TODO:
  // 1. Validate body { productId } against /config/economy.coinPackages.
  // 2. Persist a pending /topupIntents/{intentId} row (uid, productId, expiresAt).
  // 3. Return { intentId, productId } so the client can hand it to StoreKit.
  throw new HttpsError("unimplemented", "topupInit not implemented");
});

/**
 * POST /wallet/topup/finalize — verify Apple receipt + grant coins atomically.
 * Critical: idempotent on Apple `transactionId`.
 */
export const topupFinalize = onCall({ region, cors: true }, async (req: CallableRequest) => {
  requireAuth(req);
  // TODO:
  // 1. Validate body { intentId, signedTransaction } (StoreKit 2 JWS).
  // 2. Verify JWS signature against Apple's public keys.
  // 3. Match the productId to /config/economy.coinPackages.
  // 4. Look up /transactions where iapTxId == decoded.transactionId — if exists,
  //    return success (replay) without granting again.
  // 5. Firestore transaction:
  //    - increment /wallets/{uid}.balance by package.coins
  //    - increment /wallets/{uid}.totalToppedUp by package.coins
  //    - append /transactions doc { type: "topup", amount, balanceAfter, iapTxId }
  // 6. Return updated balance.
  throw new HttpsError("unimplemented", "topupFinalize not implemented");
});

/**
 * POST /filters/{id}/purchase — spend coins on a filter.
 * Header: Idempotency-Key required.
 */
export const purchaseFilter = onCall({ region, cors: true }, async (req: CallableRequest) => {
  requireAuth(req);
  // TODO:
  // 1. Validate body { filterId, idempotencyKey }.
  // 2. Look up /filters/{filterId}; reject if not published, owner self-purchase, or already owned.
  // 3. If user has active Pro membership AND filter is included in Pro pool: grant ownership without
  //    spending coins; record /transactions { type: "purchase", amount: 0, notes: "pro" } and return.
  // 4. Otherwise Firestore transaction:
  //    a. Re-read /wallets/{uid}.balance; require >= filter.priceCoins (else INSUFFICIENT_BALANCE).
  //    b. Decrement balance.
  //    c. Increment maker /wallets/{ownerUid}.earnedCoins by floor(price * 0.6).
  //    d. Append /transactions docs (purchase, earn) with shared metadata.
  //    e. Add filterId to /users/{uid}.ownedFilters.
  // 5. Return new balance + grant token for download.
  throw new HttpsError("unimplemented", "purchaseFilter not implemented");
});

/** GET /me/transactions — paginated ledger. */
export const listTransactions = onCall({ region, cors: true }, async (req: CallableRequest) => {
  requireAuth(req);
  // TODO:
  // 1. Read body { cursor?, limit?, type? }.
  // 2. Query /transactions where uid == requester, ordered by createdAt desc, with pagination.
  // 3. Return { transactions, nextCursor }.
  throw new HttpsError("unimplemented", "listTransactions not implemented");
});

/** POST /me/withdraw — maker requests payout (Phase 6, requires KYC). */
export const requestWithdraw = onCall({ region, cors: true }, async (req: CallableRequest) => {
  requireAuth(req);
  // TODO:
  // 1. Validate body { coins } against minimum threshold (5,000) and earnedCoins balance.
  // 2. Verify Stripe Connect onboarding completed + tax info present.
  // 3. Create /payouts/{auto} document with status: "requested".
  // 4. Atomically deduct earnedCoins, append /transactions { type: "withdraw" }.
  // 5. Schedule async processor (Cloud Tasks) for Stripe transfer.
  throw new HttpsError("unimplemented", "requestWithdraw not implemented");
});
