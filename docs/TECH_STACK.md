# moodit - Technology Stack & Decisions

> 버전: v1.1 (Draft, iOS native pivot) · 작성일: 2026-05-06
>
> 이 문서는 각 레이어별 기술 선택과 **결정 근거(rationale)** 그리고 검토한 대안을 기록한다.

---

## 1. 결정 요약 (TL;DR)

| 레이어 | 1차 선택 | 비고 |
|---|---|---|
| 클라이언트 언어 | **Swift 5.10+ / Swift 6** | 네이티브 표현력, 컨커런시 모델 성숙 |
| UI 프레임워크 | **SwiftUI 메인 + UIKit 보완** | 카메라 프리뷰 등 UIKit 필요 부분만 `UIViewRepresentable` |
| 카메라 | **AVFoundation (`AVCaptureSession`)** | iOS 표준 |
| GPU/셰이더 | **Metal + MSL** + 일부 Core Image (`CIFilter`) | 최고 표현력, 60FPS 보장 |
| 사진/저장 | **Photos / PhotoKit** | 표준 권한·라이브러리 흐름 |
| 비전/ML | **Vision + Core ML** (Phase 4) | 얼굴 검출, 온디바이스 NSFW |
| 최소 지원 | **iOS 17.0+** | Metal 3, Observation, SwiftData 활용 |
| 의존성 관리 | **Swift Package Manager (SPM)** | 모듈화 + 1급 지원 |
| 백엔드 (MVP) | **Firebase 통합** (Auth + Firestore + Cloud Functions) | 빠른 출시 |
| 백엔드 (Phase 4+) | Cloud Run + **Vapor (Swift)** 또는 **Ktor** — MVP 결정 보류 | 점진 분리 |
| DB | **Firestore (MVP)** → Postgres+Supabase (확장 시) | NoSQL → SQL 전환 시점 명시 |
| 미디어 저장 | **Cloudflare R2** | egress 무료 |
| CDN | Cloudflare | R2와 통합 무료 |
| 검색 | Firestore 단순 쿼리(MVP) → Algolia(Phase 4) | 단계적 |
| 인증 | Firebase Auth + Sign in with Apple/Google | 표준 |
| 결제 (Phase 6) | Apple IAP (StoreKit 2) + Stripe Connect(정산) | 정책 강제 |
| 모더레이션 | Cloud Vision SafeSearch + 온디바이스 Vision 1차 + 사용자 신고 + 모더레이터 큐 | 자동+수동 혼합 |
| CI/CD | **Xcode Cloud + Fastlane** | TestFlight 직결 |
| 모니터링 | Crashlytics + MetricKit + os_signpost + Sentry + PostHog | iOS 네이티브 친화 |
| 플랫폼 전략 | **iOS 단독 출시 (Phase 1~3)** → Phase 4 이후 Android 의사결정 | - |

---

## 2. 클라이언트 프레임워크 결정

### 2.1 평가 매트릭스

| 기준 (가중치) | Flutter | React Native | Compose Multiplatform | **Swift + SwiftUI** |
|---|---|---|---|---|
| 카메라 API 성숙도 (5) | 4/5 | 3/5 | 3/5 | **5/5** (AVFoundation) |
| GPU 셰이더 / 커스텀 렌더 (5) | 3/5 (Skia 제한) | 2/5 (RN-Skia 우회) | 3/5 (Skia for iOS 미성숙) | **5/5** (Metal 직접) |
| iOS Metal 접근 (4) | 3/5 | 2/5 | 3/5 | **5/5** |
| App Store 피처드 가능성 (4) | 2/5 | 2/5 | 2/5 | **5/5** (네이티브 우대) |
| 코드 공유율 (Android 포함, 3) | 5/5 | 5/5 | 4/5 | 1/5 (iOS only) |
| 빌드 / 핫리로드 DX (3) | 5/5 | 5/5 | 4/5 | 4/5 (SwiftUI Preview) |
| 팀 학습 곡선 (3) | 4/5 | 4/5 | 3/5 | 4/5 (팀 Swift 친숙) |
| 패키지 / 생태계 (2) | 5/5 | 5/5 | 3/5 | **5/5** |
| 빌드 산출물 크기 (2) | 3/5 | 3/5 | 4/5 | **5/5** |
| 장기 유지보수 (3) | 4/5 (Google 의존) | 3/5 (Meta 우선순위 변동) | 4/5 (JetBrains) | **5/5** (Apple 1급 시민) |
| MVP 출시 속도 (4) | 4/5 | 4/5 | 3/5 | **5/5** (PoC 1주) |
| **가중 합계** | 119 | 105 | 103 | **141** |

