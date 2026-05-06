# moodit

> **누구나 자신만의 카메라 필터를 만들고, 거래하고, 공유하는 글로벌 마켓플레이스 (iOS native)**

moodit은 GPU 셰이더 기반 라이브 카메라 필터, 모바일 친화 필터 에디터, 그리고 양면 마켓플레이스(메이커-촬영자)를 결합한 **iOS 네이티브** 어플리케이션입니다.

---

## 핵심 기능

1. **라이브 카메라 + 실시간 필터** — Metal 기반 GPU 셰이더로 1080p@30~60FPS 라이브 프리뷰
2. **모바일 필터 에디터** — LUT + 파라미터 기반, 노드 그래프(Phase 3)
3. **마켓플레이스** — 검색, 카테고리, 평점, 댓글, 다운로드
4. **소셜** — 팔로우, Remix(파생), 공유 링크
5. **모더레이션** — 자동(Cloud Vision + 온디바이스 Vision) + 신고 + 모더레이터 큐
6. **수익화** (Phase 6) — 유료 필터, IAP, Stripe Connect 정산

---

## 디렉토리 구조

```
moodit/
├── docs/                       # 설계 / 운영 문서
│   ├── README.md               # 본 문서 (인덱스)
│   ├── PRD.md                  # 제품 요구사항
│   ├── ARCHITECTURE.md         # 시스템 아키텍처
│   ├── SYSTEM_DESIGN.md        # 핵심 컴포넌트 상세 설계
│   ├── TECH_STACK.md           # 기술 스택 결정 + 근거
│   ├── TASK_LIST.md            # Phase별 작업 분해
│   ├── IMPLEMENTATION_PLAN.md  # 구현 이슈 계획
│   ├── IMPLEMENTATION_STATUS.md # 구현 진행 상태
│   ├── M0_DEVICE_VALIDATION.md # M0 실기기 검증 체크리스트
│   ├── RISKS.md                # 위험 등록부 + 완화
│   ├── SETUP.md                # 개발 환경 셋업 가이드
│   ├── EXTERNAL_SETUP.md       # 외부 계정/서비스 셋업 체크리스트
│   ├── CODING_CONVENTIONS.md   # Swift 코딩 컨벤션
│   ├── TESTING_STRATEGY.md     # 테스트 전략
│   ├── FMPKG_SCHEMA.md         # .fmpkg 필터 패키지 정식 스펙
│   ├── API_SPEC.md             # REST/Firestore API 스펙
│   ├── FIRESTORE_RULES.md      # Firestore Security Rules 초안
│   ├── MSL_SECURITY.md         # 메이커 셰이더(MSL) 보안 정책
│   └── ADR/                    # Architecture Decision Records
│       ├── README.md           # ADR 인덱스 + 작성 가이드
│       ├── template.md         # ADR 템플릿
│       ├── 0001-swift-only-ios-first.md
│       ├── 0002-firebase-mvp-backend.md
│       └── 0003-metal-msl-shader-pipeline.md
├── moodit.xcodeproj/     # Xcode 프로젝트
├── moodit.xcworkspace/   # SPM/외부 의존성 워크스페이스
├── Sources/
│   ├── App/                    # 앱 엔트리, DI, 라우팅
│   ├── Camera/                 # AVCaptureSession, 프리뷰, 셔터
│   ├── FilterEngine/           # Metal 파이프라인, MSL 셰이더, LUT 로더
│   ├── Marketplace/            # 피드/검색/상세
│   ├── Editor/                 # 필터 에디터(LUT+파라미터)
│   ├── Auth/                   # Firebase Auth + Sign in with Apple/Google
│   ├── Storage/                # R2/Firestore 클라이언트, 캐시
│   ├── Models/                 # 도메인 모델
│   └── DesignSystem/           # 컬러/타이포/컴포넌트
├── Tests/
│   ├── UnitTests/              # XCTest 단위
│   ├── SnapshotTests/          # iOSSnapshotTestCase
│   └── UITests/                # XCUITest
├── Filters/                    # 큐레이션 .fmpkg 시드
├── Shaders/                    # .metal MSL 셰이더 소스
├── .omc/                       # OMC 메타데이터
└── fastlane/                   # 배포 자동화
```

