# moodit — Currency Design (Coins)

> 버전: v1.0 · 작성일: 2026-05-06 · 상태: Active · 단일 소스
>
> 이 문서는 moodit 내부 화폐 **Coin** 의 모든 결정(이름·아이콘·패키지·분배·환불·컴플라이언스)의 단일 진실원이다. 화면·API·Firestore 스키마는 본 문서의 정의를 그대로 따른다.

---

## 1. 결정 요약 (TL;DR)

| 항목 | 값 |
|---|---|
| 화폐 이름 | **Coin** (코인) |
| 약어 | `C` |
| 아이콘 | [`mockups/brand/coin.svg`](../mockups/brand/coin.svg) — 골드 원형 디스크 + 흰색 "M" |
| 색상 | `accent` (`#B8853A` light / `#E8B86D` dark) |
| 충전 결제 | **Apple IAP 단독** (App Store Guideline 3.1.1) |
| 메이커 분배 | **60%** (필터 판매 시) |
| 출금 (메이커) | Stripe Connect → 원화 (Phase 6, 최소 5,000 C / 약 ₩70,000) |
| Pro 구독 | **별도 트랙** — Pro 가입자는 모든 유료 필터 무제한 사용 |
| 환불 | 충전 후 **7일 내 미사용분만** 가능 (Apple 환불 SLA 일치) |

---

## 2. 화폐 단위와 가격대

### 2.1 코인 패키지 (사용자 충전)

| 패키지 | 코인 | 가격 (KRW) | 보너스 | 환산가 |
|---|---:|---:|---:|---:|
| Starter | **100 C** | ₩1,500 | — | 15원 / 코인 |
| Popular | **550 C** | ₩7,500 | +10% (50 보너스) | 13.6원 / 코인 |
| Best Value | **1,200 C** | ₩15,000 | +20% (200 보너스) | 12.5원 / 코인 |
| Pro Pack | **3,000 C** | ₩34,000 | +30% (700 보너스) | 11.3원 / 코인 |

> 더 많이 살수록 단가 하락 — 모바일 게임 패키지 패턴.

### 2.2 필터 가격대 (메이커 권장)

| 등급 | 코인 | 환산 ($USD) | 권장 사용처 |
|---|---:|---:|---|
| Lite | **30 C** | ~$0.35 | 단일 LUT 기반 필터 |
| Standard | **50 C** | ~$0.55 | 파라미터 7~10 + LUT |
| Premium | **80 C** | ~$0.95 | 4-pass 셰이더 + 비네트/그레인 |
| Signature | **120 C** | ~$1.40 | MSL 셰이더 + 메이커 시그니처 |

> 무료 필터(0 C)는 마켓에서 그대로 다운로드 가능. 메이커가 자유롭게 가격 설정.

### 2.3 분배 (필터 판매 1건)

```
사용자가 50 C 결제
─ Apple IAP 수수료(충전 시점에 이미 차감, App Store에 30%) — 이 단계에서 추가 차감 없음
─ moodit 운영비: 50 C × 40% = 20 C (서버·CDN·R2·모더레이션)
─ 메이커 적립: 50 C × 60% = **30 C**
```

> Apple IAP는 충전 시점에 1회만 차감. 이후 코인 → 필터 거래는 moodit 내부 거래로 추가 수수료 없음.

---

## 3. UX 정책

### 3.1 표기 규칙

| 컨텍스트 | 표기 |
|---|---|
| 인라인 가격 | `30 C` (코인 아이콘 + 숫자) |
| 단독 잔액 표시 | `C 1,250` (대형) |
| 무료 필터 | `무료` (라벨, 가격 영역 없음) |
| Pro 가입자 시점 | `포함됨` (Pro 멤버십에 포함) |

### 3.2 잔액 부족 처리

필터 구매 시도 → 잔액 < 가격 → **충전 추천 모달** (`46-insufficient-balance.html`):

1. 부족한 코인 강조 (예: "30 C 필요 · 잔액 12 C")
2. 가장 작은 충족 패키지 추천 (필터 가격 기준 최소 충족 패키지)
3. "더 큰 패키지" 옵션도 보임 (보너스 강조)
4. 취소 → 필터 detail로 복귀

### 3.3 충전 흐름

```
1. 지갑 화면(43)에서 "충전하기" 또는 잔액 부족 모달(46)에서 진입
2. 패키지 선택(44) → Apple IAP 시트 (시스템)
3. 결제 성공 → Cloud Functions가 Apple 영수증 검증 → wallet.balance 증가
4. 거래 내역(45)에 [+550 C 충전] 기록
5. 사용자에게 토스트 "550 C 충전 완료"
```

### 3.4 구매 흐름

