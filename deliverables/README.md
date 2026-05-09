# moodit (filterMarket) — PM Deliverables

> **As of:** 2026-05-10 · **Branch:** `main` · **Owner:** Incoming PM
> **Code source-of-truth:** `Sources/`, `functions/src/`, `firestore.rules`
> **Engineering doc set:** `../docs/` (엔지니어링 reference, 인덱스는 `../docs/README.md`)
>
> 이 폴더는 **PM 관점 산출물** 모음입니다. 신규 PM이 프로젝트를 인수인계받고, 임원/투자자/외부 협업자에게 현황을 설명하고, 다음 분기 계획을 세울 때 필요한 자료를 정리했습니다.
> 엔지니어링 상세 문서(`docs/`)와 디자이너 목업 패키지(`deliverables/index.html`, `flow-*.html`)는 별개로 유지되며, 본 README가 둘을 교차 인덱싱합니다.

---

## 0. 30초 요약

- **제품**: iOS 17+ 네이티브 카메라 필터 마켓플레이스. 메이커가 LUT/Metal 셰이더 기반 필터를 만들고, 촬영자가 다운로드/구매하여 라이브 카메라·후보정에 사용.
- **MVP 플랫폼**: iOS 단독 (Android는 Phase 4 게이트에서 재결정).
- **백엔드**: Firebase (Auth + Firestore + Cloud Functions v2 `asia-northeast3`) + Cloudflare R2(미디어). 결제는 Apple StoreKit2.
- **현재 상태(2026-05-10)**: BUILD ✅ / 162 unit + 26 AppUI 테스트 통과 (베이스라인 2026-05-08) / `struct *Screen: View` **67개**(grep 실측), 약 50개가 실 데이터 path 연결 / Cloud Functions callable **30** + 트리거 **11** (`onFilterPublished` / `onReportCreated` 본문 TODO) / 일부 업로드 end-to-end 미연결. 진행 중 refactor wave: 도메인 스토어 분리(2026-05-09 commit 시리즈).
- **단일 진행 기준**: Product Phase 1~4. **현재 Phase 1~3은 In Progress, Phase 4는 Not Started**. 완료된 Phase는 아직 없음.
- **다음 가장 큰 작업**: ① `.fmpkg` 다운로드/캐시/적용 path 실제화(Phase 1 P0), ② Comments→Reviews Swift 마이그레이션 정리(Phase 3 P0), ③ 실기기 카메라 FPS 측정(Phase 1 P0).

자세한 임원 요약은 [`executive-summary/EXECUTIVE_SUMMARY.md`](./executive-summary/EXECUTIVE_SUMMARY.md).

---

## 1. PM 산출물 인덱스

| 폴더 | 핵심 산출물 | 언제 보면 되는가 |
|---|---|---|
| [`executive-summary/`](./executive-summary/) | 1-pager 임원 요약 | 보고/투자 미팅 직전 |
| [`prd/`](./prd/) | PRD, 페르소나 | 기능 범위 정렬, 신규 합류자 온보딩 |
| [`roadmap/`](./roadmap/) | Phase 1~6 로드맵, 마일스톤 | 분기 계획, 우선순위 의사결정 |
| [`flowchart/`](./flowchart/) | 핵심 사용자/시스템 플로우 (Mermaid) | 화면·플로우 변경 영향 평가 |
| [`screens/`](./screens/) | 68개 화면 인벤토리(상태/오너) | 백로그 정리, QA 우선순위 |
| [`architecture/`](./architecture/) | 시스템 컨텍스트, 모듈 맵 | 외부 협업자 기술 brief |
| [`api-and-data/`](./api-and-data/) | Cloud Functions 표면, Firestore 스키마 | 백엔드 변경 영향 평가 |
| [`kpi/`](./kpi/) | North Star + 메트릭 트리 + Phase별 목표 | OKR/KPI 리뷰 |
| [`risks/`](./risks/) | Top 위험 등록부 + 완화 추적 | 분기 위험 검토 |
| [`glossary/`](./glossary/) | 용어집(Coin, .fmpkg, LUT 등) | 신규 합류자 ramp-up |
| [`stakeholder-brief/`](./stakeholder-brief/) | 신규 PM brief, 30/60/90 plan | 인수인계 시 |

