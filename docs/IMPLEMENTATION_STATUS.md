# filterMarket - Implementation Status

> 마지막 업데이트: 2026-05-06 16:56 KST · 기준 커밋/브랜치: 로컬 작업 상태 · 상태: Phase 0 실기기 검증 대기 / seed LUT loader 구현 완료
>
> 이 문서는 실제 구현 진행 상황, 검증 결과, 남은 작업, 다음 Phase 진입 조건을 기록한다. 전체 이슈 분해는 [IMPLEMENTATION_PLAN.md](./IMPLEMENTATION_PLAN.md)를 기준으로 한다.

---

## 1. 현재 요약

현재 구현은 **M0 - Bootstrap & Metal PoC**의 코드 구현과 로컬 빌드/Simulator 테스트까지 진행됐다. 남은 M0 차단 항목은 iPhone 실기기에서 카메라 preview, 방향/비율, FPS/GPU frame time을 측정하는 것이다.

완료된 범위:
- XcodeGen 기반 iOS 프로젝트 생성
- 앱/프레임워크 모듈 골격 추가
- 카메라 권한 및 `AVCaptureSession` 기반 프레임 수신 구조 추가
- `CVMetalTextureCache` 기반 Y/CbCr plane -> Metal texture 변환 구조 추가
- `MTKView` 기반 preview surface 추가
- 기본 YUV -> RGB MSL 셰이더 추가
- warm 3D LUT texture 생성 및 preview fragment path 결합
- 필터 intensity uniform과 SwiftUI slider 연결
- FPS, CPU frame time, GPU frame time instrumentation 추가
- SwiftUI `scenePhase` 기반 capture start/stop lifecycle 추가
- frame/view aspect ratio 기반 preview aspect-fill sampling 추가
- M0 실기기 검증 체크리스트 문서 추가
- 탭 기반 앱 shell 추가 (`Camera`, `Filters`, `Market`, `Profile`)
- 카메라 화면 컨트롤 UI 재구성: filter carousel, intensity slider, shutter/action buttons
- mock filter catalog와 library/market/detail/profile placeholder 화면 추가
- 필터 선택 상태를 `MetalPreviewRenderer`에 연결
- category 기반 procedural LUT preset 적용 경로 추가
- 앱 번들 seed filter manifest와 repository loader 추가
- seed filter LUT PNG fixture와 ImageIO 기반 LUT decoder 추가
- `engine.lutFile` 기반 preview LUT texture 적용 경로 추가
- `.metal` 빌드 타임 컴파일을 위한 Metal Toolchain 설치 및 스크립트화
- 필터/manifest 도메인 모델 추가
- LUT sampler와 기본 단위 테스트 추가
- LUT PNG decoder 단위 테스트 추가
- bundle seed filter repository 단위 테스트 추가
- build/test 스크립트 추가

아직 완료되지 않은 범위:
- 실기기 카메라 preview 검증
- 실기기 FPS/GPU time 측정
- 촬영/PhotoKit 저장
- 카메라 전/후면 전환, 포커스/노출, 비율 전환

---

## 2. 구현된 파일/구조

### 프로젝트/도구

| 파일 | 내용 |
|---|---|
| [project.yml](../project.yml) | XcodeGen 프로젝트 정의 |
| [filterMarket.xcodeproj](../filterMarket.xcodeproj/project.pbxproj) | 생성된 Xcode 프로젝트 |
| [.gitignore](../.gitignore) | Xcode/SwiftPM/secret 제외 |
| [.swiftlint.yml](../.swiftlint.yml) | SwiftLint 룰 초안 |
| [.swiftformat](../.swiftformat) | SwiftFormat 설정 |
| [README.md](../README.md) | 로컬 빌드/테스트 안내 |

### 스크립트

