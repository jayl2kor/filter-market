# moodit · Executive Summary

> **One-pager**. 마지막 갱신: 2026-05-10. 다음 검토: 분기 첫 주 또는 Phase 게이트 도달 시.

## 1. What

**moodit (`com.jayl2kor.moodit`)** — iOS 17+ 네이티브 카메라 필터 마켓플레이스. 사진 필터를 *상품으로* 다루는 양면 시장(Maker ↔ Consumer)을 만든다. Metal 기반 GPU 필터(60FPS 목표) + 사용자 제작 LUT/파라미터 필터 + 코인/Pro 멤버십 결제.

## 2. Why now

- VSCO/Snapchat은 사용자 제작 필터를 거래하지 않는다. PicsArt/Lightroom Mobile은 라이브 카메라가 약하다.
- 인플루언서·콘텐츠 크리에이터(북미·서유럽·한국·일본)의 iOS 비중 65~75% — iOS 단독 출시로도 핵심 타겟 커버.
- iOS 네이티브 + App Store 피처드 잠재력(Halide·Darkroom·Procreate 동일 패턴).

## 3. Who

- **P1 페르소나**: 콘텐츠 크리에이터(24, F, IG 8k 팔로워, VSCO 유료 사용자).
- **P2 페르소나**: 필터 메이커(29, M, Lightroom 프리셋 판매 경험).
- **P3 페르소나**: 캐주얼 셀카 사용자(17, M, iPhone 13).

## 4. North Star Metric

**WAFA — Weekly Active Filter Applications** (촬영 + 후보정에서 필터 적용한 주간 횟수). 마켓 / 에디터 / 카메라 가치사슬을 한 번에 측정.

## 5. Status (2026-05-10)

| 영역 | 상태 |
|---|---|
| iOS 빌드 | ✅ BUILD SUCCEEDED |
| 테스트 | ✅ 162 unit + 26 AppUI / Functions 6 + Rules 11 모두 PASS |
| 화면 구현 | 67개 중 약 50개 SwiftUI 실구현(2026-05-10 코드 grep), 나머지 skeleton/placeholder |
| Cloud Functions | callable **30개** + 트리거 **11개** (functions/src/index.ts re-export 기준). `onFilterPublished` / `onReportCreated` 본문은 TODO |
| 결제 | Coin IAP + Pro 구독 receipt 검증 완료 / 메이커 출금(Stripe Connect)은 Phase 6 |
| Phase 진행 | 1·2·3 In Progress / 4 Not Started / **완료된 Phase 0개** |
| 진행 중 refactor wave | 2026-05-09 commit 시리즈로 *도메인 스토어 분리* (`SessionStore` / `FilterLibraryStore` / `EditorDraftStore` / `CameraStateStore`) — `MooditStore`가 얇아지는 중 |

## 6. Next 30 days — Top 3

1. **`.fmpkg` 다운로드/캐시/적용 end-to-end** (Phase 1 P0) — 현재 mock fallback 상태.
2. **Comments → Reviews Swift 마이그레이션 마무리** (Phase 3 P0) — UI/모델은 전환됐으나 route/notification naming 정리 필요.
3. **실기기 카메라 FPS / 발열 검증** (Phase 1 P0) — 시뮬레이터만으로는 TestFlight 게이트 통과 불가.

## 7. Top 3 위험

| 위험 | 점수 | 즉시 대응 |
|---|---|---|
| R-B01 저작권 침해 (메이커 무단 LUT 업로드) | 20 | DMCA 절차 + pHash DB 구축, 약관 정비 |
| R-B02 미성년 NSFW 노출 | 20 | 온디바이스 Vision 1차 + Cloud Vision 2차 검수 |
| R-B04 Apple IAP 정책 변경 | 16 | StoreKit2 100% 준수 + Remote Config 피처 플래그 |

전체: [`../risks/RISK_REGISTER.md`](../risks/RISK_REGISTER.md)

## 8. 자금/마일스톤(가정)

- **TestFlight Beta**: Phase 1 완료 게이트 통과 시점(목표 2026-Q3).
- **App Store Production**: Phase 3 완료 + 모더레이션 자동화 + 첫 실기기 회귀 통과 후.
- **수익화 활성**: Phase 6 (코인 충전 + Pro). 12개월 목표 코인 매출 \$50K/월, Pro MRR \$30K/월.

## 9. 한 줄

> "양면 시장이 도는지 검증하기 전까지는 *iOS 깊이의 차별화*에 집중. 메이커 100명 / 다운로드 10K / D1 35%가 진짜 신호."

---

**참조**: [`../prd/PRD.md`](../prd/PRD.md) · [`../roadmap/ROADMAP.md`](../roadmap/ROADMAP.md) · [`../kpi/KPI_TREE.md`](../kpi/KPI_TREE.md)
