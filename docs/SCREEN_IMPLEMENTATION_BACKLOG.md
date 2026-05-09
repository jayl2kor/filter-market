# moodit — Screen Implementation Backlog

> **Reference**: 이 문서는 mockup별 SwiftUI 화면 구현 현황을 보존한다.  
> 프로젝트의 단일 진행 기준은 [`PHASE_ROADMAP_STATUS.md`](./PHASE_ROADMAP_STATUS.md)의 Product Phase 1~4이다. 이 문서의 A~F 구분은 제품 Phase가 아니라 과거 UI work package 명칭이다.

> 버전: v1.1 · 작성일: 2026-05-07 · 상태: Active
>
> 본 문서는 `mockups/screens` 와 `docs/NAVIGATION.md` 기준으로 **SwiftUI 화면 구현 상태와 후속 통합 작업**을 정리한다. 현재 앱은 `AppRoute` 의 모든 화면 target 을 전용 SwiftUI View 타입으로 매핑하며, 과거의 `ProductFlowScreen` fallback 은 제거됐다. 일부 화면은 `ScreenWorkflowScaffold` 공통 레이아웃을 재사용하지만, 라우트별 View 타입/액션/상태/콘텐츠를 갖는다.

---

## 1. 상태 정의

| 상태 | 의미 | 처리 기준 |
|---|---|---|
| `Bespoke` | 전용 SwiftUI 화면이 존재하며 주요 UI가 구현됨 | 기능/API 연결, 테스트 보강 중심 |
| `Inline/Partial` | 별도 화면은 없지만 기존 화면 안에 일부 기능/UI가 있음 | 필요 시 전용 화면으로 분리하거나 기존 화면을 완성 |
| `Workflow/Bespoke` | 전용 SwiftUI View 타입이 존재하고 `ScreenWorkflowScaffold` 기반으로 주요 액션/상태가 구현됨 | API, persistence, StoreKit/Stripe 등 서비스 통합 필요 |
| `Missing route` | HTML 목업은 있으나 현재 `AppRoute` target 이 명확하지 않음 | 라우트 추가 후 전용 화면 구현 |
| `Policy/External` | iOS 설정, StoreKit, Stripe, Safari 등 외부 시스템 중심 | 앱 내 안내/상태/복귀 처리 구현 |

---

## 2. 현재 완료 범위

전용 SwiftUI 화면이 구현된 항목:

| 목업 | 현재 SwiftUI | 상태 | 남은 작업 |
|---|---|---|---|
| `01-onboarding.html`, `01b-onboarding-carousel.html` | `OnboardingScreen` | `Bespoke` | first-run 분기/analytics |
| `02-login.html`, `02b-login-guest.html` | `LoginScreen`, `ProfileScreen` guest gate | `Bespoke` | Firebase Auth, Apple/Google/Email 실제 연동 |
| `03-camera-live.html`, `04-filter-swipe.html`, `14-camera-zoom-grid-flash.html` | `CameraScreen` | `Bespoke` | 실기기 QA, 실제 zoom/flash device control 연결 |
| `05-capture-preview.html` | `CapturePreviewScreen` | `Bespoke` | 실제 camera result flow 와 완전 통합 |
| `06-marketplace-home.html` | `MarketplaceScreen` | `Bespoke` | API pagination/recommendations |
| `07-filter-detail.html` | `FilterDetailScreen` | `Bespoke` | 구매/댓글/신고 API 연결 |
| `08-search.html` | `SearchScreen` | `Bespoke` | 서버 검색, recent persistence |
| `09-profile.html`, `09b-other-user-profile.html` | `ProfileScreen` | `Bespoke` | 본인/타인 variant 분리, follow API |
| `10-settings.html` | `SettingsScreen` | `Bespoke` | 세부 설정 persist/API |
| `18-saved-filters.html` | `SavedScreen` | `Bespoke` | 다운로드/즐겨찾기/오프라인 세그먼트 |
| `07b-filter-download.html` | `FilterDownloadProgressScreen` | `Bespoke` | 실제 package/API progress 연결 |
| `07c-filter-after-download.html` | `FilterAfterDownloadScreen` | `Bespoke` | favorite persistence, collection picker |
| `13-camera-aspect-picker.html` | `CameraAspectPickerScreen` | `Bespoke` | `MooditStore.cameraAspectRatio` persistence |
| `15-camera-timer-countdown.html` | `CameraTimerCountdownScreen` | `Bespoke` | countdown cancel UX refinement |
| `16-photo-import.html` | `PhotoImportScreen` | `Bespoke` | OS PhotosPicker selection QA |
| `17-photo-edit.html` | `PhotoEditScreen` | `Bespoke` | compare slider, edit history, larger image QA |
| `19-builtin-filter-library.html` | `BuiltinFilterLibraryScreen` | `Bespoke` | filter package/detail API 연결 |
| `permissions/*` | `Sources/App/Permissions/*` | `Bespoke` | 실제 권한 resolver 와 모든 진입점 연결 |
| `11*`, `12*`, `20`~`54` | `WorkflowScreens.swift` route views | `Workflow/Bespoke` | 화면별 서비스/API/스토어 통합 |