| 파일 | 내용 |
|---|---|
| [scripts/metal-toolchain.sh](../scripts/metal-toolchain.sh) | Metal Toolchain 설치 상태와 실행 파일 경로 확인 |
| [scripts/build.sh](../scripts/build.sh) | Metal Toolchain 지정 후 앱 빌드 |
| [scripts/build-for-testing.sh](../scripts/build-for-testing.sh) | Metal Toolchain 지정 후 테스트 빌드 |
| [scripts/test.sh](../scripts/test.sh) | Metal Toolchain 지정 후 Simulator 테스트 |

기본값:
- `METAL_TOOLCHAIN_ID=com.apple.dt.toolchain.Metal.32023.864`
- `DERIVED_DATA_PATH=.build/DerivedData`
- `IOS_TEST_DESTINATION=platform=iOS Simulator,name=iPhone 17,OS=26.3.1`

### 앱/모듈

| 모듈 | 주요 파일 | 현재 상태 |
|---|---|---|
| `App` | [FilterMarketApp.swift](../Sources/App/FilterMarketApp.swift), [RootShell.swift](../Sources/App/RootShell.swift), [CameraScreen.swift](../Sources/App/CameraScreen.swift), [FilterLibraryScreen.swift](../Sources/App/FilterLibraryScreen.swift), [MarketplaceScreen.swift](../Sources/App/MarketplaceScreen.swift), [ProfileScreen.swift](../Sources/App/ProfileScreen.swift), [FilterMarketStore.swift](../Sources/App/FilterMarketStore.swift), [AppComponents.swift](../Sources/App/AppComponents.swift), [Info.plist](../Sources/App/Info.plist) | 앱 엔트리, 탭 shell, 카메라/필터/마켓/프로필 mock 화면 |
| `Camera` | [CameraSession.swift](../Sources/Camera/CameraSession.swift) | 권한 요청, back camera session, video frame callback |
| `FilterEngine` | [MetalPreviewRenderer.swift](../Sources/FilterEngine/MetalPreviewRenderer.swift), [MetalPreviewView.swift](../Sources/FilterEngine/MetalPreviewView.swift), [PreviewFilter.swift](../Sources/FilterEngine/PreviewFilter.swift), [ShaderSources.swift](../Sources/FilterEngine/ShaderSources.swift), [LUTSampler.swift](../Sources/FilterEngine/LUTSampler.swift), [LUTImageDecoder.swift](../Sources/FilterEngine/LUTImageDecoder.swift), [LUTTextureFactory.swift](../Sources/FilterEngine/LUTTextureFactory.swift), [RenderMetrics.swift](../Sources/FilterEngine/RenderMetrics.swift), [PreviewUniforms.swift](../Sources/FilterEngine/PreviewUniforms.swift) | Metal preview renderer, Y/CbCr texture conversion, procedural LUT fallback, PNG LUT decoder, 3D LUT texture, intensity uniform, render metrics, LUT sampler |
| `Models` | [FilterModels.swift](../Sources/Models/FilterModels.swift), [FilterManifest.swift](../Sources/Models/FilterManifest.swift), [JSONCoding.swift](../Sources/Models/JSONCoding.swift) | 필터/manifest Codable 모델 |
| `Storage` | [FilterCache.swift](../Sources/Storage/FilterCache.swift) | actor 기반 in-memory cache 초안 |
| `Marketplace` | [FilterRepository.swift](../Sources/Marketplace/FilterRepository.swift), [BundleSeedFilterRepository.swift](../Sources/Marketplace/BundleSeedFilterRepository.swift), [Resources/SeedFilters/manifest.json](../Sources/Marketplace/Resources/SeedFilters/manifest.json), [Resources/SeedFilters/luts](../Sources/Marketplace/Resources/SeedFilters/luts) | Repository protocol, mock 구현, 앱 번들 seed catalog/LUT asset |
| `DesignSystem` | [DesignTokens.swift](../Sources/DesignSystem/DesignTokens.swift) | 색상/spacing token 초안 |
| `Auth` | [AuthPlaceholder.swift](../Sources/Auth/AuthPlaceholder.swift) | 인증 상태 placeholder |

### 셰이더

