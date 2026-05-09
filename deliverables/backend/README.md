# moodit Backend — 산출물 인덱스

> 작성일: 2026-05-10
> 작성자: 신규 백엔드 엔지니어 온보딩 산출물
> 단일 소스(SoT): `functions/src/**/*.ts`, `firestore.rules`, `firestore.indexes.json`, `firebase.json`
>
> 본 문서 묶음은 **현재 코드 기준** 백엔드 표면을 정리한 명세이다. 향후 변경 시 이 문서를 갱신하기보다 위 SoT 파일을 우선 갱신하고 본 문서는 재생성해도 된다.

---

## 1. 백엔드 한 줄 요약

- **플랫폼**: Firebase (Google Cloud) — Auth + Firestore + Cloud Functions gen 2 + App Check
- **외부 스토리지**: Cloudflare R2 (egress 무료, S3 호환) — 모든 미디어/패키지는 R2에 저장
- **언어/런타임**: TypeScript 5.5 / Node 20
- **리전**: `asia-northeast3` (Seoul) — 모든 함수 동일 리전 고정
- **결제**: Apple StoreKit IAP (JWS 검증) → 폐쇄 루프 가상화폐(코인) 모델
- **API 스타일**: Firebase **HTTPS Callable** (`onCall`) 위주 + Firestore 트리거(`onDocument*`)
- **Firebase Storage는 사용하지 않음** (`storage.rules`에서 모든 경로 deny). 미디어는 R2 presigned URL 경유.

---

## 2. 산출물 파일 일람

| # | 파일 | 내용 |
|---|---|---|
| 1 | [`API_REFERENCE.md`](./API_REFERENCE.md) | 모든 Callable / Trigger 엔드포인트 상세 명세 (입출력 스키마, 에러, 인증, 부수효과) |
| 2 | [`FIRESTORE_SCHEMA.md`](./FIRESTORE_SCHEMA.md) | Firestore 컬렉션 트리, 문서 스키마, 보안 룰 요약, 인덱스 |
| 3 | [`TRIGGERS.md`](./TRIGGERS.md) | Firestore 이벤트 트리거(카운터 fan-out, 상태 미러) 명세 |
| 4 | [`ERROR_CODES.md`](./ERROR_CODES.md) | HttpsError 코드 ↔ 도메인 에러 매핑 |
| 5 | [`RATE_LIMITS.md`](./RATE_LIMITS.md) | 버킷별 한도와 적용 엔드포인트 |
| 6 | [`AUTH_AND_ROLES.md`](./AUTH_AND_ROLES.md) | 토큰/Custom Claims/role 체계, App Check |
| 7 | [`DEPLOYMENT.md`](./DEPLOYMENT.md) | 시크릿, 배포 명령, 에뮬레이터, 환경 분리 |
| 8 | [`OPENAPI.yaml`](./OPENAPI.yaml) | Callable을 REST로 표현한 OpenAPI 3.0 명세 (도구용) |

---

## 3. 시스템 컨텍스트

```
┌──────────────┐                  ┌────────────────────────────┐
│   iOS App    │                  │   Cloud Functions (gen2)   │
│              │ ── ID Token ──▶  │   asia-northeast3          │
│              │                  │   onCall(*) + Firestore    │
└──────────────┘                  │   triggers + Apple JWS     │
       │                          └─────────────┬──────────────┘
       │                                        │
       │  Firestore SDK (read 위주)              │ Admin SDK
       │                                        ▼
       │                            ┌────────────────────────┐
       └─────────────────────────▶  │  Cloud Firestore        │
                                    │  (rules: firestore.rules)│
                                    └────────────────────────┘
                                                 │
                ┌────────────────────────────────┼─────────────┐
                ▼                                ▼             ▼
        Cloudflare R2 (S3)              Apple App Store    FCM
        — .fmpkg 패키지                 — IAP/구독 검증     — 알림
        — review/sample 이미지          (JWS Verifier)
        — 사용자 아바타
        presigned PUT/GET (10분)
```

---

## 4. 모듈 맵 (functions/src/)

