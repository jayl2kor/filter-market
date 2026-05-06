# moodit — Screen Design Plan

> 버전: v1.1 · 작성일: 2026-05-06 · 상태: Active
>
> 본 문서는 `mockups/`의 실제 HTML 목업을 PRD, 구현 마일스톤, SwiftUI 화면 단위로 연결하는 단일 인벤토리다. 이전 격차 분석에서 Missing으로 분류했던 P0~P6 화면은 현재 HTML 목업 기준으로 모두 작성 완료됐다.

---

## 1. 현재 자산 인벤토리

| 분류 | 수 | 위치 |
|---|---:|---|
| 제품 화면 | 67 | `mockups/screens/*.html` (`states-catalog.html` 제외) |
| 상태 카탈로그 | 1 | `mockups/screens/states-catalog.html` |
| 권한 화면 | 8 | `mockups/screens/permissions/*.html` |
| 모달 패턴 | 4 | `mockups/screens/modals/*.html` |
| 브랜드 SVG | 10 | `mockups/brand/*.svg` |
| 브랜드 미리보기 | 1 | `mockups/brand/preview.html` |

탐색 진입점:
- [`mockups/index.html`](../mockups/index.html)
- [`mockups/README.md`](../mockups/README.md)
- [`NAVIGATION.md`](./NAVIGATION.md) — 모든 버튼 액션 + 화면 간 흐름 + SwiftUI 매핑 (개발 에이전트용 단일 진실원)

---

## 2. PRD ↔ 목업 상태

| PRD/Phase 기능 | 상태 | 대표 목업 |
|---|---|---|
| F1 카메라 라이브 + 필터 | Designed | `03`, `04`, `13`, `14`, `15` |
| F1 사진 촬영 & 저장 | Designed | `05` |
| F1 내장 필터 라이브러리 | Designed | `19` |
| F2 갤러리 후보정 | Designed | `16`, `17` |
| F3 LUT/파라미터 에디터 | Designed | `11`, `11b`, `11c`, `11d` |
| F4 마켓 둘러보기/상세/다운로드 | Designed | `06`, `07`, `07b`, `07c`, `08`, `18` |
| F5 프로필/소셜/팔로우 | Designed | `09`, `09b`, `21`, `23`, `23b`, `24`, `25`, `26`, `27`, `30`, `32`, `51` |
| F6 인증/게스트/계정 삭제/데이터 내보내기 | Designed | `02`, `02b`, `20`, `53` |
| Universal Link | Designed | `22` |
| 메이커 업로드/심사 | Designed | `12`, `12b`, `12c`, `12d`, `12e`, `28` |
| 메이커 필터 관리/반려 대응 | Designed | `48`, `50` |
| 신고/모더레이션/차단 | Designed | `29`, `33`, `34`, `35` |
| 추천/리믹스 | Designed | `31`, `36` |
| 코인/구매/Pro/지갑/정산/환불 | Designed | `37`~`47`, `49`, `52`, `54` |
| 권한 요청 | Designed | `permissions/*` |
| 상태/모달 패턴 | Designed | `states-catalog`, `modals/*` |

현재 남은 격차는 "목업 부재"가 아니라 **구현 이슈와 라우팅, API 연결, 테스트 케이스로의 전환**이다.

---

## 3. 화면 목록

### Core 12

| 파일 | 구현 영역 | 비고 |
|---|---|---|
| `01-onboarding.html` | `area:app`, `area:auth` | 첫 진입 |
| `02-login.html` | `area:auth` | Apple/Google/Email |
| `03-camera-live.html` | `area:camera`, `area:filter-engine` | 라이브 프리뷰 |
| `04-filter-swipe.html` | `area:camera`, `area:filter-engine` | 필터 전환 |
| `05-capture-preview.html` | `area:camera` | 저장/공유 |
| `06-marketplace-home.html` | `area:marketplace` | 홈 피드 |
| `07-filter-detail.html` | `area:marketplace` | 상세 |
| `08-search.html` | `area:marketplace` | 검색 |
| `09-profile.html` | `area:marketplace`, `area:auth` | 내 프로필 |
| `10-settings.html` | `area:app`, `area:auth` | 설정 |
| `11-filter-editor.html` | `area:editor` | 기본 에디터 |
| `12-upload-flow.html` | `area:editor`, `area:backend` | 기본 업로드 |

### MVP P0