| 파일 | 내용 |
|---|---|
| [Shaders/BasicYUVShaders.metal](../Shaders/BasicYUVShaders.metal) | fullscreen vertex + YUV -> RGB + 3D LUT fragment |

현재 `FilterEngine`은 번들 `metallib`를 우선 사용하고, 실패 시 [ShaderSources.swift](../Sources/FilterEngine/ShaderSources.swift)의 런타임 문자열 컴파일로 fallback한다.

---

## 3. 검증 결과

### Metal Toolchain

설치 상태:

```text
Status: installed
Toolchain Identifier: com.apple.dt.toolchain.Metal.32023.864
```

검증 명령:

```bash
./scripts/metal-toolchain.sh
```

확인된 실행 파일:

```text
.../Metal.xctoolchain/usr/bin/metal
.../Metal.xctoolchain/usr/bin/metallib
```

### Build

검증 명령:

```bash
./scripts/build-for-testing.sh
```

결과:

```text
** TEST BUILD SUCCEEDED **
```

최근 검증:
- 2026-05-06 16:56 KST

중요 확인:
- [Shaders/BasicYUVShaders.metal](../Shaders/BasicYUVShaders.metal)이 Xcode `CompileMetalFile` 단계에서 컴파일됨
- 빌드 로그에서 Metal Toolchain 경로의 `metal` 실행 확인
- iPhoneOS generic destination 기준으로 Swift/Metal 빌드 성공

### Simulator Test

검증 명령:

```bash
./scripts/test.sh
```

결과:

```text
** TEST SUCCEEDED **
```

최근 검증:
- 2026-05-06 16:47 KST

테스트 결과:
- `ModelsTests.FilterManifestTests`: 1개 통과
- `FilterEngineTests.LUTSamplerTests`: 3개 통과
- `FilterEngineTests.LUTPresetTests`: 3개 통과
- `FilterEngineTests.LUTImageDecoderTests`: 2개 통과
- `MarketplaceTests.BundleSeedFilterRepositoryTests`: 4개 통과
- 총 13개 테스트, 0 failures

### Simulator UI Smoke

검증 내용:
- `iPhone 17` Simulator에 앱 설치/실행
- Camera 탭 초기 화면 렌더링 확인
- filter carousel, intensity slider, shutter/action buttons, bottom tabs 표시 확인

주의:
- iOS Simulator는 실제 카메라 프레임을 제공하지 않으므로 preview/FPS는 `0 FPS`로 표시된다.

주의:
- 현재 환경에서는 sandbox 권한에 따라 CoreSimulatorService 접근 문제가 발생할 수 있다.
- 이번 검증은 실제 사용자 권한으로 재실행해 통과했다.

---

## 4. M0 이슈 상태