### 2.2 결정: Swift + SwiftUI (iOS 네이티브 단독)

**이유**:
- **카메라 + Metal 표현력**이 본 제품의 핵심 차별점 → 어떤 크로스플랫폼도 동등 수준 도달이 어려움
- **App Store 피처드/Apple Design Award** 가능성: 네이티브 + Apple 최신 기술(Metal 3, Vision, Observation) 채용은 큐레이션에 유리 (참고: Halide, Darkroom, Procreate)
- **MVP 출시 속도**: PoC 1주, MVP 6주 — 크로스플랫폼 PoC(2~3주) 대비 단축
- **iOS 비중이 높은 1차 페르소나**(북미·서유럽·한국·일본 크리에이터) 커버 가능
- 팀이 Swift에 친숙하며, 백엔드도 향후 Vapor 채택 시 언어 통일 가능

**리스크**:
- Android 시장 기회비용 (북미·서유럽 외 시장 손실) → Phase 4 게이트에서 정량 평가
- iOS 단일 코드베이스 → Android 진출 시 별도 구현 필요(자산 일부만 재사용)

**대안 검토 결과**:
- **Compose Multiplatform**: 이전 버전에서 1차 후보였으나, iOS 측 카메라 surface integration + Skia for iOS 성능 불확실성 + PoC 비용이 크고, MVP까지의 출시 속도가 떨어짐. **Phase 4에 Android 진출 의사결정 시 재검토 옵션 중 하나**
- **Flutter**: 카메라/셰이더는 가능하나 Metal 직접 제어가 제한적. 메이커 노트의 셰이더 표현력에서 한계
- **React Native**: GPU 셰이더 워크로드에서 가장 약함. RN-Skia로 보완은 가능하지만 성능/안정성이 우리 요구치 미달
- **네이티브 iOS+Android 동시**: 팀 5명 미만에서 비현실적. iOS 우선 출시 후 시장 검증

### 2.3 SwiftUI vs UIKit 분담
- SwiftUI: 마켓 피드, 에디터 슬라이더, 프로필, 설정, 네비게이션
- UIKit (`UIViewRepresentable`): 카메라 프리뷰(MTKView), 일부 카메라 컨트롤(고급 제스처), `PHPickerViewController`
- iOS 17+ Observation 프레임워크 적극 사용

---

## 3. GPU / 셰이더 언어

### 3.1 후보
- **MSL (Metal Shading Language)** — iOS 1급 시민
- **Core Image (`CIFilter` + `CIKernel`)** — 보조용
- **GLSL ES** — iOS에서 deprecated, 미사용

### 3.2 결정: MSL (1차) + Core Image (보조)

**이유**:
- iOS 17 + Metal 3 = 최고 GPU 성능, 60FPS 보장
- `.metal` 파일은 Xcode 빌드 시 자동 컴파일되어 `.metallib`로 번들
- 메이커 업로드 셰이더(Phase 3+)도 동일 언어 → 일관성
- Core Image는 비핫패스(썸네일 생성, 정적 합성)에서 짧은 코드로 활용

