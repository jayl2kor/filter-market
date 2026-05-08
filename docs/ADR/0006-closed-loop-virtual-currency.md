# ADR-0006: 메이커 정산을 closed-loop 가상 재화로 한정 (출금 미지원)

> Status: Accepted
> Date: 2026-05-08
> Authors: Founders
> Reviewers: Backend Lead

---

## 1. Context

### 1.1 이전 가설
[CURRENCY_DESIGN.md v1.0](../CURRENCY_DESIGN.md) §5는 메이커가 적립한 코인을 Stripe Connect를 통해 원화로 출금받는 흐름(메이커당 최소 5,000 C / 약 ₩70,000)을 가정했다. 이를 위해 다음 인프라가 필요:

- Stripe Connect 활성화 + 사업자 등록 + KYC 심사 1~2주
- 한국 세무 자문 (메이커 유형 분류 / 원천징수 정책)
- W-8BEN 등 해외 메이커 폼 처리
- 운영 부담 — 매월 원천징수 신고, 환불 시 메이커 잔액 회수, payout 실패 처리

### 1.2 문제
Phase 1~3 단계에서:
- 메이커 수가 충분하지 않음 (출금 인프라가 활성 사용자보다 먼저 들어가는 비용)
- 사업자 등록 + Stripe 심사 + 회계사 자문이 소프트웨어 출시 일정의 critical path가 됨
- 한국 원천징수 / 부가세 / 메이커별 사업자 유형 처리는 단일 운영자(Founders)가 다루기엔 무거움

### 1.3 발견
**App Store Guideline은 closed-loop virtual currency를 명시적으로 허용**한다. 앱 내에서만 소비할 수 있는 가상 재화는 IAP 흐름의 표준이고 한국 전자금융거래법 / 부가세법상 이용권에 해당해 규제 단순화.

---

## 2. Decision

**moodit Phase 1~5에서 메이커 정산은 closed-loop 가상 재화 (Coin)로만 제공한다. 메이커가 적립한 Coin은 moodit 안에서만 소비 가능하며, 원화 출금 (Stripe Payout / 은행 송금) 기능은 Phase 6 진입 시점에 별도 ADR로 재평가한다.**

### 2.1 적용 범위

- ✅ Apple IAP로 사용자가 코인 구매: 유지
- ✅ 메이커 필터 판매 시 코인 적립 (60% 분배): 유지
- ✅ 메이커가 적립 코인으로 다음에 사용 가능:
  - 다른 메이커의 유료 필터 다운로드
  - Pro 구독 결제 (코인으로)
  - 프로필 강조 / 우선 노출 같은 promotion 슬롯 (Phase 5+)
- ❌ Stripe Connect 가입: 미구현
- ❌ 메이커 출금 (코인 → 원화): 미구현
- ❌ 한국 세무 폼 (개인사업자/법인/W-8BEN): 미구현

### 2.2 적용 시점
즉시. Phase 6 진입 시 재평가 (실 사용자 매출 데이터 + 메이커 요구 기반).

---

## 3. Consequences

### 3.1 긍정적 결과
- **출시 일정 단축**: 사업자 등록 + Stripe 심사 1~2주 + 세무 자문 시간이 critical path에서 제거
- **법적 단순성**:
  - moodit는 단일 매출원 (Apple IAP 코인 판매)에만 부가세 부과
  - 메이커는 사업자 등록 / 원천징수 대상 아님 (closed-loop 재화)
  - 한국 전자금융거래법 적용 외
- **현금 흐름 단순**: 모든 코인 매출이 moodit 운영자금으로 직접 흘러들어옴
- **메이커 onboarding 단순**: KYC / 세무 폼 입력 단계 0개

### 3.2 부정적 결과 / 트레이드오프
- **메이커 인센티브 약화**: 코인이 현금화되지 않으므로 일부 전문 메이커는 다른 마켓으로 이탈 가능
- **메이커가 적립한 코인이 "묶임"**: 본인이 다른 필터 안 사면 코인이 미사용 잔액으로 누적
- **마케팅 어필**: "메이커가 돈 번다"라는 일반적 마켓플레이스 가치 제안을 못 씀
- **Phase 6 출금 도입 시 마이그레이션 비용**: 기존 누적 코인을 어떻게 환산할지 정책 결정 필요

### 3.3 잔여 위험
| 위험 | 완화 |
|---|---|
| 메이커가 누적 코인 ≥ 일정 임계 시 출금 요구 | Phase 6 ADR 트리거 — 실 데이터 기반으로 평가 |
| App Store에서 closed-loop 정책 위반 의심 | 명시적 허용 (App Store Guideline 3.1.1) — 위반 위험 없음 |
| 코인 잔액이 누적된 후 서비스 종료 | 약관에 명시 — 추후 환불 정책 수립 (Phase 6) |
| 메이커가 Pro 구독을 코인으로 결제하면 매출 인식 손실 | Pro 구독은 별도 별 매출 트랙 — 코인 결제 옵션은 Phase 5 후보 |

