# moodit Screen & Action QA Definition

> 작성일: 2026-05-08 KST  
> 상태: Current  
> 목적: 전체 앱 QA를 시작하기 전에 **모든 화면, 진입 경로, 버튼/액션 계약, 검증 우선순위**를 하나의 기준으로 고정한다.

## 1. 사용 원칙

이 문서는 QA 실행의 출발점이다. 화면이나 버튼을 고치기 전에 먼저 아래 정의에 맞는지 확인한다.

| 기준 | 단일 출처 |
|---|---|
| 화면 라우트 | `Sources/App/AppNavigation.swift`의 `AppRoute` |
| 글로벌 탭 | `Sources/App/RootShell.swift`, `FMTabBar` |
| 버튼/액션 ID | `.accessibilityIdentifier(...)`, `AppRoute.primaryActions` |
| 상세 흐름 | `docs/NAVIGATION.md` |
| 수동 QA 체크 | `docs/QA_TEST_PLAN.md` |

QA 중 새 버튼을 발견하면 아래 중 하나로 처리한다.

1. 실제 사용자 액션이면 이 문서와 `QA_TEST_PLAN.md`에 추가한다.
2. 테스트만을 위한 scaffold 액션이면 `Test-only`로 표시한다.
3. 더 이상 쓰지 않는 액션이면 제거 후보로 `Deprecated` 표시한다.

## 2. 상태 정의

| 상태 | 의미 |
|---|---|
| `Implemented` | SwiftUI 화면과 주요 액션이 구현되어 있음 |
| `Partial` | 화면은 있으나 일부 액션이 mock/no-op/backend 미연결 |
| `MockOnly` | UI 검증용 mock 데이터나 scaffold 중심 |
| `NeedsE2E` | 수동 확인은 가능하나 E2E 부족 |
| `Blocked` | 외부 서비스/실기기/권한/계정 세팅 필요 |

## 3. 글로벌 앱 셸

| Area | SwiftUI | Action ID | Expected |
|---|---|---|---|
| Market tab | `MarketplaceScreen` | `tab.market` | 탭 전환, 마켓 루트 표시 |
| Search tab | `SearchScreen` | `tab.search` | 탭 전환, 검색 루트 표시 |
| Shutter | `CameraScreen` | `tab.shutter` | selection 변경 없이 fullScreenCover로 카메라 표시 |
| Saved tab | `SavedScreen` | `tab.saved` | 탭 전환, 저장 필터 표시 |
| Profile tab | `ProfileScreen` | `tab.profile` | 탭 전환, 본인 프로필 표시 |
| Onboarding | `OnboardingScreen` | `onboard.*` | 첫 실행에서만 표시, 완료 후 `RootShell` |
| Deep link sheet | `DeepLinkDestination` | `app.deeplink.*` | universal link/push tap을 route로 변환 |
| Push bootstrap | `PushRegistration` | n/a | APNs/FCM 등록, notification tap routing 후보 |

## 4. Screen Registry

### 4.1 Auth / Account

| Screen ID | Route / Entry | SwiftUI | 상태 | Required actions |
|---|---|---|---|---|
| `auth.login` | `AppRoute.login` | `LoginScreen` | Implemented | `auth.apple`, `auth.google`, `auth.email.continue`, `auth.guest.continue`, `auth.terms` |
| `auth.email` | `AppRoute.emailLogin` | `EmailLoginScreen` | Implemented | `auth.email.input`, `auth.password.input`, `auth.signIn.submit`, `auth.signUp.submit`, `auth.passwordReset.send`, `auth.mode.toggle` |
| `auth.delete` | `AppRoute.accountDeletion` | `AccountDeletionScreen` | Implemented, NeedsE2E | `auth.delete.policy.ack`, `auth.delete.confirm.input`, `auth.delete.submit`, `auth.delete.cancel` |
| `settings.export` | `AppRoute.dataExport` | `DataExportScreen` | Partial | `settings.export.cat.toggle`, `settings.export.format`, `settings.export.submit` |

### 4.2 Marketplace / Filter

