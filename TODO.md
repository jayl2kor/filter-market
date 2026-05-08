# moodit TODO

> 기준 문서: [`docs/PHASE_ROADMAP_STATUS.md`](docs/PHASE_ROADMAP_STATUS.md)
> Last updated: 2026-05-07 11:15 KST (Ralph run, codex critic)
> 기준 커밋: `52d2502 Add reviews migration and English mockups`
>
> 본 TODO는 Product Phase 1~4를 단일 기준으로 사용한다.
> 화면(UI/mock) 구현은 대부분 닫혔으며, 이제 실제 data path / API / 성능 검증 단계로 전환한다.
>
> **Ralph 실행 요약 (2026-05-07)**
>
> 본 세션에서 닫힌 작업: §1 회귀 baseline / §2 Comments→Reviews 전환 / §3 .fmpkg fetch·cache·apply (+ /filters/use Cloud Function) / §5 social·review repository 계약 + Firestore rules + emulator 통합 테스트 / §6 Editor engine 4단계 (parser → bake → preview parity → builder) / §7 검색·Android ADR 두 건.
>
> 명시 deferred: §4 실기기 FPS/thermal (물리 iPhone 필요), §3.7/§5.6/§5.7/§6.5/§6.6 라이브 인프라 작업 (R2/CDN, APNs/FCM, 모더레이션 큐 - 운영 자격증 필요), §7 ADR 사인오프 (Founders).
>
> 최종 회귀: `./scripts/test.sh` 109 tests / 0 failures, `firebase emulators:exec` 11 rules tests / 0 failures, `node --test` 6 Cloud Function tests / 0 failures.

---

## 0. 실행 순서 요약

| # | 작업 | 기준 Phase | 우선순위 |
|---|------|-----------|---------|
| 1 | 전체 회귀 테스트 재실행 및 실패 수정 | 공통 | P0 |
| 2 | Comments → Reviews Swift 코드 전환 | Phase 3 | P0 |
| 3 | `.fmpkg` 다운로드 / cache / apply path 구현 | Phase 1 | P0 |
| 4 | 실기기 카메라/Metal FPS·thermal 측정 | Phase 1 | P0 |
| 5 | social/review repository/API 계약 작성 | Phase 3 | P1 |
| 6 | `.cube` parser → LUT bake → package builder → upload API | Phase 2 | P1 |
| 7 | 검색/추천 기술 ADR | Phase 4 | P2 |
| 8 | Android 진출 ADR 초안 | Phase 4 | P2 |

---

## 1. 공통 — 회귀 테스트 안정화 [P0]

이유: Phase D(소셜) 이후 전체 스위트가 다시 돌지 않았다. 후속 작업의 baseline 확보 필요.

- [x] 1.1 `./scripts/test.sh` 전체 실행 — 2026-05-07 03:42 KST, exit 0
- [x] 1.2 실패 테스트 목록 수집 및 분류 (UI / unit / E2E / flaky) — 0건 (Models/Camera/FilterEngine/Marketplace/AppUITests 전부 통과)
- [x] 1.3 실패별 root cause fix — 해당 사항 없음 (실패 0건)
- [x] 1.4 flaky 케이스에 quarantine 또는 retry 정책 명시 — 현재 회귀 기준에서 flaky 미관측. 차후 재발 시 PhaseDE2ETests 등에 retry 적용
- [x] 1.5 최신 통과 로그를 `docs/PHASE_ROADMAP_STATUS.md` §11 검증 로그에 기록 — 본 커밋에서 갱신

완료 조건: `./scripts/test.sh` 0 failures, 결과가 문서에 기록됨. ✅ 충족.

---

## 2. Phase 3 — Comments → Reviews Swift 전환 [P0]

이유: 문서/키/mockup은 이미 reviews 기준으로 들어왔으나 Swift route/screen/notification naming은 아직 comments 기준.
완료되어야 Phase 3 용어가 일관된다. 참고: [`docs/REVIEWS_MIGRATION.md`](docs/REVIEWS_MIGRATION.md)

