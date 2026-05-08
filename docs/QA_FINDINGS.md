# moodit QA Findings

> 작성일: 2026-05-09 KST  
> 상태: Current  
> 기준 문서: [SCREEN_ACTIONS_QA_DEFINITION.md](./SCREEN_ACTIONS_QA_DEFINITION.md), [QA_TEST_PLAN.md](./QA_TEST_PLAN.md)

## Completion Audit

| Requirement | Evidence | Status |
|---|---|---|
| 모든 앱 화면과 액션을 먼저 정의 | `SCREEN_ACTIONS_QA_DEFINITION.md`가 `AppRoute` 전체 케이스와 root tab, permission-only 화면을 포함 | Done |
| 버튼/액션 흐름과 SwiftUI 매핑 기준 확보 | `SCREEN_ACTIONS_QA_DEFINITION.md`의 Screen Registry와 `QA_TEST_PLAN.md`의 수동 QA 체크리스트 | Done |
| 자동 QA 실행 | `./scripts/test.sh` PASS, unit suites + 26 AppUITests, xcresult `Test-moodit-2026.05.09_00-44-00-+0900.xcresult` | Done |
| Backend callable unit QA | `npm --prefix functions test` PASS, 57 tests | Done |
| Firestore Rules QA | `npm --prefix functions run test:rules` PASS with Firestore emulator, 11 tests | Done |
| 누락된 액션/화면 selector 보정 | `ActionSurfaceSmokeTests`, `P0CoreActionTests`와 관련 SwiftUI accessibility ID 보강 | Done |
| 실패한 automated QA 수정 | paywall UI-test Firebase 호출 우회, filter download cancel, help center/capture preview/permission route 보강 | Done |
| 실기기/외부 서비스 QA | Apple/Google Sign-In, StoreKit sandbox, 실제 카메라 촬영/저장/공유, APNs/FCM push, App Settings deep link | Blocked |

## Automated Verification

| Date | Command | Result |
|---|---|---|
| 2026-05-09 | `xcodebuild ... -only-testing:AppUITests/ActionSurfaceSmokeTests/testMarketplaceSupportPermissionAndPreviewSurfaces` | PASS, 1 test |
| 2026-05-09 | `xcodebuild ... -only-testing:AppUITests/ActionSurfaceSmokeTests` | PASS, 5 tests, includes `filter.detail.tags` |
| 2026-05-09 | `./scripts/test.sh` | PASS, unit suites + 26 AppUITests |
| 2026-05-09 | `npm --prefix functions test` | PASS, 57 tests |
| 2026-05-09 | `env XDG_CONFIG_HOME=/private/tmp/firebase-config FIREBASE_CLI_DISABLE_UPDATE_CHECK=true npm --prefix functions run test:rules` | PASS, Firestore emulator rules, 11 tests |
| 2026-05-09 | `git diff --check` | PASS |
| 2026-05-09 | `./scripts/test.sh` | PASS, unit suites + 26 AppUITests, xcresult `Test-moodit-2026.05.09_01-16-48-+0900.xcresult` |
| 2026-05-09 | `xcodebuild ... -only-testing:AppUITests/ActionSurfaceSmokeTests/testCommerceWalletAndPayoutSurfaces` | PASS, 4 coin package actions and monthly/yearly Pro actions verified, xcresult `Test-moodit-2026.05.09_01-30-13-+0900.xcresult` |
| 2026-05-09 | `./scripts/test.sh` | PASS after StoreKit action fallback, unit suites + 26 AppUITests, xcresult `Test-moodit-2026.05.09_01-33-17-+0900.xcresult` |
| 2026-05-09 | `./scripts/test.sh` | PASS after screen/action definition alignment, unit suites + 26 AppUITests, xcresult `Test-moodit-2026.05.09_01-56-02-+0900.xcresult` |
| 2026-05-09 | `xcodebuild ... -only-testing:FilterEngineTests/PhotoFilterRendererTests` | PASS, editor reference preview render path verified, xcresult `Test-moodit-2026.05.09_03-12-31-+0900.xcresult` |
| 2026-05-09 | `xcodebuild ... -only-testing:ModelsTests/FilterManifestTests` | PASS, `signatureSampleURL` model decode verified, xcresult `Test-moodit-2026.05.09_03-27-46-+0900.xcresult` |
| 2026-05-09 | `xcodebuild ... -only-testing:AppUITests/ActionSurfaceSmokeTests/testMakerEditorAndUploadSurfaces -only-testing:AppUITests/ActionSurfaceSmokeTests/testMarketplaceSupportPermissionAndPreviewSurfaces` | PASS, editor reference controls, upload signature controls, and detail sample gallery verified, xcresult `Test-moodit-2026.05.09_03-29-09-+0900.xcresult` |
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

