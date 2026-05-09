# Error Codes

> 단일 소스: `firebase-functions/v2/https` `HttpsError` (gRPC FunctionsErrorCode) + `functions/src/lib/errors.ts` (도메인 코드 상수).
>
> Cloud Functions Callable은 두 종류의 에러 표면을 가진다:
> 1. **`HttpsError(code, message, details?)`** — code는 gRPC 표준 (예: `unauthenticated`, `not-found`)
> 2. **메시지 본문**의 도메인 코드 (예: `"download_required"`, `"insufficient_balance: ..."`) — 클라이언트가 분기.

iOS 클라이언트는 `error.code` (gRPC) → HTTP 상태 매핑 + `error.message` 도메인 키워드를 함께 본다.

---

## 1. gRPC 코드 ↔ HTTP 매핑

| HttpsError code | HTTP | 의미 |
|---|---|---|
| `unauthenticated` | 401 | 토큰 누락/만료 |
| `permission-denied` | 403 | 권한 부족 / 비-owner / entitlement 없음 |
| `not-found` | 404 | 자원 없음 또는 status 비활성 |
| `invalid-argument` | 400 | 입력 검증 실패 (zod) |
| `failed-precondition` | 400 | 상태 충돌 (status, balance, TOS, entitlement) |
| `already-exists` | 409 | 핸들/환불요청 중복 |
| `resource-exhausted` | 429 | 레이트리밋 |
| `data-loss` | 500 | R2 업로드 size 불일치 |
| `internal` | 500 | 서버 설정 누락(R2 secrets) / 가격 티어 불일치 등 |
| `unavailable` | 503 | 일시 오류 (현재 사용 안 함) |

`functions/src/lib/errors.ts` 의 `ErrorCode` 상수는 raw HTTP envelope (`onRequest`) 용으로 정의되어 있으며 callable 핸들러들은 사용하지 않는다.

---

## 2. 엔드포인트별 도메인 에러 메시지

`message`는 클라이언트가 분기 가능한 **안정 식별자** 로 의도되었다 (한국어 다국화 메시지가 아님).

### 2.1 Filters
| 엔드포인트 | code / message | 발생 조건 |
|---|---|---|
| `uploadInit` | `internal: "R2_..."` | R2 시크릿 미설정 |
| `uploadFinalize` | `not-found: "filter ... not found"` | 필터 없음 |
| | `permission-denied: "not the filter owner"` | authorUid 불일치 |
| | `failed-precondition: "filter status is X, expected uploading"` | 잘못된 상태 |
| | `not-found: "uploaded object missing on R2"` | R2 HEAD 실패 |
| | `data-loss: "size mismatch: declared=X actual=Y"` | 사이즈 불일치 |
| `submitForReview` | `failed-precondition: "tos_not_accepted"` | TOS 3종 미동의 |
| | `failed-precondition: "expected pending_review_pre, got X"` | 잘못된 상태 |
| | `internal: "invalid priceCoins tier: X"` | 화이트리스트 위반 |
| `recordUse` | `not-found: "filter ... not found"` | 필터 없음 |
| `getFilterDetail` | `not-found: "filter ... is not available (status=X)"` | status≠approved |
| | `permission-denied: "not_entitled"` | 유료 필터 미보유 |
| | `internal: "filter has no objectKey"` | 데이터 무결성 오류 |
| `submitReview` | `failed-precondition: "filter_not_available"` | status≠approved |
| | `failed-precondition: "maker_cannot_review_own_filter"` | 자기 필터 |
| | `failed-precondition: "download_required"` | entitlement 없음 |
| `markReviewHelpful` | `failed-precondition: "review_not_visible"` | review status≠active/published |
| | `failed-precondition: "cannot_mark_own_review_helpful"` | 본인 리뷰 |
| | `not-found: "review_not_found"` | reviewId 없음 |
| `deleteReview` | `permission-denied: "not_review_owner"` | uid 불일치 |
| `addUserSample` | `permission-denied: "sample_object_owner_mismatch"` | objectKey prefix 불일치 |
| | `permission-denied: "sample_url_mismatch"` | publicURL ≠ baseURL+key |
| `removeSample` | `permission-denied: "not_sample_owner_or_filter_owner"` | 권한 없음 |

