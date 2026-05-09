# moodit - Feature Inventory

> 마지막 정리: 2026-05-10 KST  
> 기준 코드: `Sources/App`, `Sources/Marketplace`, `functions/src`, `firestore.rules`, `storage.rules`  
> 목적: 현재 프로젝트에 구현된 화면, 주요 버튼/액션, 백엔드 연결 지점을 한 문서에서 확인한다.

---

## 1. 읽는 법

이 문서는 기능 단위 인벤토리다. 버튼의 stable action ID와 화면 간 상세 이동 규칙은 [NAVIGATION.md](./NAVIGATION.md)가 canonical이다. 실제 SwiftUI 라우트는 [AppNavigation.swift](../Sources/App/AppNavigation.swift)에 있고, 백엔드 callable export 목록은 [functions/src/index.ts](../functions/src/index.ts)에 있다.

상태 표기:

| 상태 | 의미 |
|---|---|
| Implemented | 실제 SwiftUI 화면 또는 Cloud Function/Firestore 연동이 있다. |
| Partial | UI 또는 로컬 상태는 있으나 업로드/외부 서비스/운영 자동화 일부가 남아 있다. |
| Mock/In-memory | 화면 동작은 가능하지만 영속 저장소가 mock, fixture, in-memory 중심이다. |
| Planned | 라우트/문서/목업은 있으나 프로덕션 연결은 후속 작업이다. |

---

## 2. 앱 구조 요약

| 영역 | 구현 위치 | 핵심 역할 |
|---|---|---|
| 앱 엔트리 | [MooditApp.swift](../Sources/App/MooditApp.swift), [RootShell.swift](../Sources/App/RootShell.swift) | Firebase 초기화, 온보딩/로그인 분기, 탭 shell, 딥링크/푸시 route 처리 |
| 라우팅 | [AppNavigation.swift](../Sources/App/AppNavigation.swift) | `AppRoute` 전체 화면 registry, 인증 필요 여부, 화면별 대표 액션 메타데이터 |
| 전역 상태 | [MooditStore.swift](../Sources/App/MooditStore.swift) | 세션, 지갑, 필터 라이브러리, 에디터 초안, 카메라 상태를 묶는 app store |
| 디자인 시스템 | [Sources/DesignSystem](../Sources/DesignSystem) | 버튼, 카드, 토큰, 빈 상태, toast, tab bar, modal |
| 카메라/렌더링 | [Sources/Camera](../Sources/Camera), [Sources/FilterEngine](../Sources/FilterEngine) | AVCapture, Metal preview, LUT/파라미터 필터, 촬영 이미지 저장 |
| 마켓/도메인 | [Sources/Marketplace](../Sources/Marketplace), [Sources/Models](../Sources/Models) | 필터 모델, seed repository, 패키지 업로드 helper, 리뷰/소셜 repository protocol |
| 백엔드 | [functions/src](../functions/src) | Firebase Functions callable, Firestore trigger, R2 presigned URL, StoreKit receipt 검증 |

---

## 3. 전역 플로우

| 기능 | 화면/버튼 | 구현/백엔드 |
|---|---|---|
| 첫 실행/온보딩 | 온보딩 완료 버튼, 로그인 이동 | `OnboardingScreen`, `MooditApp` 상태 분기 |
| 인증 | Apple 로그인, Google 로그인, 이메일 로그인, 게스트 둘러보기 | Firebase Auth 기반. 프로필 저장은 `updateProfile`, 핸들은 `setHandle` callable |
| 탭 shell | Market, Search/Feed, Camera shutter, Saved, Profile | `RootShell`, `FMTabBar`. 셔터는 탭 선택이 아니라 `CameraScreen` full-screen cover |
| 인증 가드 | 비로그인 사용자가 인증 필요 route 진입 시 Login | `AppRoute.requiresAuthentication`, Root navigation handling |
| 딥링크 | 필터 상세, 프로필, 검색, 저장됨 등으로 route 변환 | `UniversalLinkParser`, `DeepLinkDestination`, `UniversalLinkLandingScreen` |
| 푸시/알림 badge | 알림 탭, foreground banner, badge count | `PushRegistration`, `NotificationsInboxStore`, `users/{uid}/notifications` listener |
| 권한 안내 | 카메라/사진/위치/알림 priming, denied 화면 | `Sources/App/Permissions`, iOS 설정 열기 버튼 |

