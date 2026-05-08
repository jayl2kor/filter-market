# moodit QA Test Plan

> 작성: 2026-05-07 KST
> 대상 빌드: 기준 커밋 `15237a6` + QA issue batch 반영
> 목적: 모든 사용자 도달 가능 화면의 모든 인터랙티브 요소를 1:1로 검증.

---

## 0. 사용법

0. QA 시작 전 [SCREEN_ACTIONS_QA_DEFINITION.md](./SCREEN_ACTIONS_QA_DEFINITION.md)를 먼저 확인해 화면 ID, route, required action, 우선순위를 고정한다.
1. 본 문서를 인쇄 또는 분할 화면으로 띄우고 한 손에 iPhone, 다른 손에 체크박스.
2. **§1 환경 준비**부터 순서대로 — 권한 / 인증 / 시드 데이터 상태가 후속 테스트에 영향.
3. 각 행의 **PASS / FAIL** 칸에 결과 기록. FAIL은 §15 버그 리포트 템플릿으로.
4. **빨간 볼드 ⚠️**가 붙은 항목은 사용자 데이터가 변경되거나 비가역적인 동작이라 신중하게.
5. **🔴 BROKEN** 마크는 본 빌드에서 미구현/막힘이 알려진 항목 — FAIL이 아니라 *expected*.

### 빌드 / 인스톨

```bash
# 자동 회귀: unit + P0CoreActionTests + Phase A/D + ActionSurfaceSmokeTests AppUITests
./scripts/test.sh

# 시뮬레이터 (Push 미지원, 카메라 미지원, Metal 가능)
./scripts/build.sh

# 실기기 (전체 검증 가능)
xcodebuild -project moodit.xcodeproj -scheme moodit \
  -destination 'platform=iOS,name=<사용자 iPhone 이름>' \
  -toolchain com.apple.dt.toolchain.Metal.32023.864 install
```

### 테스트 계정

| 역할 | 사용 시점 | 방법 |
|---|---|---|
| **Guest** | §3 Guest flow | 첫 실행, 온보딩 후 "로그인 없이 둘러보기" |
| **일반 사용자** | §4~§9 대부분 | Apple 또는 Google 로그인 |
| **메이커** | §10 maker flow | 일반 사용자 + 업로드한 필터 1개 이상 |
| **Admin** | §13 moderation | Firebase Custom Claim `role: "admin"` 직접 설정 |

---

## 1. 환경 준비

| # | 항목 | Expected | PASS/FAIL |
|---|------|----------|-----------|
| 1.1 | 첫 설치 후 첫 실행 | 온보딩 4페이지 → 로그인 화면 |  |
| 1.2 | 카메라 권한 다이얼로그 | "사진을 촬영하고 라이브 필터를…" 메시지 |  |
| 1.3 | 사진 라이브러리 권한 | "마음에 드는 필터로 찍은 사진을…" 메시지 |  |
| 1.4 | 위치 권한 (선택) | "촬영한 사진의 EXIF 에 위치를…" 메시지 |  |
| 1.5 | 알림 권한 | "moodit"이(가) 알림을 보내고자 합니다. (실기기만) |  |
| 1.6 | `GoogleService-Info.plist` 포함 확인 | Firebase 초기화 후 크래시 없이 로그인 화면 진입. Google 계정 picker/credential 교환은 수동 QA 게이트 |  |

**Reset to baseline**: 설정 > moodit > 데이터 및 저장공간 → "앱 삭제" → 재설치.

---

## 2. Onboarding (4페이지)

**도달 경로**: 첫 실행, `@AppStorage("hasOnboarded") == false`

| # | 위치 | Element | Expected action | PASS/FAIL |
|---|------|---------|-----------------|-----------|
| 2.1 | 1~3페이지 | "건너뛰기" (우상단) | onComplete 콜백 → 로그인 화면 |  |
| 2.2 | 1~3페이지 | "다음" (FMButton primary) | TabView selection +1, 애니메이션 |  |
| 2.3 | 4페이지 | "시작하기" (FMButton primary) | onComplete 콜백 → 로그인 화면 |  |
| 2.4 | 모든 페이지 | 좌우 스와이프 | 페이지 전환 |  |
| 2.5 | 모든 페이지 | 페이지 인디케이터 dots | 비인터랙티브, 현재 페이지 강조 |  |
| 2.6 | (앱 재실행) | 온보딩 종료 후 재실행 | 온보딩 안 뜸 (직접 root 진입) |  |

---

## 3. Login

**도달 경로**: `AppRoute.login`, 또는 온보딩 종료 후

| # | Element | Expected action | PASS/FAIL |
|---|---------|-----------------|-----------|
| 3.1 | "Apple로 계속하기" | Apple Sign In 시트 → 인증 → onAuthenticated |  |
| 3.2 | "Google로 계속하기" | GIDSignIn 시트 → Google 계정 선택 → Firebase Auth credential 교환 → onAuthenticated (실기기에서만 검증 가능) |  |
| 3.3 | "이메일로 계속" (`auth.email.continue`) | EmailLoginScreen push: 토글 (auth.mode.toggle), 이메일 (auth.email.input), 비밀번호 (auth.password.input). 정책 검증, friendly Korean error map, password reset link. |  |
| 3.4 | "로그인 없이 둘러보기" | onContinueAsGuest → 마켓 탭으로 진입 |  |
| 3.5 | "이용약관" 텍스트 | SafariView로 https://moodit.app/terms 열림 (in-app) |  |
| 3.6 | "개인정보처리방침" 텍스트 | SafariView로 https://moodit.app/privacy 열림 (in-app) |  |
| 3.7 | 어떤 버튼 로딩 중 | 다른 버튼들 모두 disabled |  |

---

## 4. Marketplace (루트 탭)

**도달 경로**: 로그인 후 탭바 1번째

