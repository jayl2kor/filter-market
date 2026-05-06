/**
 * Rate limiting via Memorystore Redis (sliding window). See API_SPEC.md §7.
 *
 * For MVP cost optimization we can bypass this and rely on Firebase's built-in
 * App Check + Auth quotas. Wire in once abuse signals appear.
 */
import type Redis from "ioredis";

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
} satisfies Record<string, Bucket>;

export interface AllowResult {
  allowed: boolean;
  limit: number;
  remaining: number;
  resetAt: number;
}

/**
 * Sliding-window check. key = `${bucket.name}:${uid}` (or IP for anon).
 * Returns AllowResult; on Redis outage, fail open and let upstream handler proceed.
 */
export async function allow(
  _redis: Redis,
  _bucket: Bucket,
  _key: string,
): Promise<AllowResult> {
  // TODO:
  // 1. Lua script: ZADD <key> <now> <now>; ZREMRANGEBYSCORE <key> 0 <now-window>;
  //    ZCARD <key>; EXPIRE <key> <window>.
  // 2. Compare ZCARD result vs bucket.limit, return shaped result.
  throw new Error("allow not implemented");
}