| 파일 | 구현 영역 | 구현 이슈 기준 |
|---|---|---|
| `13-camera-aspect-picker.html` | `area:camera` | M1-A03 |
| `14-camera-zoom-grid-flash.html` | `area:camera` | M1-A01/M1-A02 추가 UI |
| `15-camera-timer-countdown.html` | `area:camera` | M1-A04 확장 |
| `01b-onboarding-carousel.html` | `area:app` | onboarding 확장 |
| `02b-login-guest.html` | `area:auth` | M2-B02 |
| `16-photo-import.html` | `area:camera`, `area:filter-engine` | Phase 1.C |
| `17-photo-edit.html` | `area:camera`, `area:filter-engine` | Phase 1.C |
| `18-saved-filters.html` | `area:marketplace`, `area:storage` | M2-A04 |
| `19-builtin-filter-library.html` | `area:marketplace`, `area:filter-engine` | M1-C02 |
| `07b-filter-download.html` | `area:marketplace`, `area:storage` | M2-B04 |
| `07c-filter-after-download.html` | `area:marketplace`, `area:storage` | M2-B04 |
| `20-account-deletion.html` | `area:auth`, `area:security` | M5-06 / `DELETE /me` |
| `53-data-export.html` | `area:auth`, `area:security` | GDPR/개인정보 export |
| `21-edit-profile.html` | `area:auth`, `area:marketplace` | M4-01 |
| `22-universal-link-landing.html` | `area:app`, `area:marketplace` | M4-07 |

### MVP P1

| 파일 | 구현 영역 | 구현 이슈 기준 |
|---|---|---|
| `11b-editor-parameters.html` | `area:editor` | M3-B01 |
| `11c-editor-lut-import.html` | `area:editor`, `area:filter-engine` | M3-A01/M3-A02 |
| `11d-editor-save-draft.html` | `area:editor`, `area:storage` | M3-B01 |
| `12b-upload-cover.html` | `area:editor` | M3-A05 |
| `12c-upload-tags-category.html` | `area:editor`, `area:models` | M3-B02 |
| `12d-upload-tos-submit.html` | `area:editor`, `area:backend` | M3-B03~M3-B05 |
| `12e-upload-pending.html` | `area:editor`, `area:backend` | M3-B05 |
| `09b-other-user-profile.html` | `area:marketplace` | M4-01 |
| `48-filter-rejected.html` | `area:editor`, `area:moderation` | M3-B05/M5-03 반려 후 재제출 |
| `50-my-filters.html` | `area:editor`, `area:marketplace` | 메이커 필터 상태 관리 |

### Social / Search / Operations

| 파일 | 구현 영역 | 구현 이슈 기준 |
|---|---|---|
| `23-comments-list.html` | `area:marketplace`, `area:backend` | M4-04 |
| `23b-comments-compose.html` | `area:marketplace`, `area:backend` | M4-04 |
| `24-rating-form.html` | `area:marketplace`, `area:backend` | M4-03 |
| `25-followers-list.html` | `area:marketplace`, `area:backend` | M4-05 |
| `26-following-list.html` | `area:marketplace`, `area:backend` | M4-05 |
| `27-notifications-inbox.html` | `area:app`, `area:backend` | Phase 3-10/3-11 |
| `51-notification-settings.html` | `area:app`, `area:auth` | 카테고리별 알림 on/off + 방해 금지 시간 (App Store 사용자 통제권) |
| `28-maker-dashboard.html` | `area:marketplace`, `area:payments` | M6-06 |
| `29-report-form.html` | `area:moderation` | M5-01 |
| `30-favorites-collection.html` | `area:marketplace` | M4-02 |
| `31-foryou-feed.html` | `area:marketplace`, `area:backend` | Phase 4 recommendations |
| `32-following-feed.html` | `area:marketplace`, `area:backend` | M4-05 확장 |
| `33-mod-queue.html` | `area:moderation`, `area:backend` | M5-03/M5-04 |
| `34-mod-detail.html` | `area:moderation`, `area:backend` | M5-03/M5-04 |
| `35-block-list.html` | `area:moderation`, `area:auth` | Phase 5 block/mute |
| `36-remix-flow.html` | `area:editor`, `area:models` | M4/M5 remix policy |

### Monetization + Wallet

