# moodit - Implementation Plan

> **Reference**: 이 문서는 초기 이슈화 전략과 label/milestone 설계를 보존한다.  
> 현재 진행 순서와 Phase 상태는 [`PHASE_ROADMAP_STATUS.md`](./PHASE_ROADMAP_STATUS.md)를 기준으로 한다.

> 버전: v1.1 · 작성일: 2026-05-06 · 상태: Active
>
> 이 문서는 현재 설계 문서를 실제 구현 이슈로 전환하기 위한 실행 계획이다. [TASK_LIST.md](./TASK_LIST.md)는 전체 Phase별 작업 분해를 담고, 본 문서는 **이슈 생성 단위, 우선순위, 완료 기준, 의존성**을 더 명확히 정의한다.

---

## 1. 구현 원칙

1. **가장 위험한 기술 가정부터 검증한다**: `AVFoundation -> CVPixelBuffer -> Metal Texture -> LUT -> MTKView` 파이프라인을 Phase 0에서 먼저 검증한다.
2. **수직 슬라이스로 진행한다**: UI, 도메인, 저장소, 렌더링을 얇게라도 끝까지 연결한 뒤 폭을 넓힌다.
3. **MVP에서는 사용자 MSL 셰이더를 비활성화한다**: `engine.type = lut+params`만 허용하고, `lut+msl`은 보안 검증 인프라 이후로 미룬다.
4. **초기 UI는 mock repository로 병렬 개발한다**: Firebase/R2 연결 전에 마켓 UI와 필터 적용 UX를 먼저 고정한다.
5. **실기기 검증을 게이트로 둔다**: 카메라/Metal 변경은 iOS Simulator만으로 완료 처리하지 않는다.
6. **문서와 코드의 단일 진실 출처를 분리한다**: 제품/설계는 `docs/`, 구현 상태는 GitHub Issues/PR에서 추적한다.

---

## 2. 마일스톤 구조

GitHub Milestone은 다음 단위로 생성한다.

| Milestone | 목표 | 종료 기준 |
|---|---|---|
| `M0 - Bootstrap & Metal PoC` | 프로젝트 골격과 실시간 카메라 필터 PoC | 실기기 1080p 30FPS+, iPhone 12+ 60FPS 목표 |
| `M1 - Camera MVP` | 촬영자가 필터를 적용해 사진 저장 | 카메라, 로컬 필터, 저장 플로우 완성 |
| `M2 - Marketplace Download` | 마켓 필터 탐색/다운로드/캐시/적용 | mock -> Firebase/R2 연결, 다운로드 카운터 |
| `M3 - Maker Editor` | LUT+파라미터 기반 필터 제작/업로드 | `.fmpkg` 생성, R2 업로드, 검수 상태 |
| `M4 - Social & Search` | 프로필, 평가, 댓글, 검색, 공유 | 마켓 참여 기능과 Universal Link |
| `M5 - Moderation & Compliance` | 신고/모더레이션/개인정보/저작권 대응 | 24h SLA 운영 가능 |
| `M6 - Monetization` | 유료 필터, IAP, 정산 | 구매/권한/정산 검증 |

---

## 3. Label 체계

이슈 관리를 위해 다음 label을 사용한다.

