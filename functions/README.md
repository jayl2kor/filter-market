# moodit — Cloud Functions

Firebase Cloud Functions (gen 2) backend for moodit. Runs alongside the iOS app in this repo.

## 스택

- **Runtime**: Node 20 on Cloud Functions for Firebase (gen 2)
- **언어**: TypeScript 5.5
- **트리거**: HTTPS Callable (`onCall`) + Firestore triggers (`onDocumentCreated/Updated`)
- **R2**: `@aws-sdk/client-s3` + `@aws-sdk/s3-request-presigner` (egress 무료)
- **Rate limit / Idempotency**: `ioredis` (Memorystore) — Phase 2 이후 wired
- **검증**: `zod` (request schema)

## 디렉토리

```
functions/
├── package.json   tsconfig.json   .eslintrc.cjs
└── src/
    ├── index.ts          # 모든 함수 re-export (배포 단위)
    ├── http/             # API_SPEC.md §4 엔드포인트
    │   ├── filters.ts    # uploadInit / uploadFinalize / submitForReview / use / getFilterDetail / report
    │   ├── moderation.ts # approveFilter / rejectFilter
    │   ├── identity.ts   # setHandle / deleteAccount
    │   └── purchases.ts  # Phase 6 placeholder
    ├── triggers/         # Firestore 트리거
    │   └── index.ts      # onFilterPublished / onReportCreated
    ├── lib/              # auth / envelope / errors / r2 / ratelimit / idempotency
    └── types/            # Firestore 도큐먼트 + .fmpkg manifest 타입
```

## 단일 소스 (../docs/)

- [API_SPEC.md](../docs/API_SPEC.md) — 엔드포인트 카탈로그, envelope, 에러코드, idempotency, rate limit
- [FMPKG_SCHEMA.md](../docs/FMPKG_SCHEMA.md) — `.fmpkg` 매니페스트 스키마
- [FIRESTORE_RULES.md](../docs/FIRESTORE_RULES.md) — `firestore.rules`의 단일 소스 (배포 mirror는 ../firestore.rules)
- [TECH_STACK.md §4](../docs/TECH_STACK.md) — 백엔드 결정

## 로컬 실행 (구현 후)

```bash
# 1. 의존성 설치
cd functions && npm install

# 2. 빌드 워치
npm run build:watch

# 3. 에뮬레이터 (다른 터미널, 리포 루트에서)
cd ..
firebase emulators:start --only auth,functions,firestore
# → Functions   http://localhost:5001
# → Firestore   http://localhost:8080
# → Auth        http://localhost:9099
# → UI          http://localhost:4000
```

## 시크릿 (배포 시)

```bash
firebase functions:secrets:set R2_ACCOUNT_ID
firebase functions:secrets:set R2_ACCESS_KEY_ID
firebase functions:secrets:set R2_SECRET_ACCESS_KEY
firebase functions:secrets:set REDIS_URL
```

## 배포

```bash
# Staging (default)
npm run deploy:staging

# Production
npm run deploy:prod

# 단일 함수만
firebase deploy --only functions:uploadInit
```

## 상태

현재 단계: **스캐폴드** — 모든 핸들러는 `unimplemented` 시그니처. 다음 마일스톤은 [`../docs/API_SPEC.md`](../docs/API_SPEC.md) §5 핵심 엔드포인트 구현.
