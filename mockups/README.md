# moodit — HTML Mockups

> 버전: v1.4 · 작성일: 2026-05-06 · 모드: Light 기본 + Dark 카메라 흐름
>
> iPhone 14 Pro 기준 393x852pt 프레임으로 작성한 제품 화면 67개, 상태 카탈로그 1개, 권한 화면 8개, 모달 패턴 4개를 관리한다. SwiftUI 구현 시 1pt = 1px 기준으로 해석한다.

---

## 보는 방법

```bash
open /Users/user/workspace/applications/filterMarket/mockups/index.html
```

또는 `mockups/index.html` 파일을 브라우저에서 직접 연다. 외부 폰트, 이미지, CDN 호출 없이 오프라인에서 동작한다.

---

## 현재 자산 인벤토리

| 분류 | 수 | 위치 |
|---|---:|---|
| 제품 화면 | 67 | `screens/*.html` (`states-catalog.html` 제외) |
| 상태 카탈로그 | 1 | `screens/states-catalog.html` |
| 권한 화면 | 8 | `screens/permissions/*.html` |
| 모달 패턴 | 4 | `screens/modals/*.html` |
| 브랜드 SVG | 10 | `brand/*.svg` |
| 브랜드 미리보기 | 1 | `brand/preview.html` |

---

## 화면 그룹

### Core 12

| 화면 | 모드 | 역할 |
|---|---|---|
| `01-onboarding.html` | Light | 진입 카드 스택 |
| `02-login.html` | Light | Apple/Google/이메일 로그인 |
| `03-camera-live.html` | Dark | 라이브 카메라 + HUD |
| `04-filter-swipe.html` | Dark | 필터 스와이프 + 강도 |
| `05-capture-preview.html` | Dark | 촬영 직후 미리보기 |
| `06-marketplace-home.html` | Light | 마켓 홈 |
| `07-filter-detail.html` | Light | 필터 상세 |
| `08-search.html` | Light | 검색 |
| `09-profile.html` | Light | 내 프로필 |
| `10-settings.html` | Light | 설정 |
| `11-filter-editor.html` | Light | 에디터 기본 |
| `12-upload-flow.html` | Light | 업로드 기본 |

### MVP P0

| 화면 | 역할 |
|---|---|
| `13-camera-aspect-picker.html` | 촬영 비율 1:1/4:3/16:9 |
| `14-camera-zoom-grid-flash.html` | 줌, 그리드, 플래시 HUD |
| `15-camera-timer-countdown.html` | 셀프타이머 카운트다운 |
| `01b-onboarding-carousel.html` | 4-step 온보딩 |
| `02b-login-guest.html` | 게스트 진입과 로그인 필요 인터셉트 |
| `16-photo-import.html` | 사진 가져오기 |
| `17-photo-edit.html` | 가져온 사진 후보정 |
| `18-saved-filters.html` | 저장됨 탭 |
| `19-builtin-filter-library.html` | 내장 필터 라이브러리 |
| `07b-filter-download.html` | 다운로드 진행 |
| `07c-filter-after-download.html` | 다운로드 완료 후 상세 |
| `20-account-deletion.html` | 계정 삭제 |
| `53-data-export.html` | 데이터 내보내기 |
| `21-edit-profile.html` | 프로필 편집 |
| `22-universal-link-landing.html` | Universal Link 랜딩 |

### MVP P1

| 화면 | 역할 |
|---|---|
| `11b-editor-parameters.html` | 에디터 파라미터 |
| `11c-editor-lut-import.html` | LUT import |
| `11d-editor-save-draft.html` | 초안 저장 |
| `12b-upload-cover.html` | 업로드 커버 |
| `12c-upload-tags-category.html` | 태그/카테고리 |
| `12d-upload-tos-submit.html` | 약관/제출 |
| `12e-upload-pending.html` | 심사 대기 |
| `09b-other-user-profile.html` | 타인 프로필 |
| `48-filter-rejected.html` | 필터 반려 안내와 재제출 |
| `50-my-filters.html` | 내 필터 관리 |