---

## 4. 화면/버튼 인벤토리

### 4.1 Auth / Onboarding

| 화면 | 주요 버튼/컨트롤 | 데이터/백엔드 | 상태 |
|---|---|---|---|
| Onboarding | 시작/다음, 건너뛰기 | 로컬 첫 실행 상태 | Implemented |
| Login | Apple 로그인, Google 로그인, 이메일로 계속, 게스트 둘러보기, 약관/개인정보 링크 | Firebase Auth 진입점, 외부 URL sheet | Partial |
| Email Login | 이메일, 비밀번호, 로그인/가입 submit | Firebase Auth 이메일 플로우용 UI | Partial |

### 4.2 Marketplace / Filter

| 화면 | 주요 버튼/컨트롤 | 데이터/백엔드 | 상태 |
|---|---|---|---|
| Marketplace Home | 검색, 지갑, 알림, 필터 tile, 카테고리/컬렉션, 다시 시도 | `FirestoreFilterRepository.listFilters/trending/newFilters`, fallback seed repository | Implemented |
| Search | 검색어 입력, 카테고리 필터, For You 이동, 필터 tile, 메이커 tile | Firestore `filters` client-side search | Implemented |
| Filter Detail Loader | 상세 로딩, 다시 시도 | `getFilterDetail` callable | Implemented |
| Filter Detail | 다운로드/구매, 좋아요, 리뷰 보기, 샘플 추가, 공유, 신고, 메이커 프로필 | `getFilterDetail`, `toggleFilterLike`, `sampleImageUploadInit`, `addUserSample` | Implemented |
| Filter Download Progress | 취소/상세로 돌아가기, 다운로드 다시 시도, 완료 후 적용 | `users/{uid}/savedFilters` write, local download state | Implemented |
| Filter After Download | 카메라로 적용, 즐겨찾기, 컬렉션 추가, 다운로드 제거 | `savedFilters`, `favorites`, camera full-screen cover | Implemented |
| Saved Filters | 편집/완료, 기본 필터, 상세 이동, 저장 삭제 | `users/{uid}/savedFilters`, `users/{uid}/favorites` | Implemented |
| Builtin Filter Library | 기본 필터 적용, Pro locked sheet, 내 필터 이동 | bundle seed filters + Pro 상태 | Implemented |
| Favorites Collection | 편집, 삭제, 새 컬렉션 만들기, 만들기 submit | `users/{uid}/collections` listener/write/delete | Implemented |
| Universal Link Landing | 마켓으로 이동, 검색, 다운로드/상세 진입 | deep link route bridge | Implemented |
| Filter Unavailable | 빈 상태 | invalid UUID/detail fallback | Implemented |

### 4.3 Camera / Photo

| 화면 | 주요 버튼/컨트롤 | 데이터/백엔드 | 상태 |
|---|---|---|---|
| Camera Live | 닫기, 전후면 전환, 셔터, 라이브러리, 비율, 타이머, grid, flash, zoom, 필터 선택, intensity | `CameraSession`, `MetalPreviewRenderer`, `CameraStateStore`, `recordUse` 후보 | Partial |
| Capture Preview | 닫기, 더보기, 재촬영, 필터 변경, 편집, 삭제, 저장, 공유, 사진 정보, 메타데이터 복사 | `PhotoLibrarySaver`, share sheet, local capture result | Implemented |
| Camera Aspect Picker | 1:1, 4:5, 4:3, 16:9 선택 | `CameraStateStore.aspectRatio` | Implemented |
| Camera Timer Countdown | OFF/3/5/10초, 카운트다운 취소 | `CameraStateStore.timerOption` | Implemented |
| Photo Import | 사진 선택, 필터 적용, 닫기 | `PhotoPicker`, imported image data | Implemented |
| Photo Edit | undo/redo/reset, 원본 비교, 필터 변경, 강도 slider, 저장, 공유 | `PhotoFilterRenderer`, `PhotoLibrarySaver`, `ShareSheet` | Implemented |
| Capture Detail | 촬영 상세 보기 | `users/{uid}/captures` read/write path | Partial |

### 4.4 Maker / Upload

