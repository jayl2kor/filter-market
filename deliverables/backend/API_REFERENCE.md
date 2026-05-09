# Backend API Reference

> 단일 소스: `functions/src/http/*.ts`
> 모든 엔드포인트는 Firebase **HTTPS Callable** (`onCall`) 이며, 클라이언트는 Firebase SDK의 `httpsCallable("<name>")(payload)` 로 호출한다.
> Base 도메인: `https://asia-northeast3-<projectId>.cloudfunctions.net/<name>` (REST로 직접 호출 시 envelope는 `{result: ...}` 또는 `{error: {code, message}}`).
>
> 공통 보안: 모든 callable은 `enforceAppCheck: true` + Firebase ID Token 필수 (단, 일부는 unauth/optional).
> 리전: `asia-northeast3` (Seoul).

---

## 0. 엔드포인트 색인

| 그룹 | 함수 | 인증 | 비고 |
|---|---|---|---|
| Filters / Maker | `uploadInit` | user | R2 presigned PUT 발급 + draft 문서 생성 |
| | `uploadFinalize` | author | R2 객체 검증 → `pending_review_pre` |
| | `submitForReview` | author | TOS 3종 동의 → `pending_review` |
| Filters / Reader | `getFilterDetail` | user | 상세 + presigned download URL |
| | `recordUse` | user | 사용 카운터 +1 (1h 쿨다운) |
| | `toggleFilterLike` | user | 좋아요 on/off |
| | `reportFilter` | user | 신고 등록 |
| Reviews | `submitReview` | user (entitled) | 별점/본문 등록·수정 |
| | `listReviews` | optional | 활성 리뷰 페이지네이션 |
| | `deleteReview` | author | 본인 리뷰 삭제 |
| | `markReviewHelpful` | user | 도움됨 +1/-1 |
| | `reviewImageUploadInit` | user | 리뷰 사진 R2 presigned PUT |
| Samples | `listSamples` | optional | 필터 샘플 페이지네이션 |
| | `sampleImageUploadInit` | user (entitled) | 샘플 R2 presigned PUT |
| | `addUserSample` | user (entitled) | 샘플 메타 등록 |
| | `removeSample` | author or filter-author | 샘플 삭제 |
| Identity | `setHandle` | user | 핸들 클레임 트랜잭션 |
| | `updateProfile` | user | 프로필 머지 업데이트 |
| | `profileAvatarUploadInit` | user | 아바타 R2 presigned PUT |
| | `deleteAccount` | user | 소프트 삭제 + Auth 사용자 삭제 |
| | `setRole` | admin | role custom claim 부여/박탈 |
| Moderation | `approveFilter` | moderator | `pending_review*` → `approved` |
| | `rejectFilter` | moderator | `pending_review*` → `rejected` |
| | `undoModerationDecision` | moderator | 결정 되돌리기 |
| | `reportReview` | user | 리뷰 신고 |
| | `reportUser` | user | 사용자 신고 |
| Wallet | `purchaseFilter` | user | 코인 차감 + entitlement 발급 |
| | `creditCoinsFromIAP` | user | Apple JWS 검증 + 코인 적립 |
| | `proSubscriptionUpdate` | user | Pro 구독 활성화 미러 |
| | `refundRequest` | user | 환불 요청 등록 |

---

## 1. Filters — Maker Lifecycle