### 2.2 Identity
| 엔드포인트 | code / message |
|---|---|
| `setHandle` | `invalid-argument: "handle must match [a-z0-9_.]{3,30}"` |
| | `failed-precondition: "handle ... is reserved"` |
| | `already-exists: "handle_taken"` |

### 2.3 Moderation
| 엔드포인트 | code / message |
|---|---|
| `approveFilter` | `failed-precondition: "not in review queue (status=X)"` |
| | `internal: "invalid priceCoins tier: X"` |
| `rejectFilter` | `failed-precondition: "not in review queue (status=X)"` |
| `undoModerationDecision` | `failed-precondition: "no completed moderation decision to undo (status=X)"` |
| `reportUser` | `failed-precondition: "cannot report self"` |

### 2.4 Wallet
| 엔드포인트 | code / message |
|---|---|
| `purchaseFilter` | `failed-precondition: "filter not available (status=X)"` |
| | `failed-precondition: "insufficient_balance: need X, have Y"` |
| | `internal: "invalid priceCoins tier: X"` |
| `creditCoinsFromIAP` | `invalid-argument: "unknown_product: X"` |
| | `permission-denied: "receipt_verification_failed"` |
| | `permission-denied: "receipt_belongs_to_another_user"` |
| `proSubscriptionUpdate` | `invalid-argument: "not_a_pro_sku: X"` |
| | `permission-denied: "receipt_verification_failed"` |
| | `permission-denied: "receipt_belongs_to_another_user"` |
| `refundRequest` | `not-found: "order_not_found"` |
| | `failed-precondition: "only_purchases_or_topups_can_be_refunded"` |
| | `invalid-argument: "reason must not be empty"` |
| | `already-exists: "refund_already_requested"` |

### 2.5 Rate Limit (모든 적용 엔드포인트 공통)
- `resource-exhausted: "rate_limited"` + `details: { limit, resetAt }`

---

## 3. 클라이언트 가이드라인

1. 토큰 만료 (`unauthenticated`) → SDK가 자동 갱신. 그래도 401이면 강제 로그아웃 후 재로그인.
2. `permission-denied` + `not_entitled` → 마켓 구매 플로우로 분기.
3. `failed-precondition` + `download_required` → 필터를 라이브러리에 추가 유도.
4. `failed-precondition` + `insufficient_balance` → 코인 충전 시트(IAP) 표시.
5. `resource-exhausted` → 사용자에게 잠시 후 재시도 안내. `details.resetAt`까지 disable.
6. `data-loss` (uploadFinalize) → 파일 재선택 후 처음부터 재업로드.
7. 알 수 없는 도메인 메시지 → 일반 에러 alert + `requestId` 포함 신고 채널 안내.

---

## 4. 추가 도메인 에러 코드 카탈로그 (legacy / `lib/errors.ts`)

`onRequest` 형식의 raw HTTP 핸들러를 추가할 때 사용 (현재 미사용):

| 코드 | 의미 |
|---|---|
| `INVALID_INPUT` | zod 실패 |
| `UNAUTHENTICATED` | 토큰 없음 |
| `FORBIDDEN` | 권한 없음 |
| `NOT_FOUND` | 자원 없음 |
| `CONFLICT` | 상태 충돌 |
| `RATE_LIMITED` | 한도 초과 |
| `PAYLOAD_TOO_LARGE` | 본문 큼 |
| `UNPROCESSABLE` | 도메인 검증 실패 |
| `IDEMPOTENCY_REPLAY` | 멱등 키 재사용 |
| `INTERNAL` | 서버 버그 |
| `UNAVAILABLE` | 일시 장애 |
