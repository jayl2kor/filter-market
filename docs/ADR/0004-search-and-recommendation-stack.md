# ADR-0004: 검색 / 추천 인프라 — Typesense self-hosted (Phase 4)

> Status: Proposed
> Date: 2026-05-07
> Authors: Backend Lead (draft, Ralph run)
> Reviewers: Founders, iOS Lead

---

## 1. Context

Phase 4 진입 시 moodit이 닫아야 하는 검색/추천 요구는 다음과 같다.

- 필터 prefix/full-text 검색 (한국어/영문 혼용, 태그/카테고리 필터)
- 메이커 핸들 검색
- 정렬: 인기 / 최신 / 별점
- 추천 v1: 인기 + 최신성 가중
- 추천 v2: co-occurrence (다운로드한 유저가 또 다운로드한 필터)
- For You 피드 backend 연결 (목록 형태 mock → 실제 추천 결과)
- 운영 인원 1~2명 백엔드 팀, 비즈니스 검증 단계 — 비용 민감

`docs/PRD.md`, `docs/SYSTEM_DESIGN.md`, `docs/TECH_STACK.md` 모두 검색/추천 백엔드를 미정 상태로 둔다. Firestore 쿼리만으로는 prefix·정렬 조합과 co-occurrence를 효율적으로 풀 수 없다. ADR-0002(Firebase MVP)의 적용 한계점이기도 하다.

---

## 2. Decision

**검색/추천 v1 인프라로 Typesense self-hosted (단일 노드, Docker on GCP Compute Engine)를 채택한다. 추천 v2 도입 시점에 외부 추천 SaaS(Algolia Recommend / Recombee)로 교체할지 재평가한다.**

- **인덱서**: Cloud Function (Firestore trigger) → Typesense `documents.upsert`. 인덱스 4종: `filters`, `users`, `tags`, `categories`.
- **클라이언트 접근**: iOS는 Cloud Function 프록시(`/search`)를 통해 Typesense에 접근. 직접 SDK 호출 금지 (API 키 노출 방지).
- **추천 v1**: 일별 Cloud Run job이 `popular_24h`, `popular_7d`, `newest`를 미리 계산해 Typesense `recommended_filters` 인덱스에 적재.
- **추천 v2**: BigQuery export → 주간 batch job → co-occurrence 매트릭스 → Typesense `co_occurrence` 인덱스. Phase 4 후반.
- **이벤트 로그**: download/view/search/install events → BigQuery (`docs/ADR/0002-firebase-mvp-backend.md`의 GA4 + 별도 events 테이블).

---

## 3. Consequences

### 3.1 긍정적 결과
- **비용 예측 가능**: 단일 노드 Compute Engine ~$30/월, Algolia 동일 워크로드 $200~500/월 대비 1/10 수준.
- **데이터 주권**: self-hosted라 외부 SaaS에 인덱스 콘텐츠/유저 데이터 공유 없음 — 향후 GDPR/PIPL 대응 단순.
- **러닝**: Typesense는 OSS Apache 2.0, 운영팀이 내부 동작을 검증 가능.
- **속도**: typo tolerance + 한국어 토크나이저 기본 내장, p95 < 30ms.

### 3.2 부정적 결과 / 트레이드오프
- **운영 부담**: 노드 백업/복원/업그레이드를 우리가 진다. Algolia/Elastic Cloud는 0이다.
- **단일 노드 장애 리스크**: Phase 4 초기에는 read replica 없이 시작. 다운타임 시 검색 화면 disabled fallback 필요.
- **추천 알고리즘은 직접 작성**: Algolia Recommend / Recombee의 모델을 못 쓴다. v2 co-occurrence는 SQL + Python 직접 구현.

### 3.3 잔여 위험
| 위험 | 완화 |
|---|---|
| Typesense 단일 노드 다운 → 검색 전체 다운 | iOS 클라이언트는 Firestore-only 모드 fallback (정렬은 createdAt 단일) |
| 한국어/영어 외 타 언어 정확도 저하 | Phase 5에서 `nori`/`mecab` 토크나이저 검토, 필요시 OpenSearch로 마이그레이션 |
| 인덱싱 lag로 신규 필터가 30초~수분 노출 안 됨 | Cloud Function trigger는 Firestore write 기준 sub-second; 우려 시 직접 upsert API 추가 호출 |

### 3.4 재검토 트리거
- Typesense 노드의 p99 latency가 100ms 초과 또는 월 다운타임 1시간 초과
- 추천 CTR 목표 미달(절대값은 §4 추천 v2의 베이스라인 대비 −20%)
- 검색 관련 Issue/Bug가 sprint 당 3건 이상
- 위 시그널 중 2개 이상 만족 → Algolia / Recombee로 마이그레이션 ADR

---

## 4. Alternatives Considered

### 대안 A: Algolia (managed)
- **요약**: SaaS 검색 + Algolia Recommend 결합
- **장점**: 운영 부담 0, p95 < 20ms 보장, recommend 모델 무료 이용, dashboard 우수
- **단점**:
  - 비용: 1k MAU 무료 → 그 이후 $1/1k 검색. moodit 추정 1k 검색/MAU/월 → MAU 10k에서 월 ~$100, MAU 100k에서 ~$1,000+
  - 인덱스 콘텐츠가 외부 클라우드 → 한국 PIPL/EU GDPR 데이터 처리 위탁 계약 추가 필요
  - 락인: 마이그레이션 비용