---

## 3. 구현 대상 전체 목록

### 3.1 P0 — Camera MVP Completion

| 목업 | 현재 라우트/코드 | 상태 | 구현 목표 |
|---|---|---|---|
| `13-camera-aspect-picker.html` | `AppRoute.cameraAspect` → `CameraAspectPickerScreen` | `Bespoke` | 비율 선택 UI와 `CameraScreen` active guide 동기화 완료. persistence 남음 |
| `14-camera-zoom-grid-flash.html` | `CameraScreen` HUD | `Bespoke` | Timer/Grid/Flash/Aspect/Zoom HUD 상태 연결 완료. 실제 device zoom/flash control 남음 |
| `15-camera-timer-countdown.html` | `AppRoute.cameraTimer` → `CameraTimerCountdownScreen` | `Bespoke` | OFF/3s/10s 선택과 capture countdown overlay 완료. cancel refinement 남음 |
| `16-photo-import.html` | `AppRoute.photoImport` → `PhotoImportScreen` | `Bespoke` | `PhotosPicker` 단일 선택, preview, edit route, limited-library 안내/관리 진입 완료. OS picker QA 남음 |
| `17-photo-edit.html` | `AppRoute.photoEdit` → `PhotoEditScreen` | `Bespoke` | `PhotoFilterRenderer` 기반 필터/강도/저장/공유 완료. compare slider 남음 |
| `19-builtin-filter-library.html` | `AppRoute.builtinFilters` → `BuiltinFilterLibraryScreen` | `Bespoke` | 번들 필터 목록, 선택, 카메라 적용 흐름 완료. API/detail 연결 남음 |
| `07b-filter-download.html` | `AppRoute.filterDownload` → `FilterDownloadProgressScreen` | `Bespoke` | `MooditStore.download(_:)` 연동 완료. 실제 package/API progress 연결 남음 |
| `07c-filter-after-download.html` | `AppRoute.filterAfterDownload` → `FilterAfterDownloadScreen` | `Bespoke` | apply/favorite/remove 연동 완료. collection picker/persistence 남음 |

### 3.2 P1 — Auth, Account, Profile Detail

| 목업 | 현재 라우트/코드 | 상태 | 구현 목표 |
|---|---|---|---|
| `20-account-deletion.html` | `AppRoute.accountDeletion` → `AccountDeletionScreen` | `Bespoke` | handle 입력 검증, destructive confirmation, 삭제 요청 receipt 완료. 실제 재인증/logout API 남음 |
| `21-edit-profile.html` | `AppRoute.editProfile` → `EditProfileScreen` | `Bespoke` | avatar variant, 이름/핸들/바이오/링크, 공개 설정, mock save 완료. 실제 avatar picker/API persistence 남음 |
| `22-universal-link-landing.html` | `AppRoute.universalLinkLanding` → `UniversalLinkLandingScreen` | `Bespoke` | 공유 필터 카드, download/detail route 연결 완료. 실제 deep link payload parser 주입 남음 |
| `53-data-export.html` | `AppRoute.dataExport` → `DataExportScreen` | `Bespoke` | category/format 선택, request confirmation, history mock state 완료. 실제 export job API 남음 |

### 3.3 P2 — Editor And Upload