---

## 2. 동거 중인 다른 산출물 패키지

이 폴더에는 PM 패키지와 별개로 **디자이너 목업**과 **백엔드 엔지니어링 명세**가 같이 살고 있습니다. PM 산출물과 분리해 사용하세요.

### 2.1 디자이너 목업 (2026-05-10 refresh)

| 파일 | 목적 |
|---|---|
| [`index.html`](./index.html) | 디자이너 목업 갤러리 (브라우저로 열기) |
| `flow-01-auth.html` … `flow-08-states-modals.html` | 8개 플로우별 iPhone-frame 목업 |
| [`DESIGNER_NOTES.md`](./DESIGNER_NOTES.md) | 디자이너 주석 (ADD/FIX/A11Y/COPY/NOTE) |
| [`_tokens.css`](./_tokens.css) | DESIGN_TOKENS.json v1.2.0 미러 |

PM은 `flow-*.html`을 의사결정 근거(목업 ↔ 코드 diff 추적)로 활용하고, 변경 의도는 `DESIGNER_NOTES.md`로 검토합니다.

### 2.2 백엔드 엔지니어링 명세 (`backend/`)

신규 백엔드 엔지니어 온보딩용 — 코드 기준(`functions/src/**/*.ts`, `firestore.rules`)에서 추출한 상세 표면.

| 파일 | 내용 |
|---|---|
| [`backend/README.md`](./backend/README.md) | 인덱스 + 백엔드 한 줄 요약 |
| [`backend/API_REFERENCE.md`](./backend/API_REFERENCE.md) | 모든 Callable / Trigger 상세 명세 (입출력 스키마, 에러, 인증) |
| [`backend/OPENAPI.yaml`](./backend/OPENAPI.yaml) | OpenAPI 3.x 스펙 |
| [`backend/FIRESTORE_SCHEMA.md`](./backend/FIRESTORE_SCHEMA.md) | 컬렉션 트리, 문서 스키마, 보안 룰 |
| [`backend/TRIGGERS.md`](./backend/TRIGGERS.md) | Firestore 트리거 (카운터 fan-out) |
| [`backend/ERROR_CODES.md`](./backend/ERROR_CODES.md) | HttpsError ↔ 도메인 에러 매핑 |
| [`backend/RATE_LIMITS.md`](./backend/RATE_LIMITS.md) | 슬라이딩 윈도우 버킷 표 |
| [`backend/AUTH_AND_ROLES.md`](./backend/AUTH_AND_ROLES.md) | App Check + custom claim 모델 |
| [`backend/DEPLOYMENT.md`](./backend/DEPLOYMENT.md) | 환경/시크릿/배포 명령 |

PM 패키지의 [`api-and-data/`](./api-and-data/)는 동일 사실의 *PM 요약*입니다. 깊은 디테일이 필요하면 `backend/`를 보세요.

---

## 3. 엔지니어링 문서와의 관계

| 알고 싶은 것 | PM 산출물 | 엔지니어링 원본 |
|---|---|---|
| 제품 비전·페르소나·KPI | `prd/PRD.md` | `../docs/PRD.md` |
| Phase별 진행 상태 | `roadmap/ROADMAP.md` | `../docs/PHASE_ROADMAP_STATUS.md` |
| 화면 액션 ID, 라우팅 | `screens/SCREEN_INVENTORY.md` | `../docs/NAVIGATION.md`, `../docs/SCREEN_ACTIONS_QA_DEFINITION.md` |
| Cloud Functions / Firestore | `api-and-data/*` | `../docs/API_SPEC.md`, `../docs/FIRESTORE_RULES.md`, `functions/src/` |
| 위험 등록 | `risks/RISK_REGISTER.md` | `../docs/RISKS.md` |
| 시스템 구조 | `architecture/*` | `../docs/ARCHITECTURE.md`, `../docs/SYSTEM_DESIGN.md` |