| Screen ID | Route / Entry | SwiftUI | 상태 | Required actions |
|---|---|---|---|---|
| `market.home` | root tab `market` | `MarketplaceScreen` | Partial, NeedsE2E | `market.header.coinBalance`, `market.trending.*`, `market.category.*`, `market.tile.*`, `market.collection.*`, `market.loadError.retry`, notification button |
| `market.search` | root tab `search`, `AppRoute.search` | `SearchScreen` | Implemented, NeedsE2E | `search.recent.*`, `search.suggested.*`, `search.maker.*`, `search.typing.tile.*`, `search.result.tile.*` |
| `filter.detail` | `AppRoute.filterDetail(id:)` | `FilterDetailLoaderScreen` or `FilterDetailScreen` | Partial, NeedsE2E | `filter.detail.share`, `filter.detail.like`, `filter.detail.sample.gallery`, `filter.detail.sample.signature`, `filter.detail.sample.reference.*`, `filter.detail.sample.lightbox`, `filter.detail.sample.lightbox.close`, `filter.detail.sample.lightbox.counter`, `filter.detail.tag.*`, maker profile, follow toggle, CTA download/purchase, review/download/like count, reviews link |
| `filter.download` | `AppRoute.filterDownload(id:)` | `FilterDownloadProgressScreen` | Partial | `filter.download.cancel`, `filter.download.retry`, `filter.download.completed.next`, `filter.apply` |
| `filter.afterDownload` | `AppRoute.filterAfterDownload(id:)` | `FilterAfterDownloadScreen` | Partial | `filter.apply`, `filter.favorite.toggle`, `filter.collection.add`, `filter.remove` |
| `filter.builtin` | `AppRoute.builtinFilters` | `BuiltinFilterLibraryScreen` | Implemented | `builtin.filter.tap`, `builtin.filter.apply.*`, `builtin.filter.info.*`, `builtin.manage` |
| `filter.paywall` | `AppRoute.paywallSingle(filterId:)` | `PaywallSingleScreen` | Partial | `filter.purchase.confirm`, `filter.purchase.pro_upgrade` |
| `collection.favorites` | `AppRoute.favoritesCollection` | `FavoritesCollectionScreen` | Implemented, NeedsFirebaseQA | `/users/{uid}/collections` listener, non-negative custom count, `collection.create`, `collection.card.tap`, `collection.edit`, `collection.delete` |
| `saved.filters` | root tab `saved`, `AppRoute.savedFilters` | `SavedScreen` | Partial | `saved.tile.*`, empty state CTA |

### 4.3 Reviews / Social

| Screen ID | Route / Entry | SwiftUI | 상태 | Required actions |
|---|---|---|---|---|
| `reviews.list` | `AppRoute.reviews(filterId:)` | `ReviewsListScreen` | Implemented, NeedsFirebaseQA | `social.reviews.filter`, `social.reviews.compose`, `social.rating.open`, `social.review.author`, `social.review.helpful` (Firestore edge + counter transaction), `social.review.more`, `social.review.more.report`, `social.review.more.block` (writes root `blocks/{actorUid}_{targetUid}` and hides blocked author reviews), `social.review.more.copy` |
| `reviews.compose` | `AppRoute.reviewCompose(filterId:)` | `ReviewComposeScreen` | Implemented, NeedsE2E | `social.compose.rating.star.*`, `social.compose.rating.label`, `social.compose.input`, `social.compose.send`, `social.compose.error`, `social.compose.attachImage`, `social.compose.removeImage`, `social.review.image`, `social.compose.insertMention`, `social.compose.emojiToggle`, `social.compose.emoji.*` |
| `reviews.rating` | `AppRoute.rating(filterId:)` | `RatingFormScreen` | Implemented, NeedsE2E | `social.rating.star`, `social.rating.star.*`, `social.rating.body`, `social.rating.submit` |
| `social.followers` | `AppRoute.followers(uid:)` | `FollowersListScreen` | Implemented, NeedsFirebaseQA | `social.user.row`, `social.user.tap`, `social.follow.toggle`, empty state |
| `social.following` | `AppRoute.following(uid:)` | `FollowingListScreen` | Implemented, NeedsFirebaseQA | `social.user.row`, `social.user.tap`, `social.follow.toggle`, empty state |
| `social.forYou` | `AppRoute.forYou` | `ForYouFeedScreen` | Implemented, NeedsFirebaseQA | `market.tile.tap` (UUID route), `market.maker.tap`, `social.foryou.hero.apply` (UUID route), `social.foryou.hero.save` (`MooditStore.toggleFavorite`), `social.foryou.maker.follow`, `social.foryou.empty` |
| `social.followingFeed` | `AppRoute.followingFeed` | `FollowingFeedScreen` | Implemented, NeedsFirebaseQA | `market.tile.tap` (UUID route), `profile.following`, `social.following.newFilter` (latest followed filter), `social.following.post.like` (`feedActions`), `social.following.post.reviews`, `social.following.post.save` (`favorites`), `social.following.post.more`, `social.following.post.hide` |
| `social.blockList` | `AppRoute.blockList` | `BlockListScreen` | Implemented, NeedsFirebaseQA | root `blocks` listener filtered by `actorUid`, `social.block.toggle`, `blocklist.retry`, `blocklist.empty` |
| `social.report` | `AppRoute.reportForm(target:)` | `ReportFormScreen` | Implemented, NeedsFirebaseQA | `report.target`, `report.reason`, `report.detail`, `report.submit`; filter/review/user target context is read-only and routes to `reportFilter` / `reportReview` / `reportUser` |

### 4.4 Camera / Photo