| # | Element | Expected action | PASS/FAIL |
|---|---------|-----------------|-----------|
| 4.1 | 검색바 ("필터, 메이커, 분위기 검색") | → AppRoute.search(initialQuery: nil) |  |
| 4.2 | 알림 종 아이콘 (우상단) | → AppRoute.notifications |  |
| 4.3 | 트렌딩 가로 스크롤 | 좌우 스와이프 동작 |  |
| 4.4 | 트렌딩 카드 0번 (highlight) | → AppRoute.filterDetail(id: title) |  |
| 4.5 | 카테고리 칩 (cinematic / vintage / pastel / etc.) | selectedCategory 갱신, 그리드 필터링 |  |
| 4.6 | "전체" 카테고리 칩 | selectedCategory = nil |  |
| 4.7 | 신규 필터 그리드 타일 (2열) | → AppRoute.filterDetail(id: title) |  |
| 4.8 | 컬렉션 캐러셀 (`market.collection.<title>`) | 컬렉션별 SearchScreen으로 (initialCategory = 컬렉션 이름) |  |
| 4.9 | 그리드 타일 long-press | 미구현 (no-op) |  |
| 4.10 | Pull-to-refresh | `store.load()` 재호출, 스피너 표시 후 데이터 갱신 |  |
| 4.11 | 코인 잔액 pill (`market.header.coinBalance`) | → AppRoute.wallet. 로그인 지갑 listener가 있으면 현재 coinBalance 표시 |  |

---

## 5. FilterDetail

**도달 경로**: 마켓/검색/프로필 등에서 카드 탭 → `AppRoute.filterDetail(id:)`

| # | Element | Expected action | PASS/FAIL |
|---|---------|-----------------|-----------|
| 5.1 | ← Back (좌상단) | dismiss |  |
| 5.2 | Share 아이콘 (우상단, `filter.detail.share`) | UIActivityViewController 시트 표시 (제목 + URL `https://moodit.app/f/<slug>`) |  |
| 5.3 | Before/After 슬라이더 | 드래그 → sliderProgress 갱신 (0~1) |  |
| 5.4 | Before/After 접근성 increment | 5%씩 증가 |  |
| 5.5 | Before/After 접근성 decrement | 5%씩 감소 |  |
| 5.6 | 메이커 핸들 (@jisoo.films) | → AppRoute.otherProfile(uid:) |  |
| 5.7 | "팔로우" 버튼 | isFollowing 토글 → "팔로잉"으로 변경 |  |
| 5.8 | "팔로잉" 버튼 | isFollowing 토글 → "팔로우"로 변경 |  |
| 5.9 | 태그 칩 (`filter.detail.tag.<tag>`) | → AppRoute.search(initialQuery: "#tag") — 검색에서 title/author/category/tags 기준으로 해당 태그 자동 필터링 |  |
| 5.10 | 샘플 갤러리 컨테이너 (`filter.detail.sample.gallery`) | 가로 스크롤 갤러리 표시. `signatureSampleURL` 또는 `coverURL`이 있으면 첫 슬롯에 메이커 시그니처/커버 샘플 표시 |  |
| 5.11 | 메이커 시그니처 샘플 (`filter.detail.sample.signature`) | URL 이미지 로드 성공 시 실제 이미지, 실패/로딩 시 카테고리 placeholder 표시 |  |
| 5.12 | 시스템 reference 샘플 (`filter.detail.sample.reference.portrait/landscape/indoor/lifestyle`) | 4개 reference가 항상 표시되고, 카테고리 LUT 적용 결과가 progressive render/cache 후 표시. 실패 시 원본 reference fallback |  |
| 5.13 | 리뷰 섹션 헤더 "리뷰 → \(N개)" | → AppRoute.reviews(filterId:) |  |
| 5.14 | 리뷰 row (3개 미리보기) | 비인터랙티브 (avatar는 별도 wiring 없음) |  |
| 5.15 | ★ 평점 등록 (toolbar) | Auth-gated → AppRoute.rating(filterId:) |  |
| 5.16 | "리뷰 작성" 버튼 (`social.reviews.compose`) | Auth-gated → AppRoute.reviewCompose(filterId:) |  |
| 5.17 | "무료 다운로드" CTA (무료 필터) | downloadState transitions: ready→downloading→completed |  |
| 5.17b | UUID 기반 실제 필터 다운로드 | `getFilterDetail.signedDownloadURL`로 `.fmpkg`를 `Application Support/moodit/downloaded-packages`에 저장하고 URLSession byte progress를 표시한 뒤 saved filter 동기화 |  |
| 5.18 | "구매" CTA (유료 필터) | `PaywallSingleScreen` 진입, `filter.purchase.confirm` 또는 `filter.purchase.pro_upgrade` 선택 가능 |  |
| 5.18b | Pro 활성 + 유료 필터 | Paywall 가격이 "Pro 멤버십에 포함"으로 표시되고 `filter.purchase.confirm`은 코인 차감/callable 없이 saved filter 동기화 후 after-download로 이동 |  |
| 5.19 | "촬영하기" CTA (다운로드 후) | dismiss → 카메라로 |  |
| 5.20 | 다운로드 진행 중 추가 탭 | no-op (재요청 불가) |  |
| 5.21 | 좋아요 CTA (`filter.detail.like`) | 실제 필터는 favorite store 토글, mock detail은 local liked state 토글. 접근성 value가 on/off로 변경 |  |
| 5.22 | 다운로드/좋아요/리뷰 카운트 | Firestore detail response의 `downloadCount`, `likeCount`, `reviewCount`를 그대로 표시. mock 추정값으로 대체하지 않음 |  |
| 5.23 | 다운로드 실패/화면 이탈 | 실패 시 완료 상태로 전환하지 않고 실패 alert 표시. 진행 중 dismiss 시 download task 취소 |  |

---

## 6. Reviews

### 6.1 ReviewsListScreen — `AppRoute.reviews(filterId:)`

| # | Element (ID) | Expected action | PASS/FAIL |
|---|---|-----------------|-----------|
| 6.1.1 | 필터 미니카드 (`social.reviews.filter`) | → AppRoute.filterDetail |  |
| 6.1.2 | 리뷰 row (`social.review.row`) | row 자체는 정보 표시 |  |
| 6.1.3 | 메이커 답글 row (`social.review.makerReply.row`) | 표시 only |  |
| 6.1.4 | 별점 표시 (`social.review.stars`) | 1~5 별 표시, 채워진 별 = stars |  |
| 6.1.5 | 다운로드 확인 뱃지 (`social.review.verified`) | isVerifiedDownload=true일 때만 |  |
| 6.1.6 | 👍 helpful (`social.review.helpful`) | helpfulIDs 토글, count 갱신 |  |
| 6.1.7 | 작성자 아바타 | → AppRoute.otherProfile(uid:) |  |
| 6.1.8 | "리뷰 추가..." (`social.reviews.compose`) | Auth-gated → AppRoute.reviewCompose |  |
| 6.1.9 | paper plane 버튼 | 동일 → reviewCompose |  |
| 6.1.10 | ★ Rating (toolbar) | Auth-gated → AppRoute.rating |  |
| 6.1.11 | ··· more (`social.review.more`) | ConfirmationDialog: 신고 / 작성자 차단 / 텍스트 복사 / 취소 |  |
| 6.1.12 | (게스트) "로그인하고 리뷰 남기기" empty state | → AppRoute.login |  |
| 6.1.13 | 화면 이탈 | Firestore reviews listener 정리, 재진입 시 중복 listener 없이 최신 목록 attach |  |

