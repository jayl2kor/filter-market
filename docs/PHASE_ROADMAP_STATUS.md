# moodit Phase Plan

> Last updated: 2026-05-07 KST  
> 기준 커밋: `52d2502 Add reviews migration and English mockups`  
> 이 문서는 앞으로의 단일 진행 기준을 **Product Phase 1~4**로 고정한다.

## 1. 단일 기준

앞으로 프로젝트 진행 상태는 **Phase 1, Phase 2, Phase 3, Phase 4**를 기준으로 판단한다.

기존에 사용했던 `Phase A/B/C/D/E/F` 표현은 제품 Phase가 아니다. 이는 화면 구현을 빠르게 묶기 위해 임시로 썼던 실행 단위였으므로, 이 문서에서는 모두 **UI Work Package**로 재분류한다.

| 이전 표현 | 새 분류 | 의미 |
|---|---|---|
| Phase A | UI Package 1-A | Phase 1에 속한 카메라/다운로드 화면 묶음 |
| Phase B | UI Package 3-A | Phase 3에 속한 계정/정책 화면 묶음 |
| Phase C | UI Package 2-A | Phase 2에 속한 메이커/에디터 화면 묶음 |
| Phase D | UI Package 3-B / 4-A | Phase 3 소셜 화면 + Phase 4 추천 feed mock |
| Phase E | UI Package 5-A | Phase 5 후보. 현재 Phase 1~4 기준 밖 |
| Phase F | UI Package 6-A | Phase 6 후보. 현재 Phase 1~4 기준 밖 |

상태 표기:

| 상태 | 의미 |
|---|---|
| Done | 현재 범위 기준 완료 |
| In Progress | 일부 완료, 남은 핵심 작업 있음 |
| Not Started | 아직 본격 구현 전 |
| Later | Phase 1~4 이후 후보 |

## 2. 현재 결론

| Product Phase | 현재 상태 | 판단 |
|---|---|---|
| Phase 1 | In Progress | UI/local E2E는 많이 진행됐지만 실제 다운로드/API/실기기/TestFlight가 남음 |
| Phase 2 | In Progress | 에디터/업로드 UI는 완료됐지만 실제 LUT/parser/package/upload가 남음 |
| Phase 3 | In Progress | 계정/소셜/리뷰 관련 UI는 많이 진행됐지만 persistence/API/search/push가 남음 |
| Phase 4 | Not Started | For You mock UI만 존재. 추천/검색 고도화/Android gate는 미착수 |

즉, 지금까지 화면 작업은 많이 진행됐지만 **Product Phase 1~4 중 완료된 Phase는 아직 없다.**

## 3. Phase 1 — MVP Camera / Filters / Market Download

목표:
- 사용자가 필터를 찾는다.
- 필터를 다운로드한다.
- 카메라 또는 사진 편집에서 적용한다.
- MVP 수준의 기본 마켓과 저장 흐름을 갖춘다.

### 3.1 진행된 작업

| 영역 | 상태 | 근거 |
|---|---|---|
| 카메라 HUD | Done | `CameraScreen`, grid/zoom/flash/aspect/timer UI |
| 카메라 비율/타이머 설정 | Done | `CameraAspectPickerScreen`, `CameraTimerCountdownScreen` |
| 사진 가져오기/편집 | Done | `PhotoImportScreen`, `PhotoEditScreen` |
| 내장 필터 라이브러리 | Done | `BuiltinFilterLibraryScreen` |
| 다운로드 진행/완료 후 적용 | Done for local flow | `FilterDownloadProgressScreen`, `FilterAfterDownloadScreen` |
| 마켓 → 다운로드 → 적용 → 카메라 E2E | Done | `AppUITests/PhaseAE2ETests` 5개 통과 기록 |

관련 커밋:
- `d8e1c3e Complete Phase A camera workflows with E2E coverage`
- `57b2997 Implement filter download completion flow`

### 3.2 남은 작업

