# moodit - Product Requirements Document (PRD)

> 버전: v1.1 (Draft, iOS native pivot) · 작성일: 2026-05-06 · 상태: Planning

---

## 1. 비전 (Vision)

**"누구나 자신만의 카메라 필터를 만들고, 거래하고, 공유하는 글로벌 마켓플레이스 — iOS부터."**

moodit은 단순한 사진 보정 앱이 아니다. **창작자(필터 메이커)와 소비자(촬영자)를 연결하는 양면 마켓플레이스(two-sided marketplace)** 로, VSCO/Snapchat의 표현력을 PicsArt의 커뮤니티성과 결합한다. 사용자는:

1. 카메라 라이브 프리뷰에 Metal 기반 GPU 셰이더 필터를 실시간으로 적용해 촬영하고,
2. 노드/파라미터 기반 에디터로 필터를 직접 제작하며,
3. 마켓플레이스에 업로드해 다른 사용자와 거래(무료/유료)·평가·소통할 수 있다.

본 v1.0은 **iOS 단독 출시**로 시작하며, Android 진출은 Phase 4 이후 시장 반응을 기반으로 별도 의사결정한다.

### 1.1 차별화 포인트

| 경쟁 제품 | 한계 | moodit의 답 |
|---|---|---|
| VSCO | 필터는 공식 큐레이션만, 사용자 제작 불가 | UGC 필터 마켓플레이스 |
| Snapchat Lens Studio | 데스크탑 전용 + AR 중심, 카메라 컬러그레이딩에 특화 안됨 | 모바일 온디바이스 필터 에디터 |
| Instagram | 필터 다양성 부족, 거래 불가 | 필터 자체가 제품(상품) |
| PicsArt | 후보정 위주, 라이브 카메라 약함 | 라이브 카메라 + 마켓 동시 충족 |
| Lightroom Mobile | 프리셋 공유 있지만 GPU 셰이더 없음, 거래 인프라 부재 | MSL 셰이더 + 거래 결합 |
| Halide / Darkroom | 단일 앱 도구, UGC 마켓 부재 | iOS 네이티브 표현력 + 커뮤니티 |

---

## 2. 타겟 사용자 (Target Users)

### 2.1 시장 규모 추정

- 글로벌 사진 편집 앱 사용자: 약 8억 명 (Statista, 2024)
- 글로벌 iOS 사진/카메라 카테고리 활성 사용자: 약 3억 명
- 인플루언서 마케팅 시장: 약 \$24B (2024) → 콘텐츠 차별화 수요 증가
- TAM(전체) → SAM(iOS 사진/영상 사용자) → SOM(필터 적극 사용자, 약 2천만 명) 가정
- 핵심 가정: **북미·서유럽·한국·일본의 인플루언서/콘텐츠 크리에이터는 iOS 비중이 65~75%** → iOS 단독 출시로도 핵심 페르소나 커버 가능

### 2.2 1차 타겟 페르소나

#### 페르소나 A: "콘텐츠 크리에이터 — 지수 (24, 여성)"
- iPhone 14 Pro 사용, 인스타그램 팔로워 8천 명, 일상/카페 사진 업로드
- VSCO 유료 구독 중, 매번 같은 프리셋에 식상함
- **Pain Point**: 차별화된 분위기를 원하지만 본인이 만들 도구가 없음
- **moodit 가치**: 다른 크리에이터가 만든 독특한 필터를 발견하고, 좋아한 필터의 변형(remix)을 시도

#### 페르소나 B: "필터 메이커 — Alex (29, 남성, 디자이너)"
- iPhone 15 Pro + iPad 사용, 컬러그레이딩 취미, Lightroom 프리셋 판매 경험 있음
- **Pain Point**: 프리셋은 정적이고 GPU 셰이더는 표현력이 좋지만 판매 채널이 없음
- **moodit 가치**: 자신이 만든 MSL 기반 셰이더 필터를 마켓에 올려 수익화 + 브랜딩

#### 페르소나 C: "캐주얼 사용자 — 민준 (17, 남성, 학생)"
- iPhone 13 사용, 친구들과 셀카·스냅 위주
- **Pain Point**: 너무 많은 보정 앱 → 매번 다른 앱 전환 피곤
- **moodit 가치**: 친구가 만든 재미있는 필터를 다운로드해 즉시 사용