### 6.2 ReviewComposeScreen — `AppRoute.reviewCompose(filterId:)`

| # | Element (ID) | Expected action | PASS/FAIL |
|---|---|-----------------|-----------|
| 6.2.1 | "취소" (toolbar leading) | dismiss |  |
| 6.2.2 | "게시" (toolbar trailing, `social.compose.send`) | dismiss + 햅틱 (실 전송은 mock) |  |
| 6.2.3 | "게시" 빈 텍스트 시 | disabled (회색) |  |
| 6.2.4 | "게시" 280자 초과 시 | disabled |  |
| 6.2.5 | 텍스트 에디터 (`social.compose.input`) | 텍스트 입력 |  |
| 6.2.6 | "@" 입력 시 mention box 표시 (`social.compose.mentions`) | 후보 3개 |  |
| 6.2.7 | mention 후보 탭 | text 안의 @jiso → @<handle> 치환 |  |
| 6.2.8 | @ 아이콘 (`social.compose.insertMention`) | 본문에 "@" 삽입 → 기존 mention box 표시; 햅틱 |  |
| 6.2.9 | photo 아이콘 (toolbar, `social.compose.attachImage`) | PHPicker 시트 → 이미지 1장 선택 → 본문 위에 썸네일 표시 |  |
| 6.2.9b | 첨부 사진 X 버튼 (`social.compose.removeImage`) | 첨부 이미지 제거 |  |
| 6.2.10 | emoji 아이콘 (`social.compose.emojiToggle`) | 16개 이모지 팔레트 토글 (✨🌅🌇🌙☕️📷🎞️🌿🌸💛🤎🔥✏️🖼🎨🌊) |  |
| 6.2.10b | 이모지 한 개 탭 (`social.compose.emoji.<emoji>`) | 본문에 해당 이모지 추가; 햅틱 |  |
| 6.2.11 | 글자 카운터 | text.count / 280 표시, 초과 시 warning 색 |  |
| 6.2.12 | (게스트 진입) FMEmptyState `.emptyReviews(false)` | "로그인하고 리뷰 쓰기" CTA → AppRoute.login |  |

### 6.3 RatingFormScreen — `AppRoute.rating(filterId:)`

| # | Element (ID) | Expected action | PASS/FAIL |
|---|---|-----------------|-----------|
| 6.3.1 | 별 1~5 (`social.rating.star.1`~`.5`) | rating 갱신, 햅틱 |  |
| 6.3.2 | rating 변화에 따른 라벨 | 초기값 "별점을 선택해주세요"; 선택 후 "아쉬워요"~"최고예요!" |  |
| 6.3.3 | 태그 칩 (자연스러움 / 강도 조절 / 등) | selectedTags 토글 |  |
| 6.3.4 | 본문 텍스트 (`social.rating.body`) | 입력 가능 |  |
| 6.3.5 | "건너뛰기" (FMButton secondary) | dismiss |  |
| 6.3.6 | "평점 등록" (`social.rating.submit`) | 별점 미선택 시 disabled. 선택 후 Firestore ratings upsert, 실패 시 inline error |  |
| 6.3.7 | (게스트 진입) | "로그인하고 평점 남기기" CTA → AppRoute.login |  |

---

## 7. Camera

**도달 경로**: 탭바의 셔터 또는 다운로드 후 "촬영하기"

| # | Element (ID) | Expected action | PASS/FAIL |
|---|---|-----------------|-----------|
| 7.1 | X 닫기 (`camera.dismiss`) | dismiss (cover로 띄웠을 때만 표시) |  |
| 7.2 | aspect ratio 메뉴 (`camera.aspectRatio`) | 1:1/4:3/16:9 선택, 체크마크 표시 |  |
| 7.3 | timer 메뉴 (`camera.timer`) | OFF/3s/10s 선택 |  |
| 7.4 | grid 토글 (`camera.grid.toggle`) | 그리드 라인 표시/숨김 |  |
| 7.5 | flash 메뉴 (`camera.flash`) | OFF/AUTO/ON 선택 |  |
| 7.6 | 전후면 전환 (`camera.flip`) | 전/후면 카메라 전환 |  |
| 7.7 | 강도 슬라이더 (`camera.filterIntensity`) | 0~100% 갱신, 라이브 프리뷰 |  |
| 7.8 | 필터 칩 (`camera.filter.<UUID>`) | 활성 필터 변경, 글로우 |  |
| 7.9 | 갤러리 (`camera.openLibrary`) | fullScreenCover PhotoImportScreen |  |
| 7.10 | 셔터 (`camera.shutter`) | timer 적용 → 캡처 → CapturePreviewScreen |  |
| 7.11 | 줌 0.5x (`camera.zoom.0.5`) | zoom preset 변경 |  |
| 7.12 | 줌 1x (`camera.zoom.1`) | zoom preset 변경 |  |
| 7.13 | 줌 3x (`camera.zoom.3`) | zoom preset 변경 |  |
| 7.14 | 프리뷰 탭 (focus) | FocusReticle 850ms 표시 |  |
| 7.15 | 좌우 드래그 | 필터 좌/우 전환 |  |
| 7.16 | timer 카운트다운 중 화면 탭 | 카운트다운 취소 |  |
| 7.17 | 캡처 실패 (시뮬레이터) | "촬영 실패" 알럿 |  |
| 7.18 | 카메라 권한 거부 후 진입 | `CameraPermissionDenied` 표시: "카메라 권한이 꺼져있어요" + "설정 열기" 버튼 |  |
| 7.19 | 7.18에서 "설정 열기" 탭 | iOS 설정 앱 → moodit 권한 페이지로 이동 |  |
| 7.20 | 카메라 권한 미요청 (notDetermined) | `CameraPermissionPriming` 표시: "카메라 사용 안내" + "허용" CTA |  |

