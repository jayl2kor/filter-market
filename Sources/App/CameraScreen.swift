import Camera
import DesignSystem
import FirebaseAuth
import FirebaseFirestore
import FilterEngine
import Marketplace
import Models
import Photos
import SwiftUI
import UIKit

// MARK: - CameraScreen
//
// Phase D4 — `mockups/screens/03-camera-live.html` + `04-filter-swipe.html` 와 정합.
// 다크 강제, frosted blur 컨트롤, 골드 악센트, 좌우 스와이프 필터 전환 (MOTION_SPEC §4).
//
// 카메라 로직 (`CameraSession`, `MetalPreviewRenderer`, `PhotoFilterRenderer`) 은 변경하지 않는다.
// 본 화면은 시각/제스처/햅틱만 폴리시한다.
struct CameraScreen: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var store: MooditStore
    @StateObject private var controller = CameraPreviewController()
    @StateObject private var permissionCoordinator = PermissionCoordinator()
    @StateObject private var recentPhotoThumbnailLoader = RecentPhotoThumbnailLoader()
    @State private var captureResult: CameraCaptureResult?
    @State private var focusIndicator: CameraFocusIndicator?
    @State private var cameraPermissionState: PermissionCoordinator.Status = .notDetermined
    @State private var isPhotoImportPresented = false
    @State private var countdownValue: Int?
    @State private var countdownTask: Task<Void, Never>?
    @State private var filterSwipeOffset: CGFloat = 0
    /// 셔터 → `controller.capture` 가 nil 을 반환했을 때의 사용자용 에러 메시지.
    /// `.fmAlert` 의 `isPresented` 와 binding 되며, 닫힐 때 nil 로 리셋된다.
    @State private var captureError: String?

    /// fullScreenCover 로 띄울 때 닫기 버튼을 노출할지 여부.
    /// RootShell 의 셔터 탭에서 띄울 때만 true.
    private let isPresentedAsCover: Bool
    private var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-ui-testing")
    }

    init(isPresentedAsCover: Bool = false) {
        self.isPresentedAsCover = isPresentedAsCover
    }

    var body: some View {
        Group {
            switch cameraPermissionState {
            case .authorized:
                cameraSurface
            case .notDetermined:
                CameraPermissionPriming(
                    onAllow: { Task { await requestCameraPermission() } },
                    onSkip: { handleCloseFromPriming() },
                    onClose: isPresentedAsCover ? { handleCloseFromPriming() } : nil
                )
            case .denied, .restricted:
                CameraPermissionDenied(
                    onOpenSettings: { permissionCoordinator.openSettings() },
                    onDismiss: { handleCloseFromPriming() },
                    onPermissionGranted: {
                        cameraPermissionState = .authorized
                    }
                )
            }
        }
        .task {
            cameraPermissionState = isUITesting ? .authorized : permissionCoordinator.currentStatus(.camera)
            if !isUITesting {
                recentPhotoThumbnailLoader.refreshIfAuthorized()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            // 사용자가 백그라운드 → 설정 → 권한 변경 → 복귀 시 상태를 새로고침.
            if !isUITesting && newPhase == .active {
                cameraPermissionState = permissionCoordinator.currentStatus(.camera)
                recentPhotoThumbnailLoader.refreshIfAuthorized()
            }
        }
    }

    private var cameraSurface: some View {
        GeometryReader { proxy in
            ZStack {
                // 라이브 프리뷰 (Metal). 카메라 로직은 변경하지 않음.
                MetalPreviewView(renderer: controller.renderer)
                    .ignoresSafeArea()

                aspectGuide
                focusAndSwipeLayer(size: proxy.size)

                if let message = controller.previewUnavailableMessage {
                    cameraUnavailableOverlay(message: message)
                }

                VStack(spacing: 0) {
                    topBar
                        .padding(.horizontal, Sp.md)
                        .padding(.top, Sp.sm)

                    aspectRatioMenu
                        .padding(.top, Sp.xs)

                    Spacer(minLength: 0)

                    bottomStack
                }

                // 좌우 인접 필터 힌트 (스와이프 가능 표시).
                swipeHints

                if let countdownValue {
                    countdownOverlay(value: countdownValue)
                }
            }
        }
        .background(Color.black)
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
        .preferredColorScheme(.dark)
        .task {
            controller.apply(filter: store.selectedFilter)
            controller.setCropAspectRatio(store.cameraAspectRatio)
            if !isUITesting && scenePhase == .active {
                await controller.start()
            }
        }
        .onChange(of: store.selectedFilterID) { _, _ in
            controller.apply(filter: store.selectedFilter)
        }
        .onChange(of: store.cameraAspectRatio) { _, newValue in
            controller.setCropAspectRatio(newValue)
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                if !isUITesting {
                    Task {
                        await controller.start()
                    }
                }
            case .background, .inactive:
                cancelCountdown()
                controller.stop()
            @unknown default:
                cancelCountdown()
                controller.stop()
            }
        }
        .onDisappear {
            cancelCountdown()
            controller.stop()
        }
        .fullScreenCover(item: $captureResult) { result in
            CapturePreviewHost(result: result) {
                captureResult = nil
            }
            .interactiveDismissDisabled(true)
        }
        .fullScreenCover(isPresented: $isPhotoImportPresented) {
            NavigationStack {
                PhotoImportScreen()
                    .environmentObject(store)
                    .appRouteDestinations()
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("닫기") {
                                isPhotoImportPresented = false
                            }
                        }
                    }
            }
            .interactiveDismissDisabled(true)
        }
        .fmAlert(
            "촬영 실패",
            isPresented: Binding(
                get: { captureError != nil },
                set: { presented in if !presented { captureError = nil } }
            )
        ) {
            Button("확인", role: .cancel) { captureError = nil }
        } message: {
            Text(captureError ?? "")
        }
    }

    private func requestCameraPermission() async {
        let next = await permissionCoordinator.request(.camera)
        cameraPermissionState = next
    }

    private func handleCloseFromPriming() {
        if isPresentedAsCover {
            FMHaptic.light.play()
            dismiss()
        }
    }

    // MARK: - Top bar

    private func cameraUnavailableOverlay(message: String) -> some View {
        VStack(spacing: Sp.sm) {
            Image(systemName: "camera.badge.ellipsis")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(FMColors.Accent.primary)
                .frame(width: 56, height: 56)
                .background(Color.black.opacity(0.55), in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                }

            Text(message)
                .font(.headline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.65), radius: 2, y: 1)

            Button {
                FMHaptic.light.play()
                isPhotoImportPresented = true
            } label: {
                Label("사진 라이브러리에서 가져오기", systemImage: "photo.on.rectangle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, Sp.md)
                    .frame(minHeight: 44)
                    .background(FMColors.Accent.primary, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("camera.unavailable.import")
        }
        .padding(Sp.md)
        .background(Color.black.opacity(0.5), in: RoundedRectangle(cornerRadius: R.lg))
        .overlay {
            RoundedRectangle(cornerRadius: R.lg)
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
        }
        .padding(.horizontal, Sp.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("camera.unavailable")
    }

    private var topBar: some View {
        HStack(alignment: .center, spacing: Sp.xs) {
            if isPresentedAsCover {
                frostedIconButton(systemName: "xmark", label: "카메라 닫기") {
                    FMHaptic.light.play()
                    dismiss()
                }
                .accessibilityIdentifier("camera.dismiss")
            }

            // 현재는 실제 조작 컨트롤이 아닌 노출 상태 정보로만 표시한다.
            modePill

            Spacer(minLength: Sp.xs)

            HStack(spacing: Sp.xs) {
                timerButton
                gridButton
                flashMenu
                frostedIconButton(systemName: "camera.rotate", label: "전후면 전환") {
                    FMHaptic.light.play()
                    Task { await controller.switchCamera() }
                }
                .accessibilityIdentifier("camera.flip")
                .disabled(controller.isSwitchingCamera || controller.isCapturing)
            }
        }
    }

    private var modePill: some View {
        HStack(spacing: 6) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 10, weight: .semibold))
            Text("AUTO")
                .font(.cameraOverlayCaption)
                .tracking(0.4)
        }
        .foregroundStyle(FMColors.Text.inverse)
        .shadow(color: .black.opacity(0.65), radius: 2, y: 1)
        .accessibilityLabel("자동 노출 모드")
        .colorScheme(.dark)
    }

    private var aspectRatioMenu: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Sp.xs) {
                ForEach(PhotoCropAspectRatio.allCases) { aspectRatio in
                    aspectRatioChip(aspectRatio)
                }
            }
            .padding(.horizontal, Sp.md)
        }
        .accessibilityIdentifier("camera.aspectRatio")
        .accessibilityElement(children: .contain)
    }

    private func aspectRatioChip(_ aspectRatio: PhotoCropAspectRatio) -> some View {
        let isSelected = aspectRatio == store.cameraAspectRatio
        return Button {
            selectAspectRatio(aspectRatio)
        } label: {
            Text(aspectRatio.label)
                .font(.cameraOverlayCaption)
                .tracking(0.3)
                .foregroundStyle(isSelected ? FMColors.Text.inverse : Color.white.opacity(0.88))
                .frame(minWidth: 52, minHeight: 36)
                .padding(.horizontal, Sp.xs)
                .background(
                    isSelected ? FMColors.Accent.primary.opacity(0.92) : Color.black.opacity(0.54),
                    in: Capsule()
                )
                .overlay {
                    Capsule()
                        .strokeBorder(isSelected ? Color.white.opacity(0.24) : Color.white.opacity(0.28), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("camera.aspectRatio.\(aspectIdentifier(aspectRatio))")
        .accessibilityLabel("비율 \(aspectRatio.label) 선택")
        .accessibilityValue(isSelected ? "현재 비율" : "선택 안 됨")
        .accessibilityHint("뷰파인더의 비율을 변경합니다")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .colorScheme(.dark)
    }

    private func selectAspectRatio(_ aspectRatio: PhotoCropAspectRatio) {
        guard store.cameraAspectRatio != aspectRatio else { return }
        FMHaptic.light.play()
        store.cameraAspectRatio = aspectRatio
        controller.setCropAspectRatio(aspectRatio)
    }

    private func aspectIdentifier(_ aspectRatio: PhotoCropAspectRatio) -> String {
        switch aspectRatio {
        case .square: "1_1"
        case .fourFive: "4_5"
        case .fourThree: "4_3"
        case .sixteenNine: "16_9"
        }
    }

    private var timerButton: some View {
        Menu {
            ForEach(CameraTimerOption.allCases) { option in
                Button {
                    FMHaptic.selection.play()
                    store.cameraTimerOption = option
                } label: {
                    if option == store.cameraTimerOption {
                        Label(option.label, systemImage: "checkmark")
                    } else {
                        Text(option.label)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "timer")
                    .font(.system(size: 13, weight: .semibold))
                Text(store.cameraTimerOption.label)
                    .font(.cameraOverlayCaptionMonospaced)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
                .foregroundStyle(store.cameraTimerOption == .off ? FMColors.Text.inverse.opacity(0.78) : FMColors.Accent.primary)
                .frame(minWidth: 44, minHeight: 44)
                .padding(.horizontal, Sp.xs)
                .background(Color.black.opacity(0.64), in: Capsule())
                .overlay {
                    Capsule()
                        .fill(store.cameraTimerOption == .off ? Color.clear : FMColors.Accent.primary.opacity(0.18))
                }
                .overlay {
                    Capsule()
                        .strokeBorder(
                            store.cameraTimerOption == .off
                                ? Color.white.opacity(0.28)
                                : FMColors.Accent.primary.opacity(0.65),
                            lineWidth: 1
                        )
                }
                .colorScheme(.dark)
        }
        .accessibilityIdentifier("camera.timer")
        .accessibilityLabel("타이머 \(store.cameraTimerOption.label)")
    }

    private var gridButton: some View {
        frostedIconButton(
            systemName: store.cameraGridEnabled ? "squareshape.split.3x3" : "square",
            label: store.cameraGridEnabled ? "그리드 끄기" : "그리드 켜기",
            isActive: store.cameraGridEnabled
        ) {
            FMHaptic.selection.play()
            store.cameraGridEnabled.toggle()
        }
        .accessibilityIdentifier("camera.grid.toggle")
    }

    private var flashMenu: some View {
        Menu {
            ForEach(CameraFlashMode.allCases) { mode in
                Button {
                    FMHaptic.selection.play()
                    store.cameraFlashMode = mode
                } label: {
                    if mode == store.cameraFlashMode {
                        Label(mode.label, systemImage: "checkmark")
                    } else {
                        Label(mode.label, systemImage: mode.systemImage)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: store.cameraFlashMode.systemImage)
                    .font(.system(size: 14, weight: .semibold))
                Text(store.cameraFlashMode.label)
                    .font(.cameraOverlayCaptionMonospaced)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
                .foregroundStyle(store.cameraFlashMode == .off ? FMColors.Text.inverse : FMColors.Accent.primary)
                .padding(.horizontal, Sp.xs + 2)
                .frame(minWidth: 54, minHeight: 44)
                .background(Color.black.opacity(0.64), in: Capsule())
                .overlay {
                    Capsule()
                        .fill(store.cameraFlashMode == .off ? Color.clear : FMColors.Accent.primary.opacity(0.18))
                }
                .overlay {
                    Capsule()
                        .strokeBorder(
                            store.cameraFlashMode == .off
                                ? Color.white.opacity(0.28)
                                : FMColors.Accent.primary.opacity(0.65),
                            lineWidth: 1
                        )
                }
                .colorScheme(.dark)
        }
        .accessibilityIdentifier("camera.flash")
        .accessibilityLabel("플래시 \(store.cameraFlashMode.label)")
    }

    private func frostedIconButton(
        systemName: String,
        label: String,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isActive ? FMColors.Accent.primary : FMColors.Text.inverse)
                .frame(width: 44, height: 44)
                .background(Color.black.opacity(0.64), in: Circle())
                .overlay {
                    Circle()
                        .fill(isActive ? FMColors.Accent.primary.opacity(0.18) : Color.clear)
                }
                .overlay {
                    Circle()
                        .strokeBorder(
                            isActive ? FMColors.Accent.primary.opacity(0.65) : Color.white.opacity(0.28),
                            lineWidth: 1
                        )
                }
                .colorScheme(.dark)
        }
        .accessibilityLabel(label)
    }

    // MARK: - Swipe layer (필터 전환)

    private func filterSwipeGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { drag in
                guard abs(drag.translation.width) > abs(drag.translation.height) else { return }
                filterSwipeOffset = CameraFilterSwipeResolver.visualOffset(
                    translation: drag.translation.width,
                    currentIndex: currentFilterIndex(),
                    filterCount: store.filters.count
                )
            }
            .onEnded { drag in
                // 가로 우세인 경우만 처리 — 세로 스와이프(포커스 등)와 충돌 방지.
                guard abs(drag.translation.width) > abs(drag.translation.height) else { return }

                let targetIndex = CameraFilterSwipeResolver.targetIndex(
                    currentIndex: currentFilterIndex(),
                    filterCount: store.filters.count,
                    translation: drag.translation.width,
                    predictedEndTranslation: drag.predictedEndTranslation.width,
                    containerWidth: width
                )

                if let targetIndex, targetIndex != currentFilterIndex() {
                    selectFilter(at: targetIndex)
                } else {
                    FMHaptic.light.play()
                    resetFilterSwipeOffset()
                }
            }
    }

    private func advanceFilter(direction: Int) {
        let targetIndex = CameraFilterSwipeResolver.clampedIndex(
            currentIndex: currentFilterIndex(),
            filterCount: store.filters.count,
            direction: direction,
            steps: 1
        )
        guard let targetIndex, targetIndex != currentFilterIndex() else {
            FMHaptic.warning.play()
            resetFilterSwipeOffset()
            return
        }
        selectFilter(at: targetIndex)
    }

    private func currentFilterIndex() -> Int {
        guard !store.filters.isEmpty else { return 0 }
        let currentID = store.selectedFilterID
        return store.filters.firstIndex(where: { $0.id == currentID }) ?? 0
    }

    private func selectFilter(at index: Int) {
        guard !store.filters.isEmpty else { return }
        let safeIndex = min(max(index, 0), store.filters.count - 1)
        let nextFilter = store.filters[safeIndex]

        filterSwipeOffset = 0
        FMHaptic.medium.play()
        withAnimation(reduceMotion ? nil : .fmSpringSwipe) {
            store.select(nextFilter)
        }
    }

    private func resetFilterSwipeOffset() {
        withAnimation(reduceMotion ? nil : .fmSpringSwipe) {
            filterSwipeOffset = 0
        }
    }

    // MARK: - Swipe hints (좌/우 인접 필터 라벨)

    @ViewBuilder
    private var swipeHints: some View {
        if let neighbours = adjacentFilters() {
            HStack {
                if let previous = neighbours.previous {
                    swipeHint(label: previous.title, leading: true)
                }
                Spacer()
                if let next = neighbours.next {
                    swipeHint(label: next.title, leading: false)
                }
            }
            .padding(.horizontal, Sp.sm)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 260)
            .offset(x: filterSwipeOffset * 0.12)
            .allowsHitTesting(false)
        }
    }

    private func swipeHint(label: String, leading: Bool) -> some View {
        HStack(spacing: 6) {
            if leading {
                Image(systemName: "chevron.left")
                    .font(.system(size: 9, weight: .bold))
            }
            Text(label)
                .font(.cameraOverlayCaption)
                .lineLimit(1)
            if !leading {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
            }
        }
        .foregroundStyle(FMColors.Text.inverse.opacity(0.85))
        .shadow(color: .black.opacity(0.55), radius: 1, y: 1)
        .padding(.horizontal, Sp.sm)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.58), in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
        }
        .colorScheme(.dark)
    }

    private func adjacentFilters() -> (previous: Filter?, next: Filter?)? {
        guard store.filters.count > 1 else { return nil }
        let currentIndex = currentFilterIndex()
        let prev = currentIndex > 0 ? store.filters[currentIndex - 1] : nil
        let next = currentIndex < store.filters.count - 1 ? store.filters[currentIndex + 1] : nil
        return (prev, next)
    }

    // MARK: - Focus tap

    private func focusAndSwipeLayer(size: CGSize) -> some View {
        GeometryReader { proxy in
            Color.clear
                .contentShape(Rectangle())
                .simultaneousGesture(
                    SpatialTapGesture()
                        .onEnded { value in
                            handleFocusTap(at: value.location, viewSize: proxy.size)
                        }
                )
                .simultaneousGesture(filterSwipeGesture(width: size.width))
                .overlay {
                    if let focusIndicator {
                        FocusReticle()
                            .position(focusIndicator.location)
                            .transition(.scale(scale: 0.82).combined(with: .opacity))
                    }
                }
        }
        .ignoresSafeArea()
    }

    // MARK: - Aspect guide

    private var aspectGuide: some View {
        GeometryReader { proxy in
            let frame = guideFrame(for: proxy.size, aspectRatio: controller.cropAspectRatio)

            ZStack {
                Color.clear

                Color.black.opacity(0.42)
                    .frame(width: proxy.size.width, height: max(frame.minY, 0))
                    .position(x: proxy.size.width / 2, y: max(frame.minY, 0) / 2)

                Color.black.opacity(0.42)
                    .frame(width: proxy.size.width, height: max(proxy.size.height - frame.maxY, 0))
                    .position(x: proxy.size.width / 2, y: frame.maxY + max(proxy.size.height - frame.maxY, 0) / 2)

                Color.black.opacity(0.42)
                    .frame(width: max(frame.minX, 0), height: frame.height)
                    .position(x: max(frame.minX, 0) / 2, y: frame.midY)

                Color.black.opacity(0.42)
                    .frame(width: max(proxy.size.width - frame.maxX, 0), height: frame.height)
                    .position(x: frame.maxX + max(proxy.size.width - frame.maxX, 0) / 2, y: frame.midY)

                if store.cameraGridEnabled {
                    ZStack {
                        cameraGridLine(width: 0.7, height: frame.height)
                            .position(x: frame.minX + frame.width / 3, y: frame.midY)
                        cameraGridLine(width: 0.7, height: frame.height)
                            .position(x: frame.minX + 2 * frame.width / 3, y: frame.midY)
                        cameraGridLine(width: frame.width, height: 0.7)
                            .position(x: frame.midX, y: frame.minY + frame.height / 3)
                        cameraGridLine(width: frame.width, height: 0.7)
                            .position(x: frame.midX, y: frame.minY + 2 * frame.height / 3)
                    }
                }

                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.white.opacity(0.42), lineWidth: 1)
                    .frame(width: frame.width, height: frame.height)
                    .position(x: frame.midX, y: frame.midY)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: controller.cropAspectRatio)
    }

    private func cameraGridLine(width: CGFloat, height: CGFloat) -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.55))
            .frame(width: width, height: height)
            .shadow(color: Color.black.opacity(0.45), radius: 0.5)
    }

    private func guideFrame(for size: CGSize, aspectRatio: PhotoCropAspectRatio) -> CGRect {
        let targetAspectRatio = aspectRatio.targetAspectRatio(for: size)
        let currentAspectRatio = size.width / max(size.height, 1)

        let guideSize: CGSize
        if currentAspectRatio > targetAspectRatio {
            guideSize = CGSize(width: size.height * targetAspectRatio, height: size.height)
        } else {
            guideSize = CGSize(width: size.width, height: size.width / targetAspectRatio)
        }

        return CGRect(
            x: (size.width - guideSize.width) / 2,
            y: (size.height - guideSize.height) / 2,
            width: guideSize.width,
            height: guideSize.height
        )
    }

    private func handleFocusTap(at location: CGPoint, viewSize: CGSize) {
        FMHaptic.light.play()
        let activeFrame = guideFrame(for: viewSize, aspectRatio: controller.cropAspectRatio)
        let indicatorLocation = CGPoint(
            x: min(max(location.x, activeFrame.minX), activeFrame.maxX),
            y: min(max(location.y, activeFrame.minY), activeFrame.maxY)
        )

        let indicator = CameraFocusIndicator(location: indicatorLocation)
        withAnimation(.fmFast.reducedIfNeeded(reduceMotion)) {
            focusIndicator = indicator
        }

        Task {
            await controller.focusAndExpose(at: indicatorLocation, activeFrame: activeFrame)
            try? await Task.sleep(for: .milliseconds(850))

            await MainActor.run {
                guard focusIndicator?.id == indicator.id else { return }
                withAnimation(.fmEaseIn.reducedIfNeeded(reduceMotion)) {
                    focusIndicator = nil
                }
            }
        }
    }

    // MARK: - Bottom stack

    private var bottomStack: some View {
        VStack(spacing: Sp.sm) {
            currentFilterLabel
            intensitySlider
            filterCarousel
            shutterBar
        }
        .padding(.top, Sp.md)
        .padding(.bottom, Sp.md)
    }

    @ViewBuilder
    private var currentFilterLabel: some View {
        if let filter = store.selectedFilter {
            HStack(spacing: Sp.xs) {
                Image(systemName: "camera.filters")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FMColors.Accent.primary)
                Text(filter.title)
                    .font(.cameraOverlayTitle)
                    .foregroundStyle(FMColors.Text.inverse)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .shadow(color: .black.opacity(0.65), radius: 2, y: 1)

                Spacer(minLength: Sp.xs)

                Text("적용 중")
                    .font(.cameraOverlayCaption)
                    .foregroundStyle(FMColors.Accent.primary)
            }
            .padding(.horizontal, Sp.sm)
            .padding(.vertical, Sp.xs)
            .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: R.md))
            .overlay {
                RoundedRectangle(cornerRadius: R.md)
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
            }
            .padding(.horizontal, Sp.md)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("현재 필터")
            .accessibilityValue("\(filter.title), \(Int((controller.intensity * 100).rounded()))퍼센트")
            .accessibilityHint("위 또는 아래로 쓸어넘겨 이전 또는 다음 필터로 이동합니다")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    advanceFilter(direction: 1)
                case .decrement:
                    advanceFilter(direction: -1)
                @unknown default:
                    break
                }
            }
        }
    }

    private var intensitySlider: some View {
        HStack(spacing: Sp.sm) {
            Label("강도", systemImage: "slider.horizontal.3")
                .font(.cameraOverlayCaption)
                .foregroundStyle(FMColors.Text.inverse.opacity(0.92))
                .labelStyle(.iconOnly)
                .frame(width: 32, alignment: .leading)
                .accessibilityLabel("강도")

            FMSlider(
                value: Binding(
                    get: { Double(controller.intensity) },
                    set: { controller.setIntensity(Float($0)) }
                ),
                showValue: false
            )

            Text("\(Int((controller.intensity * 100).rounded()))%")
                .font(.cameraOverlayCaptionMonospaced)
                .foregroundStyle(FMColors.Accent.primary)
                .frame(width: 38, alignment: .trailing)
        }
        .padding(.horizontal, Sp.md)
        .padding(.vertical, Sp.xs)
        .background(.ultraThinMaterial.opacity(0.5), in: RoundedRectangle(cornerRadius: R.md))
        .overlay {
            RoundedRectangle(cornerRadius: R.md)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        }
        .colorScheme(.dark)
        .padding(.horizontal, Sp.md)
        .accessibilityIdentifier("camera.filterIntensity")
    }

    private var filterCarousel: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Sp.xs) {
                    ForEach(store.filters) { filter in
                        filterChip(filter: filter)
                            .id(filter.id)
                    }
                }
                .padding(.horizontal, Sp.md)
                .padding(.vertical, Sp.xs)
            }
            .onChange(of: store.selectedFilterID) { _, newID in
                guard let newID else { return }
                withAnimation(reduceMotion ? nil : .fmSpringSwipe) {
                    proxy.scrollTo(newID, anchor: .center)
                }
            }
            .offset(x: filterSwipeOffset * 0.22)
        }
    }

    private func filterChip(filter: Filter) -> some View {
        let isActive = store.selectedFilterID == filter.id
        return Button {
            guard !isActive else { return }
            FMHaptic.selection.play()
            withAnimation(reduceMotion ? nil : .fmSpringSwipe) {
                store.select(filter)
            }
        } label: {
            VStack(spacing: 6) {
                FilterThumbnail(filter: filter)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: R.md))
                    .overlay {
                        RoundedRectangle(cornerRadius: R.md)
                            .strokeBorder(
                                isActive ? FMColors.Accent.primary : Color.white.opacity(0.10),
                                lineWidth: isActive ? 2 : 1
                            )
                    }
                    .shadow(
                        color: isActive ? FMColors.Accent.primary.opacity(0.45) : .clear,
                        radius: isActive ? 6 : 0
                    )

                Text(filter.title)
                    .font(.cameraOverlayCaption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(
                        isActive
                            ? FMColors.Accent.primary
                            : FMColors.Text.inverse.opacity(0.84)
                    )
                    .frame(width: 72)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("camera.filter.\(filter.id.uuidString)")
        .accessibilityLabel(filter.title)
        .accessibilityAddTraits(isActive ? [.isSelected, .isButton] : .isButton)
    }

    private var shutterBar: some View {
        HStack(spacing: 0) {
            Button {
                FMHaptic.light.play()
                openPhotoLibrary()
            } label: {
                libraryThumbnail
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("camera.openLibrary")
            .accessibilityLabel(recentPhotoThumbnailLoader.accessibilityLabel)
            .accessibilityHint("사진 라이브러리에서 가져오기 화면을 엽니다")

            // 셔터.
            Button {
                FMHaptic.medium.play()
                if countdownTask != nil {
                    cancelCountdown()
                } else {
                    countdownTask = Task { await captureWithOptionalTimer() }
                }
            } label: {
                ZStack {
                    Circle()
                        .stroke(countdownTask == nil ? Color.white : FMColors.Accent.primary, lineWidth: 3)
                        .frame(width: 76, height: 76)

                    Circle()
                        .fill(countdownTask == nil ? FMColors.Accent.primary : Color.black.opacity(0.72))
                        .frame(width: 64, height: 64)

                    if controller.isCapturing {
                        ProgressView()
                            .tint(.black)
                    } else if countdownTask != nil {
                        Image(systemName: "xmark")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(FMColors.Accent.primary)
                    }
                }
            }
            .disabled(controller.isCapturing)
            .accessibilityIdentifier("camera.shutter")
            .accessibilityLabel(countdownTask == nil ? "촬영" : "타이머 취소")
            .accessibilityHint(countdownTask == nil ? "" : "카운트다운을 취소합니다")

            compactZoomControls
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, Sp.xl)
        .padding(.top, Sp.xs)
    }

    @ViewBuilder
    private var libraryThumbnail: some View {
        ZStack {
            if let image = recentPhotoThumbnailLoader.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                FMColors.Background.bg2.opacity(0.7)
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(FMColors.Text.inverse.opacity(0.85))
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: R.md))
        .overlay {
            RoundedRectangle(cornerRadius: R.md)
                .strokeBorder(Color.white.opacity(0.65), lineWidth: 1.5)
        }
    }

    private func openPhotoLibrary() {
        guard !isUITesting else {
            isPhotoImportPresented = true
            return
        }

        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .notDetermined else {
            isPhotoImportPresented = true
            return
        }

        PHPhotoLibrary.requestAuthorization(for: .readWrite) { _ in
            Task { @MainActor in
                recentPhotoThumbnailLoader.refreshIfAuthorized()
                isPhotoImportPresented = true
            }
        }
    }

    private var compactZoomControls: some View {
        HStack(spacing: 3) {
            ForEach([0.5, 1.0, 3.0], id: \.self) { preset in
                Button {
                    FMHaptic.selection.play()
                    store.cameraZoomPreset = preset
                } label: {
                    Text(zoomLabel(for: preset))
                        .font(.cameraOverlayCaptionMonospaced)
                        .foregroundStyle(store.cameraZoomPreset == preset ? .black : FMColors.Text.inverse)
                        .frame(width: 36, height: 32)
                        .background(
                            store.cameraZoomPreset == preset
                                ? FMColors.Accent.primary
                                : Color.black.opacity(0.46),
                            in: Capsule()
                        )
                        .overlay {
                            Capsule()
                                .strokeBorder(
                                    store.cameraZoomPreset == preset
                                        ? FMColors.Accent.primary.opacity(0.9)
                                        : Color.white.opacity(0.32),
                                    lineWidth: store.cameraZoomPreset == preset ? 1.5 : 1
                                )
                        }
                }
                .buttonStyle(.plain)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityIdentifier("camera.zoom.\(preset)")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("줌 배율")
    }

    private func zoomLabel(for preset: Double) -> String {
        preset == 1.0 ? "1x" : String(format: "%.1fx", preset)
    }

    private func countdownOverlay(value: Int) -> some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
            VStack(spacing: Sp.lg) {
                Text("\(value)")
                    .font(.cameraCountdown)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 12, y: 4)

                Button {
                    cancelCountdown()
                } label: {
                    Label("취소", systemImage: "xmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, Sp.md)
                        .frame(minHeight: 44)
                        .background(Color.black.opacity(0.58), in: Capsule())
                        .overlay {
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("camera.timer.cancel")
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("타이머 \(value)초")
            .accessibilityHint("취소하려면 두 번 탭하세요")
        }
        .transition(.opacity)
        .allowsHitTesting(true)
        .onTapGesture {
            cancelCountdown()
        }
    }

    @MainActor
    private func captureWithOptionalTimer() async {
        defer {
            countdownValue = nil
            countdownTask = nil
        }
        guard !controller.isCapturing, scenePhase == .active else { return }
        let seconds = store.cameraTimerOption.rawValue
        if seconds > 0 {
            for value in stride(from: seconds, through: 1, by: -1) {
                countdownValue = value
                if value == 1 {
                    FMHaptic.light.play()
                }
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                } catch {
                    return
                }
                guard !Task.isCancelled, countdownValue != nil, scenePhase == .active else { return }
            }
        }
        guard !Task.isCancelled, scenePhase == .active else { return }
        let result = await controller.capture(filter: store.selectedFilter)
        if let result {
            captureResult = result
        } else {
            FMHaptic.error.play()
            captureError = controller.statusMessage.isEmpty
                ? "촬영에 실패했어요"
                : controller.statusMessage
        }
    }

    @MainActor
    private func cancelCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
        countdownValue = nil
    }
}

// MARK: - Filter swipe resolver

private enum CameraFilterSwipeResolver {
    static let distanceThreshold: CGFloat = 50
    private static let velocityThreshold: CGFloat = 520
    private static let fastVelocityThreshold: CGFloat = 950
    private static let maxVisualOffset: CGFloat = 160

    static func visualOffset(
        translation: CGFloat,
        currentIndex: Int,
        filterCount: Int
    ) -> CGFloat {
        guard filterCount > 1 else { return 0 }

        let isPastFirst = currentIndex <= 0 && translation > 0
        let isPastLast = currentIndex >= filterCount - 1 && translation < 0
        let resistance: CGFloat = (isPastFirst || isPastLast) ? 0.35 : 1
        let resistedTranslation = translation * resistance

        return min(max(resistedTranslation, -maxVisualOffset), maxVisualOffset)
    }

    static func targetIndex(
        currentIndex: Int,
        filterCount: Int,
        translation: CGFloat,
        predictedEndTranslation: CGFloat,
        containerWidth: CGFloat
    ) -> Int? {
        guard filterCount > 1 else { return nil }

        let velocity = predictedEndTranslation - translation
        let horizontalIntent = abs(translation) >= distanceThreshold || abs(velocity) >= velocityThreshold
        guard horizontalIntent else { return nil }

        let primaryIntent = abs(velocity) >= velocityThreshold ? velocity : translation
        let direction = primaryIntent < 0 ? 1 : -1

        let steps = swipeSteps(
            velocity: velocity,
            predictedEndTranslation: predictedEndTranslation,
            containerWidth: containerWidth
        )
        return clampedIndex(
            currentIndex: currentIndex,
            filterCount: filterCount,
            direction: direction,
            steps: steps
        )
    }

    static func clampedIndex(
        currentIndex: Int,
        filterCount: Int,
        direction: Int,
        steps: Int
    ) -> Int? {
        guard filterCount > 1, direction != 0, steps > 0 else { return nil }
        let targetIndex = currentIndex + (direction * steps)
        return min(max(targetIndex, 0), filterCount - 1)
    }

    private static func swipeSteps(
        velocity: CGFloat,
        predictedEndTranslation: CGFloat,
        containerWidth: CGFloat
    ) -> Int {
        let predictedRatio = abs(predictedEndTranslation) / max(containerWidth, 1)
        if abs(velocity) >= fastVelocityThreshold || predictedRatio >= 0.85 {
            return 3
        }
        if abs(velocity) >= velocityThreshold || predictedRatio >= 0.55 {
            return 2
        }
        return 1
    }
}

// MARK: - Recent photo thumbnail

@MainActor
private final class RecentPhotoThumbnailLoader: ObservableObject {
    @Published private(set) var image: UIImage?
    @Published private(set) var creationDate: Date?

    private let imageManager = PHCachingImageManager()
    private var currentRequestID: PHImageRequestID?

    var accessibilityLabel: String {
        guard let creationDate else {
            return "갤러리 열기"
        }
        let date = DateFormatter.localizedString(from: creationDate, dateStyle: .medium, timeStyle: .short)
        return "갤러리 열기, 최근 사진 \(date)"
    }

    func refreshIfAuthorized() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            image = nil
            creationDate = nil
            return
        }
        loadMostRecentImage()
    }

    private func loadMostRecentImage() {
        if let currentRequestID {
            imageManager.cancelImageRequest(currentRequestID)
        }

        let options = PHFetchOptions()
        options.fetchLimit = 1
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        guard let asset = PHAsset.fetchAssets(with: .image, options: options).firstObject else {
            image = nil
            creationDate = nil
            return
        }

        let imageOptions = PHImageRequestOptions()
        imageOptions.deliveryMode = .opportunistic
        imageOptions.resizeMode = .fast
        imageOptions.isNetworkAccessAllowed = false

        currentRequestID = imageManager.requestImage(
            for: asset,
            targetSize: CGSize(width: 176, height: 176),
            contentMode: .aspectFill,
            options: imageOptions
        ) { [weak self] image, info in
            guard (info?[PHImageCancelledKey] as? Bool) != true else { return }
            Task { @MainActor in
                guard let self else { return }
                self.image = image
                self.creationDate = image == nil ? nil : asset.creationDate
            }
        }
    }
}

