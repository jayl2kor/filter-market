# moodit (filterMarket) — 전체 기능 카탈로그

> **버전**: 2026-05-10 기준 / **대상**: iOS 앱 + Firebase Cloud Functions 백엔드
> **목적**: 모든 화면, 버튼, 백엔드 기능을 한 문서에서 조감(鳥瞰)할 수 있도록 종합 정리.
>
> 본 문서는 다음 기존 문서들의 사실(事實) 레이어를 통합한 것입니다 — 세부 흐름이 필요하면 원본을 참조하세요.
> - 제품/요구사항: `PRD.md`
> - 시스템 구조: `ARCHITECTURE.md`, `SYSTEM_DESIGN.md`, `TECH_STACK.md`
> - 화면/액션: `NAVIGATION.md`, `SCREENS_PLAN.md`, `SCREEN_ACTIONS_QA_DEFINITION.md`
> - API: `API_SPEC.md`, `FIRESTORE_RULES.md`, `FMPKG_SCHEMA.md`
> - 도메인: `CURRENCY_DESIGN.md`, `REVIEWS_MIGRATION.md`, `PERMISSIONS_FLOW.md`
> - 진행 현황: `PHASE_ROADMAP_STATUS.md`, `BACKEND_WIRING_TODO.md`

---

## 0. 한눈에 보는 시스템 개요

### 제품 정체성
- **이름**: moodit (`com.jayl2kor.moodit`) — 서비스 코드네임 `filterMarket`
- **카테고리**: iOS 네이티브 사진 필터 마켓플레이스 (양면 시장: Maker ↔ Consumer)
- **MVP 플랫폼**: iOS 17+ / Swift 6.0 / SwiftUI / Metal
- **백엔드 (MVP)**: Firebase (Auth + Firestore + Cloud Functions v2 + FCM) + Cloudflare R2 (미디어)
- **결제**: Apple StoreKit2 (Coin 충전 + Pro 구독), 메이커 정산은 Phase 6 이후 Stripe Connect

### 모듈 의존 그래프
```
Sources/App  ← 화면 + 라우팅 + 스토어
   │
   ├─ Camera        : AVFoundation 캡처 세션, PhotoLibrary 저장
   ├─ FilterEngine  : Metal 라이브 프리뷰, LUT 샘플러, .fmpkg 빌더/검증, 정지 필터 렌더러
   ├─ Marketplace   : FilterRepository, ReviewStore, Social/Feed/Notification 저장소
   ├─ Models        : Filter / FilterManifest / Review / LightingTag 도메인 타입
   ├─ Storage       : FilterCache (in-memory actor)
   ├─ DesignSystem  : FMColors / FMTypography / Sp / FMButton 등 UI 토큰 + 컴포넌트
   └─ Auth          : AuthState 플레이스홀더 (Firebase Auth 어댑터 슬롯)

functions/src       ← Cloud Functions v2 (asia-northeast3)
   ├─ http/         : filters, identity, wallet, moderation 콜러블
   └─ triggers/     : Firestore onCreate/onUpdate/onDelete 카운터/통계
```

### 5탭 진입 구조 (RootShell)
| 탭 | 화면 | 진입점 |
|----|------|--------|
| 마켓 | `MarketplaceScreen` | 좌측 1번 |
| 검색 | `SearchScreen` | 좌측 2번 |
| **셔터** | `CameraScreen` (fullScreenCover) | 중앙 (탭이 아닌 모달) |
| 저장됨 | `SavedScreen` | 우측 4번 |
| 프로필 | `ProfileScreen` | 우측 5번 (미확인 알림 배지) |

---

## 1. 클라이언트 (iOS) — 화면 & 버튼 카탈로그

> 화면 카운트 기준: **약 68개**. 그룹별로 화면 → 주요 버튼 / 액션 → 사용 스토어 → Firebase 호출 순으로 정리.

### 1.1 RootShell · AppNavigation · DeepLink
- **RootShell**
  - 화면: 5탭 셸 + 상단 foreground push 배너(5초 자동 해제)
  - 버튼: 탭 전환, 프로필 미확인 배지, 푸시 배너 탭(딥링크) / 닫기
  - 스토어: `MooditStore`, `FilterLibraryStore`, `WalletStore`, `EditorDraftStore`, `SessionStore`, `CameraStateStore`
  - 부수효과: 알림 카운트 Firestore 리스너, Auth 상태 감시, 딥링크 큐(인증/온보딩 완료 후 디큐)
