# Phase Roadmap Status

> Last updated: 2026-05-07 KST  
> Purpose: 제품 로드맵의 Phase 1~4와 현재 화면 구현 단위인 Phase A~D를 하나의 기준으로 통합한다.

## 1. Phase 체계

현재 문서에는 서로 다른 두 축의 Phase가 있다.

| 구분 | 의미 | 기준 문서 |
|---|---|---|
| Product Phase 1~4 | 출시/제품 완성도 기준의 장기 로드맵 | `docs/TASK_LIST.md`, `docs/README.md` |
| Implementation Phase A~D | 와이어프레임/목업 화면을 SwiftUI로 닫기 위한 실행 단위 | `docs/SCREEN_IMPLEMENTATION_BACKLOG.md` |

따라서 Phase A~D가 완료되어도 Product Phase 1~4가 완료되는 것은 아니다. 현재 A~D는 주로 화면, mock state, local flow, E2E smoke coverage를 닫는 작업이다. 실제 backend, repository, persistence, 실기기 성능, TestFlight 운영 조건은 Product Phase 완료 조건으로 별도 추적해야 한다.

## 2. 현재 요약

| 영역 | 현재 상태 |
|---|---|
| 최신 커밋 기준 | `f1e8429 Add design reinforcement assets and i18n groundwork` |
| 화면 구현 기준 | Phase A/B/C 완료, Phase D 전용 화면 및 E2E 구현 완료 상태 |
| 검증 기준 | `./scripts/build-for-testing.sh` 통과, `AppUITests/PhaseDE2ETests` 4개 통과 |
| 미커밋 상태 | Phase D 화면/E2E 변경과 별도 i18n/reviews 작업 변경이 함께 존재 |
| 주의 | i18n은 별도 에이전트 작업 중이므로 `Localizable.xcstrings`, `docs/I18N_MIGRATION.md`, `mockups/en/` 변경은 별도 흐름으로 취급 |

## 3. Product Phase 1~4 상태

| Product Phase | 원래 목표 | 현재 구현 수준 | 남은 핵심 작업 |
|---|---|---|---|
| Phase 1 | MVP: 카메라, 기본 필터, 저장, 기본 마켓, 다운로드, TestFlight Closed Beta | 화면과 local mock flow는 상당 부분 구현됨. Phase A가 카메라/다운로드/사진 편집 루프를 E2E로 검증함 | 실기기 FPS/thermal 검증, 실제 다운로드/cache package, Firestore/R2/Cloud Functions 연동, Auth 실제 연동, TestFlight/운영 준비 |
| Phase 2 | 필터 에디터: LUT + 파라미터, 메이커 업로드 | Phase C에서 editor/upload/my filters/remix 화면과 mock state 구현 완료 | 실제 LUT/.cube import, renderer preview sync, draft repository, `.fmpkg` package builder, cover picker, upload job API, moderation API |
| Phase 3 | 인증/마켓 강화: 프로필, 검색, 평점, 댓글, 팔로우, 소셜, 알림 | Phase B와 Phase D로 계정/정책/소셜 화면 구현. 댓글/평점/팔로우/For You/Following feed E2E 통과 | social repository/API, follow/comment/rating persistence, search backend, notification permission/push resolver, Universal Link payload parser |
| Phase 4 | 추천 + 검색 고도화 + Android 진출 게이트 | For You/Following feed mock 화면은 존재하지만 실제 추천/검색 고도화는 미착수 | Algolia/Typesense 결정 및 연동, recommendation event log, BigQuery export, personalization, Android 진출 ADR |

## 4. Implementation Phase A~D 상태

| Implementation Phase | 범위 | 상태 | 검증 |
|---|---|---|---|
| Phase A | Camera/Download MVP closure: 카메라 HUD, 비율/타이머, 사진 가져오기/편집, 내장 필터, 다운로드 후 적용 | 완료, 커밋됨: `d8e1c3e` | `AppUITests/PhaseAE2ETests` 5개, `./scripts/test.sh` 통과 기록 |
| Phase B | Account/Profile policy screens: 계정 삭제, 프로필 편집, Universal Link landing, 데이터 내보내기, 알림 설정 | 완료, 커밋됨: `3a3cc67` | `./scripts/test.sh` 통과 기록 |
| Phase C | Maker supply flow: 에디터, 파라미터, LUT import shell, draft, upload flow, pending/rejected/my filters/remix | 완료, 커밋됨: `dfb1560` | `./scripts/test.sh` 통과 기록 |
| Phase D | Social and discovery: 댓글/댓글 작성, 평점, 팔로워/팔로잉, For You, Following feed, 알림/즐겨찾기 유지 | 화면 구현 및 E2E 완료, 아직 미커밋 | `AppUITests/PhaseDE2ETests` 4개 통과 |

## 5. 이번 Phase D 작업 내용

이번 미커밋 작업에는 다음이 포함된다.

| 파일/영역 | 내용 |
|---|---|
| `Sources/App/Social/SocialDiscoveryScreens.swift` | 댓글 목록, 댓글 작성, 평점, 팔로워/팔로잉, For You, Following feed 전용 SwiftUI 화면 구현 |
| `Sources/App/WorkflowScreens.swift` | 기존 Phase D placeholder 제거, `PhotoImportScreen` actor 경고 정리 |
| `Sources/App/MooditApp.swift` | UI 테스트 전용 Phase D launch route 추가 |
| `Tests/AppUITests/PhaseDE2ETests.swift` | Phase D E2E 4개 시나리오 추가 |
| `docs/SCREEN_IMPLEMENTATION_BACKLOG.md` | Phase D 다운로드 수 표시 및 E2E 통과 기록 |
| `moodit.xcodeproj/project.pbxproj` | XcodeGen 재생성으로 신규 소스/테스트 포함 |