| 화면 | 주요 버튼/컨트롤 | 데이터/백엔드 | 상태 |
|---|---|---|---|
| Filter Editor | 임시 저장, 버리기, 파라미터 편집, LUT, 초안 저장, 마켓 공유로 계속 | `EditorDraftStore`, local/Firestore editor draft persistence | Implemented |
| Editor Parameters | 노출/대비/채도/그레인/비네트 slider, before 비교, 계속 | `MakerFilterDraft.parameterValues` | Implemented |
| Editor LUT Import | Files에서 LUT 가져오기, 교체, 초안 저장 단계 | `DocumentPicker`, `CubeLUTParser`, `LUT3D` | Implemented |
| Editor Draft Save | 초안 저장 후 내 필터, 바로 마켓 공유 | `users/{uid}/makerDrafts`, local disk draft | Implemented |
| Upload Cover | 커버 추가/지우기, 자동 before/after 토글, 다음, 취소 dialog | `MakerFilterDraft.coverCount` | Partial |
| Upload Tags Category | 태그 추가/삭제, 카테고리 선택, 다음, 취소 dialog | `MakerFilterDraft.tags/category` | Implemented |
| Upload TOS Submit | 원본/정책/상업 이용 약관 toggle, 검수 제출 | `submitForReview` callable only when `firestoreFilterId` exists | Partial |
| Upload Pending Review | 내 필터 보기, 닫기 | maker draft status `pending` | Implemented |
| My Filters | 상태 필터, 새 필터 만들기, 수정/검수 결과, 통계 보기, 비공개 전환 | `users/{uid}/makerDrafts`; 비공개는 draft status 변경 | Partial |
| Maker Dashboard | 기간 변경, 필터 상세, 출금 신청 | UI/data projection 중심 | Planned |
| Remix Flow | 에디터 열기, 취소 | editor draft entry flow | Mock/In-memory |

현재 업로드 백엔드는 `uploadInit`과 `uploadFinalize`가 구현되어 있으나, SwiftUI upload flow에서 `.fmpkg` 생성 및 R2 업로드까지 완전히 연결된 상태는 아니다.

### 4.5 Social / Reviews / Feed

| 화면 | 주요 버튼/컨트롤 | 데이터/백엔드 | 상태 |
|---|---|---|---|
| Reviews List | 리뷰 작성, 평점 등록, 작성자 프로필, 더보기, 수정, 삭제, 답글, 신고, 차단, 도움이 됨 | `filters/{id}/reviews` listener, `markReviewHelpful`, `deleteReview`, `reportReview`, `blocks` | Implemented |
| Review Compose | 취소, 게시/저장, 사진 첨부, 메이커 답글 | `reviewImageUploadInit`, `submitReview` | Implemented |
| Rating Form | 별점 선택, 건너뛰기, 평점 등록 | direct `filters/{id}/ratings/{uid}` write | Implemented |
| Followers List | 사용자 프로필, 팔로우 토글 | `follows/{actor}_{target}`, user profile reads | Implemented |
| Following List | 사용자 프로필, 팔로잉 토글 | `follows` query/write | Implemented |
| For You Feed | 추천 필터 열기, 저장, 메이커 프로필, 팔로우 | Firestore `filters` + mock/recommendation projection | Partial |
| Following Feed | 필터 열기, 팔로잉 목록, 피드 옵션, 숨기기, ID 복사 | `follows`, `users/{uid}/feedActions`, `filters` query | Implemented |
| Report Form | 대상 확인, 사유 선택, 상세 입력, 제출 | `reportFilter`, `reportReview`, `reportUser` | Implemented |
| Block List | 차단/뮤트 탭, 차단 해제, 다시 시도 | `blocks` listener/delete | Implemented |

### 4.6 Profile / Settings / Privacy

