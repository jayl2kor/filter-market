# Authentication & Authorization

> 단일 소스: `functions/src/lib/auth.ts`, `firestore.rules` 헬퍼, `firebase.json`.

---

## 1. 인증 토큰

- **Firebase ID Token** (Auth) — RS256 JWT, TTL 1시간, SDK가 자동 갱신.
- 모든 callable: `Authorization: Bearer <ID Token>` 헤더 필수 (Firebase SDK가 자동 첨부).
- 익명 로그인: 사용 안 함. 모든 인증 사용자는 영구 계정 (Apple/Google/Email).

## 2. App Check
- 모든 callable에 `enforceAppCheck: true` 적용.
- 미설정/위조 디바이스는 호출 자체가 차단됨 (해커 추가 차단 레이어).
- 클라이언트는 App Attest(iOS 14+) 또는 DeviceCheck로 토큰 발급.

## 3. 권한 모델 (Custom Claims)

```
role ∈ { "admin", "moderator", null }
```

- `null` 또는 클레임 없음 → 일반 사용자(`"user"` 취급).
- 클레임 부여: `setRole` callable (admin only) → `getAuth().setCustomUserClaims(uid, {role})`.
- **부트스트랩**: 첫 admin 계정은 `tools/bootstrap-admin.mjs` (서비스 계정 키 사용) 으로 직접 부여.

| 헬퍼 | 통과 조건 | 사용처 |
|---|---|---|
| `requireAuth(req)` | `req.auth.uid` 존재 | 거의 모든 callable |
| `requireAdmin(req)` | role == `admin` | `setRole` |
| `requireModerator(req)` | role ∈ {`admin`, `moderator`} | `approveFilter`, `rejectFilter`, `undoModerationDecision` |

`firestore.rules` 헬퍼와 일치:
```
function role()           { return token.get('role', 'user'); }
function isModerator()    { return role() in ['moderator', 'admin']; }
function isAdmin()        { return role() == 'admin'; }
```

---

## 4. Entitlement (필터 접근권)

`firestore.rules` 의 `hasReviewEntitlement(filterId)` 와 백엔드의 `hasReviewEntitlement(db, uid, filterId)` 가 동일 정책:

> 셋 중 하나라도 만족하면 entitled
> 1. `users/{uid}/savedFilters/{filterId}` 존재 (라이브러리 추가)
> 2. `users/{uid}/entitlements/{filterId}` 존재 (구매)
> 3. `users/{uid}/proStatus/status.active == true` (Pro 구독)

**주의**: 무료 필터(`priceCoins == 0`) 는 클라이언트 가이드상 자동 라이브러리 추가로 entitled 상태 확보.
유료 필터(`priceCoins > 0`)는 `purchaseFilter`로 entitlement 발급 후 접근.

---

## 5. 메이커 식별

- `isFilterMaker(filterId)` → `filters/{filterId}.authorUid == auth.uid`.
- 서버 함수에서는 `filterAuthorUid(data)` 헬퍼로 `data.authorUid` 또는 `data.author.uid` 추출 (둘 다 지원하는 호환 코드).
- 메이커 권한 적용:
  - 본인 필터 라이프사이클 (`uploadFinalize`, `submitForReview`)
  - 본인 필터 리뷰에 maker reply 첨부 (rules)
  - 자기 필터에 리뷰 작성 금지

---

## 6. 모더레이터 권한

- 큐 작업: `approveFilter`, `rejectFilter`, `undoModerationDecision`.
- 데이터 액세스: `firestore.rules` 에서 일부 모더레이터 조건 미명시 — Cloud Function 경유 필수.
- 신고 큐 (`/filters/{id}/reports`, `/users/{uid}/reports`): rules에서 일반 사용자 read 차단. 모더레이터 콘솔(앞으로 구현)이 admin SDK 또는 별도 callable 경유.

---

## 7. App Store / Apple JWS

`creditCoinsFromIAP` / `proSubscriptionUpdate`:
- Apple JWS는 `@apple/app-store-server-library` 의 verifier로 검증.
- 시크릿: `APP_APPLE_ID` (앱 식별자), `APP_STORE_ENV` (`Production`/`Sandbox`).
- 검증 실패 → `permission-denied: receipt_verification_failed` (HttpsError).
- 영수증 멱등성 → `walletReceipts/{originalTransactionId}` 단일 문서 (서버 전용).

---

## 8. 위험 시나리오 & 가드

| 시나리오 | 가드 |
|---|---|
| 다른 uid가 같은 IAP receipt를 claim | `walletReceipts.uid != caller` → `permission-denied: receipt_belongs_to_another_user` (#48) |
| 비인증자가 유료 필터 presigned download URL 획득 | `getFilterDetail`이 `requireAuth(req)` 강제 (#46) |
| 사용자가 자기 자신 신고 | `reportUser` `failed-precondition: cannot report self` |
| 메이커가 자기 필터에 리뷰 | `submitReview` + rules 모두에서 차단 |
| App Check 우회 (sniffed token) | callable 자체가 거부 |
| 핸들 동시 클레임 경쟁 | Firestore 트랜잭션 + `handles/{handle}` 키 충돌 |
| 클라이언트가 wallet/balance 위변조 | rules에서 모든 wallet 경로 `write: if false` |