### Social, Search, Operations

| 화면 | 역할 |
|---|---|
| `23-comments-list.html`, `23b-comments-compose.html` | 댓글 목록/작성 |
| `24-rating-form.html` | 평점 입력 |
| `25-followers-list.html`, `26-following-list.html` | 팔로워/팔로잉 |
| `27-notifications-inbox.html` | 알림 인박스 |
| `51-notification-settings.html` | 알림 카테고리 설정 |
| `28-maker-dashboard.html` | 메이커 대시보드 |
| `29-report-form.html` | 신고 폼 |
| `30-favorites-collection.html` | 즐겨찾기 컬렉션 |
| `31-foryou-feed.html`, `32-following-feed.html` | 추천/팔로잉 피드 |
| `33-mod-queue.html`, `34-mod-detail.html` | 모더레이션 큐/상세 |
| `35-block-list.html` | 차단/뮤트 관리 |
| `36-remix-flow.html` | 리믹스 흐름 |
| `49-pro-status.html` | Pro 상태/갱신/관리 |

### Monetization + Wallet

| 화면 | 역할 |
|---|---|
| `37-paywall-single.html` | 코인 기반 필터 구매 |
| `38-paywall-subscription.html` | Pro 멤버십 |
| `39-orders-history.html` | 보유 필터/구매 이력 |
| `40-payout-onboarding.html` | Stripe Connect 정산 온보딩 |
| `41-payout-tax-info.html` | 세무 정보 |
| `42-payout-history.html` | 정산 내역 |
| `43-wallet.html` | 지갑 메인 |
| `44-wallet-topup.html` | 코인 충전 |
| `45-wallet-transactions.html` | 거래 ledger |
| `46-insufficient-balance.html` | 잔액 부족 모달 |
| `52-payment-failed.html` | 결제 실패 fallback |
| `47-earnings-withdraw.html` | 메이커 출금 신청 |
| `54-refund-request.html` | 환불 요청 안내 |

---

## 구현 매핑 기준

| 목업 그룹 | 우선 문서 |
|---|---|
| 전체 화면 인벤토리 | [`../docs/SCREENS_PLAN.md`](../docs/SCREENS_PLAN.md) |
| 디자인 토큰/컴포넌트 | [`../docs/DESIGN_SYSTEM.md`](../docs/DESIGN_SYSTEM.md), [`../docs/DESIGN_TOKENS.json`](../docs/DESIGN_TOKENS.json) |
| 상태/빈 화면 | [`../docs/EMPTY_STATES.md`](../docs/EMPTY_STATES.md) |
| 권한 | [`../docs/PERMISSIONS_FLOW.md`](../docs/PERMISSIONS_FLOW.md) |
| 모달 | [`../docs/MODAL_PATTERNS.md`](../docs/MODAL_PATTERNS.md) |
| 모션 | [`../docs/MOTION_SPEC.md`](../docs/MOTION_SPEC.md) |
| 코인/지갑/정산 | [`../docs/CURRENCY_DESIGN.md`](../docs/CURRENCY_DESIGN.md) |

---

## SwiftUI 구현 메모

- 라이트 화면은 기본 색상 체계를 사용하고, 카메라 흐름은 `.preferredColorScheme(.dark)`로 고정한다.
- `index.html`은 전체 목업 탐색용이고, 실제 구현 기준은 각 개별 HTML 파일과 `SCREENS_PLAN.md`의 라우트/모듈 매핑이다.
- 모달 목업은 SwiftUI 표준 API에 매핑한다: bottom sheet는 `.sheet`, action sheet는 `.confirmationDialog`, confirmation은 `.alert`, share는 `ShareLink`/`UIActivityViewController`.
- 권한 흐름은 priming 화면을 먼저 보여준 뒤 시스템 권한 다이얼로그를 호출한다.