### 7.x CameraAspectPickerScreen — `AppRoute.cameraAspect`
| # | ID | Expected | PASS/FAIL |
|---|---|---|---|
| 7.x.1 | `cam.aspect.set.1_1` | aspect = .square |  |
| 7.x.2 | `cam.aspect.set.4_3` | aspect = .fourThree |  |
| 7.x.3 | `cam.aspect.set.16_9` | aspect = .sixteenNine |  |

### 7.y CameraTimerCountdownScreen — `AppRoute.cameraTimer`
| # | ID | Expected | PASS/FAIL |
|---|---|---|---|
| 7.y.1 | `cam.timer.set.off` | timer = .off |  |
| 7.y.2 | `cam.timer.set.3` | timer = .threeSeconds |  |
| 7.y.3 | `cam.timer.set.10` | timer = .tenSeconds |  |
| 7.y.4 | `cam.timer.cancel` | 진행 중 카운트다운 취소 |  |

---

## 8. CapturePreview / PhotoEdit / PhotoImport

### 8.1 CapturePreviewScreen (cover from CameraScreen)

| # | Element (ID) | Expected | PASS/FAIL |
|---|---|---|---|
| 8.1.1 | 닫기 (`preview.dismiss`) | onRetake() + dismiss |  |
| 8.1.2 | ··· more (`preview.more`) | ConfirmationDialog: 사진 정보 / 다른 필터로 적용 / 메타데이터 복사 / 취소 |  |
| 8.1.3 | "저장" (`preview.save`) | onSave → photoLibrarySaver.savePhoto |  |
| 8.1.4 | "공유" (`preview.share`) | onShare → ShareSheet (mock) |  |
| 8.1.5 | "재촬영" (`preview.retake`) | onRetake → CameraScreen으로 |  |
| 8.1.6 | "필터 변경" (`preview.changeFilter`) | onChangeFilter (필터 선택 UI 또는 카메라로) |  |
| 8.1.7 | "편집" (`preview.edit`) | 편집 플로우 진입 |  |
| 8.1.8 | "삭제" (`preview.discard`) | confirmation dialog |  |
| 8.1.9 | 삭제 확인 alert "삭제" | onDiscard 호출 |  |
| 8.1.10 | 삭제 확인 alert "취소" | dialog dismiss |  |

### 8.2 PhotoImportScreen — `AppRoute.photoImport`

| # | Element (ID) | Expected | PASS/FAIL |
|---|---|---|---|
| 8.2.1 | "photo.import.cell.tap" | 사진 선택 |  |
| 8.2.2 | "photo.import.next" | → AppRoute.photoEdit |  |

### 8.3 PhotoEditScreen — `AppRoute.photoEdit`

| # | Element (ID) | Expected | PASS/FAIL |
|---|---|---|---|
| 8.3.1 | "photo.edit.filter.tap" | 필터 변경 picker |  |
| 8.3.2 | "photo.edit.intensity" | 0~100% 슬라이더 |  |
| 8.3.3 | "photo.edit.save_share" | 저장/공유 시트 |  |

---

## 9. Saved (루트 탭)

| # | Element (ID) | Expected | PASS/FAIL |
|---|---|---|---|
| 9.1 | 빈 상태 | "다운로드한 필터가 없어요" + "마켓 둘러보기" CTA |  |
| 9.2 | "마켓 둘러보기" CTA | → AppRoute (no specific) |  |
| 9.3 | 다운로드된 타일 (`saved.tile.<UUID>`) | → AppRoute.filterDetail |  |
| 9.4 | "기본 필터" (toolbar) | → AppRoute.builtinFilters |  |
| 9.5 | First-appear skeleton | 약 0.5s 후 실데이터로 교체 |  |
| 9.6 | 다운로드 직후 앱 재실행 | `/users/{uid}/savedFilters` listener로 같은 필터가 다시 표시 |  |
| 9.7 | 다운로드 제거 | `/users/{uid}/savedFilters/{filterId}`와 `/users/{uid}/favorites/{filterId}` delete 성공 후 저장/즐겨찾기 상태 제거. 실패 시 rollback + alert |  |

---

## 10. Maker / Editor / Upload

### 10.1 BuiltinFilterLibrary — `AppRoute.builtinFilters`

| # | Element | Expected | PASS/FAIL |
|---|---|---|---|
| 10.1.1 | 카테고리 chip | 카테고리별 필터 |  |
| 10.1.2 | 필터 카드 | 카메라로 적용 |  |

### 10.2 FilterEditor / Parameters / LUT / Draft

`AppRoute.editor`, `.editorParameters`, `.editorLUT`, `.editorDraft`

| # | ID | Expected | PASS/FAIL |
|---|---|---|---|
| 10.2.1 | `editor.params` | → AppRoute.editorParameters |  |
| 10.2.2 | `editor.lut` | → AppRoute.editorLUT |  |
| 10.2.3 | `editor.draft` | → AppRoute.editorDraft |  |
| 10.2.4 | `editor.next` | 다음 단계 (→uploadCover) |  |
| 10.2.5 | `editor.preview` | 현재 draft category/LUT/parameter를 적용한 reference preview 표시. 렌더 실패 시 원본/gradient fallback |  |
| 10.2.6 | `editor.reference.photo.pick` | PhotosPicker 표시, 사용자 선택 이미지를 1280px 장변 JPEG로 normalize 후 preview source로 사용 |  |
| 10.2.7 | `editor.reference.photo.clear` | 사용자 reference photo 제거, 시스템 sample source로 복귀 |  |
| 10.2.8 | `editor.reference.sample.<kind>` | portrait/landscape/indoor/lifestyle 임시 샘플 중 하나 선택, 사용자 photo가 있으면 clear 후 선택 적용 |  |
| 10.2.9 | `editor.param.slider` | 노출/대비/채도/그레인/비네트 값 변경, 250ms debounce 후 preview 재렌더 |  |
| 10.2.10 | `editor.compare.hold` | 손을 누르고 있을 동안 비포 표시 |  |
| 10.2.11 | `editor.lut.import` | UIDocumentPicker 표시 (.cube 파일 선택), 파싱 성공 시 LUT 카드와 preview 갱신, 실패 시 에러 alert |  |
| 10.2.12 | `editor.lut.replace` | LUT 교체 |  |
| 10.2.13 | `editor.draft.save` | 초안 저장 → AppRoute.myFilters |  |
| 10.2.14 | `editor.draft.publish` | 바로 → AppRoute.uploadCover |  |
| 10.2.15 | draft 재진입/재시작 | `/users/{uid}/makerDrafts` listener로 저장한 draft 리스트가 MyFilters에 복원됨. 직접 선택한 signature photo 바이너리는 Storage 후속 범위 |  |