| 화면 | 주요 버튼/컨트롤 | 데이터/백엔드 | 상태 |
|---|---|---|---|
| Profile | 프로필 편집, 설정, 팔로워/팔로잉, 필터/저장/촬영 grid, 팔로우/차단(타인) | `ProfileSelfStore`, `users`, `filters`, `savedFilters`, `captures`, `follows`, `blocks` | Implemented |
| Other Profile Resolver | handle -> uid 변환 | `handles/{handle}` read | Implemented |
| Edit Profile | 사진 변경, handle 중복 확인, 저장 | `profileAvatarUploadInit`, R2 PUT, `updateProfile`, `setHandle`, `handles` read | Implemented |
| Account Deletion | 유저네임 확인 입력, 계정 영구 삭제, 취소 | `deleteAccount` callable soft delete + Auth delete | Implemented |
| Settings | 프로필 편집, 알림, 차단 목록, 데이터 내보내기, 계정 삭제, 도움말, 외부 정책 링크 | route hub + 외부 URL | Implemented |
| Data Export | 내보낼 데이터 toggle, JSON/CSV/HTML 선택, 데이터 사본 요청, 다운로드 | `users/{uid}/exportRequests` write/listener | Implemented |
| Help Center | 환불 요청, 문의 메일, 약관/개인정보/도움말 링크 | route + Safari/mail URL | Implemented |

### 4.7 Notifications

| 화면 | 주요 버튼/컨트롤 | 데이터/백엔드 | 상태 |
|---|---|---|---|
| Notifications Inbox | 알림 설정, 필터 알림 열기, 팔로우 액션, 이전 알림 더 보기, 읽음 처리 | `users/{uid}/notifications` listener/page load/batch update, `follows` write | Implemented |
| Notification Settings | iOS 설정 열기, 카테고리별 toggle, 방해 금지 toggle | `users/{uid}/notificationPreferences/main` debounced write/listener | Implemented |

### 4.8 Wallet / StoreKit / Payments

| 화면 | 주요 버튼/컨트롤 | 데이터/백엔드 | 상태 |
|---|---|---|---|
| Paywall Single | Coin으로 구매, Pro 멤버십 보기 | `purchaseFilter` callable | Implemented |
| Pro Subscription | 월간/연간 전환, 월간 Pro 시작, 연간 Pro 시작, 영수증/환불 | StoreKit 2, `proSubscriptionUpdate` | Implemented |
| Pro Status | App Store 구독 관리, 영수증/환불 안내 | `users/{uid}/proStatus/status`, external subscriptions URL | Implemented |
| Orders History | 거래 내역, 환불 요청, 주문 row | `walletLedger` projection | Partial |
| Wallet | 충전하기, 거래내역, Pro 시작 | `users/{uid}/wallet/balance`, `proStatus` listener | Implemented |
| Wallet Topup | 100/550/1200/3000C 충전, 구매 복원, 결제 실패 화면 | StoreKit 2, `creditCoinsFromIAP` | Implemented |
| Wallet Transactions | 거래 유형 필터, 주문 내역, 환불 요청 | `users/{uid}/walletLedger` listener | Implemented |
| Insufficient Balance | 지금 구매하기, 충전 화면으로, 취소 | `purchaseFilter`, wallet topup route | Implemented |
| Payment Failed | 다시 시도, 이전 구매 복원, 고객지원 | StoreKit restore, mail URL | Implemented |
| Refund Request | 주문 ID 입력, 환불 사유 입력, 제출 | `refundRequest` callable | Implemented |
| Payout Onboarding | Stripe Connect 열기 | closed-loop coin 정책상 앱 진입점은 노출하지 않음 | Planned |
| Payout Tax Info | 세금 정보 저장 | route placeholder | Planned |
| Payout History | 정산 상세 | route placeholder | Planned |
| Earnings Withdraw | 은행 변경, 빠른 금액, 출금 신청 | route placeholder | Planned |

### 4.9 Moderation

| 화면 | 주요 버튼/컨트롤 | 데이터/백엔드 | 상태 |
|---|---|---|---|
| Moderation Queue | 큐 필터, 검수 항목 열기 | Firestore `filters` where pending status | Implemented |
| Moderation Detail | 승인, 거부 사유, 거부, 되돌리기, takedown | `approveFilter`, `rejectFilter`, `undoModerationDecision`; takedown UI는 후속 | Partial |
| Filter Rejected | 검수 결과 확인, 에디터에서 수정, 고객센터 문의, 필터 삭제, 계속 보기, 이의 제기 | rejected draft/detail route + external appeal/mail | Partial |

---

## 5. 주요 클라이언트 저장소/서비스