- **AppRoute (열거형)** — 모든 라우팅이 통과하는 단일 enum (login, search, filterDetail(id), filterDownload(id), otherProfileHandle(handle), wallet, paywallSingle(filterId), proSubscription, modQueue, reviewCompose(filterId), payoutOnboarding, dataExport, refundRequest(orderId) 등 50+ 케이스)
- **UniversalLinkParser** → URL → AppRoute, **PushRegistration.deepLinkHandler** → 푸시 페이로드 처리
- **UniversalLinkLandingScreen**: 공유 링크 진입 후 필터 다운로드 권유

### 1.2 로그인 & 온보딩
- **LoginScreen**: Apple / Google / 이메일 / "둘러보기"(게스트) — 약관·개인정보 SafariView 링크
- **EmailLoginScreen**: 이메일·비밀번호, 회원가입·재설정 링크
- **OnboardingScreen**: 4페이지 캐러셀(`@AppStorage hasOnboarded`), 다음 / 건너뛰기 / 완료
- 호출: `Auth.auth().signIn(with: GoogleAuthProvider.credential)`, `GIDSignIn.sharedInstance.signIn(...)`, 게스트 시 `setLocalAuthenticationFallback(true)`

### 1.3 카메라 & 사진
- **CameraScreen** (fullScreenCover): 라이브 프리뷰 + 셔터 / 플래시(on·off·auto) / 비율 / 타이머 / 필터 스트립
- **CapturePreviewScreen**: 촬영 직후 결과 — 재촬영 / 필터 변경 / 편집 / 삭제 / 저장 / 공유
- **CameraAspectPickerScreen**: 1:1, 4:5, 4:3, 16:9 (2열 그리드)
- **CameraTimerCountdownScreen**: OFF / 3s / 5s / 10s
- **PhotoImportScreen**: PhotoPicker, limited access 안내, 빈 상태
- **PhotoEditScreen**: 필터 스트립 + 강도 슬라이더, long-press = 원본 비교, Undo / Redo / 초기화 / 저장 / 공유
- 스토어: `CameraStateStore` (aspectRatio, timerOption, importedPhotoData), `FilterLibraryStore`, `EditorDraftStore`
- 백엔드: 없음 (전부 로컬). 저장은 `PhotoLibrarySaver.savePhoto()` (PHPhotoLibrary)

### 1.4 마켓플레이스 & 검색 & 필터 상세
- **MarketplaceScreen**: 검색 헤더 + 트렌딩 캐러셀 + 카테고리 칩 + 신규 그리드 + 큐레이션 + Pull-to-refresh
- **SearchScreen**: 3 단계(`browsing` → `typing` → `results`), 최근 검색어 (UserDefaults), 추천 해시태그 — 500ms 디바운스
- **FilterDetailLoaderScreen** → **FilterDetailScreen**: 커버 / 메이커 / 평점 / 다운로드수 / 태그 / 설명 / 다운로드·구매·리뷰·신고·공유·즐겨찾기·컬렉션 추가
- **FilterDownloadProgressScreen**: 진행 바 + 취소
- **FilterAfterDownloadScreen**: 카메라로 적용 / 즐겨찾기 / 컬렉션 추가
- **BuiltinFilterLibraryScreen**: 내장 필터 + 메이커 필터 관리(MyFilters) 진입
- 호출: `getFilterDetail`, `recordUse`, `toggleFilterLike`, `purchaseFilter`, `reportFilter`

### 1.5 프로필 & 소셜
- **ProfileScreen**: 헤더(아바타 / 닉네임 / bio) + 통계 3분할 + 팔로우 / 팔로워 / 팔로잉 + 세그먼트(내 필터·저장됨·촬영함) + 3열 그리드
- **EditProfileScreen**: 아바타(PhotoPicker → `profileAvatarUploadInit`), 닉네임, bio, 핸들 중복 검사
- **ProfileHandleResolverScreen**: `@handle` → uid 해석 → ProfileScreen 리다이렉트
- **CaptureDetailScreen**: 촬영본 전체 보기
- **ReviewsListScreen / ReviewComposeScreen / RatingFormScreen**: 별 5점 + 본문 ≤280자 + 사진(선택) + 메이커 답글 1회 (App Store 패턴)
- **FollowersListScreen / FollowingListScreen**: 사용자 행 + 팔로우 토글
- **ForYouFeedScreen / FollowingFeedScreen**: 추천 hero + 메이커 카드 + 그리드 / 피드에서 숨기기
- 호출: `setHandle`, `updateProfile`, `submitReview`, `deleteReview`, `markReviewHelpful`, `reportReview`, `reportUser`, follow/block 직접 Firestore 쓰기