| 우선순위 | 작업 | 완료 조건 |
|---|---|---|
| P0 | 실제 `.fmpkg` 다운로드/cache 경로 | mock이 아닌 package fetch/cache/apply path 동작 |
| P0 | 실제 필터 파일 적용 | 다운로드한 필터가 카메라/사진 편집 렌더러와 연결 |
| P0 | 실기기 FPS/thermal 검증 | 기준 기기에서 목표 FPS와 발열 확인 |
| P1 | Firestore/R2/Cloud Functions `/filters/use` | 다운로드/사용 카운터 실제 persistence |
| P1 | 실제 Auth 연결 | Apple/Google sign-in 및 guest branch 정리 |
| P1 | Photo save/share 권한 edge case | 저장/공유 성공/실패 상태 처리 |
| P2 | TestFlight 준비 | App Store Connect, privacy, beta checklist |

### 3.3 Phase 1 완료 기준

- 실제 package 다운로드와 cache가 동작한다.
- 카메라/사진 편집에서 실제 다운로드 필터가 적용된다.
- 실기기 성능 기준을 만족한다.
- 핵심 E2E가 전체 테스트 스위트에서 안정적으로 통과한다.
- TestFlight beta 준비 조건이 충족된다.

## 4. Phase 2 — Filter Editor / Maker Upload

목표:
- 메이커가 필터를 만든다.
- LUT/파라미터 기반으로 미리본다.
- 초안 저장 후 업로드/검수 흐름으로 넘긴다.

### 4.1 진행된 작업

| 영역 | 상태 | 근거 |
|---|---|---|
| 에디터 화면 | Done for UI/mock | `FilterEditorScreen`, parameter/LUT/import 관련 화면 |
| 업로드 flow | Done for UI/mock | cover, category/tags, TOS submit, pending |
| 내 필터/거절/리믹스 화면 | Done for UI/mock | my filters, rejected, remix flow |
| mock state | Done | `MakerFilterDraft`, `UploadStep`, `MakerFilterStatus` |
| Reviews migration design | Done for docs/mockups | `REVIEWS_MIGRATION.md`, review mockups, `reviews.*` keys |

관련 커밋:
- `dfb1560 Complete Phase C maker supply flow`
- `52d2502 Add reviews migration and English mockups`

### 4.2 남은 작업

| 우선순위 | 작업 | 완료 조건 |
|---|---|---|
| P0 | `.cube` parser | LUT 파일을 안정적으로 파싱 |
| P0 | LUT bake / parameter bake | 파라미터 결과를 결정론적으로 렌더링 |
| P0 | renderer preview sync | 에디터 미리보기와 실제 적용 결과 일치 |
| P1 | `.fmpkg` packaging / manifest builder | 생성/검증/저장 가능한 package |
| P1 | draft repository | 초안 저장/복구 persistence |
| P1 | upload job API | 업로드 진행률/재개/실패 처리 |
| P2 | cover picker / preview generation | thumb/before/after 생성 |
| P2 | moderation API 연결 | pending/rejected 상태 실제화 |

### 4.3 Phase 2 완료 기준

- 메이커가 실제 LUT/파라미터 기반 필터를 만들 수 있다.
- preview와 실제 적용 결과가 일치한다.
- `.fmpkg`가 생성되고 검증된다.
- 초안 저장과 업로드가 실제 repository/API에 연결된다.

## 5. Phase 3 — Auth / Market Enhancement / Reviews / Social

목표:
- 사용자 계정과 프로필을 관리한다.
- 검색, 리뷰, 팔로우, 알림 등 마켓 신뢰/소셜 기능을 강화한다.
- 자유 댓글 중심이 아니라 리뷰 중심으로 전환한다.

### 5.1 진행된 작업

| 영역 | 상태 | 근거 |
|---|---|---|
| 계정 삭제 | Done for UI/mock | `AccountDeletionScreen` |
| 프로필 편집 | Done for UI/mock | `EditProfileScreen` |
| Universal Link landing | Done for UI/mock | `UniversalLinkLandingScreen` |
| 데이터 내보내기 | Done for UI/mock | `DataExportScreen` |
| 알림 설정 | Done for UI/mock | `NotificationSettingsScreen` |
| 댓글/평점/팔로우/피드 화면 | Done for UI/E2E | `SocialDiscoveryScreens.swift` |
| Phase 3 소셜 E2E | Done | `AppUITests/PhaseDE2ETests` 4개 통과 |
| 다운로드 수 표시 | Done for mock | 댓글 상단/For You/Following feed에 count 표시 |
| Reviews migration docs | Done for design | comments → reviews 정책 문서/키/mockups |