> **현재 상태**: Phase 0 코드 구현과 로컬 빌드/테스트 완료. iPhone 실기기 검증 대기.

---

## 산출물 링크

문서는 다음 5개 카테고리로 구성된다.

### 제품 (Product)
| 문서 | 한 줄 요약 |
|---|---|
| [PRD.md](./PRD.md) | 비전, 페르소나, MoSCoW 기능, KPI, 경쟁 분석 |

### 설계 (Design)
| 문서 | 한 줄 요약 |
|---|---|
| [ARCHITECTURE.md](./ARCHITECTURE.md) | C4 컨텍스트/컴포넌트 다이어그램, 데이터 흐름, 외부 의존성 |
| [SYSTEM_DESIGN.md](./SYSTEM_DESIGN.md) | Metal GPU 파이프라인, 필터 포맷(.fmpkg), 마켓 데이터 모델 |
| [FMPKG_SCHEMA.md](./FMPKG_SCHEMA.md) | `.fmpkg` 필터 패키지 정식 스펙 (manifest JSON Schema, 서명) |
| [API_SPEC.md](./API_SPEC.md) | Firestore 직접 접근 + Cloud Functions REST 엔드포인트 정식 스펙 |

### 운영 (Operations)
| 문서 | 한 줄 요약 |
|---|---|
| [SETUP.md](./SETUP.md) | 개발 환경 셋업 (Xcode/Homebrew/도구/시크릿/첫 빌드) |
| [EXTERNAL_SETUP.md](./EXTERNAL_SETUP.md) | Apple/Firebase/Cloudflare 외부 계정 셋업 체크리스트 |
| [CODING_CONVENTIONS.md](./CODING_CONVENTIONS.md) | Swift 코딩 컨벤션, SwiftLint/SwiftFormat 룰셋, PR 체크리스트 |
| [TESTING_STRATEGY.md](./TESTING_STRATEGY.md) | 테스트 피라미드, 도구, 커버리지 목표, CI 통합 |
| [TECH_STACK.md](./TECH_STACK.md) | 프레임워크/DB/저장/CDN/검색/결제 결정과 근거 |

### 보안 (Security)
| 문서 | 한 줄 요약 |
|---|---|
| [FIRESTORE_RULES.md](./FIRESTORE_RULES.md) | Firestore Security Rules 초안 + 인덱스 + Emulator 검증 시나리오 |
| [MSL_SECURITY.md](./MSL_SECURITY.md) | 메이커 셰이더 다층 방어(AST 화이트리스트/루프 bound/서명) |

### 계획 (Planning)
| 문서 | 한 줄 요약 |
|---|---|
| [TASK_LIST.md](./TASK_LIST.md) | Phase 0~6 작업 분해, 추정 공수, Gantt |
| [IMPLEMENTATION_PLAN.md](./IMPLEMENTATION_PLAN.md) | 구현 이슈화를 위한 마일스톤/라벨/이슈 단위 실행 계획 |
| [IMPLEMENTATION_STATUS.md](./IMPLEMENTATION_STATUS.md) | 실제 구현 진행 상황, 검증 결과, 다음 Phase 계획 |
| [M0_DEVICE_VALIDATION.md](./M0_DEVICE_VALIDATION.md) | M0-C 실기기 smoke test와 성능 기록 양식 |
| [RISKS.md](./RISKS.md) | 기술/비즈니스/운영 위험 + 매트릭스 |
| [ADR/](./ADR/README.md) | 아키텍처 결정 기록 (현재 0001~0003) |

---

## 개발 시작하기

처음 합류한 개발자라면:

1. **[SETUP.md](./SETUP.md)** — 30분 내 첫 빌드 (Xcode + Homebrew + Firebase plist)
2. **[EXTERNAL_SETUP.md](./EXTERNAL_SETUP.md)** — Apple Developer / Firebase / Cloudflare 계정 셋업
3. **[CODING_CONVENTIONS.md](./CODING_CONVENTIONS.md)** — Swift 스타일, 동시성, PR 체크리스트
4. **[TESTING_STRATEGY.md](./TESTING_STRATEGY.md)** — TDD 워크플로 + Firebase Emulator
5. **[ADR/](./ADR/README.md)** — 핵심 결정 배경 (왜 iOS 단독, 왜 Firebase, 왜 Metal)

