# filterMarket - 개발 환경 셋업 가이드

> 버전: v1.0 · 작성일: 2026-05-06
>
> 이 문서는 신규 합류 개발자가 30분 내에 로컬에서 첫 빌드를 성공시킬 수 있도록 안내한다. 외부 계정 셋업의 자세한 체크리스트는 [EXTERNAL_SETUP.md](./EXTERNAL_SETUP.md)를 함께 참조한다.

---

## 1. 시스템 요구사항

| 항목 | 최소 | 권장 |
|---|---|---|
| macOS | 14 (Sonoma) | 15 (Sequoia) |
| Xcode | 15.4 | 16.x |
| Swift | 5.10 | Swift 6 (strict concurrency) |
| iOS Simulator | iOS 17.0 | iOS 17.5+ |
| 실기기 | iPhone 12 (A14 Bionic) 이상 권장 | iPhone 15 Pro |
| 디스크 여유 공간 | 50GB | 100GB+ |
| RAM | 16GB | 32GB+ (Metal 셰이더 디버깅 시) |
| Apple Silicon | 권장 | M2 Pro 이상 권장 (Xcode Cloud sim 가속) |

---

## 2. 필수 도구

### 2.1 Xcode 및 커맨드라인 도구

```bash
# 1. App Store에서 Xcode 15.4+ 설치
# 2. Command Line Tools
xcode-select --install

# 3. 동의 (라이선스)
sudo xcodebuild -license accept

# 4. 시뮬레이터 런타임 다운로드 (Xcode > Settings > Platforms)
xcodebuild -downloadPlatform iOS
```

### 2.2 Homebrew

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 2.3 패키지 설치

```bash
brew install swiftlint swiftformat xcbeautify periphery
brew install --cask fastlane
brew install gh                    # GitHub CLI
brew install firebase-cli          # Firebase 로컬 에뮬레이터
brew install cloudflared           # R2 토큰 검증용 (선택)
```

| 도구 | 용도 |
|---|---|
| **SwiftLint** | 정적 분석 (스타일 + 코드 스멜) |
| **SwiftFormat** | 자동 포맷팅 |
| **Periphery** | 데드 코드 검출 |
| **xcbeautify** | `xcodebuild` 출력 가독성 향상 |
| **Fastlane** | 코드 사이닝, 메타데이터/스크린샷, TestFlight 자동화 |
| **Firebase CLI** | Firestore/Auth/Functions 에뮬레이터 |

---

## 3. 추천 도구

| 도구 | 용도 | 설치 |
|---|---|---|
| **Charles / Proxyman** | HTTPS 트래픽 검사 | App Store |
| **Reveal** | 런타임 뷰 계층 디버깅 | https://revealapp.com |
| **Instruments** | Metal/CPU/Memory 프로파일링 | Xcode 번들 |
| **Sourcery** | 코드 생성 (모킹 등) | `brew install sourcery` |
| **Tuist** (선택) | 프로젝트 생성 자동화 | `brew install tuist` |
| **direnv** | 디렉토리별 환경변수 로딩 | `brew install direnv` |
| **mise** | 도구 버전 매니저 (Xcode 외) | `brew install mise` |

---

## 4. 외부 계정 / 서비스 셋업 (요약)

> 자세한 가입/구성 절차는 [EXTERNAL_SETUP.md](./EXTERNAL_SETUP.md)를 참조한다. 여기서는 첫 빌드까지 필요한 최소 항목만 나열한다.

### 4.1 Apple Developer Program (필수, 첫 빌드 전)
- https://developer.apple.com/programs/ — 가입 ($99/yr)
- 개인 / 조직 / 사업자 중 선택
- 가입 완료까지 1~3 영업일 소요 (조직은 D-U-N-S 검증 필요)

### 4.2 App Store Connect 앱 레코드
- https://appstoreconnect.apple.com → My Apps → "+" → New App
- Bundle ID: `com.filtermarket.ios` (Apple Developer 콘솔 Identifiers에서 사전 등록)
- Capabilities 활성화:
  - **Sign in with Apple**
  - **Push Notifications** (Phase 3)
  - **Associated Domains** (Universal Link, Phase 3)
  - **App Attest** (Phase 5)