### 2.3 2차 타겟

- 소규모 브랜드(카페·의류·인플루언서 마케팅 에이전시) — 자체 브랜드 필터 배포
- 사진 학원/교육자 — 학생 과제용 필터 셋

---

## 3. 핵심 기능 (Core Features)

### 3.1 기능 우선순위 매트릭스 (MoSCoW)

| 기능 | 우선순위 | MVP 포함 |
|---|---|---|
| 카메라 라이브 프리뷰 + 필터 실시간 적용 | Must | Yes |
| 사진 촬영 + 갤러리 저장(Photos framework) | Must | Yes |
| 내장 기본 필터 10~15개 | Must | Yes |
| 사용자 인증 (Sign in with Apple / Google) | Must | Yes |
| 필터 다운로드 / 마켓 둘러보기 | Must | Yes |
| 필터 에디터 (LUT + 파라미터 기반) | Must | Yes (간이형) |
| 필터 업로드 + 메타데이터 | Must | Yes |
| 검색 + 카테고리 | Should | Yes |
| 평점·댓글·좋아요 | Should | Phase 3 |
| 추천 시스템 | Could | Phase 4 |
| 노드 기반 셰이더 에디터 | Could | Phase 2~3 |
| 모더레이션 + 신고 | Should | Phase 5 |
| 유료 필터 / 결제 | Could | Phase 6 |
| Vision 기반 얼굴 검출(자동 인물 보정 보조) | Could | Phase 4 |
| 영상 필터 / Stories | Won't (v1) | No |
| AR 얼굴 필터 (랜드마크/3D 마스크) | Won't (v1) | No |
| Android 출시 | Won't (v1) | Phase 4 게이트 후 결정 |

### 3.2 기능 상세

#### F1. 카메라 + 실시간 필터
- 전·후면 카메라 전환, 줌, 노출/포커스 탭(`AVCaptureDevice` 제어)
- 16:9, 4:3, 1:1 비율 지원
- `AVCaptureSession` + `AVCaptureVideoDataOutputSampleBufferDelegate` → CVPixelBuffer → MTLTexture
- Metal 셰이더 기반 GPU 필터 파이프라인 (CPU 후처리 금지, FPS≥30 목표, A14 이상에서 60FPS)
- 필터 강도(Intensity) 슬라이더 (0~100%)
- 촬영 시 원본 + 필터 적용본 동시 저장 옵션 (`AVCapturePhotoOutput`)

#### F2. 갤러리 / 후보정 적용
- Photos framework + `PHPickerViewController`로 사진 가져오기
- 필터 변경 시 즉시 미리보기
- 비교(Before/After) 토글
- HEIC/JPEG 입출력 지원

#### F3. 필터 에디터 (단계적 출시)
- **Tier 1 (MVP)**: LUT(.cube/.png) 업로드 + 노출/대비/채도/온도/색조 등 7~10개 파라미터
- **Tier 2 (Phase 2)**: 파라미터 자동 시각화, 비네트, 그레인, 페더 등
- **Tier 3 (Phase 3)**: 노드 그래프 에디터(고급 사용자용) — 메이커가 직접 셰이더 코드를 작성하는 모드는 v1 외(보안 검증 후 Phase 5+)

#### F4. 마켓플레이스
- 홈 피드: 인기/추천/신규 탭
- 카테고리: Vintage, Cinematic, Portrait, Pastel, B&W, Mood, Anime 등
- 검색: 키워드, 태그, 색감 톤
- 필터 상세: 미리보기 슬라이드, 제작자 프로필, 다운로드 카운트, 평점, 댓글
- 내 필터 / 다운로드한 필터 / 즐겨찾기

#### F5. 소셜 기능
- 사용자 프로필 (아바타, 바이오, 만든 필터 목록)
- 팔로우 / 팔로잉
- 필터 적용 사진 공유 피드 (선택적, Universal Link 공유)

#### F6. 인증 / 계정
- Sign in with Apple (iOS 강제 정책 준수, AuthenticationServices)
- Sign in with Google (Firebase Auth + Google SDK)
- 익명 게스트 모드(둘러보기만 가능, 업로드/다운로드 불가)

---

## 4. 사용자 스토리 (User Stories)