// MARK: - CapturePreviewHost

/// `CameraCaptureResult` → `CapturePreviewScreen` 어댑터.
/// 저장/공유/재촬영 액션을 기존 `PhotoLibrarySaver` 와 묶어 처리.
private struct CapturePreviewHost: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let result: CameraCaptureResult
    let onClose: () -> Void

    @State private var saveState: CaptureSaveState = .idle
    @State private var showShareSheet = false
    private var filteredImage: UIImage? {
        UIImage(data: result.filteredPhoto.filteredData)
    }
    private let photoLibrarySaver: any PhotoLibrarySaving = PhotoLibrarySaver.live()

    var body: some View {
        CapturePreviewScreen(
            image: filteredImage,
            filterName: result.filter.title,
            aspectRatio: result.cropAspectRatio.label,
            intensityPercent: Int((result.filteredPhoto.configuration.intensity.value * 100).rounded()),
            onSave: { Task { await save() } },
            onShare: { share() },
            onDiscard: onClose,
            onRetake: onClose,
            onChangeFilter: onClose,
            onEdit: nil
        )
        .overlay(alignment: .top) {
            if !saveState.message.isEmpty {
                CaptureSaveBanner(state: saveState)
                    .padding(.top, Sp.xxxl)
                    .transition(.fmReducible(.move(edge: .top).combined(with: .opacity), reduceMotion: reduceMotion))
            }
        }
        .fmAnimation(.fmEaseOut, value: saveState)
        .fmShareSheet(
            isPresented: $showShareSheet,
            items: filteredImage.map { [$0 as Any] } ?? []
        )
    }

    private func share() {
        guard filteredImage != nil else {
            saveState = .invalidShareData
            FMHaptic.error.play()
            return
        }
        showShareSheet = true
    }

    private func save() async {
        guard saveState != .saving, saveState != .saved else { return }
        saveState = .saving
        let outcome = await photoLibrarySaver.savePhoto(data: result.filteredPhoto.filteredData)
        let next = CaptureSaveState(result: outcome)
        saveState = next
        switch next {
        case .saved:
            await persistCaptureMetadata()
            FMHaptic.success.play()
        case .permissionDenied, .permissionRestricted, .permissionNotDetermined, .invalidData, .invalidShareData, .failed:
            FMHaptic.error.play()
        case .idle, .saving:
            break
        }
    }

    private func persistCaptureMetadata() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            try await Firestore.firestore()
                .collection("users").document(uid)
                .collection("captures").document()
                .setData([
                    "filterId": result.filter.id.uuidString,
                    "filterTitle": result.filter.title,
                    "intensityPercent": Int((result.filteredPhoto.configuration.intensity.value * 100).rounded()),
                    "aspect": result.cropAspectRatio.label,
                    "source": "camera",
                    "createdAt": FieldValue.serverTimestamp()
                ])
        } catch {
            // Photo save already succeeded; captures sync can retry through a later save.
        }
    }
}