### 10.3 Upload Workflow

| # | Route | ID | Expected | PASS/FAIL |
|---|---|---|---|---|
| 10.3.1 | uploadCover | `upload.cover.add` | photo picker → 커버 |  |
| 10.3.2 | uploadCover | `upload.cover.ba.toggle` | 비포/애프터 자동 |  |
| 10.3.3 | uploadCover | `upload.signature.preview` | 선택한 시그니처 샘플 미리보기. 직접 사진 또는 시스템 sample kind가 없으면 category gradient placeholder |  |
| 10.3.4 | uploadCover | `upload.signature.photo.pick` | PhotosPicker 표시, 사용자 사진을 normalize 후 시그니처 샘플 슬롯에 반영 |  |
| 10.3.5 | uploadCover | `upload.signature.sample.<kind>` | portrait/landscape/indoor/lifestyle 임시 샘플 중 하나를 시그니처 샘플 슬롯으로 선택 |  |
| 10.3.6 | uploadCover | `upload.signature.clear` | 직접 사진/시스템 샘플 선택 초기화 |  |
| 10.3.7 | uploadCover | `upload.next` | → uploadTags |  |
| 10.3.7b | uploadCover | `upload.cancel` | alert: 초안 저장하고 나가기=draft save+dismiss, 초안 버리고 나가기=reset+dismiss, 계속 작성=stay |  |
| 10.3.8 | uploadTags | `upload.tag.add` | 태그 추가 시트 |  |
| 10.3.9 | uploadTags | `upload.cat.tap` | 카테고리 picker |  |
| 10.3.10 | uploadTags | `upload.next` | → uploadSubmit |  |
| 10.3.11 | uploadSubmit | `upload.tos.toggle` | TOS 토글 |  |
| 10.3.12 | uploadSubmit | `upload.submit` | TOS off일 때 disabled, on이면 → uploadPending |  |
| 10.3.13 | uploadPending | `upload.pending.view_filter` | → AppRoute.myFilters |  |
| 10.3.14 | uploadPending | `upload.pending.dismiss` | dismiss |  |
| 10.3.15 | (전체) | Cloud Function `uploadInit` (Firestore draft 생성 + R2 presigned PUT URL 발급, `signatureSampleURL` 필드 보존) → 클라이언트 PUT (FilterPackageUploader) → `uploadFinalize` (R2 HEAD로 size/sha256 검증, status → `pending_review_pre`). UI ↔ Function 호출과 실제 시그니처 이미지 R2 업로드는 별도 이슈로 추적. |  |

### 10.4 RemixFlow / MakerDashboard / ReportForm

| # | Route | Expected | PASS/FAIL |
|---|---|---|---|
| 10.4.1 | `.remixFlow` | 부모 필터 카드 동적 표시 (`remix.parent.name`/`remix.parent.maker`) + "에디터 열기"가 draft를 `<parent> Remix` 이름과 remix 태그로 prefill |  |
| 10.4.2 | `.makerDashboard` | 통계 카드 표시 |  |
| 10.4.3 | `.reportForm` | 신고 입력 |  |

---

## 11. Profile / EditProfile / AccountDeletion / DataExport

### 11.1 ProfileScreen (own/other)

| # | Element | Expected | PASS/FAIL |
|---|---|---|---|
| 11.1.1 | (게스트) 로그인 CTA | navigateToLogin = true |  |
| 11.1.2 | (own) 톱니바퀴 (toolbar) | → AppRoute.settings |  |
| 11.1.3 | 필터 카운트 stat | 비인터랙티브 |  |
| 11.1.4 | 팔로워 stat | → AppRoute.followers(uid:) |  |
| 11.1.5 | 팔로잉 stat | → AppRoute.following(uid:) |  |
| 11.1.6 | 세그먼트 picker (내 필터/저장됨/촬영함) | 그리드 변경 |  |
| 11.1.7 | 그리드 타일 | → AppRoute.filterDetail |  |
| 11.1.8 | (other) 팔로우 버튼 | toggle |  |
| 11.1.9 | (other) 차단 버튼 | confirmation → block |  |

### 11.2 EditProfileScreen — `.editProfile`

| # | ID | Expected | PASS/FAIL |
|---|---|---|---|
| 11.2.1 | `profile.edit.avatar.change` | PhotosPicker → 선택 이미지를 512px 장변 JPEG로 normalize, avatar preview 갱신 |  |
| 11.2.2 | `profile.edit.handle.check` | 유저네임 중복 확인 (mock). UI 문구는 "핸들"이 아니라 "유저네임" |  |
| 11.2.3 | `profile.edit.save` | 저장 + dismiss |  |

### 11.3 AccountDeletionScreen — `.accountDeletion`

| # | ID | Expected | PASS/FAIL |
|---|---|---|---|
| 11.3.1 | `auth.delete.confirm.input` | 핸들 입력 시 submit enable |  |
| 11.3.2 | ⚠️ `auth.delete.submit` | 영구 삭제 확인 alert → `deleteAccount` Cloud Function 성공 후 receipt 표시 + signOut. 실패 시 alert |  |
| 11.3.3 | 핸들 안 맞을 때 submit 시도 | disabled |  |

### 11.4 DataExportScreen / NotificationSettingsScreen

| # | Element | Expected | PASS/FAIL |
|---|---|---|---|
| 11.4.1 | dataExport: "내보내기 요청" | mock 비동기 진행 |  |
| 11.4.2 | dataExport: 이전 요청 row | `/users/{uid}/exportRequests` listener 기반 상태 표시. `downloadURL`이 있으면 다운로드 버튼 표시 |  |
| 11.4.3 | notificationSettings: 시스템 알림 카드 | `UNUserNotificationCenter.notificationSettings()` 기준으로 허용됨/차단됨/권한 미결정 표시. 설정 앱에서 변경 후 복귀 시 자동 갱신 |  |
| 11.4.4 | notificationSettings: `notif.system.open` | iOS 앱 설정으로 이동 |  |
| 11.4.5 | notificationSettings: 카테고리별 토글 (소셜/리뷰/마켓/메이커/지갑/제품) | 사용자 입력에서만 `/users/{uid}/notificationPreferences/main` debounced save 예약. remote listener 반영은 재저장하지 않음 |  |
| 11.4.6 | notificationSettings: 방해 금지 시간 | 시작/종료 버튼 탭 시 다음 시간으로 변경되고 debounced save 예약 |  |