| Label | 의미 |
|---|---|
| `area:app` | 앱 엔트리, DI, navigation, 환경 설정 |
| `area:camera` | AVFoundation, 권한, 촬영, PhotoKit |
| `area:filter-engine` | Metal, MSL, LUT, 렌더링 파이프라인 |
| `area:models` | 도메인 모델, Codable, schema |
| `area:storage` | 로컬 DB, 파일 캐시, 다운로드 큐 |
| `area:marketplace` | 피드, 상세, 검색, 다운로드 UI |
| `area:editor` | LUT 파서, 파라미터 에디터, `.fmpkg` 빌더 |
| `area:auth` | Firebase Auth, Apple/Google 로그인 |
| `area:backend` | Cloud Functions, Firestore, R2, API |
| `area:security` | Firestore Rules, 서명, App Attest, MSL 검증 |
| `area:moderation` | 신고, SafeSearch, 어드민 큐 |
| `area:payments` | StoreKit 2, Coin wallet, Pro subscription, Stripe Connect |
| `area:design-system` | 색상, 타이포, 공통 컴포넌트 |
| `type:feature` | 사용자 기능 |
| `type:infra` | 프로젝트/빌드/CI/배포 인프라 |
| `type:test` | 테스트 추가/개선 |
| `type:docs` | 문서 |
| `type:spike` | 조사/PoC |
| `priority:p0` | 즉시 처리, milestone 차단 |
| `priority:p1` | 현재 milestone 핵심 |
| `priority:p2` | 중요하지만 차단 아님 |
| `risk:high` | 기술/일정/정책 리스크 높음 |
| `device-required` | 실기기 검증 필요 |

---

## 4. 이슈 작성 템플릿

개별 구현 이슈는 다음 형태를 기본으로 한다.

```markdown
## 목표
<사용자/시스템 관점에서 달성할 결과>

## 범위
- 포함:
- 제외:

## 구현 메모
- 관련 모듈:
- 주요 타입/파일:
- 의존 이슈:

## 완료 기준
- [ ] 빌드 성공
- [ ] 단위/통합 테스트 추가 또는 기존 테스트 갱신
- [ ] UI 변경 시 스냅샷 또는 스크린샷 확인
- [ ] 카메라/Metal 변경 시 실기기 검증

## 관련 문서
- ...
```

---

## 5. M0 - Bootstrap & Metal PoC

목표: 실제 iOS 프로젝트를 만들고 가장 중요한 기술 가정인 라이브 카메라 + Metal LUT 렌더링을 검증한다.

### Epic M0-A. 프로젝트 골격

| Issue | 제목 | Labels | 의존성 | 완료 기준 |
|---|---|---|---|---|
| M0-A01 | Xcode 프로젝트와 SPM 모듈 골격 생성 | `area:app`, `type:infra`, `priority:p0` | - | 앱이 Simulator에서 빈 화면으로 빌드/실행 |
| M0-A02 | SwiftLint/SwiftFormat 설정 추가 | `area:app`, `type:infra`, `priority:p1` | M0-A01 | lint/format 명령 실행 가능 |
| M0-A03 | Debug/Staging/Release 설정과 xcconfig 골격 추가 | `area:app`, `type:infra`, `priority:p1` | M0-A01 | 빌드 config별 앱 이름/환경 값 분리 |
| M0-A04 | 기본 테스트 타깃과 fixture 구조 생성 | `type:test`, `priority:p1` | M0-A01 | XCTest 1개 이상 통과 |

### Epic M0-B. Camera + Metal PoC

| Issue | 제목 | Labels | 의존성 | 완료 기준 |
|---|---|---|---|---|
| M0-B01 | 카메라 권한 요청과 세션 lifecycle 구현 | `area:camera`, `type:feature`, `priority:p0`, `device-required` | M0-A01 | 권한 허용 후 실기기 프레임 수신 |
| M0-B02 | `MTKView` 기반 Metal preview surface 구현 | `area:filter-engine`, `type:feature`, `priority:p0`, `device-required` | M0-A01 | 빈 drawable clear/present |
| M0-B03 | `CVMetalTextureCache`로 Y/CbCr plane 텍스처 변환 | `area:camera`, `area:filter-engine`, `priority:p0`, `risk:high`, `device-required` | M0-B01, M0-B02 | 카메라 프레임이 Metal texture로 전달 |
| M0-B04 | YUV->RGB MSL fragment shader 구현 | `area:filter-engine`, `priority:p0`, `risk:high`, `device-required` | M0-B03 | 실시간 RGB preview 표시 |
| M0-B05 | identity/warm LUT 적용 PoC 구현 | `area:filter-engine`, `priority:p0`, `risk:high`, `device-required` | M0-B04 | LUT on/off 시각 차이 확인 |
| M0-B06 | FPS/GPU 시간 측정 instrumentation 추가 | `area:filter-engine`, `type:test`, `priority:p1`, `device-required` | M0-B05 | 30/60FPS 측정값 로그 확인 |

