# Designer Notes — moodit (2026-05-10)

> A consolidated list of comments raised across the mockup refresh.
> Each item links to the flow file where the screen lives, and references the canonical doc/source where applicable.

---

## A. What's working

These do **not** need changes. Recording so the next designer doesn't accidentally regress them.

1. **Token system in `docs/DESIGN_TOKENS.json` v1.2.0** is comprehensive — covers state (skeleton, overlay, empty), interaction (hover/pressed/selected/focusRing), and z-index scale. Mockups port it 1:1; do not re-derive from the SwiftUI source.
2. **Light-default + dark-camera split** — the camera live screen is the only OLED-style surface. This is intentional and matches Apple Camera. Don't darken the rest of the app to "match."
3. **5-tab + center shutter** (`RootShell.swift`) is correct for a camera-forward marketplace. Center shutter as `.fullScreenCover` (not as a tab selection) is the right pattern — it preserves back stack on Marketplace/Saved/Profile and matches Instagram/Snapchat models.
4. **Coin glyph + tabular numbers** in the marketplace header coin pill — keep tabular nums everywhere balances/prices appear (Wallet, Paywall, Topup, Orders, Refund).
5. **Korean primary copy with English action verbs in dev** — matches the project locale (`Localizable.xcstrings` is canonical). All mockup copy is written in Korean.

---

## B. Stale screens — mockup vs. code divergence

These are **the reason this refresh exists**. Old `mockups/` no longer match `Sources/App/**`.

| # | Screen | What changed in code | Where in deliverables |
|---|--------|---------------------|----------------------|
| 1 | Marketplace Home | Greeting copy split into two lines (`오늘의 빛, / 지금 만나보세요`); coin pill + bell moved into header right; 5-category chip row replaced 3-category; pull-to-refresh added | `flow-02-marketplace.html#marketplace-home` |
| 2 | Search | Now has 3 phases (`browsing` / `typing` / `results`) with 500ms debounce. Old mockup only showed `results`. Recent searches stored in `UserDefaults`. | `flow-02-marketplace.html#search` |
| 3 | Filter Detail | Sample carousel collapsed when `samples.count > 3`. Maker reply on review now shows a single chevron-down expand. New `report` action moved into kebab menu. | `flow-02-marketplace.html#filter-detail` |
| 4 | Camera Live | Filter strip uses 56×56 thumbs (was 48); shutter 76px (was 70); zoom indicator shifts position on aspect-ratio change. | `flow-03-camera.html#camera-live` |
| 5 | Photo Edit | New undo/redo bar, long-press = original-comparison (was a separate "before" toggle). Reset moved into top right menu. | `flow-03-camera.html#photo-edit` |
| 6 | Filter Editor | 5 sliders not 4 — `grain` was added between `saturation` and `vignette`. | `flow-04-maker.html#editor-parameters` |
| 7 | Wallet | Pro CTA banner moved above transactions; Pro status now has its own dedicated screen (`Pro Status`) when active. | `flow-05-wallet.html#wallet` |
| 8 | Wallet Topup | 4 packs (`100 / 550 / 1200 / 3000`), each with bonus % badge. Old mockup showed 3. | `flow-05-wallet.html#wallet-topup` |
| 9 | Profile | Segment control: `내 필터 / 저장됨 / 촬영함` (3 segments) — old mockup had `내 필터 / 좋아요`. | `flow-06-profile-social.html#profile-self` |
| 10 | For You Feed | Hero card + maker carousel + grid (3 sections). Old mockup was a single feed. | `flow-06-profile-social.html#foryou` |
| 11 | Reviews List | Order changed: helpfulCount-sorted by default, with toggle to "최신순". Maker reply collapsed inline (was a modal). | `flow-06-profile-social.html#reviews-list` |
| 12 | Notifications Inbox | 6 category chips (모두/좋아요/댓글/다운로드/팔로우/시스템). Time grouping is `새 / 오늘 / 이번 주 / 이전`. Old mockup only had `새 / 이전`. | `flow-07-notifications-settings.html#notifications` |
| 13 | Settings | New entries: 데이터 내보내기, 차단 목록, 도움말 외부 링크. | `flow-07-notifications-settings.html#settings` |
| 14 | Saved Filters | Edit-mode swipe-to-delete; + segmented control filtering by category. | `flow-07-notifications-settings.html#saved` |
| 15 | Favorites Collection | 4-photo mosaic cover (was single cover). New collection bottom sheet has 비공개 토글. | `flow-07-notifications-settings.html#collections` |
| 16 | Permissions modals | Now 4 permissions (camera/photos/notifications/location). Each has priming → denied two-state. | `flow-08-states-modals.html#permissions` |
| 17 | Universal Link Landing | Was rendered as a sheet — now full-screen with "마켓 열기" CTA. | `flow-02-marketplace.html#universal-link-landing` |
| 18 | Filter Rejected | Now offers 4 actions: 수정 / 이의 제기 / 고객센터 / 삭제. Old mockup had 2. | `flow-04-maker.html#filter-rejected` |

