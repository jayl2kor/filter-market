# Architecture Decision Records (ADR)

> 본 디렉토리는 moodit의 **아키텍처 결정 기록**을 모은다. 결정의 맥락(why)을 시간순으로 보존하여 후임자가 같은 함정을 반복하지 않도록 한다.

---

## ADR이란

> "An architectural decision record (ADR) is a document that captures an important architectural decision made along with its context and consequences."
> — Michael Nygard

핵심 속성:
- **불변(immutable)**: 한 번 Accepted 된 ADR은 수정하지 않는다 (오타 외). 변경이 필요하면 새 ADR을 만들어 이전 ADR을 `Superseded by ADR-XXXX`로 표시.
- **단일 결정**: 한 ADR은 한 결정만 다룬다.
- **번호 + 짧은 슬러그**: `0001-swift-only-ios-first.md`
- **상태**: Proposed → Accepted → Deprecated/Superseded

---

## 작성 시점

ADR은 다음 시점에 작성한다:

1. 새로운 기술/프레임워크 채택 또는 교체
2. 기존 결정을 뒤집을 때 (이전 ADR의 supersede)
3. 비-자명한 트레이드오프가 있는 설계 결정
4. 외부 의존성 추가
5. Phase 게이트 결정 (예: Phase 4 Android 진출)
6. 보안/규정 관련 결정

---

## 작성 절차

1. `template.md`를 복사 → `NNNN-slug.md`
2. 번호는 마지막 ADR + 1 (zero-padded 4자리)
3. PR로 제출 → 1명 이상 검토 + 적어도 1주 코멘트 기간
4. Accepted 상태로 머지 (또는 Rejected → 폐기 폴더로 이동)
5. 관련 문서(PRD/ARCH/SYSTEM_DESIGN/TECH_STACK/RISKS) cross-reference 갱신

---

## 인덱스

| ID | 제목 | 상태 | 날짜 |
|---|---|---|---|
| [0001](./0001-swift-only-ios-first.md) | Swift + iOS 네이티브 단독 출시 (Compose MP → Swift only 전환) | Accepted | 2026-05-06 |
| [0002](./0002-firebase-mvp-backend.md) | MVP 백엔드로 Firebase 통합 채택, Phase 4 재평가 | Accepted | 2026-05-06 |
| [0003](./0003-metal-msl-shader-pipeline.md) | Metal + MSL을 1차 셰이더 파이프라인으로 채택 | Accepted | 2026-05-06 |

---

## 관련 문서

- [template.md](./template.md) — ADR 작성 양식
- 상위 [README.md](../README.md)
- 결정 근거가 본 ADR에 반영된 문서들:
  - [TECH_STACK.md](../TECH_STACK.md)
  - [ARCHITECTURE.md](../ARCHITECTURE.md)
  - [SYSTEM_DESIGN.md](../SYSTEM_DESIGN.md)
  - [RISKS.md](../RISKS.md)