Phase D E2E 커버리지:

| 테스트 | 검증 내용 |
|---|---|
| `testCommentsListSignedInComposeAndRatingEntry` | 로그인 상태 댓글 목록, 좋아요, 댓글 작성, 평점 입력 |
| `testSocialWriteActionsRouteGuestsToLogin` | guest 상태 댓글/평점 작성 시 로그인 유도 |
| `testFollowListsSearchSegmentAndToggle` | 팔로워/팔로잉 목록, 검색, 팔로우 토글 |
| `testDiscoveryFeedsExposeDownloadCountsAndSocialActions` | For You/Following feed, 다운로드 수 표시, 좋아요/저장/댓글 이동 |

## 6. 남은 작업 통합 목록

### 6.1 바로 해야 할 일

| 우선순위 | 작업 | 이유 |
|---|---|---|
| P0 | Phase D 변경사항 커밋 범위 분리 | 현재 i18n/reviews 별도 작업과 Phase D 작업이 같은 working tree에 섞여 있음 |
| P0 | 전체 테스트 스위트 재실행 | Phase D 단독 E2E는 통과했지만 전체 회귀는 아직 재검증 전 |
| P1 | `docs/SCREEN_IMPLEMENTATION_BACKLOG.md`의 Phase D 상태를 "완료"로 격상할지 결정 | 화면/E2E 기준으로는 완료에 가까우나 실제 repository/API는 남아 있음 |
| P1 | 실제 repository/API 통합 계획 문서화 | Product Phase 완료 조건과 화면 구현 완료 조건을 분리해야 함 |

### 6.2 Product Phase 1 closure

| 작업 | 상태 |
|---|---|
| 카메라/다운로드/사진 편집 핵심 화면 | 화면 및 E2E 완료 |
| 실제 필터 package 다운로드/cache | 미완료 |
| 실기기 FPS/thermal 측정 | 미완료 |
| Firestore/R2/Cloud Functions `/filters/use` | scaffold 또는 문서 수준, 실제 통합 필요 |
| Auth 실제 Sign in with Apple/Google | UI 존재, 실제 인증 flow 추가 필요 |
| TestFlight External Beta 준비 | 미완료 |

### 6.3 Product Phase 2 closure

| 작업 | 상태 |
|---|---|
| 에디터/upload 화면 | Phase C에서 mock flow 완료 |
| `.cube` parser / LUT bake | 미완료 |
| renderer preview sync | 미완료 |
| `.fmpkg` packaging | 미완료 |
| draft/upload repository | 미완료 |
| upload job API / moderation API | 미완료 |

### 6.4 Product Phase 3 closure

| 작업 | 상태 |
|---|---|
| 프로필/계정 정책 화면 | Phase B에서 완료 |
| 댓글/평점/팔로우/피드 화면 | Phase D에서 화면 및 E2E 완료 |
| comment/rating/follow persistence | 미완료 |
| social repository/API | 미완료 |
| 검색 backend / 정렬 | 미완료 |
| APNs/FCM push, notification resolver | 미완료 |
| Universal Link payload parser | 미완료 |

### 6.5 Product Phase 4 준비

| 작업 | 상태 |
|---|---|
| For You mock 화면 | Phase D에서 구현 |
| 실제 recommendation backend | 미착수 |
| Algolia/Typesense 선택 및 인덱서 | 미착수 |
| 이벤트 로그/BigQuery export | 미착수 |
| personalization/co-occurrence 추천 | 미착수 |
| Android 진출 ADR | 미착수 |

## 7. 다음 실행 순서 제안

1. Phase D 변경만 선별 커밋한다.
2. `./scripts/test.sh`로 전체 회귀 테스트를 돌린다.
3. Phase D를 화면/E2E 기준 완료로 표시하고, API/persistence는 Product Phase 3 통합 backlog로 이동한다.
4. Product Phase 1 closure checklist를 먼저 닫는다. 실제 베타 출시 가능성을 만들려면 카메라/다운로드/저장/마켓의 실제 data path가 우선이다.
5. 그 다음 Product Phase 3의 social repository를 붙인다. 현재 Phase D 화면이 있으므로 API 계약을 붙이기 좋은 상태다.
6. Product Phase 2의 실제 editor engine과 upload pipeline은 renderer/package/API가 얽혀 있어 별도 스프린트로 분리한다.
7. Product Phase 4는 For You UI를 유지한 채, 검색/추천 backend 의사결정 문서와 ADR부터 시작한다.

## 8. 검증 로그

최근 확인된 명령:

```sh
./scripts/build-for-testing.sh
```

결과: `TEST BUILD SUCCEEDED`

```sh
xcodebuild -project moodit.xcodeproj -scheme moodit -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' -derivedDataPath .build/DerivedData -toolchain com.apple.dt.toolchain.Metal.32023.864 -only-testing:AppUITests/PhaseDE2ETests test
```

결과: `Executed 4 tests, with 0 failures`

전체 `./scripts/test.sh`는 Phase D E2E 추가 후 아직 다시 실행하지 않았다.