### Epic M0-C. 실기기 검증

| Issue | 제목 | Labels | 의존성 | 완료 기준 |
|---|---|---|---|---|
| M0-C01 | iPhone 실기기 preview smoke test | `area:camera`, `area:filter-engine`, `type:test`, `priority:p0`, `device-required` | M0-B06 | 영상 표시, 권한 허용/거부, background lifecycle 확인 |
| M0-C02 | M0 성능 측정 결과 기록 | `area:filter-engine`, `type:docs`, `priority:p0`, `device-required` | M0-C01 | 기기/iOS/FPS/CPU ms/GPU ms 표 기록 |
| M0-C03 | preview orientation/crop 보정 | `area:camera`, `area:filter-engine`, `priority:p1`, `device-required` | M0-C01 | portrait 기준 왜곡/회전 없이 preview 표시 |

### M0 종료 기준

- [ ] iPhone 12 이상에서 1080p 30FPS 이상
- [ ] iPhone 12 이상에서 60FPS 가능성 확인 또는 병목 기록
- [ ] 카메라 권한 거부/허용 플로우 동작
- [ ] 앱 background 진입 시 `AVCaptureSession` 정지
- [ ] PoC 결과를 이슈/PR에 수치로 기록

---

## 6. M1 - Camera MVP

목표: 로컬 필터를 선택해 실시간으로 촬영하고 사진 라이브러리에 저장할 수 있게 한다.

### Epic M1-A. 카메라 사용자 기능

| Issue | 제목 | Labels | 의존성 | 완료 기준 |
|---|---|---|---|---|
| M1-A01 | 전/후면 카메라 전환 | `area:camera`, `type:feature`, `priority:p1`, `device-required` | M0-B01 | 전환 후 preview 유지 |
| M1-A02 | 탭 포커스/노출 제어 | `area:camera`, `type:feature`, `priority:p1`, `device-required` | M0-B01 | 탭 위치 기준 focus/exposure 동작 |
| M1-A03 | 촬영 비율 1:1, 4:3, 16:9 전환 | `area:camera`, `area:app`, `priority:p1` | M0-B02 | preview crop과 저장 비율 일치 |
| M1-A04 | 셔터, 햅틱, 촬영 상태 UI | `area:camera`, `area:design-system`, `priority:p1` | M1-A01 | 셔터 입력 중 중복 촬영 방지 |
| M1-A05 | PhotoKit 저장 구현 | `area:camera`, `priority:p1`, `device-required` | M1-A04 | 필터 적용본 저장 성공 |

### Epic M1-B. FilterEngine 정식화

| Issue | 제목 | Labels | 의존성 | 완료 기준 |
|---|---|---|---|---|
| M1-B01 | Metal device/command queue/renderer 추상화 | `area:filter-engine`, `priority:p1` | M0-B05 | preview renderer와 capture renderer 분리 가능 |
| M1-B02 | LUT PNG -> 3D texture loader 구현 | `area:filter-engine`, `area:models`, `priority:p1` | M1-B01 | identity LUT 픽셀 테스트 통과 |
| M1-B03 | 필터 intensity 파라미터 적용 | `area:filter-engine`, `area:camera`, `priority:p1` | M1-B02 | 0~100% 슬라이더 실시간 반영 |
| M1-B04 | 기본 4-pass 파이프라인 초안 | `area:filter-engine`, `priority:p1`, `risk:high`, `device-required` | M1-B03 | YUV/RGB/params/LUT/post pass 분리 |
| M1-B05 | thermal/low power fallback 정책 구현 | `area:filter-engine`, `area:camera`, `priority:p2`, `device-required` | M1-B04 | serious thermal에서 FPS/해상도 다운 |

### Epic M1-C. 로컬 필터와 기본 UI

