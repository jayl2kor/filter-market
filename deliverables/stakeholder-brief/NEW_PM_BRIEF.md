# moodit · 신규 PM 인수인계 Brief

> **읽는 시간**: 약 15분. 이 문서를 다 읽으면 *오늘 무엇을 결정해야 하는지* 알게 된다.
> **버전**: 2026-05-10. 다음 PM에게 인계할 때 본 문서 전체를 갱신해 주세요.

## 1. "지금이 어디인가" — 한 페이지 요약

| 항목 | 현재 |
|---|---|
| 제품 | iOS 17+ 카메라 필터 마켓플레이스 (`com.jayl2kor.moodit`) |
| 단계 | Phase 1·2·3 In Progress / 4 Not Started / **완료된 Phase 0개** |
| 빌드/테스트 | ✅ BUILD SUCCEEDED / 162 unit + 26 AppUI 통과 (베이스라인 로그 2026-05-08, `.omc/logs/test-s4-final2.log`) |
| 화면 | `struct *Screen: View` **67개** (코드 grep 실측) / `AppRoute` cases 64개 |
| 백엔드 | callable **30개** (Identity 5 + Filters 16 + Moderation 5 + Wallet 4) + 트리거 **11개** (`onFilterPublished`·`onReportCreated` 본문 TODO) |
| 진행 중 refactor | 2026-05-09 commit 시리즈가 도메인 스토어 분리(`SessionStore`/`FilterLibraryStore`/`EditorDraftStore`/`CameraStateStore`) 진행 중 — uncommitted M 18건 존재 |
| 결제 | 코인 IAP + Pro 구독 receipt 검증 ✅ / 메이커 출금 placeholder |
| 디자인 | 2026-05-10 mockup refresh 완료 (`deliverables/index.html`) — *18개 화면이 코드와 diverge* |

**오늘 결정할 만한 가장 큰 한 건**: Phase 1 다운로드 path (mock fallback 상태)와 Phase 3 Comments→Reviews 마이그레이션을 *동시에* 닫을지, *순차*로 닫을지. PM은 팀 구성을 보고 판단.

## 2. 가장 먼저 해야 할 것 (Day 1)

1. **본 패키지(`deliverables/`)를 끝까지 읽기** — README → executive-summary → PRD → roadmap → screens → risks 순.
2. **빌드/테스트 실행** — `xcodegen generate && ./scripts/build.sh && ./scripts/test.sh`.
3. **TODO.md 확인** — `/Users/user/workspace/applications/filterMarket/TODO.md`에 미결 작업 정리.
4. **2026-05-07 회귀 baseline 재실행** — `./scripts/test.sh`. 결과를 `docs/PHASE_ROADMAP_STATUS.md` §11에 추가.
5. **이번 주 리스크 1개 픽** — `risks/RISK_REGISTER.md` Top 10 중 R-B01 또는 R-B02. 둘 다 점수 20.

## 3. 30/60/90 — 핵심만 ([상세](./30_60_90_PLAN.md))

- **30일**: Phase 1 `.fmpkg` end-to-end + 실기기 FPS + Comments→Reviews 정리.
- **60일**: TestFlight Internal 5~10명 + Phase 2 LUT 엔진 + ADR(검색/추천).
- **90일**: TestFlight External + Phase 3 social API persistence + App Store Production 게이트 평가.

## 4. 알아야 할 핵심 사람·역할

| 역할 | 대표 산출물 |
|---|---|
| iOS 리드 | `Sources/`, `project.yml`, Metal 셰이더 (`Shaders/`) |
| 백엔드 리드 | `functions/src/`, `firestore.rules`, `firestore.indexes.json` |
| 디자이너 | `deliverables/flow-*.html`, `DESIGNER_NOTES.md`, `docs/DESIGN_TOKENS.json` |
| QA | `Tests/`, `docs/SCREEN_ACTIONS_QA_DEFINITION.md`, `docs/QA_FINDINGS.md` |
| (Phase 6) 재무 | `docs/CURRENCY_DESIGN.md` |
| (Phase 5) 법무 자문 | `docs/MSL_SECURITY.md`, R-B01/R-B02/R-B03 |

## 5. 중요한 의사결정의 *역사*

PM이 *왜 이렇게 되어 있는가*를 추적하기 위해 알아야 할 결정 5건. 변경 시 충분한 근거 필요.