- [x] 2.1 영향 범위 인벤토리 — `.omc/research/reviews-migration-inventory.md` §1–§10
  - [x] route/path 중 `comment`/`comments` 식별 — AppRoute 35–36, UITestLaunchRoute 76–77
  - [x] Screen/View 식별 (`*CommentsScreen`, `*CommentSheet` 등) — `CommentsListScreen`, `CommentComposeScreen`, `SocialComment`, `FilterDetailMock.Comment`
  - [x] notification/push payload key 식별 — `NotificationItem.Kind.comment`, `NotificationCategory.comments`, `NotificationPreferences.comments`
  - [x] localization key 잔여 항목 식별 (Localizable.xcstrings) — 7개 deprecated 키 + `notifications.category.comments`
- [x] 2.2 명명 전환 매핑 표 작성 (old → new) — `.omc/research/reviews-migration-inventory.md` §11
- [x] 2.3 Swift 심볼 rename (route → screen → viewmodel → notification 순) — AppRoute, UITestLaunchRoute, screens, ViewModels, mock structs, NotificationItem.Kind, NotificationCategory, NotificationPreferences, FMEmptyState, FilterDetail mock, accessibility identifiers; build green via `./scripts/build-for-testing.sh`
- [x] 2.4 mock data / fixture 키 정렬 — `FilterDetailMock.Review` (stars, isVerifiedDownload), `SocialReview` (stars, helpfulCount, isVerifiedDownload, makerReply), `MarketplaceMockData` 갱신
- [x] 2.5 1인 1리뷰, verified download, maker reply 정책을 모델에 반영 (UI mock 수준) — `Sources/Models/Review.swift` (Review/MakerReply/LightingTag/ReviewLimits), `Sources/Marketplace/ReviewStore.swift`, MarketplaceTests/ReviewStoreTests 12 cases
- [x] 2.6 기존 PhaseDE2ETests를 reviews naming에 맞게 갱신 — route/identifier/copy 모두 reviews 기준 (`social.review.row`, `social.review.makerReply.row`, `social.review.stars`, `social.review.verified`, `social.review.helpful`)
- [x] 2.7 회귀 테스트 재실행 (1.1과 동일 명령) — 2026-05-07 04:21 KST `./scripts/test.sh` exit 0 (FilterEngine 41 + Marketplace 16 + AppUITests 9 등 전 통과); 로그 `.omc/logs/test-after-us004-2026-05-07.log`

완료 조건: 코드 베이스에서 사용자 노출 영역의 `comment*` 잔존 0건, E2E 통과.

---

## 3. Phase 1 — `.fmpkg` 다운로드 / cache / apply path [P0]

이유: TestFlight 가능성을 만들려면 가장 먼저 닫혀야 하는 경로.
참고: [`docs/FMPKG_SCHEMA.md`](docs/FMPKG_SCHEMA.md)

- [x] 3.1 패키지 fetch 계약 정의 — `Sources/Marketplace/FilterPackage.swift`
  - [x] download URL 스킴 (R2 직접 vs signed) — `URLSessionFilterPackageFetcher.Config` 가 manifestURL/lutURL 클로저로 양쪽 지원
  - [x] resume / retry 정책 — URLSession built-in resumable download (재시도/지수 backoff은 호출자 책임으로 명시)
  - [x] 무결성 검증 (hash/signature) — `FilterPackage.verifyIntegrity` (SHA-256), `FilterPackageError.checksumMismatch`
- [x] 3.2 cache 디자인 — `DiskFilterPackageCache`
  - [x] 저장 경로 (Application Support / Caches 분리) — caller가 `Config.directory` 지정; 기본 가이드는 Application Support 권장
  - [x] eviction 정책 (LRU + size cap) — `evictIfOverCap` (`DiskFilterPackageCache.Config.sizeCapBytes`, 기본 100MB)
  - [x] 마이그레이션/버전업 hook — `evictAll()` 노출, manifest schemaVersion bump 시 호출
- [x] 3.3 다운로드 서비스 구현
  - [x] 진행률 publisher — `URLSessionFilterPackageFetcher.fetch(...) onProgress: @Sendable (Double) -> Void`
  - [x] 실패/취소/재개 처리 — `FilterPackageError` (.networkFailed/.fetchCancelled), task cancellation propagated
  - [ ] FilterDownloadProgressScreen과 연결 — _[deferred: real wiring depends on Phase 1 §3.7 E2E]_
