# ADR-0002: MVP 백엔드로 Firebase 통합 채택, Phase 4 재평가

> Status: Accepted
> Date: 2026-05-06
> Authors: Backend Lead, iOS Lead
> Reviewers: PM, CTO

---

## 1. Context

### 1.1 백엔드 요구사항 (MVP)
- 사용자 인증(Apple/Google/Anonymous)
- 사용자 프로필 + 소셜 그래프(팔로우)
- 필터 메타데이터 + 검색 가능 인덱스
- 다운로드 카운터 / 평점 / 좋아요 / 댓글
- 미디어 업로드 (presigned URL)
- 실시간 알림 (인앱 + APNs)
- 모더레이션 워커 (Phase 5)
- 결제 (Phase 6, 별도)

### 1.2 제약
- 팀 1명 (백엔드)이 풀타임 운영
- MVP 6주 출시 (Phase 1)
- 50K MAU 까지 무료 또는 저렴
- iOS SDK 1급 지원 + 오프라인 캐시 필수
- 미디어는 egress 비용 회피 필요 (모바일은 다운로드 트래픽 크다)

### 1.3 가용 옵션
- Firebase 통합(Auth + Firestore + Cloud Functions)
- Supabase (Postgres + Auth + Storage + Edge Functions)
- AWS Amplify (Cognito + DynamoDB + AppSync + Lambda)
- 자체 백엔드 (Cloud Run + Vapor/Ktor + Postgres)

---

## 2. Decision

**MVP 백엔드는 Firebase 통합(Auth + Firestore + Cloud Functions)으로 채택한다. 미디어 저장은 Cloudflare R2를 직접 사용(Firebase Storage 미사용)한다. Phase 4 진입 시점에 자체 백엔드 분리 옵션(Cloud Run + Vapor 또는 Ktor)을 재평가한다.**

구체:
- **Authentication**: Firebase Auth + Sign in with Apple + Google + Anonymous
- **데이터**: Firestore (asia-northeast3, 서울)
- **API**: Cloud Functions (Node.js 20, Blaze plan)
- **미디어**: Cloudflare R2 (egress 무료)
- **CDN**: Cloudflare (R2 통합 무료)
- **검색**: Firestore 기본 쿼리 (MVP) → Algolia (Phase 4)
- **분석**: BigQuery (Firebase Analytics export) + PostHog

---

## 3. Consequences

### 3.1 긍정적 결과
- **MVP 출시 속도**: 인프라 작성 최소 → 6주 안에 풀스택 가능
- **iOS SDK 품질**: Firebase iOS SDK 1급, 오프라인 캐시 내장
- **보안 룰**: Firestore Rules로 권한 코드 최소화 (참고: [FIRESTORE_RULES.md](../FIRESTORE_RULES.md))
- **무료 티어**: 50K MAU까지 거의 무료 (Cloud Functions 호출량만 과금)
- **운영 부담**: 자동 스케일, 무중단 배포, 로깅 통합
- **미디어 비용**: R2 egress 무료로 월 $19K → ~$795 절감 (100K MAU 기준 추정 — [TECH_STACK.md](../TECH_STACK.md) §6.2)

### 3.2 부정적 결과 / 트레이드오프
- **벤더 락인**: Firestore 데이터 모델은 NoSQL → 추후 Postgres 전환 시 재설계 필요
- **복잡 쿼리 어려움**: JOIN/aggregation 미지원, 인덱스 명시 필요
- **단일 문서 1 write/sec 한계**: 카운터는 샤드 패턴 필요
- **읽기 비용 증가 가능성**: 무한 스크롤 + 캐시 부재 시 비용 폭증 위험 (R-T05)
- **Firebase Storage 미사용**: 미디어는 R2로 분기 → 일관성 떨어지나 egress 절감이 더 큼

### 3.3 잔여 위험
| 위험 | 완화 |
|---|---|
| Firestore 비용 폭증 | 클라이언트 캐싱 + limit 강제 + 매일 비용 모니터링 (RISKS.md R-T05) |
| 추천/검색 한계 | Phase 4 Algolia + BigQuery 도입 |
| 벤더 락인 | 도메인 모델은 Codable 중립 + Repository 추상화로 차후 마이그레이션 가능 |

### 3.4 재검토 트리거 (→ Phase 4 분리 검토)
- Firestore 읽기 비용이 매출의 30% 초과
- p95 레이턴시 > 500ms 지속
- 추천/검색이 Firestore에 종속되어 한계
- 복잡 트랜잭션이 빈번해짐

