# ADR-0001: Swift + iOS 네이티브 단독 출시 (Compose MP → Swift only 전환)

> Status: Accepted
> Date: 2026-05-06
> Authors: filterMarket Founders
> Reviewers: iOS Lead, Backend Lead, PM

---

## 1. Context

### 1.1 이전 가설
filterMarket의 초기 검토에서는 다음 두 가지 클라이언트 옵션을 비교했다.

- **Compose Multiplatform (KMP)**: iOS + Android 동시 출시, UI 일부 공유
- **iOS 네이티브 단독 (Swift + SwiftUI + Metal)**: iOS 우선 출시 후 Android 의사결정

### 1.2 문제
초기 PoC와 시장조사 결과 다음 사실이 드러났다.

1. **카메라 + Metal 기반 60FPS 라이브 필터**가 본 제품의 핵심 차별점이다.
2. Compose Multiplatform의 iOS 측 카메라 surface integration + Skia for iOS는 PoC 단계에서 성능/안정성 불확실성이 컸다.
3. Halide / Darkroom / Procreate 등 **App Store 피처드 사례는 모두 네이티브** 단독 출시를 통해 큐레이션 노출을 확보했다.
4. 1차 페르소나(북미·서유럽·한국·일본의 콘텐츠 크리에이터)는 **iOS 비중이 65~75%** 로 높다.
5. 팀 규모(iOS 2 + 백엔드 1 + 디자인 0.5)에서 **두 플랫폼 동시 출시는 출시 속도와 표현력 모두를 희생**한다.

### 1.3 제약
- 출시 마감: MVP 6주 + Phase 0 PoC 1주
- 팀 인원: 풀타임 ~3.5명
- 자본 효율 우선: 시장 검증 전 양 플랫폼 투자 회피

---

## 2. Decision

**filterMarket v1.0은 iOS 네이티브 단일 스택(Swift 5.10+ / SwiftUI + UIKit + AVFoundation + Metal)으로 출시한다. Android 진출은 Phase 4(시장 검증 후)에 별도 ADR로 결정한다.**

- **클라이언트 언어**: Swift 5.10+, Swift 6 strict concurrency 단계적 적용
- **UI 프레임워크**: SwiftUI 메인 + UIKit 보완(`UIViewRepresentable`로 카메라 프리뷰 등)
- **GPU**: Metal + MSL (1차) + Core Image (보조), 자세한 셰이더 정책은 [ADR-0003](./0003-metal-msl-shader-pipeline.md)
- **최소 지원**: iOS 17.0+
- **의존성 관리**: Swift Package Manager
- **출시 채널**: App Store (TestFlight Internal → External Closed Beta → Production)

Phase 4 진입 시점에 다음 옵션 중 1택을 결정한다:
- 옵션 A: 네이티브 Kotlin (Android 별도 코드베이스)
- 옵션 B: Compose Multiplatform 도입 (UI 일부 공유)
- 옵션 C: iOS 단독 유지 (시장 반응이 그렇게 정당화하면)

---

## 3. Consequences

### 3.1 긍정적 결과
- **MVP 출시 속도**: 크로스플랫폼 PoC(2~3주) 대비 PoC 1주 + MVP 6주로 단축
- **표현력**: AVFoundation + Metal 직접 제어 → 1080p 60FPS 라이브 필터, 4-pass 셰이더 파이프라인 가능
- **App Store 피처드 가능성**: 네이티브 + Apple 최신 기술(Metal 3, Vision, Observation, SwiftData) → Apple Design Award / Today 피처드 우대
- **팀 학습 곡선**: Swift는 팀 친숙, Vapor 채택 시 백엔드와 언어 통일 가능
- **장기 유지보수**: Apple 1급 시민 → API 변경/지원 신뢰성

### 3.2 부정적 결과 / 트레이드오프
- **Android 시장 기회비용**: 인도, 동남아, 아프리카 등 Android 비중 70%+ 시장 미커버 (참고: [RISKS.md](../RISKS.md) R-B07)
- **글로벌 MAU 상한 제약**: iOS 단독으로 잠재 MAU 절반 가까이 제약 가능
- **경쟁사 Android 우선 진입 리스크**: 시장 선점 가능성
- **재구현 비용**: Phase 4 Android 진출 시 UI 코드는 재작성 (도메인/백엔드/포맷은 재사용)

