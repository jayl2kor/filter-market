# moodit · Cloud Functions API Surface

> **Region**: `asia-northeast3`. 모든 callable은 `enforceAppCheck: true` (App Check 적용).
> **As of**: 2026-05-10. 시그니처/오류코드 상세: [`../../docs/API_SPEC.md`](../../docs/API_SPEC.md). 코드 진실원: `functions/src/`.
>
> 본 문서는 PM 관점에서 *어떤 callable이 어떤 화면/플로우를 작동시키는가*를 본다. 오류 코드/요청 schema 디테일은 API_SPEC.md.

## 1. 한눈에

코드 실측(2026-05-10, `functions/src/index.ts` re-export + `grep -rE "^export const \w+ = onCall|onDocument" functions/src/`):

| 영역 | callable 수 | 트리거 수 | 상태 |
|---|---|---|---|
| Identity | 5 | 0 | ✅ Done |
| Filters / Reviews / Samples | **16** | 9 | ✅ 대부분 Done / 트리거 `onFilterPublished` 본문 TODO |
| Moderation / Reports | 5 | 0 | ✅ Done. `onReportCreated` 트리거 본문 TODO |
| Wallet / StoreKit | 4 | 0 | ✅ Done |
| **Total** | **30 callables** | **11 triggers** | 트리거 본문 2개(`onFilterPublished`, `onReportCreated`) TODO — 함수는 export 되어 있으나 부수 효과 미구현 |

## 2. Identity / Profile (`functions/src/http/identity.ts`)

| Callable | 입력 | 처리 | 권한 |
|---|---|---|---|
| `setRole` | targetUid, role | Auth custom claim 부여/해제 | admin |
| `setHandle` | handle | `[a-z0-9_.]{3,30}` 검증 + 예약어 차단 + 트랜잭션 | auth |
| `updateProfile` | displayName, bio, website, makerPageVisible, photoSharingAllowed, avatarVariant, avatarURL/photoURL, avatarObjectKey | `users/{uid}` patch | auth |
| `profileAvatarUploadInit` | contentType, imageBytes | R2 presigned PUT URL: `users/{uid}/avatar/...` | auth |
| `deleteAccount` | — | GDPR 5.1.1(v): 공개 필드 초기화 + `deletedAt`, Auth user 삭제 | auth |

**예약어**: admin, moderator, moodit, support, help, official, system, root, user, guest, anonymous, null, undefined.

## 3. Filters / Reviews / Samples (`functions/src/http/filters.ts`)

### 3.1 필터 라이프사이클

| Callable | 입력 | 효과 | 상태 |
|---|---|---|---|
| `uploadInit` | name, category, tags?, packageBytes, contentSha256?, signatureSampleURL? | filterId 예약 + R2 presigned PUT URL, 상태=`uploading` | ✅ |
| `uploadFinalize` | filterId | R2 객체 HEAD 검증 → `pending_review_pre` | ✅ |
| `submitForReview` | filterId, tos {Original, Policy, Commercial} | 약관 수락 → `pending_review` | ✅ |
| `recordUse` | filterId | (uid, filterId) 1시간 쿨다운 멱등 useCount 증가 | ✅ |
| `getFilterDetail` | filterId | 상세 + presigned 다운로드 URL (유료 시 entitlement/Pro 검증) | ✅ |
| `toggleFilterLike` | filterId, liked | `/filters/{id}/likes/{uid}` 생성/삭제 | ✅ |
| `reportFilter` | filterId, reasonCode, detail? | rate limit 30/h, report 문서 + reportCount 증가 | ✅ |

### 3.2 리뷰

| Callable | 효과 |
|---|---|
| `reviewImageUploadInit` | R2 presigned URL: `reviews/{filterId}/{uid}/{ts}-{uuid}.{ext}` |
| `submitReview` | entitlement 검증, 1 user/filter, 본인 필터 리뷰 차단 |
| `listReviews` (비인증) | helpfulCount 정렬 + 커서 페이징 |
| `deleteReview` | 본인만 |
| `markReviewHelpful` | 본인 리뷰 제외, ±1 토글 |

### 3.3 샘플 (사용자 제공 결과 이미지)

| Callable | 효과 |
|---|---|
| `sampleImageUploadInit` | entitlement 검증 + R2 presigned URL: `samples/{filterId}/{uid}/...` |
| `addUserSample` | objectKey 일치 확인 후 sample 문서 생성 |
| `listSamples` (비인증) | featured 우선 + 페이징 |
| `removeSample` | 소유자 또는 메이커 |