private struct CaptureSaveBanner: View {
    let state: CaptureSaveState

    var body: some View {
        HStack(spacing: Sp.xs) {
            Image(systemName: state.iconName)
                .font(.system(size: 14, weight: .semibold))
            Text(state.message)
                .font(.cameraOverlayLabel)
                .lineLimit(1)
        }
        .foregroundStyle(state.tint)
        .padding(.horizontal, Sp.md)
        .padding(.vertical, Sp.xs)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(state.tint.opacity(0.4), lineWidth: 1)
        }
        .colorScheme(.dark)
        .accessibilityLabel(state.message)
    }
}

private extension Font {
    static let cameraOverlayCaption = Font.caption2.weight(.semibold)
    static let cameraOverlayCaptionMonospaced = Font.caption2.weight(.semibold).monospacedDigit()
    static let cameraOverlayLabel = Font.footnote.weight(.semibold)
    static let cameraOverlayTitle = Font.subheadline.weight(.bold)
    static let cameraCountdown = Font.system(.largeTitle, design: .rounded).weight(.bold).monospacedDigit()
}

// MARK: - CameraCaptureResult / Focus model

private struct CameraCaptureResult: Identifiable {
    let id = UUID()
    let filter: Filter
    let photo: CapturedPhoto
    let filteredPhoto: FilteredPhoto
    let cropAspectRatio: PhotoCropAspectRatio
}

