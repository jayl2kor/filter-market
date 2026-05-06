import Camera
import DesignSystem
import FilterEngine
import Marketplace
import Models
import SwiftUI
import UIKit

struct CameraScreen: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var store: FilterMarketStore
    @StateObject private var controller = CameraPreviewController()
    @State private var captureResult: CameraCaptureResult?
    @State private var focusIndicator: CameraFocusIndicator?

    var body: some View {
        ZStack(alignment: .bottom) {
            MetalPreviewView(renderer: controller.renderer)
                .ignoresSafeArea()

            aspectGuide
            focusTapLayer

            VStack(spacing: FMSpacing.large) {
                topBar
                aspectRatioPicker
                Spacer()
                filterCarousel
                intensitySlider
                shutterBar
            }
            .padding(.horizontal, FMSpacing.large)
            .padding(.top, FMSpacing.large)
            .padding(.bottom, FMSpacing.xLarge)
        }
        .background(FMColor.background)
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
        .sheet(item: $captureResult) { result in
            CaptureResultScreen(result: result)
                .presentationDetents([.medium])
        }
    }

    private var topBar: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: FMSpacing.small) {
                Text(controller.statusMessage)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, FMSpacing.medium)
                    .padding(.vertical, FMSpacing.small)
                    .background(.black.opacity(0.55), in: Capsule())

                if let selectedFilter = store.selectedFilter {
                    HStack(spacing: FMSpacing.small) {
                        Image(systemName: "camera.filters")
                        Text(selectedFilter.title)
                            .lineLimit(1)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))
                    .padding(.horizontal, FMSpacing.medium)
                    .padding(.vertical, FMSpacing.small)
                    .background(.black.opacity(0.4), in: Capsule())
                }
            }

            Spacer()

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Image(systemName: "gearshape.fill")
                    .frame(width: 38, height: 38)
                    .background(.black.opacity(0.5), in: Circle())
            }
            .foregroundStyle(.white)
            .accessibilityIdentifier("camera.settings")
        }
    }

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

    private var aspectGuide: some View {
        GeometryReader { proxy in
            let frame = guideFrame(for: proxy.size, aspectRatio: controller.cropAspectRatio)

            ZStack {
                Color.clear

                Color.black.opacity(0.18)
                    .frame(width: proxy.size.width, height: max(frame.minY, 0))
                    .position(x: proxy.size.width / 2, y: max(frame.minY, 0) / 2)

                Color.black.opacity(0.18)
                    .frame(width: proxy.size.width, height: max(proxy.size.height - frame.maxY, 0))
                    .position(x: proxy.size.width / 2, y: frame.maxY + max(proxy.size.height - frame.maxY, 0) / 2)

                Color.black.opacity(0.18)
                    .frame(width: max(frame.minX, 0), height: frame.height)
                    .position(x: max(frame.minX, 0) / 2, y: frame.midY)

                Color.black.opacity(0.18)
                    .frame(width: max(proxy.size.width - frame.maxX, 0), height: frame.height)
                    .position(x: frame.maxX + max(proxy.size.width - frame.maxX, 0) / 2, y: frame.midY)

                RoundedRectangle(cornerRadius: 2)
                    .stroke(.white.opacity(0.42), lineWidth: 1)
                    .frame(width: frame.width, height: frame.height)
                    .position(x: frame.midX, y: frame.midY)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var aspectRatioPicker: some View {
        Picker("Aspect Ratio", selection: Binding(
            get: { controller.cropAspectRatio },
            set: { controller.setCropAspectRatio($0) }
        )) {
            ForEach(PhotoCropAspectRatio.allCases) { aspectRatio in
                Text(aspectRatio.label)
                    .tag(aspectRatio)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 184)
        .accessibilityIdentifier("camera.aspectRatio")
    }

    private func handleFocusTap(at location: CGPoint, viewSize: CGSize) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        let indicator = CameraFocusIndicator(location: location)
        withAnimation(.easeOut(duration: 0.16)) {
            focusIndicator = indicator
        }

        Task {
            await controller.focusAndExpose(at: location, in: viewSize)
            try? await Task.sleep(for: .milliseconds(850))

            await MainActor.run {
                guard focusIndicator?.id == indicator.id else { return }
                withAnimation(.easeIn(duration: 0.18)) {
                    focusIndicator = nil
                }
            }
        }
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

    private var filterCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FMSpacing.medium) {
                ForEach(store.filters) { filter in
                    Button {
                        store.select(filter)
                    } label: {
                        VStack(spacing: FMSpacing.small) {
                            FilterThumbnail(filter: filter)
                                .frame(width: 68, height: 68)
                                .overlay {
                                    if store.selectedFilterID == filter.id {
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(FMColor.accent, lineWidth: 3)
                                    }
                                }

                            Text(filter.title)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .frame(width: 76)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("camera.filter.\(filter.id.uuidString)")
                }
            }
            .padding(.vertical, FMSpacing.xSmall)
        }
    }

    private var intensitySlider: some View {
        HStack(spacing: FMSpacing.medium) {
            Image(systemName: "circle.lefthalf.filled")
                .foregroundStyle(.white.opacity(0.72))

            Slider(
                value: Binding(
                    get: { Double(controller.intensity) },
                    set: { controller.setIntensity(Float($0)) }
                ),
                in: 0...1
            )
            .tint(FMColor.accent)
            .accessibilityIdentifier("camera.filterIntensity")

            Text("\(Int((controller.intensity * 100).rounded()))")
                .font(.caption.monospacedDigit().weight(.bold))
                .foregroundStyle(.white.opacity(0.72))
                .frame(width: 30, alignment: .trailing)
        }
        .padding(.horizontal, FMSpacing.medium)
        .padding(.vertical, FMSpacing.small)
        .background(.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 8))
    }

    private var shutterBar: some View {
        HStack {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Image(systemName: "photo.on.rectangle")
                    .font(.title3)
                    .frame(width: 48, height: 48)
                    .background(.black.opacity(0.45), in: Circle())
            }
            .foregroundStyle(.white)
            .accessibilityIdentifier("camera.openLibrary")

            Spacer()

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                Task {
                    captureResult = await controller.capture(filter: store.selectedFilter)
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 74, height: 74)
                        .overlay {
                            Circle()
                                .stroke(.black.opacity(0.45), lineWidth: 3)
                                .frame(width: 61, height: 61)
                        }

                    if controller.isCapturing {
                        ProgressView()
                            .tint(.black)
                    }
                }
            }
            .disabled(controller.isCapturing)
            .accessibilityIdentifier("camera.shutter")

            Spacer()

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                Task {
                    await controller.switchCamera()
                }
            } label: {
                Image(systemName: controller.cameraPosition == .back ? "camera.rotate.fill" : "camera.fill")
                    .font(.title3)
                    .frame(width: 48, height: 48)
                    .background(.black.opacity(0.45), in: Circle())
            }
            .foregroundStyle(.white)
            .disabled(controller.isSwitchingCamera || controller.isCapturing)
            .accessibilityIdentifier("camera.flip")
        }
    }
}

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
            .stroke(.white.opacity(0.92), lineWidth: 1.5)
            .frame(width: 82, height: 82)
            .overlay {
                Circle()
                    .stroke(FMColor.accent.opacity(0.82), lineWidth: 1)
                    .frame(width: 58, height: 58)
            }
            .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
            .allowsHitTesting(false)
    }
}

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

