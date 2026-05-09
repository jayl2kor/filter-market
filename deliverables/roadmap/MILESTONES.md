# moodit · Milestones & Now-Next-Later

> 날짜는 *목표*이며 Phase 게이트 통과 시점에 따라 갱신한다. 결정·완료 사실이 발생하면 § 4 결정 로그에 추가.

## 1. Now-Next-Later

| Horizon | 항목 | 측정 가능한 결과 |
|---|---|---|
| **Now** (이번 sprint) | `.fmpkg` 다운로드/캐시/적용 path | 카메라에서 다운로드한 필터가 실제 렌더 |
| **Now** | Comments→Reviews Swift naming 정리 | route/screen/notification 키 모두 reviews 기준 |
| **Now** | 실기기 FPS 측정(iPhone 12 mini/13/15 Pro) | A14+ 60FPS 평균 / A11~A13 30FPS 평균 |
| **Next** (다음 분기) | TestFlight Internal 베타 | 5~10명 dogfood, 크래시율 < 1% |
| **Next** | 검색·추천 기술 ADR | Algolia vs Typesense 결정 + 비용 모델 |
| **Next** | Maker upload end-to-end | LUT 임포트 → .fmpkg → 검수 제출 |
| **Later** | Android 진출 ADR | Phase 4 게이트, 정량 데이터 기반 |
| **Later** | 모더레이션 자동화 | 신고 임계값 → 자동 큐 |
| **Later** | Stripe Connect 출금 활성 | 첫 메이커 출금 1건 |

## 2. 마일스톤 (가정 일정)

> 일정은 팀 규모/속도에 따라 변동. **각 마일스톤은 *날짜* 기준이 아니라 *DoD* 기준으로 닫는다.**

| ID | 마일스톤 | 목표 분기 | DoD 핵심 |
|---|---|---|---|
| M1 | Phase 1 완료 (TestFlight Beta) | 2026-Q3 | 실제 .fmpkg path + 실기기 통과 + TestFlight Internal |
| M2 | Phase 2 완료 (Maker Upload Live) | 2026-Q4 | LUT→.fmpkg→검수 제출 + 검수 승인 1건 |
| M3 | Phase 3 완료 (Social Live) | 2026-Q4 | Reviews/follows/검색 실 backend + Comments naming 제거 |
| M4 | App Store Production 출시 | 2027-Q1 | M3 + 모더레이션 자동화 + 개인정보 라벨 + 첫 1주 안정 |
| M5 | Phase 4 완료 (Recommendation v1 + Android ADR) | 2027-Q1~Q2 | For You 실데이터 + Android 결정서 |
| M6 | Phase 6 활성 (Coin + Pro) | 2027-Q2 | 첫 IAP 결제 1건 + Pro 가입 1건 |
| M7 | Stripe Connect 첫 출금 | 2027-Q3 | 메이커 1명이 5,000 코인 → KRW 환전 완료 |

> 일정은 *외부 약속이 아닌 내부 계획*. 변경 시 § 4에 기록.

## 3. 측정 시점 (KPI 게이트)

각 마일스톤에서 측정해야 할 핵심 지표 — `../kpi/KPI_TREE.md` 참조.

| 마일스톤 | 측정 KPI | MVP 목표 |
|---|---|---|
| M1 | 카메라 평균 FPS, 크래시율 | FPS ≥ 30 / 크래시 < 1% |
| M3 | D1 리텐션, 첫 촬영까지 시간 | D1 35% / 첫 촬영 < 60s |
| M4 | iOS MAU, 다운로드 전환율 | MAU 8K / 전환 5% |
| M5 | 검색 p95, For You CTR | 측정 가능성 자체가 게이트 |
| M6 | 코인 충전 ARPU, Pro 가입률 | 가설 검증 (1차 데이터) |
| M7 | 메이커 활성률, 출금 신청 비율 | 메이커 200명 / 출금 신청자 ≥ 5명 |

## 4. 결정 로그

> 의사결정과 그 근거를 *날짜순*으로 기록. 변경하지 않는다.

| 날짜 | 결정 | 근거 / 대안 | 결정자 |
|---|---|---|---|
| 2026-05-06 | iOS 단독 출시 (Android는 Phase 4 게이트로 연기) | iOS 비중 65~75% 핵심 페르소나 + 팀 4명 규모 + Compose MP PoC 비용 큼 (`../../docs/RISKS.md` R-B07) | 창립 PM + iOS 리드 |
| 2026-05-06 | Firebase + Cloudflare R2 백엔드 (Postgres+자체 백엔드는 Phase 4 이후 평가) | 50K MAU까지 무료 영역 + 미디어 egress 무료 (R2) (`../../docs/ARCHITECTURE.md` §9.1) | 백엔드 리드 |
| 2026-05-06 | 메이커 분배 60% / Pro 월 ₩4,900 / 코인 4단계 (100/550/1200/3000) | 시장 비교 + IAP 가이드 3.1.1 준수 (`../../docs/CURRENCY_DESIGN.md`) | PM + 재무 |
| 2026-05-06 | Comments → Reviews 전환 (App Store 패턴) | 1인 1리뷰 + verified download + maker reply (`../../docs/REVIEWS_MIGRATION.md`) | PM |
| 2026-05-07 | Phase A/B/C/D/E/F 표현 폐기 → Product Phase 1~4 + UI Work Package 분리 | 화면 패키지와 제품 Phase 혼동 (`../../docs/PHASE_ROADMAP_STATUS.md`) | PM |
| 2026-05-10 | PM 산출물 패키지(`deliverables/*`) 신설 | 신규 PM 인수인계 + 임원/외부 협업자 자료 정리 | Incoming PM |

## 5. 다가오는 게이트 결정 항목 (TBD)

- TestFlight External 확장 시 dogfood 인원 (5명? 50명?)
- 모더레이션 BPO 외주 여부 (Phase 5)
- 추천 학습 데이터 BigQuery export 시점 (Phase 4)
- Android 옵션 A/B/C 결정 기준치 (예: 누적 매출 \$50K, 메이커 200명, MAU 100K 중 ≥ 2건 충족)

---

**참조**: [`ROADMAP.md`](./ROADMAP.md) · [`../kpi/KPI_TREE.md`](../kpi/KPI_TREE.md) · [`../risks/RISK_REGISTER.md`](../risks/RISK_REGISTER.md)