### 1.6 메이커 & 필터 에디터 (필터 만들기 → 마켓 공유)
- **FilterEditorScreen** → **EditorParametersScreen** (노출·대비·채도·그레인·비네팅 슬라이더, long-press before/after) → **EditorLUTImportScreen** (DocumentPicker로 .cube) → **EditorDraftSaveScreen** (이름 입력 / 초안 저장 / 바로 공유)
- 업로드 플로우: **UploadCoverScreen**(커버 + Before/After 토글) → **UploadTagsCategoryScreen**(태그 + 카테고리 Picker) → **UploadTOSSubmitScreen**(약관 3종 동의 + 제출) → **UploadPendingReviewScreen**(검수 대기 안내)
- **MyFiltersScreen**: 상태 필터(pending/approved/rejected) + 정렬 + 행별 더보기(대시보드/비공개) + FAB(신규)
- **RemixFlowScreen**: 기존 필터 선택 → 에디터 오픈
- **MakerDashboardScreen**: 필터별 다운로드/평점/매출 + 기간 선택 + 출금 신청
- **PayoutOnboardingScreen / PayoutTaxInfoScreen / PayoutHistoryScreen**: Stripe Connect (외부 링크)
- 호출: `uploadInit` → R2 PUT → `uploadFinalize` → `submitForReview`, `recordUse`, 출금은 Phase 6

### 1.7 지갑 & 결제
- **WalletScreen**: 잔액(원/Coin) + 충전 + 거래내역 + Pro 시작
- **WalletTopupScreen**: 100/550/1200/3000 Coin IAP + 이전 구매 복원
- **WalletTransactionsScreen**: 거래 종류별 필터 (충전/구매/환불)
- **PaywallSingleScreen**: 단일 필터 구매 — 잔액 / 결제 후 잔액 표시, Pro 업그레이드 분기
- **ProSubscriptionScreen**: 월간/연간 토글 + 혜택 + 구독
- **ProStatusScreen**: 이미 Pro인 경우 — App Store 구독 관리 외부 링크
- **InsufficientBalanceScreen**: 충전 화면 / 지금 구매 / 취소
- **PaymentFailedScreen**: 다시 시도 / 복원 / 고객지원 메일
- **OrdersHistoryScreen** → **RefundRequestScreen**: 주문 ID + 사유 → `refundRequest`
- 호출: `creditCoinsFromIAP`, `proSubscriptionUpdate`, `purchaseFilter`, `refundRequest`, StoreKit2 `SKPaymentQueue`

### 1.8 알림 & 설정
- **NotificationsInboxScreen**: 카테고리 칩(모두/좋아요/댓글/다운로드/팔로우/시스템) + 그룹(새/오늘/이번 주/이전) + 행 variants(읽음/미읽음)
- **NotificationSettingsScreen**: iOS 설정 열기 + 카테고리별 토글 + 방해 금지 시간대
- **SettingsScreen**: 프로필 편집 / 로그아웃 / 데이터 내보내기 / 계정 삭제 / 약관·개인정보·라이선스 / 피드백 메일 / 버전
- **DataExportScreen**: 항목 체크박스 + JSON·CSV·HTML 포맷 → 이메일 전송 요청
- **HelpCenterScreen**: SafariView (`help.moodit.app`)
- **AccountDeletionScreen**: 핸들 재입력 확인 + 영구 삭제
- 호출: `requestDataExport`, `deleteAccount`, `updateNotificationPreferences`, FCM 토큰 등록은 `users/{uid}/devices`

### 1.9 모더레이션 (관리자/모더레이터 전용)
- **ModerationQueueScreen**: 상태 필터 + 큐 항목 리스트
- **ModerationDetailScreen**: 필터 상세 + 승인 / 거부(사유) / Takedown / 되돌리기
- **FilterRejectedScreen**: 메이커가 거절 통지 받는 화면 — 에디터에서 수정 / 이의 제기
- 호출: `approveFilter`, `rejectFilter`, `undoModerationDecision`