- **채택하지 않은 이유**: 비용 곡선이 너무 가파르고 데이터 주권 이슈. **단**, Phase 5 이후 운영 인력 부족으로 self-host가 부담될 시 우선 마이그레이션 후보.

### 대안 B: Meilisearch (self-hosted)
- **요약**: Rust 기반 OSS, 단일 바이너리, Algolia 닮은 API
- **장점**:
  - 가벼움, single binary, 설정 단순
  - typo tolerance 양호
- **단점**:
  - 한국어 토크나이저 약함 (Typesense는 ICU + 자체 한국어 분석기 내장)
  - 추천 / aggregations가 Typesense 대비 약함
  - 클러스터링/replica 제한적 (당시 점검 시 ROC 미흡)
- **채택하지 않은 이유**: 한국어 검색 품질 + replica 로드맵에서 Typesense가 우위.

### 대안 C: Elasticsearch / OpenSearch
- **요약**: 산업 표준 검색 엔진
- **장점**: 강력함, 풍부한 분석/aggregations, Korean nori 분석기 우수
- **단점**:
  - 운영 부담 큼 (JVM 튜닝, 마스터/데이터 노드 분리, snapshot 정책)
  - 메모리 fingerprint 1GB+ → Compute Engine 비용 상승
  - MVP 단계의 수십 만 필터 인덱스에는 과한 stack
- **채택하지 않은 이유**: 현재 트래픽 규모 대비 운영 복잡도 과다. Phase 5+ DAU 100k 도달 시 OpenSearch로 마이그레이션 검토.

### 대안 D: Firestore-only (현상 유지)
- **요약**: 정렬과 필터를 Firestore 인덱스로 처리, 검색은 prefix `where` 절
- **장점**: 추가 인프라 0, 비용 거의 0
- **단점**: typo tolerance 없음, full-text 불가, 한국어 prefix는 형태소 단위로만 의미가 있음, co-occurrence 추천 불가
- **채택하지 않은 이유**: 검색 요구를 만족 못함. For You 피드 backend 연결 불가능.

### 대안 E: Pinecone / Qdrant (벡터 검색)
- **요약**: 임베딩 기반 의미 검색 + 추천
- **장점**: 임베딩 1번이면 검색 + 추천 통합
- **단점**: 임베딩 모델/파이프라인 구축 비용, 콜드스타트 데이터 부족, 운영 새 스택
- **채택하지 않은 이유**: Phase 4 시점 데이터 양 부족 + ML ops 인력 미보유. Phase 6+ 추천 고도화 시 재검토.

### 대안 F: Recombee / Algolia Recommend SaaS만 추천에 사용 + Firestore 검색
- **요약**: 검색은 Firestore, 추천만 외부 SaaS
- **장점**: 추천 알고리즘 책임 외주
- **단점**: 검색 약점 그대로, 추천 SaaS 비용은 별도 발생
- **채택하지 않은 이유**: 검색 요구를 닫지 못함.

---

## 5. Implementation Notes

### 5.1 Phase 4-A: Typesense 단일 노드 + 검색
1. Cloud Function `onFilterWrite` → Typesense upsert
2. Cloud Function `/search` proxy (rate limit + auth)
3. iOS `SearchScreen` 클라이언트 → `/search` 호출
4. 인덱스 스키마: `filters` (id, title, slug, tags, category, makerHandle, downloadCount, createdAt, rating)
5. Cloud Run 노드 백업: 일 1회 GCS snapshot

### 5.2 Phase 4-B: 추천 v1
1. Cloud Run job (Daily 03:00 KST): `popular_24h`, `popular_7d`, `newest` 계산
2. 결과를 Typesense `recommended_filters` 인덱스에 적재
3. iOS For You 피드 → `/search/recommended?type=popular_24h`

### 5.3 Phase 4-C: 추천 v2 (co-occurrence)
1. BigQuery export (events table)
2. 주간 batch (Python pandas/Spark): user-filter co-occurrence 매트릭스
3. 결과를 Typesense `co_occurrence` 인덱스에 적재
4. iOS `FilterDetailScreen` → "이 필터를 본 사람이 또 본 필터" 섹션

### 5.4 모니터링
- Cloud Logging metrics: `/search` p50/p95/p99
- Synthetic search probe (Pub/Sub cron) → Cloud Monitoring alert

---

## 6. Decision Status / Sign-off

본 ADR은 **Proposed** 상태로 PR 머지된다. Phase 4 진입 시점(아직 미정)에 사람 사인오프(Founders + Backend Lead) 후 **Accepted** 로 전환한다. 그 시점에 비용/시장 데이터를 다시 검토한다.

후속 작업 후보 (TODO.md §7로 트래킹):
- POC: Typesense 노드 1개 + 1k 필터 시드 → 검색 latency 측정
- 운영 비용 견적: Compute Engine + 백업 GCS + 모니터링
- 추천 v1 베이스라인 측정 방법 정의 (CTR / dwell time)

---

## 7. References

- [TECH_STACK.md](../TECH_STACK.md) — 백엔드 스택 표
- [SYSTEM_DESIGN.md](../SYSTEM_DESIGN.md) — 검색/추천 절
- [ADR-0002](./0002-firebase-mvp-backend.md) — Firebase MVP 백엔드 채택
- Typesense 공식 문서: https://typesense.org/docs/
- Algolia Pricing: https://www.algolia.com/pricing/
- Recombee: https://www.recombee.com/
