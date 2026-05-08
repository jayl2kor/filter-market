# ADR-0005: Android 진출 결정 — Phase 4 게이트 후속

> Status: Proposed
> Date: 2026-05-07
> Authors: Founders (draft, Ralph run)
> Reviewers: iOS Lead, Backend Lead, PM

---

## 1. Context

[ADR-0001](./0001-swift-only-ios-first.md)은 MVP를 Swift + iOS 단일 스택으로 출시하고, Android 진출 결정을 **Phase 4** 게이트로 명시 연기했다. 본 ADR은 Phase 4 후반 진입 시 사용할 결정 프레임을 미리 문서화한다(실제 전환은 Phase 4 종료 시점 데이터로 다시 사인오프).

### 1.1 알려진 사실(2026-05-07 기준)
- moodit은 iOS 단독, MVP `52d2502` 시점.
- 카메라 60FPS Metal 파이프라인이 핵심 차별점.
- `.fmpkg`, REST API는 ADR-0001 §5에 따라 **플랫폼 중립** 으로 설계되어 있음. iOS-only 코드는 UI/렌더 파이프라인에 한정.
- 시장 데이터(MAU, 매출, 메이커 수)는 아직 없음 — 본 ADR은 **결정의 프레임만** 미리 정의.

### 1.2 후보 옵션
- **옵션 A**: 네이티브 Kotlin (Android 별도 코드베이스, Jetpack Compose UI)
- **옵션 B**: Compose Multiplatform 도입 (UI 일부 공유, iOS 측은 점진적 전환)
- **옵션 C**: iOS 단독 유지 (Phase 5+에 재검토)
- **옵션 D**: Flutter (도메인+UI 모두 새 언어로 재작성)

옵션 D는 이미 ADR-0001에서 셰이더 표현력을 이유로 거부됐으므로 본 ADR에서는 다시 다루지 않는다.

---

## 2. Decision (proposal)

**Phase 4 종료 시점에 다음 게이트 평가를 통과하면 옵션 A(네이티브 Kotlin)로 Android 진출한다. 미통과 시 옵션 C(iOS 단독 유지)로 6개월 추가 데이터 수집 후 재평가.**

옵션 B(Compose Multiplatform)는 본 ADR에서 **현재로선 비채택**, 단 Phase 6+에 검토 가능 후보로 남긴다.

### 2.1 게이트 평가 체크리스트
| 지표 | 게이트 |
|---|---|
| iOS 누적 다운로드 | ≥ 100k |
| iOS MAU | ≥ 20k |
| 메이커 활성 비율 | 메이커 활동 ≥ 200명 / 월 |
| 매출 (Phase 6 진입 시) | 월 ≥ $5k 또는 페이드 컨버전 ≥ 1.5% |
| iOS 미수용 시장에서 들어온 demand 신호 | 인도/SEA/중남미 사용자 요청 ≥ 100건 또는 PIPL/EU 외부 메이커 신청 ≥ 50명 |
| 팀 인원 | Android 1명 풀타임 채용 가능한 자본 상태 |

5/6 통과 시 옵션 A 진입, 4/6 이하면 옵션 C 유지.

---

## 3. Consequences

### 3.1 옵션 A (네이티브 Kotlin) 채택 시

**긍정적**
- iOS와 동일한 60FPS 카메라/Metal 수준의 표현력 가능 (Vulkan + RenderScript 후속, 또는 OpenGL ES 4.x + Skia)
- 도메인/REST API/`.fmpkg`는 100% 재사용
- Android 마켓 큐레이션 (Play Featured) 가능성

**부정적**
- 인력 1명 이상 풀타임 추가 필요
- 출시 시점 6~9개월 추가
- iOS·Android 간 디자인/QA double cost (피처 평행 출시 부담)

**잔여 위험**
- Vulkan/Metal 표현력 차이 (예: Metal performance shaders 일부는 Android 미지원) → 일부 필터에서 시각적 차이 발생 가능. 완화: 기준 LUT-only 필터를 `engine.type == "lut+params"`로 강제하고, MSL 셰이더 의존 필터는 iOS-only 마크.

### 3.2 옵션 C (iOS 단독 유지) 채택 시
- 인력/시간 절약, 핵심 사용자에 집중
- 기회비용: Android 70% 시장 미커버 (특히 인도, SEA, 중남미)
- 리스크: 경쟁사 Android 우선 진입 시 시장 선점 손실

