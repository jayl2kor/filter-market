# moodit - 외부 계정 / 서비스 셋업 체크리스트

> 버전: v1.0 · 작성일: 2026-05-06
>
> 본 문서는 [SETUP.md](./SETUP.md)의 외부 의존성 부분을 정식 체크리스트로 확장한다. 각 항목별로 비용, 소요 시간, 제출 정보, 후속 단계를 명시한다.

---

## 1. 우선순위 / 일정

| 우선순위 | 항목 | Phase 시점 | 차단 작업 |
|---|---|---|---|
| P0 | Apple Developer Program | 사전 (D-7) | 모든 빌드/배포 |
| P0 | Apple Developer 콘솔 (Bundle ID, Cert) | 사전 (D-3) | 실기기 / TestFlight |
| P0 | Firebase 프로젝트 (3 환경) | Phase 0 | 인증/Firestore |
| P0 | Cloudflare 계정 + R2 버킷 | Phase 0 | 미디어 저장 |
| P0 | Google Cloud OAuth Client | Phase 1 | Google 로그인 |
| P0 | Apple Sign in Service ID | Phase 1 | Apple 로그인 |
| P0 | App Store Connect 앱 레코드 | Phase 1 | TestFlight |
| P1 | Sentry / Crashlytics 결정 | Phase 1 | 모니터링 |
| P1 | PostHog | Phase 1 | 분석 |
| P2 | 도메인 (moodit.app) | Phase 1 | Universal Link |
| P2 | APNs Auth Key | Phase 3 | 푸시 |
| P3 | Algolia | Phase 4 | 검색 고도화 |
| P3 | Stripe Connect | Phase 6 | 정산 |

---

## 2. Apple Developer Program

### 2.1 가입
- URL: https://developer.apple.com/programs/
- **비용**: $99/yr (개인/조직), $299/yr (Enterprise — 본 프로젝트 비해당)
- **소요**: 1~3 영업일 (조직은 D-U-N-S 검증 + Apple 통화 가능)