| Screen ID | Route / Entry | SwiftUI | 상태 | Required actions |
|---|---|---|---|---|
| `camera.live` | `tab.shutter`, UI test route | `CameraScreen` | Partial, Blocked on real device | `camera.dismiss`, `camera.flip`, `camera.aspectRatio`, `camera.timer`, `camera.grid.toggle`, `camera.flash`, `camera.filterIntensity`, `camera.filter.*`, `camera.openLibrary`, `camera.shutter`, `camera.zoom.*` |
| `camera.capturePreview` | after shutter | `CapturePreviewScreen` | Partial, Blocked on camera | `preview.dismiss`, `preview.more`, `preview.more.info`, `preview.more.changeFilter`, `preview.more.copyMetadata`, `preview.retake`, `preview.changeFilter`, `preview.edit`, `preview.discard`, `preview.save` (Photos save + `/users/{uid}/captures` metadata), `preview.share` |
| `camera.aspect` | `AppRoute.cameraAspect` | `CameraAspectPickerScreen` | Implemented | `cam.aspect.set.1_1`, `cam.aspect.set.4_3`, `cam.aspect.set.16_9` |
| `camera.timer` | `AppRoute.cameraTimer` | `CameraTimerCountdownScreen` | Implemented | `cam.timer.set.off`, `cam.timer.set.3`, `cam.timer.set.10`, `cam.timer.cancel` |
| `photo.import` | `AppRoute.photoImport` | `PhotoImportScreen` | Partial, Blocked on photos permission | `photo.import.cell.tap`, `photo.import.next` |
| `photo.edit` | `AppRoute.photoEdit` | `PhotoEditScreen` | Partial | `photo.edit.filter.tap`, `photo.edit.filter.*`, `photo.edit.intensity`, `photo.edit.done`, `photo.edit.save_share` |

### 4.5 Maker / Editor / Upload

| Screen ID | Route / Entry | SwiftUI | 상태 | Required actions |
|---|---|---|---|---|
| `editor.main` | `AppRoute.editor` | `FilterEditorScreen` | Partial | `editor.preview`, `editor.reference.photo.pick`, `editor.reference.photo.clear`, `editor.reference.sample.*`, `editor.cancel`, `editor.params`, `editor.lut`, `editor.draft`, `editor.next`, `editor.compare.hold` |
| `editor.parameters` | `AppRoute.editorParameters` | `EditorParametersScreen` | Partial | `editor.preview`, `editor.param.slider.*`, `editor.param.slider`, `editor.compare.hold`, `editor.next` |
| `editor.lut` | `AppRoute.editorLUT` | `EditorLUTImportScreen` | Partial | `editor.preview`, `editor.lut.import`, `editor.lut.replace`, `editor.next` |
| `editor.draft` | `AppRoute.editorDraft` | `EditorDraftSaveScreen` | Partial | `editor.draft.name`, `editor.draft.description`, `editor.draft.save`, `editor.draft.publish` |
| `upload.cover` | `AppRoute.uploadCover` | `UploadCoverScreen` | Partial | `upload.cover.add`, `upload.cover.remove`, `upload.signature.preview`, `upload.signature.photo.pick`, `upload.signature.sample.*`, `upload.signature.clear`, `upload.cover.ba.toggle`, `upload.next`, `upload.cancel` |
| `upload.tags` | `AppRoute.uploadTags` | `UploadTagsCategoryScreen` | Partial | `upload.tag.add`, `upload.tag.remove`, `upload.cat.tap.*`, `upload.cat.tap`, `upload.next` |
| `upload.submit` | `AppRoute.uploadSubmit` | `UploadTOSSubmitScreen` | Partial | `upload.tos.toggle`, `upload.submit` |
| `upload.pending` | `AppRoute.uploadPending` | `UploadPendingReviewScreen` | Partial | `upload.pending.view_filter`, `upload.pending.dismiss` |
| `maker.myFilters` | `AppRoute.myFilters` | `MyFiltersScreen` | Partial | `myfilters.fab.create`, `myfilters.status.filter.*`, `myfilters.status.filter`, `myfilters.row.tap`, `myfilters.row.dashboard`, `myfilters.row.takedown` |
| `maker.dashboard` | `AppRoute.makerDashboard` | `MakerDashboardScreen` | Partial | `maker.dashboard.create`, `maker.dashboard.withdraw`, `maker.period.set`, `maker.filter.row` |
| `editor.remix` | `AppRoute.remixFlow` | `RemixFlowScreen` | Partial | `remix.parent.name`, `remix.parent.maker`, `editor.remix.cancel`, `editor.remix.open_editor` |

### 4.6 Moderation

| Screen ID | Route / Entry | SwiftUI | 상태 | Required actions |
|---|---|---|---|---|
| `mod.queue` | `AppRoute.modQueue` | `ModerationQueueScreen` | Implemented, NeedsFirebaseQA | `modqueue.empty`, `mod.queue.filter.tap`, `mod.queue.row` |
| `mod.detail` | `AppRoute.modDetail(id:)` | `ModerationDetailScreen` | Implemented, NeedsFirebaseQA | filter metadata/preview, `modDetail.approve`, `modDetail.reason`, `modDetail.reject`, `modDetail.undo`, `mod.detail.takedown` |
| `mod.rejected` | `AppRoute.filterRejected(id:)` | `FilterRejectedScreen` | Implemented | `mod.rejected.review`, `mod.rejected.detail`, `mod.rejected.support`, `mod.rejected.appeal`, `mod.rejected.cancel`, `mod.rejected.edit` |

### 4.7 Wallet / Payment / Pro

