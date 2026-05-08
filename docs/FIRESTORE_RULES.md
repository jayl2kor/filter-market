# moodit - Firestore Security Rules 초안

> 버전: v1.0 · 작성일: 2026-05-06
>
> 본 문서는 Firestore 보안 규칙의 정식 초안 + 헬퍼 함수 + 인덱스 + 검증 시나리오를 정의한다. 코드 블록은 그대로 `firestore.rules`에 사용 가능한 형태이며, Firebase Emulator로 검증한다 (참고: [TESTING_STRATEGY.md](./TESTING_STRATEGY.md)).

---

## 1. 설계 원칙

1. **default deny**: 명시적 allow 없으면 거부
2. **데이터 검증**: 클라이언트 직접 쓰기 시 `request.resource.data` 필드 타입/길이/enum 검증
3. **권한 분리**: `user`/`moderator`/`admin` Custom Claim
4. **민감 작업은 Cloud Function**: 카운터, 결제, 모더레이션 액션은 보안 룰만으로 충분치 않음 → 함수에서 검증 후 admin SDK로 쓰기
5. **읽기 비용 통제**: 룰에서 추가 read를 최소화 (룰의 `get()`/`exists()` 호출은 비용)

---

## 2. 헬퍼 함수

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // ---- 헬퍼 ----
    function isAuthenticated() {
      return request.auth != null;
    }
    function isOwner(uid) {
      return isAuthenticated() && request.auth.uid == uid;
    }
    function role() {
      return isAuthenticated() ? request.auth.token.get('role', 'user') : 'guest';
    }
    function isModerator() {
      return role() in ['moderator', 'admin'];
    }
    function isAdmin() {
      return role() == 'admin';
    }

    function hasOnly(fields) {
      return request.resource.data.keys().hasOnly(fields);
    }
    function hasAll(fields) {
      return request.resource.data.keys().hasAll(fields);
    }

    function isValidString(field, minLen, maxLen) {
      return field is string && field.size() >= minLen && field.size() <= maxLen;
    }

    function isUnchanged(field) {
      return resource.data[field] == request.resource.data[field];
    }

    function statusIs(s) {
      return resource.data.status == s;
    }

    // ---- 검증 ----
    function validUserData(d) {
      return d.keys().hasOnly(['displayName', 'avatarUrl', 'bio', 'signingPublicKey', 'notificationPrefs', 'stats', 'createdAt', 'updatedAt'])
        && isValidString(d.displayName, 1, 40)
        && (!('bio' in d) || isValidString(d.bio, 0, 280))
        && (!('signingPublicKey' in d) || (d.signingPublicKey is string && d.signingPublicKey.size() == 44)); // base64 32 bytes
    }

    function validFilterCreate(d) {
      return d.keys().hasAll(['authorUid','title','category','engine','status','version','createdAt'])
        && d.authorUid == request.auth.uid
        && isValidString(d.title, 1, 60)
        && d.category in ['cinematic','vintage','pastel','bw','portrait','food','travel','anime','mood','bright','moody','skin']
        && d.engine.type in ['lut+params','lut+msl','nodegraph']
        && d.status == 'PENDING'
        && d.version.matches('^\\d+\\.\\d+\\.\\d+$');
    }

    function validRating(d) {
      return d.keys().hasOnly(['stars','createdAt'])
        && d.stars is int && d.stars >= 1 && d.stars <= 5;
    }

    function validComment(d) {
      return d.keys().hasOnly(['authorUid','body','parentCommentId','createdAt','status'])
        && d.authorUid == request.auth.uid
        && isValidString(d.body, 1, 1000)
        && d.status == 'visible';
    }

    function validReport(d) {
      return d.keys().hasOnly(['reporterUid','targetType','targetId','reason','detail','status','createdAt'])
        && d.reporterUid == request.auth.uid
        && d.targetType in ['filter','user','comment']
        && d.reason in ['NSFW','COPYRIGHT','SPAM','VIOLENCE','OTHER']
        && (!('detail' in d) || isValidString(d.detail, 0, 500))
        && d.status == 'open';
    }

    // 콜렉션별 규칙은 §3 참조
  }
}
```

---

## 3. 콜렉션별 규칙

### 3.1 `users/{uid}` — 사용자 프로필

```javascript
match /users/{uid} {
  allow read: if true;  // 공개 프로필
  allow create: if isOwner(uid)
    && validUserData(request.resource.data);
  allow update: if isOwner(uid)
    && validUserData(request.resource.data)
    // stats는 클라이언트가 못 바꿈
    && (!('stats' in request.resource.data.diff(resource.data).affectedKeys()))
    // signingPublicKey는 비워두거나 한 번만 설정 (회전은 Cloud Function)
    && (
      !('signingPublicKey' in resource.data) ||
      isUnchanged('signingPublicKey')
    );
  allow delete: if isAdmin();
}
```

> private 필드(이메일 등)는 별도 `users/{uid}/private/profile` 서브문서에 두고 `read: if isOwner(uid)`만 허용.

#### `users/{uid}/private/{doc}`
```javascript
match /users/{uid}/private/{doc} {
  allow read, write: if isOwner(uid);
}
```

#### `users/{uid}/devices/{deviceId}` — APNs 토큰
```javascript
match /users/{uid}/devices/{deviceId} {
  allow read, write: if isOwner(uid);
}
```

### 3.2 `filters/{filterId}` — 필터 메타

```javascript
match /filters/{filterId} {
  // 누구나 PUBLISHED 필터 read, 비공개는 작성자/모더레이터
  allow read: if resource.data.status == 'PUBLISHED'
    || (isAuthenticated() && resource.data.authorUid == request.auth.uid)
    || isModerator();

  // 생성: 작성자만, status는 PENDING으로만 시작
  allow create: if isAuthenticated()
    && validFilterCreate(request.resource.data);

  // 수정: 작성자가 PENDING/REJECTED 상태일 때만 메타 수정 가능
  // status 변경은 모더레이터만
  allow update: if (
    // 작성자: 본인이고, status 필드는 못 바꿈 (재제출은 Cloud Function)
    isOwner(resource.data.authorUid)
      && resource.data.status in ['PENDING','REJECTED']
      && isUnchanged('status')
      && isUnchanged('authorUid')
      && isUnchanged('createdAt')
      && (!('metrics' in request.resource.data.diff(resource.data).affectedKeys()))
  ) || (
    // 모더레이터: status 필드만 변경 가능
    isModerator()
      && request.resource.data.diff(resource.data).affectedKeys()
           .hasOnly(['status','moderatedAt','moderatedBy','rejectionReason','publishedAt'])
  );

  allow delete: if isOwner(resource.data.authorUid) || isAdmin();
}
```

#### `filters/{filterId}/ratings/{uid}` — 별점

```javascript
match /filters/{filterId}/ratings/{raterUid} {
  allow read: if true;
  allow create: if isOwner(raterUid)
    && validRating(request.resource.data)
    && exists(/databases/$(database)/documents/filters/$(filterId))
    && get(/databases/$(database)/documents/filters/$(filterId)).data.status == 'PUBLISHED';
  allow update: if isOwner(raterUid) && validRating(request.resource.data);
  allow delete: if isOwner(raterUid) || isModerator();
}
```

#### `filters/{filterId}/comments/{commentId}` — 댓글

```javascript
match /filters/{filterId}/comments/{commentId} {
  allow read: if resource.data.status == 'visible' || isModerator();
  allow create: if isAuthenticated() && validComment(request.resource.data);
  allow update: if isOwner(resource.data.authorUid)
    && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['body','updatedAt']);
  allow delete: if isOwner(resource.data.authorUid) || isModerator();
}
```

### 3.3 `users/{uid}/favorites/{filterId}` — 즐겨찾기

```javascript
match /users/{uid}/favorites/{filterId} {
  allow read, write: if isOwner(uid);
}
```

### 3.4 `users/{uid}/downloads/{filterId}` — 다운로드 이력

```javascript
match /users/{uid}/downloads/{filterId} {
  allow read: if isOwner(uid);
  // 직접 쓰기 금지 — Cloud Function이 admin SDK로 작성
  allow write: if false;
}
```

### 3.5 `follows/{followerUid}_{followingUid}`

```javascript
match /follows/{relationId} {
  allow read: if true;
  allow create: if isAuthenticated()
    && relationId == request.auth.uid + '_' + request.resource.data.followingUid
    && request.resource.data.followerUid == request.auth.uid
    && request.resource.data.followerUid != request.resource.data.followingUid
    && request.resource.data.keys().hasOnly(['followerUid','followingUid','createdAt']);
  allow delete: if isAuthenticated()
    && resource.data.followerUid == request.auth.uid;
  allow update: if false;
}
```

### 3.6 `reports/{reportId}` — 신고

```javascript
match /reports/{reportId} {
  // 본인 신고만 read, 모더레이터는 모두 read
  allow read: if isOwner(resource.data.reporterUid) || isModerator();
  allow create: if isAuthenticated() && validReport(request.resource.data);
  // 작성 후 수정 불가, 처리 결과만 모더레이터가 갱신
  allow update: if isModerator()
    && request.resource.data.diff(resource.data).affectedKeys()
         .hasOnly(['status','resolvedBy','resolvedAt','resolution']);
  allow delete: if isAdmin();
}
```

### 3.7 `recommendations/{uid}` — 추천 캐시 (Phase 4+)

```javascript
match /recommendations/{uid} {
  allow read: if isOwner(uid);
  allow write: if false;  // 추천 워커만 (admin SDK)
}
```

### 3.8 `notifications/{uid}/items/{itemId}` — 인앱 알림

```javascript
match /notifications/{uid}/items/{itemId} {
  allow read: if isOwner(uid);
  allow update: if isOwner(uid)
    && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['readAt']);
  allow create, delete: if false;  // Cloud Function이 작성
}
```

### 3.9 사용자 지갑/보유권 서브컬렉션

> 실제 앱/Functions 경로 기준. 모든 write는 Cloud Functions(Admin SDK)만 수행하고, 클라이언트는 본인 uid 아래의 파생 상태만 read 한다.

```javascript
match /users/{uid}/wallet/{doc} {
  allow read: if isOwner(uid);
  allow write: if false;
}
match /users/{uid}/savedFilters/{filterId} {
  allow read: if isOwner(uid);
  allow create, update: if isOwner(uid)
    && request.resource.data.filterId == filterId;
  allow delete: if isOwner(uid);
}
match /users/{uid}/favorites/{filterId} {
  allow read: if isOwner(uid);
  allow create, update: if isOwner(uid)
    && request.resource.data.filterId == filterId;
  allow delete: if isOwner(uid);
}
match /users/{uid}/exportRequests/{requestId} {
  allow read: if isOwner(uid);
  allow create: if isOwner(uid)
    && request.resource.data.status == "requested"
    && request.resource.data.categories is list
    && request.resource.data.format in ["JSON", "CSV"];
  allow update, delete: if false;
}
match /users/{uid}/makerDrafts/{draftId} {
  allow read: if isOwner(uid);
  allow create, update: if isOwner(uid)
    && request.resource.data.status in ["draft", "pending", "rejected", "live"]
    && request.resource.data.name is string
    && request.resource.data.category is string;
  allow delete: if isOwner(uid);
}
match /users/{uid}/editorDrafts/{draftId} {
  allow read, create, update, delete: if isOwner(uid);
}
match /users/{uid}/reviewHelpful/{edgeId} {
  allow read: if isOwner(uid);
  allow create: if isOwner(uid)
    && request.resource.data.filterId is string
    && request.resource.data.reviewId is string;
  allow delete: if isOwner(uid);
  allow update: if false;
}
match /users/{uid}/walletLedger/{entryId} {
  allow read: if isOwner(uid);
  allow write: if false;
}
match /users/{uid}/entitlements/{filterId} {
  allow read: if isOwner(uid);
  allow write: if false;
}
match /users/{uid}/proStatus/{doc} {
  allow read: if isOwner(uid);
  allow write: if false;
}
match /users/{uid}/refundRequests/{reqId} {
  allow read: if isOwner(uid);
  allow write: if false;
}
```

### 3.10 `auditLogs/{logId}` — 감사 로그

```javascript
match /auditLogs/{logId} {
  allow read: if isAdmin();
  allow write: if false;
}
```

### 3.11 `wallets/{uid}` — 사용자 지갑 (Phase 6)

> [`CURRENCY_DESIGN.md`](./CURRENCY_DESIGN.md) §8.2. 모든 잔액 변경은 Cloud Functions 트랜잭션으로만 가능.

```javascript
match /wallets/{uid} {
  allow read: if isOwner(uid);
  allow write: if false;  // 모든 mutate는 서버 트랜잭션 한정
}
```

### 3.12 `transactions/{txId}` — 거래 ledger (Phase 6)

```javascript
match /transactions/{txId} {
  allow read: if isAuthed() && resource.data.uid == request.auth.uid;
  allow write: if false;  // append-only via Cloud Functions
}
```

### 3.13 `payouts/{payoutId}` — 메이커 출금 요청 (Phase 6)

```javascript
match /payouts/{payoutId} {
  allow read: if isAuthed() && resource.data.uid == request.auth.uid;
  allow write: if false;  // /me/withdraw Cloud Function만
}
```

### 3.14 `topupIntents/{intentId}` — IAP 충전 의도 토큰 (Phase 6)

```javascript
match /topupIntents/{intentId} {
  allow read, write: if false;  // 클라이언트 직접 접근 차단 — Cloud Function 전용
}
```

### 3.15 `config/{doc}` — 공개 설정 (코인 패키지·환율·임계치)

```javascript
match /config/{doc} {
  allow read: if true;        // 카탈로그는 공개 캐시
  allow write: if isAdmin();  // 운영팀 콘솔로만
}
```

---

## 4. Composite Index 정의

`firestore.indexes.json` 으로 관리.

```json
{
  "indexes": [
    {
      "collectionGroup": "filters",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "category", "order": "ASCENDING" },
        { "fieldPath": "metrics.downloads", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "filters",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "filters",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "authorUid", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "filters",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "tags", "arrayConfig": "CONTAINS" },
        { "fieldPath": "metrics.downloads", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "comments",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "ratings",
      "queryScope": "COLLECTION_GROUP",
      "fields": [
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "follows",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "followerUid", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "follows",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "followingUid", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "reports",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "ASCENDING" }
      ]
    }
  ],
  "fieldOverrides": []
}
```

---

## 5. 데이터 검증 규칙 (필드별)

| 필드 | 타입 | 제약 | 검증 위치 |
|---|---|---|---|
| `users.displayName` | string | 1~40자 | rules + Cloud Function |
| `users.bio` | string | 0~280자 | rules |
| `users.signingPublicKey` | string | 44자 base64 (32B) | rules + Function on register |
| `filters.title` | string | 1~60자 | rules + Function |
| `filters.category` | enum | 12개 시스템 카테고리 | rules |
| `filters.tags` | string[] | ≤12, 각 ≤24자 | rules |
| `filters.engine.type` | enum | `lut+params`/`lut+msl`/`nodegraph` | rules |
| `filters.status` | enum | `PENDING`/`PUBLISHED`/`REJECTED`/`TAKEDOWN` | rules + Function |
| `filters.version` | string | semver | rules |
| `ratings.stars` | int | 1~5 | rules |
| `comments.body` | string | 1~1000자 | rules |
| `reports.reason` | enum | 5종 | rules |

---

## 6. Firebase Emulator 테스트 시나리오

### 6.1 셋업
```bash
firebase init emulators                    # firestore + auth
firebase emulators:exec --only firestore "npm test"
```

### 6.2 테스트 매트릭스

#### `users/{uid}`
- [ ] 게스트가 임의 uid 프로필 read → 성공
- [ ] 다른 사용자가 본인 프로필 update → 거부
- [ ] 본인이 displayName 41자 → 거부
- [ ] 본인이 stats 변경 시도 → 거부
- [ ] 본인이 signingPublicKey 두 번째 set → 거부 (Cloud Function 경유 필요)

#### `filters/{filterId}`
- [ ] 게스트가 PUBLISHED 필터 read → 성공
- [ ] 게스트가 PENDING 필터 read → 거부
- [ ] 작성자가 본인의 PENDING read → 성공
- [ ] 모더레이터가 임의 필터 read → 성공
- [ ] 사용자가 status=PUBLISHED로 직접 생성 시도 → 거부
- [ ] 작성자가 PENDING에서 title 수정 → 성공
- [ ] 작성자가 status=PUBLISHED 직접 변경 → 거부
- [ ] 모더레이터가 status=PUBLISHED 변경 → 성공
- [ ] 모더레이터가 title 같이 변경 → 거부 (status만 허용)
- [ ] 다른 사용자가 작성자 필드 변경 → 거부

#### `ratings`
- [ ] 인증 사용자가 PUBLISHED 필터에 stars=5 → 성공
- [ ] 인증 사용자가 stars=0 → 거부
- [ ] 인증 사용자가 PENDING 필터에 평가 → 거부 (get()으로 status 확인)
- [ ] 본인이 자기 평가 update → 성공
- [ ] 다른 사용자의 평가 delete → 거부

#### `comments`
- [ ] 인증 사용자가 본인 명의로 작성 → 성공
- [ ] 인증 사용자가 타인 uid로 작성 시도 → 거부
- [ ] 본인 댓글 본문 수정 → 성공
- [ ] 본인 댓글 status를 hidden으로 변경 → 거부 (모더레이터만)
- [ ] 모더레이터가 임의 댓글 delete → 성공

#### `follows`
- [ ] 본인이 A→B follow → 성공
- [ ] 다른 사용자가 A→B follow 생성 시도 → 거부
- [ ] 자기자신 팔로우 시도 → 거부
- [ ] follow update 시도 → 거부

#### `reports`
- [ ] 인증 사용자가 신고 작성 → 성공
- [ ] 본인이 본인 신고 read → 성공
- [ ] 다른 사용자의 신고 read → 거부
- [ ] 모더레이터가 신고 status 변경 → 성공
- [ ] 모더레이터가 reason 변경 → 거부

#### `ownedFilters` / `wallets` / `transactions` (Phase 6)
- [ ] 본인 `users/{uid}/ownedFilters` read → 성공
- [ ] 클라이언트 직접 `ownedFilters` write → 거부
- [ ] 본인 `wallets/{uid}` read → 성공
- [ ] 다른 사용자 wallet/transactions read → 거부
- [ ] 클라이언트 직접 wallet/transactions write → 거부
- [ ] Cloud Function (admin SDK) purchase/topup/withdraw write → 성공

### 6.3 테스트 코드 예시 (`@firebase/rules-unit-testing`)
```typescript
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';