### 1.10 권한 (모달 8종)
| 권한 | 프라이밍 → 거부 |
|------|----------------|
| 카메라 | `CameraPermissionPriming` → `CameraPermissionDenied` |
| 사진 | `PhotosPermissionPriming` → `PhotosPermissionDenied` |
| 알림 | `NotificationsPermissionPriming` → `NotificationsPermissionDenied` |
| 위치 | `LocationPermissionPriming` → `LocationPermissionDenied` (향후) |

- 공통 버튼: 허용하기 / 건너뛰기 / 닫기 / 설정 열기(`UIApplication.openSettingsURLString`)
- 코디네이터: `PermissionCoordinator.currentStatus / currentStatusAsync`

### 1.11 컬렉션 / 즐겨찾기
- **FavoritesCollectionScreen**: "전체 즐겨찾기"(자동) + 사용자 컬렉션 2열 그리드(4-사진 모자이크 커버) + 새 컬렉션 만들기 bottom sheet(이름 + 비공개)
- 편집 모드(swipe-to-delete), Firestore listener: `/users/{uid}/collections`

### 1.12 텔레메트리
- `Telemetry.trackScreen`, `trackAction`, `trackFunnelStep`
- 백엔드: Firebase Analytics + Crashlytics

---

## 2. 클라이언트 모듈 — 공개 API 요약

### 2.1 Camera (`/Sources/Camera`)
- `CameraSession` — AVCaptureSession 래퍼, `onFrame` 콜백으로 CMSampleBuffer 스트림 → MetalPreviewRenderer
- `CameraPosition` (전/후), `CameraFocusPoint` (정규화 0~1), `CapturedPhoto`, `CameraSessionError`
- `PhotoLibrarySaver` — PHPhotoLibrary 추상화 (실제 구현 `live()` + 테스트 stub)

### 2.2 FilterEngine (`/Sources/FilterEngine`)
- **LUT**: `LUT3D`, `RGBColor`, `LUTSampler` (삼선형 보간), `FilterIntensity`, `LUTPreset` (identity/warm/cool/mono/vivid/soft)
- **렌더링**: `RenderFilter`, `FilterRenderConfiguration`, `PreviewFilter`, `PhotoFilterRenderer` (정지 사진 CPU), `MetalPreviewRenderer` (라이브 GPU 60fps), `MetalPreviewView`(MTKView 래퍼), `PreviewUniforms`
- **.fmpkg**: `FmpkgManifest`, `FmpkgBuilder` (.cube + SHA256), `FmpkgVerifier` (manifest/LUT/checksum 검증)
- **패키지 라이프사이클**: `FilterPackage`, `FilterPackageFetcher`(URLSession), `FilterPackageCache` (DiskFilterPackageCache, LRU 100MB), `FilterPackageCoordinator` (cache → fetch → insert)
- **유틸**: `CubeLUTParser/Writer`, `LUTTextureFactory`, `LUTImageDecoder`, `LUTResourceResolver`, `LUTBake` (파라미터 → LUT 베이킹)
- **셰이더**: `ShaderSources.basicYUV` (YUV 420p → RGB + LUT lookup)

### 2.3 DesignSystem (`/Sources/DesignSystem`)
- 색상 토큰: `FMColors.{Background, Surface, Border, Text, Accent, Semantic, Category, Skeleton, Overlay, Empty}` (Light/Dark)
- 타이포: `FMTypography.Style.{display, titleLarge, title, headline, body, callout, subhead, footnote, caption}`
- 스페이싱: `Sp.xxs(4) ~ Sp.xxxxl(64)`, `R.md`, `FMLayout.{screenPadding, tabBarHeight, topBarHeight, minTapTarget(44)}`, `Opacity`
- 컴포넌트: `FMButton`(primary/secondary/ghost/destructive × sm/md/lg), `FMCard`, `FMFilterTile`, `FMSlider`, `FMSegmentedControl`, `FMToggle`, `FMTextField`, `FMToast`, `FMAlert`, `FMBottomSheet`, `FMConfirmationDialog`, `FMAvatar`, `FMRemoteImage`, `FMTag`, `FMEmptyState`, `FMSkeleton`, `FMTabBar`, `FMHapticEngine`
- 출처: `docs/DESIGN_TOKENS.json` v1.2.0과 정합

