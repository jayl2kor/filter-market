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

    var body: some View {
        ZStack(alignment: .bottom) {
            MetalPreviewView(renderer: controller.renderer)
                .ignoresSafeArea()

            VStack(spacing: FMSpacing.large) {
                topBar
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
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera")
                    .font(.title3)
                    .frame(width: 48, height: 48)
                    .background(.black.opacity(0.45), in: Circle())
            }
            .foregroundStyle(.white)
            .accessibilityIdentifier("camera.flip")
        }
    }
}

private struct CameraCaptureResult: Identifiable {
    let id = UUID()
    let filter: Filter
    let photo: CapturedPhoto
    let filteredPhoto: FilteredPhoto
}

@MainActor
private final class CameraPreviewController: ObservableObject {
    @Published private(set) var statusMessage = "Preparing camera"
    @Published private(set) var metricsText = "0 FPS · GPU 0.00ms · CPU 0.00ms"
    @Published private(set) var intensity: Float = 0.65
    @Published private(set) var isCapturing = false

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
            let filteredPhoto = try photoFilterRenderer.apply(to: photo.data, configuration: configuration)
            statusMessage = "Filtered photo captured"
            return CameraCaptureResult(filter: filter, photo: photo, filteredPhoto: filteredPhoto)
        } catch {
            statusMessage = "Capture failed"
            return nil
        }
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
        return "Original \(original) · Filtered \(filtered). PhotoKit saving is next."
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