| Screen ID | Route / Entry | SwiftUI | 상태 | Required actions |
|---|---|---|---|---|
| `wallet.home` | `AppRoute.wallet` | `WalletScreen` | Partial | `wallet.balance`, `wallet.action.*`, `wallet.topup`, `wallet.transactions`, `wallet.pro` |
| `wallet.topup` | `AppRoute.walletTopup` | `WalletTopupScreen` | Partial, Blocked on StoreKit sandbox | `wallet.topup.package.com.jayl2kor.moodit.coins.100`, `wallet.topup.package.com.jayl2kor.moodit.coins.550`, `wallet.topup.package.com.jayl2kor.moodit.coins.1200`, `wallet.topup.package.com.jayl2kor.moodit.coins.3000`, `wallet.topup.restore`, `wallet.topup.failed_demo` |
| `wallet.transactions` | `AppRoute.walletTransactions` | `WalletTransactionsScreen` | Partial | `wallet.transactions.row.*`, `wallet.transactions.empty`, `wallet.tx.filter.cat`, `orders.history`, `wallet.refund_request` |
| `wallet.insufficient` | `AppRoute.insufficientBalance(filterId:)` | `InsufficientBalanceScreen` | Partial | `insufficient.topup`, `wallet.insufficient.cancel` |
| `wallet.paymentFailed` | `AppRoute.paymentFailed` | `PaymentFailedScreen` | Partial | `wallet.topup.retry`, `payment.failed.restore`, `wallet.topup.support` |
| `wallet.refund` | `AppRoute.refundRequest(orderId:)` | `RefundRequestScreen` | Partial, Needs Firebase QA | `refund.orderId`, `refund.reason`, `refund.submit`; direct entry accepts manual order ID, order-scoped entry pre-fills a read-only order ID; reason is capped at 2000 chars and successful submit dismisses |
| `orders.history` | `AppRoute.ordersHistory` | `OrdersHistoryScreen` | Partial, Needs Firebase QA | `orders.empty`, `wallet.transactions`, `wallet.refund_request`, `orders.refund_request.<orderId>` |
| `pro.subscription` | `AppRoute.proSubscription` | `ProSubscriptionScreen` | Partial, Blocked on StoreKit sandbox | `pro.subscribe.com.jayl2kor.moodit.pro.monthly`, `pro.subscribe.com.jayl2kor.moodit.pro.yearly`, `pro.plan.toggle`, `pro.invoice` |
| `pro.status` | `AppRoute.proStatus` | `ProStatusScreen` | Partial | `pro.cancel`, `pro.invoice` |

### 4.8 Payout

| Screen ID | Route / Entry | SwiftUI | 상태 | Required actions |
|---|---|---|---|---|
| `payout.withdraw` | `AppRoute.earningsWithdraw` | `EarningsWithdrawScreen` | MockOnly | `payout.bank.change`, `payout.amount.quick`, `payout.submit`, `payout.placeholder.*` |
| `payout.onboarding` | `AppRoute.payoutOnboarding` | `PayoutOnboardingScreen` | MockOnly | `payout.stripe.connect`, `payout.placeholder.*` |
| `payout.tax` | `AppRoute.payoutTaxInfo` | `PayoutTaxInfoScreen` | MockOnly | `payout.tax.save`, `payout.placeholder.*` |
| `payout.history` | `AppRoute.payoutHistory` | `PayoutHistoryScreen` | MockOnly | `payout.history.row`, `payout.placeholder.*` |

### 4.9 Profile / Settings / Notifications / Help

| Screen ID | Route / Entry | SwiftUI | 상태 | Required actions |
|---|---|---|---|---|
| `profile.self` | root tab `profile` | `ProfileScreen` | Partial | `profile.login`, `profile.settings`, `profile.edit.open`, `profile.share`, `profile.shortcut.wallet`, `profile.shortcut.myFilters`, `profile.shortcut.dashboard`, `profile.tile.*` (filter UUID route, capture detail route), followers/following |
| `profile.other` | `AppRoute.otherProfile(uid:)` | `ProfileScreen(otherUid:)` | Partial | `profile.follow.toggle`, `profile.share`, `profile.other.menu`, report/block/share menu actions, `profile.tile.*` |
| `profile.edit` | `AppRoute.editProfile` | `EditProfileScreen` | Implemented, NeedsE2E | `profile.edit.avatar.change`, `profile.edit.name`, `profile.edit.handle`, `profile.edit.handle.status`, `profile.edit.handle.check`, `profile.edit.bio`, `profile.edit.website`, `profile.edit.save` |
| `settings.home` | `AppRoute.settings` | `SettingsScreen` | Partial | `settings.nav.*`, `settings.row.*`, account, notification, data export, refund/help, admin section |
| `settings.help` | `AppRoute.helpCenter` | `HelpCenterScreen` | Implemented | `help.faq.*`, `help.email`, `help.refund`, `help.terms`, `help.privacy` |
| `notifications.inbox` | `AppRoute.notifications` | `NotificationsInboxScreen` | Partial | `notif.settings`, `notif.cat.*`, `notif.tap`, `notif.follow.action.*` |
| `notifications.settings` | `AppRoute.notificationSettings` | `NotificationSettingsScreen` | Partial | `notif.system.open`, `notif.cat.toggle`, `notif.quiet.toggle` |
| `deeplink.landing` | `AppRoute.universalLinkLanding` | `UniversalLinkLandingScreen` | Partial | `app.deeplink.confirm`, `app.deeplink.detail` |

