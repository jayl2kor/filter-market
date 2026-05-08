# Backend Wiring & Broken Screens — Master TODO

**전수조사 일자**: 2026-05-08
**상태**: UI 30+개 화면 중 대부분이 mock 데이터 + skeleton placeholder. 실제 backend 호출 = Firestore 1건(FCM), Cloud Functions 0건.

## Sprint 1-4 Ralph 진행 상황 (2026-05-08)

| Story | 상태 | 빌드 | 비고 |
|---|---|---|---|
| US-S1-01 helpCenter 라우팅 | ✅ 완료 | ✅ BUILD SUCCEEDED | AppRoute.helpCenter 추가 + HelpCenterScreen 신규 + SettingsScreen 라우트 수정 |
| US-S1-02 ~ US-S4-03 (20개) | ⏳ 대기 | — | Marketplace 모듈에 Firebase deps 추가 또는 Firestore impl을 App 모듈에 분리 필요 |

**주요 아키텍처 결정 필요**:
- Marketplace target에 FirebaseFirestore 의존 추가 vs Firestore impl을 App 모듈에 두기 — App 모듈 분리가 의존성 측면에서 깔끔
- Filter 모델 확장 (useCount/createdAt/status/priceCoins) vs 별도 MarketplaceFilter 모델 — 후자가 도메인 분리 측면에서 안전

---

## A. Skeleton 화면 (ScreenWorkflowScaffold만 표시 — 실제 로직 0)

총 **15개**. 모두 `Sources/App/WorkflowScreens.swift` 라인 2726–2787에서 `ScreenWorkflowScaffold(route: .xxx)`만 호출.

### A-1. Wallet / IAP / 결제 (P0 — 코인 구매 진입 불가의 직접 원인)

| # | Route | 화면 | 빠진 것 |
|---|---|---|---|
| 1 | `.wallet` | WalletScreen | 잔액 표시, 거래내역 진입, Pro 시작 진입 |
| 2 | `.walletTopup` | WalletTopupScreen | 코인 패키지 4종 목록, StoreKit Product 로드, 구매 버튼 |
| 3 | `.walletTransactions` | WalletTransactionsScreen | Firestore 거래 내역 쿼리 + 리스트 |
| 4 | `.paywallSingle` | PaywallSingleScreen | 가격, 잔액, 구매 → 코인 차감 + 다운로드 권한 부여 |
| 5 | `.proSubscription` | ProSubscriptionScreen | Pro 월/연 상품, StoreKit 구매 |
| 6 | `.proStatus` | ProStatusScreen | 현재 구독 상태, 다음 결제일, 혜택 목록 |
| 7 | `.ordersHistory` | OrdersHistoryScreen | 결제 내역 Firestore 조회 |
| 8 | `.insufficientBalance` | InsufficientBalanceScreen | "충전하기" CTA → walletTopup 실제 dispatch |
| 9 | `.paymentFailed` | PaymentFailedScreen | 재시도 / 복원 동작 실제 구현 |
| 10 | `.refundRequest` | RefundRequestScreen | 환불 폼 + Cloud Function callable |

### A-2. Moderation / Safety (P1)

| # | Route | 화면 | 빠진 것 |
|---|---|---|---|
| 11 | `.modQueue` | ModerationQueueScreen | admin claim 사용자만, Firestore 미승인 필터 쿼리 |
| 12 | `.modDetail` | ModerationDetailScreen | 승인/거절 callable (`adminApprove`, `adminReject`) |
| 13 | `.blockList` | BlockListScreen | `/users/{uid}/blocks` 쿼리 + 차단 해제 |
| 14 | `.reportForm` | ReportFormScreen | `reportFilter` callable 호출 (현재 unimplemented stub) |

### A-3. Maker (P2)

| # | Route | 화면 | 빠진 것 |
|---|---|---|---|
| 15 | `.makerDashboard` | MakerDashboardScreen | 내 필터 사용/구매/리뷰 통계 집계 |

---

## B. Mock 데이터 → Firestore 교체

### B-1. 진입 화면 (P0)

