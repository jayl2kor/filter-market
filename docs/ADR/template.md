# ADR-NNNN: <Title>

> Status: Proposed | Accepted | Deprecated | Superseded by ADR-XXXX
> Date: YYYY-MM-DD
> Authors: <name(s)>
> Reviewers: <name(s)>

---

## 1. Context (배경)

이 결정이 필요한 비즈니스/기술적 상황을 기술한다.

- 지금 어떤 문제를 풀려고 하는가
- 이 결정이 영향을 받는 제약 (시간/팀/비용/규제 등)
- 관련 이전 결정 / ADR
- 발견된 새로운 정보 / 데이터

> 대안을 토론하기 전에, **현재 상태**와 **변화의 필요성**을 명확히 한다.

---

## 2. Decision (결정)

채택한 대안을 명령형 한 문장으로 시작 → 짧은 보강 단락.

> 예: "MVP 백엔드로 Firebase Auth + Firestore + Cloud Functions를 통합 채택한다. Phase 4에 Cloud Run + Vapor/Ktor 분리 옵션을 재평가한다."

핵심 포인트:
- 누가 / 무엇을 / 언제부터 적용
- 적용 범위(전체 / 특정 모듈 / 특정 Phase)
- 영향받는 영역 (리포지토리 / 인프라 / 팀)

---

## 3. Consequences (결과)

채택 결정의 좋고 나쁜 결과를 모두 기록한다 (정직하게).

### 3.1 긍정적 결과
- ...

### 3.2 부정적 결과 / 트레이드오프
- ...

### 3.3 잔여 위험
- ...

### 3.4 성공/실패 측정 기준
- 어떤 신호가 나오면 결정이 유효 / 무효한지 (재검토 트리거)

---

## 4. Alternatives Considered (검토한 대안)

각 대안에 대해:

### 대안 A: <name>
- 요약:
- 장점:
- 단점:
- 채택하지 않은 이유:

### 대안 B: <name>
- ...

### 대안 C: 현상 유지 (do nothing)
- 어떤 비용이 누적되는가

---

## 5. Implementation Notes (선택)

- 마이그레이션 단계
- 의존하는 ADR / 후속 ADR 후보
- 관련 PR / 이슈 / RFC

---

## 6. References (참고)

- 관련 내부 문서: [TECH_STACK.md](../TECH_STACK.md), [ARCHITECTURE.md](../ARCHITECTURE.md), ...
- 외부 자료(공식 문서/블로그/벤치마크)
- 토론 기록 (회의 노트, RFC)
