# moodit · Risk Register (PM View)

> **위험 점수** = 발생가능성(1~5) × 영향(1~5). ≥15 Critical / 10~14 High / 5~9 Medium / ≤4 Low.
> 원본/상세: [`../../docs/RISKS.md`](../../docs/RISKS.md). 본 문서는 PM 의사결정 우선순위로 정렬한 *짧은* 등록부.
>
> 검토 주기: 주간(운영) · 월간(Critical/High) · 분기(전체) · Phase 게이트(필수).

## 1. Top 10 (점수 순)

| # | ID | 위험 | 영역 | 점수 | 1차 책임자 | 즉시 대응 |
|---|---|---|---|---|---|---|
| 1 | R-B01 | 메이커 무단 LUT 업로드 (저작권) | 비즈/법무 | **20** | PM + 법무 | DMCA 절차 + pHash DB + 약관 |
| 2 | R-B02 | 미성년자 NSFW 노출 (App Store 정책) | 비즈/법무 | **20** | PM + 법무 | 온디바이스 Vision + Cloud Vision 2단 |
| 3 | R-T01 | 사용자 MSL 셰이더 보안 (GPU 남용/크래시) | 기술 | **16** | iOS 리드 | v1 비허용. Phase 3+ 다층 방어 |
| 4 | R-B04 | Apple IAP 정책 변경 | 비즈 | **16** | PM | StoreKit2 100% + Remote Config |
| 5 | R-B03 | GDPR / 한국 개인정보보호법 | 비즈/법무 | **15** | PM + 법무 | 사진 원본 미업로드, ATT, 데이터 내보내기·삭제 |
| 6 | R-T02 | LUT 정밀도 부족 (banding) | 기술 | 12 | iOS 리드 | trilinear + dithering, 65³ premium |
| 7 | R-T03 | iPhone 배터리/발열 | 기술 | 12 | iOS 리드 | thermalState 모니터, 단순화 패스 |
| 8 | R-T04 | iOS 디바이스 호환성 (구형 칩) | 기술 | 12 | iOS 리드 | 디바이스 등급별 화질 자동 조정 |
| 9 | R-T05 | Firebase 비용 폭증 | 기술/운영 | 12 | 백엔드 리드 | 캐싱 + 페이지네이션 + 일일 알람 |
| 10 | R-B07 | iOS 단독 출시 → Android 시장 기회비용 | 비즈/전략 | 12 | 창립 PM + iOS 리드 | Phase 4 게이트로 정량 평가 |

## 2. Phase별 위험 게이트

| Phase | 진입 전 반드시 mitigated/accepted 상태 |
|---|---|
| Phase 1 → 2 | R-T03(발열), R-T04(호환성) — 실기기 검증 필수 |
| Phase 3 → 4 | R-B03(개인정보) — 데이터 내보내기/삭제 운영 SOP 확정 |
| Phase 4 → 5 | R-B07(Android) ADR 작성 |
| Phase 5 → 6 | R-B01(저작권), R-B02(NSFW) — 모더레이션 자동화 PoC 통과 |
| Phase 6 진입 | R-B04(IAP 정책) — StoreKit2 100% 준수 검증 + Remote Config 피처 플래그 |

## 3. 기술 위험 요약

| ID | 위험 | 핵심 완화 |
|---|---|---|
| R-T01 | 사용자 셰이더 GPU 남용 | v1 비허용 / Phase 3+ 화이트리스트+AST+timeout+서명 |
| R-T02 | LUT 색감 왜곡 | trilinear + dithering / 65³ premium / RGBA16F (Phase 3) |
| R-T03 | 배터리/발열 | idle FPS↓, thermalState 모니터, Low Power Mode |
| R-T04 | 구형 디바이스 | iPhone X 미만 720p+30FPS 강제 |
| R-T05 | Firestore 비용 | 클라이언트 캐싱(5min TTL), 페이지 limit=20, R2로 미디어 |
| R-T06 | 오프라인→온라인 동기화 | Firestore offline + URLSession Background + 멱등 op |
| R-T07 | iOS 메이저 업데이트 (매년 9월) | 6~7월 Developer Beta 검증, WWDC 영향 ADR |