### 2.4 Marketplace (`/Sources/Marketplace`)
- `FilterRepository` (프로토콜 + `MockFilterRepository`) — `listFilters`, `filter(id)`, 확장 `trending`, `newFilters`, `search`
- `FilterPackage`, `FilterPackageUploader` (Cloud Functions 후크)
- `ReviewStore` (actor) — App Store 정책 (1 review/user/filter, 1 makerReply/review)
- 모델: `Review`, `ReviewDraft`, `MakerReply`, `LightingTag`, `ReviewLimits` (stars 1~5, body ≤280, makerReply ≤200)
- 소셜 도메인: `FollowEdge`, `BlockEdge`, `AppNotification`, `FeedItem` + 저장소 프로토콜 (in-memory 구현 제공)

### 2.5 Models (`/Sources/Models`)
- `Filter` (id, title, version, author, category, engine, marketplace metadata, status, priceCoins, ratingAvg, downloadCount, tags)
- `FilterStatus` enum: `uploading`, `pendingReviewPre`, `pendingReview`, `approved`, `rejected`
- `FilterCategory`: cinematic, vintage, pastel, bw, portrait, food, travel, anime, mood, bright, moody, skin
- `FilterEngineType`: `lutParams`, `lutMSL`, `nodeGraph`
- `FilterParameter` (key, label, type[float/color/bool], min/max/default)
- `FilterManifest` (.fmpkg 내장 — schemaVersion, id, version, title, author, engine, parameters, createdAt, checksum)
- `FilterLicense`: CC0, CC-BY, CC-BY-SA, CC-BY-NC, All-Rights-Reserved, Commercial

### 2.6 Storage (`/Sources/Storage`)
- `FilterCache` (actor) — in-memory `filter(id)` / `store(_:)`, FilterRepository 결과 캐싱

### 2.7 Auth (`/Sources/Auth`)
- `AuthState` enum: guest / authenticated(uid) — Firebase Auth 어댑터 슬롯 (현재 플레이스홀더)

---

## 3. 백엔드 (Cloud Functions v2 · `asia-northeast3`)

### 3.1 필터 라이프사이클 (`functions/src/http/filters.ts`)
| 함수 | 인증 | 입력 | 효과 |
|------|------|------|------|
| `uploadInit` | ✅ | name, category, tags?, packageBytes, contentSha256?, signatureSampleURL? | filter ID 예약 + R2 presigned PUT URL 발급, 상태=`uploading` |
| `uploadFinalize` | ✅ | filterId | R2 객체 존재/크기 검증 → 상태 `pending_review_pre` |
| `submitForReview` | ✅ | filterId, tos {Original, Policy, Commercial} | 약관 수락 → 상태 `pending_review` |
| `recordUse` | ✅ | filterId | (uid,filterId) 1시간 쿨다운 멱등 useCount 증가 |
| `getFilterDetail` | ✅ | filterId | 상세 + presigned 다운로드 URL (유료 시 entitlement/Pro 검증) |
| `toggleFilterLike` | ✅ | filterId, liked | `/filters/{id}/likes/{uid}` 생성/삭제 |
| `reportFilter` | ✅ | filterId, reasonCode, detail? | rate limit 30/h, report 문서 + reportCount 증가 |

### 3.2 리뷰 & 샘플 (`functions/src/http/filters.ts`)
| 함수 | 효과 |
|------|------|
| `reviewImageUploadInit` | R2 presigned URL: `reviews/{filterId}/{uid}/{ts}-{uuid}.{ext}` |
| `submitReview` | entitlement 검증, 1 user/filter — 본인 필터 리뷰 차단 |
| `listReviews` (비인증) | helpfulCount 정렬 + 커서 페이징 |
| `deleteReview` | 본인만 |
| `markReviewHelpful` | 본인 리뷰 제외, ±1 토글 |
| `sampleImageUploadInit` | entitlement 검증 + R2 presigned URL: `samples/{filterId}/{uid}/...` |
| `addUserSample` | objectKey 일치 확인 후 sample 문서 생성 |
| `listSamples` (비인증) | featured 우선 + 페이징 |
| `removeSample` | 소유자 또는 메이커 |

