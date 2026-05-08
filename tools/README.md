# tools/

운영 자격증을 사용하는 1회성 스크립트 모음. 코드 베이스가 아닌 **운영 절차**입니다.

## bootstrap-admin.mjs

첫 admin 롤 부여용. Firebase Admin SDK 서비스 계정 JSON 필요.

### 사전 준비

1. https://console.firebase.google.com/project/moodit-a9e7a → ⚙️ **Project settings** → **Service accounts** 탭
2. **Generate new private key** 클릭 → JSON 파일 다운로드
3. **저장 위치 — 절대 git에 커밋 금지**:
   ```
   ~/Documents/secrets/moodit-admin.json
   ```
4. `.gitignore`에는 이미 `*-firebase-adminsdk*.json`, `tools/secrets/` 패턴 추가되어 있음

### 부트스트랩 실행

```bash
# 1. tools 의존성 설치 (한 번만)
cd tools && npm install
cd ..

# 2. 본인 Firebase UID 확인
#    Firebase Console → Authentication → Users → 본인 row 클릭 → "User UID" 복사

# 3. bootstrap 실행
node tools/bootstrap-admin.mjs \
  --service-account ~/Documents/secrets/moodit-admin.json \
  --uid <YOUR_FIREBASE_UID> \
  --role admin
```

성공 시:
```
✓ Found user: you@example.com — uid=XXX
✓ Set role=admin for XXX.

Note: the user must sign out + sign back in ...
```

### 클라이언트 반영

iOS 앱에서 새 role claim 반영:

- 옵션 A: 로그아웃 + 재로그인
- 옵션 B: `Auth.auth().currentUser?.getIDToken(forcingRefresh: true)`
- moodit는 SettingsScreen 진입 시마다 자동 forceRefresh — 설정 → admin 섹션이 표시되는지 확인

### 다른 사람에게 role 부여 (admin 부트스트랩 후)

Cloud Function `setRole` 사용. 호출자가 admin claim을 가져야 함.

```swift
// iOS — admin 사용자가 호출
Functions.functions(region: "asia-northeast3").httpsCallable("setRole")
    .call(["targetUid": "...", "role": "moderator"]) { ... }
```

### 권한 회수

```bash
node tools/bootstrap-admin.mjs \
  --service-account ~/Documents/secrets/moodit-admin.json \
  --uid <USER_UID> \
  --role none
```

### Audit log (권장)

권한 부여/회수는 ad-hoc audit log로 기록 (예: `/audit/{auto}` 컬렉션). 본 스크립트 자체는 audit 기록을 안 만드니, 회사 차원의 권한 관리가 필요해지면 `setRole` Cloud Function이 audit 작성도 함께 하도록 확장하시면 됩니다.