### 3.4 재검토 트리거
다음 중 둘 이상 만족 시 Phase 6 시점에 본 결정 재검토:
- 메이커 누적 미사용 코인 ≥ moodit 월 매출의 30%
- 메이커 5명 이상이 출금 기능을 공식 요구
- moodit 월 매출이 ₩1,000만 이상 (Stripe Connect 운영비를 흡수 가능)
- 한국에서 closed-loop 가상 재화의 규제 환경 변화 (예: 환불 의무화)

---

## 4. Alternatives Considered

### 대안 A: Stripe Connect + 메이커 출금 (이전 가설)
- **장점**: 메이커에게 명확한 인센티브 (실 수입)
- **단점**:
  - 사업자 등록 + Stripe 심사 1~2주
  - 회계사 자문 + 한국 원천징수 운영 부담
  - 해외 메이커 W-8BEN 처리
  - 환불 시 메이커 잔액 회수 → 마이너스 잔액 시 회수 절차
- **채택하지 않은 이유**: Phase 1~3 단계의 ROI 음수. 메이커 수가 인프라를 정당화할 만큼 누적된 후 (Phase 6) 재고려.

### 대안 B: closed-loop 단계 + Phase 4 출금 도입 (점진적)
- **장점**: 일찍부터 메이커 인센티브 확장 가능
- **단점**: Phase 4는 검색/추천 도입 시점이라 본 결정과 일정이 충돌
- **채택하지 않은 이유**: Phase 6에 한 번에 평가하는 게 운영 단순.

### 대안 C: 외부 SaaS (Tipalti / Hyperwallet) 활용
- **장점**: KYC / W-8BEN / payout 자동화
- **단점**:
  - 월 사용료 (Tipalti는 보통 $1,000+/월 minimum)
  - moodit 매출이 충분히 누적되기 전엔 비용 비효율
- **채택하지 않은 이유**: Phase 6 시점에 Stripe Connect 대안으로 재평가.

### 대안 D: 현상 유지 (CURRENCY_DESIGN.md v1.0 그대로)
- **단점**: §1.2/§1.3에 기술된 비용이 출시 전에 누적됨
- **채택하지 않은 이유**: 일정/리소스 비용이 성과보다 큼.

---

## 5. Implementation Notes

### 5.1 코드 변경
- iOS: `WalletScreen`에서 "메이커 출금" 진입점 제거
- iOS: `PayoutOnboardingScreen` / `PayoutTaxInfoScreen` / `EarningsWithdrawScreen` / `PayoutHistoryScreen` 본문을 "Phase 6 이후 지원 예정" placeholder로 교체
- `AppRoute.payoutOnboarding` / `.payoutTaxInfo` / `.earningsWithdraw` / `.payoutHistory` 케이스는 enum에 유지 (deep-link 들어와도 깨지지 않게)
- Cloud Functions: `wallet.ts`의 `requestWithdraw` 등 미구현 stub은 그대로 유지

### 5.2 문서 변경
- `CURRENCY_DESIGN.md` §5 "출금" 섹션을 "Phase 6 후보로 deferred" 표시
- `PHASE_ROADMAP_STATUS.md` Phase 6 범위 축소 (StoreKit IAP만, payout 제외)
- `QA_TEST_PLAN.md` §13.2.16~§13.2.19 행을 placeholder로 갱신
- `TODO.md` 후순위 표에 "Stripe Connect 출금 — Phase 6 ADR 후"

### 5.3 GitHub 이슈
- #11 (Stripe Connect), #12 (Tax info), #13 (earningsWithdraw): `wontfix` 라벨 + 본 ADR 링크로 close

### 5.4 약관 / 개인정보처리방침 (사용자가 변호사 검토)
- "메이커 적립 코인은 moodit 안에서만 사용 가능, 원화 출금 미지원" 명시
- 서비스 종료 시 적립 코인 처리 정책

---

## 6. References
- [CURRENCY_DESIGN.md](../CURRENCY_DESIGN.md) — 코인 모델 단일 소스
- [ADR-0001](./0001-swift-only-ios-first.md) — iOS 단독 출시 (출시 일정 단축 우선)
- [PHASE_ROADMAP_STATUS.md](../PHASE_ROADMAP_STATUS.md) — Phase 6 범위 축소
- App Store Guideline 3.1.1 — In-App Purchase: https://developer.apple.com/app-store/review/guidelines/#in-app-purchase
- 한국 전자금융거래법 — 폐쇄형 가상 재화 (선불 전자지급수단) 규제 적용 외
