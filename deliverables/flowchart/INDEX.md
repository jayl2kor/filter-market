# moodit · Flowcharts Index

> Mermaid 기반 핵심 사용자/시스템 플로우. 각 플로우는 [`CORE_FLOWS.md`](./CORE_FLOWS.md)에 통합되어 있으며, 본 INDEX는 어떤 플로우가 어떤 의사결정에 쓰이는지 안내한다.
>
> **단일 진실원**: SwiftUI route는 `Sources/App/AppNavigation.swift`의 `AppRoute`. Action ID는 [`../../docs/NAVIGATION.md`](../../docs/NAVIGATION.md). 본 산출물은 PM 관점의 *플로우 부감*이며, 코드/Action 매핑이 필요하면 NAVIGATION.md를 본다.

## 1. 플로우 카탈로그

| ID | 이름 | 보면 좋은 의사결정 | 코드 진입점 |
|---|---|---|---|
| F1 | Auth & Onboarding | 게스트→가입 전환 deflection 검토 | `LoginScreen`, `OnboardingScreen` |
| F2 | Discover → Download → Apply | 마켓→다운로드→카메라 funnel 최적화 | `MarketplaceScreen` → `FilterDetailScreen` → `FilterDownloadProgressScreen` → `CameraScreen` |
| F3 | Maker Upload | 업로드 drop-off 분석, 약관 단계 검토 | `FilterEditorScreen` → 4-step upload → `UploadPendingReviewScreen` |
| F4 | Wallet & Payment | 코인 충전 / 단일 구매 / Pro 분기 | `WalletScreen` → `WalletTopupScreen` / `PaywallSingleScreen` |
| F5 | Social & Reviews | 리뷰 작성 마찰 / 신고·차단 흐름 | `FilterDetailScreen` → `ReviewsListScreen` → `ReviewComposeScreen` |
| F6 | Moderation | 큐→상세→승인/거부 SLA 측정 | `ModerationQueueScreen` → `ModerationDetailScreen` |
| F7 | Permissions Priming | 카메라/사진 권한 거부 복귀율 | `Permissions/*PrimingScreen` |
| F8 | System (.fmpkg upload) | 백엔드 업로드 시퀀스 (개발 brief용) | `uploadInit` → R2 PUT → `uploadFinalize` → `submitForReview` |
| F9 | System (Live Camera + Filter) | Metal 4-pass 파이프라인 (성능 brief용) | `CameraSession` → `MetalPreviewRenderer` |

## 2. 어떤 플로우를 언제 보는가

| 상황 | 보는 플로우 |
|---|---|
| 신규 합류자 온보딩 | F1 → F2 → F3 (사용자 여정 순) |
| 컨버전 funnel 분석 | F2 (download), F4 (purchase) |
| 모더레이션 SLA 검토 | F6 |
| 백엔드 변경 영향 평가 | F8, F9 |
| 권한 거부율 회복 | F7 |
| 메이커 활성률 개선 | F3, F5 (반응 루프 포함) |

## 3. 외부 시스템 의존 표시

| 외부 시스템 | 등장 플로우 | 영향 |
|---|---|---|
| Apple StoreKit2 | F4 | 코인 충전 / Pro 구독 / 환불 |
| Cloudflare R2 | F2, F8 | 미디어 PUT/GET (presigned URL) |
| Firebase Functions | 모든 F* | callable API 호출 |
| Firebase Auth | F1 | 토큰 발급 / 검증 |
| FCM/APNs | F5, F6 | 알림 |
| Stripe Connect | F4 (Phase 6) | 메이커 출금 |
| Cloud Vision API | F6 (Phase 5) | 자동 모더레이션 |

---

**다음**: 모든 Mermaid 다이어그램은 [`CORE_FLOWS.md`](./CORE_FLOWS.md).