```markdown
US-01 [촬영자] 카페에서 음료 사진을 찍으면서, 빈티지 필름 느낌의 필터를 라이브로 보고 싶다.
US-02 [촬영자] 마켓에서 "여름 파스텔" 키워드로 검색해 마음에 드는 필터를 다운로드하고 싶다.
US-03 [촬영자] 다른 사용자의 사진에 적용된 필터가 마음에 들어 그 필터로 바로 이동하고 싶다.
US-04 [메이커] 내가 만든 LUT를 업로드하고, 강도 파라미터를 조정 가능하게 설정하고 싶다.
US-05 [메이커] 내 필터의 다운로드 수 / 평점을 대시보드에서 확인하고 싶다.
US-06 [메이커] 유료 필터로 전환하여 \$0.99에 판매하고 싶다 (Phase 6).
US-07 [관리자] 부적절한 콘텐츠로 신고된 필터를 검토하고 비공개 처리하고 싶다.
US-08 [캐주얼] 친구가 보낸 Universal Link를 누르면 앱이 열리며 필터가 즉시 적용되길 원한다.
US-09 [메이커] 다른 사람 필터의 "Remix"(파생) 버전을 만들고 원본을 크레딧 표기하고 싶다.
US-10 [촬영자] 오프라인에서도 다운로드한 필터로 촬영할 수 있어야 한다.
```

---

## 5. 성공 지표 (KPI)

### 5.1 North Star Metric
- **Weekly Active Filter Applications (WAFA)**: 주간 필터 적용 횟수 (촬영 + 후보정)
- 이유: 마켓·에디터·카메라 전체 가치사슬을 통합적으로 측정

### 5.2 보조 지표

| 카테고리 | 지표 | MVP 목표 (iOS 출시 후 6주) | 12개월 목표 |
|---|---|---|---|
| 출시 | iOS App Store 출시 (TestFlight → Production) | 6주 | - |
| 획득 | iOS MAU | 8K | 200K |
| 활성화 | D1 리텐션 | 35% | 45% |
| 활성화 | 첫 촬영까지 시간 | <60s | <30s |
| 참여 | 사용자당 일평균 필터 적용 | 3 | 8 |
| 참여 | 마켓 둘러보기 → 다운로드 전환율 | 5% | 12% |
| 메이커 | 누적 업로드 필터 수 | 1K | 50K |
| 메이커 | 메이커 활성률(주 1회 이상 업로드) | 200명 | 5K |
| 품질 | 카메라 평균 FPS | ≥30 (전체) | ≥60 (A14+) |
| 품질 | 크래시율 (Crashlytics) | <1% | <0.3% |
| 마케팅 | App Store 피처드(Today/Apps) | - | 1회 이상 |
| 수익 (Phase 6) | 유료 필터 매출 | - | \$50K/월 |

---

## 6. MVP vs 후속 버전 범위

### 6.1 MVP (Phase 0~1, 약 7주)
- **iOS 단독 출시** (Android 미포함 — Phase 4 이후 별도 결정)
- 기본 카메라 + 15개 내장 필터 + 사진 저장
- 사용자 인증(Sign in with Apple/Google)
- 마켓 둘러보기 + 다운로드 (무료만)
- 간이 LUT 업로드 에디터
- Firebase + Cloudflare R2 백엔드

### 6.2 Phase 2~3 (약 +11주)
- 파라미터 기반 에디터 강화
- 검색·카테고리·평점·댓글
- 사용자 프로필 + 팔로우

### 6.3 Phase 4~5 (약 +8주)
- 추천 시스템 (Algolia + co-occurrence)
- 모더레이션 / 신고 / 자동 필터링 (Cloud Vision + 온디바이스 Vision)
- 셰이더 노드 에디터 (베타)
- **Android 진출 의사결정 게이트** (네이티브 Kotlin / Compose MP / iOS only 유지)

### 6.4 Phase 6+ (수익화)
- 유료 필터 / Apple IAP + Stripe Connect 정산
- 메이커 정산 시스템
- 영상 / Reels-style / AR 얼굴 필터(Vision/ARKit)

---

## 7. 경쟁 분석 (Competitive Landscape)

