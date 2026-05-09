# moodit · Screen Inventory (PM View)

> **As of**: 2026-05-10. **`struct *Screen: View` 정의 67개** (코드 실측: `grep -rE "^\s*(public\s+)?struct\s+\w+Screen\s*:\s*View" Sources/`). 다중 화면을 묶은 파일: `MakerWorkflowScreens.swift`(13), `MarketplaceWorkflowScreens.swift`, `CameraWorkflowScreens.swift`, `WalletWorkflowScreens.swift`, `ProfileWorkflowScreens.swift`, `SocialDiscoveryScreens.swift`, `ModerationWorkflowScreens.swift` 등. **`AppRoute` enum cases 64개** (`Sources/App/AppNavigation.swift`).
> Action ID/QA 우선순위: [`../../docs/SCREEN_ACTIONS_QA_DEFINITION.md`](../../docs/SCREEN_ACTIONS_QA_DEFINITION.md).
>
> 본 문서는 **PM 관점**: 각 화면의 *실구현 상태 + 어느 Phase에 속하는가 + 누가 책임지는가*를 한 표에 본다. Action ID 매핑은 `docs/NAVIGATION.md`를 본다.

## 1. 5-Tab Shell

| Tab | Screen | 진입점 | 비고 |
|---|---|---|---|
| 0 | Marketplace | `MarketplaceScreen` | 검색 헤더 + 트렌딩 + 카테고리 + 신규 그리드 |
| 1 | Search | `SearchScreen` | browsing → typing → results 3 단계 |
| 2 | **Shutter** | `CameraScreen` (fullScreenCover) | 탭이 아니라 모달. 종료 시 이전 탭 복귀 |
| 3 | Saved | `SavedScreen` | 저장 / 즐겨찾기 / 컬렉션 |
| 4 | Profile | `ProfileScreen` | 알림 미확인 배지 노출 |

## 2. 화면 상태 범례

| 상태 | 의미 |
|---|---|
| ✅ Done | UI + 백엔드 연결 모두 안정 |
| 🟡 Partial | UI 있음 / 일부 백엔드·외부 연결 남음 |
| 🟠 Mock | 화면 동작 가능 / 데이터는 mock·in-memory |
| ⚪ Planned | 라우트/문서/목업만 존재 |

## 3. 그룹별 인벤토리

### 3.1 Auth / Onboarding (3)

| 화면 | 상태 | Phase | 백엔드 callable | 비고 |
|---|---|---|---|---|
| Onboarding (4-page carousel) | ✅ | 1 | — | `@AppStorage hasOnboarded` |
| Login (Apple/Google/Email/Guest) | 🟡 | 1 | Firebase Auth | 어댑터 슬롯 — 실연결 정리 중 |
| Email Login | 🟡 | 1 | Firebase Auth | UI Done / 실연결 정리 중 |

### 3.2 Camera / Photo (7)

| 화면 | 상태 | Phase | 비고 |
|---|---|---|---|
| Camera Live (`CameraScreen`) | 🟡 | 1 | HUD ✅ / `.fmpkg` 적용 미연결 |
| Capture Preview | ✅ | 1 | PhotoKit save / share sheet |
| Camera Aspect Picker (1:1/4:5/4:3/16:9) | ✅ | 1 | 2열 그리드 |
| Camera Timer (OFF/3/5/10s) | ✅ | 1 | |
| Photo Import (PHPicker) | ✅ | 1 | limited access 안내 |
| Photo Edit (필터+강도+undo/redo) | ✅ | 1 | 정지 사진 CPU 렌더 |
| Capture Detail | 🟡 | 1 | `users/{uid}/captures` |

### 3.3 Marketplace / Filter (10)