| Issue | 제목 | Labels | 의존성 | 완료 기준 |
|---|---|---|---|---|
| M1-C01 | `Filter`, `FilterManifest`, `FilterParameter` 모델 구현 | `area:models`, `priority:p1` | M0-A04 | Codable round-trip 테스트 |
| M1-C02 | 앱 번들 seed 필터 로딩 | `area:storage`, `area:filter-engine`, `priority:p1` | M1-C01, M1-B02 | 10개 이상 로컬 필터 표시 |
| M1-C03 | 필터 선택 carousel/sheet 구현 | `area:camera`, `area:design-system`, `priority:p1` | M1-C02 | 선택 즉시 preview 반영 |
| M1-C04 | 카메라 화면 접근성 identifier 부여 | `area:camera`, `type:test`, `priority:p2` | M1-C03 | XCUITest selector 안정화 |

### M1 종료 기준

- [ ] 첫 실행 후 60초 안에 촬영 가능
- [ ] 로컬 필터 10~15개 선택 가능
- [ ] 필터 강도 조정 가능
- [ ] PhotoKit 저장 성공
- [ ] 카메라 핵심 플로우 XCUITest 1개 이상

---

## 7. M2 - Marketplace Download

목표: 마켓에서 필터를 둘러보고 다운로드해 카메라에 적용한다.

### Epic M2-A. Repository와 mock UI

| Issue | 제목 | Labels | 의존성 | 완료 기준 |
|---|---|---|---|---|
| M2-A01 | `FilterRepository` 프로토콜 정의 | `area:models`, `area:marketplace`, `priority:p1` | M1-C01 | mock/firestore 구현 교체 가능 |
| M2-A02 | mock marketplace feed 구현 | `area:marketplace`, `priority:p1` | M2-A01 | 인기/신규 탭 mock 표시 |
| M2-A03 | 필터 상세 화면 구현 | `area:marketplace`, `priority:p1` | M2-A02 | preview, author, metrics, apply 버튼 표시 |
| M2-A04 | 다운로드한 필터 목록 화면 구현 | `area:marketplace`, `area:storage`, `priority:p1` | M2-A03 | 로컬 seed/downloaded 구분 |

### Epic M2-B. Firebase/R2 연결

| Issue | 제목 | Labels | 의존성 | 완료 기준 |
|---|---|---|---|---|
| M2-B01 | Firebase SDK와 환경별 plist 로딩 | `area:backend`, `area:auth`, `type:infra`, `priority:p1` | M0-A03 | dev/staging/prod 분기 |
| M2-B02 | 게스트/익명 인증 플로우 | `area:auth`, `priority:p1` | M2-B01 | 게스트가 마켓 read 가능 |
| M2-B03 | Firestore `filters` read repository 구현 | `area:marketplace`, `area:backend`, `priority:p1` | M2-A01, M2-B01 | published 필터 목록 조회 |
| M2-B04 | R2/CDN `.fmpkg` 다운로드와 파일 캐시 | `area:storage`, `area:backend`, `priority:p1` | M2-B03 | cache miss 다운로드, cache hit 즉시 로드 |
| M2-B05 | `.fmpkg` manifest 최소 검증과 로딩 | `area:storage`, `area:models`, `area:filter-engine`, `priority:p1` | M2-B04 | invalid package 거부 |
| M2-B06 | `/filters/{id}/use` Cloud Function 구현 | `area:backend`, `priority:p1` | M2-B03 | 멱등 카운터 증가 |
| M2-B07 | Firestore Rules와 emulator 테스트 초안 추가 | `area:security`, `area:backend`, `type:test`, `priority:p1` | M2-B03 | 주요 read/write 시나리오 통과 |

### M2 종료 기준

- [ ] 마켓 필터 목록 조회 가능
- [ ] 필터 상세에서 다운로드 가능
- [ ] 다운로드한 필터를 오프라인에서 적용 가능
- [ ] 다운로드/use 카운터가 중복 없이 증가
- [ ] Firestore Rules emulator 테스트 통과