위 트리거 중 하나라도 발생 시 Phase 4 시작 시점에 새 ADR로 분리 옵션 결정 (Cloud Run + Vapor vs Ktor vs Spring Boot vs Node + NestJS).

---

## 4. Alternatives Considered

### 대안 A: Supabase (Postgres + Auth + Storage + Edge Functions)
- **장점**:
  - Postgres → 복잡 쿼리 / aggregation 자유
  - Open source, 자체 호스팅 가능
  - Row-level Security
- **단점**:
  - iOS SDK 미성숙 (Firebase 대비 오프라인 캐시 약함)
  - Storage egress 유료 (Firebase 동일)
  - Realtime 채널은 PostgreSQL replication 기반 — Firestore 대비 부담
- **채택하지 않은 이유**: iOS SDK 1급 지원이 약함, MVP 출시 속도가 Firebase 대비 떨어짐. Phase 4에서 Postgres 마이그레이션 시 후보.

### 대안 B: AWS Amplify (Cognito + DynamoDB + AppSync + Lambda)
- **장점**: 깊은 AWS 통합, Cognito는 강력
- **단점**:
  - 학습 곡선 높음
  - GraphQL(AppSync) 채택 시 모바일 클라이언트 복잡도 증가
  - 비용 예측 어려움
  - Cognito는 Sign in with Apple 통합이 Firebase 대비 번거로움
- **채택하지 않은 이유**: 1인 백엔드에 부담, MVP 속도 저하

### 대안 C: 자체 백엔드 (Cloud Run + Vapor + Postgres)
- **장점**:
  - 완전한 통제
  - Vapor 채택 시 모바일과 Swift 통일 → Codable 모델 직접 공유
  - 비용 예측 쉬움
- **단점**:
  - MVP 백엔드 인프라 작성 비용이 큼 (8주+ 추정)
  - 인증/세션/이메일 인증 등 부가 인프라 직접 구축
  - 1인 백엔드로 운영 부담
- **채택하지 않은 이유**: 시장 검증 전 인프라 비용이 너무 큼. **Phase 4 분리 옵션의 1순위 후보**.

### 대안 D: Spring Boot / Node NestJS
- **장점**: 풍부한 생태계, 채용 풀
- **단점**: 모바일과 언어 분리, 1인 운영 부담
- **채택하지 않은 이유**: 동일 사유, Phase 4에 Android 결정과 함께 재평가

### 대안 E: 현상 유지 (백엔드 미도입, 단말 P2P)
- **단점**: 마켓플레이스가 본 제품의 핵심 → 비현실적

---

## 5. Implementation Notes

### 5.1 분리 가능 설계
도메인 레이어는 백엔드에 종속되지 않게 설계:
- `FilterRepository` 프로토콜 (Repository 패턴)
- 구체 구현은 `FirestoreFilterRepository` (MVP) → 추후 `RestFilterRepository` 추가 가능
- 모든 도메인 모델은 Codable + 백엔드 무관 JSON

### 5.2 마이그레이션 경로 (Phase 4)
Firestore → Cloud Run + Postgres 마이그레이션 시:
1. API Gateway 도입 (Cloud Run + Vapor) — Firestore 직접 접근 제거
2. 도메인별 점진 이전: filters → users → social_graph → activity
3. Firestore는 실시간 알림 채널로 유지하거나 Postgres LISTEN/NOTIFY로 대체
4. **Auth는 Firebase Auth 유지** (전환 비용 큼, 토큰 호환성)

### 5.3 비용 모니터링
- GCP Billing → Budget alert: $50, $200, $500
- Firestore reads dashboard 매일 확인 (Phase 1 출시 직후 1주)
- 매출 발생 후(Phase 6) 비용/매출 비율 30% 초과 시 알람

---

## 6. References

- [TECH_STACK.md](../TECH_STACK.md) §4 백엔드, §6 미디어 저장
- [ARCHITECTURE.md](../ARCHITECTURE.md) §3.2 백엔드 컴포넌트, §9 확장 시나리오
- [SYSTEM_DESIGN.md](../SYSTEM_DESIGN.md) §4 데이터 모델, §8 API 설계
- [API_SPEC.md](../API_SPEC.md)
- [FIRESTORE_RULES.md](../FIRESTORE_RULES.md)
- [RISKS.md](../RISKS.md) R-T05 — Firebase 비용 예측 실패
- Cloudflare R2 vs S3 비용 비교 — TECH_STACK.md §6.2
- [ADR-0001](./0001-swift-only-ios-first.md) — iOS 단독 출시 결정 (백엔드 결정의 컨텍스트)