| 화면 | 상태 | Phase | 백엔드 | 비고 |
|---|---|---|---|---|
| Marketplace Home | ✅ | 1 | `listFilters` / fallback seed | trending + category + new |
| Search | ✅ | 1 | client-side filters query | 500ms debounce |
| Filter Detail Loader | ✅ | 1 | `getFilterDetail` | |
| Filter Detail | ✅ | 1 | `toggleFilterLike`, `recordUse`, `reportFilter` | |
| Filter Download Progress | ✅ | 1 | `users/{uid}/savedFilters` | local download state |
| Filter After Download | ✅ | 1 | savedFilters / favorites | |
| Saved Filters | ✅ | 1 | savedFilters / favorites | |
| Builtin Filter Library | ✅ | 1 | bundle seed | Pro lock sheet |
| Favorites Collection | ✅ | 1 | `users/{uid}/collections` listener | |
| Universal Link Landing | ✅ | 1 | deep link bridge | |
| Filter Unavailable (404) | ✅ | 1 | invalid id fallback | |

### 3.4 Maker / Upload (10)

| 화면 | 상태 | Phase | 백엔드 | 비고 |
|---|---|---|---|---|
| Filter Editor | ✅ | 2 | `editorDrafts/current` | UI Done / 엔진 In Progress |
| Editor Parameters | ✅ | 2 | local | 노출/대비/채도/그레인/비네팅 |
| Editor LUT Import (.cube) | ✅ | 2 | DocumentPicker + `CubeLUTParser` | |
| Editor Draft Save | ✅ | 2 | `makerDrafts` | |
| Upload Cover | 🟡 | 2 | local mock | B/A 토글 |
| Upload Tags & Category | ✅ | 2 | local | |
| Upload TOS Submit | 🟡 | 2 | `submitForReview`(시도) | `firestoreFilterId` 있어야 호출 |
| Upload Pending Review | ✅ | 2 | draft.status=pending | |
| My Filters | 🟡 | 2 | `users/{uid}/makerDrafts` | 비공개 = status 변경 |
| Maker Dashboard | ⚪ | 6 | UI projection | 통계 mock |
| Remix Flow | 🟠 | 2 | editor entry | |

### 3.5 Reviews / Social / Feed (12)

| 화면 | 상태 | Phase | 백엔드 | 비고 |
|---|---|---|---|---|
| Reviews List | ✅ | 3 | `filters/{id}/reviews` listener | helpfulCount 정렬 |
| Review Compose | ✅ | 3 | `reviewImageUploadInit`, `submitReview` | ★1~5 + ≤280자 |
| Rating Form | ✅ | 3 | `filters/{id}/ratings/{uid}` direct | |
| Followers List | ✅ | 3 | `follows` query | |
| Following List | ✅ | 3 | `follows` query | |
| For You Feed | 🟡 | 4 | mock projection | hero + rail + grid |
| Following Feed | ✅ | 3 | `feedActions` + `filters` | |
| Report Form | ✅ | 3 | `reportFilter`, `reportReview`, `reportUser` | |
| Block List | ✅ | 3 | `blocks` listener | |
| Profile (self) | ✅ | 3 | `users`, `filters`, `savedFilters`, `captures` | 세그먼트 |
| Profile (other) | ✅ | 3 | + `follows`, `blocks` | |
| Other Profile Resolver | ✅ | 3 | `handles/{handle}` | @handle → uid |
| Edit Profile | ✅ | 3 | `profileAvatarUploadInit`, `setHandle`, `updateProfile` | |
| Capture Detail | 🟡 | 1 | `users/{uid}/captures` | |

### 3.6 Wallet / Payment (10)

| 화면 | 상태 | Phase | 백엔드 | 비고 |
|---|---|---|---|---|
| Wallet | ✅ | 6 | `wallet/balance`, `proStatus` listener | |
| Wallet Topup | ✅ | 6 | StoreKit2, `creditCoinsFromIAP` | 100/550/1200/3000 |
| Wallet Transactions | ✅ | 6 | `walletLedger` | |
| Paywall Single | ✅ | 6 | `purchaseFilter` | Pro 분기 |
| Pro Subscription | ✅ | 6 | StoreKit2, `proSubscriptionUpdate` | 월/연 |
| Pro Status | ✅ | 6 | `proStatus/status` | App Store 외부 링크 |
| Insufficient Balance | ✅ | 6 | `purchaseFilter` | 충전/지금 구매/취소 |
| Payment Failed | ✅ | 6 | StoreKit restore | |
| Orders History | 🟡 | 6 | `walletLedger` projection | |
| Refund Request | ✅ | 6 | `refundRequest` | 7일 정책 |
| Payout Onboarding | ⚪ | 6 | Stripe Connect | closed-loop 정책상 비노출 |
| Payout Tax Info | ⚪ | 6 | placeholder | |
| Payout History | ⚪ | 6 | placeholder | |
| Earnings Withdraw | ⚪ | 6 | placeholder | |