---

## 8. M3 - Maker Editor

목표: 메이커가 LUT와 파라미터로 필터를 제작하고 `.fmpkg`로 업로드한다.

### Epic M3-A. LUT/manifest 제작

| Issue | 제목 | Labels | 의존성 | 완료 기준 |
|---|---|---|---|---|
| M3-A01 | `.cube` parser 구현 | `area:editor`, `area:filter-engine`, `priority:p1` | M1-B02 | 17/33/65 cube fixture 파싱 |
| M3-A02 | LUT PNG packing/baking 구현 | `area:editor`, `priority:p1` | M3-A01 | deterministic output 테스트 |
| M3-A03 | 파라미터 -> LUT bake 구현 | `area:editor`, `area:filter-engine`, `priority:p1` | M3-A02 | 동일 파라미터 동일 checksum |
| M3-A04 | manifest builder와 schema validation 구현 | `area:editor`, `area:models`, `priority:p1` | M1-C01 | FMPKG_SCHEMA 예시 통과 |
| M3-A05 | preview image 생성 | `area:editor`, `priority:p1` | M3-A03 | thumb/before/after 생성 |
| M3-A06 | `.fmpkg` zip packer 구현 | `area:editor`, `area:storage`, `priority:p1` | M3-A04, M3-A05 | 1MB 이하 패키지 생성 |

### Epic M3-B. 에디터 UI와 업로드

| Issue | 제목 | Labels | 의존성 | 완료 기준 |
|---|---|---|---|---|
| M3-B01 | 에디터 기본 화면 구현 | `area:editor`, `area:design-system`, `priority:p1` | M3-A03 | 슬라이더 변경이 preview에 반영 |
| M3-B02 | 라이선스/카테고리/태그 입력 UI | `area:editor`, `priority:p1` | M3-B01 | manifest metadata 생성 |
| M3-B03 | `POST /filters` presigned upload 시작 API | `area:backend`, `priority:p1` | M2-B01 | uploadUrl 발급 |
| M3-B04 | R2 presigned PUT 업로드 | `area:editor`, `area:storage`, `area:backend`, `priority:p1` | M3-A06, M3-B03 | background upload 성공 |
| M3-B05 | `POST /filters/{id}/finalize` 구현 | `area:backend`, `priority:p1` | M3-B04 | status=PENDING 생성 |
| M3-B06 | 업로드 진행률/실패 재시도 UI | `area:editor`, `priority:p2` | M3-B04 | 실패 후 재시도 가능 |

### M3 종료 기준

- [ ] 앱에서 LUT 기반 필터 생성 가능
- [ ] `.fmpkg` 생성과 최소 검증 가능
- [ ] R2 업로드 후 Firestore status=PENDING
- [ ] 업로드 성공률 95% 이상을 목표로 오류 경로 처리
- [ ] 사용자 업로드 MSL 셰이더는 여전히 비활성

---

## 9. M4 - Social & Search

목표: 마켓플레이스의 탐색성과 커뮤니티 기능을 추가한다.

| Issue | 제목 | Labels | 의존성 | 완료 기준 |
|---|---|---|---|---|
| M4-01 | 사용자 프로필 화면 | `area:marketplace`, `area:auth`, `priority:p1` | M2-B02 | 만든/받은/즐겨찾기 필터 표시 |
| M4-02 | 좋아요와 즐겨찾기 분리 | `area:marketplace`, `area:backend`, `priority:p1` | M2-B03 | 토글 상태 동기화 |
| M4-03 | 평점 시스템 | `area:marketplace`, `area:backend`, `priority:p1` | M2-B07 | 1회 평가와 평균 집계 |
| M4-04 | 댓글 시스템 | `area:marketplace`, `area:backend`, `priority:p1` | M4-01 | visible 댓글 목록/작성 |
| M4-05 | 팔로우 시스템 | `area:marketplace`, `area:backend`, `priority:p2` | M4-01 | follow/unfollow와 카운터 |
| M4-06 | Firestore 기반 prefix 검색 | `area:marketplace`, `area:backend`, `priority:p1` | M2-B03 | q/category/tag 검색 |
| M4-07 | Universal Link 적용 | `area:app`, `area:marketplace`, `priority:p2` | M2-A03 | 링크 클릭 시 필터 상세/적용 |
| M4-08 | Android 진출 게이트 ADR 작성 | `type:docs`, `priority:p1` | M4 완료 지표 | 옵션 A/B/C 결정 기록 |