### 3.3 옵션 B (Compose Multiplatform) — 현재 비채택 사유
1. iOS 측 Skia/Compose iOS 측 카메라 surface integration이 ADR-0001 시점 대비 *충분히* 성숙해졌다는 증거가 아직 없다(2026 기준 JetBrains는 stable 직전).
2. 도입하려면 iOS 코드를 일부 재작성해야 하는데, 이미 SwiftUI + Metal로 빌드된 카메라/에디터를 다시 만들 비용이 크다.
3. 4-pass Metal 셰이더는 KMP에서 직접 표현하기 어려움 (ADR-0001 §4 동일 사유).
4. 단, **Phase 6+** 시점에 다음이 모두 만족하면 옵션 B 재검토 ADR 작성:
   - JetBrains Compose iOS GA + Metal 인터롭 매뉴얼 출간
   - moodit 코드베이스 안정 + 인력 5명 이상
   - 신규 OS feature 추가 빈도 감소 (재작성 ROI 발생)

---

## 4. Alternatives Considered

### 대안 A: 옵션 A 채택 (위 §2.1 게이트 통과 시)
이미 위 §3.1에 분석. 기준 시나리오.

### 대안 B: 옵션 C 무조건 유지 (Android 진출 영구 보류)
- 단점: 글로벌 MAU 상한 제약 영구화, 경쟁사 진입 리스크
- 채택하지 않은 이유: ADR-0001은 Phase 4 재평가를 명시했고, 시장 데이터 누적 후 거부할 근거가 없으면 진출이 옳다.

### 대안 C: 옵션 B 즉시 도입 (KMP)
- 단점: §3.3에 분석한 표현력/마이그레이션 비용
- 채택하지 않은 이유: 현재 시점 ROI가 음수.

### 대안 D: 외부 에이전시에 Android 발주
- 단점: 카메라/Metal-equivalent 셰이더 표현력은 핵심 IP, 외주가 어려움. 디자인 일관성 유지 비용.
- 채택하지 않은 이유: 핵심 차별점 외주는 위험.

---

## 5. Implementation Notes (Phase 4 진입 시)

### 5.1 옵션 A 채택 시 단계
1. **0~1개월**: Android Lead 채용 + Compute baseline PoC
   - Camera2 API + GPU 셰이더 (OpenGL ES 3.0 + Vulkan 옵션) PoC
   - `.fmpkg` 로더 Kotlin 구현 + 한국어 텍스트 픽업
2. **1~3개월**: Marketplace + 다운로드/적용 흐름
3. **3~6개월**: 에디터 + 업로드 흐름
4. **6~9개월**: Closed Beta → 정식 출시

### 5.2 공유 자산 매핑
| 자산 | iOS 상태 | Android 재사용 |
|---|---|---|
| `.fmpkg` 컨테이너 / manifest | 정의됨 ([FMPKG_SCHEMA.md](../FMPKG_SCHEMA.md)) | 100% |
| REST/Cloud Function API | 정의됨 ([API_SPEC.md](../API_SPEC.md)) | 100% |
| Firestore 스키마 / 보안룰 | 정의됨 ([FIRESTORE_RULES.md](../FIRESTORE_RULES.md)) | 100% |
| Metal 셰이더 | iOS 전용 (MSL) | Vulkan/GLSL로 포팅 — 셰이더 매크로 단위 재구현 |
| 디자인 시스템 (FMColors/Sp) | iOS Swift | Kotlin/Compose 토큰으로 재선언 |
| 카메라 파이프라인 | AVCapture + Metal | Camera2 + GPU 셰이더 |

### 5.3 게이트 미통과 시(옵션 C 6개월 연장)
- 6개월 후 다시 같은 게이트로 재평가
- 그 사이 데이터 수집 우선순위:
  - 비-iOS 사용자가 가입 의향을 보이는 채널 (waitlist / TF 트래픽)
  - 한국·일본·미국 외 시장의 콘텐츠 메이커 진입 의향
  - iOS 매출 곡선

---

## 6. Decision Status / Sign-off

본 ADR은 **Proposed**. 실제 전환은 Phase 4 종료 시점에 §2.1 게이트 데이터 + Founders 사인오프를 거쳐 **Accepted**로 전환한다. 본 Ralph 실행에서 ADR을 머지하지만 그 자체로 자동 옵션 A 채택을 의미하지 않는다.

---

## 7. References

- [ADR-0001](./0001-swift-only-ios-first.md) — Swift + iOS 단독 채택 (이 ADR의 상위)
- [ADR-0003](./0003-metal-msl-shader-pipeline.md) — Metal/MSL 의존성
- [FMPKG_SCHEMA.md](../FMPKG_SCHEMA.md) — 플랫폼 중립 패키지 포맷
- [API_SPEC.md](../API_SPEC.md) — REST API 명세
- [RISKS.md](../RISKS.md) R-B07 — Android 시장 기회비용
- JetBrains Compose Multiplatform iOS Status: https://www.jetbrains.com/lp/compose-multiplatform/
- Android Vulkan + Camera2 sample: https://github.com/android/camera-samples