| Issue | 제목 | 상태 | 비고 |
|---|---|---|---|
| M0-A01 | Xcode 프로젝트와 SPM 모듈 골격 생성 | Done | XcodeGen 기반 프로젝트 생성 |
| M0-A02 | SwiftLint/SwiftFormat 설정 추가 | Done | 설정 파일 추가, 도구 설치 검증은 별도 |
| M0-A03 | Debug/Staging/Release 설정과 xcconfig 골격 추가 | Partial | 기본 Debug/Release만 있음. env config는 후속 |
| M0-A04 | 기본 테스트 타깃과 fixture 구조 생성 | Done | Models/FilterEngine tests 추가 |
| M0-B01 | 카메라 권한 요청과 세션 lifecycle 구현 | Partial | 코드 추가, 실기기 검증 필요 |
| M0-B02 | `MTKView` 기반 Metal preview surface 구현 | Partial | 코드 추가, 실기기 검증 필요 |
| M0-B03 | `CVMetalTextureCache`로 Y/CbCr plane 텍스처 변환 | Partial | 코드 추가, 실기기 검증 필요 |
| M0-B04 | YUV->RGB MSL fragment shader 구현 | Partial | 빌드 타임 컴파일 확인, 화면 검증 필요 |
| M0-B05 | identity/warm LUT 적용 PoC 구현 | Partial | warm LUT preview path 결합, 실기기 시각 검증 필요 |
| M0-B06 | FPS/GPU 시간 측정 instrumentation 추가 | Partial | FPS/CPU/GPU 측정 코드와 UI 표시 추가, 실기기 수치 기록 필요 |
| M0-C01 | iPhone 실기기 preview smoke test | Not Started | [M0_DEVICE_VALIDATION.md](./M0_DEVICE_VALIDATION.md) 기준으로 진행 |
| M0-C02 | M0 성능 측정 결과 기록 | Not Started | 실기기 측정값 필요 |
| M0-C03 | preview orientation/crop 보정 | Partial | aspect-fill sampling 추가, 실기기 확인 필요 |
| UI-01 | App navigation shell 구성 | Done | `Camera`, `Filters`, `Market`, `Profile` 탭 추가 |
| UI-02 | Camera controls UI 정리 | Partial | simulator 렌더링 확인, 실기기 preview 위 배치 확인 필요 |
| UI-03 | Filter carousel 구현 | Partial | bundle seed catalog 선택 UI와 실제 seed LUT texture 적용 경로 연결, 실기기 시각 확인 필요 |
| M1-B02 | LUT PNG -> 3D texture loader 구현 | Done | 33^3 packed PNG decoder, seed LUT fixtures, manifest `lutFile` preview 연결, fallback 유지 |

---

## 5. 알려진 제약/리스크

1. **실기기 미검증**
   - iOS Simulator는 카메라 하드웨어를 검증할 수 없다.
   - M0 종료 기준은 반드시 iPhone 실기기에서 확인해야 한다.

2. **Metal Toolchain 지정 필요**
   - 이 Xcode 환경에서는 기본 `xcrun metal`이 Metal Toolchain을 자동 선택하지 않는다.
   - 빌드/테스트는 `-toolchain com.apple.dt.toolchain.Metal.32023.864`를 사용해야 한다.
   - 프로젝트 스크립트가 이를 기본값으로 처리한다.

3. **런타임 셰이더 fallback**
   - 현재는 번들 `metallib` 우선 + runtime source fallback 구조다.
   - Phase 1 이후에는 fallback 정책을 명확히 결정해야 한다.

4. **Swift 6 동시성**
   - `CameraSession`과 `MetalPreviewRenderer`는 현재 `@unchecked Sendable`을 사용한다.
   - 프레임 전달 경계와 renderer state 동기화는 M1 전에 재검토해야 한다.

---

## 6. 다음 작업 계획

### Next Sprint: M0 Device Validation

목표: 현재 코드가 실제 기기에서 라이브 preview로 동작하는지 확인하고, FPS/GPU 측정값을 확보한다.

| 순서 | 작업 | 완료 기준 |
|---|---|---|
| 1 | 실기기 빌드/실행 경로 확인 | iPhone에서 앱 실행, 카메라 권한 요청 확인 |
| 2 | 카메라 frame -> Metal preview 화면 검증 | back camera 영상이 `MTKView`에 표시 |
| 3 | YUV orientation/crop 확인 | portrait 화면에서 영상 방향과 비율이 수용 가능 |
| 4 | intensity slider 실기기 확인 | 0~100% 조절 시 preview 색감 변화 |
| 5 | FPS/GPU frame time 기록 | 화면 표시값 또는 log 기준으로 수치 확보 |
| 6 | background/foreground lifecycle 확인 | background 진입 시 capture 중지, 복귀 시 재개 |
| 7 | M0 결과 기록 | FPS, 기기 모델, iOS 버전, 병목 기록 |

### M0 종료 조건

- [ ] iPhone 12 이상에서 1080p 30FPS 이상
- [ ] iPhone 12 이상에서 60FPS 가능성 확인 또는 병목 기록
- [ ] 카메라 권한 거부/허용 플로우 동작
- [ ] 앱 background 진입 시 `AVCaptureSession` 정지
- [ ] PoC 결과를 본 문서 또는 별도 PR/issue에 수치로 기록