PM 산출물은 **요약·결정·조율**에 최적화되어 있고, 깊은 기술 디테일은 항상 `docs/`를 가리킵니다. 사실 충돌 시 코드 > `docs/` > `deliverables/` 순으로 신뢰합니다.

---

## 4. 산출물 유지보수 원칙

1. **불변 사실**(스크린 ID, callable 시그니처, 컬렉션 스키마)은 코드와 `docs/`만 진실원으로 두고, `deliverables/`는 그 시점 스냅샷이다.
2. **결정 기록**은 `roadmap/MILESTONES.md` 또는 `risks/RISK_REGISTER.md`에 날짜·결정자와 함께 남긴다.
3. PRD/페르소나는 분기 1회 리뷰. 변경 시 `prd/PRD.md` 상단 버전 라인을 갱신.
4. 새 산출물을 추가하기 전, 기존 폴더에 섹션으로 들어갈 수 있는지 먼저 확인.

---

## 5. 변경 이력

| 날짜 | 변경 | 작성자 |
|---|---|---|
| 2026-05-10 | PM 산출물 패키지 초안 (11개 폴더 / 14개 문서) | Incoming PM |
| 2026-05-10 | 코드 직접 검증 후 callable/trigger 수, 화면 수, 테스트 baseline 날짜 정정 (`docs/`가 outdated 일 수 있어 § 6 기록) | Incoming PM |

---

## 6. 검증 부록 — Source-of-Truth 추적

> 본 패키지의 **모든 숫자는 *코드 직접 grep* 으로 재검증 가능해야** 한다. 이 표는 *어떻게 검증했는지* 기록 — 다음 PM이 1년 뒤에 다시 돌렸을 때 같은 값을 얻어야 한다. 값이 바뀌면 산출물도 바뀐다.

### 6.1 코드로 검증된 사실 (2026-05-10)

| 사실 | 값 | 검증 명령 | 결과 |
|---|---|---|---|
| iOS deployment target | 17.0 | `grep -nE deploymentTarget project.yml` | 8개 모두 `17.0` |
| Firebase region | `asia-northeast3` | `grep -rE "asia-northeast" functions/src/` | 5개 파일 모두 동일 |
| handle regex | `/^[a-z0-9_.]{3,30}$/` | `grep -nE HANDLE_REGEX functions/src/http/identity.ts` | line 58 |
| `recordUse` 쿨다운 | 1h (3600000ms) | `grep -nE RECORD_USE_COOLDOWN_MS functions/src/http/filters.ts` | line 38 |
| Storage 규칙 | 모든 경로 deny | `cat storage.rules` | `allow read, write: if false` |
| IAP 상품 ID | coins.{100/550/1200/3000} + pro.{monthly/yearly} | `grep -rE "com\.jayl2kor\.moodit\.(coins\|pro)" Sources/ functions/src/` | 6개 ID 양쪽 일치 |
| Cloud Functions callables | **30** (filters 16, identity 5, moderation 5, wallet 4) | `grep -rE "^export const \w+ = onCall" functions/src/http/ \| wc -l` | 30 |
| Firestore triggers | **11** | `grep -nE "^export const \w+ = onDocument" functions/src/triggers/index.ts \| wc -l` | 11 |
| 트리거 본문 TODO | `onFilterPublished`, `onReportCreated` | `grep -nE "TODO" functions/src/triggers/index.ts` | line 29, 44 |
| `struct *Screen: View` 정의 | **67** | `grep -rcE "^\s*(public\s+)?struct\s+\w+Screen\s*:\s*View" Sources/ \| awk -F: '{s+=$2} END {print s}'` | 67 |
| `AppRoute` enum cases | **64** | `grep -cE "^\s*case\s+\w" Sources/App/AppNavigation.swift` | 64 |
| Rate limit buckets | 8 (default, filtersUpload/Use/Report, identityHandle, walletPurchase/IAP/Refund) | `grep -nE "Buckets\s*=\|filters\.\|wallet\.\|identity\." functions/src/lib/ratelimit.ts` | line 17~25 |
| Functions 테스트 파일 | 9 (8 unit + 1 rules) | `ls functions/test/ \| wc -l` | 9 |
| iOS test 디렉토리 | 6 (App, AppUI, Camera, FilterEngine, Marketplace, Models) | `find Tests -mindepth 1 -maxdepth 1 -type d` | 6 |