## Remaining Manual QA Gates

| Gate | Why automated QA is insufficient | Required setup | Pass evidence |
|---|---|---|---|
| Apple Sign-In | Native auth sheet and real credential flow cannot be fully asserted by simulator smoke tests | Apple developer capability, signed build; see `EXTERNAL_SETUP.md` §3, §5 | Tap `auth.apple`, complete Apple sheet, app reaches authenticated root with user profile populated |
| Google Sign-In | `Sources/App/Resources/GoogleService-Info.plist` exists, but external account picker and Firebase credential exchange still require interactive account QA | Test Google account, Firebase Auth provider enabled; see `EXTERNAL_SETUP.md` §6, §7 | Tap `auth.google`, complete Google account picker, Firebase user appears and app reaches authenticated root |
| StoreKit purchase/restore | UI-test mode now verifies the 4 coin package buttons and monthly/yearly Pro buttons, but product availability, real purchase, restore, and cancellation still require StoreKit sandbox or a valid local `.storekit` config | Sandbox tester plus App Store Connect products, or add local `.storekit`; see `EXTERNAL_SETUP.md` Phase 6 | 100/550/1200/3000 coin purchase updates wallet, monthly/yearly Pro activates Pro state, restore recovers entitlement |
| Camera capture | Simulator cannot validate real camera session, photo quality, focus, capture latency | Physical iPhone | `camera.shutter` captures a photo, preview opens, focus/flip/flash/timer controls remain responsive |
| Photo save/share | Actual Photos permission and share sheet destinations are OS/external surfaces | Physical iPhone with Photos access | `preview.save` writes to Photos and `preview.share` opens a working destination |
| Push notification | APNs token, FCM registration, notification tap routing require device/APNs path | Physical iPhone, Firebase/APNs config; see `EXTERNAL_SETUP.md` §11 | Console logs FCM token persistence, Firebase Console test notification arrives, tap routes to expected app screen |
| Push first-login registration | FCM token timing depends on Firebase/APNs and can arrive before Auth is ready | Fresh install on physical iPhone, Firebase/APNs config | After first login, `/users/{uid}/devices/{deviceId}` exists even if token was issued pre-login |
| App Settings links | `UIApplication.openSettingsURLString` leaves the app and needs OS-level validation | Device or interactive simulator run | Permission/settings buttons leave app to moodit Settings page and returning preserves app state |
| PhotosPicker reference/signature import | Automated QA verifies entry points only; OS Photos picker, permission prompt, and real image normalization require interactive QA | Simulator with seeded Photos library or physical iPhone with Photos access | `editor.reference.photo.pick` updates `editor.preview`; `upload.signature.photo.pick` updates `upload.signature.preview`; clear/sample fallback works |
| Profile avatar import | EditProfile now opens PhotosPicker and stores a normalized local avatar preview, but OS picker and real image selection need interactive QA | Simulator with seeded Photos library or physical iPhone with Photos access | `profile.edit.avatar.change` updates the avatar preview and save/dismiss preserves the edited profile state |
| Signature sample R2 upload | UI can select a signature sample and backend preserves `signatureSampleURL`, but real image upload/final URL wiring is not yet connected in the SwiftUI submit flow | Backend endpoint or storage workflow for signature image upload | Submitted filter detail contains a real `signatureSampleURL`; detail gallery first tile displays the uploaded image |

## Open QA Notes

