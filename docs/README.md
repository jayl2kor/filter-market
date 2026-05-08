# moodit Docs

> 문서 진입점. 현재 진행 기준은 [PHASE_ROADMAP_STATUS.md](./PHASE_ROADMAP_STATUS.md) 하나로 본다.

## 1. 먼저 볼 문서

| 목적 | 문서 | 상태 |
|---|---|---|
| 현재 진행 상황과 다음 작업 | [PHASE_ROADMAP_STATUS.md](./PHASE_ROADMAP_STATUS.md) | Current |
| 원래 제품 로드맵 원본 | [TASK_LIST.md](./TASK_LIST.md) | Current |
| 제품 요구사항 | [PRD.md](./PRD.md) | Current |
| 개발 환경 셋업 | [SETUP.md](./SETUP.md) | Current |
| 네비게이션/버튼 액션 매핑 | [NAVIGATION.md](./NAVIGATION.md) | Current |
| 화면/액션 QA 정의 | [SCREEN_ACTIONS_QA_DEFINITION.md](./SCREEN_ACTIONS_QA_DEFINITION.md) | Current |
| QA 결과/잔여 게이트 | [QA_FINDINGS.md](./QA_FINDINGS.md) | Current |

진행 상태를 판단할 때는 `PHASE_ROADMAP_STATUS.md`를 우선한다. 다른 계획 문서는 세부 설계나 과거 결정의 reference로 본다.

## 2. 문서 상태 기준

| 상태 | 의미 |
|---|---|
| Current | 현재 기준 문서 |
| Reference | 상세 설계나 보조 자료로 유효하지만 진행 기준은 아님 |
| Legacy | 과거 계획/상태 기록. 새 계획 판단에는 사용하지 않음 |
| Superseded | 다른 문서로 대체됨. 링크 보존 목적 |

## 3. Current 문서

### Product / Roadmap

| 문서 | 역할 |
|---|---|
| [PHASE_ROADMAP_STATUS.md](./PHASE_ROADMAP_STATUS.md) | Product Phase 1~4 기준 현재 상태, 남은 작업, 다음 순서 |
| [TASK_LIST.md](./TASK_LIST.md) | Product Phase 0~6 원본 작업 분해 |
| [PRD.md](./PRD.md) | 제품 비전, 사용자, KPI, 기능 범위 |
| [RISKS.md](./RISKS.md) | 기술/제품/운영 리스크 |

### Architecture / API

| 문서 | 역할 |
|---|---|
| [ARCHITECTURE.md](./ARCHITECTURE.md) | 시스템 아키텍처 개요 |
| [SYSTEM_DESIGN.md](./SYSTEM_DESIGN.md) | 주요 컴포넌트 상세 설계 |
| [TECH_STACK.md](./TECH_STACK.md) | 기술 스택 결정과 근거 |
| [API_SPEC.md](./API_SPEC.md) | API/Firestore endpoint 설계 |
| [FIRESTORE_RULES.md](./FIRESTORE_RULES.md) | Firestore rules 초안 |
| [FMPKG_SCHEMA.md](./FMPKG_SCHEMA.md) | `.fmpkg` 패키지 스펙 |

### Design / UX

| 문서 | 역할 |
|---|---|
| [BRAND.md](./BRAND.md) | 브랜드 원칙 |
| [DESIGN_SYSTEM.md](./DESIGN_SYSTEM.md) | 디자인 시스템 |
| [DESIGN_PRINCIPLES.md](./DESIGN_PRINCIPLES.md) | UX/시각 원칙 |
| [DESIGN_LOG.md](./DESIGN_LOG.md) | 디자인 변경 로그 |
| [DESIGN_TOKENS.json](./DESIGN_TOKENS.json) | 토큰 원본 |
| [EMPTY_STATES.md](./EMPTY_STATES.md) | 빈 상태 패턴 |
| [MODAL_PATTERNS.md](./MODAL_PATTERNS.md) | 모달 패턴 |
| [MOTION_SPEC.md](./MOTION_SPEC.md) | 모션/전환 스펙 |
| [PERMISSIONS_FLOW.md](./PERMISSIONS_FLOW.md) | 권한 흐름 |
| [I18N_MIGRATION.md](./I18N_MIGRATION.md) | i18n 마이그레이션 |
| [REVIEWS_MIGRATION.md](./REVIEWS_MIGRATION.md) | Comments → Reviews 전환 결정 |
| [SCREEN_ACTIONS_QA_DEFINITION.md](./SCREEN_ACTIONS_QA_DEFINITION.md) | 전체 화면, 액션 ID, QA 우선순위 정의 |
| [QA_FINDINGS.md](./QA_FINDINGS.md) | 자동 QA 결과와 남은 실기기/외부 서비스 검증 게이트 |