### 6.2 *코드로 검증되지 않은* 사실 (사람의 판단/외부)

다음은 코드에서 직접 확인 불가 — 별도 출처 또는 운영 데이터 필요. 산출물에서 인용 시 *출처 표시 의무*.

| 사실 | 출처 |
|---|---|
| 페르소나 수치 (지수 24·8K 팔로워 등) | PRD.md 인터뷰 가설 — 실 데이터 미수집 |
| 12개월 KPI 목표 (MAU 200K 등) | PRD.md §5, 시장 추정 기반 |
| iOS 핵심 페르소나 비중 65~75% | Statista 등 외부 자료 추정 |
| 메이커 분배 60% | 정책 결정 (`docs/CURRENCY_DESIGN.md`) |
| 일정 (M1=2026-Q3 등) | 내부 가정, 변동 가능 |
| Phase 진행 % | 정성적 — `docs/PHASE_ROADMAP_STATUS.md` 기반 |

### 6.3 발견된 doc / code 불일치 (2026-05-10)

| 사실 | docs/ 표기 | 코드 실측 | 본 패키지 적용 값 |
|---|---|---|---|
| Cloud Functions callable 수 | 11 (`docs/FEATURE_CATALOG.md` §8) | 30 | **30** |
| Trigger 수 | 9 | 11 | **11** |
| 화면 수 | "약 68" | 67 | **67** |
| 회귀 테스트 baseline 날짜 | 2026-05-07 (`docs/PHASE_ROADMAP_STATUS.md`) | 최신 로그 2026-05-08 | **2026-05-08** |
| 진행 중 refactor wave | 미언급 | 2026-05-09 도메인 스토어 분리 commit 시리즈 + uncommitted M 18건 | 본 패키지에 명시 |

### 6.4 다음 PM이 분기마다 다시 돌릴 검증 스크립트

```bash
cd /Users/user/workspace/applications/filterMarket

# (1) Cloud Functions surface
grep -rcE "^export const \w+ = onCall"      functions/src/http/      # → 30 기대
grep -cE  "^export const \w+ = onDocument"  functions/src/triggers/index.ts  # → 11
grep -nE  "TODO"                             functions/src/triggers/index.ts  # → 본문 미구현 트리거

# (2) iOS surface
grep -rE  "^\s*(public\s+)?struct\s+\w+Screen\s*:\s*View" Sources/ | wc -l   # → 화면 struct 수
grep -cE  "^\s*case\s+\w" Sources/App/AppNavigation.swift                    # → AppRoute case 수

# (3) 정책 상수 정합
grep -nE  "RECORD_USE_COOLDOWN_MS"           functions/src/http/filters.ts
grep -nE  "HANDLE_REGEX"                     functions/src/http/identity.ts
grep -nE  "Buckets\s*=" -A 10                functions/src/lib/ratelimit.ts
grep -rE  "com\.jayl2kor\.moodit"            Sources/App/Marketplace/IAPProductIDs.swift functions/src/http/wallet.ts

# (4) 빌드/테스트 baseline
xcodegen generate && ./scripts/build.sh && ./scripts/test.sh
( cd functions && npm run build && npm run test && npm run test:rules )

# (5) 진행 중 작업 컨텍스트
git status -sb
git log --since="-14 days" --pretty="%h %ad %s" --date=short
```

값이 표 6.1과 어긋나면 — *그 fact를 인용한 산출물 문장*을 모두 갱신해야 한다. grep 결과 자체를 검증의 정답으로 삼는다.