private struct CameraFocusIndicator: Identifiable, Equatable {
    let id = UUID()
    let location: CGPoint
}

private struct FocusReticle: View {
    var body: some View {
        Circle()
            .stroke(Color.white.opacity(0.92), lineWidth: 1.5)
            .frame(width: 82, height: 82)
            .overlay {
                Circle()
                    .stroke(FMColors.Accent.primary.opacity(0.82), lineWidth: 1)
                    .frame(width: 58, height: 58)
            }
            .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
            .allowsHitTesting(false)
    }
}

// MARK: - CameraPreviewController

@MainActor
private final class CameraPreviewController: ObservableObject {
    @Published private(set) var statusMessage = "Preparing camera"
    @Published private(set) var metricsText = "0 FPS · GPU 0.00ms · CPU 0.00ms"
    @Published private(set) var intensity: Float = 0.65
    @Published private(set) var isCapturing = false
    @Published private(set) var isSwitchingCamera = false
    @Published private(set) var cameraPosition = CameraPosition.back
    @Published private(set) var cropAspectRatio = PhotoCropAspectRatio.fourThree
    @Published private(set) var previewUnavailableMessage: String?

    let renderer = MetalPreviewRenderer(lutResourceBundle: MarketplaceResources.bundle)

    private let cameraSession = CameraSession()
    private let photoFilterRenderer = PhotoFilterRenderer(lutResourceBundle: MarketplaceResources.bundle)
    private var activeFilter: RenderFilter?
    private var isRunning = false
    private var isStarting = false
    private var lifecycleGeneration: UInt64 = 0
    private var metricsTask: Task<Void, Never>?