---

## 12. Settings

`AppRoute.settings`. 프로필 카드부터 하단까지 순서대로.

| # | Element | Expected | PASS/FAIL |
|---|---|---|---|
| 12.1 | 프로필 카드 | → AppRoute.editProfile |  |
| 12.2 | 프로필 정보 row | → AppRoute.editProfile |  |
| 12.3 | 결제 및 구독 row | → AppRoute.wallet |  |
| 12.4 | 개인정보 및 보안 row | → AppRoute.dataExport |  |
| 12.5 | 기본 비율 picker | defaultAspectRatio 변경 |  |
| 12.6 | 그리드 토글 | showGrid 변경 (카메라 다음 진입에서 반영) |  |
| 12.7 | 셔터음 토글 | shutterSound 변경 |  |
| 12.8 | 원본 저장 토글 | saveOriginal 변경 |  |
| 12.9 | 푸시 알림 row | → AppRoute.notificationSettings |  |
| 12.10 | 다운로드 관리 row | → AppRoute.savedFilters |  |
| 12.11 | 민감 콘텐츠 picker | sensitiveFilter (off/soft/strong) |  |
| 12.12 | 차단 사용자 row | → AppRoute.blockList |  |
| 12.13 | 도움말 row (`settings.nav.도움말`) | → AppRoute.helpCenter |  |
| 12.14 | 이용약관 row (`settings.row.이용약관`) | SafariView로 https://moodit.app/terms |  |
| 12.15 | 개인정보처리방침 row (`settings.row.개인정보처리방침`) | SafariView로 https://moodit.app/privacy |  |
| 12.16 | 버전 row | 비인터랙티브 |  |
| 12.17 | 모더레이션 큐 (admin/moderator only — `settings.admin.section` 안에 표시) | → AppRoute.modQueue. 일반 유저는 운영 섹션 자체가 안 보임. |  |
| 12.18 | 공유 링크 테스트 (admin/moderator only) | → AppRoute.universalLinkLanding |  |
| 12.19 | ⚠️ 로그아웃 | alert 표시, 확인 시 `Auth.auth().signOut()` + `isAuthenticated = false` + dismiss |  |
| 12.20 | ⚠️ 계정 삭제 | → AppRoute.accountDeletion |  |

---

## 13. Notifications Inbox / Wallet / Pro

### 13.1 NotificationsInboxScreen — `.notifications`

| # | ID | Expected | PASS/FAIL |
|---|---|---|---|
| 13.1.1 | 카테고리 chip `notif.cat.all` | 전체 표시 |  |
| 13.1.2 | `notif.cat.likes` | 좋아요만 |  |
| 13.1.3 | `notif.cat.reviews` | 리뷰만 (renamed from `comments`) |  |
| 13.1.4 | `notif.cat.downloads` | 다운로드만 |  |
| 13.1.5 | `notif.cat.system` | 시스템만 |  |
| 13.1.6 | `notif.settings` (toolbar) | → AppRoute.notificationSettings |  |
| 13.1.7 | `notif.tap` row 탭 | markRead, 배경 변화 |  |
| 13.1.8 | row 좌측 아이콘 | item.gradient 표시 |  |
| 13.1.9 | review/like/download 알림 우측 thumb | → AppRoute.filterDetail |  |
| 13.1.10 | followRequest 알림 | "팔로우" 버튼 → root `follows/{currentUid}_{actorUid}` write 성공 후 markRead. 실패 시 alert |  |
| 13.1.11 | 빈 상태 | "알림이 없어요" |  |
| 13.1.12 | 100건 초과 알림 | `notif.loadMore`로 다음 페이지 fetch, 중복 없이 이전 알림 추가 |  |
| 13.1.13 | 시간 라벨 | 앱을 오래 켜둬도 `createdAt` 기준으로 분/시간/일 라벨과 그룹 재계산 |  |
| 13.1.14 | 앱 badge | unread count 기준으로 badge count 갱신 |  |
| 13.1.15 | Foreground push | `kind`별 notificationPreferences 카테고리와 quiet hours를 존중. 차단된 카테고리/quiet hours 중에는 badge만 허용 |  |
| 13.1.16 | 신규 로그인 직후 FCM 등록 | 로그인 전 FCM token이 먼저 도착해도 로그인 후 `/users/{uid}/devices/{deviceId}` upsert 재시도 |  |

### 13.2 Wallet / Pro / Payment