| 화면 | 현재 데이터 출처 | 필요한 backend 작업 |
|---|---|---|
| MarketplaceScreen | `MarketplaceMockData.trending/newFilters` (12+12 하드코딩) | Firestore listener `/filters where status=="approved"` order by `useCount desc` (trending) / `createdAt desc` (new) |
| SearchScreen | `MarketplaceMockData.newFilters` 필터링 | Firestore 쿼리 + Algolia/Typesense 검색 인덱스 (또는 in-memory client filter) |
| FilterDetailScreen | `FilterDetailMock.preview`, 리뷰 3개 하드코딩 | `getFilterDetail` callable 구현 + Firestore 리뷰 listener |

### B-2. 사용자 데이터 (P1)

| 화면 | 현재 | 필요한 backend |
|---|---|---|
| ProfileScreen | `ProfileMockData.myFilters/saved/captures` (12+6+5 하드코딩) | `/users/{uid}/filters`, `/users/{uid}/savedFilters`, `/users/{uid}/captures` listener |
| NotificationsInboxScreen | `NotificationItem.mock` 초기화 | `/users/{uid}/notifications` listener + 작성 trigger |
| SocialDiscoveryScreens (Reviews) | `SocialReview.mock` | `/filters/{id}/reviews` listener + create callable |

### B-3. MooditStore 초기화 (P0 — 모든 화면의 근원)

`Sources/App/MooditStore.swift:355` `BundleSeedFilterRepository` (번들 manifest.json만 로드) → Firestore 기반 repository로 교체.

---

## C. Cloud Functions 미구현 stub

`functions/src/http/filters.ts` 등에서 `throw HttpsError("unimplemented")` 상태:

| Function | 현재 | 필요 |
|---|---|---|
| `getFilterDetail` | unimplemented | `/filters/{id}` + R2 signed URL 반환 |
| `submitForReview` | unimplemented | status 전환 `pending_review_pre` → `pending_review` + ToS 검증 |
| `reportFilter` | unimplemented | `/filters/{id}/reports/{auto}` append + counter |
| **신규**: `adminApprove(filterId)` | 없음 | admin claim 검증 + status `approved` |
| **신규**: `adminReject(filterId, reason)` | 없음 | admin claim 검증 + status `rejected` + 알림 trigger |
| **신규**: `purchaseFilter(filterId)` | 없음 | 코인 차감 + 구매 권한 grant (트랜잭션) |
| **신규**: `creditCoinsFromIAP(receipt)` | 없음 | StoreKit receipt 검증 + 코인 잔액 증가 |
| **신규**: `refundRequest(orderId, reason)` | 없음 | 환불 요청 큐 등록 |
| **신규**: `notifyUser(uid, type, payload)` | 없음 | `/users/{uid}/notifications` 작성 trigger |

---

## D. StoreKit 2 통합 (P0 — 코인/Pro 구매 동작 전제 조건)

현재: `import StoreKit` **0건**, `Product.products(for:)` 호출 0건.

