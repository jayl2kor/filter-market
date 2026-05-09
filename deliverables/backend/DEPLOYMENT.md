# Deployment & Environments

> 단일 소스: `firebase.json`, `functions/package.json`, `functions/README.md`.

---

## 1. 환경

| 환경 | Firebase project | 비고 |
|---|---|---|
| dev | (선택) — 로컬 에뮬레이터 위주 | Auth + Functions + Firestore + Storage(deny) + UI |
| staging | `moodit-staging` | 사전 승인 후 프로덕션과 동일 빌드 |
| prod | `moodit-prod` (또는 `moodit`) | `api.moodit.app` 도메인 (예정) |

리전: 모든 함수가 `asia-northeast3` (Seoul) 고정.
런타임: Node 20 (`firebase.json:13`).

---

## 2. 시크릿

`firebase functions:secrets:set <NAME>` 로 등록.

| 시크릿 | 사용 함수 | 설명 |
|---|---|---|
| `R2_ENDPOINT` | filters/identity (R2 사용 함수) | Cloudflare R2 S3 호환 엔드포인트 |
| `R2_ACCESS_KEY_ID` | 동일 | R2 액세스 키 |
| `R2_SECRET_ACCESS_KEY` | 동일 | R2 시크릿 |
| `R2_BUCKET` | 동일 | R2 버킷 이름 |
| `R2_PUBLIC_BASE_URL` | review/sample/avatar 업로드 | 공개 CDN 베이스 URL |
| `APP_APPLE_ID` | wallet | Apple App ID |
| `APP_STORE_ENV` | wallet | `Production` 또는 `Sandbox` |
| `REDIS_URL` | (예정) | Memorystore Redis 이전 시 |

각 callable의 `secrets:` 옵션으로 명시적 바인딩되어 있으며 cold-start 시 `process.env`에 노출.

---

## 3. 로컬 에뮬레이터

```bash
cd functions && npm install
npm run build:watch        # 다른 터미널
cd ..
firebase emulators:start --only auth,functions,firestore
```

- Auth: localhost:9099
- Functions: localhost:5001
- Firestore: localhost:8080
- Storage(차단됨): 9199 (deny rules)
- UI: localhost:4000

iOS 시뮬레이터는 `useEmulator` 분기로 로컬 endpoint 호출.

---

## 4. 빌드 & 테스트

```bash
cd functions
npm run lint             # eslint --ext .ts src
npm run build            # tsc → lib/
npm test                 # node --test (8개 .test.mjs)
npm run test:rules       # firestore-rules.test.mjs (Java 필요)
```

`predeploy` 훅 (firebase.json:21-24) 에서 lint + build 자동 실행 — 빌드 실패 시 배포 차단.

---

## 5. 배포

```bash
# 빌드 + 전체 함수 배포 (staging)
npm run deploy:staging
# → firebase use staging && firebase deploy --only functions

# 프로덕션
npm run deploy:prod

# 단일 함수만
firebase deploy --only functions:purchaseFilter

# 룰 / 인덱스 배포 (필수 — functions와 분리 가능)
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
firebase deploy --only storage
```

> **함수와 룰은 항상 함께 검증**. `firestore.rules` 의 `hasReviewEntitlement` 와 백엔드의 동일 함수가 일치하는지 코드 리뷰 시 확인.

---

## 6. 모니터링 / 로그

```bash
firebase functions:log                            # 최근 로그
firebase functions:log --only purchaseFilter      # 단일 함수
```

Stackdriver / Cloud Logging 콘솔에서 에러율, p95 latency, cold-start 메트릭 확인.

---

## 7. 롤백

- `firebase deploy --only functions:<name>` 로 이전 빌드를 다시 배포.
- 함수 삭제: `firebase functions:delete <name> --region asia-northeast3`.
- Firestore 룰 롤백: 이전 룰 파일을 commit으로 되돌리고 재배포.

---

## 8. 부트스트랩 / 운영 도구

| 도구 | 위치 | 용도 |
|---|---|---|
| `bootstrap-admin.mjs` | `tools/` (계획) | 첫 admin role 클레임 부여 |
| `firestore-debug.log` | `functions/firestore-debug.log` | 에뮬레이터 디버그 로그 (gitignore) |
| `certs/` | `functions/certs/` | 로컬 테스트용 인증서 (필요 시) |

---

## 9. CI/CD 권장 (현재 미설정)

- Branch `main` push → GitHub Actions:
  1. `npm ci` (functions/)
  2. `npm run lint && npm run build`
  3. `npm test`
  4. (옵션) `firebase deploy --only functions` (staging)
- Tag 배포: `vX.Y.Z` 태그 → prod 배포 + Slack 알림.

CI는 모더레이터 키, R2 시크릿을 GitHub Secrets로 보관 후 Firebase 토큰으로 deploy. (`FIREBASE_TOKEN`)

---

## 10. 비용 가이드

| 항목 | 비용 패턴 |
|---|---|
| Functions invocation | 호출 수 + GB-seconds. 콜드스타트 < 1s 목표 |
| Firestore | read/write/delete 수 — 카운터 트리거가 read-heavy. recalculateReviewStats는 리뷰 많은 필터에서 비용↑ |
| R2 | egress 무료, GET/PUT 요청만 과금. presigned URL TTL 10분 → 재요청 캐시 X |
| Apple JWS verifier | 자체 호출 비용 X (라이브러리만 사용) |
| FCM | 무료 (대량 발송 시 배치 권장) |