---

## C. Suggested additions (proposed, not yet in code)

Tagged `ADD` in the flow files. Listed in priority order.

### C.1 Critical — UX gaps in shipped flows

1. **Wallet low-balance hint inside Camera/Filter strip** — when user taps a paid filter from the camera strip and `walletStore.coinBalance < filter.priceCoins`, today they hit the paywall sheet which is jarring mid-capture. Add an inline pill ("부족 · 충전") next to the filter name in the strip.
2. **Search empty-state CTA** — when results = 0, currently shows "검색 결과 없음" with no next action. Add "추천 해시태그" row + "필터 만들기" deep link to maker flow.
3. **Filter Detail "체험" button** — there's no way to preview a paid filter without owning it. Add a "사진으로 미리보기" mini-flow that lets the user import a photo, applies the filter at 50% intensity for 5 seconds with a watermark, then shows the paywall.
4. **Notifications: undo for "모두 읽음 처리"** — destructive (irreversible) but currently has no confirmation or undo. Either add a confirmation dialog or a 5-second toast with `[되돌리기]` action.
5. **Maker upload: progress recovery** — if the app is killed mid-upload, today the draft remains in `pending_review_pre` indefinitely. Add a "재개 / 재시도 / 처음부터" prompt in `My Filters` for stuck drafts.

### C.2 Nice-to-have — polish

6. **Filter Tile pressed state** — on `MarketplaceScreen` cards there's no visual feedback on tap before navigation. Add a `scale(0.98) + opacity 0.85` micro-interaction (150ms ease-out) — `ui-ux-pro-max` rule §7 `scale-feedback`.
7. **Capture Preview metadata sheet** — currently there's a "사진 정보" button but no UX spec for what it shows. Mockup proposes a bottom sheet with: filter applied, intensity, datetime, location (if granted), filter author handle, "메이커 프로필 보기" link.
8. **For You feed "이 필터가 마음에 드세요?"** — add a binary thumbs-up/down on each hero card. Recommendations improve, and we get a signal source for the recommender we don't yet have.
9. **Pro status renewal-warning banner** — 7 days before `proStatus.expiresAt`, show an orange info banner on the Wallet screen ("Pro 멤버십이 4월 23일 만료됩니다 · 자동 갱신 확인").
10. **Followers list bulk-action** — for makers with 1000+ followers, no way to find or block a specific user without scrolling. Add a search-within-followers field at top.

### C.3 New screens to draw

11. **Camera "Filter favorites" reorder** — the camera filter strip pulls from saved filters. Today there's no UX to reorder. Add a "필터 정렬" sheet in camera settings with drag-handle reorder + pin-to-front.
12. **Maker earnings (closed-loop coin)** — `payout-onboarding` is `Planned` but per the inventory note, payout is closed-loop coin. Mockup shows the `Maker Dashboard` with: daily downloads chart · coin earnings · top filters. Withdraw is hidden until Phase 6.
13. **Onboarding skip → guest tour** — the `둘러보기` (guest) path lands on Marketplace immediately. Suggest a 3-step tooltip tour on first open: Camera shutter · Filter detail tap · Profile tab.

---

## D. Accessibility audit findings

Tagged `A11Y` in the flow files. From the `ui-ux-pro-max` Quick Reference §1.