| 컴포넌트 | 기능 | 영속 저장소 |
|---|---|---|
| `SessionStore` | 인증 상태, 프로필, 알림 설정, 데이터 내보내기, 계정 삭제 | Firebase Auth, `users`, `handles`, `notificationPreferences`, `exportRequests`, profile avatar R2 |
| `FilterLibraryStore` | 필터 목록, 선택 필터, 다운로드/즐겨찾기, 마켓 재시도 | `filters`, `savedFilters`, `favorites` |
| `WalletStore` | 코인 잔액, Pro 상태, 결제 오류 | `users/{uid}/wallet/balance`, `users/{uid}/proStatus/status` |
| `WalletLedgerStore` | 지갑 거래 내역 | `users/{uid}/walletLedger` |
| `EditorDraftStore` | 에디터 초안, LUT, 업로드 단계, 내 필터 | local disk, `editorDrafts/current`, `makerDrafts`, `submitForReview` |
| `NotificationsInboxStore` | 알림 목록, 더 보기, 읽음 처리 | `users/{uid}/notifications` |
| `ProfileSelfStore` | 본인 프로필 요약, 내 필터/저장/촬영 grid | `users`, `filters`, `savedFilters`, `captures` |
| `StoreKitManager` | 상품 로드, 구매, 복원, transaction listener | StoreKit 2, `creditCoinsFromIAP`, `proSubscriptionUpdate` |
| `PushRegistration` | APNs token 등록/삭제 | `users/{uid}/devices` |
| `CameraStateStore` | 카메라 비율/타이머/grid/flash/zoom/imported photo | 메모리 상태 |

---

## 6. 백엔드 인벤토리

모든 callable은 `asia-northeast3` region을 사용하고, 현재 export는 대부분 `enforceAppCheck: true`다.

### 6.1 Identity / Profile

| Callable | 입력 | 처리 | 권한 |
|---|---|---|---|
| `setRole` | `targetUid`, `role` | Firebase Auth custom claim 부여/해제 | admin |
| `setHandle` | `handle` | `handles/{handle}` 예약, 이전 handle 해제, `users/{uid}.handle` 갱신 | auth |
| `updateProfile` | displayName, bio, website, 공개 옵션, avatar URL | `users/{uid}` profile patch | auth |
| `profileAvatarUploadInit` | contentType, imageBytes | R2 avatar presigned PUT URL 발급 | auth |
| `deleteAccount` | 없음 | `users/{uid}` soft-delete, Auth user delete 시도 | auth |

### 6.2 Filters / Reviews / Samples

| Callable | 입력 | 처리 | 권한 |
|---|---|---|---|
| `uploadInit` | name, category, tags, packageBytes, sha256, sample URL | `filters/{id}` uploading 생성, R2 `.fmpkg` PUT URL 발급 | auth |
| `uploadFinalize` | filterId | R2 object HEAD 검증, `pending_review_pre` 전환 | owner |
| `submitForReview` | filterId, ToS booleans | `pending_review_pre` -> `pending_review` | owner |
| `recordUse` | filterId | 1시간 cooldown 기반 `useCount` 증가 | auth |
| `getFilterDetail` | filterId | 승인 필터 상세, 샘플/리뷰 일부, like 상태, signed download URL | auth |
| `reviewImageUploadInit` | filterId, contentType, imageBytes | 리뷰 이미지 R2 PUT URL 발급 | auth |
| `submitReview` | filterId, stars, body, optional photo | 다운로드/소유/Pro 확인 후 `reviews/{uid}` upsert | auth |
| `listReviews` | filterId, limit, cursor | 리뷰 페이지네이션, helpful 우선 정렬 | callable |
| `deleteReview` | filterId, reviewId | 작성자 리뷰 삭제 | review owner |
| `markReviewHelpful` | filterId, reviewId, helpful | helpful edge 생성/삭제, count 증감 | auth |
| `sampleImageUploadInit` | filterId, contentType, imageBytes | 사용자 샘플 R2 PUT URL 발급 | auth + entitlement |
| `addUserSample` | filterId, objectKey, publicURL, categoryHint | `samples/{sampleId}` 생성 | auth + entitlement |
| `listSamples` | filterId, limit, cursor | 샘플 페이지네이션 | callable |
| `removeSample` | filterId, sampleId | 샘플 작성자 또는 필터 작성자가 삭제 | owner/maker |
| `toggleFilterLike` | filterId, liked | `filters/{id}/likes/{uid}` 생성/삭제 | auth |
| `reportFilter` | filterId, reasonCode, detail | 신고 생성, `reportCount` 증가 | auth |

