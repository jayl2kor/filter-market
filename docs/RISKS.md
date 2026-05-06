# moodit - Risk Register & Mitigation

> 버전: v1.1 (Draft, iOS native pivot) · 작성일: 2026-05-06
>
> 본 문서는 식별된 위험과 대응 방안을 등록한다. 분기마다 재검토하며, 새 위험은 ID(R-XXX)로 추가한다.
>
> **위험 점수** = 발생가능성(1-5) × 영향(1-5). ≥15는 Critical, 10~14 High, 5~9 Medium, ≤4 Low.

---

## 1. 기술적 위험 (Technical)

### R-T01 [Critical] 사용자 업로드 MSL 셰이더의 보안 — GPU 자원 남용 / 크래시 / 메모리 우회

| 항목 | 내용 |
|---|---|
| 가능성 | 4 |
| 영향 | 4 |
| **점수** | **16** |
| 영향 범위 | Phase 3+ (사용자 셰이더 활성화 시), 단일 악성 셰이더가 다수 디바이스에 영향 |
| 트리거 | 메이커가 무한 루프, threadgroup 메모리 무단 사용, 텍스처 외부 메모리 접근, 시간 의존 사이드채널 등을 셰이더에 삽입 |

**완화 (Pre-mitigation)**
- v1 MVP: **사용자 업로드 셰이더 비허용** (`engine.type = lut+params`만 허용)
- v2 (Phase 3+) 활성화 시 다층 방어:
  1. **함수 화이트리스트**: `fragment` 함수 1개 + 미리 정의 헬퍼만 사용. `kernel`/atomic/threadgroup/`device` 포인터 차단
  2. **AST 정적 분석** (서버측): 금지 키워드 차단, 루프 깊이/길이 상한
  3. **샘플러/텍스처 바인딩 강제**: 미리 정의된 입력만 허용
  4. **컴파일 타임아웃**: `MTLDevice.makeLibrary(source:)` 100ms 한도
  5. **런타임 가드**: `MTLCommandBuffer.addCompletedHandler`로 GPU 시간 측정, 16ms × 5 frames 초과 시 셰이더 비활성화 + 신고 큐 자동 등록
  6. **서명**: 백엔드가 검증 후 `.metallib`에 ed25519 서명, 클라이언트가 검증 후 로드

**플랜 B**: 검증 인프라 미완성 시 v2를 무기한 연기, "노드 그래프 → 사전 정의 셰이더 컴파일" 방식만 허용

---

### R-T02 [High] LUT 정밀도 부족 → 색감 왜곡 (banding, posterization)

| 가능성 | 영향 | 점수 |
|---|---|---|
| 3 | 4 | 12 |

**원인**
- 33³ 그리드 + RGBA8 → 256단계 → 그라디언트에서 banding 발생
- sRGB 비선형 공간 처리 차이

**완화**
- 1차: trilinear 보간 + dithering(blue noise) 적용
- 2차: 17³ baseline + 65³ premium(메이커 선택)
- 3차: Phase 3에서 RGBA16Float 텍스처 옵션(고급 메이커)
- 메이커 가이드: "그라디언트가 강한 LUT는 65³ + RGBA16F 권장"

---

### R-T03 [High] iPhone 배터리 / 발열 (라이브 카메라 + Metal 4-pass)

| 가능성 | 영향 | 점수 |
|---|---|---|
| 4 | 3 | 12 |

**원인**
- 60FPS Metal 4-pass + AVCaptureSession ISP → 5분 사용 시 발열, 배터리 5~10% 소비
- iOS의 자동 thermal throttling 발생 시 FPS 저하

**완화**
- Idle 시 프리뷰 FPS 다운(15FPS)
- 백그라운드/잠금 즉시 `AVCaptureSession.stopRunning()`
- Low Power Mode 감지 (`ProcessInfo.isLowPowerModeEnabled`) → 셰이더 패스 단순화
- `ProcessInfo.thermalState` 모니터링 → fair/serious 시 FPS 자동 다운 + 사용자 안내
- MetricKit `MXMetricPayload`로 실사용 데이터 수집

---

### R-T04 [High] iOS 디바이스 호환성 (구형 iPhone 성능)

| 가능성 | 영향 | 점수 |
|---|---|---|
| 3 | 4 | 12 |

**원인**
- iOS 17 최소 지원이지만 iPhone X/11 등 구형 칩(A11/A13)에서 60FPS 미달
- 일부 4-pass 셰이더는 A11에서 30FPS도 위태로움

**완화**
- 디바이스 등급별 자동 화질 조정 (`MTLDevice.supportsFamily(.apple4)` 등 체크)
- iPhone X 미만: 720p + 30FPS 강제
- 미지원 디바이스(iOS 17 미지원) → App Store deployment target으로 자연 차단
- Phase 0 PoC에 구형 기기 테스트 포함(iPhone 11/12 mini)

