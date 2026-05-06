/**
 * Standard response envelope per API_SPEC.md §4.1.
 *
 * `onCall` v2 handlers return plain objects which the client wraps. For
 * `onRequest` (raw HTTP) handlers we shape the body ourselves using these
 * helpers so all REST responses share one schema.
 */
export interface ApiSuccess<T> {
  ok: true;
  data: T;
  meta: ApiMeta;
}

export interface ApiFailure {
  ok: false;
  error: ApiError;
  meta: ApiMeta;
}

export interface ApiMeta {
  requestId?: string;
  ts: number;
}

export interface ApiError {
  code: string;
  message: string;
  details?: Record<string, unknown>;
}

export function success<T>(data: T, requestId?: string): ApiSuccess<T> {
  return { ok: true, data, meta: { requestId, ts: Math.floor(Date.now() / 1000) } };
}

export function failure(error: ApiError, requestId?: string): ApiFailure {
  return { ok: false, error, meta: { requestId, ts: Math.floor(Date.now() / 1000) } };
}
