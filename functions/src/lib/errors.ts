/**
 * Error code catalog. See API_SPEC.md §4.1 for the canonical list.
 *
 * `onCall` handlers should throw HttpsError with the matching FunctionsErrorCode.
 * Keep these strings stable — clients branch on them.
 */
export const ErrorCode = {
  InvalidInput: "INVALID_INPUT",
  Unauthenticated: "UNAUTHENTICATED",
  Forbidden: "FORBIDDEN",
  NotFound: "NOT_FOUND",
  Conflict: "CONFLICT",
  RateLimited: "RATE_LIMITED",
  PayloadTooLarge: "PAYLOAD_TOO_LARGE",
  Unprocessable: "UNPROCESSABLE",
  IdempotencyReplay: "IDEMPOTENCY_REPLAY",
  Internal: "INTERNAL",
  Unavailable: "UNAVAILABLE",
} as const;

export type ErrorCodeT = (typeof ErrorCode)[keyof typeof ErrorCode];
