# moodit · Core Flows (Mermaid)

> 본 문서의 다이어그램은 GitHub / VS Code / Obsidian에서 Mermaid 자동 렌더링됩니다. 별도 환경은 [mermaid.live](https://mermaid.live)에 코드를 붙여넣으세요.
> Action ID 1:1 매핑은 [`../../docs/NAVIGATION.md`](../../docs/NAVIGATION.md), 화면 인벤토리는 [`../screens/SCREEN_INVENTORY.md`](../screens/SCREEN_INVENTORY.md).

## F1 — Auth & Onboarding

```mermaid
graph TD
  Launch{앱 시작}
  Launch -->|first_run| OB[Onboarding Carousel<br/>4 page]
  Launch -->|already onboarded| Login[Login]
  OB -->|next x4 / skip| Login
  Login -->|Apple| Root[RootShell · 5 tabs]
  Login -->|Google| Root
  Login -->|Email| Email[Email Login]
  Email -->|signIn / signUp| Root
  Login -->|Guest 둘러보기| Market[Marketplace]
  Market -->|업로드/구매 시도| LoginIntercept[Login intercept]
  Root -->|tab.shutter| Camera[Camera Live]
  Camera -.->|"카메라 권한 미허용"| PermPriming[Camera Priming]
  PermPriming -->|allow| Camera
  PermPriming -->|deny| PermDenied[Camera Denied + 설정 열기]
```

**의사결정 포인트**
- 게스트 → 인증 전환은 *행동 인터셉트*(다운로드/구매 시도)로 트리거. 이 위치를 변경하면 회원가입 funnel이 흔들린다.
- Onboarding은 4페이지 캐러셀로 고정. 페이지 수 변경은 카피·일러스트 자산 함께 갱신.

---

## F2 — Discover → Download → Apply

```mermaid
graph TD
  Market[Marketplace Home<br/>trending + category + new] -->|search| Search[Search<br/>browsing→typing→results]
  Market -->|tile| Detail[Filter Detail Loader → Filter Detail]
  Market -->|For You| ForYou[For You Feed<br/>mock]
  Market -->|maker tile| OtherProfile[Other Profile]
  Search --> Detail
  Detail -->|"free / has_pro / owned"| Download[Download Progress]
  Detail -->|"paid &amp; balance&gt;=price"| Paywall[Paywall Single]
  Detail -->|"paid &amp; balance&lt;price"| Insufficient[Insufficient Balance]
  Insufficient -->|topup| Topup[Wallet Topup]
  Topup --> Detail
  Paywall -->|구매 confirm| Download
  Paywall -->|Pro 업그레이드| ProSheet[Pro Subscription]
  Download --> AfterDL[After Download<br/>적용/즐겨찾기/컬렉션]
  AfterDL -->|apply| Camera[Camera Live<br/>w/ filter selected]
```

**의사결정 포인트**
- `if:filter.paid && balance>=price` 분기는 **3중 조건**(잔액 / Pro / 소유)으로 단순화 가능 여부 검토.
- 다운로드 화면은 *진행 + 취소 + 재시도*만 — 광고/추가 CTA 금지(드롭 방지).

---

## F3 — Maker Upload

```mermaid
graph TD
  Entry{에디터 진입}
  Entry -->|새로 만들기| Editor[Filter Editor]
  Entry -->|Remix| Remix[Remix Flow]
  Remix --> Editor
  Editor --> Params[Editor Parameters<br/>노출/대비/채도/그레인/비네팅]
  Editor --> LUT[Editor LUT Import<br/>.cube]
  Params --> LUT
  LUT --> Draft[Draft Save]
  Draft -->|로컬 저장| MyFilters[My Filters]
  Draft -->|바로 마켓 공유| Up1[Upload Cover<br/>+ B/A 토글]
  Up1 --> Up2[Upload Tags &amp; Category]
  Up2 --> Up3[Upload TOS &amp; Submit<br/>3 약관]
  Up3 -->|submit| Pending[Pending Review]
  Pending --> Notif{모더레이션 결과}
  Notif -->|승인| Published[알림: 공개됨 → My Filters]
  Notif -->|거부| Rejected[Filter Rejected<br/>사유 + 이의 제기]
  Rejected -->|에디터에서 수정| Editor
```

**의사결정 포인트**
- 약관 3종(Original / Policy / Commercial) 동시 동의 강제 — 약관 변경 시 `submitForReview` callable 검증 동기 갱신.
- 거절→수정 루프가 메이커 retention의 핵심. 거부 사유 *구체성*이 부족하면 메이커 D7 떨어짐.

---

## F4 — Wallet & Payment

```mermaid
graph TD
  Profile[Profile] -->|profile.wallet| Wallet[Wallet<br/>잔액 + 거래내역 + Pro]
  Wallet --> Topup[Wallet Topup<br/>100/550/1200/3000]
  Wallet --> Tx[Wallet Transactions]
  Wallet -->|maker only| Withdraw[Earnings Withdraw<br/>Phase 6]
  Wallet --> ProStatus[Pro Status]
  Topup -->|external-iap| Apple{Apple IAP}
  Apple -->|성공| TopupOk[Toast: 충전 완료 → Wallet]
  Apple -->|실패| Failed[Payment Failed]
  Failed -->|retry| Topup
  Failed -->|refund| Refund[Refund Request]
  ProStatus -->|cancel| AppleSubs[external: App Store 구독 관리]
  Withdraw -->|"if:!stripe_connected"| Onboard[Payout Onboarding]
  Onboard -->|external-stripe| StripeWeb[Stripe Connect Express]
  StripeWeb -->|돌아옴| TaxInfo[Payout Tax Info]
  TaxInfo --> Withdraw
  Withdraw -->|submit| PayoutHistory[Payout History]
```

**의사결정 포인트**
- 출금은 `closed-loop coin` 정책상 Phase 6 후반까지 *앱 진입점 비노출* 상태로 유지.
- Topup 패키지 4단계 — 시장 데이터 후 5번째 패키지(예: 5,000) 추가 검토.

---

## F5 — Social & Reviews

```mermaid
graph TD
  Detail[Filter Detail] -->|reviews| Reviews[Reviews List<br/>helpfulCount 정렬]
  Detail -->|report| Report[Report Form]
  Detail -->|share| Share[Share Sheet · Universal Link]
  Reviews -->|작성| Compose[Review Compose<br/>★1~5 + body ≤280 + 사진]
  Reviews -->|작성자| OtherProfile[Other Profile]
  OtherProfile -->|follow| OtherProfile
  OtherProfile -->|followers| Followers[Followers]
  OtherProfile -->|following| Following[Following]
  OtherProfile -->|block / report| Block[Block / Report]
  Reviews -->|helpful| Reviews
  Reviews -->|maker reply 1회| Reviews
```

**의사결정 포인트**
- App Store 패턴(1인 1리뷰, 메이커 답글 1회). 변경은 약관·Cloud Function `submitReview` 검증 동시 갱신.
- 신고는 *임계값 도달 시* 자동 큐 진입 — Phase 5 트리거 작업 (`onReportCreated` TODO).

---

## F6 — Moderation

```mermaid
graph TD
  Queue[Moderation Queue<br/>filter: 전체/자동/사용자/신규] -->|row| ModDetail[Moderation Detail]
  ModDetail -->|approve| QueueOk[Toast: 승인 → Queue]
  ModDetail -->|reject + reason| QueueRj[Toast: 거부 → Queue]
  ModDetail -->|takedown| QueueTd[Toast: 비공개 → Queue]
  ModDetail -->|undo| QueueUndo[Toast: 되돌림 → Queue]
  RejectedNotif[Maker 알림: 거절] -->|에디터에서 수정| FilterEditor[Filter Editor]
  RejectedNotif -->|이의 제기| Appeal[external: 이의 제기 폼]
```

**의사결정 포인트**
- 24h SLA 위반 시 알람 — Phase 5에서 모더레이션 BPO 외주 결정.
- `undoModerationDecision`은 운영 실수 복구용. 사용 빈도 추적 → SLA 지표.

---

## F7 — Permissions Priming

```mermaid
graph TD
  Trigger{권한 필요 액션} -->|"camera.shutter / camera.openLibrary / 알림 토글 / 위치"| Priming[Priming 화면<br/>이유 + CTA]
  Priming -->|허용| Granted[Granted → 원래 액션 재개]
  Priming -->|건너뛰기/닫기| Skip[원래 화면으로 복귀]
  Priming -->|시스템 다이얼로그 거부| Denied[Denied 화면<br/>설정 열기]
  Denied -->|external-system| Settings[iOS Settings]
  Settings -->|복귀| Recheck{Permission 재확인}
  Recheck -->|granted| Granted
  Recheck -->|still denied| Denied
```

**의사결정 포인트**
- 거부 후 복귀율은 권한별 다름. 카메라 priming 카피가 가장 큰 lever.

---

## F8 — System: .fmpkg Upload (서버 시퀀스)

```mermaid
sequenceDiagram
    actor M as Maker
    participant App as iOS App
    participant API as Filter Service<br/>(Cloud Functions)
    participant R2 as Cloudflare R2
    participant DB as Firestore
    participant Mod as Moderation Worker
    M->>App: 검수 제출
    App->>API: uploadInit(name, category, tags, packageBytes, sha256)
    API->>DB: filters/{id} status=uploading
    API-->>App: presigned PUT URL + filterId
    App->>R2: PUT .fmpkg
    App->>API: uploadFinalize(filterId)
    API->>R2: HEAD verify
    API->>DB: status=pending_review_pre
    App->>API: submitForReview(filterId, tos)
    API->>DB: status=pending_review
    Note over Mod: Phase 5 자동 모더레이션
    Mod->>DB: status=approved | rejected
    DB-->>App: 알림 fanout (FCM)
```

**의사결정 포인트**
- 멱등성 보장: `uploadInit`은 filterId 예약, 중복 호출 시 동일 ID 반환.
- 검수 단계가 너무 많은 상태(uploading→pre→review→approved)지만 *각 단계가 다른 actor*. 합치면 추적성 손실.

---

## F9 — System: Live Camera + Filter (단말 내부)

```mermaid
sequenceDiagram
    participant Cam as AVCaptureSession
    participant Buf as CVPixelBuffer<br/>(YUV 420f)
    participant TC as CVMetalTextureCache
    participant Pipe as Metal Pipeline<br/>(4 pass)
    participant View as MTKView
    participant Photo as AVCapturePhotoOutput
    loop every frame ~16ms / 60FPS
        Cam->>Buf: didOutput sampleBuffer
        Buf->>TC: createMetalTextureFromImage
        TC->>Pipe: Y plane + CbCr plane
        Pipe->>Pipe: pass1 YUV→RGB
        Pipe->>Pipe: pass2 base params
        Pipe->>Pipe: pass3 LUT lookup
        Pipe->>Pipe: pass4 grain/vignette
        Pipe->>View: drawable.present()
    end
    Note over Cam,Photo: 셔터 누름
    Cam->>Photo: capturePhoto(with:)
    Photo->>Pipe: high-res pixel buffer
    Pipe->>Photo: HEIC encode → PhotoKit
```

**의사결정 포인트**
- A11~A13에서는 4-pass 중 grain/vignette 패스 자동 단순화 — `ProcessInfo.thermalState` 모니터링 트리거.
- iPhone X 미만은 720p + 30FPS 강제 (호환성 정책 R-T04).

---

**참조**: [`INDEX.md`](./INDEX.md) · [`../../docs/NAVIGATION.md`](../../docs/NAVIGATION.md) · [`../../docs/SYSTEM_DESIGN.md`](../../docs/SYSTEM_DESIGN.md)