---

## 10. M5 - Moderation & Compliance

목표: UGC 운영에 필요한 신고, 저작권, 개인정보 대응을 갖춘다.

| Issue | 제목 | Labels | 의존성 | 완료 기준 |
|---|---|---|---|---|
| M5-01 | 신고 API와 신고 UI | `area:moderation`, `priority:p1` | M4-04 | filter/user/comment 신고 생성 |
| M5-02 | Cloud Vision SafeSearch worker | `area:moderation`, `area:backend`, `priority:p1` | M3-B05 | preview 검사 결과 저장 |
| M5-03 | 모더레이터 큐 API | `area:moderation`, `area:backend`, `priority:p1` | M5-01 | approve/reject/takedown |
| M5-04 | 모더레이터 웹 어드민 초안 | `area:moderation`, `priority:p1` | M5-03 | 큐 조회/처리 가능 |
| M5-05 | DMCA takedown 워크플로 | `area:moderation`, `area:security`, `priority:p1` | M5-03 | 24h 처리 기록 가능 |
| M5-06 | GDPR/개인정보 export/delete API | `area:security`, `area:backend`, `priority:p1` | M2-B02 | 내보내기/삭제 요청 처리 |
| M5-07 | App Attest 도입 | `area:security`, `priority:p2`, `device-required` | M2-B01 | 검증된 디바이스 quota 분기 |
| M5-08 | MSL 셰이더 보안 verifier spike | `area:security`, `area:filter-engine`, `type:spike`, `risk:high` | M3 완료 | `lut+msl` 활성화 가능성 판단 |

---

## 11. M6 - Monetization

목표: [`CURRENCY_DESIGN.md`](./CURRENCY_DESIGN.md)의 Coin 모델을 구현한다. 사용자는 StoreKit 2로 Coin을 충전하고, 필터 구매는 서버 트랜잭션으로 Coin을 차감해 보유권을 부여한다. Pro 멤버십은 별도 구독 트랙이며, 메이커는 적립 Coin을 Stripe Connect를 통해 원화로 출금한다.

| Issue | 제목 | Labels | 의존성 | 완료 기준 |
|---|---|---|---|---|
| M6-01 | Coin economy config와 product catalog | `area:payments`, `area:backend`, `priority:p1` | M2-B02 | `/config/economy`가 패키지/환율/임계치를 반환 |
| M6-02 | StoreKit 2 Coin top-up client | `area:payments`, `priority:p1` | M6-01 | sandbox에서 100/550/1200/3000 C 구매 성공 |
| M6-03 | `/wallet/topup/init` + `/wallet/topup/finalize` | `area:payments`, `area:backend`, `priority:p1` | M6-02 | signed transaction 검증, replay 방지, 잔액 grant |
| M6-04 | Wallet/transaction ledger UI | `area:payments`, `area:marketplace`, `priority:p1` | M6-03 | `43`/`45` 화면 데이터 표시 |
| M6-05 | Coin 기반 필터 구매 API와 잔액 부족 처리 | `area:payments`, `area:marketplace`, `area:backend`, `priority:p1` | M6-04 | `POST /filters/{id}/purchase`, `46` insufficient balance |
| M6-06 | 보유 필터와 환불 상태 동기화 | `area:payments`, `area:security`, `priority:p1` | M6-05 | `users/{uid}/ownedFilters`, `39` 보유/환불 상태 |
| M6-07 | Pro 멤버십 StoreKit 구독 | `area:payments`, `priority:p1` | M6-03 | Pro 활성 시 Coin 차감 없이 premium 다운로드 |
| M6-08 | Stripe Connect onboarding | `area:payments`, `area:backend`, `priority:p1` | M6-04 | 메이커 KYC 링크 생성, `40` 화면 연결 |
| M6-09 | 세무 정보와 payout profile | `area:payments`, `area:backend`, `priority:p1` | M6-08 | `41` 입력값 저장/검증 |
| M6-10 | 메이커 출금 신청/내역/대시보드 | `area:payments`, `area:backend`, `area:marketplace`, `priority:p1` | M6-09 | `POST /me/withdraw`, `42`/`47`/`28` 표시 |
| M6-11 | 환불/transaction updates 동기화 | `area:payments`, `priority:p1` | M6-06 | Apple 환불, Coin 환원, 보유권 회수 반영 |