### 6.3 Moderation / Reports

| Callable | 입력 | 처리 | 권한 |
|---|---|---|---|
| `approveFilter` | filterId | pending filter를 `approved`로 전환 | moderator |
| `rejectFilter` | filterId, reason | pending filter를 `rejected`로 전환 | moderator |
| `undoModerationDecision` | filterId | approved/rejected를 `pending_review`로 되돌림 | moderator |
| `reportReview` | filterId, reviewId, authorUid, reasonCode, detail | 리뷰 하위 report 생성, review `reportCount` 증가 | auth |
| `reportUser` | targetUid, reasonCode, detail | user 하위 report 생성, user `reportCount` 증가 | auth |

### 6.4 Wallet / StoreKit

| Callable | 입력 | 처리 | 권한 |
|---|---|---|---|
| `purchaseFilter` | filterId | 잔액 차감, entitlement 생성, walletLedger 기록. 이미 소유 시 idempotent | auth |
| `creditCoinsFromIAP` | originalTransactionId, productId, signedJWS | Apple receipt 검증, 중복 receipt 차단, 코인 적립, ledger 기록 | auth |
| `proSubscriptionUpdate` | originalTransactionId, productId, signedJWS | Apple transaction 검증, `proStatus/status` mirror | auth |
| `refundRequest` | orderId, reason | ledger 검증 후 `refundRequests/{orderId}` 생성 | auth |

### 6.5 Firestore Triggers

| Trigger | 문서 경로 | 처리 |
|---|---|---|
| `onFilterPublished` | `filters/{filterId}` updated | `published` 전환 감지. owner count/FCM/search index는 TODO |
| `onReportCreated` | `filters/{filterId}/reports/{reportId}` created | report queue/threshold 처리는 TODO |
| `onFollowCreated` | `follows/{edgeId}` created | actor followingCount, target followerCount 증가 |
| `onFollowDeleted` | `follows/{edgeId}` deleted | actor followingCount, target followerCount 감소 |
| `onReviewCreated` | `filters/{filterId}/reviews/{reviewId}` created | reviewCount/ratingAvg 재계산 |
| `onReviewUpdated` | `filters/{filterId}/reviews/{reviewId}` updated | stars/status 변경 시 review stats 재계산 |
| `onReviewDeleted` | `filters/{filterId}/reviews/{reviewId}` deleted | review stats 재계산 |
| `onSampleCreated` | `filters/{filterId}/samples/{sampleId}` created | sampleCount 증가 |
| `onSampleDeleted` | `filters/{filterId}/samples/{sampleId}` deleted | sampleCount 감소 |
| `onFilterLikeCreated` | `filters/{filterId}/likes/{uid}` created | likeCount 증가 |
| `onFilterLikeDeleted` | `filters/{filterId}/likes/{uid}` deleted | likeCount 감소 |

---

## 7. Firestore 컬렉션 맵

| 경로 | 사용처 |
|---|---|
| `users/{uid}` | 프로필, 공개 설정, 삭제 상태, follower/following count |
| `handles/{handle}` | handle 중복 방지 및 profile resolver |
| `users/{uid}/notificationPreferences/main` | 알림 카테고리/방해금지 설정 |
| `users/{uid}/notifications/{notificationId}` | 알림 인박스, badge |
| `users/{uid}/devices/{deviceId}` | APNs token 등록 |
| `users/{uid}/savedFilters/{filterId}` | 다운로드/저장한 필터 |
| `users/{uid}/favorites/{filterId}` | 즐겨찾기 |
| `users/{uid}/collections/{collectionId}` | 사용자 컬렉션 |
| `users/{uid}/captures/{captureId}` | 촬영 결과 grid |
| `users/{uid}/editorDrafts/current` | 현재 에디터 초안 |
| `users/{uid}/makerDrafts/{draftId}` | 내 필터/업로드 단계 |
| `users/{uid}/wallet/balance` | 코인 잔액 |
| `users/{uid}/walletLedger/{ledgerId}` | 충전/구매 거래 내역 |
| `users/{uid}/entitlements/{filterId}` | 유료 필터 소유권 |
| `users/{uid}/proStatus/status` | Pro 구독 mirror |
| `users/{uid}/exportRequests/{requestId}` | 데이터 내보내기 요청 |
| `users/{uid}/refundRequests/{orderId}` | 환불 요청 |
| `users/{uid}/reviewHelpful/{edgeId}` | 리뷰 helpful edge |
| `users/{uid}/feedActions/{postId}` | following feed 숨김/저장 액션 |
| `filters/{filterId}` | 필터 메타데이터, 가격, 상태, counters |
| `filters/{filterId}/reviews/{uid}` | 리뷰/별점 본문 |
| `filters/{filterId}/ratings/{uid}` | 별점 form direct write |
| `filters/{filterId}/samples/{sampleId}` | 사용자/대표 샘플 이미지 |
| `filters/{filterId}/likes/{uid}` | 좋아요 edge |
| `filters/{filterId}/reports/{reportId}` | 필터 신고 |
| `filters/{filterId}/uses/{uid}` | recordUse cooldown |
| `follows/{actorUid}_{targetUid}` | 팔로우 관계 |
| `blocks/{actorUid}_{targetUid}` | 차단 관계 |
| `walletReceipts/{originalTransactionId}` | 코인 IAP 중복 방지 |
| `proReceipts/{originalTransactionId}` | Pro subscription receipt mirror |

