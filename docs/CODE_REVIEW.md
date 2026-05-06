# moodit Code Review v1.0

> 작성일: 2026-05-06 · 리뷰어: oh-my-claudecode:code-reviewer (Opus)
>
> Phase D6 + rename + brand 통합 후 시점의 종합 리뷰. 향후 cleanup 액션 트래킹.

---

## Executive Summary

**전체 코드 품질: 8.0 / 10** (Critical 0 · High 5 · Medium 11 · Low 9)

### Top 5 강점
1. 모듈 경계 깨끗 — `DesignSystem`, `Models`가 leaf
2. Swift 6 strict concurrency 의도적 설계 — `Sendable`, `@MainActor`, `actor FilterCache`
3. D0 토큰 시스템 정돈됨 — `FMColors.*` light/dark 듀얼 1:1 매핑
4. 카메라 라이프사이클 정확 — `scenePhase` 분기, `[weak self]` 일관, double-resume 가드
5. `PhotoLibrarySaver`의 DI 설계 모범적 — closure 주입 `Sendable` struct

### Top 5 개선 필요
1. `Sources/App/AppComponents.swift` D0 마이그레이션 미완 — `FMColor.*`/`FMSpacing.*` 7회 잔존
2. 에러 silent swallow — `MooditStore.load()` `catch { filters = [] }`
3. D3~D6 SwiftUI 화면 ~5,500 LOC 테스트 0건
4. `CameraScreen.swift` 1,031 LOC — God Object 스멜
5. `PermissionCoordinator.requestLocation` 30초 main-thread 폴링

---

## High 우선순위 5건 (즉시 수정)

| # | 파일:라인 | 항목 |
|---|---|---|
| 1 | `Sources/App/Search/SearchScreen.swift:444~448` | 검색 무결과 → 전체 노출 fallback 제거 |
| 2 | `Sources/App/MooditStore.swift:36~38` | load() silent failure → `loadError` state |
| 3 | `Sources/App/CameraScreen.swift:867~894` | capture 실패 사용자 알림 |
| 4 | `Sources/App/AppComponents.swift` | deprecated alias 마이그레이션 + `@available` |
| 5 | `Sources/App/Permissions/PermissionCoordinator.swift:181~190` | 30초 폴링 → AsyncStream |

## Medium 우선순위 11건

| 파일 | 항목 |
|---|---|
| `CameraScreen.swift` 1031 LOC | 4~5 파일로 분할 |
| `Sources/App/Permissions/*` 8 화면 | `PermissionScreen(permission:kind:)` 통합 |
| `project.yml` Marketplace 타겟 | Resources 명시 |
| `PhotoFilterRenderer.apply` | async 화 (background actor) |
| `MetalPreviewRenderer` first-frame | source compile fallback 검토 |
| `MarketplaceScreen.isLoading` | loadError 분기 추가 |
| Photos save 거부 후 흐름 | "설정 열기" CTA 부재 |
| `MetalPreviewRenderer.stop()` | `currentFrame = nil` 추가 |
| `MockFilterRepository` vs `BundleSeedFilterRepository` | source-of-truth 단일화 |
| `LUTImageDecoder` | 외부 다운로드 도입 시 PNG bomb 가드 |
| `CapturePreviewScreen` placeholder | VoiceOver 라벨 누락 |

## Low 우선순위 9건

`Color.black.opacity(...)` hardcoded 빈도 / inline `.font(.system(size:))` / `Auth/AuthPlaceholder.swift` placeholder / `Storage/FilterCache.swift` placeholder / swipe hint chevron `.accessibilityHidden(true)` / 350ms hard-coded delay / `MooditStore.select` vs `download` 책임 모호 / 검색 query memory 처리 / 350 ms skeleton fake delay 운영 전 제거

---

## 보안 체크리스트 (OWASP Mobile Top 10)

| 항목 | 상태 | 비고 |
|---|---|---|
| M1 Credential Usage | ⚠️ | Firebase API_KEY plist (의도) — App Check 활성화 필수 |
| M2 Supply Chain | ✅ | Apple SPM 만 |
| M3 Authentication | ⏳ | placeholder, 후속 phase |
| M4 Input Validation | ⚠️ | LUT PNG 외부 다운로드 시 가드 필요 |
| M5 Communication | ✅ | ATS 기본값 |
| M6 Privacy | ✅ | usage description 명확 |
| M7 Binary Protection | ⏳ | obfuscation 미적용 (일반적 모바일) |
| M8 Security Misconfiguration | ⚠️ | `firestore.rules` default-deny + TODO — 운영 전 채워야 |
| M9 Data Storage | ✅ | `@AppStorage("hasOnboarded")` 만 |
| M10 Cryptography | N/A | 현재 미사용 |

---

## 정리(Cleanup) 진행 추적

| 항목 | 상태 | 커밋 |
|---|---|---|
| H1 SearchScreen 무결과 fallback 제거 | ⏳ | — |
| H2 MooditStore loadError 추가 | ⏳ | — |
| H3 CameraScreen capture 실패 알림 | ⏳ | — |
| H4 AppComponents alias 마이그레이션 | ⏳ | — |
| H5 PermissionCoordinator 30초 폴링 → AsyncStream | ⏳ | — |
| M1~M11 | 후속 | — |
| L1~L9 | 후속 | — |

---

## 보고서 풀버전

상세 발견사항(파일:라인 + 의사코드 권장 수정)은 리뷰 세션 transcript 참조. 본 문서는 추적 요약본.
