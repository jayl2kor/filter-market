# M0 Device Validation

> 작성일: 2026-05-06 · 마지막 업데이트: 2026-05-06 15:40 KST · 상태: 실기기 검증 대기
>
> 이 문서는 M0-C 이슈를 닫기 위한 iPhone 실기기 smoke test와 성능 기록 양식이다.

---

## 1. 대상 이슈

| Issue | 목적 | 완료 기준 |
|---|---|---|
| M0-C01 | iPhone 실기기 preview smoke test | 영상 표시, 권한 허용/거부, background lifecycle 확인 |
| M0-C02 | M0 성능 측정 결과 기록 | 기기/iOS/FPS/CPU ms/GPU ms 표 기록 |
| M0-C03 | preview orientation/crop 보정 | portrait 기준 왜곡/회전 없이 preview 표시 |

---

## 2. 실행 전 준비

```bash
./scripts/metal-toolchain.sh
./scripts/build-for-testing.sh
```

Xcode에서 실행할 때:

1. `filterMarket.xcodeproj`를 연다.
2. scheme을 `filterMarket`으로 선택한다.
3. 실기기 iPhone을 destination으로 선택한다.
4. Signing Team을 로컬 Apple Developer Team으로 지정한다.
5. Run으로 설치/실행한다.

---

## 3. Smoke Test Checklist

| 항목 | 기대 결과 | 결과 |
|---|---|---|
| 첫 실행 권한 요청 | 카메라 권한 alert 표시 | TBD |
| 권한 허용 | preview 화면 진입 | TBD |
| 권한 거부 | "Camera permission needed" 상태 표시 | TBD |
| back camera preview | 화면 전체에 실시간 영상 표시 | TBD |
| 방향 | portrait 화면에서 영상이 90도 틀어지지 않음 | TBD |
| 비율/crop | preview가 화면을 채우고 과도한 왜곡 없음 | TBD |
| intensity slider 0% | 원본에 가까운 색감 | TBD |
| intensity slider 100% | warm LUT 색감 변화 확인 | TBD |
| background 진입 | capture session stop, metrics polling stop | TBD |
| foreground 복귀 | capture session restart, preview 복구 | TBD |

---

## 4. 성능 기록

앱 하단 상태 텍스트의 FPS/GPU/CPU 값을 30초 이상 관찰해 기록한다.

| 기기 | iOS | 해상도 preset | 평균 FPS | 최저 FPS | GPU ms | CPU ms | thermal state | 비고 |
|---|---|---|---:|---:|---:|---:|---|---|
| TBD | TBD | hd1920x1080 | TBD | TBD | TBD | TBD | TBD | TBD |

---

## 5. 현재 코드 기준

- `AVCaptureSession.sessionPreset = .hd1920x1080`
- `AVCaptureVideoDataOutput.alwaysDiscardsLateVideoFrames = true`
- `CVMetalTextureCache`로 Y plane과 CbCr plane을 Metal texture로 변환
- MSL fragment에서 YUV -> RGB 변환 후 warm 3D LUT 적용
- SwiftUI `scenePhase`에 따라 active에서는 start, inactive/background에서는 stop
- `MTLCommandBuffer.addCompletedHandler`에서 FPS, GPU frame time, CPU frame time 갱신
- shader에서 frame/view aspect ratio 기반 aspect-fill sampling 적용

---

## 6. 로컬 검증 결과

| 시각 | 명령 | 결과 |
|---|---|---|
| 2026-05-06 15:39 KST | `./scripts/build-for-testing.sh` | `** TEST BUILD SUCCEEDED **` |
| 2026-05-06 15:40 KST | `./scripts/test.sh` | `** TEST SUCCEEDED **`, 4 tests, 0 failures |

---

## 7. 실패 시 기록할 정보

| 증상 | 기록할 정보 |
|---|---|
| preview blank | 권한 상태, `renderer.isAvailable`, Metal Toolchain 빌드 여부 |
| 영상 회전 | 기기 방향, orientation lock 상태, texture width/height |
| crop 과다 | texture width/height, drawable width/height |
| FPS 부족 | 기기, iOS, thermal state, 평균 FPS/GPU ms/CPU ms |
| background 복귀 실패 | scene phase 전환 순서, status text 변화 |