### 3.3 LUT 형식
- 외부 입력: Adobe `.cube`, DaVinci `.3dl` (Swift 파서)
- 내부 표준: 1024×1024 PNG (33³ 그리드 packing) 또는 `MTLTextureType.type3D` 직접 RGBA16Float
- 33³ 정밀도 = 35,937 sample → 부드러움 충분, 용량 작음
- 고급: 65³ + RGBA16F 옵션 (Phase 3, banding 회피)

---

## 4. 백엔드 결정

### 4.1 MVP: Firebase 통합

**선택 이유**:
- Auth + Firestore + Cloud Functions가 한 묶음 → MVP까지 백엔드 인프라 작성 최소화
- 50K MAU까지 무료 티어 + 점진적 비용
- Firebase iOS SDK가 풍부, 오프라인 지원 내장
- 보안 규칙(Security Rules)으로 권한 코딩 최소화

> 미디어 저장은 처음부터 **Cloudflare R2** (Firebase Storage 미사용 — egress 비용 회피).

### 4.2 Phase 4+ 분리 옵션: Cloud Run + Vapor 또는 Ktor — MVP 결정 보류

**전환 트리거**:
- Firestore 읽기 비용이 매출의 30% 초과
- 추천/검색이 Firestore에 종속되어 한계
- p95 레이턴시 > 500ms

**Phase 4 옵션 비교**:

| 기준 | Vapor (Swift) | Ktor (Kotlin) | Spring Boot | Node + NestJS |
|---|---|---|---|---|
| 모바일 코드 공유 | **5/5** (Codable 모델 직접) | 4/5 (Android 진출 시 KMP) | 3/5 | 2/5 |
| 콜드 스타트 | 4/5 | **4/5** | 2/5 | 4/5 |
| 비용 (Phase 4) | 4/5 | 4/5 | 3/5 | 4/5 |
| 운영 복잡도 | 3/5 | 3/5 | 2/5 | 3/5 |
| 생태계 | 3/5 | 4/5 | **5/5** | **5/5** |
| 채용 풀 | 2/5 | 4/5 | **5/5** | **5/5** |

**MVP 단계 결정 보류 사유**:
- Phase 4 시점에 Android 진출 여부에 따라 답이 달라짐 (Android 진출 → Ktor 가산점, iOS 단독 유지 → Vapor 가산점)
- 따라서 Phase 4 시작 시점에 시장 데이터 + Android 결정과 함께 재평가

---

## 5. 데이터베이스

### 5.1 MVP: Firestore

| 장점 | 단점 |
|---|---|
| iOS SDK 1급 (오프라인 캐시) | 복잡 쿼리(JOIN, aggregation) 어려움 |
| 실시간 동기화 무료 | 비용이 읽기/쓰기/문서 단위 |
| 보안 규칙 강력 | 단일 문서 1 write/sec 한계 |
| 자동 스케일 | 인덱스 명시 필요 |

### 5.2 Phase 4+: Postgres + Supabase / GCP Cloud SQL

**전환 트리거**: 위 백엔드 분리 트리거와 동일

**Postgres 우위**:
- 복잡 검색/추천 쿼리(window function, CTE)
- 트랜잭션
- 비용 예측 쉬움

**전환 전략**:
- 도메인별 점진 이전: filters → users → social_graph → activity
- Auth는 Firebase Auth 유지(전환 비용 큼)
- Firestore는 실시간 알림 채널로 유지하거나 Postgres LISTEN/NOTIFY로 대체

### 5.3 분석/이벤트
- **BigQuery**: 이벤트 로그(클릭, 다운로드, 검색) 적재 → 추천/대시보드
- **PostHog (self-hosted Phase 5)**: 제품 분석 + 실험

### 5.4 클라이언트 로컬 DB
- **SwiftData** (iOS 17+) 또는 **GRDB** — 다운로드 필터 메타/오프라인 큐 저장
- 결정: SwiftData 1차 시도, 마이그레이션/성능 이슈 시 GRDB로 전환

---

## 6. 미디어 저장