관련 커밋:
- `3a3cc67 Complete Phase B account policy screens`
- `b8fadc4 Complete Phase D social discovery flow`
- `52d2502 Add reviews migration and English mockups`

### 5.2 남은 작업

| 우선순위 | 작업 | 완료 조건 |
|---|---|---|
| P0 | 전체 회귀 테스트 재실행 | `./scripts/test.sh` 통과 |
| P0 | Comments → Reviews Swift 전환 | route/screen/notification naming이 reviews 기준으로 정리 |
| P0 | social repository/API | follow/review/rating/feed 데이터가 실제 source와 연결 |
| P1 | review persistence | 1인 1리뷰, verified download, maker reply 저장 |
| P1 | follow/block state persistence | 팔로우/차단 상태가 실제 사용자 기준 유지 |
| P1 | 검색 backend | prefix/category/tag/정렬 동작 |
| P1 | notification resolver/push | APNs/FCM/알림 row route 연결 |
| P2 | Universal Link payload parser | 공유 링크 payload 기반 route/apply |
| P2 | profile API | 프로필 편집/조회 persistence |

### 5.3 Phase 3 완료 기준

- 리뷰/팔로우/알림/검색이 실제 API와 연결된다.
- Comments 기반 UX가 Reviews 기반 UX로 전환된다.
- 계정/프로필/데이터/알림 정책 화면이 실제 persistence와 연결된다.
- 핵심 E2E가 전체 테스트에서 안정적으로 통과한다.

## 6. Phase 4 — Recommendation / Search Advanced / Android Gate

목표:
- 개인화 추천과 고도화 검색을 도입한다.
- Android 진출 여부를 정량/정성 지표로 결정한다.

### 6.1 진행된 작업

| 영역 | 상태 | 근거 |
|---|---|---|
| For You 화면 | Done for mock UI | `ForYouFeedScreen` |
| Following feed 화면 | Done for mock UI | `FollowingFeedScreen` |
| 추천 카드 다운로드 수 표시 | Done for mock UI | For You hero/rail, Following post badge |

관련 커밋:
- `b8fadc4 Complete Phase D social discovery flow`

### 6.2 남은 작업

| 우선순위 | 작업 | 완료 조건 |
|---|---|---|
| P0 | 검색/추천 기술 선택 | Algolia vs Typesense 등 ADR 작성 |
| P0 | 이벤트 로그 설계 | recommendation/download/search event schema |
| P1 | 검색 인덱서 worker | filter/user/tag index sync |
| P1 | 추천 v1 | 인기 + 최신성 가중 추천 |
| P1 | 추천 v2 | co-occurrence / item-item 추천 |
| P1 | For You backend 연결 | mock이 아닌 추천 결과 표시 |
| P2 | BigQuery export | 분석/추천 학습용 export |
| P2 | Android 진출 ADR | Kotlin/Compose MP/iOS only 결정 |

### 6.3 Phase 4 완료 기준

- 검색 p95와 추천 CTR 목표를 측정할 수 있다.
- For You feed가 실제 추천 결과를 사용한다.
- Android 진출 여부가 ADR로 결정된다.

## 7. Phase 1~4 외부 후보

아래 항목은 중요하지만 현재 단일 기준인 Phase 1~4 밖이다.

| 후보 | 기존 표현 | 상태 | 비고 |
|---|---|---|---|
| Safety/moderation | Phase E | Later | Product Phase 5에 해당. 신고/차단/모더레이션 큐 |
| Monetization | Phase F | Later | Product Phase 6에 해당. wallet/paywall/payout/refund |

## 8. 현재까지 완료된 커밋

| 커밋 | 내용 | 주 기준 Phase |
|---|---|---|
| `d8e1c3e` | camera workflows with E2E coverage | Phase 1 |
| `3a3cc67` | account policy screens | Phase 3 |
| `dfb1560` | maker supply flow | Phase 2 |
| `f1e8429` | design reinforcement assets and i18n groundwork | 공통 |
| `b8fadc4` | social discovery flow | Phase 3 / Phase 4 mock |
| `52d2502` | reviews migration and English mockups | Phase 2 / Phase 3 |

## 9. 다음 실행 순서

