# moodit · KPI Tree

> **North Star**: WAFA — Weekly Active Filter Applications. 마켓·에디터·카메라 가치사슬을 한 번에 측정.
> **검토 주기**: 주간(획득/활성화/참여), 월간(메이커 양면 시장), 분기(수익).

## 1. North Star

**WAFA = (촬영 시 필터 적용 횟수) + (사진 후보정 시 필터 적용 횟수)** — 1주일 동안 합산.

이 지표가 의미 있는 이유:
- **사용자 가치**: 필터를 *적용*한다는 것은 단순 다운로드가 아닌 실제 사용 의도 발현.
- **메이커 가치**: 적용 횟수 = 메이커 분배 베이스(`recordUse`).
- **마켓 가치**: 다운로드→적용 전환이 살아 있으면 마켓이 도는 것.

## 2. KPI Tree

```
WAFA (북극성)
│
├── 신규 사용자 적용 (Activation)
│   ├── 신규 가입자 수 (DAU 신규)
│   ├── 첫 촬영까지 시간 (T2FS · Time to First Shot)
│   └── 첫 필터 다운로드까지 시간 (T2FD)
│
├── 기존 사용자 적용 (Engagement)
│   ├── D1 / D7 / D30 리텐션
│   ├── 사용자당 일평균 필터 적용 (filters/user/day)
│   ├── 마켓 둘러보기 → 다운로드 전환율
│   └── 즐겨찾기/컬렉션 보유 사용자 비율
│
├── 메이커 공급 (Supply)
│   ├── 누적 업로드 필터 수
│   ├── 주간 활성 메이커 수 (1회 이상 업로드)
│   ├── 검수 통과율 (approved / submitted)
│   └── 평균 검수 SLA (제출→결과)
│
└── 수익 (Phase 6)
    ├── 코인 충전 ARPU
    ├── Pro 가입률 / MRR
    ├── 메이커 적립 코인 / 사용 코인 비율 (코인 속도)
    └── 메이커 출금 신청 비율
```

## 3. Phase별 목표

### Phase 1 완료 (TestFlight Beta 가능 시점)
| 지표 | 목표 |
|---|---|
| 카메라 평균 FPS | ≥ 30 (전체) / ≥ 60 (A14+) |
| 크래시율 (Crashlytics) | < 1% |
| 첫 촬영까지 시간 (T2FS) | < 60s |
| 다운로드 cache hit ratio | ≥ 80% (CDN warm 후) |

### Phase 3 완료 (App Store Production 직전)
| 지표 | 목표 |
|---|---|
| iOS MAU | 8K |
| D1 리텐션 | 35% |
| 사용자당 일평균 필터 적용 | 3 |
| 마켓 → 다운로드 전환 | 5% |
| 누적 업로드 필터 | 1K |
| 메이커 활성률(주 1+ 업로드) | 200명 |
| 검수 SLA (제출→결과) | 24h 이내 95% |

### 12개월 (Phase 5~6 활성 후)
| 지표 | 목표 |
|---|---|
| iOS MAU | 200K |
| D1 리텐션 | 45% |
| 첫 촬영까지 시간 | < 30s |
| 사용자당 일평균 필터 적용 | 8 |
| 다운로드 전환율 | 12% |
| 누적 필터 | 50K |
| 메이커 활성률 | 5K |
| 평균 FPS | ≥ 60 (A14+) |
| 크래시율 | < 0.3% |
| App Store 피처드 | 1회 이상 |
| 코인 매출 | \$50K/월 |
| Pro MRR | \$30K/월 |
| 코인 속도 (적립/사용) | 0.6 ± 0.1 |

## 4. 측정 인프라

| 레이어 | 도구 | 측정 시점 |
|---|---|---|
| 클라이언트 텔레메트리 | `Telemetry.trackScreen / trackAction / trackFunnelStep` | 화면 진입 / 버튼 클릭 / funnel step |
| 분석 백엔드 | Firebase Analytics + PostHog (예정) | 이벤트 수집 |
| 크래시/성능 | Crashlytics + MetricKit | 자동 |
| 비용/SLO | Cloud Monitoring + GCP Billing 대시보드 | 일/주간 |
| 비즈니스 (Phase 4+) | BigQuery export | 주간 |

## 5. Funnel (다운로드 전환)

```
Marketplace Home 진입
   ↓ (CTR 1)
Filter Detail 진입
   ↓ (CTR 2)
다운로드/구매 버튼 클릭
   ↓ (성공률)
다운로드 완료
   ↓ (Apply CTR)
카메라/사진편집에서 필터 적용 → 촬영 (= WAFA + 1)
```

각 단계 측정:
- CTR 1 (홈→상세) MVP 목표 ≥ 30%
- CTR 2 (상세→다운로드) ≥ 15%
- 다운로드 성공률 ≥ 95%
- Apply CTR (다운로드→적용) ≥ 60%

## 6. 메이커 funnel (Supply)

```
가입
   ↓
에디터 진입 (Onboarding 후 마이 필터에서)
   ↓
LUT 임포트 또는 파라미터 조정
   ↓
초안 저장
   ↓
업로드 시작 (Cover)
   ↓
약관 동의 + 검수 제출
   ↓
검수 결과
```

각 단계 drop-off 추적. 약관 페이지(`UploadTOSSubmitScreen`)에서 가장 큰 마찰 발생 가능성 — A/B 후보.

## 7. 안티 KPI (악화 모니터링)

| 지표 | 임계 |
|---|---|
| 모더레이션 큐 24h+ 항목 비율 | > 10% → 알람 |
| 사용자 신고 → 자동 비공개 비율 | > 20% → 정책 검토 |
| 환불 요청 / 결제 비율 | > 5% → 결제 UX 점검 |
| iOS 리젝트 사례 (App Store 심사) | 0 유지 |
| Firestore 비용 / 매출 비율 | > 30% → 마이그레이션 트리거 |

## 8. KPI 리뷰 의식

- **주간**: PM + iOS 리드. 활성화/참여/안티 KPI.
- **월간**: 전체 팀. 메이커 공급 + funnel.
- **분기**: 이사회/투자자. 12개월 목표 대비.
- **Phase 게이트**: Phase별 목표 충족 시에만 다음 Phase 진입.

---

**참조**: [`../prd/PRD.md`](../prd/PRD.md) §7 · [`../roadmap/MILESTONES.md`](../roadmap/MILESTONES.md) · [`../../docs/PRD.md`](../../docs/PRD.md) §5