### 6.1 결정: Cloudflare R2 (1차)

**이유**:
- **Egress 무료** — 모바일 앱은 다운로드 트래픽이 핵심 비용 → S3/Firebase Storage 대비 큰 차이
- S3 호환 API → 코드 이식성
- Cloudflare CDN과 무료 통합

### 6.2 비용 추정 (월간, 100K iOS MAU 가정)

| 항목 | 양 | R2 비용 | S3 비용 (참고) |
|---|---|---|---|
| 저장(.fmpkg + 미리보기) | 50TB | \$750 | \$1,150 |
| Egress(다운로드) | 200TB | **\$0** | \$18,000 |
| Class A 요청 | 10M | \$45 | \$50 |
| **합계** | | **~\$795** | **~\$19,200** |

> Egress 차이만으로 R2 결정은 자명하다.

---

## 7. CDN

### 7.1 결정: Cloudflare

- R2와 통합 무료
- 200+ PoP, 한국·동남아 지연 낮음
- Worker로 edge 인증/리사이징 가능

### 7.2 캐시 키 설계
- `https://cdn.moodit.app/filters/{filterId}/v{version}/filter.fmpkg`
- `version` 변경 시 자연 무효화

---

## 8. 검색

### 8.1 단계
- **MVP**: Firestore 기본 쿼리(이름 prefix, 카테고리, 태그)
- **Phase 4**: Algolia 또는 Typesense
- **Phase 6+**: 자체 임베딩 + Vertex AI Vector Search

### 8.2 Algolia vs Typesense

| 기준 | Algolia | Typesense |
|---|---|---|
| 출시 속도 | **5/5** (managed) | 4/5 |
| iOS SDK 품질 | **5/5** | 4/5 |
| 비용 (Phase 4) | 3/5 (\$1/1K req) | **5/5** (self-host) |
| 검색 품질 | **5/5** | 4/5 |
| Personalization | **5/5** | 3/5 |
| 운영 부담 | **5/5** | 3/5 |

> **결정**: Algolia로 출시, 비용이 매출의 5% 초과하면 Typesense로 전환 검토.

---

## 9. 인증

### 9.1 Firebase Auth + Sign in with Apple
- Sign in with Apple (필수, `AuthenticationServices`)
- Google Sign In (`GoogleSignIn-iOS`)
- Email + Password (Phase 2)
- Custom Claims로 role 관리
- 다중 IdP 연결 지원

### 9.2 보안 헤더 / 정책
- TLS 1.3 강제
- Phase 5: 인증서 핀닝 (`URLSessionDelegate.urlSession(_:didReceive:completionHandler:)`)
- 토큰 회전: ID Token 1h TTL, Refresh Token 30일 (Firebase SDK 자동)
- Keychain Services로 민감 정보 저장
- App Attest (`DCAppAttestService`)로 디바이스 무결성 검증

---

## 10. CI/CD

### 10.1 결정: Xcode Cloud + Fastlane

```mermaid
flowchart LR
    PR[PR] --> Lint[SwiftLint + SwiftFormat]
    Lint --> Test[XCTest Unit + Snapshot]
    Test --> Build[Xcode Cloud Build]
    Build --> UI[XCUITest (Cloud sim)]
    UI --> IPA[Archive IPA]
    IPA --> TF[TestFlight Internal]
    TF --> Beta[Beta Group<br/>External Testers]
    Beta -->|tag v1.x| Prod[App Store Connect]
```

- **Xcode Cloud**: SwiftPM 1급 지원, TestFlight 자동 배포
- **Fastlane**: code signing match, 메타데이터/스크린샷 자동화

### 10.2 환경 변수 / 시크릿
- Xcode Cloud Environment + GCP Secret Manager
- Fastlane match로 인증서 관리