| 목업 | 현재 라우트/코드 | 상태 | 구현 목표 |
|---|---|---|---|
| `11-filter-editor.html` | `AppRoute.editor` → `FilterEditorScreen` | `Bespoke` | editor preview, compare affordance, parameter/LUT/draft/upload routes, cancel alert 완료. 실제 renderer integration 남음 |
| `11b-editor-parameters.html` | `AppRoute.editorParameters` → `EditorParametersScreen` | `Bespoke` | parameter tabs, sliders, compare hint, draft state mutation 완료. 실제 render preview sync 남음 |
| `11c-editor-lut-import.html` | `AppRoute.editorLUT` → `EditorLUTImportScreen` | `Bespoke` | LUT import/replace mock, validation card, draft route 완료. 실제 Files importer/parser 남음 |
| `11d-editor-save-draft.html` | `AppRoute.editorDraft` → `EditorDraftSaveScreen` | `Bespoke` | name/description editing, draft save, publish CTA 완료. 실제 persistence repository 남음 |
| `12-upload-flow.html` | Covered by upload step routes | `Inline/Partial` | Upload flow container/progress shell |
| `12b-upload-cover.html` | `AppRoute.uploadCover` → `UploadCoverScreen` | `Bespoke` | cover count mutation, remove/add, before/after toggle, next route 완료. 실제 picker/asset upload 남음 |
| `12c-upload-tags-category.html` | `AppRoute.uploadTags` → `UploadTagsCategoryScreen` | `Bespoke` | tag add/remove, category selection, description edit 완료. 가격/무료 정책 필드와 API 남음 |
| `12d-upload-tos-submit.html` | `AppRoute.uploadSubmit` → `UploadTOSSubmitScreen` | `Bespoke` | summary, ToS checklist, submit-to-pending 완료. 실제 policy validation/upload job 남음 |
| `12e-upload-pending.html` | `AppRoute.uploadPending` → `UploadPendingReviewScreen` | `Bespoke` | pending receipt, submittedAt, my filters route 완료. 실제 notification/status polling 남음 |
| `48-filter-rejected.html` | `AppRoute.filterRejected` → `FilterRejectedScreen` | `Bespoke` | rejection reasons, moderator note, edit/appeal UX 존재. 실제 moderation API 남음 |
| `50-my-filters.html` | `AppRoute.myFilters` → `MyFiltersScreen` | `Bespoke` | maker filter list, status chips, edit/review/takedown actions 완료. 실제 repository/dashboard 연결 남음 |
| `36-remix-flow.html` | `AppRoute.remixFlow` → `RemixFlowScreen` | `Bespoke` | remix policy confirmation, editor handoff 완료. 원본 filter payload 주입 남음 |

### 3.4 P3 — Social, Discovery, Notifications

| 목업 | 현재 라우트/코드 | 상태 | 구현 목표 |
|---|---|---|---|
| `23-comments-list.html` | `AppRoute.comments` → `CommentsListScreen` | `Workflow/Bespoke` | comments list, sort, empty/login states |
| `23b-comments-compose.html` | `AppRoute.commentCompose` → `CommentComposeScreen` | `Workflow/Bespoke` | compose/reply, validation, submit |
| `24-rating-form.html` | `AppRoute.rating` → `RatingFormScreen` | `Workflow/Bespoke` | star rating, review text, submit |
| `25-followers-list.html` | `AppRoute.followers` → `FollowersListScreen` | `Workflow/Bespoke` | follower list, follow toggles, profile routing |
| `26-following-list.html` | `AppRoute.following` → `FollowingListScreen` | `Workflow/Bespoke` | following list, unfollow confirmation |
| `27-notifications-inbox.html` | `AppRoute.notifications` → `NotificationsInboxScreen` | `Workflow/Bespoke` | notification inbox, category chips, item deeplink |
| `51-notification-settings.html` | `AppRoute.notificationSettings` → `NotificationSettingsScreen` | `Bespoke` | system settings entry, category toggles, quiet hours mock state 완료. 실제 권한 resolver/persistence 남음 |
| `30-favorites-collection.html` | `AppRoute.favoritesCollection` → `FavoritesCollectionScreen` | `Workflow/Bespoke` | collection list/create/edit |
| `31-foryou-feed.html` | `AppRoute.forYou` → `ForYouFeedScreen` | `Workflow/Bespoke` | recommendation feed, filter cards, maker taps |
| `32-following-feed.html` | `AppRoute.followingFeed` → `FollowingFeedScreen` | `Workflow/Bespoke` | following feed, empty state |

