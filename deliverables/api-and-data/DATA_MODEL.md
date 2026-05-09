# moodit · Data Model (Firestore + R2)

> Firestore 컬렉션 / 스키마 / 보안 규칙 요지. 코드 진실원: `firestore.rules`, `firestore.indexes.json`, `functions/src/`.
>
> 본 문서는 PM 관점 — 어떤 컬렉션이 무엇을 저장하고, 어떤 화면이 어떤 path를 읽는가를 한 페이지에 둔다.

## 1. 컬렉션 트리

```
firestore/
├── filters/{id}                          ← 필터 메타데이터
│   ├── reviews/{authorUid}               ← 리뷰 (1인 1리뷰, docId=authorUid)
│   ├── ratings/{uid}                     ← 별점 form direct write
│   ├── samples/{sampleId}                ← 사용자/대표 샘플 이미지
│   ├── likes/{uid}                       ← 좋아요 edge
│   ├── uses/{uid}                        ← recordUse 쿨다운
│   └── reports/{reportId}                ← 필터 신고
├── users/{uid}                           ← 프로필
│   ├── notificationPreferences/main
│   ├── notifications/{nId}
│   ├── devices/{deviceId}                ← FCM 토큰
│   ├── savedFilters/{filterId}
│   ├── favorites/{filterId}
│   ├── collections/{collectionId}
│   ├── captures/{captureId}
│   ├── editorDrafts/current
│   ├── makerDrafts/{draftId}
│   ├── wallet/balance
│   ├── walletLedger/{txId}
│   ├── entitlements/{filterId}
│   ├── proStatus/status
│   ├── exportRequests/{requestId}
│   ├── refundRequests/{orderId}
│   ├── reviewHelpful/{edgeId}
│   └── feedActions/{postId}
├── handles/{handle}                      ← 핸들 소유권
├── follows/{actorUid}_{targetUid}
├── blocks/{actorUid}_{targetUid}
├── walletReceipts/{originalTransactionId} ← IAP 중복 방지
├── proReceipts/{originalTransactionId}
├── _ratelimit/{bucket}/keys/{key}
└── config/...
```

## 2. 핵심 컬렉션 스키마

### `filters/{id}`
```
authorUid, title, category, tags[], status, version,
packageBytes, objectKey, contentSha256, signatureSampleURL,
priceCoins, useCount, downloadCount, likeCount, reviewCount, ratingAvg, sampleCount,
createdAt, publishedAt, rejectionReason
```

**상태 머신**: `uploading → pending_review_pre → pending_review → approved | rejected`

### `filters/{id}/reviews/{authorUid}`
```
stars, body (≤280), photoUrl, isVerifiedDownload,
helpfulCount, makerReply, status, createdAt
```
docId = authorUid → 1인 1리뷰 unique 자동 보장.

### `users/{uid}`
```
handle, displayName, bio, website, avatarURL, photoURL, avatarVariant,
isMaker, filterCount, followerCount, followingCount,
makerPageVisible, photoSharingAllowed, deletedAt
```
soft delete 지원 (`deletedAt` 설정).

### `users/{uid}/wallet/balance`
```
value, updatedAt
```

### `users/{uid}/walletLedger/{txId}`
```
kind: purchase | topup | refund,
amount, relatedFilterId, createdAt
```

### `users/{uid}/proStatus/status`
```
active, productId, expiresAt, revokedAt
```

## 3. 보안 규칙 요지 (`firestore.rules`)

| 컬렉션 | 읽기 | 쓰기 |
|---|---|---|
| `filters` | 공개 | Cloud Functions 전용 |
| `filters/{id}/reviews` | 공개 | 본인(본문/별점) — makerReply는 Functions |
| `filters/{id}/samples` | 공개 | Functions |
| `filters/{id}/likes` | 공개 | 본인 |
| `users/{uid}` | 본인 / 부분 공개(handle, displayName 등) | Functions / 본인 일부 |
| `users/{uid}/wallet`, `walletLedger`, `entitlements` | 본인 | **Cloud Functions 전용** |
| `follows`, `blocks` | 인증 사용자 / actor 한정 | 본인 |
| `helpfulCount` 변경 | — | ±1 검증 강제 |

**Storage 규칙(`storage.rules`)**: 모두 차단 — 미디어는 R2로만.

## 4. 인덱스 (`firestore.indexes.json`)

| 인덱스 | 용도 |
|---|---|
| `filters: status↑ × useCount↓` | 인기 |
| `filters: status↑ × createdAt↓` | 최신 |
| `filters: authorUid↑ × createdAt↓` | 메이커 화면 |
| `filters: status↑ × category↑ × createdAt↓` | 카테고리 + 최신 |

## 5. 미디어 사이즈 제한 (R2)

| 종류 | 한도 | 경로 |
|---|---|---|
| 필터 패키지(.fmpkg) | 5 MB | `filters/{filterId}/...` |
| 리뷰 이미지 | 2.5 MB | `reviews/{filterId}/{uid}/...` |
| 샘플 이미지 | 4 MB | `samples/{filterId}/{uid}/...` |
| 아바타 | 1.5 MB | `users/{uid}/avatar/...` |

## 6. 화면→데이터 경로 매핑 (PM 빠른 참조)

| 화면 | 주요 경로 |
|---|---|
| Marketplace Home | `filters` (status=approved) |
| Filter Detail | `filters/{id}` + `filters/{id}/reviews` (head) + `filters/{id}/likes/{uid}` |
| Reviews List | `filters/{id}/reviews` (helpfulCount sort) |
| Profile (self) | `users/{uid}` + `filters` (authorUid) + `users/{uid}/savedFilters` + `users/{uid}/captures` |
| Saved Filters | `users/{uid}/savedFilters`, `users/{uid}/favorites` |
| Wallet | `users/{uid}/wallet/balance`, `users/{uid}/proStatus/status` |
| Wallet Transactions | `users/{uid}/walletLedger` |
| Notifications Inbox | `users/{uid}/notifications` |
| Notification Settings | `users/{uid}/notificationPreferences/main` |
| Block List | `blocks` (actorUid={me}) |
| Followers/Following | `follows` (actor/target=uid) |

## 7. 결제 도메인 정책 (Phase 6)

- **IAP 상품 ID**: `com.jayl2kor.moodit.coins.{100,550,1200,3000}`, `com.jayl2kor.moodit.pro.{monthly, yearly}`.
- **환율**: 1 Coin ≈ ₩14.
- **필터 가격(코인)**: `[0, 30, 50, 80, 120]`.
- **메이커 분배**: 60% (코인 적립).
- **출금**: Stripe Connect 통한 KRW 환전, 임계 5,000 코인.
- **환불**: 7일 정책 (`refundRequest`).
- **Pro 혜택**: 월 ₩4,900 / 연 ₩34,800. 모든 유료 필터 무제한 + 월 300 코인 자동 적립.

## 8. recordUse 쿨다운

`RECORD_USE_COOLDOWN_MS = 3600000` (1시간) — 동일 (uid, filterId) 페어 내 useCount 멱등 증가.

---

**참조**: [`CLOUD_FUNCTIONS.md`](./CLOUD_FUNCTIONS.md) · [`../../docs/FIRESTORE_RULES.md`](../../docs/FIRESTORE_RULES.md) · [`../../docs/CURRENCY_DESIGN.md`](../../docs/CURRENCY_DESIGN.md) · [`../../docs/FMPKG_SCHEMA.md`](../../docs/FMPKG_SCHEMA.md)