    init() {
        cameraSession.onFrame = { [weak renderer] sampleBuffer in
            renderer?.enqueue(sampleBuffer)
        }
    }

    func start() async {
        guard !isRunning, !isStarting else { return }

        isStarting = true
        lifecycleGeneration &+= 1
        let generation = lifecycleGeneration
        defer { isStarting = false }

        let isAuthorized = await cameraSession.requestAccess()
        guard generation == lifecycleGeneration else { return }
        guard isAuthorized else {
            statusMessage = "Camera permission needed"
            return
        }

        do {
            try await cameraSession.start()
            guard generation == lifecycleGeneration else {
                cameraSession.stop()
                return
            }
            isRunning = true
            previewUnavailableMessage = nil
            statusMessage = renderer.isAvailable ? "Live Metal preview" : "Metal unavailable"
            startMetricsPolling()
        } catch {
            statusMessage = "Camera failed to start"
            previewUnavailableMessage = "카메라를 사용할 수 없어요"
            Telemetry.record(error: error, context: ["where": "CameraPreviewController.start"])
        }
    }

    func stop() {
        lifecycleGeneration &+= 1
        isStarting = false
        if isRunning {
            isRunning = false
            cameraSession.stop()
        }
        renderer.stop()
        stopMetricsPolling()
        if renderer.isAvailable {
            statusMessage = "Camera paused"
        }
    }