---

## 12. 첫 스프린트 권장 범위

첫 스프린트는 M0만 다룬다. M0-A/M0-B는 코드 구현 기준 대부분 진행됐고, 현재는 M0-C 실기기 검증 이슈를 우선 생성한다.

1. M0-A01 Xcode 프로젝트와 SPM 모듈 골격 생성
2. M0-A02 SwiftLint/SwiftFormat 설정 추가
3. M0-A04 기본 테스트 타깃과 fixture 구조 생성
4. M0-B01 카메라 권한 요청과 세션 lifecycle 구현
5. M0-B02 `MTKView` 기반 Metal preview surface 구현
6. M0-B03 `CVMetalTextureCache`로 Y/CbCr plane 텍스처 변환
7. M0-B04 YUV->RGB MSL fragment shader 구현
8. M0-B05 identity/warm LUT 적용 PoC 구현
9. M0-B06 FPS/GPU 시간 측정 instrumentation 추가
10. M0-C01 iPhone 실기기 preview smoke test
11. M0-C02 M0 성능 측정 결과 기록
12. M0-C03 preview orientation/crop 보정

M0-B03부터 M0-B06은 `risk:high`와 `device-required`를 반드시 붙인다. M0-C 전체는 `device-required`를 붙이고, 실제 iPhone 검증 결과가 없으면 Done으로 닫지 않는다.

---

## 13. 게이트와 의사결정

| Gate | 시점 | 질문 | 결정 |
|---|---|---|---|
| G0 | M0 종료 | 실기기에서 30~60FPS 라이브 LUT가 가능한가? | 가능하면 M1 진행, 불가능하면 파이프라인/해상도/프레임 목표 재설정 |
| G1 | M1 종료 | 카메라 UX가 베타 사용자에게 공개 가능한가? | 가능하면 마켓 연결, 아니면 카메라 품질 보강 |
| G2 | M3 종료 | 메이커가 필터 업로드를 안정적으로 완료할 수 있는가? | 가능하면 소셜/검색 확대 |
| G3 | M4 종료 | Android 진출이 사업적으로 필요한가? | 새 ADR로 Kotlin/Compose MP/iOS only 결정 |
| G4 | M5 종료 | UGC 운영 리스크를 감당할 수 있는가? | 유료화 전 운영 기준 확인 |

---

## 14. 관련 문서

- [README.md](./README.md)
- [IMPLEMENTATION_STATUS.md](./IMPLEMENTATION_STATUS.md)
- [PRD.md](./PRD.md)
- [ARCHITECTURE.md](./ARCHITECTURE.md)
- [SYSTEM_DESIGN.md](./SYSTEM_DESIGN.md)
- [TECH_STACK.md](./TECH_STACK.md)
- [TASK_LIST.md](./TASK_LIST.md)
- [FMPKG_SCHEMA.md](./FMPKG_SCHEMA.md)
- [API_SPEC.md](./API_SPEC.md)
- [FIRESTORE_RULES.md](./FIRESTORE_RULES.md)
- [MSL_SECURITY.md](./MSL_SECURITY.md)
- [TESTING_STRATEGY.md](./TESTING_STRATEGY.md)
- [ADR/](./ADR/README.md)