| 모듈 | 책임 | 주요 export |
|---|---|---|
| `index.ts` | 함수 단일 진입점, 모든 callable + trigger를 re-export | (deploy unit) |
| `http/filters.ts` | 필터 라이프사이클 (업로드/검수/사용/상세/리뷰/샘플/좋아요/신고) | uploadInit, uploadFinalize, submitForReview, recordUse, getFilterDetail, listReviews, listSamples, submitReview, deleteReview, markReviewHelpful, reviewImageUploadInit, sampleImageUploadInit, addUserSample, removeSample, toggleFilterLike, reportFilter |
| `http/identity.ts` | 핸들/프로필/계정/role | setHandle, updateProfile, profileAvatarUploadInit, deleteAccount, setRole |
| `http/moderation.ts` | 모더레이터 큐 + 신고 처리 | approveFilter, rejectFilter, undoModerationDecision, reportReview, reportUser |
| `http/wallet.ts` | 코인 지갑, IAP 적립, Pro 구독, 환불 | purchaseFilter, creditCoinsFromIAP, proSubscriptionUpdate, refundRequest |
| `http/purchases.ts` | (Phase 6 placeholder, 미배포) | — |
| `triggers/index.ts` | Firestore 이벤트 트리거 (카운터, 통계 재계산) | onFilterPublished, onReportCreated, onFollowCreated/Deleted, onReviewCreated/Updated/Deleted, onSampleCreated/Deleted, onFilterLikeCreated/Deleted |
| `lib/auth.ts` | requireAuth/requireAdmin/requireModerator | — |
| `lib/r2.ts` | R2 presigned URL (PUT/GET/HEAD+SHA-256) | loadR2Config, presignPut, presignGet, headWithChecksum |
| `lib/ratelimit.ts` | Firestore 기반 sliding-window 레이트리밋 | allow, Buckets |
| `lib/idempotency.ts` | 멱등 키 캐시 (확장용) | — |
| `lib/pricing.ts` | 가격 티어 화이트리스트(0/30/50/80/120) | VALID_PRICE_TIERS, isValidPriceTier |
| `lib/appleReceiptVerifier.ts` | App Store JWS 검증 (Apple `app-store-server-library`) | verifyAppleReceipt, verifyAppleTransaction |
| `lib/envelope.ts` | 표준 응답 envelope 헬퍼 (raw HTTP용) | success, failure |
| `lib/errors.ts` | 도메인 에러 코드 상수 | ErrorCode |
| `types/*.ts` | Firestore 도큐먼트 TS 타입 (filter/wallet/user/moderation/package) | — |

---

## 5. 검증된 사실 (Verified)

| 항목 | 값 | 근거 |
|---|---|---|
| Functions 리전 | `asia-northeast3` | 모든 `http/*.ts` 상수 `region` |
| Node 런타임 | `nodejs20` | `firebase.json:13` |
| App Check | 모든 callable에 `enforceAppCheck: true` | `http/*.ts` |
| 인증 토큰 | Firebase ID Token (Auth) | `lib/auth.ts:17` |
| 권한 모델 | Custom Claim `role ∈ {admin, moderator}` | `lib/auth.ts:25-28`, `firestore.rules:24-30` |
| 미디어 저장소 | Cloudflare R2 (S3 호환) | `lib/r2.ts`, `storage.rules:6-9` |
| 가격 티어 | `[0, 30, 50, 80, 120]` 코인만 허용 | `lib/pricing.ts:1` |
| 사용 카운터 쿨다운 | 1시간/(uid, filter) | `http/filters.ts:38` (`RECORD_USE_COOLDOWN_MS`) |
| Presigned URL TTL | 600초 (10분) | `http/filters.ts:165` 외 |
| 지갑 쓰기 | 클라이언트 직접 쓰기 차단, 서버 트랜잭션만 허용 | `firestore.rules:309-313`, `wallet.ts` |
| IAP 멱등성 | `walletReceipts/{originalTransactionId}` 단일 문서 | `wallet.ts:194` |
| 리뷰 1인 1건 | 문서 ID = `authorUid` (Firestore key collision으로 강제) | `firestore.rules:117`, `filters.ts:423` |

## 6. 알려진 미구현/주의사항

- `purchases.ts` — Phase 6 placeholder. Stripe Connect 기반 메이커 페이아웃 파이프라인은 미연결.
- `triggers/index.ts:onFilterPublished`, `onReportCreated` — TODO 주석. FCM/검색 인덱싱/SafeSearch 미연결.
- `firestore.rules` — `filters` 루트 문서 create/update/delete는 클라이언트에서 차단(`allow ... if false`). 모든 lifecycle 변경은 Cloud Function 경유.
- 레이트리밋은 현재 Firestore 기반이며 Memorystore Redis로 이전 가능 (`lib/ratelimit.ts` 주석). MVP에서는 Firestore로 충분.
- Storage 룰은 전체 deny — 신규 미디어 경로는 모두 R2 presigned로 추가해야 함.