| 파일 | 구현 영역 | 구현 이슈 기준 |
|---|---|---|
| `37-paywall-single.html` | `area:payments`, `area:marketplace` | M6-04/M6-05 |
| `38-paywall-subscription.html` | `area:payments` | M6-07 |
| `39-orders-history.html` | `area:payments`, `area:marketplace` | M6-06/M6-08 |
| `40-payout-onboarding.html` | `area:payments`, `area:backend` | M6-08 |
| `41-payout-tax-info.html` | `area:payments`, `area:backend` | M6-09 |
| `42-payout-history.html` | `area:payments`, `area:backend` | M6-10 |
| `43-wallet.html` | `area:payments` | M6-01/M6-02 |
| `44-wallet-topup.html` | `area:payments` | M6-02/M6-03 |
| `45-wallet-transactions.html` | `area:payments` | M6-06 |
| `46-insufficient-balance.html` | `area:payments`, `area:marketplace` | M6-05 |
| `52-payment-failed.html` | `area:payments` | IAP 실패/취소 fallback |
| `47-earnings-withdraw.html` | `area:payments`, `area:backend` | M6-10 |
| `49-pro-status.html` | `area:payments`, `area:auth` | Pro 구독 상태/갱신/관리 |
| `54-refund-request.html` | `area:payments`, `area:app` | 환불 요청/Apple 환불 안내 |
| `52-payment-failed.html` | `area:payments` | IAP 결제 실패 fallback (재시도/복원/지원) — App Store 결제 안내 의무 |
| `53-data-export.html` | `area:auth`, `area:security` | GDPR Art. 20 / 개인정보보호법 §35 데이터 다운로드 — EU 출시 차단 |
| `54-refund-request.html` | `area:payments` | 환불 안내 — Apple 채널 직접 진입 + moodit 사유 폼(선택) |

Coin 모델의 단일 진실원은 [`CURRENCY_DESIGN.md`](./CURRENCY_DESIGN.md)이다.

---

## 4. 구현 전환 우선순위

| 순서 | 화면 묶음 | 이유 |
|---|---|---|
| 1 | 카메라 Core + `13`~`15` | 현재 코드가 가장 많이 진행된 영역이며 실기기 검증과 직접 연결 |
| 2 | 사진 저장/후보정 `05`, `16`, `17` | 카메라 MVP의 완결 흐름 |
| 3 | 저장됨/내장 필터/다운로드 `18`, `19`, `07b`, `07c` | 마켓 다운로드 MVP의 핵심 |
| 4 | 인증/게스트/계정 `02`, `02b`, `20`, `21` | App Store 정책과 가입 전환 |
| 5 | 마켓/검색/상세 `06`, `07`, `08`, `22` | 외부 공유와 필터 적용 동선 |
| 6 | 에디터/업로드 `11*`, `12*` | 메이커 공급 측 기능 |
| 7 | 소셜/운영 `23`~`36` | 커뮤니티와 UGC 운영 |
| 8 | 코인/정산 `37`~`47` | Phase 6 수익화 |

---

## 5. 문서 동기화 규칙

화면을 추가하거나 의미를 바꾸면 다음 문서를 함께 갱신한다.

| 변경 종류 | 갱신 문서 |
|---|---|
| 새 화면/화면 삭제 | `mockups/README.md`, `mockups/index.html`, 본 문서 |
| 라우트/API/이슈 변경 | `IMPLEMENTATION_PLAN.md`, `API_SPEC.md` |
| 코인/결제/정산 변경 | `CURRENCY_DESIGN.md`, `FIRESTORE_RULES.md`, `API_SPEC.md` |
| 권한 문구 변경 | `PERMISSIONS_FLOW.md`, `Info.plist` |
| 상태/모달 패턴 변경 | `EMPTY_STATES.md`, `MODAL_PATTERNS.md` |

---

## 6. 남은 문서 과제

| 항목 | 상태 | 메모 |
|---|---|---|
| 환불/분쟁 상세 UX | 부분 보강 필요 | `39`, `45`에 상태는 있으나 환불 요청/Apple 안내 진입이 별도 화면으로 분리되어 있지 않다. |
| 구현 route 명세 | 필요 | SwiftUI `NavigationPath`/tab route 이름을 실제 코드가 정해지면 본 문서에 추가한다. |
| 스냅샷 테스트 기준 | 필요 | 주요 화면별 acceptance screenshot 기준을 테스트 전략에 연결한다. |

---

## 7. 관련 문서

- [`PRD.md`](./PRD.md)
- [`IMPLEMENTATION_PLAN.md`](./IMPLEMENTATION_PLAN.md)
- [`TASK_LIST.md`](./TASK_LIST.md)
- [`DESIGN_SYSTEM.md`](./DESIGN_SYSTEM.md)
- [`CURRENCY_DESIGN.md`](./CURRENCY_DESIGN.md)
- [`PERMISSIONS_FLOW.md`](./PERMISSIONS_FLOW.md)
- [`MODAL_PATTERNS.md`](./MODAL_PATTERNS.md)
- [`EMPTY_STATES.md`](./EMPTY_STATES.md)