필요한 작업:
1. App Store Connect IAP 6종 등록 (Issue #14 — 사용자 진행중)
2. `Sources/Marketplace/StoreKitManager.swift` (신규) — `@Observable` actor
   - `loadProducts()` — `Product.products(for: ["coins.100", ...])`
   - `purchase(_:)` — `product.purchase()` + verification
   - `Transaction.updates` listener
   - 구매 완료 시 `creditCoinsFromIAP` callable 호출
3. `WalletTopupScreen` — products 표시 + 구매 트리거
4. `ProSubscriptionScreen` — 구독 상품 표시 + 구매 트리거
5. `Transaction.currentEntitlements` 기반 Pro 상태 판정

---

## E. Navigation 구조 리팩터 (P1)

현재 5개 탭 독립 `NavigationStack` → 단일 `NavigationStack(path:)`로 통합.

| 작업 | 파일 |
|---|---|
| `RootShell`을 `@State path: [AppRoute]`로 전환 | `Sources/App/AppNavigation.swift` |
| 탭 전환 시에도 path 유지 / 탭별 path 분리 결정 | 동일 |
| `DeepLinkDestination` default case → 모든 AppRoute 명시적 dispatch | 동일 |
| `UniversalLinkParser.route(forPushUserInfo:)`에 wallet 이벤트 매핑 추가 | `Sources/App/Notifications/UniversalLinkParser.swift` |
| `pendingDeepLinkRoute` sheet → path push로 변경 | 동일 |
| ProfileScreen guest/auth 분리 | `Sources/App/Profile/ProfileScreen.swift` |

---

## F. 라우팅 버그 (P0 — 즉시 수정 가능)

| 위치 | 문제 | 수정 |
|---|---|---|
| `SettingsScreen.swift` "도움말" row | `.refundRequest` 라우트로 잘못 연결됨 (환불 폼이 뜸) | `.helpCenter` 신규 case 추가 또는 `.refundRequest` 라벨 변경 |

---

## G. Dead-end 버튼 (P2)

| 위치 | 동작 | 의도 |
|---|---|---|
| `FilterDetailScreen.swift:485` "좋아요" | Haptic만 | `/filters/{id}/likes/{uid}` 토글 + counter |
| `ProfileScreen.swift:282` "프로필 공유" | Haptic만 | ShareSheet — universal link 생성 |
| `ProfileScreen.swift:214-218` 통계 항목(필터/팔로워/팔로잉) | 빈 closure | 각 리스트 화면으로 push |
| `SocialDiscoveryScreens.swift:525` "로그인하고 리뷰 쓰기" | NavigationLink만, 후속 라우팅 없음 | 로그인 성공 후 `.reviewCompose(filterId:)` resume |
| `SocialDiscoveryScreens.swift:647` "로그인하고 평점 남기기" | 동일 | 로그인 성공 후 `.rating(filterId:)` resume |
| `SettingsScreen.swift:158` "버전" row | 빈 closure | 의도적 정보 표시 — 유지 OK |

---

## H. 작업 우선순위 (제안)

### Sprint 1 — 진입 가능하게 (P0)
1. **F**: 도움말 라우팅 버그 수정 (10분)
2. **B-3 + B-1**: MooditStore Firestore listener + Marketplace mock 제거 (반나절)
3. **C-getFilterDetail + B-1 FilterDetail**: 상세 화면 backend 연결 (반나절)
4. **D StoreKit 1단계**: StoreKitManager 신규 + WalletTopupScreen 실구현 (1일)
5. **A-1.1~3**: Wallet / WalletTopup / WalletTransactions 실구현 (1일)

### Sprint 2 — 결제 흐름 완성 (P0)
6. **C-purchaseFilter + creditCoinsFromIAP**: 결제 callable (반나절)
7. **A-1.4**: PaywallSingle 실구현 (반나절)
8. **A-1.5~6**: Pro Subscription / ProStatus (1일)
9. **A-1.7~10**: OrdersHistory / Insufficient / PaymentFailed / RefundRequest (1일)

### Sprint 3 — 사용자 데이터 (P1)
10. **B-2**: Profile / Notifications / Reviews backend (1.5일)
11. **G**: Dead-end 버튼 모두 (반나절)

### Sprint 4 — Moderation + Navigation (P1)
12. **A-2**: Moderation 4개 + adminApprove/Reject callable (1.5일)
13. **E**: Navigation 단일 NavigationStack(path:) 리팩터 (1일)

### 보류 (Phase 6+)
- payoutOnboarding / payoutTaxInfo / payoutHistory / earningsWithdraw — ADR-0006 closed-loop 정책 유지
- A-3 makerDashboard — Sprint 4 이후

---

## 외부 의존성 (사용자 진행 필요)

| 항목 | 상태 | Issue |
|---|---|---|
| App Store Connect IAP 6종 등록 | 진행중 | #14 |
| Sandbox Tester 계정 | 미확인 | — |
| Algolia/Typesense 검색 인덱스 | 미결정 | — |
| Firestore composite index (status + createdAt 등) | 자동 prompt 시 추가 | — |
