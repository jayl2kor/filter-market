# ADR-0003: Metal + MSL을 1차 셰이더 파이프라인으로 채택

> Status: Accepted
> Date: 2026-05-06
> Authors: iOS Lead, Graphics Lead
> Reviewers: CTO, PM

---

## 1. Context

### 1.1 셰이더 요구사항
- **라이브 카메라 1080p @ 30~60FPS**, 프레임당 GPU ≤ 16ms (A14 이상에서 60FPS 목표)
- **4-pass 파이프라인**: YUV→RGB → 파라미터(노출/대비/채도/온도) → LUT 적용 → 그레인/비네트
- **고해상 캡처**(12MP+) 동일 셰이더 체인 1초 이내 적용
- **메이커 업로드 셰이더**(Phase 3+): 동일 언어 + 보안 검증
- **iOS 17+** 최소 지원 (Metal 3 가능)
- **플랫폼 중립**: Phase 4 Android 진출 시 LUT/파라미터 자산은 재사용 가능해야 함

### 1.2 후보 셰이더 언어
- **MSL (Metal Shading Language)**: iOS 1급, Apple Silicon 최적화
- **GLSL ES**: iOS에서 deprecated (iOS 12+에서 OpenGL ES 비공식 지원, Metal 권장)
- **Core Image (`CIFilter` + `CIKernel`)**: 짧은 코드, 일부 가속, 핫패스에서 예측성 떨어짐
- **AGSL (Android Graphics Shading Language)**: Android 13+, iOS 비호환
- **WebGL/WebGPU 기반 abstraction**: 모바일에서 부적합 (성능/안정성)

### 1.3 이전 결정 / ADR 종속성
- [ADR-0001](./0001-swift-only-ios-first.md): iOS 네이티브 단독 → Metal 직접 접근 가능
- [ADR-0002](./0002-firebase-mvp-backend.md): 백엔드 분리 결정과 무관한 클라이언트 결정

---

## 2. Decision

**filterMarket 셰이더 파이프라인의 1차 언어로 MSL(Metal Shading Language)을 채택한다. 보조용으로 Core Image를 비핫패스(썸네일 생성, 정적 합성)에 사용한다. GLSL ES / OpenGL ES는 사용하지 않는다.**

핵심 결정:
- **셰이더 소스**: `.metal` 파일 (Xcode 빌드 시 자동 컴파일 → `.metallib`)
- **렌더 surface**: `MTKView` 또는 `CAMetalLayer` (`MTLDevice.maximumDrawableCount = 3`)
- **정밀도**: 1080p 입력은 `bgra8Unorm`, LUT는 `rgba16Float` (banding 방지)
- **LUT 형식**: 33³ 1차, 65³ premium (Phase 3+)
- **메이커 셰이더**: 동일 MSL + 화이트리스트 + 컴파일 검증 + Ed25519 서명 (참고: [MSL_SECURITY.md](../MSL_SECURITY.md))
- **Phase 4 Android 진출 시**: 셰이더는 별도 GLSL/AGSL/Vulkan SC 포팅 (자산은 LUT/파라미터 재사용)

---

## 3. Consequences

### 3.1 긍정적 결과
- **최고 성능**: Metal 3 + Apple Silicon → A14 이상에서 60FPS 보장
- **Apple 1급 시민**: API 변경 신뢰성, WWDC 세션 + 샘플 풍부
- **Tooling**: Xcode Metal debugger, Instruments Metal trace, GPU Capture
- **Zero-copy**: `CVMetalTextureCache`로 카메라 YUV → MTLTexture 무복사
- **앱 번들 사이즈**: `.metallib`은 컴파일된 바이너리 → 런타임 컴파일 비용 0
- **메이커 셰이더 일관성**: 동일 MSL 언어 → 검증/감사 단순화

### 3.2 부정적 결과 / 트레이드오프
- **Android 미지원**: Phase 4 Android 진출 시 셰이더 재구현 필요 (다만 LUT/파라미터는 재사용)
- **개발자 풀**: GLSL 대비 MSL 경험자 적음 (단, GLSL과 문법/개념 70% 유사)
- **시뮬레이터 한계**: 일부 Metal feature는 시뮬레이터 미지원 → 실기기 검증 필수
- **메이커 보안**: 임의 MSL 실행 위험 → 다층 방어 필요 (별도 [MSL_SECURITY.md](../MSL_SECURITY.md))

### 3.3 잔여 위험
| 위험 | 완화 |
|---|---|
| 메이커 셰이더 GPU 자원 남용 | AST 화이트리스트 + 컴파일 타임아웃 + 런타임 GPU 시간 모니터링 + Ed25519 서명 ([MSL_SECURITY.md](../MSL_SECURITY.md), RISKS.md R-T01) |
| LUT 정밀도 부족(banding) | dithering(blue noise) + 65³ + RGBA16F 옵션 (RISKS.md R-T02) |
| 4-pass 발열 / 배터리 | thermal/Low Power Mode 모니터링 + FPS 다운 (RISKS.md R-T03) |
| 구형 디바이스 60FPS 미달 | A11/A13 디바이스에서 720p + 30FPS 자동 다운 (RISKS.md R-T04) |
| Phase 4 Android 포팅 비용 | 도메인 모델/.fmpkg 포맷/REST API는 플랫폼 중립 설계 (FMPKG_SCHEMA.md) |

