/**
 * Idempotency-Key support per API_SPEC.md §9.
 *
 * Strategy:
 *   - Required for non-GET endpoints listed in §9 (POST /filters/{id}/use, etc.).
 *   - On first call, record (uid, key) -> response with 24h TTL in Redis.
 *   - On replay, return cached response with same status.
 */
import type Redis from "ioredis";

const TTL_SECONDS = 24 * 60 * 60;

export interface CachedResponse {
  status: number;
  body: unknown;
}

function cacheKey(uid: string, key: string): string {
  return `idempotency:${encodeURIComponent(uid)}:${encodeURIComponent(key)}`;
}

/** Look up a cached response. Returns null on miss. */
export async function get(
  redis: Redis,
  uid: string,
  key: string,
): Promise<CachedResponse | null> {
  const cached = await redis.get(cacheKey(uid, key));
  if (!cached) return null;
  const parsed = JSON.parse(cached) as Partial<CachedResponse>;
  if (typeof parsed.status !== "number" || !("body" in parsed)) {
    return null;
  }
  return { status: parsed.status, body: parsed.body };
}

/** Cache a response keyed by (uid, idempotency-key). */
export async function put(
  redis: Redis,
  uid: string,
  key: string,
  response: CachedResponse,
): Promise<void> {
  await redis.set(cacheKey(uid, key), JSON.stringify(response), "EX", TTL_SECONDS, "NX");
}
