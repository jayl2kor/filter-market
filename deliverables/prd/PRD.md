# moodit · Product Requirements Document (PM Edition)

> **버전**: PM v1 (2026-05-10) — *엔지니어링 PRD `../../docs/PRD.md`(v1.1)을 PM 관점으로 재작성*
> **상태**: Active · **검토 주기**: 분기 1회 또는 Phase 게이트 통과 시
> **변경 시 영향**: 본 문서가 `docs/PRD.md`와 충돌하면 코드와 PHASE_ROADMAP_STATUS를 우선 신뢰

## 1. 비전 한 문장

> **누구나 자신만의 카메라 필터를 만들고, 거래하고, 공유하는 글로벌 마켓플레이스 — iOS부터.**

세부: VSCO/Snapchat의 표현력 + PicsArt의 커뮤니티성 + 메이커가 *수익화 가능한* 양면 시장. iOS 17+ Metal/Swift/SwiftUI 단독 출시.

## 2. 문제와 기회

| 사용자 | 현재 어려움 | moodit이 푸는 방식 |
|---|---|---|
| 촬영자 | VSCO 프리셋이 식상하고 다양성이 적다 | UGC 필터 카탈로그 + 추천 |
| 메이커 | LUT 판매 채널이 없거나 분산 | 검수·결제·정산이 통합된 마켓 |
| 캐주얼 | 친구가 쓴 필터를 즉시 못 쓴다 | Universal Link 1탭 적용 |

## 3. 1차 페르소나 요약

- **P1 콘텐츠 크리에이터(지수, 24, F)** — IG 8k, VSCO 유료, 차별화 욕구.
- **P2 필터 메이커(Alex, 29, M)** — Lightroom 프리셋 판매 경험, MSL/LUT 도구 원함.
- **P3 캐주얼(민준, 17, M)** — 보정앱 피로, 친구 추천에 반응.

상세: [`PERSONAS.md`](./PERSONAS.md)

## 4. 기능 범위 (MoSCoW × Phase)

| 기능 | MoSCoW | 첫 도입 Phase | 현재 |
|---|---|---|---|
| 라이브 카메라 + Metal 필터 | Must | Phase 1 | In Progress |
| 사진 가져오기 + 후보정 | Must | Phase 1 | Done(UI) / 실기기 검증 남음 |
| 내장 필터 10~15개 | Must | Phase 1 | Done |
| Apple/Google/Email/Guest 인증 | Must | Phase 1 | Partial(어댑터 슬롯) |
| 마켓 둘러보기 + 다운로드 | Must | Phase 1 | In Progress(.fmpkg path 미연결) |
| 검색·카테고리·태그 | Should | Phase 1 | Done(client-side) |
| LUT 기반 에디터 (Tier 1) | Must | Phase 2 | UI Done / 엔진 In Progress |
| 필터 업로드 + 약관 + 검수 | Must | Phase 2 | UI Done / .fmpkg upload 미연결 |
| 리뷰·별점·메이커 답글 | Should | Phase 3 | UI Done / persistence In Progress |
| 팔로우·차단·알림 | Should | Phase 3 | Done(API) / push resolver 정리 중 |
| 추천 / For You feed | Could | Phase 4 | mock UI만 |
| 모더레이션 큐·신고 자동화 | Should | Phase 5 | UI Done / 트리거 TODO |
| Coin / Pro / 환불 | Must (수익화) | Phase 6 | 결제 callable Done / 출금 placeholder |
| Android 출시 | Won't (v1) | Phase 4 게이트 | Not Started |

> Phase 4 게이트 = 정량(누적 매출, 메이커 수, 시장조사) + 정성(전략) 결정 후 Android Kotlin / Compose MP / iOS only 중 택1.

## 5. 사용자 스토리 (대표 10건, 변경 동결)

