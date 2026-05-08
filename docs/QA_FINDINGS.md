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

## Remaining Manual QA Gates

| Gate | Why automated QA is insufficient | Required setup | Pass evidence |
|---|---|---|---|
| Apple Sign-In | Native auth sheet and real credential flow cannot be fully asserted by simulator smoke tests | Apple developer capability, signed build; see `EXTERNAL_SETUP.md` §3, §5 | Tap `auth.apple`, complete Apple sheet, app reaches authenticated root with user profile populated |
| Google Sign-In | `Sources/App/Resources/GoogleService-Info.plist` exists, but external account picker and Firebase credential exchange still require interactive account QA | Test Google account, Firebase Auth provider enabled; see `EXTERNAL_SETUP.md` §6, §7 | Tap `auth.google`, complete Google account picker, Firebase user appears and app reaches authenticated root |
| StoreKit purchase/restore | UI-test mode now verifies the 4 coin package buttons and monthly/yearly Pro buttons, but product availability, real purchase, restore, and cancellation still require StoreKit sandbox or a valid local `.storekit` config | Sandbox tester plus App Store Connect products, or add local `.storekit`; see `EXTERNAL_SETUP.md` Phase 6 | 100/550/1200/3000 coin purchase updates wallet, monthly/yearly Pro activates Pro state, restore recovers entitlement |
| Camera capture | Simulator cannot validate real camera session, photo quality, focus, capture latency | Physical iPhone | `camera.shutter` captures a photo, preview opens, focus/flip/flash/timer controls remain responsive |
| Photo save/share | Actual Photos permission and share sheet destinations are OS/external surfaces | Physical iPhone with Photos access | `preview.save` writes to Photos and `preview.share` opens a working destination |
| Push notification | APNs token, FCM registration, notification tap routing require device/APNs path | Physical iPhone, Firebase/APNs config; see `EXTERNAL_SETUP.md` §11 | Console logs FCM token persistence, Firebase Console test notification arrives, tap routes to expected app screen |
| App Settings links | `UIApplication.openSettingsURLString` leaves the app and needs OS-level validation | Device or interactive simulator run | Permission/settings buttons leave app to moodit Settings page and returning preserves app state |

## Open QA Notes

| Area | Note | Follow-up |
|---|---|---|
| `filter.detail.tag.*` | `ActionSurfaceSmokeTests` verifies the stable `filter.detail.tags` container. Individual lazy tag chip selectors are still left for manual QA because SwiftUI accessibility flattening was unstable in the simulator. | Verify manual tag navigation through `QA_TEST_PLAN.md` §5.9, then add a targeted chip tap test if selector stability improves. |
| Payout | Current screens are marked `MockOnly`; automated QA verifies placeholder surfaces, not real Stripe payout behavior. | Keep hidden/controlled until payout backend scope is defined. |
| Firebase-backed mutations | Several screens expose state and action contracts, but production write/read behavior still depends on real Firebase setup. | Run manual QA with seeded Firebase project before release. |