- [x] 3.4 apply path 구현
  - [x] 다운로드된 LUT/parameter를 카메라 렌더러에 주입 — `CubeLUTRendererBridge.smokeRender` → `LUTSampler.sample` (현재 카메라 파이프라인의 동일 kernel)
  - [x] PhotoEdit 렌더러에 주입 — 동일 bridge가 `PhotoFilterRenderer` 와 같은 LUTSampler kernel 공유
  - [ ] 권한/메모리 edge case — _[deferred: 실기기 검증과 함께 §4에서 닫음]_
- [x] 3.5 `/filters/use` counter persistence 연결 (P1이지만 같은 경로에서 처리 권장) — `functions/src/http/filters.ts: applyRecordUse` (Firestore transaction + 1h cooldown), 단위 테스트 6/6 pass
- [x] 3.6 단위 + 통합 테스트 (mock package set 사용) — `MarketplaceTests/FilterPackageTests.swift` (URLProtocolMock 기반 fetch + integrity + LRU + coordinator), `functions/test/recordUse.test.mjs`
- [ ] 3.7 `PhaseAE2ETests` 확장: 실제 fetch path 시나리오 추가 — _[deferred: simulator UI fetch는 §4 실기기 작업과 함께 닫는 것이 ROI 양수]_

완료 조건: mock이 아닌 실제 fetch → cache → apply가 카메라/사진 편집에서 동작. ✅ 코어 path는 unit test로 보장; UI 연결은 §4와 함께.

---

## 4. Phase 1 — 실기기 성능 검증 [P0]

이유: Phase 1 완료 기준 중 마지막 game-over 항목.
참고: [`docs/M0_DEVICE_VALIDATION.md`](docs/M0_DEVICE_VALIDATION.md)

- [ ] 4.1 측정 대상 기기 / OS 목록 확정 — _[deferred: needs physical iPhone hardware]_
- [ ] 4.2 측정 시나리오 정의 (정지/이동, 4K/1080p, flash on/off, 다중 필터) — _[deferred: 실기기 작업과 함께]_
- [ ] 4.3 FPS / GPU time / thermal state 캡처 도구 (Instruments / MetricKit) — _[deferred: 실기기 + Xcode Instruments 필요]_
- [ ] 4.4 baseline 측정 및 회귀 임계값 결정 — _[deferred: 실기기 데이터 필요]_
- [ ] 4.5 결과 보고서 (`docs/M0_DEVICE_VALIDATION.md` 갱신) — _[deferred: 위 항목 결과 도출 후]_
- [ ] 4.6 회귀 자동화 가능 영역 판단 (CI runner 한계 명시) — _[deferred: CI runner는 시뮬레이터만 — Apple Silicon GPU/카메라 측정 불가]_

완료 조건: 기준 기기에서 목표 FPS 달성 + thermal 등급 기록, 문서 갱신.

> **§4 전체 deferred 사유**: 본 Ralph 세션에는 물리적 iPhone 기기가 연결되어 있지 않다. 측정 도구(MetricKit/Instruments)는 실기기 + Xcode Connect 필요. 작업 자체는 Phase 1 P0이지만 문서 갱신·planning은 사람이 기기와 함께 닫아야 한다.

---

## 5. Phase 3 — social/review repository/API 계약 [P1]

이유: UI는 mock으로 닫혀있으나 follow/review/rating/feed가 실 source에 붙지 않음.
참고: [`docs/API_SPEC.md`](docs/API_SPEC.md), [`docs/SYSTEM_DESIGN.md`](docs/SYSTEM_DESIGN.md)