---

### R-T05 [Medium] Firebase 비용 예측 실패

| 가능성 | 영향 | 점수 |
|---|---|---|
| 3 | 4 | 12 |

**원인**
- Firestore 읽기 비용 = $0.06/100K reads. 마켓 피드 무한 스크롤 시 폭증 가능
- Firebase Storage 사용 안 함(R2 사용)으로 egress 비용은 회피

**완화**
- 클라이언트 캐싱 적극 적용(SwiftData/GRDB + in-memory TTL 5분)
- Firestore 인덱스 최소화 + 페이지네이션 강제(limit=20)
- 매일 비용 대시보드 모니터링, 매출의 30% 초과 알람
- 미디어는 처음부터 R2

---

### R-T06 [Medium] 데이터 동기화 충돌(오프라인 → 온라인 복귀)

| 가능성 | 영향 | 점수 |
|---|---|---|
| 3 | 3 | 9 |

**완화**
- Firestore 오프라인 캐시 + URLSession Background Task 큐
- 사용자 액션은 idempotent operation(POST `/use`는 멱등)
- 충돌 시 last-write-wins, 클라이언트가 사용자에게 안내

---

### R-T07 [Medium] iOS 메이저 업데이트 호환성 (매년 9월)

| 가능성 | 영향 | 점수 |
|---|---|---|
| 4 | 2 | 8 |

**원인**
- iOS 18, 19 등에서 AVFoundation/Metal/SwiftUI API 동작 변경
- App Privacy / 권한 정책 변경

**완화**
- 매년 6~7월 iOS Developer Beta로 사전 검증
- WWDC 키노트 직후 영향 평가 ADR 작성
- Xcode Cloud에 Beta SDK 빌드 잡 추가

---

## 2. 비즈니스 / 법적 위험 (Business / Legal)

### R-B01 [Critical] 저작권 침해 (메이커가 타사 LUT 무단 업로드)

| 가능성 | 영향 | 점수 |
|---|---|---|
| 5 | 4 | 20 |

**시나리오**
- VSCO/Tezza 등 유료 프리셋을 무단 변환·업로드
- DMCA 통지 → 미대응 시 App Store 리젝트, 소송 가능성

**완화**
- 약관 / EULA에 책임 명시 (메이커가 권리 보유 책임)
- DMCA Takedown 양식 + 24시간 내 처리 SLA
- pHash 데이터베이스 구축(알려진 유료 LUT 식별)
- 반복 침해자 계정 정지(3회 strikes)
- 라이선스 표시 의무(CC-BY/CC0/All Rights Reserved)

---

### R-B02 [Critical] 미성년자 NSFW 노출 (App Store 정책 위반)

| 가능성 | 영향 | 점수 |
|---|---|---|
| 4 | 5 | 20 |

**시나리오**
- 사용자가 누드/성적 미리보기 이미지 업로드
- App Store에서 앱 즉시 제거(이전 사례 多)

**완화**
- 온디바이스 Vision/Core ML 1차 NSFW 검사 (업로드 전 차단)
- Cloud Vision SafeSearch 2차 검증 + 임계값 보수적 설정
- 업로드 시 명시적 동의(약관)
- 사용자 신고 1건만으로 즉시 비공개 → 사후 검토
- 미성년자 보호 모드: 13~17세 계정에 더 엄격한 콘텐츠 필터
- 모더레이터 24/7 커버리지(Phase 5+)
- App Store Age Rating 12+/17+ 사전 적합성 확인

---

### R-B03 [High] GDPR / 한국 개인정보보호법 위반

| 가능성 | 영향 | 점수 |
|---|---|---|
| 3 | 5 | 15 |

**대상**
- 사용자 사진(원본) 백엔드 업로드 시 개인정보
- 위치/기기 식별자 (IDFA, IDFV)
- 미성년자 데이터(COPPA)

**완화**
- **사진 원본은 기본 업로드 안 함** (필터 메타데이터 + 미리보기만)
- App Tracking Transparency (`ATTrackingManager`) 정확히 구현
- 데이터 처리 동의 이중 확인(가입 + 첫 업로드)
- 데이터 내보내기 / 삭제 API (30일 grace)
- 개인정보처리방침 한/영 이중 게시
- 제3자 공유 시 명시(Algolia, Sentry, Crashlytics, PostHog)
- App Privacy 라벨 정확히 신고
- 한국 ISMS-P / GDPR 컨설턴트 검토(Phase 5)

---

### R-B04 [High] App Store 결제 정책 변경 (Apple)

| 가능성 | 영향 | 점수 |
|---|---|---|
| 4 | 4 | 16 |