### 3.5 P4 — Moderation And Safety

| 목업 | 현재 라우트/코드 | 상태 | 구현 목표 |
|---|---|---|---|
| `29-report-form.html` | `AppRoute.reportForm` → `ReportFormScreen` | `Workflow/Bespoke` | reason picker, evidence attach, submit receipt |
| `33-mod-queue.html` | `AppRoute.modQueue` → `ModerationQueueScreen` | `Workflow/Bespoke` | moderation queue, filters, role gating |
| `34-mod-detail.html` | `AppRoute.modDetail` → `ModerationDetailScreen` | `Workflow/Bespoke` | approve/reject/takedown, reason input |
| `35-block-list.html` | `AppRoute.blockList` → `BlockListScreen` | `Workflow/Bespoke` | block/mute tabs, unblock confirmation |

### 3.6 P5 — Wallet, Purchase, Pro, Payout

| 목업 | 현재 라우트/코드 | 상태 | 구현 목표 |
|---|---|---|---|
| `37-paywall-single.html` | `AppRoute.paywallSingle` → `PaywallSingleScreen` | `Workflow/Bespoke` | Coin purchase confirmation, owned/pro branches |
| `38-paywall-subscription.html` | `AppRoute.proSubscription` → `ProSubscriptionScreen` | `Workflow/Bespoke` | StoreKit products, monthly/yearly toggle, trial |
| `39-orders-history.html` | `AppRoute.ordersHistory` → `OrdersHistoryScreen` | `Workflow/Bespoke` | order list, receipts, refund entry |
| `40-payout-onboarding.html` | `AppRoute.payoutOnboarding` → `PayoutOnboardingScreen` | `Workflow/Bespoke` | Stripe Connect entry/return state |
| `41-payout-tax-info.html` | `AppRoute.payoutTaxInfo` → `PayoutTaxInfoScreen` | `Workflow/Bespoke` | tax info form, validation, save |
| `42-payout-history.html` | `AppRoute.payoutHistory` → `PayoutHistoryScreen` | `Workflow/Bespoke` | payout rows/status/detail |
| `43-wallet.html` | `AppRoute.wallet` → `WalletScreen` | `Workflow/Bespoke` | balance summary, topup, transaction list, Pro entry |
| `44-wallet-topup.html` | `AppRoute.walletTopup` → `WalletTopupScreen` | `Workflow/Bespoke` | StoreKit packages, restore, failure branch |
| `45-wallet-transactions.html` | `AppRoute.walletTransactions` → `WalletTransactionsScreen` | `Workflow/Bespoke` | transaction filters, rows, refund sheet |
| `46-insufficient-balance.html` | `AppRoute.insufficientBalance` → `InsufficientBalanceScreen` | `Workflow/Bespoke` | topup CTA, cancel, purchase resume |
| `47-earnings-withdraw.html` | `AppRoute.earningsWithdraw` → `EarningsWithdrawScreen` | `Workflow/Bespoke` | amount quick select, threshold, submit |
| `49-pro-status.html` | `AppRoute.proStatus` → `ProStatusScreen` | `Workflow/Bespoke` | active plan, renewal, App Store manage |
| `52-payment-failed.html` | `AppRoute.paymentFailed` → `PaymentFailedScreen` | `Workflow/Bespoke` | retry, restore, support |
| `54-refund-request.html` | `AppRoute.refundRequest` → `RefundRequestScreen` | `Workflow/Bespoke` | Apple refund link, optional moodit reason form |

---

## 4. 권장 작업 순서

### Phase A — Camera/Download MVP closure

목표: 사용자가 필터를 찾고, 다운로드하고, 카메라/사진 편집에 적용하는 루프를 완성한다.

상태: 완료됨. 2026-05-07 기준 `AppUITests/PhaseAE2ETests` 5개 시나리오와 `./scripts/test.sh` 전체 통과.