### 4.10 Permissions

| Screen ID | Entry | SwiftUI | 상태 | Required actions |
|---|---|---|---|---|
| `permission.camera.priming` | camera notDetermined | `CameraPermissionPriming` | Implemented | `permission.camera.priming.allow`, `permission.camera.priming.skip` |
| `permission.camera.denied` | camera denied | `CameraPermissionDenied` | Implemented | `permission.camera.denied.openSettings`, `permission.camera.denied.dismiss` |
| `permission.photos.priming` | photos notDetermined | `PhotosPermissionPriming` | Implemented | `permission.photos.priming.allow`, `permission.photos.priming.skip` |
| `permission.photos.denied` | photos denied | `PhotosPermissionDenied` | Implemented | `permission.photos.denied.openSettings`, `permission.photos.denied.dismiss` |
| `permission.notifications.priming` | notification priming | `NotificationsPermissionPriming` | Implemented | `permission.notifications.priming.allow`, `permission.notifications.priming.skip` |
| `permission.notifications.denied` | notification denied | `NotificationsPermissionDenied` | Implemented | `permission.notifications.denied.openSettings`, `permission.notifications.denied.dismiss` |
| `permission.location.priming` | location notDetermined | `LocationPermissionPriming` | Implemented | `permission.location.priming.allow`, `permission.location.priming.skip` |
| `permission.location.denied` | location denied | `LocationPermissionDenied` | Implemented | `permission.location.denied.openSettings`, `permission.location.denied.dismiss` |

## 5. QA Priority Buckets

### P0: App must be usable

| Flow | Screens | Pass condition |
|---|---|---|
| First launch | Onboarding, Login, RootShell | 앱 설치 후 크래시 없이 루트 진입 |
| Guest browse | Login, Marketplace, Search, FilterDetail | 비로그인으로 둘러보기 가능, gated action은 로그인으로 유도 |
| Auth profile | Login, EmailLogin, Profile, EditProfile | 로그인/가입/프로필 저장이 실제 Firebase Functions와 연결 |
| Marketplace detail | Marketplace, Search, FilterDetail | 카드 탭, 상세, 공유, 태그 이동이 정상 |
| Camera basic | Camera, CapturePreview | 실기기에서 권한 허용 후 촬영/저장/공유 가능 |

### P1: Core commerce/social

| Flow | Screens | Pass condition |
|---|---|---|
| Download/apply | FilterDetail, FilterDownload, FilterAfterDownload, Camera | 다운로드 완료 후 카메라 적용 상태로 이어짐 |
| Wallet/IAP | Wallet, Topup, Transactions, PaymentFailed | StoreKit sandbox에서 충전/복원/실패 분기 확인 |
| Reviews | ReviewsList, ReviewCompose, Rating | 작성/별점/helpful/게스트 분기 확인 |
| Profile/social | Profile, Followers, Following, ForYou, FollowingFeed | 팔로우/프로필 이동/피드 액션 확인 |

### P2: Maker/admin/ops

| Flow | Screens | Pass condition |
|---|---|---|
| Maker create | Editor, LUT, Draft, Upload, MyFilters | 초안 생성부터 제출까지 상태 유지 |
| Moderation | ModQueue, ModDetail, FilterRejected | 승인/반려/이의제기/수정 진입 확인 |
| Data rights | Settings, DataExport, AccountDeletion, Refund | 정책성 액션이 실수 없이 확인 단계 포함 |

## 6. Action Contract

모든 액션은 아래 계약 중 하나로 분류한다.

| Contract | 의미 | QA 방법 |
|---|---|---|
| `navigate` | `NavigationLink` 또는 route append | 대상 화면 title/accessibility ID 확인 |
| `present-sheet` | sheet/confirmationDialog/share/photo picker | 시트 표시와 dismiss 확인 |
| `present-cover` | camera 등 fullScreenCover | 표시, dismiss, state 유지 확인 |
| `mutate-state` | 토글/슬라이더/선택 상태 변경 | UI label/value/accessibility value 변화 확인 |
| `callable` | Firebase Functions 호출 | 성공/실패/로딩/재시도 확인 |
| `firestore-listener` | Firestore snapshot 기반 표시 | seed 변경 후 UI 갱신 확인 |
| `external` | URL, Mail, App Settings, StoreKit, Stripe | 실기기 또는 sandbox에서 열림 확인 |
| `mock-only` | 현재 mock/no-op | QA finding으로 실제 구현 필요 여부 기록 |

## 7. Current Known Risk Before QA