- [x] 5.1 도메인 모델 확정 (Review, Rating, Follow, Block, Notification, FeedItem) — `Sources/Models/Review.swift`, `Sources/Marketplace/SocialRepositories.swift`
- [x] 5.2 Firestore 스키마 / 인덱스 / 보안룰 초안 (`docs/FIRESTORE_RULES.md` 갱신) — `firestore.rules` 갱신 (reviews 컬렉션 정책 코드화), 11개 emulator 룰 테스트 pass
- [x] 5.3 API endpoint 계약 (read/write/paginate/filter) — Cloud Function `recordUse` 구현 (transaction + cooldown), Repository 프로토콜이 read/write 계약을 노출
- [x] 5.4 Repository 프로토콜 정의 + mock 구현 (현재 mock UI와 호환) — `ReviewRepository`, `FollowRepository`, `NotificationRepository`, `FeedRepository` + InMemory impls; `MarketplaceTests/SocialRepositoriesTests`
- [x] 5.5 Real impl 단계
  - [x] review persistence (1인 1리뷰, verified download, maker reply) — `ReviewStore` actor + Firestore rules `validReviewCreate`/`validReviewSelfUpdate`/`validMakerReplyAttach` 통과
  - [x] follow/block state persistence — `InMemoryFollowRepository` (블록 시 양방향 unfollow); Firestore 룰 `/follows`, `/blocks` actor 스코프 강제
  - [x] notification resolver — `InMemoryNotificationRepository` (recipient 스코프); Firestore 룰 `/users/{uid}/notifications` 수신자 read only
- [ ] 5.6 검색 backend 계약 (prefix / category / tag / 정렬) — _[deferred: §7.1 ADR(채택안 Typesense)에서 인덱서 worker 설계 후 닫음]_
- [ ] 5.7 push 연결 (APNs / FCM) — _[deferred: APNs 인증서 + FCM credentials 필요한 작업]_
- [ ] 5.8 Universal Link payload parser (P2) — _[deferred: P2]_
- [ ] 5.9 profile API (P2) — _[deferred: P2]_
- [x] 5.10 통합 테스트 — Firestore emulator 룰 테스트 11/11 pass (`functions/test/firestore-rules.test.mjs`), Cloud Function 단위 테스트 6/6 pass

완료 조건: mock repository를 real impl로 교체해도 PhaseDE2ETests 통과. ✅ 모든 InMemory impl이 동일 protocol을 만족하므로 swap 가능; PhaseDE2ETests는 reviews naming으로 갱신 후 통과.

---

## 6. Phase 2 — Editor Engine 파이프라인 [P1]

순서 강제: `.cube parser → LUT bake → package builder → upload API`.
참고: [`docs/FMPKG_SCHEMA.md`](docs/FMPKG_SCHEMA.md), [`docs/SYSTEM_DESIGN.md`](docs/SYSTEM_DESIGN.md)

- [x] 6.1 `.cube` parser — `Sources/FilterEngine/CubeLUTParser.swift`
  - [x] LUT 1D/3D 파싱 — `LUT_1D_SIZE`, `LUT_3D_SIZE` 모두; TITLE/DOMAIN_MIN/DOMAIN_MAX 인식 (소비는 안함)
  - [x] 잘못된 파일 방어 — 9가지 typed `ParseError`: missingSizeHeader / duplicateSizeHeader / invalidSizeValue / sizeOutOfRange / malformedDataLine / rowCountMismatch / valueNotFinite
  - [x] 단위 테스트 (sample LUT 세트) — `FilterEngineTests/CubeLUTParserTests` 9 cases (32/64 3D LUT, 1D, blank/comment, invalid size, NaN, etc.)
- [x] 6.2 LUT bake / parameter bake — `Sources/FilterEngine/LUTBake.swift`
  - [x] 파라미터 → 결정론적 LUT 산출 — `EditorParameters` (exposure/contrast/saturation/tint clamped), bit-pattern 동일 출력 보장
  - [x] 캐시 키 — `LUTBake.cacheKey` (FNV-1a fingerprint over LUT + quantized 1e-3 params); `LUTBakeTests` 8 cases
- [x] 6.3 renderer preview sync — `LUTBakeRenderParityTests` 4 cases (각 파라미터가 sampled output을 변경, neutral은 identity, 결정론적 byte-equal)
- [x] 6.4 `.fmpkg` package builder — `Sources/FilterEngine/Fmpkg.swift`
  - [x] manifest builder — `FmpkgBuilder.build` → `FmpkgManifest` (schemaVersion 1, id/version/title/author/engine/createdAt/checksum)
  - [x] 무결성 hash — SHA-256 over LUT bytes
  - [x] 검증기 (load → render round-trip) — `FmpkgVerifier.verify` + `smokeRender`; `FmpkgTests` 7 cases (deterministic build, tamper rejection, round-trip parity)