    func setIntensity(_ intensity: Float) {
        self.intensity = intensity
        if let activeFilter {
            renderer.apply(configuration: FilterRenderConfiguration(filter: activeFilter, intensityValue: intensity))
        } else {
            renderer.setIntensity(intensity)
        }
    }

    func apply(filter: Filter?) {
        guard let filter else { return }
        let renderFilter = makeRenderFilter(from: filter)
        activeFilter = renderFilter
        renderer.apply(configuration: FilterRenderConfiguration(filter: renderFilter, intensityValue: intensity))
    }

    func capture(filter: Filter?) async -> CameraCaptureResult? {
        guard let filter, !isCapturing else { return nil }

        isCapturing = true
        defer { isCapturing = false }

        do {
            let configuration = FilterRenderConfiguration(
                filter: makeRenderFilter(from: filter),
                intensityValue: intensity
            )
            let photo = try await cameraSession.capturePhoto()
            let filteredPhoto = try photoFilterRenderer.apply(
                to: photo.data,
                configuration: configuration,
                cropAspectRatio: cropAspectRatio
            )
            statusMessage = "Filtered photo captured"
            return CameraCaptureResult(
                filter: filter,
                photo: photo,
                filteredPhoto: filteredPhoto,
                cropAspectRatio: cropAspectRatio
            )
        } catch {
            statusMessage = "Capture failed"
            return nil
        }
    }