```
1. 필터 detail에서 "30 C로 구매"
2. 클라이언트 → POST /filters/{id}/purchase (Idempotency-Key)
3. 서버 트랜잭션:
   a. 잔액 ≥ 30 C 확인 (실패 시 INSUFFICIENT_BALANCE)
   b. wallet.balance -= 30
   c. 메이커 wallet.earnedCoins += 18 (60%)
   d. moodit.feeCoins += 12 (40%)
   e. /transactions/ 4 doc 기록 (구매·메이커 적립·moodit 수수료·필터 보유)
   f. /users/{uid}/ownedFilters에 추가
4. 클라이언트는 다운로드 진행 화면(07b)으로 이동
```

### 3.5 일일 보너스 / 신규 가입 보너스

| 트리거 | 지급 코인 |
|---|---:|
| 신규 가입 | **50 C** (1회) |
| 7일 연속 접속 | **20 C** |
| Pro 구독 (월간) | 월 자동 **300 C** |
| Pro 구독 (연간) | 즉시 **4,000 C** + 월 300 C |

---

## 4. Pro 멤버십 (구독 모델 — 별도 트랙)

코인과 별도로, **Pro 멤버십**은 모든 유료 필터에 대한 **무제한 접근권**을 제공한다 (구매 코인을 소비하지 않음).

| 플랜 | 가격 | 권한 |
|---|---|---|
| 월간 | ₩4,900 / 월 | 모든 유료 필터 무제한 + 월 300 C 보너스 |
| 연간 | ₩34,800 / 년 | 동일 + 즉시 4,000 C + 7일 무료 체험 |

Pro 가입자가 필터에 접근할 때:
- 필터 detail에 **"Pro 멤버십에 포함됨"** 라벨 표시
- 코인 차감 없이 즉시 다운로드
- 메이커는 **고정 분배**를 받음 (Pro 풀에서 다운로드 비율 기반 — 월 정산)

> Pro 풀 분배 상세는 Phase 6 진입 시 확정. MVP는 단건 코인 모델만 활성화.

---

## 5. 메이커 출금

### 5.1 임계치와 절차

- 최소 출금 금액: **5,000 C** (≈ ₩70,000 → 60% 비율 적용 시)
- 환산 비율: **1 C = ₩14** (메이커 출금 시 고정 환율 — 평균 패키지 단가에 보수적 마진)
  - 예: 5,000 C 적립 → 출금 시 ₩70,000 (Stripe 수수료·VAT 차감 전)
- 출금 주기: **주 1회** (매주 월요일)
- 첫 출금 전 Stripe Connect 인증 + 세무 정보 (`40·41` 화면)

### 5.2 환율 결정 근거

평균 충전 단가와 Apple 수수료 이후 순매출을 기준으로 월별 보수적 환율을 서버 설정값으로 관리한다. v1 초기값은 **1 C = ₩14**이며, 메이커 지급률과 운영비 마진은 실제 충전 믹스/소상공인 수수료 적용 여부를 보고 조정한다.

> 환율은 `firestore /config/economy.coinToWonRate` 에 두고 **서버 설정값**으로 관리. 변경은 30일 사전 공지.

---

## 6. 컴플라이언스

### 6.1 Apple App Store

- **Guideline 3.1.1**: 디지털 재화 결제는 IAP 필수 → ✅ Coin 충전은 StoreKit 2로만
- 외부 결제 페이지 링크/버튼 금지 (Pro 구독도 IAP)
- 영수증 검증: 서버 측 `/wallet/topup/finalize` 에서 Apple `/verifyReceipt` 또는 ASN1 파싱

### 6.2 한국

- 게임이 아니므로 셧다운제·결제한도 직접 적용은 X
- 미성년자 결제 한도는 Apple ID 가족 공유 정책에 위임
- 전자상거래법: 환불·청약철회 정책 명시 필수 → §7

### 6.3 부정사용 방지

- 모든 잔액 변경은 **서버 트랜잭션 한정** — Firestore 보안 규칙은 wallet/transactions read-only
- Idempotency-Key로 이중 차감 방지 (구매·충전 모두)
- 단일 사용자 일일 충전 한도: ₩300,000 (이상 시 추가 인증)
- 비정상 패턴 감지: 짧은 시간 내 다수 환불 → 자동 플래그
- 도용된 IAP 영수증 재사용 차단 (transactionId 기반 한 번만 grant)

---

## 7. 환불 정책

### 7.1 충전 코인

- **사용 전 7일 이내**: 사용자 요청 시 환불 가능 (Apple 채널 통해)
- **부분 사용**: 미사용 부분만 비례 환불
- **모두 사용**: 환불 불가 (이미 디지털 콘텐츠 소비)

### 7.2 필터 구매 (코인)

- 구매 직후 **24시간 이내 미사용**: 코인 환원 가능
- 사용 후: 환불 불가 (필터 적용은 즉시 디지털 사용으로 간주)

### 7.3 Pro 멤버십

- 첫 7일 무료 체험 동안 해지 시 결제 0원
- 결제 후 환불은 Apple 환불 정책에 따름 (앱 내 환불 버튼 X)

---

## 8. Firestore 스키마

### 8.1 컬렉션