```
US-01 [촬영자] 카페에서 음료 사진을 라이브 빈티지 필름 필터로 보면서 찍는다.
US-02 [촬영자] 마켓에서 "여름 파스텔" 검색 → 다운로드 → 카메라에서 즉시 적용.
US-03 [촬영자] 친구가 공유한 Universal Link → 앱 열림 → 같은 필터 자동 적용.
US-04 [메이커] LUT 업로드 + 강도 파라미터 정의 → 약관 동의 → 검수 제출.
US-05 [메이커] 대시보드에서 다운로드/평점/매출 확인 → 코인 출금 신청.
US-06 [메이커] 다른 사람 필터 Remix → 원본 크레딧 표기 → 새 필터 게시.
US-07 [관리자] 신고된 필터 검토 → 거부 사유 입력 → takedown.
US-08 [캐주얼] 친구 추천 필터를 1탭으로 다운로드.
US-09 [Pro] 모든 유료 필터 무제한 + 월 300코인 자동 적립.
US-10 [촬영자] 오프라인에서도 다운로드한 필터로 촬영 가능.
```

## 6. 비-목표 (v1 Out of Scope)

- 영상 필터 / Stories
- AR 얼굴 트래킹 / 3D 마스크 (ARKit)
- 데스크탑·웹 에디터
- 음악·오디오 편집
- 라이브 스트리밍
- Android 빌드 (Phase 4 게이트 후 결정)

## 7. 성공 기준

### 7.1 North Star
**WAFA** = Weekly Active Filter Applications.

### 7.2 MVP 게이트(iOS 출시 후 6주)
- iOS MAU 8K
- D1 리텐션 35%
- 첫 촬영까지 시간 < 60s
- 사용자당 일평균 필터 적용 3회
- 마켓→다운로드 전환 5%
- 누적 업로드 필터 1K
- 카메라 평균 FPS ≥ 30 / Crashlytics 크래시율 < 1%

### 7.3 12개월 목표
iOS MAU 200K · D1 45% · 다운로드 전환 12% · 누적 필터 50K · Pro MRR \$30K · 코인 매출 \$50K/월.

> Phase별 DoD는 [`../roadmap/ROADMAP.md`](../roadmap/ROADMAP.md) §"완료 기준" 참조.

## 8. 결제·코인 정책 (Phase 6)

- **코인**: Apple IAP만(`coins.{100/550/1200/3000}`). 1 Coin ≈ ₩14.
- **필터 가격(코인)**: `[0, 30, 50, 80, 120]`.
- **메이커 분배**: 60% (코인 적립), moodit 운영비 40%.
- **Pro 구독**: 월 ₩4,900 / 연 ₩34,800 (`pro.monthly`/`pro.yearly`). 모든 유료 필터 무제한 + 월 300 코인 자동 적립.
- **출금**: Stripe Connect 통한 코인→KRW 환전, 임계 5,000 코인. KYC + 세무 정보 필수.
- **환불**: 7일 정책 (`refundRequest` callable).

## 9. 가정과 의존성

- iOS 17+ Metal 3로 1080p@60fps 라이브 필터 가능 (A14 Bionic 이상).
- Firebase / Cloudflare R2 가용성 (둘 다 SLA 99.9%+).
- Apple App Store 심사 정책: UGC 모더레이션 + 24h SLA + IAP 강제(IAP 가이드 3.1.1).
- 한국·일본·동남아 셀피 문화 시장이 초기 베타에 적합.

## 10. 핵심 차별화 / 해자

- **Metal 4-pass 셰이더 파이프라인**: A14+ 60FPS, iOS에서 비자명한 엔지니어링.
- **양면 네트워크 효과**: 메이커↑ → 촬영자 가치↑ → 메이커 수익↑.
- **필터 라이브러리 자산**: 시간이 지날수록 가치 누적, 향후 Android 포팅 시 동일 LUT/.fmpkg 재사용.
- **iOS 네이티브 표현력**: App Store 피처드 가능성(Halide/Darkroom 사례).

## 11. 변경 이력

| 버전 | 날짜 | 변경 |
|---|---|---|
| PM v1 | 2026-05-10 | PM 관점으로 재작성, 현재 구현 상태 반영(2026-05-10 스냅샷) |
| (eng v1.1) | 2026-05-06 | 엔지니어링 원본 PRD — `docs/PRD.md` |

---

**참조**: [`PERSONAS.md`](./PERSONAS.md) · [`../roadmap/ROADMAP.md`](../roadmap/ROADMAP.md) · [`../kpi/KPI_TREE.md`](../kpi/KPI_TREE.md) · [`../../docs/PRD.md`](../../docs/PRD.md)
