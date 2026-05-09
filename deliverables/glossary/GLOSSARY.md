# moodit · Glossary

> 신규 합류자 ramp-up용. 코드/문서 전반에 등장하는 *프로젝트 고유 용어*만 모았다. 일반 iOS/Firebase 용어는 제외.

## 제품 / 비즈니스

| 용어 | 정의 |
|---|---|
| **moodit** | 제품 공식 이름 (`com.jayl2kor.moodit`). 서비스 코드네임 `filterMarket` 또한 같은 프로젝트를 가리킴 |
| **양면 시장** (two-sided marketplace) | 메이커(공급) ↔ 촬영자(수요)가 양쪽 사용자인 마켓플레이스 |
| **메이커** (Maker) | 필터를 제작·업로드하는 사용자. 검수 통과 후 적립/판매 가능 |
| **촬영자** (Consumer) | 마켓에서 필터를 찾아 다운로드/구매해 사용하는 사용자 |
| **WAFA** | **W**eekly **A**ctive **F**ilter **A**pplications. North Star 지표. 주간 필터 적용 횟수(촬영+후보정) |
| **Coin** | 앱 내부 화폐. Apple IAP로 충전(`100/550/1200/3000`), 1 Coin ≈ ₩14 |
| **Pro 멤버십** | 월 ₩4,900 / 연 ₩34,800. 모든 유료 필터 무제한 + 월 300 코인 자동 적립 |
| **closed-loop coin** | 코인을 앱 내에서만 사용하고 외부 환전을 막는 정책. v1에서는 메이커 출금 진입점도 비노출 |
| **Phase 1~6** | 제품 진행 기준. 1=MVP, 2=에디터, 3=리뷰/소셜, 4=추천+Android게이트, 5=모더레이션, 6=수익화 |
| **UI Work Package** (구 Phase A~F) | 화면 개발 묶음 단위. 제품 Phase가 아니다 |

## 기술 / 도메인

| 용어 | 정의 |
|---|---|
| **.fmpkg** | moodit 필터 패키지 포맷. LUT(.cube) + manifest(JSON) + checksum(SHA256) 묶음. R2에 저장. 스펙: `docs/FMPKG_SCHEMA.md` |
| **LUT** | Look-Up Table. 색감 변환 테이블. 17³/33³/65³ 그리드 + RGBA8/RGBA16F |
| **MSL** | Metal Shading Language. Apple GPU 셰이더 언어 |
| **Metal 4-pass** | 라이브 카메라 렌더링 파이프라인: ① YUV→RGB ② base params ③ LUT lookup ④ grain/vignette |
| **MTKView** | MetalKit의 텍스처 렌더 뷰. 카메라 라이브 프리뷰 surface |
| **CVPixelBuffer** | AVFoundation이 카메라 프레임을 전달하는 버퍼 타입. YUV 420f |
| **CVMetalTextureCache** | CVPixelBuffer를 MTLTexture로 zero-copy 변환 |
| **AppRoute** | 모든 화면 라우팅이 통과하는 단일 enum (`Sources/App/AppNavigation.swift`) |
| **Action ID** | 모든 버튼의 stable 식별자. `<group>.<verb>` 형식. SwiftUI `accessibilityIdentifier`와 일치 |
| **handle** | 사용자 핸들. `[a-z0-9_.]{3,30}`. `handles/{handle}` 컬렉션이 소유권 보장 |
| **entitlement** | 사용자가 유료 필터를 소유하고 있다는 권한. `users/{uid}/entitlements/{filterId}` |
| **rate limit bucket** | callable별 호출 한도(`_ratelimit/{bucket}/keys/{key}`). 슬라이딩 윈도우 |
| **App Check** | Firebase callable 호출자가 *진짜 앱*인지 검증. `enforceAppCheck: true` |
| **App Attest** | iOS DeviceCheck/AppAttest. 디바이스 무결성 검증 (Phase 5 도입 예정) |

## 화면 / 라우팅

| 용어 | 정의 |
|---|---|
| **RootShell** | 5탭 셸 + 셔터 모달 진입점. `Sources/App/RootShell.swift` |
| **셔터(중앙 탭)** | 일반 탭이 아닌 fullScreenCover로 카메라를 띄우는 진입점 |
| **권한 priming** | 시스템 다이얼로그 *전에* 띄우는 설명 화면 (카메라/사진/알림/위치) |
| **Universal Link** | Apple 표준 딥링크. `UniversalLinkParser` → `AppRoute` 매핑 |
| **DeepLinkDestination** | Universal Link / Push 페이로드 → AppRoute 변환 결과 |
| **Telemetry funnel step** | 단계별 사용자 이동 측정 이벤트(`Telemetry.trackFunnelStep`) |

## 모더레이션 / 정책

| 용어 | 정의 |
|---|---|
| **검수 (review)** | 메이커 업로드 후 모더레이터 판단 (`approved` / `rejected`) |
| **takedown** | 이미 공개된 필터를 비공개 처리. moderation queue에서 트리거 |
| **Comments → Reviews** | 자유 댓글 모델을 App Store 리뷰 패턴(1인 1리뷰 + 별점 + 메이커 답글 1회)로 전환한 결정. `docs/REVIEWS_MIGRATION.md` |
| **DMCA** | Digital Millennium Copyright Act. 저작권 침해 신고/24시간 처리 SLA |
| **pHash** | Perceptual Hash. 이미지 유사도 비교용. 알려진 유료 LUT 식별 |
| **Age Rating** | App Store 연령 등급. moodit는 12+/17+ 사전 적합성 검토 |

## 결제 / 정산

| 용어 | 정의 |
|---|---|
| **JWS** | JSON Web Signature. Apple 영수증 서명 형식. `signedJWS` 필드 |
| **originalTransactionId** | Apple IAP 영수증 고유 ID. 중복 충전 방지 키 |
| **walletLedger** | 거래 로그. `kind: purchase | topup | refund` |
| **Stripe Connect** | 메이커 출금용 외부 결제 인프라. Express 계정 onboarding (Phase 6) |
| **메이커 분배** | 필터 1건 판매 시 메이커 60% 코인 적립, moodit 운영비 40% |
| **출금 임계** | 5,000 코인. 도달 시 KRW 환전 가능 (Stripe Connect, KYC 필수) |

## 도구 / 빌드

| 용어 | 정의 |
|---|---|
| **xcodegen** | `project.yml` → `moodit.xcodeproj` 생성 |
| **scripts/build.sh, test.sh** | 표준 빌드/테스트 스크립트. DerivedData=`.build/DerivedData` |
| **Firebase emulators** | Functions/Firestore 로컬 검증 (`npm run serve`) |
| **firestore-rules.test.mjs** | 규칙 emulator 테스트 |

---

**참조**: 코드 내 검색 — `Sources/App/AppNavigation.swift`(AppRoute), `Sources/Models/Filter.swift`(도메인 타입). 정책 단일 진실원: `docs/CURRENCY_DESIGN.md`, `docs/REVIEWS_MIGRATION.md`, `docs/PERMISSIONS_FLOW.md`.