| # | Route | Element | Expected | PASS/FAIL |
|---|---|---|---|---|
| 13.2.1 | `.wallet` | 잔액 카드 | 표시 only |  |
| 13.2.2 | `.wallet` | 충전하기 | → walletTopup |  |
| 13.2.3 | `.wallet` | 거래내역 | → walletTransactions |  |
| 13.2.4 | `.wallet` | Pro 구독 | → proSubscription |  |
| 13.2.5 | `.wallet` | 메이커 출금 진입점 | ❌ 제거됨 (ADR-0006 closed-loop) — wallet primary actions에 노출 안 됨 |  |
| 13.2.6 | `.walletTopup` | `wallet.topup.package.com.jayl2kor.moodit.coins.100` | 100C StoreKit purchase (sandbox/local StoreKit config 필요) |  |
| 13.2.7 | `.walletTopup` | `wallet.topup.package.com.jayl2kor.moodit.coins.550` | 550C StoreKit purchase (sandbox/local StoreKit config 필요) |  |
| 13.2.8 | `.walletTopup` | `wallet.topup.package.com.jayl2kor.moodit.coins.1200` | 1200C StoreKit purchase (sandbox/local StoreKit config 필요) |  |
| 13.2.9 | `.walletTopup` | `wallet.topup.package.com.jayl2kor.moodit.coins.3000` | 3000C StoreKit purchase (sandbox/local StoreKit config 필요) |  |
| 13.2.10 | `.walletTopup` | `wallet.topup.restore` | StoreKit restore purchase (sandbox/local StoreKit config 필요) |  |
| 13.2.11 | `.walletTopup` | `wallet.topup.failed_demo` | → paymentFailed |  |
| 13.2.11b | `.walletTopup` | 결제 성공 직후 잔액 | optimistic balance 표시 후 Firestore listener 또는 10초 fallback reload로 `/users/{uid}/wallet/balance.value`와 일치 |  |
| 13.2.12 | `.proSubscription` | `pro.plan.toggle` | 월간/연간 가격 표시 변경 |  |
| 13.2.13 | `.proSubscription` | `pro.subscribe.com.jayl2kor.moodit.pro.monthly` | 월간 Pro StoreKit subscription (sandbox/local StoreKit config 필요) |  |
| 13.2.14 | `.proSubscription` | `pro.subscribe.com.jayl2kor.moodit.pro.yearly` | 연간 Pro StoreKit subscription (sandbox/local StoreKit config 필요) |  |
| 13.2.15 | `.proSubscription` | `pro.invoice` | → refundRequest |  |
| 13.2.16 | `.paymentFailed` | `wallet.topup.retry` | → walletTopup |  |
| 13.2.17 | `.paymentFailed` | `payment.failed.restore` | StoreKit restore purchase (sandbox/local StoreKit config 필요) |  |
| 13.2.18 | `.paymentFailed` | `wallet.topup.support` | mailto 고객지원 열림 |  |
| 13.2.19 | `.refundRequest` | 환불 입력 | mock 제출 |  |
| 13.2.20 | `.insufficientBalance(filterId:)` | 충전하기 → walletTopup |  |
| 13.2.21 | `.payoutOnboarding` | Closed-loop placeholder (`payout.placeholder.정산 연결`) — "추후 지원 예정" + 적립 코인 사용처 안내. ADR-0006 정책. |  |
| 13.2.22 | `.payoutTaxInfo` | Closed-loop placeholder (`payout.placeholder.세금 정보`) — 출금 미지원으로 세금 폼 불필요 |  |
| 13.2.23 | `.payoutHistory` | 정산 내역 | mock 표시 |  |
| 13.2.24 | `.earningsWithdraw` | Closed-loop placeholder (`payout.placeholder.출금 신청`) — Phase 6+ 후보 |  |

### 13.3 Moderation (Admin only) / Reports

| # | Route | Element | Expected | PASS/FAIL |
|---|---|---|---|---|
| 13.3.1 | `.modQueue` | 큐 필터 메뉴 | 상태별 필터 |  |
| 13.3.2 | `.modQueue` | 큐 row | → modDetail(id:) |  |
| 13.3.3 | `.modDetail` | 승인 button | mock approve |  |
| 13.3.4 | `.modDetail` | 거부 button | → filterRejected(id:) |  |
| 13.3.5 | `.modDetail` | 게시 중단 | confirmation → takedown |  |
| 13.3.6 | `.blockList` | 세그먼트 (차단/뮤트) | 리스트 변경 |  |
| 13.3.7 | `.blockList` | 차단 해제 | row 제거 |  |
| 13.3.8 | `.reportForm` | 사유 picker | NSFW/저작권/스팸/폭력/기타 |  |
| 13.3.9 | `.reportForm` | 제출 | mock + dismiss |  |
| 13.3.10 | `.filterRejected(id:)` | 고객지원 (?) | mailto:support@moodit.app |  |
| 13.3.11 | `.filterRejected(id:)` | 거부 사유 list | 표시 only |  |
| 13.3.12 | `.filterRejected(id:)` | 검수 결과 확인 | 모달 |  |
| 13.3.13 | `.filterRejected(id:)` | 에디터 수정 | → editor |  |
| 13.3.14 | `.filterRejected(id:)` | 이의 제기 | external link |  |
| 13.3.15 | `.filterRejected(id:)` | 상세로 돌아가기 | → filterDetail(id:) |  |

---

## 14. Cross-cutting Flow Tests (시나리오)

각 시나리오는 하나의 사용자 여정을 검증. 위 §1~§13과 별개로 **end-to-end로** 한 번 더 돌리세요.

### 14.1 Guest → Signup → Apply (Phase 1 핵심)
1. 첫 실행 → 온보딩 4 → 로그인
2. "Apple로 계속하기" → 인증 → 마켓 진입
3. 마켓 카드 → FilterDetail
4. "무료 다운로드" → progress → completed
5. "촬영하기" → CameraScreen에 적용된 필터로 촬영
6. CapturePreview → "저장"
7. 사진 앱에서 사진 확인
- **PASS 기준**: 모든 단계가 1번 시도로 진행 / 7단계에서 사진이 정상 색감

### 14.2 Review End-to-End (Phase 3 reviews migration)
1. 로그인 → 필터 다운로드 (verified download 조건 충족)
2. FilterDetail → ★ 평점 등록 → 별 4개 → 본문 입력 → 평점 등록
3. FilterDetail로 돌아가서 → 리뷰 → ReviewsListScreen 진입
4. social.review.helpful 탭 → count +1
5. 다른 사용자 (Guest)로 재진입 → 같은 화면에서 helpful 다시 +1 (Firestore에선 두 번 못 누르지만 mock에선 toggle)
- **PASS 기준**: 본인 리뷰 작성 후 같은 (uid, filterId)로 두번째 리뷰 시도 안 됨

### 14.3 Maker Upload (Phase 2)
1. 로그인 → 에디터 진입
2. LUT import → bake 적용
3. uploadCover → uploadTags → uploadSubmit (TOS) → uploadPending
4. uploadPending → "내 필터 보기" → myFilters
5. (mock 거부 상태로 설정) → filterRejected 진입 시 거부 사유 표시
- **PASS 기준**: 모든 navigation 정상, mock 데이터로 끝까지

### 14.4 Push Notification (실기기 + Firebase Console)
1. 실기기 첫 실행, 알림 권한 수락
2. Xcode 콘솔에서 `[Push] Persisted FCM token for device <UUID>` 확인
3. Firestore Console → `users/{uid}/devices/{deviceId}` 문서 존재 확인
4. Firebase Console → Cloud Messaging → 테스트 메시지 → 토큰 붙여넣기 → 전송
5. iPhone 백그라운드 상태에서 알림 도착 확인
- **PASS 기준**: 5단계에서 lock screen / notification center에 알림 표시