---

## 빠른 결정 요약

- **클라이언트**: Swift 5.10+ / Swift 6, SwiftUI 메인 + UIKit 보완(카메라 프리뷰), AVFoundation, Metal/MSL, Core Image, Photos
- **지원 플랫폼**: iOS 17.0+ (Phase 1~3). Android는 Phase 4 이후 시장 반응 보고 결정
- **백엔드 (MVP)**: Firebase 통합 (Auth + Firestore + Cloud Functions)
- **백엔드 (Phase 4+)**: Cloud Run + Vapor(Swift) 또는 Ktor — MVP 결정 보류
- **저장**: Cloudflare R2 (egress 무료) + Cloudflare CDN
- **검색**: Firestore (MVP) → Algolia (Phase 4)
- **결제 (Phase 6)**: Apple IAP + Stripe Connect 정산

---

## 로드맵 (요약)

| Phase | 기간 | 목표 |
|---|---|---|
| 0 | 1주 | PoC: Swift + Metal 라이브 프리뷰 30~60FPS 검증 |
| 1 | 6주 | MVP — 카메라/내장 15필터/저장/마켓 다운로드 — TestFlight Closed Beta |
| 2 | 5주 | LUT + 파라미터 에디터 — 메이커 베타 |
| 3 | 6주 | 소셜(팔로우/평점/댓글/Remix) + 검색 |
| 4 | 4주 | 추천 시스템 + Algolia + **Android 진출 의사결정 게이트** |
| 5 | 4주 | 모더레이션 / 신고 / 저작권 |
| 6 | 6주 | 유료 필터 / IAP / 메이커 정산 |

전체 ~32주 (약 8개월)에 v1.0 풀 피처(iOS) 출시 목표.

---

## 핵심 KPI (12개월)

- iOS MAU 200K (Phase 4까지 iOS 단독 기준)
- D1 리텐션 45%
- 누적 업로드 필터 50K
- 사용자당 일평균 필터 적용 8회
- 카메라 평균 FPS ≥ 60 (95퍼센타일, A14 Bionic 이상)
- App Store "Today" 또는 "App of the Day" 피처드 1회 이상

---

## 다음 단계

1. 본 문서 세트(PRD, Architecture, Design, Tech Stack, Tasks, Risks, ADR 0001~0003) **이해관계자 리뷰** (1주)
2. 외부 계정 사전 셋업 — [EXTERNAL_SETUP.md](./EXTERNAL_SETUP.md) Phase 0 체크리스트 (Apple Developer, Firebase 3 환경, Cloudflare R2)
3. **Phase 0 PoC 킥오프** — [SETUP.md](./SETUP.md)대로 환경 셋업 + Swift + Metal + AVFoundation 라이브 프리뷰 검증 (1주 이내)
4. PoC 결과로 Phase 1 백로그 확정 → 6주 스프린트 시작
5. Phase 4 종료 시 **Android 진출 옵션 비교**(네이티브 Kotlin / Compose MP / iOS only 유지) → 새 ADR로 기록 (참고: [ADR-0001](./ADR/0001-swift-only-ios-first.md) §3.4)

---

## 라이선스 / 약관 (예정)

- 앱 코드: 향후 결정 (현재 비공개 사내 프로젝트)
- 메이커 콘텐츠: 메이커가 라이선스 선택 (CC-BY / CC0 / All Rights Reserved)
- 사용자 약관 / 개인정보처리방침: Phase 1 종료 전 게시

---

## 컨텍스트

이전 세션에서 trvlog 프로젝트의 카메라 필터 + 템플릿 마켓플레이스 + Firebase 로그인 논의가 있었으며, 본 moodit은 그 아이디어를 본격적인 독립 어플리케이션으로 분리·구체화한 결과입니다. 초기에는 크로스플랫폼(Compose Multiplatform)을 검토했으나, **iOS 네이티브 단독 출시로 전략을 재정렬**하여 카메라/Metal 표현력과 출시 속도를 우선합니다.
