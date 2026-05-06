/**
 * Wallet + transaction document shapes. See docs/CURRENCY_DESIGN.md §8.
 */

/** /wallets/{uid} — single document per user. Server-only writes. */
export interface WalletDoc {
  /** Spendable coins (purchases, top-ups, bonuses, refunds). */
  balance: number;
  /** Maker-earned coins. Eligible for withdrawal but NOT spendable. */
  earnedCoins: number;
  /** Earnings not yet eligible for withdrawal (e.g. pending review window). */
  pendingEarnings: number;
  /** Cumulative top-up coins (analytics). */
  totalToppedUp: number;
  /** Cumulative spent coins. */
  totalSpent: number;
  /** Pro membership expiry timestamp. Falsy = not Pro. */
  proUntil?: FirebaseFirestore.Timestamp;
  updatedAt: FirebaseFirestore.Timestamp;
}

export type TransactionType =
  | "topup"      // user purchased coins via Apple IAP
  | "purchase"   // user spent coins on a filter
  | "earn"       // maker earned coins from a sale
  | "withdraw"   // maker withdrew coins to fiat
  | "refund"     // refunded purchase or top-up
  | "bonus"      // streak / signup / promo bonus
  | "pro_grant"; // monthly Pro membership coin grant

/** /transactions/{txId} — append-only ledger. */
export interface TransactionDoc {
  uid: string;
  type: TransactionType;
  /** Signed amount: + for credit, − for debit. */
  amount: number;
  /** Wallet balance immediately after this transaction. */
  balanceAfter: number;
  /** purchase / earn — the involved filter ID. */
  filterId?: string;
  /** topup — Apple's transactionId (de-dup key). */
  iapTxId?: string;
  /** withdraw — payout document ID. */
  payoutId?: string;
  /** Optional human-readable note shown in transaction history. */
  notes?: string;
  createdAt: FirebaseFirestore.Timestamp;
}

/** /payouts/{payoutId} — maker withdrawal request (Phase 6). */
export interface PayoutDoc {
  uid: string;
  /** Coins being withdrawn. */
  coins: number;
  /** Fiat amount in KRW (post-conversion). */
  amountKRW: number;
  /** Conversion rate at request time (CURRENCY_DESIGN.md §5.2). */
  coinToWonRate: number;
  status: "requested" | "processing" | "paid" | "failed" | "cancelled";
  stripeTransferId?: string;
  failureReason?: string;
  requestedAt: FirebaseFirestore.Timestamp;
  paidAt?: FirebaseFirestore.Timestamp;
}

/** Coin top-up package definition (server-side catalog). */
export interface CoinPackage {
  /** App Store product identifier. */
  productId: string;
  /** Coins granted on purchase (base + bonus). */
  coins: number;
  /** Bonus coins included in `coins` (for UI breakdown). */
  bonusCoins: number;
  /** Display price (display only — IAP authoritative price comes from StoreKit). */
  priceLabel: string;
}