---

## 8. 외부 서비스/시크릿

| 서비스 | 사용처 | 설정 |
|---|---|---|
| Firebase Auth | 로그인, custom claims, account deletion | Firebase project + GoogleService-Info |
| Firestore | 앱 데이터와 실시간 listener | `firestore.rules`, `firestore.indexes.json` |
| Firebase Functions v2 | callable API, trigger | `functions/package.json`, `functions/src` |
| Firebase App Check | callable 보호 | callable `enforceAppCheck: true` |
| Cloudflare R2 | `.fmpkg`, avatar, review/sample images | `R2_ENDPOINT`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET`, `R2_PUBLIC_BASE_URL` |
| StoreKit 2 / App Store | coin topup, Pro subscription, restore | `IAPProductIDs`, Apple receipt verifier |
| APNs/FCM | device token, push notification | `PushRegistration`, `users/{uid}/devices` |
| Stripe Connect | payout placeholder | Product Phase 후속. 현재 closed-loop coin 정책상 앱 진입점 비노출 |

---

## 9. 구현 갭

| 영역 | 현재 갭 |
|---|---|
| 업로드 end-to-end | `uploadInit/uploadFinalize` 백엔드는 있으나 SwiftUI upload flow가 `.fmpkg` 생성, R2 PUT, finalize까지 완전 연결되어 있지 않다. |
| 모더레이션 자동화 | report threshold, FCM fanout, search indexing은 trigger TODO로 남아 있다. |
| Search/recommendation | Firestore client-side search 중심이며 full-text search/추천 엔진은 ADR-0004 후속이다. |
| Payout | closed-loop coin 모델로 인해 정산 화면은 route placeholder에 가깝고, 실제 Stripe Connect 연동은 후속이다. |
| 카메라 실기기 검증 | 렌더링/저장 코드는 있으나 실기기 FPS, 방향, 색상, PhotoKit 결과 검증은 별도 게이트다. |
| 일부 화면 데이터 | Maker dashboard, orders history 일부 지표, For You 추천은 projection/mock 성격이 남아 있다. |

---

## 10. 테스트 맵

| 영역 | 테스트 위치 |
|---|---|
| Functions identity/filter/wallet/moderation | [functions/test](../functions/test) |
| Firestore rules | [functions/test/firestore-rules.test.mjs](../functions/test/firestore-rules.test.mjs) |
| App route/UI smoke | [Tests/AppUITests](../Tests/AppUITests) |
| App stores/parser | [Tests/AppTests](../Tests/AppTests) |
| Marketplace package/repository/review | [Tests/MarketplaceTests](../Tests/MarketplaceTests) |
| Camera services | [Tests/CameraTests](../Tests/CameraTests) |
| Filter engine/LUT/rendering | [Tests/FilterEngineTests](../Tests/FilterEngineTests) |
| Models | [Tests/ModelsTests](../Tests/ModelsTests) |

검증 명령은 [README.md](../README.md)와 [TESTING_STRATEGY.md](./TESTING_STRATEGY.md)를 따른다.

