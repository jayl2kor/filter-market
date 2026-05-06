/**
 * Idempotency-Key support per API_SPEC.md §9.
 *
 * Strategy:
 *   - Required for non-GET endpoints listed in §9 (POST /filters/{id}/use, etc.).
 *   - On first call, record (uid, key) → response with 24h TTL in Redis.
 *   - On replay, return cached response with same status.
 */
import type Redis from "ioredis";

const TTL_SECONDS = 24 * 60 * 60;

export interface CachedResponse {
  status: number;
  body: unknown;
}

/** Look up a cached response. Returns null on miss. */
export async function get(
  _redis: Redis,
  _uid: string,
  _key: string,
): Promise<CachedResponse | null> {
  // TODO: GET key, JSON.parse, return null on missing.
  return null;
}

/** Cache a response keyed by (uid, idempotency-key). */
export async function put(
  _redis: Redis,
  _uid: string,
  _key: string,
  _response: CachedResponse,
): Promise<void> {
  void TTL_SECONDS;
  // TODO: SET key value EX TTL_SECONDS NX (NX so we don't overwrite a winning race).
}