| Risk | 영향 | QA에서 확인할 것 |
|---|---|---|
| action 문서와 실제 `accessibilityIdentifier`가 다시 어긋날 수 있음 | E2E selector 실패 가능 | 새 화면/버튼 변경 시 `NAVIGATION.md`, 본 문서, `AppRoute.primaryActions`를 함께 갱신 |
| mock route id가 title 문자열인 곳 존재 | Firestore document id와 불일치 가능 | 실제 UUID filter에서 상세/리뷰/다운로드 확인 |
| 프로필 avatar 변경 | 현재 QA 대상은 PhotosPicker 선택과 로컬 preview/persist 경로이며, 원격 Storage 업로드/URL 배포는 별도 백엔드 작업 필요 | 선택 이미지가 EditProfile/Profile에 반영되는지 확인하고, 릴리스 전 Storage 업로드 이슈 분리 |
| 팔로우 리스트 | Firestore root `follows` edge와 `users/{uid}` profile/count listener를 사용 | 실제 Firebase seed에서 followers/following row, count, toggle round-trip 확인 |
| 상세 backend metadata | `getFilterDetail`이 tags, samples, reviews, review/like/download count, userHasLiked를 내려주는 계약으로 확장 | 실제 filter 문서와 subcollection seed에서 detail UI count/preview 표시 확인 |
| Push 권한 요청이 앱 시작 시 발생 가능 | 첫 실행 UX 회귀 | Onboarding/Login 전 알림 prompt 발생 여부 |
| Payout은 closed-loop coin 정책상 후순위 | 불필요한 진입점 노출 위험 | 사용자가 볼 수 있는 entry point인지 확인 |
| StoreKit/Google/Apple sign-in은 sandbox/실기기 의존 | 시뮬레이터만으로 검증 불가 | 실기기 QA checklist 별도 표시 |
| 저장/즐겨찾기/컬렉션 사용자 상태 | `/users/{uid}/savedFilters`, `/users/{uid}/favorites`, `/users/{uid}/collections` snapshot listener가 단일 출처 | 동일 uid 재실행/다른 디바이스 동기화와 실패 rollback 확인 |
| 알림 설정 동기화 | 사용자 입력만 debounced Firestore write를 예약하고 remote snapshot은 재저장하지 않음 | 빠른 토글 6개 변경 후 최종 상태 1회성 반영, listener write loop 없음 |
| Foreground push 표시 | `PushRegistration` foreground delegate가 notificationPreferences와 quiet hours를 적용 | 카테고리 OFF/quiet hours 중에는 banner/sound 없이 badge만 허용 |
| Push device 등록 | 로그인 전 수신한 FCM token은 캐시하고 로그인 후 재저장 또는 token fetch 재시도 | 신규 사용자 첫 로그인 후 `/users/{uid}/devices/{deviceId}` 생성 확인 |
| Pro 유료 필터 접근 | `isProActive && priceCoins > 0`이면 코인 구매 callable 없이 saved filter 동기화 | PaywallSingle에서 Pro 포함 라벨, 차감 없는 after-download 이동 확인 |
| 업로드 취소 | `upload.cancel`은 저장 후 나가기/버리고 나가기/계속 작성의 3-way dialog | 저장/버리기 선택 시 화면 dismiss, 계속 작성은 stay |
| 필터 패키지 다운로드 | UUID 기반 `filter.download`는 `signedDownloadURL`을 stream fetch 후 로컬 `.fmpkg` 저장 | 저장 성공 후에만 savedFilters marker 작성, 실패 시 retry 노출 |
| 데이터 내보내기 이력 | `settings.export`는 `/users/{uid}/exportRequests` listener를 단일 출처로 사용 | backend status/downloadURL 갱신이 화면 이력에 자동 반영 |
| 메이커 draft 리스트 | `maker.myFilters`는 `/users/{uid}/makerDrafts` listener를 단일 출처로 사용 | draft 저장/상태 변경이 재시작/다른 디바이스에서 복원 |
| Deep link destination | `DeepLinkDestination`은 모든 `AppRoute` case를 실제 화면으로 매핑하고 raw enum fallback을 노출하지 않음 | 새 route 추가 시 컴파일 단계에서 switch 누락 확인 |
| 평점 폼 기본값 | `reviews.rating`은 빈 상태로 시작하고 별점 선택 전 submit 불가 | placeholder/글자수 제한/error 표시 확인 |

## 8. Definition Gate Before QA

QA를 시작하기 전 반드시 아래 순서로 정의를 고정한다.

| Step | Check | Evidence |
|---|---|---|
| 1 | `AppRoute`의 모든 case가 §4 Screen Registry에 존재 | Screen ID, route, SwiftUI, 상태, Required actions |
| 2 | 루트 탭과 권한 전용 화면이 §3/§4.10에 존재 | tab ID, permission allow/dismiss/openSettings ID |
| 3 | 각 화면의 버튼/탭/제스처가 action contract로 분류됨 | `navigate`, `present-sheet`, `mutate-state`, `external`, `mock-only` |
| 4 | SwiftUI에서 E2E 가능한 action은 stable `accessibilityIdentifier` 보유 | `ActionSurfaceSmokeTests`, `P0CoreActionTests` |
| 5 | 외부 의존 액션은 자동 QA와 수동 QA를 분리 | `QA_FINDINGS.md` Remaining Manual QA Gates |

이 gate가 깨진 화면은 구현 완료가 아니라 `Partial` 또는 `Blocked`로 유지한다.

## 9. QA Execution Order

1. `npm --prefix functions test`
2. `./scripts/test.sh`로 unit + P0/Phase A/Phase D AppUITests 실행
3. `docs/QA_TEST_PLAN.md`의 P0 수동 QA
4. P0 FAIL 항목 수정
5. P1 수동 QA 및 E2E 추가
6. P2/ops 화면 QA
7. `docs/QA_FINDINGS.md` 또는 이슈로 FAIL 항목 분리