Phase 1~4 기준으로 다음 순서를 권장한다.

1. 전체 회귀 테스트 실행: `./scripts/test.sh`.
2. Phase 3의 Comments → Reviews Swift 전환 범위를 확정한다.
3. Phase 1의 실제 download package/cache path를 구현한다.
4. Phase 1 실기기 성능 측정 계획을 실행한다.
5. Phase 3 social/review repository/API 계약을 작성한다.
6. Phase 2 editor engine 작업을 `.cube parser → LUT bake → package builder → upload API` 순서로 진행한다.
7. Phase 4 검색/추천 기술 ADR을 작성한다.

이유:
- 화면 구현은 많이 닫혔으므로 이제 Product Phase 완료 조건인 실제 data path/API/성능 검증으로 전환해야 한다.
- TestFlight 가능성을 만들려면 Phase 1의 실제 다운로드/적용 경로가 가장 먼저 닫혀야 한다.
- Reviews migration은 문서와 mockup이 먼저 들어왔으므로 Swift 코드 전환을 빠르게 마무리해야 Phase 3 용어가 정리된다.

## 10. 바로 열 이슈 후보

| 우선순위 | 이슈 | 기준 Phase |
|---|---|---|
| P0 | 전체 회귀 테스트 재실행 및 실패 수정 | 공통 |
| P0 | 실제 `.fmpkg` 다운로드/cache/apply path 구현 | Phase 1 |
| P0 | Comments → Reviews Swift route/screen migration | Phase 3 |
| P0 | 실기기 카메라/Metal FPS 측정 | Phase 1 |
| P1 | social/review repository/API 설계 | Phase 3 |
| P1 | `.cube` parser + LUT bake 구현 | Phase 2 |
| P1 | `.fmpkg` package builder 구현 | Phase 2 |
| P2 | 검색/추천 기술 ADR | Phase 4 |
| P2 | Android 진출 ADR 초안 | Phase 4 |

## 11. 검증 로그

최근 확인된 명령:

```sh
./scripts/build-for-testing.sh
```

결과:

```text
TEST BUILD SUCCEEDED
```

```sh
xcodebuild -project moodit.xcodeproj -scheme moodit -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' -derivedDataPath .build/DerivedData -toolchain com.apple.dt.toolchain.Metal.32023.864 -only-testing:AppUITests/PhaseDE2ETests test
```

결과:

```text
Executed 4 tests, with 0 failures
```

전체 `./scripts/test.sh`는 social discovery UI 작업 이후 다시 실행해야 한다.

```sh
./scripts/test.sh
```

결과 (2026-05-07 03:42 KST, 기준 커밋 `52d2502`):

```text
ModelsTests.xctest       passed
CameraTests.xctest       passed
FilterEngineTests        Executed 21 tests, with 0 failures
MarketplaceTests         Executed  4 tests, with 0 failures
AppUITests (PhaseAE2E + PhaseDE2E)  Executed 9 tests, with 0 failures
** TEST SUCCEEDED **
```

전체 로그: `.omc/logs/test-baseline-2026-05-07.log`.

이후 Reviews migration + Editor engine 코어 + Filter package fetch/cache + repository protocols 추가 후 재실행:

```sh
./scripts/test.sh
```

결과 (2026-05-07 11:15 KST):

```text
ModelsTests.xctest       passed
CameraTests.xctest       Executed 13 tests, with 0 failures
FilterEngineTests        Executed 53 tests, with 0 failures   (CubeLUTParser 9 + LUTBake 8 + LUTBakeRenderParity 4 + Fmpkg 7 + 기존 25)
MarketplaceTests         Executed 34 tests, with 0 failures   (BundleSeed 4 + ReviewStore 12 + SocialRepositories 9 + FilterPackage 9)
AppUITests (PhaseAE2E + PhaseDE2E)  Executed 9 tests, with 0 failures
** TEST SUCCEEDED **
```

추가 검증 (Cloud Functions + Firestore rules emulator):

```sh
cd functions && npm test       # Node 20 in-memory mock — 6/6 pass (applyRecordUse)
cd functions && npm run test:rules  # firebase emulators:exec — 11/11 pass (reviews/follows/blocks/notifications)
```

전체 로그: `.omc/logs/test-final-2026-05-07.log`.