1. **iOS 단독 출시** (2026-05-06) — Compose MP PoC 비용 + 팀 4명 규모 + 핵심 페르소나 iOS 비중 65~75%. Phase 4 게이트로 재평가. 근거: `docs/RISKS.md` R-B07.
2. **Firebase + R2** (2026-05-06) — 50K MAU까지 무료 영역 + R2 egress 무료. Postgres+자체 백엔드는 Phase 4 이후. 근거: `docs/ARCHITECTURE.md` §9.1.
3. **메이커 60% 분배 / Pro 월 ₩4,900** (2026-05-06) — IAP 가이드 3.1.1 준수 + 시장 비교. 근거: `docs/CURRENCY_DESIGN.md`.
4. **Comments → Reviews** (2026-05-06) — App Store 패턴(1인 1리뷰 + 메이커 답글 1회 + verified download). 근거: `docs/REVIEWS_MIGRATION.md`.
5. **Phase A~F → Phase 1~4 + UI Work Package** (2026-05-07) — 화면 패키지와 제품 Phase 혼동 정리. 근거: `docs/PHASE_ROADMAP_STATUS.md` §1.

## 6. 함정 / 헷갈리기 쉬운 것

- **셔터 탭은 일반 탭이 아니다**. fullScreenCover 진입점. 종료 시 *이전 탭으로 복귀*.
- **`Phase A~F`라는 표현이 코드 주석/이전 PR에 남아 있을 수 있다**. 모두 *UI Work Package*로 재분류됨. 결정은 `Phase 1~4` 기준.
- **Comments / Reviews 키가 혼재**. naming 정리는 Phase 3 P0 작업. 새 코드 추가 시 *Reviews* 사용.
- **payout/* 화면은 placeholder**. closed-loop coin 정책상 *앱 진입점 비노출*. 디자이너 목업이 있어 헷갈릴 수 있음.
- **Storage 규칙은 모두 차단**. 미디어는 *반드시* R2 (presigned URL)로만 송수신.
- **mockups/ 폴더는 2026-05-06 historical snapshot**. 현행 디자인 진실원은 `deliverables/flow-*.html`.

## 7. 자주 쓰는 명령어

```bash
# iOS 빌드/테스트
xcodegen generate
./scripts/build.sh
./scripts/test.sh
./scripts/metal-toolchain.sh

# Functions
cd functions
npm run build
npm run lint
npm run serve            # Firebase emulators
npm run test             # 6개 callable 단위 테스트
npm run test:rules       # firestore-rules emulator
npm run deploy:staging
npm run deploy:prod
```

## 8. 외부 시크릿 / 계정 위치

- Firebase 프로젝트(dev/staging/prod) — `firebase.json` + Cloud Console 콘솔
- Cloudflare R2 — `R2_*` 시크릿 (Functions secret)
- Apple App Store Connect — 콘솔 별도
- Stripe Connect (Phase 6) — 미설정

각 시크릿 위치/회전 SOP는 `docs/EXTERNAL_SETUP.md` 참조.

## 9. 첫 주에 만날 가능성이 큰 결정 5건

1. **TestFlight Internal 인원** — 5명? 50명? PM 판단.
2. **검수 SLA** — 24h가 현실적인가? Phase 5 BPO 외주 시점은?
3. **약관 3종 simplification** — Original/Policy/Commercial을 *체크박스 1개*로 묶을 수 있을까? (메이커 funnel 마찰)
4. **카메라 *셔터*에 *코인 잔액 표시* 여부** — 현재 마켓 헤더에만 노출. 디자이너 코멘트 1번 (`DESIGNER_NOTES.md`).
5. **Maker Dashboard MVP 범위** — 현재 placeholder. Phase 6 진입 전 어디까지 보여줄지.

## 10. *반드시* 매주 보는 지표 5개

1. **iOS 빌드 그린/레드** (CI 결과)
2. **`./scripts/test.sh` 결과** (회귀 통과 여부)
3. **Crashlytics 크래시율** (목표 < 1%)
4. **Cloud Functions p95 latency** (목표 < 300ms)
5. **모더레이션 큐 24h+ 적체 비율** (목표 < 10%)

## 11. 도움 요청 채널 (TBD)

- 슬랙/디스코드: TBD
- 이슈 트래커: GitHub Issues (private repo)
- 모더레이션 escalation: TBD

---

**다음 단계**: [`30_60_90_PLAN.md`](./30_60_90_PLAN.md)로 이동.

**자주 가는 문서**: [`../README.md`](../README.md) · [`../executive-summary/EXECUTIVE_SUMMARY.md`](../executive-summary/EXECUTIVE_SUMMARY.md) · [`../roadmap/ROADMAP.md`](../roadmap/ROADMAP.md) · [`../risks/RISK_REGISTER.md`](../risks/RISK_REGISTER.md)