### 3.3 모더레이션 (`functions/src/http/moderation.ts`)
| 함수 | 권한 | 효과 |
|------|------|------|
| `approveFilter` | mod/admin | 상태 → `approved`, `publishedAt` |
| `rejectFilter` | mod/admin | 상태 → `rejected` + reason |
| `undoModerationDecision` | mod/admin | 상태 → `pending_review` |
| `reportReview` | 인증 | 30/h, review 신고 |
| `reportUser` | 인증 | 자기 자신 차단, 30/h |

### 3.4 신원 (`functions/src/http/identity.ts`)
| 함수 | 효과 |
|------|------|
| `setHandle` | 정규식 `[a-z0-9_.]{3,30}`, 예약어 차단(admin/moderator/moodit/support…), 트랜잭션 |
| `updateProfile` | displayName, bio, website, makerPageVisible, photoSharingAllowed, avatarVariant, avatarURL/photoURL, avatarObjectKey |
| `profileAvatarUploadInit` | R2 presigned: `users/{uid}/avatar/...` |
| `deleteAccount` | GDPR/5.1.1(v) — 공개 필드 초기화 + `deletedAt`, Auth 사용자 삭제 시도 |
| `setRole` | admin only — Auth custom claim `role` 부여 |

### 3.5 지갑 (`functions/src/http/wallet.ts`)
| 함수 | 효과 |
|------|------|
| `purchaseFilter` | 잔액 차감 + entitlement + ledger, 멱등(이미 보유 시 `alreadyOwned`), 30/min |
| `creditCoinsFromIAP` | Apple JWS 검증, originalTransactionId 중복 방지, 패키지 100/550/1200/3000, 10/min |
| `proSubscriptionUpdate` | 월/연 구독 JWS → `/proReceipts/{otxId}` + `/users/{uid}/proStatus/status` |
| `refundRequest` | walletLedger 항목(purchase/topup) 기반, 5/h |

### 3.6 Firestore Triggers (`functions/src/triggers/index.ts`)
| 트리거 | 처리 |
|--------|------|
| `onFilterPublished` | TODO — filterCount/FCM/검색 인덱싱 |
| `onReportCreated` | TODO — 임계값 도달 시 자동 검토 플래그 |
| `onFollowCreated/Deleted` | followerCount/followingCount ±1 |
| `onReviewCreated/Updated/Deleted` | filter.reviewCount, ratingAvg 재계산 |
| `onSampleCreated/Deleted` | filter.sampleCount ±1 |
| `onFilterLikeCreated/Deleted` | filter.likeCount ±1 |

---

## 4. Firestore 컬렉션 스키마 (요약)

| 컬렉션 | 핵심 필드 | 비고 |
|--------|-----------|------|
| `filters/{id}` | authorUid, title, category, tags, status, version, packageBytes, objectKey, contentSha256, signatureSampleURL, priceCoins, useCount, downloadCount, likeCount, reviewCount, ratingAvg, sampleCount, createdAt, publishedAt, rejectionReason | uploading→pending_review_pre→pending_review→approved/rejected |
| `filters/{id}/reviews/{authorUid}` | stars, body, photoUrl, isVerifiedDownload, helpfulCount, makerReply, status, createdAt | 문서 ID = authorUid (uniqueness) |
| `filters/{id}/samples/{sampleId}` | kind, authorUid, categoryHint, coverURL, thumbnailURL, objectKey, featured, status |  |
| `filters/{id}/likes/{uid}` | createdAt | 좋아요 에지 |
| `filters/{id}/uses/{uid}` | lastUseAt | 쿨다운 |
| `filters/{id}/reports/{reportId}` | reporterUid, reasonCode, detail | reportCount 트리거 |
| `users/{uid}` | handle, displayName, bio, website, avatarURL, photoURL, avatarVariant, isMaker, filterCount, followerCount, followingCount, makerPageVisible, photoSharingAllowed, deletedAt | soft delete 지원 |
| `users/{uid}/savedFilters/{filterId}` | filterId | 저장 + entitlement 증명 |
| `users/{uid}/entitlements/{filterId}` | grantedAt, pricePaid | 구매 권한 |
| `users/{uid}/proStatus/status` | active, productId, expiresAt, revokedAt |  |
| `users/{uid}/wallet/balance` | value, updatedAt | 코인 잔액 |
| `users/{uid}/walletLedger/{txId}` | kind(purchase/topup/refund), amount, relatedFilterId, createdAt | 거래 로그 |
| `users/{uid}/refundRequests/{orderId}` | reason, ledgerKind, status |  |
| `users/{uid}/reviewHelpful/{edgeId}` | filterId, reviewId | 유용함 표시 |
| `users/{uid}/devices/{deviceId}` | fcmToken, platform, deviceId | FCM 등록 |
| `users/{uid}/notifications/{nId}` | type, message, readAt | 서버 전용 쓰기 |
| `walletReceipts/{originalTransactionId}` | uid, productId, amount | IAP 중복 방지 |
| `proReceipts/{originalTransactionId}` | uid, productId, active, expiresDate, revocationDate |  |
| `handles/{handle}` | uid, claimedAt | 핸들 소유권 |
| `follows/{actorUid_targetUid}` | actorUid, targetUid, createdAt |  |
| `blocks/{actorUid_targetUid}` | actorUid, targetUid, createdAt |  |
| `_ratelimit/{bucket}/keys/{key}` | count, windowStart | 슬라이딩 윈도우 |
| `config/...` | 동적 | 서버 설정 |

