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
import { getFirestore, FieldValue, type Firestore, type Transaction } from "firebase-admin/firestore";
import { z } from "zod";
import { requireAuth } from "../lib/auth.js";

const region = "asia-northeast3";

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
    if (price < 0) {
      throw new HttpsError("internal", "filter has invalid priceCoins");
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

export const purchaseFilter = onCall({ region, cors: true }, async (req: CallableRequest) => {
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

  // (#46) Production 안전 가드 — 검증기 미주입이면 즉시 throw.
  // 테스트는 deps.verifyReceipt를 명시적 주입해야 함.
  const verifier = deps.verifyReceipt ?? (async (): Promise<boolean> => {
    throw new HttpsError("internal", "receipt_verifier_not_configured");
  });
  const verified = await verifier(signedJWS, productId);
  if (!verified) {
    throw new HttpsError("permission-denied", "receipt_verification_failed");
  }

  const db = deps.firestore ?? getFirestore();
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
        creditedAmount: amount,
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

export const creditCoinsFromIAP = onCall({ region, cors: true }, async (req: CallableRequest) => {
  const uid = requireAuth(req);
  return applyCreditCoinsFromIAP(uid, req.data);
});

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

export async function applyProSubscriptionUpdate(
  uid: string,
  rawData: unknown,
  deps: {
    firestore?: Firestore;
    verifyReceipt?: (jws: string, productId: string) => Promise<boolean>;
  } = {},
): Promise<ProSubscriptionResult> {
  const parsed = proSubSchema.safeParse(rawData);
  if (!parsed.success) {
    throw new HttpsError("invalid-argument", parsed.error.message);
  }
  const { productId, signedJWS } = parsed.data;
  if (!PRO_PRODUCT_IDS.has(productId)) {
    throw new HttpsError("invalid-argument", `not_a_pro_sku: ${productId}`);
  }
  // (#46) JWS 검증 — 검증기 미주입 시 즉시 throw로 production 안전.
  const verifier = deps.verifyReceipt ?? (async (): Promise<boolean> => {
    throw new HttpsError("internal", "receipt_verifier_not_configured");
  });
  const verified = await verifier(signedJWS, productId);
  if (!verified) {
    throw new HttpsError("permission-denied", "receipt_verification_failed");
  }
  const db = deps.firestore ?? getFirestore();
  const ref = db.collection("users").doc(uid).collection("proStatus").doc("status");
  await ref.set(
    {
      active: true,
      productId,
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  return { ok: true, productId, active: true };
}

export const proSubscriptionUpdate = onCall({ region, cors: true }, async (req: CallableRequest) => {
  const uid = requireAuth(req);
  return applyProSubscriptionUpdate(uid, req.data);
});

// ─────────────────────────────────────────────────────────────────────────────
// refundRequest
// ─────────────────────────────────────────────────────────────────────────────

const refundSchema = z.object({
  orderId: z.string().min(1).max(128),
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
  const ref = db.collection("users").doc(uid).collection("refundRequests").doc();
  await ref.set({
    orderId,
    reason,
    status: "pending",
    createdAt: FieldValue.serverTimestamp(),
  });
  return { ok: true, requestId: ref.id };
}

export const refundRequest = onCall({ region, cors: true }, async (req: CallableRequest) => {
  const uid = requireAuth(req);
  return applyRefundRequest(uid, req.data);
});