## 4. Moderation / Reports (`functions/src/http/moderation.ts`)

| Callable | 권한 | 효과 |
|---|---|---|
| `approveFilter` | mod/admin | 상태 → `approved`, `publishedAt` 기록 |
| `rejectFilter` | mod/admin | 상태 → `rejected` + reason |
| `undoModerationDecision` | mod/admin | 상태 → `pending_review` |
| `reportReview` | auth | 30/h, review 신고 + reportCount 증가 |
| `reportUser` | auth | 자기 자신 차단, 30/h |

## 5. Wallet / StoreKit (`functions/src/http/wallet.ts`)

| Callable | 효과 | Rate limit |
|---|---|---|
| `purchaseFilter` | 잔액 차감 + entitlement + ledger, 멱등(이미 보유 시 `alreadyOwned`) | 30/min |
| `creditCoinsFromIAP` | Apple JWS 검증, originalTransactionId 중복 방지, 패키지 100/550/1200/3000 | 10/min |
| `proSubscriptionUpdate` | 월/연 구독 JWS → `/proReceipts/{otxId}` + `/users/{uid}/proStatus/status` | — |
| `refundRequest` | walletLedger 항목 기반(purchase/topup) | 5/h |

## 6. Firestore Triggers (`functions/src/triggers/index.ts`)

| Trigger | 문서 경로 | 처리 | 상태 |
|---|---|---|---|
| `onFilterPublished` | `filters/{id}` updated | filterCount/FCM/검색 인덱싱 | 🟠 TODO |
| `onReportCreated` | `filters/{id}/reports/{reportId}` created | 임계값 도달 시 자동 검토 플래그 | 🟠 TODO |
| `onFollowCreated/Deleted` | `follows/{edgeId}` | followerCount/followingCount ±1 | ✅ |
| `onReviewCreated/Updated/Deleted` | `filters/{id}/reviews/{reviewId}` | reviewCount, ratingAvg 재계산 | ✅ |
| `onSampleCreated/Deleted` | `filters/{id}/samples/{sampleId}` | sampleCount ±1 | ✅ |
| `onFilterLikeCreated/Deleted` | `filters/{id}/likes/{uid}` | likeCount ±1 | ✅ |

## 7. Rate Limit Buckets (`_ratelimit/{bucket}/keys/{key}`)

| Bucket | 한도 | 윈도우 |
|---|---|---|
| default | 60 | 60s |
| filters.upload | 10 | 3600s |
| filters.use | 600 | 3600s |
| filters.report | 30 | 3600s |
| identity.handle | 5 | 86400s |
| wallet.purchase | 30 | 60s |
| wallet.iap | 10 | 60s |
| wallet.refund | 5 | 3600s |

## 8. 화면→Callable 매핑 (PM 빠른 참조)

| 화면 | 호출 callable |
|---|---|
| Filter Detail | `getFilterDetail`, `toggleFilterLike`, `recordUse`, `reportFilter` |
| Filter Detail (paid) | `purchaseFilter` |
| Reviews List | `listReviews` (비인증), `markReviewHelpful` |
| Review Compose | `reviewImageUploadInit`, `submitReview` |
| Edit Profile | `profileAvatarUploadInit`, `updateProfile`, `setHandle` |
| Account Deletion | `deleteAccount` |
| Filter Editor 업로드 | `uploadInit` → R2 PUT → `uploadFinalize` → `submitForReview` |
| Wallet Topup | `creditCoinsFromIAP` |
| Pro Subscription | `proSubscriptionUpdate` |
| Refund Request | `refundRequest` |
| Moderation Detail | `approveFilter`, `rejectFilter`, `undoModerationDecision` |

## 9. 외부 시크릿

```
R2_ENDPOINT          = https://<accountId>.r2.cloudflarestorage.com
R2_ACCESS_KEY_ID     = (secret)
R2_SECRET_ACCESS_KEY = (secret)
R2_BUCKET            = moodit-filters
R2_PUBLIC_BASE_URL   = (CDN)
APP_APPLE_ID         = <numeric>
APP_STORE_ENV        = PRODUCTION | SANDBOX
```

라이브러리: `firebase-admin@12`, `firebase-functions@6`, `zod@3`, `@apple/app-store-server-library@3`, `@aws-sdk/client-s3@3`, `@aws-sdk/s3-request-presigner@3`.

---

**참조**: [`DATA_MODEL.md`](./DATA_MODEL.md) · [`../../docs/API_SPEC.md`](../../docs/API_SPEC.md) · [`../../docs/FIRESTORE_RULES.md`](../../docs/FIRESTORE_RULES.md)