### 4.1 보안 규칙 요지 (`firestore.rules`)
- 읽기: 필터/리뷰/샘플/좋아요는 공개; 사용자 문서·지갑·entitlement·ledger는 소유자 한정; 팔로우는 인증 사용자, 차단은 actor 한정
- 쓰기: 필터/리뷰 makerReply/샘플/지갑/ledger/entitlement는 **Cloud Functions 전용**; 팔로우/차단/savedFilters/likes/리뷰 본문은 본인만; helpfulCount는 ±1 검증
- Storage 규칙 (`storage.rules`): **모두 차단** — 미디어는 R2로만

### 4.2 인덱스 (`firestore.indexes.json`)
- `filters: status↑ × useCount↓` (인기)
- `filters: status↑ × createdAt↓` (최신)
- `filters: authorUid↑ × createdAt↓` (메이커 화면)
- `filters: status↑ × category↑ × createdAt↓` (카테고리 + 최신)

---

## 5. 결제 / 코인 / Pro 정책

### 5.1 IAP 상품 (App Store Connect)
- 코인: `com.jayl2kor.moodit.coins.{100, 550, 1200, 3000}`
- Pro: `com.jayl2kor.moodit.pro.{monthly, yearly}`

### 5.2 가격
- 코인 ↔ 원 환율: **1 Coin ≈ ₩14**
- 필터 가격(코인): `[0, 30, 50, 80, 120]` (0 = 무료)
- 메이커 분배: 60% (Phase 6)
- 환불: 7일 정책 (`refundRequest`)

### 5.3 Rate Limit Bucket
| Bucket | 한도 | 윈도우 |
|--------|------|--------|
| default | 60 | 60s |
| filters.upload | 10 | 3600s |
| filters.use | 600 | 3600s |
| filters.report | 30 | 3600s |
| identity.handle | 5 | 86400s |
| wallet.purchase | 30 | 60s |
| wallet.iap | 10 | 60s |
| wallet.refund | 5 | 3600s |

### 5.4 핸들 규칙
- 정규식: `[a-z0-9_.]{3,30}`
- 예약어: admin, moderator, moodit, support, help, official, system, root, user, guest, anonymous, null, undefined

### 5.5 미디어 사이즈 제한
- 필터 패키지 5MB, 리뷰 이미지 2.5MB, 샘플 4MB, 아바타 1.5MB

### 5.6 사용 쿨다운
- `recordUse`: 60분 (`RECORD_USE_COOLDOWN_MS = 3600000`)

---

## 6. 외부 통합 / 시크릿

### Firebase Secrets (모두 `asia-northeast3`)
```
R2_ENDPOINT          = https://<accountId>.r2.cloudflarestorage.com
R2_ACCESS_KEY_ID     = (secret)
R2_SECRET_ACCESS_KEY = (secret)
R2_BUCKET            = moodit-filters
R2_PUBLIC_BASE_URL   = (CDN)
APP_APPLE_ID         = <numeric>
APP_STORE_ENV        = PRODUCTION | SANDBOX
```