    func switchCamera() async {
        guard !isSwitchingCamera, !isCapturing else { return }

        isSwitchingCamera = true
        defer { isSwitchingCamera = false }

        do {
            let position = try await cameraSession.switchCamera()
            cameraPosition = position
            statusMessage = position == .front ? "Front camera" : "Back camera"
        } catch {
            statusMessage = "Camera switch failed"
        }
    }

    func focusAndExpose(at location: CGPoint, activeFrame: CGRect) async {
        guard !isCapturing else { return }

        do {
            let point = CameraFocusPoint(
                viewLocation: location,
                activeFrame: activeFrame,
                isMirrored: cameraPosition == .front
            )
            try await cameraSession.focusAndExpose(at: point)
            statusMessage = "Focus adjusted"
        } catch {
            statusMessage = "Focus failed"
        }
    }

    func setCropAspectRatio(_ cropAspectRatio: PhotoCropAspectRatio) {
        self.cropAspectRatio = cropAspectRatio
        statusMessage = "\(cropAspectRatio.label) frame"
    }

    private func makeRenderFilter(from filter: Filter) -> RenderFilter {
        RenderFilter(
            id: filter.id,
            title: filter.title,
            lutFile: filter.engine.lutFile,
            lutSize: filter.engine.lutSize ?? 33,
            fallbackPreset: LUTPreset.preset(for: filter.category)
        )
    }