### 14.5 Auth-Gated 동작 (게스트 차단 검증)
모든 게스트 차단 진입 — 게스트 상태에서 다음 기능 진입 시 항상 LoginScreen으로:
- 6.1.8 ReviewsList 리뷰 작성
- 6.2.12 ReviewCompose
- 6.3.7 RatingForm
- 5.13/5.14 FilterDetail의 평점/리뷰 CTAs
- 카메라 셔터 (?) — 정책에 따라 다름
- 업로드 시작 (?)
- **PASS 기준**: 게스트 클릭 → LoginScreen, "취소" 시 원래 화면 복귀

### 14.6 Universal Link (deep link)
1. Safari/메모/Slack 등에서 다음 URL 탭:
   - `moodit://filter/Sunset%201973` → FilterDetail 시트
   - `moodit://reviews/Sunset%201973` → ReviewsList 시트
   - `moodit://maker/jisoo.films` → ProfileScreen 시트
   - `moodit://search?q=warm&category=cinematic` → SearchScreen 시트 (initialQuery=warm)
   - `moodit://notifications` → NotificationsInbox 시트
   - `https://moodit.app/f/Sunset%201973` → FilterDetail (Universal Link)
2. 앱 진입 → `MooditStore.pendingDeepLinkRoute` 설정 → RootShell이 sheet로 destination 표시
- **PASS 기준**: 위 6개 URL 모두 적절한 화면으로 라우팅 (시트로). 시트 닫으면 원래 탭으로 돌아옴.
- **알 수 없는 URL** (`moodit://unknown`, `https://example.com/...`) → 시트 안 열림 (no-op).

### 14.7 Push 알림 deep-link 라우팅
1. Firebase Console에서 다음 페이로드의 푸시 전송:
   - `data: {kind: "review", filterId: "Sunset 1973"}` → 탭 시 ReviewsList 시트 열림
   - `data: {kind: "like", filterId: "Honey Glow"}` → 탭 시 FilterDetail 시트 열림
   - `data: {kind: "followRequest", actorUid: "u-emma"}` → 탭 시 ProfileScreen 시트 열림
   - `data: {kind: "system"}` → 탭 시 NotificationsInbox 시트 열림
2. 앱이 background/closed 상태에서 알림 탭 → 위 라우팅 동작
- **PASS 기준**: 모든 케이스가 적절한 시트로 라우팅. 알 수 없는 kind는 무시.
- **유닛 테스트**: AppTests/UniversalLinkParserTests 20/20 pass (`UniversalLinkParser.route(forPushUserInfo:)` 보장)

---

## 15. 버그 리포트 템플릿

```markdown
## Bug #N — [한 줄 요약]

**Reproduce steps**:
1.
2.
3.

**Expected**: <QA 문서 §X.Y의 expected 인용>
**Actual**: <실제 동작>
**Severity**: blocker / high / medium / low
**Build**: 52d2502 + Ralph (2026-05-07)
**Device**: iPhone XX, iOS XX
**Auth state**: guest / signed-in / admin
**Screenshot**: (있으면 첨부)
**Reference**: docs/QA_TEST_PLAN.md §X.Y
```

---

## 16. 알려진 BROKEN 항목 요약 (FAIL이 아니라 expected)

| 영역 | 미구현 / 부분 구현 |
|---|---|
| Auth | GoogleService-Info.plist 포함됨. Google/Apple external auth sheet와 credential exchange는 수동 QA 게이트; Email + Password ✅ FIXED; ToS/Privacy SafariView ✅ FIXED |
| Marketplace | 컬렉션 진입 wiring, pull-to-refresh, long-press |
| FilterDetail | Share sheet, 태그 점프, 유료 paywallSingle, sample gallery visual correctness/cache re-entry는 수동 확인 |
| Review compose | image ✅ FIXED in batch 3 (PHPicker); @ + emoji ✅ FIXED in batch 4 |
| Camera | 권한 거부 시 안내 화면 |
| Editor | reference PhotosPicker와 LUT Files picker는 진입점/렌더 경로 자동 검증 완료, 실제 OS picker 선택은 수동 QA |
| Upload | ✅ FIXED in batch 10 — R2 presigned PUT (lib/r2.ts) + uploadInit/Finalize Cloud Functions + iOS FilterPackageUploader. Signature sample UI와 `signatureSampleURL` 보존은 완료, 실제 signature image R2 upload wiring은 후속 이슈. |
| Wallet | StoreKit 상품 액션은 정의/노출됨. 실제 purchase/restore/cancel은 sandbox 또는 local `.storekit` config 필요; payout / Stripe Connect ❌ Won't fix in Phase 1~5 (ADR-0006 closed-loop currency) |
| Push | ✅ FIXED in batch 3 — `PushRegistration.userNotificationCenter(_:didReceive:)` → `UniversalLinkParser.route(forPushUserInfo:)` → `MooditStore.pendingDeepLinkRoute` |
| Moderation | admin claim 부트스트랩 ✅ FIXED in batch 8 (`tools/bootstrap-admin.mjs` + `setRole` Cloud Function + Settings role-claim visibility); ModerationQueueScreen 실 wiring은 별도 이슈 |
| Universal Link | ✅ FIXED in batch 3 — `UniversalLinkParser` + RootShell `.onOpenURL` + sheet 라우팅 (20/20 unit tests pass) |

이 항목들은 §16에 모인 대로 — **§1~§14에서 마주치면 PASS/FAIL이 아닌 🔴 BROKEN으로 마킹**하시면 됩니다.

---

## 17. 다음 라운드 (Ralph로 닫을 수 있는 것)

QA에서 **새로운** FAIL 발견 시:
- 회귀 (이전엔 동작했던 게 깨짐) → Ralph 재호출 시 우선순위 P0
- 신규 버그 (미구현이 아닌 wiring 잘못) → Ralph P1
- BROKEN 항목 → 자격증/인프라 닫히면 Ralph로 진행 (`§5.7 Push routing`, `§3.1 fetch wiring` 등)

---

## 18. QA 완료 기준

- [ ] §1 ~ §13 모든 행에 PASS / FAIL / 🔴 BROKEN 중 하나가 마킹
- [ ] §14의 6개 시나리오 모두 1회 이상 실행
- [ ] FAIL 항목 ≤ 5건 (회귀 0건 목표)
- [ ] 발견된 모든 FAIL이 §15 템플릿으로 `docs/QA_BUGS.md`에 정리
- [ ] PASS율 (PASS / (PASS + FAIL))가 80% 이상

PASS율이 80% 미만이면 다음 Ralph 세션은 *새 기능*이 아니라 *발견된 FAIL 수정*이 우선입니다.