### 1.1 `uploadInit`
**파일**: `http/filters.ts:127`
**인증**: 인증된 유저 누구나 (App Check 강제)
**시크릿**: `R2_ENDPOINT`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET`

**Request**
```ts
{
  name: string,                  // 1..60
  category: string,              // 1..40
  tags?: string[],               // ≤12, 각 24자
  packageBytes: number,          // 1..5_000_000 (5MB)
  contentSha256?: string,        // base64
  signatureSampleURL?: string    // url
}
```

**Response**
```ts
{
  id: string,                    // 신규 filterId
  uploadUrl: string,             // R2 presigned PUT URL (10분 유효)
  uploadHeaders: Record<string,string>,
  expiresAt: number,             // epoch seconds
  objectKey: string              // filters/{uid}/{filterId}.fmpkg
}
```

**Side effects**: `/filters/{id}` 문서 생성, `status="uploading"`.

**Errors**: `unauthenticated`, `invalid-argument`, `internal` (R2 config missing).

---

### 1.2 `uploadFinalize`
**파일**: `http/filters.ts:191`
**인증**: 작성자(authorUid 일치)

**Request**
```ts
{ filterId: string }
```

**Response**
```ts
{ ok: true, filterId: string, sha256: string | null }
```

**Side effects**: R2 object 존재 확인 + size match → status를 `uploading` → `pending_review_pre` 로 전이, `sha256`/`uploadedAt` 기록.

**Errors**: `not-found`, `permission-denied`, `failed-precondition` (status 불일치), `data-loss` (size mismatch).

---

### 1.3 `submitForReview`
**파일**: `http/filters.ts:673`
**인증**: 작성자

**Request**
```ts
{
  filterId: string,
  tosOriginal: boolean,
  tosPolicy: boolean,
  tosCommercial: boolean
}
```

**Response**
```ts
{ ok: true, filterId: string, status: "pending_review" }
```

**Side effects**: `pending_review_pre` → `pending_review` 전이. `priceCoins`가 화이트리스트(0/30/50/80/120)에 속하지 않으면 거부.

**Errors**: `failed-precondition` (TOS 미동의 / 잘못된 status / 가격 티어), `permission-denied`, `not-found`.

---

## 2. Filters — Reader

### 2.1 `getFilterDetail`
**파일**: `http/filters.ts:1008`
**인증**: 인증 필수 (#46 — 유료 필터 presigned URL 누출 방지)
**시크릿**: R2 set

**Request**
```ts
{ filterId: string }
```

**Response** (요약)
```ts
{
  filter: {
    id, title, description, version, category, status,
    useCount, downloadCount, priceCoins,
    coverURL: string|null, signatureSampleURL: string|null,
    ratingAvg: number|null, reviewCount, likeCount, sampleCount,
    tags: string[],
    createdAt: number|null,                  // epoch ms
    author: { uid: string, displayName: string }
  },
  samples: Array<{ id, kind, categoryHint, coverURL, thumbnailURL }>,  // 최대 12
  reviews: Array<{ id, authorUid, authorDisplayName, stars, body, photoUrl, isVerifiedDownload, helpfulCount, createdAt }>,  // 최대 3
  userHasLiked: boolean,
  signedDownloadURL: string,                  // R2 presigned GET (10분)
  expiresAt: number
}
```

**유료 게이트**: `priceCoins > 0` 인 경우 호출자(uid)의 `users/{uid}/entitlements/{filterId}` 또는 `users/{uid}/proStatus/status.active == true` 가 있어야 함. 미충족 시 `permission-denied: not_entitled`.

**Errors**: `not-found` (status≠approved 포함), `permission-denied`, `internal`.

---

### 2.2 `recordUse`
**파일**: `http/filters.ts:679`
**인증**: 사용자

**Request**
```ts
{ filterId: string }
```

**Response**
```ts
{ filterId: string, useCount: number, counted: boolean }
```

**의미론**: (uid, filterId)당 **1시간 쿨다운**으로 멱등 카운팅. 트랜잭션 내에서 카운터 + `/filters/{id}/uses/{uid}.lastUseAt` 동시 갱신.

**Errors**: `not-found`, `invalid-argument`.

---

### 2.3 `toggleFilterLike`
**파일**: `http/filters.ts:1251`
**인증**: 사용자

**Request**
```ts
{ filterId: string, liked: boolean }
```

**Response**
```ts
{ ok: true, filterId: string, liked: boolean }
```

**Side effects**: `/filters/{id}/likes/{uid}` set/delete. likeCount는 트리거(`onFilterLikeCreated/Deleted`)가 fan-out.

---

### 2.4 `reportFilter`
**파일**: `http/filters.ts:1260` → `moderation.applyReportFilter`
**인증**: 사용자
**Rate limit**: `Buckets.filtersReport` (30/3600s, per uid)

**Request**
```ts
{ filterId: string, reasonCode: string, detail?: string }
```

**Response** `{ ok: true, reportId: string }`

**Side effects**: `/filters/{id}/reports/{auto}` 생성, `reportCount++`.

---

## 3. Reviews

### 3.1 `submitReview`
**파일**: `http/filters.ts:454`
**인증**: 사용자 + entitlement 보유

**Request**
```ts
{
  filterId: string,
  stars: 1..5,                // int
  body: string,               // trim, 5..500
  photoUrl?: string,
  photoObjectKey?: string
}
```

**Response**
```ts
{ ok: true, filterId, reviewId: <uid>, isVerifiedDownload: boolean }
```

**규칙**:
- 필터가 `approved` 상태여야 함 → 아니면 `failed-precondition: filter_not_available`.
- 메이커는 자기 필터 리뷰 불가 → `failed-precondition: maker_cannot_review_own_filter`.
- entitlement = `savedFilters` ∨ `entitlements/{filterId}` ∨ Pro active. 미보유 시 `failed-precondition: download_required`.
- 1인 1건: 문서 ID = uid. 이미 있으면 update, 없으면 create.

---

### 3.2 `listReviews`
**파일**: `http/filters.ts:1062`
**인증**: optional

**Request**
```ts
{ filterId: string, limit?: 1..20 = 20, cursor?: string }
```

**Response**
```ts
{
  filterId: string,
  reviews: Array<{ id, authorUid, authorDisplayName, stars, body, photoUrl, isVerifiedDownload, helpfulCount, createdAt }>,
  nextCursor: string | null      // base64url JSON {id, createdAt}
}
```

**정렬**: `helpfulCount desc, createdAt desc, id desc`. 활성 상태(`active|published`)만 노출.

---

### 3.3 `deleteReview`
**파일**: `http/filters.ts:1137`
**인증**: 리뷰 작성자(uid 일치) — 모더레이터 삭제는 별도(rules에서 허용).

**Request** `{ filterId, reviewId }`
**Response** `{ ok: true, filterId, reviewId }`

---

### 3.4 `markReviewHelpful`
**파일**: `http/filters.ts:1188`
**인증**: 사용자

**Request** `{ filterId, reviewId, helpful: boolean }`
**Response** `{ ok: true, filterId, reviewId, helpful }`

**규칙**: 본인 리뷰에 도움됨 불가. (filterId, reviewId)당 1회만. helpfulCount 카운터는 함수가 직접 `FieldValue.increment(±1)` 적용. edge 문서: `users/{uid}/reviewHelpful/{filterId_reviewId}`.

---

### 3.5 `reviewImageUploadInit`
**파일**: `http/filters.ts:349`
**인증**: 사용자
**Request**
```ts
{ filterId, contentType: "image/jpeg"|"image/png", imageBytes: 1..2_500_000 }
```
**Response**
```ts
{
  filterId, objectKey, uploadUrl, uploadHeaders,
  publicURL,           // R2_PUBLIC_BASE_URL + objectKey
  expiresAt
}
```
**Object key**: `reviews/{filterId}/{uid}/{ts}-{uuid}.{jpg|png}`

---

## 4. Samples (사용자 샘플)

### 4.1 `listSamples`
**파일**: `http/filters.ts:1108`
**Request** `{ filterId, limit?: 1..24 = 12, cursor?: string }`
**Response** `{ filterId, samples: [{id, kind, categoryHint, coverURL, thumbnailURL}], nextCursor }`
**정렬**: `featured desc, createdAt desc, id desc`. `hidden|removed` 제외.

### 4.2 `sampleImageUploadInit`
**파일**: `http/filters.ts:597`
**인증**: 사용자 + entitlement
**Request** `{ filterId, contentType: "image/jpeg"|"image/png", imageBytes: 1..4_000_000 }`
**Response**: `reviewImageUploadInit`과 동일 형태. Object key: `samples/{filterId}/{uid}/{ts}-{uuid}.{ext}`.

### 4.3 `addUserSample`
**파일**: `http/filters.ts:605`
**인증**: 사용자 + entitlement
**Request**
```ts
{
  filterId, objectKey,        // sampleImageUploadInit이 발급한 키와 prefix(`samples/{filterId}/{uid}/`) 검증
  publicURL,                  // R2_PUBLIC_BASE_URL + objectKey 일치 검증
  categoryHint?: string
}
```
**Response** `{ ok: true, filterId, sampleId, coverURL }`

### 4.4 `removeSample`
**파일**: `http/filters.ts:1222`
**인증**: 샘플 작성자 OR 필터 작성자
**Request** `{ filterId, sampleId }`
**Response** `{ ok: true, filterId, sampleId }`

---

## 5. Identity / Profile

### 5.1 `setHandle`
**파일**: `http/identity.ts:128`
**인증**: 사용자
**Request** `{ handle: string }` — 정규식 `^[a-z0-9_.]{3,30}$`, 예약어 차단(`admin`, `support`, ...).
**Response** `{ ok: true, handle: string }`
**구현**: Firestore 트랜잭션으로 `handles/{handle}` 클레임 + `users/{uid}.handle` 동기화. 이전 핸들이 있으면 자동 해제. 충돌 시 `already-exists: handle_taken`.

### 5.2 `updateProfile`
**파일**: `http/identity.ts:169`
**인증**: 사용자
**Request** (모든 필드 optional, undefined는 미적용)
```ts
{
  displayName?: 1..60,
  bio?: ≤500,
  website?: ≤200,
  makerPageVisible?: boolean,
  photoSharingAllowed?: boolean,
  avatarVariant?: 0..64 int,
  avatarURL?: url,
  photoURL?: url,
  avatarObjectKey?: 1..512
}
```
**Response** `{ ok: true }`. 머지 set, `updatedAt` 자동.

### 5.3 `profileAvatarUploadInit`
**파일**: `http/identity.ts:241`
**Request** `{ contentType: "image/jpeg"|"image/png", imageBytes: 1..1_500_000 }`
**Response**: 일반 R2 presigned PUT 형태. Object key: `users/{uid}/avatar/{ts}-{uuid}.{ext}`.

### 5.4 `deleteAccount`
**파일**: `http/identity.ts:275`
**인증**: 사용자
**Request**: 없음
**Response** `{ ok: true }`
**Side effects**:
1. `users/{uid}` soft-delete (`deletedAt` + 공개 필드 비움).
2. Firebase Auth 사용자 삭제 (idempotent — 이미 삭제돼도 ok).
3. R2 정리/Auth 후속 작업은 비동기 분리 (TODO).

### 5.5 `setRole` (admin only)
**파일**: `http/identity.ts:37`
**인증**: admin
**Request** `{ targetUid: string, role: "admin"|"moderator"|null }` (null = 박탈)
**Response** `{ ok: true, targetUid, role }`
**구현**: `getAuth().setCustomUserClaims(uid, {role})`.
**부트스트랩**: 첫 admin은 `tools/bootstrap-admin.mjs` 실행으로 부여.

---

## 6. Moderation

> 모든 호출자 검증: `requireModerator(req)` — `role` 클레임이 `admin` 또는 `moderator`.

### 6.1 `approveFilter`
**파일**: `http/moderation.ts:266`
**Request** `{ filterId }`
**Response** `{ ok: true, filterId, status: "approved" }`
**전제**: 현재 status ∈ {`pending_review`, `pending_review_pre`}, priceCoins 티어 유효.
**Side effects**: `status="approved"`, `publishedAt` 설정.

### 6.2 `rejectFilter`
**파일**: `http/moderation.ts:271`
**Request** `{ filterId, reason: 1..2000 }`
**Response** `{ ok: true, filterId, status: "rejected" }`
**전제**: 동일 (review 큐 상태).
**Side effects**: `rejectionReason`, `rejectedAt` 기록.

### 6.3 `undoModerationDecision`
**파일**: `http/moderation.ts:276`
**Request** `{ filterId }`
**Response** `{ ok: true, filterId, status: "pending_review" }`
**전제**: 현재 status ∈ {`approved`, `rejected`}.
**Side effects**: `publishedAt`, `rejectedAt`, `rejectionReason` 삭제(FieldValue.delete).

### 6.4 `reportReview`
**파일**: `http/moderation.ts:256`
**인증**: 사용자
**Rate limit**: `Buckets.filtersReport`
**Request** `{ filterId, reviewId, authorUid?, reasonCode, detail? }`
**Response** `{ ok: true, reportId }`
**Side effects**: `/filters/{filterId}/reviews/{reviewId}/reports/{auto}` 생성, 리뷰 `reportCount++`.

### 6.5 `reportUser`
**파일**: `http/moderation.ts:261`
**인증**: 사용자 (`targetUid !== self`)
**Rate limit**: `Buckets.filtersReport`
**Request** `{ targetUid, reasonCode, detail? }`
**Response** `{ ok: true, reportId }`
**Side effects**: `/users/{targetUid}/reports/{auto}` 생성 + `reportCount++`.

---

## 7. Wallet (폐쇄 루프 코인)

> 정책: 코인은 moodit 내부에서만 사용. 원화 출금 미지원. ADR-0006.

### 7.1 `purchaseFilter`
**파일**: `http/wallet.ts:131`
**인증**: 사용자
**Rate limit**: `Buckets.walletPurchase` (30/60s)

**Request** `{ filterId }`
**Response** `{ ok: true, balance: number, filterId, alreadyOwned: boolean }`

**트랜잭션 로직**:
1. 필터 조회 → `status==="approved"` & `priceCoins ∈ [0,30,50,80,120]` 검증
2. `users/{uid}/wallet/balance` + `users/{uid}/entitlements/{filterId}` 읽기
3. 이미 entitlement 보유 → `alreadyOwned: true`로 즉시 종료 (idempotent)
4. balance < price → `failed-precondition: insufficient_balance`
5. balance 차감 + entitlement 생성 + ledger 항목(`kind: "purchase", amount: -price`) 기록

### 7.2 `creditCoinsFromIAP`
**파일**: `http/wallet.ts:245`
**인증**: 사용자
**Rate limit**: `Buckets.walletIAP` (10/60s)
**시크릿**: `APP_APPLE_ID`, `APP_STORE_ENV`

**Request**
```ts
{
  originalTransactionId: string,    // Apple receipt 식별자
  productId: string,                // "com.jayl2kor.moodit.coins.{100|550|1200|3000}"
  signedJWS: string                 // Apple JWS
}
```

**Response** `{ ok: true, productId, creditedAmount, balance, duplicate: boolean }`

**검증**: `verifyAppleReceipt(jws, productId)` — App Store Server Library JWS 검증. 실패 시 `permission-denied: receipt_verification_failed`.

**멱등성**: `walletReceipts/{originalTransactionId}` 단일 문서. 같은 txId 재호출은 `duplicate: true`. 다른 uid가 같은 receipt를 claim 시 `permission-denied: receipt_belongs_to_another_user` (#48 가드).

**적립량**: productId 매핑 (100/550/1200/3000 코인).

### 7.3 `proSubscriptionUpdate`
**파일**: `http/wallet.ts:349`
**인증**: 사용자
**시크릿**: `APP_APPLE_ID`, `APP_STORE_ENV`

**Request** `{ originalTransactionId, productId, signedJWS }` — productId ∈ {`com.jayl2kor.moodit.pro.monthly`, `com.jayl2kor.moodit.pro.yearly`}

**Response** `{ ok: true, productId, active: boolean }`

**구현**: JWS → `AppleTransactionInfo` 검증 → `expiresDate > now && !revocationDate`로 active 판정 → `proReceipts/{txId}` + `users/{uid}/proStatus/status` 미러.

### 7.4 `refundRequest`
**파일**: `http/wallet.ts:409`
**인증**: 사용자
**Rate limit**: `Buckets.walletRefund` (5/3600s)

**Request** `{ orderId: 1..128 [A-Za-z0-9._:-], reason: 1..2000 }`
**Response** `{ ok: true, requestId }`

**전제**:
- `users/{uid}/walletLedger/{orderId}` 가 존재해야 하며 `kind ∈ {"purchase","topup"}` 만 허용.
- 동일 orderId 중복 요청은 `already-exists: refund_already_requested`.

**Side effects**: `users/{uid}/refundRequests/{orderId}` 생성 (`status: "pending"`). 사람 검토 큐.

---

## 8. 공통 동작

### 8.1 인증 헤더
- 모든 callable: Firebase SDK가 자동 첨부 (`Authorization: Bearer <ID Token>`).
- App Check 토큰도 Firebase SDK가 자동 첨부.

### 8.2 응답 envelope
- Callable v2는 SDK 레이어에서 `{result}` / `{error: {code, message, details}}` 형태로 자동 래핑.
- 본 문서의 "Response" 표기는 핸들러가 반환하는 **데이터 페이로드** 만 가리킨다.

### 8.3 에러 코드
[`ERROR_CODES.md`](./ERROR_CODES.md) 참조. 모든 핸들러는 `firebase-functions/v2/https`의 `HttpsError(code, message, details?)` 만 throw.

### 8.4 멱등성
| 엔드포인트 | 멱등 키 |
|---|---|
| `recordUse` | (uid, filterId) + 1h 윈도우 |
| `purchaseFilter` | entitlement 존재 → 즉시 반환 |
| `creditCoinsFromIAP` | `walletReceipts/{originalTransactionId}` |
| `proSubscriptionUpdate` | `proReceipts/{originalTransactionId}` |
| `refundRequest` | `refundRequests/{orderId}` |
| `submitReview` | `reviews/{uid}` (update 또는 create) |
| `setHandle` | 트랜잭션 내 `handles/{handle}` 충돌 검사 |

### 8.5 페이지네이션
`listReviews`, `listSamples` — `cursor`는 base64url(JSON({id, createdAt})). 응답의 `nextCursor`를 그대로 다음 호출에 전달.