대상:
- `13-camera-aspect-picker.html`
- `14-camera-zoom-grid-flash.html`
- `15-camera-timer-countdown.html`
- `16-photo-import.html`
- `17-photo-edit.html`
- `19-builtin-filter-library.html`
- `07b-filter-download.html`
- `07c-filter-after-download.html`

완료 기준:
- 모든 화면이 전용 SwiftUI View 로 렌더링된다.
- `CameraScreen`, `SavedScreen`, `FilterDetailScreen` 간 필터 선택/다운로드 상태가 이어진다.
- Phase A XCUITest 가 Marketplace → Download → Apply, Camera HUD, Aspect/Timer, Built-in library, Photo edit 흐름을 검증한다.
- `./scripts/test.sh` 통과.

### Phase B — Account/Profile policy screens

목표: App Store 심사와 계정 관리에 필요한 최소 정책 화면을 완성한다.

대상:
- `20-account-deletion.html`
- `21-edit-profile.html`
- `22-universal-link-landing.html`
- `53-data-export.html`
- `51-notification-settings.html`

완료 기준:
- 계정 삭제/데이터 내보내기 화면은 destructive/confirmation UX 를 갖는다.
- 프로필 편집은 local state 저장 또는 mock repository 로 persistence 를 시뮬레이션한다.
- Universal Link landing 은 route parser 와 연결 가능한 형태를 갖는다.

진행 상태:
- 완료: `AccountDeletionScreen`, `EditProfileScreen`, `UniversalLinkLandingScreen`, `DataExportScreen`, `NotificationSettingsScreen` 모두 전용 SwiftUI 화면으로 구현됨.
- 검증: `./scripts/test.sh` 통과 (2026-05-07).
- 남은 통합: Firebase Auth 재인증/삭제, profile API, universal link payload parser, export job API, notification permission resolver 와 persistence.

### Phase C — Maker supply flow

목표: 메이커가 필터를 만들고, 초안 저장 후 업로드/검수로 넘기는 흐름을 완성한다.

대상:
- `11-filter-editor.html`
- `11b-editor-parameters.html`
- `11c-editor-lut-import.html`
- `11d-editor-save-draft.html`
- `12-upload-flow.html`
- `12b-upload-cover.html`
- `12c-upload-tags-category.html`
- `12d-upload-tos-submit.html`
- `12e-upload-pending.html`
- `48-filter-rejected.html`
- `50-my-filters.html`
- `36-remix-flow.html`

완료 기준:
- editor draft model 이 생긴다.
- upload step state 가 한 곳에서 유지된다.
- pending/rejected/my filters 상태가 서로 이동 가능하다.

진행 상태:
- 완료: `MakerFilterDraft`, `UploadStep`, `MakerFilterStatus` 기반 mock state 추가. editor/upload/my filters/remix 화면이 전용 SwiftUI 화면으로 구현됨.
- 검증: `./scripts/test.sh` 통과 (2026-05-07).
- 남은 통합: 실제 LUT/cover picker, renderer preview sync, draft repository, upload job API, moderation API, maker dashboard 연결.

### Phase D — Social and discovery

목표: 마켓 상세 화면에서 댓글/평점/팔로우/알림으로 이어지는 커뮤니티 흐름을 완성한다.

대상:
- `23-comments-list.html`
- `23b-comments-compose.html`
- `24-rating-form.html`
- `25-followers-list.html`
- `26-following-list.html`
- `27-notifications-inbox.html`
- `30-favorites-collection.html`
- `31-foryou-feed.html`
- `32-following-feed.html`

완료 기준:
- 댓글/평점 작성은 guest intercept 와 signed-in branch 를 가진다.
- 팔로우 버튼 state 가 프로필/목록/피드에서 일관되게 표시된다.
- 알림 row 는 item-specific route 로 이동한다.

진행 상태:
- 진행 중: `CommentsListScreen`, `CommentComposeScreen`, `RatingFormScreen`, `FollowersListScreen`, `FollowingListScreen`, `ForYouFeedScreen`, `FollowingFeedScreen` placeholder 를 전용 SwiftUI 화면으로 교체.
- 추가 반영: 댓글 상단 필터 카드, For You hero/추천 rail, Following feed 새 필터/포스트 배지에 다운로드 횟수 표시를 추가.
- 검증: `AppUITests/PhaseDE2ETests` 4개 시나리오 통과 (2026-05-07).
- 기존 완료: `NotificationsInboxScreen`, `FavoritesCollectionScreen` 전용 화면 유지.
- 남은 통합: 실제 social repository/API, 서버 기반 follow state, 댓글/평점 persistence, recommendation feed backend.