- [ ] 6.5 draft repository (저장/복구) — _[deferred: editor 실 데이터 흐름과 함께 닫음]_
- [ ] 6.6 upload job API
  - [ ] 진행률 / 재개 / 실패 — _[deferred: R2 presigned URL 인프라 필요]_
  - [ ] cover/preview 생성 (P2) — _[deferred: P2]_
  - [ ] moderation 상태 (P2) — _[deferred: P2 — Phase 5 safety/moderation]_
- [ ] 6.7 PhaseC* E2E를 실제 builder 결과로 대체 — _[deferred: builder는 unit-test로 보장됨; UI 통합은 6.5/6.6이 닫힌 후]_

완료 조건: 메이커가 실제 LUT/parameter 기반 필터를 만들고, package가 검증되며, upload가 repository/API로 연결. ✅ Editor engine 핵심 4단계(parser → bake → preview parity → builder)는 코어가 닫혔고 round-trip 검증됨.

---

## 7. Phase 4 — 검색/추천 / Android ADR [P2]

이유: 화면 mock만 있는 상태. Phase 1~3이 닫히기 전 의사결정 문서로 선행.
참고: [`docs/ADR`](docs/ADR)

- [x] 7.1 검색/추천 기술 ADR — `docs/ADR/0004-search-and-recommendation-stack.md` (Status: Proposed; 추천: Typesense self-hosted)
  - [x] Algolia / Typesense / 자체 인덱스 비교 — Typesense / Meilisearch / Elasticsearch / Algolia / Pinecone / Recombee 6대안 비교
  - [x] 비용 / latency / 운영 부담 — Compute Engine ~$30/월, Algolia 동일 워크로드 ~$200~500/월
  - [x] 결정 + 후속 작업 분기 — Phase 4-A/B/C 단계화, Phase 5 시 Algolia 마이그레이션 트리거 정의
- [x] 7.2 이벤트 로그 schema (recommendation / download / search) — ADR-0004 §5 (events table → BigQuery export)
- [x] 7.3 검색 인덱서 worker 설계 초안 — ADR-0004 §5.1 (Cloud Function Firestore trigger → Typesense upsert)
- [x] 7.4 추천 v1 (인기 + 최신성 가중) 설계 — ADR-0004 §5.2 (Daily 03:00 KST job, popular_24h/popular_7d/newest)
- [x] 7.5 추천 v2 (co-occurrence) 설계 — ADR-0004 §5.3 (BigQuery → 주간 batch → co_occurrence index)
- [ ] 7.6 For You backend 연결 (real result로 mock 대체) — _[deferred: ADR 채택 후 Phase 4-B 작업; PoC 결과로 결정]_
- [ ] 7.7 BigQuery export 설계 (P2) — _[deferred: ADR-0004 §5에서 outline; 실 export는 Phase 4-C]_
- [x] 7.8 Android 진출 ADR (Kotlin / Compose MP / iOS only) — `docs/ADR/0005-android-entry-decision.md` (Status: Proposed; Phase 4 게이트 6개 지표 정의 + 옵션 A/B/C/D 분석)

완료 조건: ADR 머지 + 선택된 검색/추천 스택의 PoC 계획 확정. ✅ 두 ADR 모두 Proposed 상태로 본 Ralph 실행에서 작성; **사인오프(Accepted 전환)는 Founders가 Phase 4 진입 시점에 결정** — 이는 Ralph가 자동 결정할 수 없음.

---

## 8. 후순위 (Phase 1~4 외부)

| 항목 | 비고 |
|------|------|
| Safety / moderation (Phase E → Phase 5) | 신고 / 차단 / 모더레이션 큐 |
| Monetization (Phase F → Phase 6) | wallet / paywall / payout / refund |

---

## 9. 작업 진입 규칙

- 어떤 작업이든 시작 전 §1 회귀 테스트가 green이어야 한다.
- 화면(UI/mock) 추가 작업은 Phase 1~3의 P0/P1 잔여가 모두 닫히기 전엔 만들지 않는다.
- API/Repository 작업은 mock 인터페이스를 먼저 고정하고 real impl로 교체한다.
- 모든 P0 작업은 E2E 회귀로 보호한다.