## 9.1 Automated Coverage Snapshot

| Date | Suite | Coverage |
|---|---|---|
| 2026-05-08 | `P0CoreActionTests` | Login/email auth contract, root tab shell guest flow, profile/settings/wallet/edit entrypoints, settings data/help entrypoints |
| 2026-05-08 | `PhaseAE2ETests` | Marketplace download/apply/camera, camera HUD, built-in filters, photo edit, deep links |
| 2026-05-08 | `PhaseDE2ETests` | Reviews, rating, guest auth gate, follow lists, For You/following feed social actions |
| 2026-05-09 | `ActionSurfaceSmokeTests` | Maker/editor/upload including reference photo preview and signature sample controls, account/data rights, notifications, reports, collections, moderation, wallet/commerce, wallet transactions/order/refund, Pro plan/invoice, payout placeholders, search, filter detail sample gallery/download/paywall/after-download, universal link landing, edit profile, help center, capture preview, permission priming/denied action contracts |

## 9.2 Latest Verification

| Date | Command | Result |
|---|---|---|
| 2026-05-08 | Route/action document audit against `AppNavigation.swift` | PASS |
| 2026-05-08 | `AppRoute.primaryActions` ID alignment audit for report/moderation/refund/payment/insufficient balance | PASS |
| 2026-05-08 | `xcodebuild ... -only-testing:AppUITests/P0CoreActionTests` | PASS, 8 tests |
| 2026-05-08 | `xcodebuild ... -only-testing:AppUITests/PhaseAE2ETests` | PASS, 9 tests |
| 2026-05-09 | `xcodebuild ... -only-testing:AppUITests/ActionSurfaceSmokeTests` | PASS, 3 tests, xcresult `Test-moodit-2026.05.08_23-58-04-+0900.xcresult` |
| 2026-05-09 | `./scripts/test.sh` | PASS, unit suites + 24 AppUITests, xcresult `Test-moodit-2026.05.09_00-03-22-+0900.xcresult` |
| 2026-05-09 | `xcodebuild ... -only-testing:AppUITests/ActionSurfaceSmokeTests/testMarketplaceSupportPermissionAndPreviewSurfaces` | PASS, 1 test, xcresult `Test-moodit-2026.05.09_00-34-24-+0900.xcresult` |
| 2026-05-09 | `xcodebuild ... -only-testing:AppUITests/ActionSurfaceSmokeTests` | PASS, 5 tests, xcresult `Test-moodit-2026.05.09_00-36-43-+0900.xcresult` |
| 2026-05-09 | `./scripts/test.sh` | PASS, unit suites + 26 AppUITests, xcresult `Test-moodit-2026.05.09_00-44-00-+0900.xcresult` |
| 2026-05-09 | `npm --prefix functions test` | PASS, 57 tests |
| 2026-05-09 | `xcodebuild ... -only-testing:AppUITests/ActionSurfaceSmokeTests` | PASS, 5 tests, includes `filter.detail.tags`, xcresult `Test-moodit-2026.05.09_01-01-23-+0900.xcresult` |
| 2026-05-09 | `env XDG_CONFIG_HOME=/private/tmp/firebase-config FIREBASE_CLI_DISABLE_UPDATE_CHECK=true npm --prefix functions run test:rules` | PASS, Firestore emulator rules, 11 tests |
| 2026-05-08 | `npm --prefix functions test` | PASS, 57 tests |
| 2026-05-09 | `./scripts/test.sh` | PASS, unit suites + 26 AppUITests, xcresult `Test-moodit-2026.05.09_01-16-48-+0900.xcresult` |
| 2026-05-09 | `xcodebuild ... -only-testing:AppUITests/ActionSurfaceSmokeTests/testCommerceWalletAndPayoutSurfaces` | PASS, verifies 4 coin package actions and monthly/yearly Pro actions, xcresult `Test-moodit-2026.05.09_01-30-13-+0900.xcresult` |
| 2026-05-09 | `./scripts/test.sh` | PASS after StoreKit action fallback, unit suites + 26 AppUITests, xcresult `Test-moodit-2026.05.09_01-33-17-+0900.xcresult` |
| 2026-05-09 | `NAVIGATION.md` stale mockup action ID audit | PASS, current SwiftUI route/action names aligned |
| 2026-05-09 | `./scripts/test.sh` | PASS after definition alignment, unit suites + 26 AppUITests, xcresult `Test-moodit-2026.05.09_01-56-02-+0900.xcresult` |
| 2026-05-09 | `xcodebuild ... -only-testing:FilterEngineTests/PhotoFilterRendererTests` | PASS, editor reference preview renderer regression, xcresult `Test-moodit-2026.05.09_03-12-31-+0900.xcresult` |
| 2026-05-09 | `xcodebuild ... -only-testing:ModelsTests/FilterManifestTests` | PASS, `signatureSampleURL` decode coverage, xcresult `Test-moodit-2026.05.09_03-27-46-+0900.xcresult` |
| 2026-05-09 | `xcodebuild ... -only-testing:AppUITests/ActionSurfaceSmokeTests/testMakerEditorAndUploadSurfaces -only-testing:AppUITests/ActionSurfaceSmokeTests/testMarketplaceSupportPermissionAndPreviewSurfaces` | PASS, editor reference controls, upload signature controls, detail sample gallery, xcresult `Test-moodit-2026.05.09_03-29-09-+0900.xcresult` |
| 2026-05-09 | `xcodebuild ... -destination 'generic/platform=iOS Simulator' ... build` | PASS after #55/#57 |
| 2026-05-09 | `npm run build` in `functions` + `node --test test/getFilterDetail.test.mjs` | PASS, Cloud Function detail response includes `signatureSampleURL` |
| 2026-05-09 | `npm --prefix functions test` | PASS after filter detail metadata expansion, 57 tests |
| 2026-05-09 | `xcodebuild ... -destination 'generic/platform=iOS Simulator' ... build` | PASS after QA doc update/current issue batch |
| 2026-05-09 | `xcodebuild ... -destination 'generic/platform=iOS Simulator' ... build` | PASS after P0/P1 issue batch (#185/#186/#187/#188/#189/#190/#192/#207/#203) |
| 2026-05-09 | `xcodebuild ... -only-testing:FilterEngineTests/CubeLUTParserTests -only-testing:MarketplaceTests/SocialRepositoriesTests test` | PASS, LUT size cap and self-block guard covered |
| 2026-05-09 | `xcodebuild ... -destination 'generic/platform=iOS Simulator' ... build` | PASS after P0 state/account deletion batch (#140/#147/#227) |
| 2026-05-09 | `npm --prefix functions test` | PASS after backend P0 security batch (#142/#144/#137), 61 tests |
| 2026-05-09 | `npm --prefix functions run test:rules` | PASS after wallet/pro/refund rules hardening (#136), 12 tests |
| 2026-05-09 | `xcodebuild ... -destination 'generic/platform=iOS Simulator' ... build` | PASS after FirebaseAppCheck iOS provider wiring (#137) |
| 2026-05-09 | `xcodebuild ... -destination 'generic/platform=iOS Simulator' ... build` | PASS after notifications inbox QA batch (#216/#217/#218/#239/#240/#243) |
| 2026-05-09 | `xcodebuild ... -destination 'generic/platform=iOS Simulator' ... build` | PASS after saved/favorites/wallet reconcile batch (#219/#220/#249) |
| 2026-05-09 | `npm --prefix functions run test:rules` | PASS after savedFilters/favorites owner rules, 13 tests |
| 2026-05-09 | `xcodebuild ... -destination 'generic/platform=iOS Simulator' ... build` | PASS after notification settings debounce/system permission batch (#247/#248) |
| 2026-05-09 | `xcodebuild ... -destination 'generic/platform=iOS Simulator' ... build` | PASS after foreground push preference gate (#223) |
| 2026-05-09 | `xcodebuild ... -destination 'generic/platform=iOS Simulator' ... build` | PASS after FCM token auth retry (#222) |
| 2026-05-09 | `xcodebuild ... -destination 'generic/platform=iOS Simulator' ... build` | PASS after Pro included paid-filter download path (#253) |
| 2026-05-09 | `xcodebuild ... -destination 'generic/platform=iOS Simulator' ... build` | PASS after upload cover cancel dialog fix (#254) |
| 2026-05-09 | `xcodebuild ... -destination 'generic/platform=iOS Simulator' ... build` | PASS after signed filter package download wiring (#252) |
| 2026-05-09 | `xcodebuild ... -destination 'generic/platform=iOS Simulator' ... build` | PASS after data export listener wiring (#250) |
| 2026-05-09 | `npm --prefix functions run test:rules` | PASS after exportRequests owner create/read rules (#250), 14 tests |
| 2026-05-09 | `xcodebuild ... -destination 'generic/platform=iOS Simulator' ... build` | PASS after makerDrafts listener/write wiring (#251) |
| 2026-05-09 | `npm --prefix functions run test:rules` | PASS after makerDrafts owner rules (#251), 15 tests |
| 2026-05-09 | `xcodebuild ... -destination 'generic/platform=iOS Simulator' ... build` | PASS after DeepLinkDestination full AppRoute coverage (#246) |
| 2026-05-09 | `xcodebuild ... -destination 'generic/platform=iOS Simulator' ... build` | PASS after rating form default/validation fix (#245) |

## 10. Definition of Done

화면 하나를 완료로 표시하려면 아래를 모두 만족해야 한다.

| 항목 | 기준 |
|---|---|
| 화면 진입 | root/tab/deep link/navigation route 중 최소 1개 경로로 진입 가능 |
| 주요 액션 | 이 문서의 Required actions가 모두 동작 또는 명시적 mock-only |
| 상태 | loading/empty/error/success 중 해당 화면에 필요한 상태 존재 |
| 인증 분기 | guest/signed-in 권한 차이가 필요한 액션은 분기 확인 |
| 접근성 ID | E2E 가능한 stable identifier 존재 |
| 테스트 | P0/P1 화면은 E2E 또는 수동 QA 기록 존재 |
| 문서 | 변경 시 이 문서와 `QA_TEST_PLAN.md` 갱신 |