### 3.3 잔여 위험
| 위험 | 완화 |
|---|---|
| Android 진출 시 .fmpkg/REST API 호환성 | 처음부터 플랫폼 중립 설계 (참고: [FMPKG_SCHEMA.md](../FMPKG_SCHEMA.md)) |
| iOS 17 점유율 상승 부진 | 점유율 < 70% 되면 iOS 16+ 하향 검토 (TECH_STACK.md §14) |

### 3.4 재검토 트리거
- Phase 4 종료 시점에서 다음 지표로 정량 평가:
  - iOS MAU
  - 메이커 수
  - 누적 매출 (Phase 6 진입)
  - 팀 규모
  - 국가별 잠재 시장 데이터
- 정량 + 정성 결합으로 옵션 A/B/C 결정 → 새 ADR로 기록

---

## 4. Alternatives Considered

### 대안 A: Compose Multiplatform (KMP)
- **요약**: iOS + Android 동시 출시, 도메인/UI 일부 공유
- **장점**:
  - 코드 공유율 60~80% 가능
  - JetBrains 1급 지원
  - Android 진출 즉시 가능
- **단점**:
  - iOS Skia surface 성능 불확실성 (라이브 카메라 60FPS 미보장)
  - 카메라 surface integration 복잡 — `AVCaptureSession`을 KMP에서 다루는 패턴이 미성숙
  - Metal 직접 접근 어려움 → 4-pass 셰이더 파이프라인 구현 위험
  - PoC 비용이 크고, MVP까지 출시 속도 저하
  - App Store 피처드 가능성 낮음 (네이티브 우대)
- **채택하지 않은 이유**: 본 제품의 핵심 차별점인 60FPS 라이브 Metal 필터의 표현력 손실이 크고, 출시 속도가 느림. Phase 4에서 Android 진출 결정 시 다시 후보.

### 대안 B: Flutter
- **요약**: Dart 기반 크로스플랫폼
- **장점**: 빌드/핫리로드 DX, 풍부한 패키지
- **단점**: GPU 셰이더 표현력 부족(Skia 제한), Metal 직접 제어 불가, 모바일 카메라 API 깊이 부족
- **채택하지 않은 이유**: 셰이더 표현력 한계가 본 제품에 치명적

### 대안 C: React Native
- **요약**: JS 기반 크로스플랫폼
- **장점**: 큰 생태계
- **단점**: GPU 셰이더 워크로드에서 가장 약함. RN-Skia 보완은 가능하나 성능/안정성 미달
- **채택하지 않은 이유**: 카메라/셰이더 적합성이 가장 낮음

### 대안 D: 네이티브 iOS + Android 동시
- **요약**: 두 코드베이스 동시 개발
- **장점**: 양 플랫폼 모두 네이티브 표현력
- **단점**: 팀 5명 미만에서 비현실적, 출시 속도 1.5~2배 저하
- **채택하지 않은 이유**: 팀 규모 제약

### 대안 E: 현상 유지 (이전 Compose MP 가설 유지)
- **단점**: 위 대안 A의 단점이 시간이 갈수록 더 큰 비용으로 누적 (PoC 실패 → 재설계 비용)

---

## 5. Implementation Notes

- Phase 0: SPM 모듈 골격(App, Camera, FilterEngine, Marketplace, Auth, Storage, Models, DesignSystem)
- Phase 1: TestFlight Closed Beta (100명) 출시
- Phase 4: Android 진출 의사결정 게이트 — 시장조사 + 옵션 비교 후 새 ADR
- 도메인 모델 / .fmpkg 포맷 / REST API는 처음부터 **플랫폼 중립**으로 설계 → 향후 Android 포팅 시 자산 재사용

---

## 6. References

- [PRD.md](../PRD.md) §7 경쟁 분석
- [TECH_STACK.md](../TECH_STACK.md) §2 클라이언트 프레임워크 결정
- [ARCHITECTURE.md](../ARCHITECTURE.md) §1 아키텍처 원칙
- [RISKS.md](../RISKS.md) R-B07 — Android 시장 기회비용
- [TASK_LIST.md](../TASK_LIST.md) Phase 4 게이트
- [ADR-0003](./0003-metal-msl-shader-pipeline.md) — Metal/MSL 채택
- 사례 분석: Halide / Darkroom / Procreate (모두 iOS 우선 출시 → 시장 장악 → 멀티플랫폼)