### 바로 생성할 이슈 후보

| Issue | 제목 | Labels | 완료 기준 |
|---|---|---|---|
| M0-C01 | iPhone 실기기 preview smoke test | `area:camera`, `area:filter-engine`, `type:test`, `priority:p0`, `device-required` | 영상 표시, 권한 허용/거부, background lifecycle 확인 |
| M0-C02 | M0 성능 측정 결과 기록 | `area:filter-engine`, `type:docs`, `priority:p0`, `device-required` | 기기/iOS/FPS/CPU ms/GPU ms 표 기록 |
| M0-C03 | preview orientation/crop 보정 | `area:camera`, `area:filter-engine`, `priority:p1`, `device-required` | portrait 기준 왜곡/회전 없이 preview 표시 |

### 코드 작업 기준 다음 순서

실기기 검증과 병행 가능한 다음 코드 작업은 **renderer/capture 공용 필터 적용 인터페이스 정리**다. preview는 이제 `engine.lutFile` 기반 LUT texture를 사용할 수 있으므로, 다음 구현에서는 같은 필터 chain을 사진 저장 경로에서도 재사용할 수 있게 분리한다.

---

## 7. 다음 Phase 계획: M1 - Camera MVP

M0 실기기 검증이 통과하면 M1로 진입한다. M1의 목표는 **로컬 필터를 선택해 실시간으로 촬영하고 사진 라이브러리에 저장하는 MVP 카메라**다.

### M1 우선순위

| Priority | 작업 | 이유 |
|---|---|---|
| P0 | PhotoKit 저장 | 촬영 앱의 최소 완성도 |
| P0 | 필터 intensity slider | 사용자 체감 핵심 |
| P0 | 로컬 seed filter loading | manifest loader와 seed LUT PNG loader 완료 |
| P1 | 전/후면 전환 | 기본 카메라 기대 기능 |
| P1 | 탭 포커스/노출 | 실제 촬영 품질 |
| P1 | 비율 1:1/4:3/16:9 | SNS 촬영 UX |
| P1 | 4-pass 파이프라인 정리 | Phase 2+ 에디터/마켓 필터 기반 |
| P2 | thermal/low power fallback | 장시간 사용 안정성 |
| P2 | 카메라 화면 XCUITest selector | 회귀 테스트 기반 |

### M1 구현 순서

1. renderer/capture 공용 필터 적용 인터페이스 정리
2. `AVCapturePhotoOutput` 기반 촬영 구현
3. 고해상 이미지에 동일 필터 chain 적용
4. PhotoKit 저장 및 권한 처리
5. 전/후면 전환, 탭 포커스/노출, 비율 전환 추가
6. 핵심 플로우 테스트 및 실기기 smoke test

### M1 진입 전 결정 필요

| 결정 | 선택지 | 권장 |
|---|---|---|
| seed filter 형식 | 임시 JSON+PNG / `.fmpkg` seed | `.fmpkg`에 가깝게 시작 |
| LUT 정밀도 | 33^3 RGBA8 / 33^3 RGBA16F | MVP는 33^3 RGBA8, banding 확인 후 조정 |
| 렌더링 fallback | runtime compile 유지 / 제거 | Phase 1까지 유지 |
| 로컬 저장소 | FileManager only / SwiftData | M1은 FileManager only |

---

## 8. 관련 문서

- [IMPLEMENTATION_PLAN.md](./IMPLEMENTATION_PLAN.md)
- [M0_DEVICE_VALIDATION.md](./M0_DEVICE_VALIDATION.md)
- [TASK_LIST.md](./TASK_LIST.md)
- [SYSTEM_DESIGN.md](./SYSTEM_DESIGN.md)
- [TECH_STACK.md](./TECH_STACK.md)
- [TESTING_STRATEGY.md](./TESTING_STRATEGY.md)
- [ADR/0003-metal-msl-shader-pipeline.md](./ADR/0003-metal-msl-shader-pipeline.md)
