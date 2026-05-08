/**
 * Wallet 관련 callables.
 *
 *   POST /purchaseFilter         — 코인 차감 + 엔터블먼트 생성 (idempotent)
 *   POST /creditCoinsFromIAP     — StoreKit IAP 영수증 검증 + 코인 적립 (idempotent on originalTransactionId)
 *   POST /proSubscriptionUpdate  — Pro 구독 활성화/갱신 미러
 *   POST /refundRequest          — 환불 요청 큐 등록
 *
 * 폐쇄 루프 가상 화폐 모델 (ADR-0006). 코인은 moodit 안에서만 사용 가능, 원화 출금 미지원.
 */
import { onCall, HttpsError } from "firebase-functions/v2/https";
import type { CallableRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { getFirestore, FieldValue, type Firestore, type Transaction } from "firebase-admin/firestore";
import { z } from "zod";
import { requireAuth } from "../lib/auth.js";
import { allow, Buckets, type Bucket } from "../lib/ratelimit.js";
import { isValidPriceTier } from "../lib/pricing.js";
import {
  type AppleTransactionInfo,
  verifyAppleReceipt,
  verifyAppleTransaction,
} from "../lib/appleReceiptVerifier.js";

const region = "asia-northeast3";

// Apple JWS 검증에 사용하는 시크릿. 콜러블 정의에 secrets로 명시해 cold-start에 노출.
const APP_APPLE_ID = defineSecret("APP_APPLE_ID");
const APP_STORE_ENV = defineSecret("APP_STORE_ENV");
const appleSecrets = [APP_APPLE_ID, APP_STORE_ENV];

async function enforceRateLimit(db: Firestore, bucket: Bucket, key: string): Promise<void> {
  const result = await allow(undefined, bucket, key, { firestore: db });
  if (!result.allowed) {
    throw new HttpsError("resource-exhausted", "rate_limited", {
      limit: result.limit,
      resetAt: result.resetAt,
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// purchaseFilter
// ─────────────────────────────────────────────────────────────────────────────

const purchaseFilterSchema = z.object({
  filterId: z.string().min(1).max(128),
});

export interface PurchaseFilterDeps {
  firestore?: Firestore;
}

export interface PurchaseFilterResult {
  ok: true;
  balance: number;
  filterId: string;
  alreadyOwned: boolean;
}

export async function applyPurchaseFilter(
  uid: string,
  rawData: unknown,
  deps: PurchaseFilterDeps = {},
): Promise<PurchaseFilterResult> {
  const parsed = purchaseFilterSchema.safeParse(rawData);
  if (!parsed.success) {
    throw new HttpsError("invalid-argument", parsed.error.message);
  }
  const { filterId } = parsed.data;
  const db = deps.firestore ?? getFirestore();
  await enforceRateLimit(db, Buckets.walletPurchase, uid);

  return db.runTransaction(async (tx: Transaction) => {
    const filterRef = db.collection("filters").doc(filterId);
    const filterSnap = await tx.get(filterRef);
    if (!filterSnap.exists) {
      throw new HttpsError("not-found", `filter ${filterId} not found`);
    }
    const filterData = filterSnap.data() ?? {};
    if (filterData.status !== "approved") {
      throw new HttpsError("failed-precondition", `filter not available (status=${filterData.status})`);
    }
    const price = (filterData.priceCoins as number | undefined) ?? 0;
    if (!isValidPriceTier(price)) {
      throw new HttpsError("internal", `invalid priceCoins tier: ${price}`);
    }

    const balanceRef = db.collection("users").doc(uid)
      .collection("wallet").doc("balance");
    const balanceSnap = await tx.get(balanceRef);
    const currentBalance = ((balanceSnap.data()?.value as number | undefined) ?? 0);

    const entitlementRef = db.collection("users").doc(uid)
      .collection("entitlements").doc(filterId);
    const entitlementSnap = await tx.get(entitlementRef);

    if (entitlementSnap.exists) {
      // 이미 소유 — idempotent.
      return { ok: true, balance: currentBalance, filterId, alreadyOwned: true };
    }

    if (currentBalance < price) {
      throw new HttpsError(
        "failed-precondition",
        `insufficient_balance: need ${price}, have ${currentBalance}`,
      );
    }
    const newBalance = currentBalance - price;

    tx.set(balanceRef, { value: newBalance, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
    tx.set(entitlementRef, {
      filterId,
      grantedAt: FieldValue.serverTimestamp(),
      pricePaid: price,
    });
    const ledgerRef = db.collection("users").doc(uid)
      .collection("walletLedger").doc();
    tx.set(ledgerRef, {
      kind: "purchase",
      amount: -price,
      relatedItemTitle: (filterData.title as string | undefined) ?? null,
      relatedFilterId: filterId,
      createdAt: FieldValue.serverTimestamp(),
    });

    return { ok: true, balance: newBalance, filterId, alreadyOwned: false };
  });
}

export const purchaseFilter = onCall({ region, cors: true, enforceAppCheck: true }, async (req: CallableRequest) => {
  const uid = requireAuth(req);
  return applyPurchaseFilter(uid, req.data);
});

// ─────────────────────────────────────────────────────────────────────────────
// creditCoinsFromIAP
// ─────────────────────────────────────────────────────────────────────────────

const creditCoinsSchema = z.object({
  originalTransactionId: z.string().min(1).max(128),
  productId: z.string().min(1).max(128),
  signedJWS: z.string().min(1),
});

const COIN_PRODUCT_AMOUNTS: Record<string, number> = {
  "com.jayl2kor.moodit.coins.100": 100,
  "com.jayl2kor.moodit.coins.550": 550,
  "com.jayl2kor.moodit.coins.1200": 1200,
  "com.jayl2kor.moodit.coins.3000": 3000,
};

export interface CreditCoinsDeps {
  firestore?: Firestore;
  /** App Store JWS 검증 hook — 프로덕션에서는 실제 영수증 검증, 테스트에선 stub. */
  verifyReceipt?: (jws: string, productId: string) => Promise<boolean>;
}

export interface CreditCoinsResult {
  ok: true;
  productId: string;
  creditedAmount: number;
  balance: number;
  duplicate: boolean;
}

export async function applyCreditCoinsFromIAP(
  uid: string,
  rawData: unknown,
  deps: CreditCoinsDeps = {},
): Promise<CreditCoinsResult> {
  const parsed = creditCoinsSchema.safeParse(rawData);
  if (!parsed.success) {
    throw new HttpsError("invalid-argument", parsed.error.message);
  }
  const { originalTransactionId, productId, signedJWS } = parsed.data;

  const amount = COIN_PRODUCT_AMOUNTS[productId];
  if (!amount) {
    throw new HttpsError("invalid-argument", `unknown_product: ${productId}`);
  }
  const db = deps.firestore ?? getFirestore();
  await enforceRateLimit(db, Buckets.walletIAP, uid);

  // (Tier1-1) 기본 검증기는 Apple App Store Server Library JWS verifier.
  // 테스트는 deps.verifyReceipt를 명시적 주입.
  const verifier = deps.verifyReceipt ?? verifyAppleReceipt;
  const verified = await verifier(signedJWS, productId);
  if (!verified) {
    throw new HttpsError("permission-denied", "receipt_verification_failed");
  }

  return db.runTransaction(async (tx: Transaction) => {
    const receiptRef = db.collection("walletReceipts").doc(originalTransactionId);
    const receiptSnap = await tx.get(receiptRef);
    const balanceRef = db.collection("users").doc(uid)
      .collection("wallet").doc("balance");
    const balanceSnap = await tx.get(balanceRef);
    const currentBalance = ((balanceSnap.data()?.value as number | undefined) ?? 0);

    if (receiptSnap.exists) {
      // (#48) 동일 originalTransactionId 재호출 — 첫 claim한 uid와 일치하는지 확인.
      // 다른 uid가 같은 receipt를 claim하려 하면 차단 (정상 흐름에선 JWS가 막아주지만 defensive).
      const receiptOwner = receiptSnap.data()?.uid as string | undefined;
      if (receiptOwner && receiptOwner !== uid) {
        throw new HttpsError("permission-denied", "receipt_belongs_to_another_user");
      }
      return {
        ok: true,
        productId,
        creditedAmount: 0,
        balance: currentBalance,
        duplicate: true,
      };
    }

    const newBalance = currentBalance + amount;
    tx.set(receiptRef, {
      uid,
      productId,
      amount,
      createdAt: FieldValue.serverTimestamp(),
    });
    tx.set(balanceRef, { value: newBalance, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
    const ledgerRef = db.collection("users").doc(uid)
      .collection("walletLedger").doc();
    tx.set(ledgerRef, {
      kind: "topup",
      amount,
      relatedItemTitle: `IAP ${productId}`,
      relatedTransactionId: originalTransactionId,
      createdAt: FieldValue.serverTimestamp(),
    });

    return {
      ok: true,
      productId,
      creditedAmount: amount,
      balance: newBalance,
      duplicate: false,
    };
  });
}

export const creditCoinsFromIAP = onCall(
  { region, cors: true, secrets: appleSecrets, enforceAppCheck: true },
  async (req: CallableRequest) => {
    const uid = requireAuth(req);
    return applyCreditCoinsFromIAP(uid, req.data);
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// proSubscriptionUpdate
// ─────────────────────────────────────────────────────────────────────────────

const proSubSchema = z.object({
  originalTransactionId: z.string().min(1).max(128),
  productId: z.string().min(1).max(128),
  signedJWS: z.string().min(1),
});

const PRO_PRODUCT_IDS = new Set([
  "com.jayl2kor.moodit.pro.monthly",
  "com.jayl2kor.moodit.pro.yearly",
]);

export interface ProSubscriptionResult {
  ok: true;
  productId: string;
  active: boolean;
}

export interface ProSubscriptionDeps {
  firestore?: Firestore;
  verifyTransaction?: (
    jws: string,
    productId: string,
  ) => Promise<AppleTransactionInfo | false>;
}

function isProTransactionActive(tx: AppleTransactionInfo): boolean {
  if (tx.revocationDate !== undefined) {
    return false;
  }
  if (tx.expiresDate !== undefined) {
    return tx.expiresDate > Date.now();
  }
  return true;
}

export async function applyProSubscriptionUpdate(
  uid: string,
  rawData: unknown,
  deps: ProSubscriptionDeps = {},
): Promise<ProSubscriptionResult> {
  const parsed = proSubSchema.safeParse(rawData);
  if (!parsed.success) {
    throw new HttpsError("invalid-argument", parsed.error.message);
  }
  const { originalTransactionId, productId, signedJWS } = parsed.data;
  if (!PRO_PRODUCT_IDS.has(productId)) {
    throw new HttpsError("invalid-argument", `not_a_pro_sku: ${productId}`);
  }
  // (Tier1-1) Apple JWS 검증 — production 기본은 verifyAppleReceipt.
  const verifier = deps.verifyTransaction ?? verifyAppleTransaction;
  const transaction = await verifier(signedJWS, productId);
  if (!transaction || transaction.productId !== productId) {
    throw new HttpsError("permission-denied", "receipt_verification_failed");
  }
  const db = deps.firestore ?? getFirestore();
  const active = isProTransactionActive(transaction);
  await db.runTransaction(async (tx: Transaction) => {
    const receiptRef = db.collection("proReceipts").doc(originalTransactionId);
    const receiptSnap = await tx.get(receiptRef);
    const receiptOwner = receiptSnap.data()?.uid as string | undefined;
    if (receiptSnap.exists && receiptOwner && receiptOwner !== uid) {
      throw new HttpsError("permission-denied", "receipt_belongs_to_another_user");
    }

    tx.set(receiptRef, {
      uid,
      productId,
      active,
      expiresDate: transaction.expiresDate ?? null,
      revocationDate: transaction.revocationDate ?? null,
      updatedAt: FieldValue.serverTimestamp(),
      createdAt: receiptSnap.exists
        ? receiptSnap.data()?.createdAt ?? FieldValue.serverTimestamp()
        : FieldValue.serverTimestamp(),
    }, { merge: true });

    const ref = db.collection("users").doc(uid).collection("proStatus").doc("status");
    tx.set(
      ref,
      {
        active,
        productId,
        expiresAt: transaction.expiresDate ?? null,
        revokedAt: transaction.revocationDate ?? null,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  });
  return { ok: true, productId, active };
}

export const proSubscriptionUpdate = onCall(
  { region, cors: true, secrets: appleSecrets, enforceAppCheck: true },
  async (req: CallableRequest) => {
    const uid = requireAuth(req);
    return applyProSubscriptionUpdate(uid, req.data);
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// refundRequest
// ─────────────────────────────────────────────────────────────────────────────

const refundSchema = z.object({
  orderId: z.string().min(1).max(128).regex(/^[A-Za-z0-9._:-]+$/),
  reason: z.string().min(1).max(2000),
});

export async function applyRefundRequest(
  uid: string,
  rawData: unknown,
  deps: { firestore?: Firestore } = {},
): Promise<{ ok: true; requestId: string }> {
  const parsed = refundSchema.safeParse(rawData);
  if (!parsed.success) {
    throw new HttpsError("invalid-argument", parsed.error.message);
  }
  const { orderId, reason } = parsed.data;
  const db = deps.firestore ?? getFirestore();
  await enforceRateLimit(db, Buckets.walletRefund, uid);
  const ledgerRef = db.collection("users").doc(uid).collection("walletLedger").doc(orderId);
  const ledgerSnap = await ledgerRef.get();
  if (!ledgerSnap.exists) {
    throw new HttpsError("not-found", "order_not_found");
  }
  const ledger = ledgerSnap.data() ?? {};
  const kind = ledger.kind as string | undefined;
  if (kind !== "purchase" && kind !== "topup") {
    throw new HttpsError("failed-precondition", "only_purchases_or_topups_can_be_refunded");
  }

  const sanitizedReason = reason.trim().replace(/<[^>]*>/g, "").trim();
  if (!sanitizedReason) {
    throw new HttpsError("invalid-argument", "reason must not be empty");
  }

  const ref = db.collection("users").doc(uid).collection("refundRequests").doc(orderId);
  const existing = await ref.get();
  if (existing.exists) {
    throw new HttpsError("already-exists", "refund_already_requested");
  }
  await ref.set({
    orderId,
    reason: sanitizedReason,
    ledgerKind: kind,
    status: "pending",
    createdAt: FieldValue.serverTimestamp(),
  });
  return { ok: true, requestId: ref.id };
}

export const refundRequest = onCall({ region, cors: true, enforceAppCheck: true }, async (req: CallableRequest) => {
  const uid = requireAuth(req);
  return applyRefundRequest(uid, req.data);
});