```
/wallets/{uid}                    # 사용자 지갑 (단일 문서)
  balance: int                    # 사용 가능 코인
  earnedCoins: int                # 메이커 적립 코인 (구매에는 사용 X, 출금만 가능)
  pendingEarnings: int            # 미정산 (정산 주기까지)
  totalToppedUp: int              # 누적 충전 (분석)
  totalSpent: int                 # 누적 사용
  updatedAt: timestamp
  proUntil: timestamp?            # Pro 멤버십 만료일

/transactions/{txId}              # 거래 ledger (append-only)
  uid: string
  type: "topup" | "purchase" | "earn" | "withdraw" | "refund" | "bonus" | "pro_grant"
  amount: int                     # signed (충전 +, 사용 −)
  balanceAfter: int               # 트랜잭션 후 잔액 스냅샷
  filterId: string?               # purchase/earn 전용
  iapTxId: string?                # topup 전용 (Apple transactionId)
  payoutId: string?               # withdraw 전용
  createdAt: timestamp
  notes: string?

/payouts/{payoutId}               # 메이커 출금 요청 (Phase 6)
  uid: string
  coins: int                      # 출금 코인량
  amountKRW: int                  # 환산 원화
  status: "requested" | "processing" | "paid" | "failed" | "cancelled"
  stripeTransferId: string?
  requestedAt, paidAt: timestamp
```

### 8.2 보안 규칙 핵심 (FIRESTORE_RULES.md 동기화)

```
match /wallets/{uid} {
  allow read: if request.auth.uid == uid;
  allow write: if false;  // Cloud Functions 전용
}
match /transactions/{txId} {
  allow read: if request.auth.uid == resource.data.uid;
  allow write: if false;  // Cloud Functions 전용
}
```

---

## 9. API 엔드포인트 (API_SPEC.md 동기화)

| Method | Path | 인증 | 설명 |
|---|---|---|---|
| GET | `/me/wallet` | Required | 잔액·earnedCoins·proUntil 조회 |
| POST | `/wallet/topup/init` | Required | IAP 시작 토큰 발급 |
| POST | `/wallet/topup/finalize` | Required | Apple 영수증 검증 + 코인 지급 |
| POST | `/filters/{id}/purchase` | Required | 코인 차감 + 필터 보유권 부여 (Idempotency-Key 필수) |
| GET | `/me/transactions` | Required | 페이지네이션 거래 내역 |
| POST | `/me/withdraw` | Required + KYC | 메이커 출금 요청 (Phase 6) |
| GET | `/config/economy` | Public | 패키지·환율·임계치 (서버 설정) — 클라이언트 캐시 |

---

## 10. 텔레메트리 / KPI

| 지표 | 측정 |
|---|---|
| ARPU (Avg Revenue Per User) | 사용자당 평균 충전 원화 |
| ARPPU (Avg Rev Per Paying User) | 충전 사용자당 평균 |
| Coin Velocity | (총 사용 코인) / (총 발행 코인) — 1.0에 가까울수록 인플레 X |
| Spending → Earning Ratio | 평균 30일 기준 메이커 적립 / 사용자 사용 비율 |
| Topup → First Purchase 시간 | 충전 후 첫 필터 구매까지 |
| Free → Pay 전환율 | 무료 필터 다운 후 30일 내 코인 사용 비율 |

---

## 11. 화면 매핑

| 화면 | 역할 |
|---|---|
| `43-wallet.html` | 지갑 메인 (잔액·최근 거래·충전·Pro 진입) |
| `44-wallet-topup.html` | 충전 (4 패키지) |
| `45-wallet-transactions.html` | 거래 내역 ledger |
| `46-insufficient-balance.html` | 잔액 부족 모달 (필터 구매 시) |
| `47-earnings-withdraw.html` | 메이커 출금 신청 |
| `37-paywall-single.html` | 코인 가격 표시로 갱신 |
| `38-paywall-subscription.html` | Pro 멤버십 = 무제한 + 월 코인 보너스 |
| `40·41·42 payout-*` | 출금 흐름 (Phase 6) |

---

## 12. 결정 변경 이력

| 버전 | 날짜 | 변경 |
|---|---|---|
| v1.0 | 2026-05-06 | 초안 — 화폐명 Coin, 분배 60%, Pro 멤버십 별도 트랙, 4 패키지 |

---

## 13. 관련 문서

- [`PRD.md`](./PRD.md) §3.1 / §6.4 — 결제 모델 결정 반영
- [`API_SPEC.md`](./API_SPEC.md) §4.2 / §5 — 신규 엔드포인트
- [`FMPKG_SCHEMA.md`](./FMPKG_SCHEMA.md) — 패키지 자체는 가격을 담지 않고, 마켓 메타데이터가 `priceCoins`를 가진다.
- [`FIRESTORE_RULES.md`](./FIRESTORE_RULES.md) — 지갑/거래 규칙
- [`SCREENS_PLAN.md`](./SCREENS_PLAN.md) Phase 6 → Wallet 그룹 재구성
- [`BRAND.md`](./BRAND.md) — 코인 아이콘 정의
- [`../mockups/brand/coin.svg`](../mockups/brand/coin.svg)