const env = await initializeTestEnvironment({
  projectId: 'moodit-test',
  firestore: { rules: fs.readFileSync('firestore.rules', 'utf8') },
});

const alice = env.authenticatedContext('alice', { role: 'user' });
const moderator = env.authenticatedContext('mod1', { role: 'moderator' });

await assertSucceeds(alice.firestore().doc('users/alice').set({
  displayName: 'Alice', bio: '', stats: { /* ... */ }
}));

await assertFails(alice.firestore().doc('users/bob').set({
  displayName: 'Hacked'
}));

await assertSucceeds(moderator.firestore().doc('filters/f1').update({
  status: 'PUBLISHED', moderatedAt: new Date()
}));
```

---

## 7. 배포 / 운영

### 7.1 룰 배포
```bash
firebase deploy --only firestore:rules --project moodit-prod
```

- 배포는 ADR(또는 PR) 승인 + 모더레이터/PM 검토 필수
- staging에서 24h 노출 후 prod 적용
- 룰 백업: GitHub `firestore.rules` 자체가 SoT

### 7.2 모니터링
- Cloud Logging의 `cloud.googleapis.com/firestore/document_request` 거부 이벤트 트래킹
- 대량 거부 발생 시 알람 (대개 클라이언트 버그 또는 공격)

### 7.3 변경 관리
- 룰 변경은 PR + 테스트 매트릭스 갱신 필수
- 룰의 `get()`/`exists()` 호출 추가 시 비용 영향 PR 본문에 명시

---

## 8. 관련 문서

- [API_SPEC.md](./API_SPEC.md) — 콜렉션별 접근 패턴 요약
- [SYSTEM_DESIGN.md](./SYSTEM_DESIGN.md) §4 데이터 모델
- [TESTING_STRATEGY.md](./TESTING_STRATEGY.md) — Emulator 테스트
- [FMPKG_SCHEMA.md](./FMPKG_SCHEMA.md) §8 — 메이커 키 등록
- [ADR/0002-firebase-mvp-backend.md](./ADR/0002-firebase-mvp-backend.md)
