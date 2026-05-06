import Camera
import DesignSystem
import FilterEngine
import Marketplace
import Models
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
    @EnvironmentObject private var store: FilterMarketStore
    @StateObject private var controller = CameraPreviewController()
    @StateObject private var permissionCoordinator = PermissionCoordinator()
    @State private var captureResult: CameraCaptureResult?
    @State private var focusIndicator: CameraFocusIndicator?
    @State private var cameraPermissionState: PermissionCoordinator.Status = .notDetermined

    /// fullScreenCover 로 띄울 때 닫기 버튼을 노출할지 여부.
    /// RootShell 의 셔터 탭에서 띄울 때만 true.
    private let isPresentedAsCover: Bool

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
                    onDismiss: { handleCloseFromPriming() }
                )
            }
        }
        .task {
            cameraPermissionState = permissionCoordinator.currentStatus(.camera)
        }
        .onChange(of: scenePhase) { _, newPhase in
            // 사용자가 백그라운드 → 설정 → 권한 변경 → 복귀 시 상태를 새로고침.
            if newPhase == .active {
                cameraPermissionState = permissionCoordinator.currentStatus(.camera)
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
                focusTapLayer
                swipeGestureLayer(width: proxy.size.width)

                VStack(spacing: 0) {
                    topBar
                        .padding(.horizontal, Sp.md)
                        .padding(.top, Sp.sm)

                    Spacer(minLength: 0)

                    bottomStack
                }

                // 좌우 인접 필터 힌트 (스와이프 가능 표시).
                swipeHints
            }
        }
        .background(Color.black)
        .preferredColorScheme(.dark)
        .task {
            controller.apply(filter: store.selectedFilter)
            if scenePhase == .active {
                await controller.start()
            }
        }
        .onChange(of: store.selectedFilterID) { _, _ in
            controller.apply(filter: store.selectedFilter)
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                Task {
                    await controller.start()
                }
            case .background, .inactive:
                controller.stop()
            @unknown default:
                controller.stop()
            }
        }
        .onDisappear {
            controller.stop()
        }
        .fullScreenCover(item: $captureResult) { result in
            CapturePreviewHost(result: result) {
                captureResult = nil
            }
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

    private var topBar: some View {
        HStack(alignment: .center, spacing: Sp.xs) {
            if isPresentedAsCover {
                frostedIconButton(systemName: "xmark", label: "카메라 닫기") {
                    FMHaptic.light.play()
                    dismiss()
                }
                .accessibilityIdentifier("camera.dismiss")
            }

            // 모드 라벨 (현재는 AUTO 고정 — 후속 phase 에서 노출/수동 등으로 확장).
            modePill

            Spacer(minLength: Sp.xs)

            HStack(spacing: Sp.xs) {
                aspectRatioMenu
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
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.4)
        }
        .foregroundStyle(FMColors.Text.inverse)
        .padding(.horizontal, Sp.sm)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial.opacity(0.7), in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        }
        .colorScheme(.dark)
    }

    private var aspectRatioMenu: some View {
        Menu {
            ForEach(PhotoCropAspectRatio.allCases) { aspectRatio in
                Button {
                    FMHaptic.selection.play()
                    controller.setCropAspectRatio(aspectRatio)
                } label: {
                    if aspectRatio == controller.cropAspectRatio {
                        Label(aspectRatio.label, systemImage: "checkmark")
                    } else {
                        Text(aspectRatio.label)
                    }
                }
            }
        } label: {
            Text(controller.cropAspectRatio.label)
                .font(.system(size: 12, weight: .semibold))
                .tracking(0.3)
                .foregroundStyle(FMColors.Text.inverse)
                .frame(minWidth: 38, minHeight: 40)
                .padding(.horizontal, Sp.xs)
                .background(.ultraThinMaterial.opacity(0.7), in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                }
                .colorScheme(.dark)
        }
        .accessibilityIdentifier("camera.aspectRatio")
        .accessibilityLabel("비율 \(controller.cropAspectRatio.label)")
    }

    private func frostedIconButton(
        systemName: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(FMColors.Text.inverse)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial.opacity(0.7), in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                }
                .colorScheme(.dark)
        }
        .accessibilityLabel(label)
    }

    // MARK: - Swipe layer (필터 전환)

    private func swipeGestureLayer(width: CGFloat) -> some View {
        Color.clear
            .contentShape(Rectangle())
            // 셔터/하단 컨트롤은 빼고, 화면 위쪽 60% 영역만 스와이프 처리.
            .frame(maxWidth: .infinity)
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.bottom, 240)
            .gesture(filterSwipeGesture(width: width))
            .allowsHitTesting(width > 0)
    }

    private func filterSwipeGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onEnded { drag in
                // 가로 우세인 경우만 처리 — 세로 스와이프(포커스 등)와 충돌 방지.
                guard abs(drag.translation.width) > abs(drag.translation.height) else { return }

                let displacement = drag.translation.width
                let velocity = drag.predictedEndTranslation.width - drag.translation.width
                let distanceThreshold = max(80, width * 0.3)
                let velocityThreshold: CGFloat = 500

                if displacement <= -distanceThreshold || velocity <= -velocityThreshold {
                    advanceFilter(direction: 1) // 다음 필터
                } else if displacement >= distanceThreshold || velocity >= velocityThreshold {
                    advanceFilter(direction: -1) // 이전 필터
                }
                // threshold 미달 — 시각 변화 없음. 후속 phase 에서 인접 필터 peek 추가 시
                // 여기서 snap-back 애니메이션을 도입할 수 있다.
            }
    }

    private func advanceFilter(direction: Int) {
        guard !store.filters.isEmpty else { return }

        let currentID = store.selectedFilterID
        let currentIndex = store.filters.firstIndex(where: { $0.id == currentID }) ?? 0
        let nextIndex = (currentIndex + direction + store.filters.count) % store.filters.count
        let nextFilter = store.filters[nextIndex]

        FMHaptic.medium.play()
        withAnimation(reduceMotion ? .fmFast : .fmSpringSwipe) {
            store.select(nextFilter)
        }
    }

    // MARK: - Swipe hints (좌/우 인접 필터 라벨)

    @ViewBuilder
    private var swipeHints: some View {
        if let neighbours = adjacentFilters() {
            HStack {
                swipeHint(label: neighbours.previous.title, leading: true)
                Spacer()
                swipeHint(label: neighbours.next.title, leading: false)
            }
            .padding(.horizontal, Sp.sm)
            .frame(maxHeight: .infinity, alignment: .center)
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
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
            if !leading {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
            }
        }
        .foregroundStyle(FMColors.Text.inverse.opacity(0.85))
        .padding(.horizontal, Sp.sm)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial.opacity(0.6), in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        }
        .colorScheme(.dark)
        .opacity(0.85)
    }

    private func adjacentFilters() -> (previous: Filter, next: Filter)? {
        guard store.filters.count > 1 else { return nil }
        let currentID = store.selectedFilterID
        let currentIndex = store.filters.firstIndex(where: { $0.id == currentID }) ?? 0
        let prev = store.filters[(currentIndex - 1 + store.filters.count) % store.filters.count]
        let next = store.filters[(currentIndex + 1) % store.filters.count]
        return (prev, next)
    }

    // MARK: - Focus tap

    private var focusTapLayer: some View {
        GeometryReader { proxy in
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    SpatialTapGesture()
                        .onEnded { value in
                            handleFocusTap(at: value.location, viewSize: proxy.size)
                        }
                )
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

                // 1/3 컴포지션 라인 (3x3 그리드).
                ZStack {
                    Rectangle()
                        .fill(Color.white.opacity(0.16))
                        .frame(width: 1, height: frame.height)
                        .position(x: frame.minX + frame.width / 3, y: frame.midY)
                    Rectangle()
                        .fill(Color.white.opacity(0.16))
                        .frame(width: 1, height: frame.height)
                        .position(x: frame.minX + 2 * frame.width / 3, y: frame.midY)
                    Rectangle()
                        .fill(Color.white.opacity(0.16))
                        .frame(width: frame.width, height: 1)
                        .position(x: frame.midX, y: frame.minY + frame.height / 3)
                    Rectangle()
                        .fill(Color.white.opacity(0.16))
                        .frame(width: frame.width, height: 1)
                        .position(x: frame.midX, y: frame.minY + 2 * frame.height / 3)
                }

                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.white.opacity(0.42), lineWidth: 1)
                    .frame(width: frame.width, height: frame.height)
                    .position(x: frame.midX, y: frame.midY)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
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

        let indicator = CameraFocusIndicator(location: location)
        withAnimation(.fmFast) {
            focusIndicator = indicator
        }

        Task {
            await controller.focusAndExpose(at: location, in: viewSize)
            try? await Task.sleep(for: .milliseconds(850))

            await MainActor.run {
                guard focusIndicator?.id == indicator.id else { return }
                withAnimation(.fmEaseIn) {
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
        .background(
            LinearGradient(
                stops: [
                    .init(color: Color.clear, location: 0.0),
                    .init(color: Color.black.opacity(0.65), location: 0.35),
                    .init(color: Color.black.opacity(0.92), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    @ViewBuilder
    private var currentFilterLabel: some View {
        if let filter = store.selectedFilter {
            VStack(spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "camera.filters")
                        .font(.system(size: 10, weight: .semibold))
                    Text("FILTER · \(Int((controller.intensity * 100).rounded()))%")
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .tracking(0.4)
                }
                .foregroundStyle(FMColors.Accent.primary)
                .padding(.horizontal, Sp.sm)
                .padding(.vertical, 4)
                .background(FMColors.Accent.primary.opacity(0.16), in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(FMColors.Accent.primary.opacity(0.6), lineWidth: 1)
                }

                Text(filter.title)
                    .font(.system(size: 17, weight: .bold))
                    .tracking(-0.2)
                    .foregroundStyle(FMColors.Text.inverse)
                    .lineLimit(1)

                Text("@\(filter.author.displayName)")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(0.3)
                    .foregroundStyle(FMColors.Text.inverse.opacity(0.62))
                    .lineLimit(1)
            }
            .padding(.horizontal, Sp.md)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("현재 필터 \(filter.title), 강도 \(Int((controller.intensity * 100).rounded()))퍼센트")
        }
    }

    private var intensitySlider: some View {
        HStack(spacing: Sp.sm) {
            Text("강도")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(FMColors.Text.inverse.opacity(0.7))
                .frame(width: 36, alignment: .leading)

            FMSlider(
                value: Binding(
                    get: { Double(controller.intensity) },
                    set: { controller.setIntensity(Float($0)) }
                ),
                showValue: false
            )

            Text("\(Int((controller.intensity * 100).rounded()))%")
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
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
                withAnimation(reduceMotion ? .fmFast : .fmSpringSwipe) {
                    proxy.scrollTo(newID, anchor: .center)
                }
            }
        }
    }

    private func filterChip(filter: Filter) -> some View {
        let isActive = store.selectedFilterID == filter.id
        return Button {
            guard !isActive else { return }
            FMHaptic.selection.play()
            withAnimation(reduceMotion ? .fmFast : .fmSpringSwipe) {
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
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.2)
                    .lineLimit(1)
                    .foregroundStyle(
                        isActive
                            ? FMColors.Accent.primary
                            : FMColors.Text.inverse.opacity(0.62)
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
            // 좌하: 갤러리 썸네일 placeholder.
            Button {
                FMHaptic.light.play()
                // 갤러리 진입 — 후속 phase.
            } label: {
                RoundedRectangle(cornerRadius: R.md)
                    .fill(FMColors.Background.bg2.opacity(0.7))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(FMColors.Text.inverse.opacity(0.85))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: R.md)
                            .strokeBorder(Color.white.opacity(0.65), lineWidth: 1.5)
                    }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("camera.openLibrary")
            .accessibilityLabel("갤러리 열기")

            // 셔터.
            Button {
                FMHaptic.medium.play()
                Task {
                    captureResult = await controller.capture(filter: store.selectedFilter)
                }
            } label: {
                ZStack {
                    Circle()
                        .stroke(Color.white, lineWidth: 3)
                        .frame(width: 76, height: 76)

                    Circle()
                        .fill(FMColors.Accent.primary)
                        .frame(width: 64, height: 64)

                    if controller.isCapturing {
                        ProgressView()
                            .tint(.black)
                    }
                }
            }
            .disabled(controller.isCapturing)
            .accessibilityIdentifier("camera.shutter")
            .accessibilityLabel("촬영")

            // 우하: 전후면 전환 (보조 진입점 — top bar 와 중복하나 모킹과 일치).
            Button {
                FMHaptic.light.play()
                Task { await controller.switchCamera() }
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(FMColors.Text.inverse)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial.opacity(0.7), in: Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                    }
                    .colorScheme(.dark)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .disabled(controller.isSwitchingCamera || controller.isCapturing)
            .accessibilityHidden(true) // top-bar 의 flip 과 중복이므로 VoiceOver 에서 숨김.
        }
        .padding(.horizontal, Sp.xl)
        .padding(.top, Sp.xs)
    }
}

// MARK: - CapturePreviewHost

/// `CameraCaptureResult` → `CapturePreviewScreen` 어댑터.
/// 저장/공유/재촬영 액션을 기존 `PhotoLibrarySaver` 와 묶어 처리.
private struct CapturePreviewHost: View {
    let result: CameraCaptureResult
    let onClose: () -> Void

    @State private var saveState: CaptureSaveState = .idle
    @State private var showShareSheet = false
    private let photoLibrarySaver: any PhotoLibrarySaving = PhotoLibrarySaver.live()

    var body: some View {
        CapturePreviewScreen(
            image: UIImage(data: result.filteredPhoto.filteredData),
            filterName: result.filter.title,
            aspectRatio: result.cropAspectRatio.label,
            intensityPercent: Int((result.filteredPhoto.configuration.intensity.value * 100).rounded()),
            onSave: { Task { await save() } },
            onShare: { showShareSheet = true },
            onDiscard: onClose,
            onRetake: onClose,
            onChangeFilter: onClose,
            onEdit: nil
        )
        .overlay(alignment: .top) {
            if !saveState.message.isEmpty {
                CaptureSaveBanner(state: saveState)
                    .padding(.top, Sp.xxxl)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.fmEaseOut, value: saveState)
        .fmShareSheet(
            isPresented: $showShareSheet,
            items: [UIImage(data: result.filteredPhoto.filteredData) ?? result.filteredPhoto.filteredData]
        )
    }

    private func save() async {
        guard saveState != .saving, saveState != .saved else { return }
        saveState = .saving
        let outcome = await photoLibrarySaver.savePhoto(data: result.filteredPhoto.filteredData)
        let next = CaptureSaveState(result: outcome)
        saveState = next
        switch next {
        case .saved:
            FMHaptic.success.play()
        case .permissionDenied, .permissionRestricted, .permissionNotDetermined, .invalidData, .failed:
            FMHaptic.error.play()
        case .idle, .saving:
            break
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
                .font(.system(size: 13, weight: .semibold))
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

    let renderer = MetalPreviewRenderer(lutResourceBundle: MarketplaceResources.bundle)

    private let cameraSession = CameraSession()
    private let photoFilterRenderer = PhotoFilterRenderer(lutResourceBundle: MarketplaceResources.bundle)
    private var activeFilter: RenderFilter?
    private var isRunning = false
    private var metricsTask: Task<Void, Never>?

    init() {
        cameraSession.onFrame = { [weak renderer] sampleBuffer in
            renderer?.enqueue(sampleBuffer)
        }
    }

    func start() async {
        guard !isRunning else { return }

        let isAuthorized = await cameraSession.requestAccess()
        guard isAuthorized else {
            statusMessage = "Camera permission needed"
            return
        }

        do {
            try cameraSession.start()
            isRunning = true
            statusMessage = renderer.isAvailable ? "Live Metal preview" : "Metal unavailable"
            startMetricsPolling()
        } catch {
            statusMessage = "Camera failed to start"
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        cameraSession.stop()
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

    func focusAndExpose(at location: CGPoint, in viewSize: CGSize) async {
        guard !isCapturing else { return }

        do {
            let point = CameraFocusPoint(
                viewLocation: location,
                viewSize: viewSize,
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
        case .invalidData, .failed:
            "exclamationmark.triangle.fill"
        case .idle, .saving:
            "circle"
        }
    }

    var tint: Color {
        switch self {
        case .saved:
            FMColors.Accent.primary
        case .permissionDenied, .permissionRestricted, .permissionNotDetermined, .invalidData, .failed:
            FMColors.Semantic.error
        case .idle, .saving:
            FMColors.Text.inverse.opacity(0.6)
        }
    }
}