### 3.7 Notifications / Settings (8)

| 화면 | 상태 | Phase | 백엔드 | 비고 |
|---|---|---|---|---|
| Notifications Inbox | ✅ | 3 | `users/{uid}/notifications` listener + page load | 카테고리 칩 + 그룹 |
| Notification Settings | ✅ | 3 | `notificationPreferences/main` | iOS 설정 열기 + 방해금지 |
| Settings | ✅ | 3 | route hub | |
| Data Export | ✅ | 3 | `exportRequests` | JSON/CSV/HTML |
| Help Center | ✅ | 3 | external Safari | help.moodit.app |
| Account Deletion | ✅ | 3 | `deleteAccount` | handle 재입력 |
| (Saved Filters → 3.3 참조) | | | | |

### 3.8 Moderation (3)

| 화면 | 상태 | Phase | 백엔드 | 비고 |
|---|---|---|---|---|
| Moderation Queue | ✅ | 5 | filters where pending | mod/admin 한정 |
| Moderation Detail | 🟡 | 5 | `approveFilter`, `rejectFilter`, `undoModerationDecision` | takedown UI 후속 |
| Filter Rejected | 🟡 | 5 | rejected route + external appeal | maker 통지 |

### 3.9 Permissions (4 priming + 4 denied)

| 권한 | Priming | Denied | Phase |
|---|---|---|---|
| Camera | ✅ | ✅ | 1 |
| Photos | ✅ | ✅ | 1 |
| Notifications | ✅ | ✅ | 3 |
| Location | ⚪ | ⚪ | 향후 |

## 4. 구현 갭 (PM 관점 우선순위)

| 우선 | 갭 | 영향 | 파장 |
|---|---|---|---|
| P0 | 업로드 end-to-end 미연결 (.fmpkg 빌드 → R2 PUT → finalize) | 메이커 활성률 = 0 | Phase 2 게이트 |
| P0 | 모더레이션 자동화 트리거 미작성(`onReportCreated`) | 신고→대응 SLA 측정 불가 | Phase 5 |
| P1 | For You 추천이 mock | Phase 4 측정 자체 불가 | Phase 4 |
| P1 | Search full-text 부재 | 카탈로그 5K+ 시 client-side 한계 | Phase 4 ADR |
| P1 | Maker Dashboard 통계 mock | 메이커 retention 데이터 부재 | Phase 6 |
| P2 | Payout placeholder | 수익 인출 실루프 부재 | Phase 6 후반 |
| P2 | 실기기 카메라 검증 미실시 | TestFlight 게이트 통과 불가 | Phase 1 |

## 5. 신규 화면 추가 / 변경 절차

1. `docs/NAVIGATION.md` §4에 Action ID + 라우트 추가.
2. `docs/SCREEN_ACTIONS_QA_DEFINITION.md` §4에 QA 정의 추가.
3. `Sources/App/AppNavigation.swift` `AppRoute` enum에 case 추가.
4. SwiftUI 화면 파일 추가, `accessibilityIdentifier`를 Action ID와 일치.
5. 본 인벤토리(`SCREEN_INVENTORY.md`)에 행 추가.
6. 디자이너: `deliverables/flow-*.html`에 목업 추가, `DESIGNER_NOTES.md` 업데이트.

---

**참조**: [`../../docs/NAVIGATION.md`](../../docs/NAVIGATION.md) · [`../../docs/SCREEN_ACTIONS_QA_DEFINITION.md`](../../docs/SCREEN_ACTIONS_QA_DEFINITION.md) · [`../flowchart/CORE_FLOWS.md`](../flowchart/CORE_FLOWS.md)