### Engineering / Ops

| 문서 | 역할 |
|---|---|
| [CODING_CONVENTIONS.md](./CODING_CONVENTIONS.md) | 코딩 컨벤션 |
| [TESTING_STRATEGY.md](./TESTING_STRATEGY.md) | 테스트 전략 |
| [EXTERNAL_SETUP.md](./EXTERNAL_SETUP.md) | 외부 계정/서비스 셋업 |
| [M0_DEVICE_VALIDATION.md](./M0_DEVICE_VALIDATION.md) | 실기기 검증 체크리스트 |
| [MSL_SECURITY.md](./MSL_SECURITY.md) | MSL 보안 정책 |
| [ASSETS_NEEDED.md](./ASSETS_NEEDED.md) | 필요한 시각 자산 목록 |
| [CODE_REVIEW.md](./CODE_REVIEW.md) | 코드 리뷰 누적 기록 |
| [GAPS_AUDIT.md](./GAPS_AUDIT.md) | 갭 감사 기록 |

### ADR

| 문서 | 역할 |
|---|---|
| [ADR/README.md](./ADR/README.md) | ADR 인덱스 |
| [ADR/0001-swift-only-ios-first.md](./ADR/0001-swift-only-ios-first.md) | iOS first 결정 |
| [ADR/0002-firebase-mvp-backend.md](./ADR/0002-firebase-mvp-backend.md) | Firebase MVP backend 결정 |
| [ADR/0003-metal-msl-shader-pipeline.md](./ADR/0003-metal-msl-shader-pipeline.md) | Metal/MSL pipeline 결정 |

## 4. Reference / Legacy 문서

아래 문서는 삭제하지 않는다. 다만 현재 진행 기준으로 사용하지 않는다.

| 문서 | 상태 | 현재 대체 기준 |
|---|---|---|
| [IMPLEMENTATION_STATUS.md](./IMPLEMENTATION_STATUS.md) | Superseded | [PHASE_ROADMAP_STATUS.md](./PHASE_ROADMAP_STATUS.md) |
| [IMPLEMENTATION_PLAN.md](./IMPLEMENTATION_PLAN.md) | Reference | [TASK_LIST.md](./TASK_LIST.md), [PHASE_ROADMAP_STATUS.md](./PHASE_ROADMAP_STATUS.md) |
| [SCREEN_IMPLEMENTATION_BACKLOG.md](./SCREEN_IMPLEMENTATION_BACKLOG.md) | Reference | [PHASE_ROADMAP_STATUS.md](./PHASE_ROADMAP_STATUS.md), [NAVIGATION.md](./NAVIGATION.md) |
| [SCREENS_PLAN.md](./SCREENS_PLAN.md) | Reference | [NAVIGATION.md](./NAVIGATION.md), [PHASE_ROADMAP_STATUS.md](./PHASE_ROADMAP_STATUS.md) |
| [DESIGN_INTEGRATION_PLAN.md](./DESIGN_INTEGRATION_PLAN.md) | Legacy | [DESIGN_LOG.md](./DESIGN_LOG.md), [PHASE_ROADMAP_STATUS.md](./PHASE_ROADMAP_STATUS.md) |
| [CURRENCY_DESIGN.md](./CURRENCY_DESIGN.md) | Reference | Product Phase 6 진입 시 재검토 |

## 5. 정리 원칙

1. 진행 기준은 `PHASE_ROADMAP_STATUS.md`로 통일한다.
2. 상세 작업 분해 원본은 `TASK_LIST.md`에 둔다.
3. 화면 라우팅과 버튼 흐름은 `NAVIGATION.md`를 기준으로 둔다.
4. 과거 계획 문서는 삭제하지 않고 `Legacy` 또는 `Superseded`로 표시한다.
5. 새 문서를 추가하기 전 기존 Current 문서에 섹션으로 넣을 수 있는지 먼저 확인한다.