### 2.2 제출 정보
- **개인**: Apple ID, 신용카드, 거주지 주소
- **조직**:
  - 법인등기부 + 사업자등록증
  - D-U-N-S Number (https://developer.apple.com/enroll/duns-lookup/) — 무료, 5~14일
  - 법인 대표 / 권한자 정보 + Apple 인증 통화 (한국/영어 가능)
  - 법인 결제 카드

### 2.3 후속 단계
- App Store Connect 자동 활성화 (가입자 = Account Holder)
- 팀 구성: 다른 개발자 초대 (Admin / Developer / Marketing 역할)
- WWDC / Tech Talk 비디오 액세스

### 2.4 트러블슈팅
- "We're unable to verify your name" → 결제 카드 명의 일치 + 재입금
- 한국 사업자: D-U-N-S 발급에 영문 법인명/주소 통일 필수

---

## 3. Apple Developer 콘솔 (Identifiers / Capabilities)

### 3.1 Bundle ID 등록
- **URL**: https://developer.apple.com/account/resources/identifiers
- **Bundle ID 명명**: `com.moodit.ios` (env 분기는 `com.moodit.ios.dev`, `.staging`)
- 활성화할 Capabilities:
  - Sign in with Apple (필수)
  - Push Notifications (Phase 3)
  - Associated Domains (Universal Link, Phase 3)
  - App Attest (Phase 5)
  - In-App Purchase (Phase 6)

### 3.2 인증서 / 프로비저닝 프로파일
- Fastlane match 사용 권장 — 별도 git 저장소(`moodit-certificates`)에 암호화 저장
- 종류: Development, Distribution (App Store), Distribution (Ad Hoc — TestFlight 미사용 시)

### 3.3 비용 / 소요
- 비용: 위 Apple Developer Program 포함
- 소요: 즉시 (가입 후)

---

## 4. App Store Connect 앱 레코드

### 4.1 생성
- **URL**: https://appstoreconnect.apple.com → My Apps → "+"
- 입력:
  - Platform: iOS
  - Name: moodit
  - Primary Language: English
  - Bundle ID: 사전 등록한 것 선택
  - SKU: 자유, 예: `moodit-ios-001`

### 4.2 메타데이터 (사전 작성)
- **카테고리**: Photo & Video (Primary), Social Networking (Secondary)
- **Age Rating**: 12+ 또는 17+ (UGC 노출 수준 결정 후)
- **Pricing**: Free (Phase 6 전까지)
- **App Privacy**: Photos, Camera, User Content, Identifiers, Diagnostics, Usage Data — 정확히 신고
- **Support URL**, **Marketing URL**: moodit.app 또는 임시 GitHub Pages

### 4.3 비용 / 소요
- 비용: 무료 (Apple Developer 포함)
- 소요: 즉시

---

## 5. Apple Sign in Service ID

### 5.1 생성
- **URL**: Identifiers → "+" → Services IDs
- Identifier: `com.moodit.signin`
- Description: "moodit Sign in with Apple"
- Configure:
  - Domain: `moodit-{env}.firebaseapp.com` (3개 환경 + verified)
  - Return URL: `https://moodit-{env}.firebaseapp.com/__/auth/handler`

### 5.2 Key 생성 (Phase 3 backend 직접 검증 시)
- Keys → "+" → "Sign in with Apple" 활성화
- Key file (.p8) 다운로드 (1회 다운로드, 분실 시 재발급 필요)
- Key ID + Team ID + Service ID 보관

### 5.3 후속 단계
- Firebase Auth → "Sign-in method" → Apple → Service ID + OAuth callback 등록
- 클라이언트 `AuthenticationServices.framework` 통합 (참고: [API_SPEC.md](./API_SPEC.md) §2)

---

## 6. Google Cloud Console / OAuth

### 6.1 프로젝트
- Firebase 프로젝트와 동일 GCP 프로젝트 (자동) 사용
- **URL**: https://console.cloud.google.com → 프로젝트 선택

### 6.2 OAuth 2.0 Client ID
- APIs & Services → Credentials → CREATE CREDENTIALS → OAuth client ID
- Application type: **iOS**
- Bundle ID: `com.moodit.ios`
- Reversed Client ID 복사 → Info.plist `CFBundleURLTypes` URL Scheme 등록

### 6.3 OAuth Consent Screen
- User Type: External
- App name, Logo, Support email, Authorized domains (`moodit.app`)
- Scopes: `email`, `profile`, `openid` (기본)
- Phase 1: Testing 모드(테스트 사용자 100명) → Phase 2 출시 후 Production 게시 (검토 1~2주)

### 6.4 비용 / 소요
- 비용: 무료 (GCP 무료 티어)
- 소요: Client ID 즉시, Production 게시 1~2주

---

## 7. Firebase 프로젝트 (3 환경)

### 7.1 프로젝트 생성
- **URL**: https://console.firebase.google.com → "Add project"
- 3개 생성:
  - `moodit-dev`
  - `moodit-staging`
  - `moodit-prod`
- Region 선택: **asia-northeast3 (서울)** — 한국 사용자 지연 최소화

### 7.2 활성화할 서비스
| 서비스 | 활성화 | 비고 |
|---|---|---|
| **Authentication** | ✓ | Sign-in providers: Apple, Google, Anonymous |
| **Firestore Database** | ✓ | Native mode, asia-northeast3 |
| **Cloud Functions** | ✓ | Node.js 20, Blaze plan 필수 |
| **Cloud Storage** | (선택) | R2 사용 — 비활성 권장 |
| **Cloud Messaging** | ✓ (Phase 3) | APNs 키 업로드 |
| **Crashlytics** | ✓ | dSYM 자동 업로드 |
| **Performance** | ✓ | 자동 |
| **Remote Config** | ✓ | 피처 플래그 |
| **App Check** | ✓ (Phase 5) | App Attest 통합 |
| **Hosting** | ✓ | 모더레이터 웹 어드민 (Phase 5) |

### 7.3 iOS 앱 추가
- 각 프로젝트 → "Add app" → iOS
- Bundle ID 입력 (env별 분기)
- `GoogleService-Info.plist` 다운로드 → `Sources/App/Resources/Firebase/{env}/GoogleService-Info.plist`

### 7.4 Firestore 초기 셋업
- Rules: 첫 배포는 명시적 deny → [FIRESTORE_RULES.md](./FIRESTORE_RULES.md)
- Indexes: `firestore.indexes.json` 배포

### 7.5 비용 / 소요
- 무료 티어: 50K MAU까지 충분
- Cloud Functions는 **Blaze plan**(종량) 필수 — 신용카드 등록 필요
- 알람: GCP Billing → Budget alert ($50, $200, $500 임계)
- 소요: 즉시

---

## 8. Cloudflare 계정 + R2 버킷

### 8.1 계정 가입
- **URL**: https://dash.cloudflare.com/sign-up
- 무료 플랜 가입 → Pro($20/mo)는 출시 후 검토 (DDoS / WAF)

### 8.2 R2 활성화
- Dashboard → R2 → "Enable R2"
- 결제 정보 입력 (소액 — 첫 10GB 무료, 이후 GB당 $0.015)

### 8.3 버킷 생성
| 이름 | 용도 |
|---|---|
| `moodit-prod` | 프로덕션 |
| `moodit-staging` | 스테이징 |
| `moodit-dev` | 개발 |

### 8.4 API 토큰
- Account → R2 → "Manage R2 API Tokens"
- Permissions: **Object Read & Write**
- Bucket: 해당 단일 버킷 (env별 분리)
- TTL: 90일 (회전)
- 발급된 키:
  - Access Key ID
  - Secret Access Key
  - Endpoint: `https://<account-id>.r2.cloudflarestorage.com`
- 시크릿은 GCP Secret Manager 또는 Xcode Cloud Environment Variables에 저장 — 절대 git 금지

### 8.5 CDN 연결 (Public bucket)
- R2 버킷 → Settings → "Connect Domain" → `cdn.moodit.app`
- DNS는 Cloudflare에서 관리 (CNAME `cdn` → `<bucket>.r2.dev` 또는 자동)
- Cache Rules: 30일 TTL, versioned URL 패턴

### 8.6 비용
- 저장: $0.015/GB/mo (10GB 무료)
- Class A (write) 요청: $4.50 / 1M
- Class B (read) 요청: $0.36 / 1M
- **Egress**: $0 (Cloudflare 강점)

---

## 9. Sentry vs Crashlytics 결정

### 9.1 옵션
| 도구 | 장점 | 단점 |
|---|---|---|
| **Crashlytics** | Firebase 통합 무료 | 검색 약함, 비-크래시 에러 처리 약함 |
| **Sentry** | 강력한 검색/그루핑, source map, performance | 5K event/mo 무료, 이상 유료 |

### 9.2 권장
- **둘 다 사용** (이중화):
  - Crashlytics: 크래시 + dSYM 자동 (무료)
  - Sentry: 비크래시 에러 + 사용자 피드백 + Performance (5K event 무료)
- Phase 4부터 Sentry Team plan ($26/mo, 50K events) 검토

### 9.3 셋업
- Crashlytics: Firebase 콘솔에서 활성화, dSYM 업로드는 Xcode Cloud post-action으로 자동
- Sentry: https://sentry.io 가입 → DSN을 Xcconfig 환경 변수로 주입

---

## 10. PostHog (제품 분석)

### 10.1 가입
- **URL**: https://app.posthog.com (Cloud) 또는 self-host (Phase 5+)
- 무료 1M event/mo

### 10.2 셋업
- Project 생성 → API Key (write) 발급
- iOS SDK 통합 (`PostHog`, SwiftPM)
- 이벤트 분류: `app_install`, `signup_complete`, `camera_first_frame`, `filter_apply`, `filter_download`, `filter_upload_finalize`
- Feature flags 동기화 (Firebase Remote Config와 이중 운영)

### 10.3 비용
- 무료 1M event/mo
- 그 이상: $0.000248/event (Cloud) 또는 self-host

---

## 11. APNs Auth Key

### 11.1 발급 (Phase 3)
- Apple Developer Console → Keys → "+"
- Key Name: `APNs moodit`
- Services: APNs 활성
- 다운로드 .p8 (1회)
- Key ID + Team ID 기록

### 11.2 Firebase 등록
- Firebase 콘솔 → Cloud Messaging → APNs Authentication Key
- .p8 + Key ID + Team ID 입력

---

## 12. 도메인 (선택)

### 12.1 등록
- **moodit.app** 또는 .io (.app은 HTTPS 강제 — 보안 우호)
- 등록 (예: Cloudflare Registrar, Namecheap)
- 비용: 약 $20~30/yr

### 12.2 DNS
- Cloudflare에서 관리 (CDN/방어 통합)
- 필요한 레코드:
  - `cdn.moodit.app` → R2 bucket
  - `api.moodit.app` → Cloud Functions 또는 Cloud Run
  - `app.moodit.app` → Hosting (어드민) 또는 마케팅 페이지
  - `_well-known/apple-app-site-association` → Universal Link

### 12.3 Universal Link / Associated Domains
- App Capabilities에서 `applinks:moodit.app` 추가
- AASA 파일을 Hosting 또는 R2에서 서빙

---

## 13. Algolia (Phase 4)

### 13.1 가입
- **URL**: https://www.algolia.com (Phase 4 진입 직전)
- 무료 1K req/mo (테스트 충분), Build $1/1K req

### 13.2 셋업 (Phase 4)
- Index 1개: `filters_<env>`
- Searchable attributes: `title`, `tags`, `description`, `category`, `authorName`
- Custom ranking: `metrics.downloads desc`, `popularity desc`
- API Keys: Search-only (클라이언트), Admin (서버)

> Phase 1~3에는 가입 불필요.

---

## 14. Stripe Connect (Phase 6)

### 14.1 가입
- **URL**: https://dashboard.stripe.com (Phase 6 진입 직전)
- 비용: 결제당 2.9% + $0.30 (정산 표준)

### 14.2 Connect Express 설정
- Express 계정 — 메이커가 KYC를 Stripe 호스팅 페이지에서 완료
- Webhook: `payment_intent.succeeded`, `account.updated` 등을 Cloud Function으로 수신
- Onboarding URL은 동적 생성 (메이커별)

### 14.3 한국 메이커 추가 정보
- 사업자등록번호 또는 주민등록번호(개인 메이커)
- 정산 계좌 (한국 은행 직접 입금 지원)

> Phase 1~5에는 가입 불필요.

---

## 15. 마스터 체크리스트

```markdown
## Phase 0 (사전 ~ 1주차)
- [ ] Apple Developer Program 가입 완료
- [ ] D-U-N-S 발급 (조직)
- [ ] Bundle ID 등록 (com.moodit.ios + .dev/.staging)
- [ ] Capabilities: Sign in with Apple, Push, Associated Domains
- [ ] Fastlane match 인증서 git repo 셋업
- [ ] Firebase 프로젝트 3개 + iOS 앱 추가 + plist 다운로드
- [ ] Cloudflare 계정 + R2 버킷 3개 + API 토큰
- [ ] Apple Sign in Service ID + Firebase Auth 연동
- [ ] Google OAuth Client ID + Reversed Client ID

## Phase 1
- [ ] App Store Connect 앱 레코드 + 메타데이터 사전 작성
- [ ] Crashlytics + Sentry 통합
- [ ] PostHog 통합
- [ ] Privacy Policy / EULA 한·영 게시
- [ ] App Privacy 라벨 정확히 신고
- [ ] TestFlight Internal 첫 배포

## Phase 3
- [ ] APNs Auth Key + Firebase 등록
- [ ] Universal Link / Associated Domains + AASA 파일
- [ ] 도메인 등록 (moodit.app)

## Phase 4
- [ ] Algolia 가입 + index 셋업

## Phase 5
- [ ] App Attest 활성화
- [ ] 모더레이션 BPO 후보 평가 (선택)

## Phase 6
- [ ] Stripe Connect 가입
- [ ] StoreKit 2 product 등록 (App Store Connect)
- [ ] 한국 사업자 정보 등록 / 외환 정산
```

---

## 16. 비용 요약 (월간, MVP 기준)

| 항목 | Phase 1~3 (저활성) | Phase 4~6 (활성) |
|---|---|---|
| Apple Developer | $8/mo (yr) | $8/mo |
| Firebase Blaze | $0~10 | $50~150 |
| Cloudflare R2 | $1~5 | $10~50 |
| Cloudflare CDN | $0 | $20 (Pro) |
| Sentry Team | $0 | $26 |
| PostHog | $0 | $0~50 |
| Algolia | — | $50~200 |
| 도메인 | $2 | $2 |
| **합계** | **~$25/mo** | **~$200~500/mo** |

> Stripe / Apple IAP 수수료는 매출 기준 별도. Stripe Connect는 결제당 2.9% + $0.30, Apple IAP 30%(소형 사업자 15%).

---

## 17. 관련 문서

- [SETUP.md](./SETUP.md)
- [TECH_STACK.md](./TECH_STACK.md) §외부 서비스
- [ARCHITECTURE.md](./ARCHITECTURE.md) §5 외부 서비스 의존성
- [RISKS.md](./RISKS.md) — 비용 / 정책 위험