**시나리오 (역사적 사례)**
- 2024 EU DMA → 외부 결제 일부 허용
- 향후 IAP 30% → 17% 인하 가능성
- 우회 결제 시 앱 제거 위험

**완화**
- 1차: IAP 100% 준수 (StoreKit 2)
- 2차: 메이커 정산은 Stripe Connect(앱 외부)
- 3차: 정책 변경 시 빠른 대응(Firebase Remote Config 피처 플래그)

---

### R-B05 [Medium] 광고/홍보 콘텐츠로 마켓 오염

| 가능성 | 영향 | 점수 |
|---|---|---|
| 4 | 2 | 8 |

**완화**
- 필터 설명에 외부 링크/연락처 금지 룰
- 광고성 키워드 자동 검출
- 검증된 브랜드는 별도 "Brand" 라벨

---

### R-B06 [Medium] 메이커 정산 분쟁

| 가능성 | 영향 | 점수 |
|---|---|---|
| 3 | 3 | 9 |

**완화**
- 정산 명세서 자동 생성
- Stripe Connect 사용으로 분쟁 처리 표준화
- 약관에 분쟁 해결 절차 명시

---

### R-B07 [High] iOS 단독 출시로 Android 시장 기회비용 — 잠재 사용자 손실

| 가능성 | 영향 | 점수 |
|---|---|---|
| 3 | 4 | 12 |

**시나리오**
- 인도, 동남아, 아프리카 등 Android 비중 높은 시장의 잠재 사용자(약 70% 점유) 미커버
- 글로벌 MAU 상한이 절반 가까이 제약될 가능성
- 경쟁사가 Android 우선 진입 → 시장 선점 리스크

**완화 (트레이드오프)**
- **집중도 향상의 이점**: iOS 네이티브 표현력으로 차별화 → App Store 피처드 기회 + 핵심 페르소나(북미·서유럽·한국·일본 크리에이터)는 iOS 비중 65%+
- Phase 4에 **Android 진출 의사결정 게이트** 명시 (네이티브 Kotlin / Compose MP / iOS only 유지 중 택1)
- 도메인 모델/.fmpkg 포맷/REST API는 플랫폼 중립적으로 설계 → 향후 포팅 시 자산 재사용
- iOS 단독 마케팅 전략(Apple 생태계 ASO, App Store 피처드 적극 추구)
- Phase 1~3 동안 정량 시장 데이터(국가별 MAU, 매출, 메이커 분포) 수집

**잔여 위험 수용 사유**: 팀 4명 규모로 Android 동시 개발은 비현실적 (이전 Compose MP 검토에서 PoC 비용 + iOS 카메라 surface 통합 리스크가 컸음). 시장 검증 후 결정이 합리적

---

## 3. 운영 위험 (Operational)

### R-O01 [High] 인기 필터 트래픽 폭증 (스파이크)

| 가능성 | 영향 | 점수 |
|---|---|---|
| 3 | 4 | 12 |

**시나리오**
- 인플루언서가 SNS에 필터 공유 → 1시간에 100K 다운로드 시도

**완화**
- Cloudflare CDN edge 캐시(30일 TTL) → origin 부하 거의 0
- versioned URL → cache hit ratio ≥ 95%
- API에서 인기 필터 메타는 Memorystore(Redis)에 1분 캐시
- 자동 스케일(Cloud Run min=0, max=100)
- DDoS 방지(Cloudflare Pro)

---

### R-O02 [High] 스토리지 비용 통제 실패

| 가능성 | 영향 | 점수 |
|---|---|---|
| 3 | 4 | 12 |

**원인**
- 필터당 평균 500KB × 50K 필터 = 25GB → 작음
- 그러나 사용자 사진 백업 옵션 활성화 시 폭증 (Phase 6+)

**완화**
- 사진 백업은 옵션, 무료 100MB/유저, 추가는 구독
- 6개월 비활성 필터(다운로드 0) 자동 cold storage 이동
- 매월 스토리지 비용 vs 매출 비율 모니터링

---

### R-O03 [High] 모더레이션 큐 적체

| 가능성 | 영향 | 점수 |
|---|---|---|
| 4 | 3 | 12 |

**완화**
- 자동 모더레이션이 95% 이상 처리 (온디바이스 Vision + Cloud Vision)
- 신고 우선순위 큐
- 외부 모더레이션 BPO(Phase 5+ 옵션)
- SLA 미달성 알람(24h 이상 큐 대기)

---

### R-O04 [Medium] 스팸 메이커 / 봇 가입

| 가능성 | 영향 | 점수 |
|---|---|---|
| 3 | 3 | 9 |