| 제품 | 강점 | 약점 | moodit 대응 |
|---|---|---|---|
| **VSCO** | 큐레이션 품질, 브랜드 | UGC 필터 없음, 거래 부재 | 사용자 제작 + 거래 |
| **Snapchat / Lens Studio** | AR/얼굴 필터 압도적, Lens Studio 강력 | 데스크탑 도구 한정, 컬러그레이딩 약함 | 모바일 온디바이스 LUT/MSL 셰이더 에디터 |
| **Instagram** | 사용자 베이스 | 필터 다양성 작음, 마켓 없음 | 필터 자체를 상품으로 |
| **PicsArt** | 풍부한 후보정 도구 | 라이브 카메라 부족, UI 복잡 | 단순 + 라이브 강조 |
| **Lightroom Mobile** | 프로 사용자 신뢰 | 셰이더 부재, 진입장벽 높음 | 모바일 친화적 셰이더 |
| **Halide / Darkroom** | iOS 네이티브 화질, 피처드 사례 | UGC 마켓 부재, 단일 도구 | 같은 iOS 깊이 + 커뮤니티 |
| **Hipstamatic / Huji** | 빈티지 한 가지 콘셉트 | 확장성 부족 | 무한한 필터 풀 |
| **Foodie / B612** | 셀피 특화 | 필터 마켓 부재 | 마켓플레이스 차별화 |

### 7.1 iOS 우선 출시 사례 분석
- **Halide**: iOS 네이티브 카메라 앱, App Store 피처드 다수, Apple Design Award 수상 → 네이티브 표현력의 마케팅 가치
- **Darkroom**: iOS 우선 → 충성 사용자 확보 후 macOS/iPadOS로 확장
- **Procreate**: 동일 패턴 — iPad 단독 출시 후 시장 장악
- **시사점**: iOS 단독 출시가 오히려 App Store 알고리즘과 피처드 노출에 유리, 초기 6개월 집중도가 높다

### 7.2 진입 장벽 / 해자(Moat)
- **양면 네트워크 효과**: 메이커가 많을수록 촬영자 가치↑, 촬영자가 많을수록 메이커 수익↑
- **필터 라이브러리 자산**: 시간이 지날수록 가치 누적
- **Metal 파이프라인 노하우**: iOS에서 60FPS + 4-pass 셰이더는 비자명한 엔지니어링이며, 추후 Android 포팅 시 동일 LUT/파라미터 자산 재사용 가능

### 7.3 위협
- 대형 플랫폼(Instagram/TikTok)이 유사 기능 출시 → **빠른 메이커 커뮤니티 확보가 필수**
- Apple의 정책 변경(IAP 강제 등) → 결제 우회 경로 사전 검토
- iOS 단독으로 인한 Android 시장 기회비용 → Phase 4에 정량 평가 후 결정

---

## 8. 가정과 의존성 (Assumptions & Dependencies)

### 가정
- iOS 17+ Metal 3로 1080p@60fps 라이브 필터 가능 (A14 Bionic 이상)
- LUT 기반 필터가 메이커 진입장벽을 충분히 낮춘다
- 1차 타겟(크리에이터·셀피 사용자)의 iOS 비중이 충분히 높다 (북미·서유럽·한국·일본 60% 이상)
- 한국·동남아 시장이 초기 베타에 적합하다 (셀피 문화 강함)

### 외부 의존성
- Firebase Auth / Firestore / Cloud Functions 가용성 및 가격
- Apple App Store 심사 정책 (특히 UGC 모더레이션 요구 + 24h SLA)
- 결제(Phase 6): IAP(Apple) 30%/15% 수수료 vs Stripe(웹 결제 우회 가능성)

---

## 9. Out of Scope (v1)

- Android 출시 (Phase 4 게이트 후 별도 결정)
- 영상 필터, Stories
- AR 얼굴 트래킹 / 3D 마스크 (ARKit)
- 데스크탑 / 웹 에디터
- 음악·오디오 편집
- 라이브 스트리밍

> 위 항목은 명시적으로 v1에서 제외하며, 로드맵 검토 시 재논의한다.

---

## 10. 관련 문서

- [ARCHITECTURE.md](./ARCHITECTURE.md) — 시스템 아키텍처
- [SYSTEM_DESIGN.md](./SYSTEM_DESIGN.md) — 핵심 시스템 상세 설계
- [TECH_STACK.md](./TECH_STACK.md) — 기술 스택 결정
- [TASK_LIST.md](./TASK_LIST.md) — 단계별 작업 분해
- [RISKS.md](./RISKS.md) — 위험요소 및 대응