### 라이브러리
- `firebase-admin@12`, `firebase-functions@6` — 서버
- `zod@3` — 입력 검증
- `@apple/app-store-server-library@3` — JWS 검증
- `@aws-sdk/client-s3@3`, `@aws-sdk/s3-request-presigner@3` — R2
- (사용 보류) `ioredis@5` — Rate limit 외부화

### 클라이언트 SDK
- `firebase-ios-sdk` 11+ (Auth, Firestore, Functions, Messaging, Analytics, Crashlytics)
- `GoogleSignIn-iOS` 8+

---

## 7. 빌드 & 테스트 명령어

### iOS
```bash
xcodegen generate                     # project.yml → moodit.xcodeproj
./scripts/build.sh                    # 빌드 (DerivedData=.build/DerivedData)
./scripts/test.sh                     # XCTest (iPhone 17 / iOS 26.3.1 기본)
./scripts/metal-toolchain.sh          # Metal 셰이더 툴체인
```

### Functions
```bash
cd functions
npm run build                         # tsc
npm run lint
npm run serve                         # firebase emulators (auth/functions/firestore)
npm run test                          # node --test (recordUse, wallet, moderation, identity, …)
npm run test:rules                    # firestore-rules.test.mjs (emulator)
npm run deploy:staging                # firebase use staging && deploy
npm run deploy:prod
```

### Functions 테스트 커버리지
- `recordUse.test.mjs` — 쿨다운 멱등성
- `getFilterDetail.test.mjs` — presigned URL + entitlement
- `wallet.test.mjs` — 구매 / 코인 크레딧
- `moderation.test.mjs` — approve/reject/undo
- `identity.test.mjs` — handle/profile
- `submitForReview.test.mjs` — 약관 흐름
- `appleReceiptVerifier.test.mjs` — JWS 검증
- `idempotency.test.mjs` — 일관성
- `firestore-rules.test.mjs` — 규칙 emulator

---

## 8. 진행 현황 (2026-05-09 스냅샷, `PHASE_ROADMAP_STATUS.md` 기준)

- **빌드**: ✅ BUILD SUCCEEDED (iOS Simulator)
- **테스트**: ✅ 162 unit + 26 AppUI 통과
- **화면**: 67개 중 ~50개 SwiftUI 구현, 나머지는 skeleton/placeholder
- **Cloud Functions**: 11개 callable + 9개 트리거 (일부 트리거 TODO)
- **남은 미연결 작업**: `BACKEND_WIRING_TODO.md`에 mock 제거 + 15개 skeleton 화면 wiring 정리 중

---

## 9. 더 깊이 보고 싶을 때 (원본 참조 인덱스)

| 알고 싶은 것 | 보러갈 곳 |
|--------------|-----------|
| 제품 비전, 페르소나, KPI | `docs/PRD.md` |
| C4 다이어그램, Phase 4 백엔드 전환 | `docs/ARCHITECTURE.md` |
| Metal 4-pass 셰이더 파이프라인 | `docs/SYSTEM_DESIGN.md` |
| 모든 화면의 Action ID, 라우팅 | `docs/NAVIGATION.md` + `docs/SCREEN_ACTIONS_QA_DEFINITION.md` |
| 콜러블 함수 시그니처/에러코드 | `docs/API_SPEC.md` |
| 보안 규칙 시나리오 | `docs/FIRESTORE_RULES.md` |
| .fmpkg 매니페스트 JSON Schema | `docs/FMPKG_SCHEMA.md` |
| 결제/환불/Pro 정책 | `docs/CURRENCY_DESIGN.md` |
| 댓글→리뷰 마이그레이션 의사결정 | `docs/REVIEWS_MIGRATION.md` |
| 권한 프라이밍/거부 흐름 | `docs/PERMISSIONS_FLOW.md` |
| 모달/토스트/시트 패턴 | `docs/MODAL_PATTERNS.md` |
| 빈 상태 카탈로그 | `docs/EMPTY_STATES.md` |
| 메이커 셰이더 보안 | `docs/MSL_SECURITY.md` |

---

> 변경 이력: 2026-05-10 초안 (자동 카탈로그) — 화면 정의 / Cloud Functions 시그니처 / Firestore 스키마 변경 시 동기화 필요.