private struct CaptureResultScreen: View {
    let result: CameraCaptureResult
    let photoLibrarySaver: any PhotoLibrarySaving

    @Environment(\.dismiss) private var dismiss
    @State private var saveState = CaptureSaveState.idle

    init(
        result: CameraCaptureResult,
        photoLibrarySaver: any PhotoLibrarySaving = PhotoLibrarySaver.live()
    ) {
        self.result = result
        self.photoLibrarySaver = photoLibrarySaver
    }

    var body: some View {
        VStack(spacing: FMSpacing.large) {
            Capsule()
                .fill(.white.opacity(0.28))
                .frame(width: 42, height: 4)

            FilterThumbnail(filter: result.filter)
                .frame(width: 160, height: 160)

            VStack(spacing: FMSpacing.xSmall) {
                Text("Captured with \(result.filter.title)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                Text(captureSummary)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.64))

                Text(saveState.message)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(saveState.messageColor)
                    .frame(minHeight: 18)
            }

            HStack(spacing: FMSpacing.medium) {
                Button("Retake") {
                    dismiss()
                }
                    .buttonStyle(.bordered)

                Button {
                    Task {
                        await savePhoto()
                    }
                } label: {
                    if saveState == .saving {
                        ProgressView()
                    } else {
                        Text(saveState.buttonTitle)
                    }
                }
                    .buttonStyle(.borderedProminent)
                    .tint(FMColor.accent)
                    .disabled(saveState.isSaveDisabled)
            }
        }
        .padding(FMSpacing.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FMColor.background)
    }

    private func formattedByteCount(_ byteCount: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
    }

    private var captureSummary: String {
        let original = formattedByteCount(result.photo.byteCount)
        let filtered = formattedByteCount(result.filteredPhoto.filteredByteCount)
        return "\(result.cropAspectRatio.label) · Original \(original) · Filtered \(filtered)"
    }

    private func savePhoto() async {
        guard !saveState.isSaveDisabled else { return }

        saveState = .saving
        let saveResult = await photoLibrarySaver.savePhoto(data: result.filteredPhoto.filteredData)
        saveState = CaptureSaveState(result: saveResult)
    }
}

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

    var buttonTitle: String {
        switch self {
        case .idle, .permissionDenied, .permissionRestricted, .permissionNotDetermined, .invalidData, .failed:
            "Save"
        case .saving:
            "Saving"
        case .saved:
            "Saved"
        }
    }

    var message: String {
        switch self {
        case .idle, .saving:
            ""
        case .saved:
            "Saved to Photos"
        case .permissionDenied, .permissionRestricted, .permissionNotDetermined:
            "Photos permission needed"
        case .invalidData:
            "Photo data is unavailable"
        case .failed:
            "Save failed"
        }
    }

    var messageColor: Color {
        switch self {
        case .saved:
            FMColor.accent
        case .permissionDenied, .permissionRestricted, .permissionNotDetermined, .invalidData, .failed:
            .red.opacity(0.85)
        case .idle, .saving:
            .white.opacity(0.64)
        }
    }

    var isSaveDisabled: Bool {
        self == .saving || self == .saved
    }
}