1. **Top-bar icon buttons** (search, wallet, bell on `MarketplaceScreen`) all have `accessibilityLabel` set in code — confirmed in `MarketplaceScreen.swift:120-145`. Mockup mirrors them. **OK.**
2. **Filter tile cover** has no `accessibilityLabel` for the gradient image. Add `accessibilityLabel("\(filter.title), \(filter.author.handle), 별점 \(filter.ratingAvg)")` and combine to a single accessibility element.
3. **Camera filter strip** — each filter thumb is a separate accessibility element. With 20+ filters this is a screen-reader trap. Group as a single horizontally-scrollable region with `accessibilityCustomActions` for next/prev filter, OR mark the container as an `accessibilityElement(children: .contain)` so users can flick-to-scroll.
4. **Star ratings** — drawn as 5 separate stars but should announce as a single value: `"별점 4.7 / 5"`. Confirm `ReviewsListScreen` does this (need to check `Sources/App/Profile/ProfileWorkflowScreens.swift`).
5. **Camera shutter button** has only `accessibilityLabel("촬영")`. Add `accessibilityHint("두 번 탭하여 촬영합니다 · 길게 눌러 연속 촬영")` so VoiceOver users discover long-press behavior.
6. **Color-only meaning** — filter status badge (`pending` / `approved` / `rejected`) is currently differentiated by color alone in the `My Filters` rows. Add an SF Symbol prefix: `clock` / `checkmark.seal` / `exclamationmark.triangle`.
7. **Modal dismiss** — the `FMBottomSheet` for "새 컬렉션" lacks an explicit close button (relies on swipe-down). Add a small `xmark` in the top right for VoiceOver users who can't perform the dismiss gesture.
8. **Dynamic Type** — verify on Photo Edit screen that the intensity slider value text doesn't truncate at AX5 size. Currently it's set to `.fmTypography(.subhead)` with `lineLimit(1)`.

---

## E. Microcopy / i18n

Tagged `COPY` in the flow files.

1. **"오늘의 빛, 지금 만나보세요"** (marketplace greeting) — beautiful but unclear what "빛" refers to (filter? mood?). Consider A/B: `"오늘의 무드, 지금 만나보세요"` or `"오늘 어울리는 필터를 골라보세요"`.
2. **"둘러보기"** (login screen guest button) — implies "browsing" but actually creates a guest account. Suggest `"로그인 없이 시작"` for clarity.
3. **"체험"** vs **"미리보기"** — both used in different files. Pick one. I prefer `"미리보기"`.
4. **"Pro 시작"** vs **"Pro 멤버십 보기"** — first appears on Wallet, second on Paywall. They should both be "Pro 멤버십 보기" before subscribing, then "내 Pro" once active.
5. **Notifications time labels** — `"새"` is a single character and reads ambiguously. Use `"읽지 않음"` or `"새 알림"`.
6. **Refund Request reason picker** — current options are free-text. Consider a fixed picker with: `중복 구매 / 작동 안 함 / 단순 변심 / 기타`. Apple's IAP refund flow uses this pattern.

---

## F. Consistency checks across the system

1. **Card radius**: tiles use `R.md` (12px) — consistent. **OK.**
2. **Tap target**: all buttons in mockup have `min-height: 44px`. Confirmed against `FMLayout.minTapTarget`. **OK.**
3. **Header height** varies between Marketplace (~80) and Profile (~120) due to greeting/bio. Not a bug, but the back-button/title alignment should snap to the same baseline.
4. **Toast position** — sometimes from top (foreground push banner), sometimes from bottom (action confirmations). Confirm: top = system events, bottom = user actions. Document this in `MODAL_PATTERNS.md`.
5. **Filter status pills** — rendered different ways across `My Filters`, `Mod Queue`, `Filter Detail`. Standardize to: pill with category color + SF Symbol prefix + Korean label.

---

## G. Out of scope (deferred)

* Tablet / iPad split-view layouts — `project.yml` targets iPhone only at MVP.
* Apple Watch companion — not in scope.
* iMessage stickers — Phase 7+, not in inventory.
* Localization beyond ko/en — see `docs/I18N_MIGRATION.md` for plan.

---

— End of designer notes. See individual flow files for screen-level annotations.