**완화**
- 가입 시 Sign in with Apple/Google IdP만 (이메일 직접 가입 후순위)
- App Attest로 디바이스 무결성 검증
- 신규 계정 24시간 업로드 제한(쿨다운)
- 동일 IP 다계정 검출
- 업로드 quota: 20/day

---

### R-O05 [Medium] 핵심 인력 의존(Bus factor)

| 가능성 | 영향 | 점수 |
|---|---|---|
| 3 | 3 | 9 |

**완화**
- 코드 리뷰 강제 + 페어 프로그래밍
- ADR(Architecture Decision Record) 문서화
- 온콜 로테이션
- 매주 KT(Knowledge Transfer) 세션
- DocC로 SPM 모듈 API 문서화

---

### R-O06 [Medium] 외부 SaaS 장애 (Firebase/Cloudflare)

| 가능성 | 영향 | 점수 |
|---|---|---|
| 2 | 4 | 8 |

**완화**
- Firebase 다운: Cloudflare에 CDN 캐시된 정적 콘텐츠는 동작 → 전체 다운 회피
- Cloudflare 다운: 임시 fallback URL (직접 R2 액세스 키)
- 상태 페이지 모니터링(Statuspage 통합)

---

## 4. 위험 매트릭스

```mermaid
quadrantChart
    title Risk Matrix (Likelihood vs Impact)
    x-axis Low Likelihood --> High Likelihood
    y-axis Low Impact --> High Impact
    quadrant-1 Mitigate Now (Critical)
    quadrant-2 Monitor Closely (High)
    quadrant-3 Accept (Low)
    quadrant-4 Plan For (Medium)
    "R-T01 MSL Shader Security": [0.75, 0.75]
    "R-B01 Copyright": [0.95, 0.8]
    "R-B02 NSFW Minor": [0.75, 0.95]
    "R-B03 GDPR/PIPA": [0.55, 0.95]
    "R-B04 Apple IAP Policy": [0.75, 0.75]
    "R-B07 Android Opportunity": [0.55, 0.75]
    "R-T02 LUT Precision": [0.55, 0.75]
    "R-T03 Battery/Thermal": [0.75, 0.55]
    "R-T04 iOS Compatibility": [0.55, 0.75]
    "R-T05 Firebase Cost": [0.55, 0.75]
    "R-O01 Traffic Spike": [0.55, 0.75]
    "R-O02 Storage Cost": [0.55, 0.75]
    "R-O03 Mod Backlog": [0.75, 0.55]
```

---

## 5. 위험 거버넌스

### 5.1 책임자 (Risk Owners)

| 영역 | 1차 책임자 |
|---|---|
| 기술 (T) | iOS 리드 / 백엔드 리드 |
| 비즈니스/법적 (B) | PM + 외부 법무 자문 |
| 운영 (O) | DevOps + CS 매니저 |
| 플랫폼 전략 (Android 진출) | 창립 PM + iOS 리드 (Phase 4 게이트 공동 결정) |

### 5.2 검토 주기

- **주간**: 운영 위험 상태 (Red/Amber/Green)
- **월간**: 모든 Critical/High 재검토
- **분기**: 전체 위험 등록부 재점검 + 신규 위험 추가
- **출시 전**: Phase 종료 시 게이트로 사용
- **Phase 4 종료 시점**: R-B07(Android 시장 기회비용) 정량 평가 + 의사결정

### 5.3 완화 추적

각 위험은 다음 상태를 추적:
- `Open`: 미해결
- `Mitigated`: 완화책 구현 완료
- `Accepted`: 잔여 위험 수용 결정 (책임자 + 사유 기록)
- `Closed`: 위험 사라짐 (조건 변화)

---

## 6. 잔여 위험 (Residual Risk Acceptance)

다음 위험은 완화 후에도 잔여 위험이 존재하며 비즈니스적으로 수용한다:

| 위험 | 잔여 영향 | 수용 사유 |
|---|---|---|
| R-T03 배터리/발열 | 5분 사용 시 배터리 5~7% | 카메라 앱 본질적 한계, UX로 보완 |
| R-O01 트래픽 스파이크 | 첫 1분 캐시 미스 | CDN warm-up 후 자연 해소 |
| R-B04 Apple 정책 변경 | 매출 모델 재설계 위험 | 시장 조건, 통제 불가 |
| R-B07 Android 미커버 시장 | iOS 단독으로 글로벌 MAU 상한 제약 | 팀 규모/집중도 측면에서 합리적, Phase 4 게이트로 재평가 |

---

## 7. 관련 문서
- [PRD.md](./PRD.md)
- [ARCHITECTURE.md](./ARCHITECTURE.md)
- [SYSTEM_DESIGN.md](./SYSTEM_DESIGN.md)
- [TECH_STACK.md](./TECH_STACK.md)
- [TASK_LIST.md](./TASK_LIST.md)