## 4. 비즈/법무 위험 요약

| ID | 위험 | 핵심 완화 |
|---|---|---|
| R-B01 | 저작권 침해 | DMCA + pHash DB + 약관/EULA + 3-strike |
| R-B02 | NSFW (미성년자) | 온디바이스 Vision 1차 + Cloud Vision 2차 + 신고 1건 즉시 비공개 + Age Rating 12+/17+ 적합성 |
| R-B03 | GDPR/PIPA | ATT 정확 구현 + 데이터 내보내기/삭제(30일 grace) + 한·영 정책 + ISMS-P 컨설턴트 |
| R-B04 | Apple IAP 정책 변경 | StoreKit2 100% / 메이커 정산은 Stripe Connect 외부 / Remote Config 피처 플래그 |
| R-B05 | 광고/홍보 마켓 오염 | 외부 링크 금지, 자동 검출, "Brand" 라벨 |
| R-B06 | 메이커 정산 분쟁 | 자동 정산 명세서 + Stripe Connect 표준 |
| R-B07 | Android 미커버 시장 | Phase 4 게이트, .fmpkg 포맷 플랫폼 중립 설계 |

## 5. 운영 위험 요약

| ID | 위험 | 핵심 완화 |
|---|---|---|
| R-O01 | 인기 필터 트래픽 폭증 | Cloudflare CDN edge cache(30일 TTL), versioned URL, Redis 1분 캐시 |
| R-O02 | 스토리지 비용 통제 실패 | 6개월 비활성 필터 cold storage, 사진 백업은 옵션+무료 100MB |
| R-O03 | 모더레이션 큐 적체 | 자동 모더레이션 95%+, 24h SLA 알람, BPO Phase 5+ |
| R-O04 | 스팸/봇 가입 | Apple/Google IdP만 + App Attest + 24h 업로드 쿨다운 + 20/day quota |
| R-O05 | 핵심 인력 의존 (Bus factor) | ADR 문서화, 페어 프로그래밍, KT 세션 |
| R-O06 | 외부 SaaS 장애 | 캐시된 정적 콘텐츠 동작, 직접 R2 액세스 fallback |

## 6. 잔여 위험 (수용)

| 위험 | 잔여 영향 | 수용 사유 |
|---|---|---|
| R-T03 배터리/발열 | 5분 사용 시 5~7% | 카메라 앱 본질적 한계, UX로 보완 |
| R-O01 트래픽 스파이크 | 첫 1분 캐시 미스 | CDN warm-up 후 자연 해소 |
| R-B04 Apple IAP 변경 | 매출 모델 재설계 | 시장 조건, 통제 불가 |
| R-B07 Android 미커버 | 글로벌 MAU 상한 제약 | 팀 규모/집중도 합리적, Phase 4 게이트 재평가 |

## 7. 위험 거버넌스

### 책임자
| 영역 | 1차 책임자 |
|---|---|
| 기술 (T) | iOS 리드 / 백엔드 리드 |
| 비즈/법무 (B) | PM + 외부 법무 자문 |
| 운영 (O) | DevOps + CS 매니저 |
| 플랫폼 전략 (Android) | 창립 PM + iOS 리드 (Phase 4 공동) |

### 상태 추적
- `Open`: 미해결
- `Mitigated`: 완화책 구현 완료
- `Accepted`: 잔여 위험 수용 (책임자 + 사유 기록)
- `Closed`: 위험 사라짐

### 새 위험 추가 절차
1. ID 부여 (R-T#, R-B#, R-O#)
2. 발생가능성/영향/점수 계산
3. 이 표 + `docs/RISKS.md` 동시 갱신
4. 점수 ≥10이면 다음 분기 검토에 포함

---

**참조**: [`../../docs/RISKS.md`](../../docs/RISKS.md) (전체 등록부) · [`../roadmap/ROADMAP.md`](../roadmap/ROADMAP.md) (Phase 게이트)