### 4.3 Apple Sign in Service ID
- Identifiers → Services IDs → 신규
  - Identifier: `com.filtermarket.signin`
  - Return URL: `https://filtermarket-{env}.firebaseapp.com/__/auth/handler`

### 4.4 Firebase 콘솔
- https://console.firebase.google.com → 프로젝트 신규 (3개)
  - `filtermarket-dev`
  - `filtermarket-staging`
  - `filtermarket-prod`
- 각 프로젝트 → 앱 추가 (iOS) → Bundle ID 입력 → `GoogleService-Info.plist` 다운로드
- 활성화할 서비스: Authentication (Apple/Google providers), Firestore (asia-northeast3), Cloud Functions (Node 20), Cloud Messaging
- 다운로드한 plist 위치: `Sources/App/Resources/Firebase/{env}/GoogleService-Info.plist` (env별 폴더 분리, 빌드 컨피그로 선택)

### 4.5 Cloudflare R2
- https://dash.cloudflare.com → R2
- 버킷 생성: `filtermarket-prod`, `filtermarket-staging`, `filtermarket-dev`
- API 토큰 발급: Account → R2 → "Manage R2 API Tokens" → Object Read/Write
- 토큰은 시크릿 매니저에 저장 (로컬은 `.env.local`에 임시 보관, 절대 커밋 금지)

### 4.6 Google Cloud Console (OAuth)
- Firebase 프로젝트와 동일한 GCP 프로젝트 사용 OK
- APIs & Services → Credentials → OAuth 2.0 Client ID (iOS)
- iOS Bundle ID 입력 → `REVERSED_CLIENT_ID`를 Info.plist URL Scheme에 등록

> Algolia, Sentry, PostHog는 Phase 1 끝물 / Phase 4에서 추가 — 첫 빌드에는 불필요.

---

## 5. 로컬 환경 변수 / 시크릿 관리

### 5.1 원칙
1. 시크릿은 절대 git에 커밋하지 않는다
2. CI/Xcode Cloud는 Environment Variables + Secret Manager 사용
3. 로컬은 `.env` (또는 `.xcconfig`)에 보관하고 `.gitignore`에 등록

### 5.2 `.xcconfig` 사용 (권장)

```text
# Configurations/Debug.xcconfig
FIREBASE_PROJECT_ID = filtermarket-dev
R2_BUCKET = filtermarket-dev
R2_ENDPOINT = https://<account-id>.r2.cloudflarestorage.com
GOOGLE_OAUTH_CLIENT_ID = 1234567890-abcdef.apps.googleusercontent.com
APPLE_SIGN_IN_SERVICE_ID = com.filtermarket.signin

// 시크릿: Xcode Cloud Environment Variables로 주입
// 로컬은 별도 Configurations/Debug.local.xcconfig (gitignore)
```

`Info.plist`에서 `$(KEY_NAME)` 보간으로 사용. 빌드 컨피그에 따라 자동 전환된다.

### 5.3 `.env` 패턴 (Functions, 스크립트용)

```bash
# .env.local (gitignore)
R2_ACCESS_KEY_ID=...
R2_SECRET_ACCESS_KEY=...
FIREBASE_TOKEN=...        # firebase login:ci 결과
```

`direnv`로 디렉토리 진입 시 자동 로딩:
```bash
echo "dotenv .env.local" > .envrc
direnv allow
```

### 5.4 `.gitignore` 필수 항목

```gitignore
# Secrets
*.local.xcconfig
.env
.env.local
.env.*.local

# Firebase
GoogleService-Info.plist           # plist는 env별 폴더에 보관 → 일반 plist는 무시
!Sources/App/Resources/Firebase/**/GoogleService-Info.plist  # 명시 허용

# Build
DerivedData/
build/
*.xcuserstate
*.xcuserdatad
fastlane/report.xml
```

---

## 6. 첫 빌드 절차

```bash
# 1. 클론
gh repo clone <org>/filterMarket
cd filterMarket

# 2. 부트스트랩 (스크립트 또는 수동)
./scripts/bootstrap.sh
#   - Homebrew 의존성 확인
#   - SwiftPM 의존성 resolve
#   - Fastlane match (인증서 동기화)
#   - Firebase plist 위치 검증

# 3. Xcode로 열기
open filterMarket.xcworkspace

# 4. 스킴 / 컨피그 선택
#   - Scheme: filterMarket-Debug
#   - Destination: iPhone 15 Pro (Simulator)

# 5. 빌드 + 실행 (Cmd+R)
```