### 3.4 재검토 트리거
- Apple이 Metal을 deprecate하거나 새 GPU API로 전환 (현재 가능성 매우 낮음)
- Phase 4 Android 진출 결정 시 Compose MP + Skia AGSL 검토 → 새 ADR
- 메이커 셰이더 보안 검증이 실현 불가능으로 판명 → `lut+msl` 무기한 연기, `nodegraph → 사전 정의 셰이더` 방식만 사용

---

## 4. Alternatives Considered

### 대안 A: Core Image (`CIFilter` + `CIKernel`) 단독
- **장점**: 짧은 코드, 자동 최적화, 시뮬레이터 친화
- **단점**:
  - 라이브 카메라 핫패스에서 프레임 예측성 떨어짐 (CIContext의 자동 합성 로직)
  - 4-pass 직접 제어 어려움
  - 메이커 업로드 셰이더와 일관성 떨어짐 (CIKernel은 별도 언어)
- **채택하지 않은 이유**: 핫패스 성능/예측성 부족. 다만 비핫패스 보조용으로는 채택.

### 대안 B: GLSL ES + OpenGL ES
- **장점**: 크로스플랫폼 (Android에서도 동일 셰이더 일부 재사용), GLSL 개발자 풀 큼
- **단점**:
  - iOS에서 OpenGL ES deprecated (iOS 12+)
  - 신규 iOS 기능(Metal 3, Tile shading 등) 활용 불가
  - 카메라 zero-copy YUV 통합이 Metal 대비 번거로움
- **채택하지 않은 이유**: deprecated API 채용은 장기 유지보수 위험

### 대안 C: SwiftUI 자체 ShaderLibrary (iOS 17+) 단독
- **장점**: 통합 간편 (`.colorEffect`, `.distortionEffect`)
- **단점**:
  - 4-pass 파이프라인 / LUT 3D / 파라미터 다수에 부적합
  - 메이커 업로드 셰이더 보안 모델 부재
- **채택하지 않은 이유**: 표현력/제어 부족. 일부 단순 효과(Phase 5+)에서 보조용 검토.

### 대안 D: Skia + AGSL (Compose Multiplatform)
- **장점**: 크로스플랫폼 잠재력
- **단점**:
  - iOS Skia 성능 불확실
  - Metal 직접 접근 불가
  - [ADR-0001](./0001-swift-only-ios-first.md)에서 KMP 비채택 결정
- **채택하지 않은 이유**: ADR-0001과 일관

### 대안 E: 자체 셰이더 DSL (노드 그래프 → 백엔드별 컴파일)
- **장점**: 플랫폼 중립
- **단점**:
  - DSL/컴파일러 설계 비용 큼 (수개월)
  - MVP 단계에서 over-engineering
- **채택하지 않은 이유**: Phase 3 노드 그래프 에디터로 부분 도입 검토 — 단, 백엔드는 일단 MSL로 컴파일

### 대안 F: 현상 유지 (셰이더 채택 결정 보류)
- **단점**: PoC 진행 불가, MVP 6주 마감 위반
- **채택하지 않은 이유**: 자명

---

## 5. Implementation Notes

### 5.1 단계별 도입
- **Phase 0**: 단일 fragment 셰이더 + 33³ LUT으로 PoC (1080p 60FPS 검증)
- **Phase 1**: 4-pass 파이프라인 + 15개 큐레이션 LUT 시드
- **Phase 2**: 파라미터 → LUT 베이크 + 그레인/비네트
- **Phase 3+**: 메이커 .fmpkg 셰이더 (lut+msl), 보안 검증 활성화

### 5.2 디바이스 등급 / fallback
- A14 이상 (iPhone 12+): 1080p @ 60FPS, 4-pass, RGBA16F LUT 옵션
- A13 (iPhone 11): 1080p @ 30~60FPS, 4-pass, RGBA8 LUT
- A12/A11 (iPhone XS/X — iOS 17 미지원이 자연 차단)
- thermalState `.serious` 도달 → 720p @ 30FPS 다운
- Metal 디바이스 초기화 실패 → Core Image fallback 모드 안내

### 5.3 도구 / 디버깅
- Xcode → Capture GPU Frame
- Instruments → Metal System Trace
- `os_signpost` 로 4 패스 GPU 시간 트래킹
- MetricKit `MXMetricPayload` 의 GPU/CPU 데이터 수집

### 5.4 .fmpkg 호환성
- engine.type = `lut+params` (MVP) → `lut+msl` (Phase 3+) → `nodegraph` (Phase 5+)
- LUT 자산은 plat-neutral, 셰이더는 platform-specific 슬롯 (참고: [FMPKG_SCHEMA.md](../FMPKG_SCHEMA.md) §13)

---

## 6. References

- [TECH_STACK.md](../TECH_STACK.md) §3 GPU/셰이더 언어
- [SYSTEM_DESIGN.md](../SYSTEM_DESIGN.md) §1 카메라 캡처 + 실시간 필터
- [FMPKG_SCHEMA.md](../FMPKG_SCHEMA.md) §5 셰이더 파일 규칙
- [MSL_SECURITY.md](../MSL_SECURITY.md) — 메이커 셰이더 보안 정책
- [RISKS.md](../RISKS.md) R-T01, R-T02, R-T03, R-T04
- [ADR-0001](./0001-swift-only-ios-first.md) — iOS 네이티브 단독 결정
- Apple Metal Shading Language Specification (MSL 3.x)
- WWDC 2023 "Optimize app power and performance for spatial computing" (Metal trace 기법)