### 10.3 테스트 전략
- 단위 테스트: **XCTest** (Swift Testing 전환 검토)
- 스냅샷 테스트: `iOSSnapshotTestCase` 또는 `swift-snapshot-testing`
- 통합 테스트: Firebase Emulator Suite (CI에서 docker)
- UI 테스트: **XCUITest**
- E2E: Maestro (선택, 핵심 플로우)
- 성능 회귀: Instruments + `os_signpost` + XCTest performance metrics

---

## 11. 모니터링 / 관측성

| 도구 | 용도 | 비용 |
|---|---|---|
| Firebase Crashlytics | 크래시 | 무료 |
| **MetricKit** | hang/disk/battery/launch 자동 수집 | 무료 (iOS 표준) |
| **os_signpost** + Instruments | 사용자 정의 트레이스 | 무료 |
| Sentry | 에러 + Source map (dSYM) | 5K event/mo 무료 |
| Firebase Performance | 클라이언트 성능 추적 (네트워크/HTTP) | 무료 |
| Cloud Logging / Monitoring | 백엔드 로그/메트릭 | 50GB/mo 무료 |
| PostHog | 제품 분석 + 실험 | 1M event/mo 무료(self-host 가능) |
| BigQuery | 이벤트 분석 | 1TB query/mo 무료 |

### 11.1 Custom Trace (성능 SLO) — `os_signpost`
- 카메라 첫 프레임까지 시간(TTFF)
- 필터 로드까지 시간 (.fmpkg 다운로드 + Metal 텍스처 업로드)
- 마켓 피드 로드 p95
- API p95

---

## 12. 코드 품질 / 표준

| 영역 | 도구 |
|---|---|
| Swift lint | **SwiftLint** + **SwiftFormat** (pre-commit + CI) |
| 타입 안전 | Swift 6 strict concurrency mode (`-strict-concurrency=complete`) |
| 커밋 메시지 | Conventional Commits |
| Pre-commit | git pre-commit hook (lint + 포맷 + 단위 테스트 일부) |
| PR 템플릿 | 변경 요약, 영향 범위, 테스트, 스크린샷 |
| 문서화 | DocC (`.docc` 카탈로그) |

---

## 13. 배포 / 스토어

### 13.1 iOS App Store
- 카테고리: Photo & Video
- 12+ 또는 17+ (UGC 노출 수준에 따라)
- App Privacy 라벨: Photos, Camera, User Content, Identifiers, Diagnostics, Usage Data
- UGC 정책: EULA + 보고/차단 기능 + **24h 모더레이션 SLA**
- App Store Connect API로 메타데이터/스크린샷 자동화

### 13.2 Android (Phase 4 게이트 후 결정 — 현 단계 미적용)
- Phase 4에 Android 옵션 결정 (네이티브 Kotlin / Compose MP / iOS only)

### 13.3 단계적 출시
- Internal (TestFlight) → Closed Beta(External 100명) → Open Beta → Production
- A/B 실험: Firebase Remote Config + PostHog
- iOS 단계적 출시: App Store Connect "Phased Release" 7일

---

## 14. 위험 / 결정 재검토 시점

| 결정 | 재검토 트리거 |
|---|---|
| Swift + SwiftUI (iOS only) | Phase 4 게이트 — Android 시장 데이터 평가 |
| iOS 17+ 최소 지원 | iOS 17 점유율 < 70%면 16+로 하향 검토 |
| Firebase 통합 | Firestore 비용 폭증 / 추천 한계 |
| R2 | Cloudflare 가격 변경 / 신뢰성 사고 |
| Algolia | 매출 대비 비용 5% 초과 |
| Phase 4 백엔드(Vapor vs Ktor) | Android 진출 결정과 동시에 확정 |

---

## 15. 관련 문서
- [PRD.md](./PRD.md)
- [ARCHITECTURE.md](./ARCHITECTURE.md)
- [SYSTEM_DESIGN.md](./SYSTEM_DESIGN.md)
- [TASK_LIST.md](./TASK_LIST.md)
- [RISKS.md](./RISKS.md)