CLI 빌드(시뮬레이터):
```bash
xcodebuild -workspace filterMarket.xcworkspace \
  -scheme filterMarket-Debug \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.5' \
  build | xcbeautify
```

테스트 실행:
```bash
xcodebuild test \
  -workspace filterMarket.xcworkspace \
  -scheme filterMarket-Debug \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.5' \
  | xcbeautify
```

Firebase 에뮬레이터(통합 테스트):
```bash
firebase emulators:start --only auth,firestore,functions
```

---

## 7. 셋업 검증 체크리스트

- [ ] `xcodebuild -version` 가 15.4+ 출력
- [ ] `swift --version` 가 5.10+ 출력
- [ ] `swiftlint --version`, `swiftformat --version`, `fastlane --version` 정상
- [ ] Apple Developer 계정으로 Xcode 사이닝 가능
- [ ] `GoogleService-Info.plist` (3 환경) 존재
- [ ] `Configurations/Debug.local.xcconfig` 작성 (시크릿 주입)
- [ ] iPhone 15 Pro Simulator 부팅 + 앱 실행
- [ ] 실기기 배포 1회 성공 (provisioning 검증)
- [ ] `firebase emulators:start` 정상 동작
- [ ] `swiftlint` PR 차단 룰 통과

---

## 8. 자주 발생하는 문제 (Troubleshooting)

### 8.1 "No matching provisioning profile found"
- 원인: Apple Developer 콘솔과 Xcode 사이닝 불일치
- 해결: `fastlane match development` 실행 → 인증서/프로파일 동기화

### 8.2 "Module 'FirebaseCore' not found"
- 원인: SwiftPM 캐시 손상
- 해결:
  ```bash
  rm -rf ~/Library/Developer/Xcode/DerivedData
  xcodebuild -resolvePackageDependencies
  ```

### 8.3 "GoogleService-Info.plist not found at runtime"
- 원인: Build Phase의 Copy Bundle Resources에 누락 또는 컨피그별 폴더 잘못
- 해결: `Sources/App/Resources/Firebase/{Debug|Staging|Release}/GoogleService-Info.plist` 경로 확인 + Build Settings의 `FIREBASE_PLIST_PATH = $(SRCROOT)/Sources/App/Resources/Firebase/$(CONFIGURATION)`

### 8.4 시뮬레이터에서 카메라 미지원
- iOS Simulator는 카메라 하드웨어 시뮬레이션 제한 — 실기기 사용 필수
- 카메라 PoC/디버깅은 iPhone 12+ 실기기 권장

### 8.5 Metal 컴파일 에러 "fatal error: 'metal_stdlib' file not found"
- 원인: Xcode 명령행 도구 버전 불일치
- 해결: `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`

### 8.6 `swift build` Strict Concurrency 에러
- Swift 6 모드 활성화 시 발생 가능
- Phase 0~1: 일부 모듈만 strict 적용, 나머지는 `-strict-concurrency=minimal`
- 해결 가이드: [CODING_CONVENTIONS.md](./CODING_CONVENTIONS.md) §4 동시성

### 8.7 Sign in with Apple 시뮬레이터 "AKAuthenticationError -7026"
- 원인: 시뮬레이터에 iCloud 미로그인
- 해결: 시뮬레이터 Settings → Apple Account 로그인, 또는 실기기 사용

---

## 9. 다음 단계

- 코딩 컨벤션: [CODING_CONVENTIONS.md](./CODING_CONVENTIONS.md)
- 외부 계정 풀 셋업: [EXTERNAL_SETUP.md](./EXTERNAL_SETUP.md)
- 테스트 전략: [TESTING_STRATEGY.md](./TESTING_STRATEGY.md)
- Firestore 보안 룰: [FIRESTORE_RULES.md](./FIRESTORE_RULES.md)
- API 스펙: [API_SPEC.md](./API_SPEC.md)
- `.fmpkg` 포맷: [FMPKG_SCHEMA.md](./FMPKG_SCHEMA.md)

---

## 10. 관련 문서

- [README.md](./README.md)
- [TECH_STACK.md](./TECH_STACK.md) — 도구 선택 근거
- [ARCHITECTURE.md](./ARCHITECTURE.md) — 모듈 구성