| Area | Note | Follow-up |
|---|---|---|
| `filter.detail.tag.*` | `ActionSurfaceSmokeTests` verifies the stable `filter.detail.tags` container. Individual lazy tag chip selectors are still left for manual QA because SwiftUI accessibility flattening was unstable in the simulator. | Verify manual tag navigation through `QA_TEST_PLAN.md` §5.9, then add a targeted chip tap test if selector stability improves. |
| `filter.detail.sample.reference.*` | Automated QA verifies the gallery and portrait reference tile. Full visual correctness still needs manual inspection because rendered LUT output is image-based. | Verify `QA_TEST_PLAN.md` §5.10~§5.12 on simulator/device for all four reference samples and cache re-entry behavior. |
| `filter.detail.like` | Like CTA is now stateful for real filters and mock detail previews, but production favorite/like semantics still depend on the final backend distinction between saved/favorite/like. | Confirm whether detail heart should write favorites, likes, or both before release analytics/backfill. |
| `social.followers` / `social.following` | Follow lists now read Firestore root `follows` edges and user profile docs, with local fallback for unauthenticated QA. | Seed Firebase with follow edges and verify row population, empty states, follow toggle, and follower/following counter triggers. |
| `market.header.coinBalance` | Marketplace exposes wallet navigation through the balance pill. Product availability is still covered by StoreKit manual QA. | Verify logged-in wallet listener updates the pill and tapping opens `WalletScreen`. |
| Profile username copy | Edit profile/settings/data export copy now uses "유저네임" instead of "핸들"; existing accessibility IDs remain `profile.edit.handle*` for selector stability. | Manual Korean copy pass before App Store screenshots. |
| Filter detail download | Detail CTA now owns and cancels its download task and only transitions to completed after `store.download` succeeds. | Manual offline/Firebase permission-denied QA should verify the failure alert and no stale completed CTA after dismissal. |
| Filter package download | FilterDownloadProgress now uses `signedDownloadURL` for UUID-based filters, streams bytes to `Application Support/moodit/downloaded-packages/<filterId>.fmpkg`, and only writes savedFilters after the package fetch succeeds. | Firebase/R2 QA should download a real large and small package, verify local file existence, progress behavior, retry on network failure, and offline apply wiring in the renderer path. |
| Reviews list listener | Reviews Firestore listener is removed on disappear and now decodes `stars`, `helpfulCount`, and `isVerifiedDownload`. | Firebase seeded review QA should verify live updates after navigating away/back. |
| Reviews mini card | ReviewsListScreen now resolves the filter title, maker, rating/download metadata, and cover image from local store or `filters/{filterId}` instead of showing a generic UUID fallback. | Push/deep-link QA should open a UUID filter's review list directly and verify the mini card matches the source notification/detail screen. |
| Review helpful toggle | Review helpful state now syncs through `/users/{uid}/reviewHelpful` and updates `filters/{filterId}/reviews/{reviewId}.helpfulCount` in a transaction with optimistic rollback. | Firebase QA should verify same-user re-entry preserves the filled thumb state and double tap cannot create duplicate helpful edges. |
| Refund request flow | OrdersHistory now exposes a refund action for every order plus the generic support action. RefundRequest accepts a direct/manual order ID or a read-only order ID prefilled from order history, caps the reason at 2000 chars, and dismisses after a successful callable submit. | Firebase QA should seed purchase ledger rows, open `orders.refund_request.<orderId>`, verify the prefilled ID, submit a valid reason, and confirm the Cloud Function receives trimmed `orderId`/`reason`. |
| For You feed | ForYouFeedScreen now builds hero, rail, reason text, and maker spotlight from `MooditStore` filter data instead of hardcoded mock content. Hero/rail routes use filter UUIDs and the hero bookmark calls `MooditStore.toggleFavorite`. | Firebase QA should seed approved filters, verify hero/rail detail navigation by UUID, favorite persistence, and empty-state behavior when no filters are available. |
| Following feed | FollowingFeedScreen now listens to root `follows` edges, loads approved filters from followed makers, uses filter UUIDs for detail/review routes, persists likes/hides in `/users/{uid}/feedActions`, and saves posts through favorites. | Firebase QA should follow a maker with approved filters, verify new-filter card/post rows, like/hide persistence, favorite sync, and true empty state for users with no followed activity. |
| Block list and review author block | BlockListScreen now listens to root `blocks` edges scoped by `actorUid`, shows load/unblock failures with retry/error copy, and deletes by UID edge ID. ReviewsListScreen writes `blocks/{actorUid}_{targetUid}` from `social.review.more.block`, stores target handle/display name as metadata, and filters blocked author reviews by UID. | Firebase QA should block a review author, verify the block appears immediately in Settings → Block List, relaunch and confirm the author remains hidden, then unblock and verify the row is removed. |
| Notification follow action | Follow notification action now writes a root `follows/{actor}_{target}` edge before marking the notification read. | Seed follow notification and verify count trigger/list update in Firebase. |
| Root wallet/profile subscription | RootShell now starts the wallet/profile/auth listener on cold start, and MooditStore listener callbacks re-enter MainActor before publishing state. | Device/Firebase QA should verify cold-start balance, Pro status, profile handle onboarding, and notification preference state. |
| Account deletion | Account deletion confirmation now calls the `deleteAccount` Cloud Function before showing the receipt and signs out after success. | Manual Firebase QA should verify `users/{uid}` soft-delete fields and failure alert behavior. |
| Data export requests | DataExportScreen now reads `/users/{uid}/exportRequests` through a listener, maps backend statuses/download URLs into the history list, and rules allow owner create/read only. | Backend QA should update an export request to `ready` with `downloadURL` and verify the button appears across app restart/second device. |
| Maker drafts list | Maker draft metadata now syncs through `/users/{uid}/makerDrafts`, and MyFilters repopulates from a listener after restart/second-device login. Direct signature sample photo bytes are not stored in this metadata doc. | Firebase QA should save multiple drafts, force-quit/relogin, verify MyFilters restoration, then confirm image binary persistence once Storage upload wiring is added. |
| Active editor draft autosave | The in-progress editor draft now persists per uid to local UserDefaults and `/users/{uid}/editorDrafts/current`, restoring after cold start/relogin and syncing metadata across devices. Logout clears in-memory state but keeps the saved draft for the same uid. | QA should edit name/parameters/tags, force-quit, relaunch, and verify the editor restores. Then login on a second device and verify the remote current draft appears; direct signature photo bytes remain local-only until image storage wiring. |
| App Check | Callable Cloud Functions now enforce App Check and iOS registers AppCheckDebugProviderFactory in DEBUG / AppAttestProviderFactory in release. | Register debug tokens in Firebase Console for dev devices/CI before exercising callable flows. |
| Wallet security rules | Wallet, ledger, entitlements, Pro status, and refund request subcollections are owner-read/server-write only. | Emulator rules tests pass; production Firebase rules deploy remains a release gate. |
| Pro subscription verifier | Pro receipts are now idempotent, owner-scoped, and expired/revoked JWS metadata maps to inactive Pro state. | StoreKit sandbox renewal/cancel manual QA remains required. |
| Notifications inbox | Notification rows now compute relative time/buckets from `createdAt`, expose literal Korean labels instead of unresolved keys, support older-page loading, and surface markRead/follow errors. | Firebase QA should seed 100+ notifications and verify load-more, badge count, read state, and follow edge writes. |
| Notification settings | Category and quiet-hours changes now save through user-input bindings with an 800ms debounce, while remote listener snapshots only update local state. The system card reads actual iOS notification authorization status. | Manual QA should toggle several categories quickly and verify one final Firestore document state, then change iOS notification permission in Settings and confirm the card refreshes on return. |
| Foreground push gating | Foreground push presentation now maps `kind`/`type`/`category` payloads to notification preferences and suppresses banner/sound during disabled categories or quiet hours. | Device/APNs QA should send foreground pushes for like/review/wallet/system kinds with preferences on/off and quiet hours spanning the current time. |
| Push device registration | FCM tokens received before login are cached, and auth state changes retry device registration or explicitly fetch the current token. | New-user device QA should verify `/users/{uid}/devices/{deviceId}` appears after login even when the token was issued before auth. |
| Saved/favorites state | Saved filters and favorites now sync through `/users/{uid}/savedFilters` and `/users/{uid}/favorites` snapshot listeners with optimistic rollback on failed remove/favorite writes. | Firebase QA should verify download, favorite toggle, remove download, app relaunch, and second-device sync under the same uid. |
| Collections state | FavoritesCollectionScreen now listens to `/users/{uid}/collections`, derives a non-negative custom collection count, creates/deletes collection documents directly under owner-scoped Firestore Rules, and surfaces failures through alerts. | Firebase QA should create a collection, leave and re-enter the screen, verify it persists on a second device, then delete it and confirm the document is removed. |
| Wallet optimistic reconcile | Coin credit optimism now falls back to a direct wallet balance reload if the listener does not reconcile within 10 seconds. | StoreKit/Firebase QA should verify top-up UI immediately changes, then converges to `/users/{uid}/wallet/balance.value`. |
| Moderation detail | Moderation detail now loads the target filter document, displays cover/signature preview, metadata, tags, and engine fields, disables repeated approve/reject calls, and offers a 5-second undo through `undoModerationDecision`. | Admin Firebase QA should approve/reject a pending filter, verify queue listener removal, test undo within 5 seconds, and confirm the detail screen auto-dismisses when not undone. |
| Pro paid-filter access | Active Pro users now see paid filters as included in PaywallSingle and download them without `purchaseFilter` coin deduction. There is no ad SDK path in the current app build. | StoreKit sandbox QA should activate Pro, open a paid filter, confirm no coin balance change, and verify saved filter sync. |
| Insufficient balance retry | InsufficientBalanceScreen now keeps the original `filterID`, watches live wallet balance, auto-retries `purchaseFilter` once balance is sufficient, exposes a manual `insufficient.purchase.retry` CTA, and routes to FilterAfterDownload after success. | StoreKit/Firebase QA should start a paid filter purchase with low balance, top up, return to the insufficient screen, and verify automatic or manual completion without returning to detail. |
| Payout | Current screens are marked `MockOnly`; automated QA verifies placeholder surfaces, not real Stripe payout behavior. | Keep hidden/controlled until payout backend scope is defined. |
| Firebase-backed mutations | Several screens expose state and action contracts, but production write/read behavior still depends on real Firebase setup. | Run manual QA with seeded Firebase project before release. |