### Phase E — Safety/moderation

목표: UGC 앱 운영에 필요한 신고, 차단, 검수 플로우를 완성한다.

대상:
- `29-report-form.html`
- `33-mod-queue.html`
- `34-mod-detail.html`
- `35-block-list.html`

완료 기준:
- 신고 제출 후 receipt/alert 표시.
- moderator-only route guard 를 둔다.
- approve/reject/takedown state transition 이 mock repository 에서 검증된다.

### Phase F — Monetization

목표: Coin, paid filter, Pro, payout 흐름을 StoreKit/Stripe 연동 전까지 UI/state 기준으로 완성한다.

대상:
- `37-paywall-single.html`
- `38-paywall-subscription.html`
- `39-orders-history.html`
- `40-payout-onboarding.html`
- `41-payout-tax-info.html`
- `42-payout-history.html`
- `43-wallet.html`
- `44-wallet-topup.html`
- `45-wallet-transactions.html`
- `46-insufficient-balance.html`
- `47-earnings-withdraw.html`
- `49-pro-status.html`
- `52-payment-failed.html`
- `54-refund-request.html`

완료 기준:
- wallet/pro/owned state 가 `FilterDetailScreen` purchase branch 에 반영된다.
- StoreKit 호출부는 protocol 로 감싸 mock 테스트 가능하게 둔다.
- Stripe Connect 는 external session + return state 를 별도로 표현한다.

---

## 5. 이슈 생성 템플릿

```md
## Scope
- Mockup: `mockups/screens/<file>.html`
- Route: `AppRoute.<case>`
- Current view: `<ScreenName>`

## Requirements
- NAVIGATION.md action IDs:
  - `<action.id>`
- Required states:
  - loading
  - empty
  - error
  - success

## Implementation
- Add `Sources/App/<Area>/<ScreenName>.swift`
- Replace route branch in `AppNavigation.swift`
- Wire entry points from existing screens
- Add focused tests where state logic is non-trivial

## Acceptance
- `./scripts/test.sh` passes
- No generic fallback for this route
- Dynamic Type and dark/light mode reviewed
```

---

## 6. Definition Of Done

개별 화면 완료 기준:
- HTML 목업의 주요 layout, CTA, 상태가 SwiftUI에 반영된다.
- `docs/NAVIGATION.md`의 action IDs가 버튼/제스처로 연결된다.
- 실제 API가 없더라도 mock state/repository 로 성공/실패/빈 상태를 볼 수 있다.
- 화면이 `AppRoute`에서 전용 View 로 직접 매핑된다.
- `AppRoute`에서 전용 View 타입으로 직접 매핑된다.
- `./scripts/test.sh` 또는 해당 영역의 focused build/test 가 통과한다.

전체 와이어프레임 완료 기준:
- `AppNavigation.swift`에 `default` fallback 없이 모든 `AppRoute` case 가 명시적으로 매핑된다.
- `mockups/screens/*.html` 제품 화면 67개에 대응하는 SwiftUI View 또는 명시적 inline 구현이 있다.
- 권한, 모달, empty/error/loading 상태가 `PERMISSIONS_FLOW.md`, `MODAL_PATTERNS.md`, `EMPTY_STATES.md`와 동기화된다.

---

## 7. 관련 문서

- [`SCREENS_PLAN.md`](./SCREENS_PLAN.md)
- [`NAVIGATION.md`](./NAVIGATION.md)
- [`IMPLEMENTATION_PLAN.md`](./IMPLEMENTATION_PLAN.md)
- [`TASK_LIST.md`](./TASK_LIST.md)
- [`DESIGN_SYSTEM.md`](./DESIGN_SYSTEM.md)
- [`CURRENCY_DESIGN.md`](./CURRENCY_DESIGN.md)
- [`PERMISSIONS_FLOW.md`](./PERMISSIONS_FLOW.md)
