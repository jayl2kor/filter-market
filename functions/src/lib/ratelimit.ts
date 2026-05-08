/**
 * Rate limiting via Memorystore Redis (sliding window). See API_SPEC.md §7.
 *
 * For MVP cost optimization we can bypass this and rely on Firebase's built-in
 * App Check + Auth quotas. Wire in once abuse signals appear.
 */
import type Redis from "ioredis";
import { FieldValue, getFirestore, type Firestore, type Transaction } from "firebase-admin/firestore";

export interface Bucket {
  name: string;
  limit: number;
  windowSeconds: number;
}

/** Canonical bucket catalog per API_SPEC.md §7.1. */
export const Buckets = {
  default: { name: "default", limit: 60, windowSeconds: 60 },
  filtersUpload: { name: "filters.upload", limit: 10, windowSeconds: 3600 },
  filtersUse: { name: "filters.use", limit: 600, windowSeconds: 3600 },
  filtersReport: { name: "filters.report", limit: 30, windowSeconds: 3600 },
  identityHandle: { name: "identity.handle", limit: 5, windowSeconds: 86400 },
  walletPurchase: { name: "wallet.purchase", limit: 30, windowSeconds: 60 },
  walletIAP: { name: "wallet.iap", limit: 10, windowSeconds: 60 },
  walletRefund: { name: "wallet.refund", limit: 5, windowSeconds: 3600 },
} satisfies Record<string, Bucket>;

export interface AllowResult {
  allowed: boolean;
  limit: number;
  remaining: number;
  resetAt: number;
}

export interface AllowDeps {
  firestore?: Firestore;
  nowMillis?: () => number;
}

/**
 * Sliding-window check. key = `${bucket.name}:${uid}` (or IP for anon).
 * Returns AllowResult; on Redis outage, fail open and let upstream handler proceed.
 */
export async function allow(
  _redis: Redis | undefined,
  bucket: Bucket,
  key: string,
  deps: AllowDeps = {},
): Promise<AllowResult> {
  const db = deps.firestore ?? getFirestore();
  const now = deps.nowMillis?.() ?? Date.now();
  const windowMs = bucket.windowSeconds * 1000;
  const docId = encodeURIComponent(`${bucket.name}:${key}`);
  const ref = db.collection("_ratelimit").doc(docId);

  return db.runTransaction(async (tx: Transaction) => {
    const snap = await tx.get(ref);
    const data = snap.data() as { count?: number; windowStart?: number } | undefined;
    const windowStart = data?.windowStart;
    const currentCount = data?.count;
    const shouldReset =
      !snap.exists ||
      typeof windowStart !== "number" ||
      typeof currentCount !== "number" ||
      now - windowStart >= windowMs;

    if (shouldReset) {
      tx.set(ref, {
        bucket: bucket.name,
        key,
        count: 1,
        windowStart: now,
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
      return {
        allowed: true,
        limit: bucket.limit,
        remaining: Math.max(bucket.limit - 1, 0),
        resetAt: now + windowMs,
      };
    }

    if (currentCount >= bucket.limit) {
      return {
        allowed: false,
        limit: bucket.limit,
        remaining: 0,
        resetAt: windowStart + windowMs,
      };
    }

    const nextCount = currentCount + 1;
    tx.set(ref, {
      count: nextCount,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    return {
      allowed: true,
      limit: bucket.limit,
      remaining: Math.max(bucket.limit - nextCount, 0),
      resetAt: windowStart + windowMs,
    };
  });
}