    private func startMetricsPolling() {
        guard metricsTask == nil else { return }

        metricsTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard let self else { return }
                metricsText = renderer.snapshotMetrics().displayText
                if renderer.isAvailable {
                    statusMessage = metricsText
                }
            }
        }
    }

    private func stopMetricsPolling() {
        metricsTask?.cancel()
        metricsTask = nil
    }
}

// MARK: - Capture save state

private enum CaptureSaveState: Equatable {
    case idle
    case saving
    case saved
    case permissionDenied
    case permissionRestricted
    case permissionNotDetermined
    case invalidData
    case invalidShareData
    case failed

    init(result: PhotoLibrarySaveResult) {
        switch result {
        case .saved:
            self = .saved
        case .permissionDenied:
            self = .permissionDenied
        case .permissionRestricted:
            self = .permissionRestricted
        case .permissionNotDetermined:
            self = .permissionNotDetermined
        case .invalidData:
            self = .invalidData
        case .failed:
            self = .failed
        }
    }

    var message: String {
        switch self {
        case .idle, .saving:
            ""
        case .saved:
            "사진이 저장되었어요"
        case .permissionDenied, .permissionRestricted, .permissionNotDetermined:
            "사진 접근 권한이 필요해요"
        case .invalidData:
            "사진 데이터가 비어 있어요"
        case .invalidShareData:
            "공유할 사진을 준비하지 못했어요"
        case .failed:
            "저장에 실패했어요"
        }
    }

    var iconName: String {
        switch self {
        case .saved:
            "checkmark.circle.fill"
        case .permissionDenied, .permissionRestricted, .permissionNotDetermined:
            "lock.fill"
        case .invalidData, .invalidShareData, .failed:
            "exclamationmark.triangle.fill"
        case .idle, .saving:
            "circle"
        }
    }

    var tint: Color {
        switch self {
        case .saved:
            FMColors.Accent.primary
        case .permissionDenied, .permissionRestricted, .permissionNotDetermined, .invalidData, .invalidShareData, .failed:
            FMColors.Semantic.error
        case .idle, .saving:
            FMColors.Text.inverse.opacity(0.6)
        }
    }
}
