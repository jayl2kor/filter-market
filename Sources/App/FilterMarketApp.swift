import Camera
import DesignSystem
import FilterEngine
import SwiftUI

@main
struct FilterMarketApp: App {
    var body: some Scene {
        WindowGroup {
            CameraScreen()
                .preferredColorScheme(.dark)
        }
    }
}

private struct CameraScreen: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var controller = CameraPreviewController()

    var body: some View {
        ZStack(alignment: .bottom) {
            MetalPreviewView(renderer: controller.renderer)
                .ignoresSafeArea()

            VStack(spacing: FMSpacing.large) {
                statusBar
                intensitySlider
                shutterButton
            }
            .padding(.horizontal, FMSpacing.large)
            .padding(.bottom, FMSpacing.xLarge)
        }
        .background(FMColor.background)
        .task {
            if scenePhase == .active {
                await controller.start()
            }
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
    }

    private var statusBar: some View {
        HStack {
            Text(controller.statusMessage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, FMSpacing.medium)
                .padding(.vertical, FMSpacing.small)
                .background(.black.opacity(0.55), in: Capsule())

            Spacer()
        }
    }

    private var intensitySlider: some View {
        Slider(
            value: Binding(
                get: { Double(controller.intensity) },
                set: { controller.setIntensity(Float($0)) }
            ),
            in: 0...1
        )
        .tint(FMColor.accent)
        .accessibilityIdentifier("camera.filterIntensity")
    }

    private var shutterButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            Circle()
                .fill(.white)
                .frame(width: 72, height: 72)
                .overlay {
                    Circle()
                        .stroke(.black.opacity(0.45), lineWidth: 3)
                        .frame(width: 60, height: 60)
                }
        }
        .accessibilityIdentifier("camera.shutter")
    }
}

@MainActor
private final class CameraPreviewController: ObservableObject {
    @Published private(set) var statusMessage = "Preparing camera"
    @Published private(set) var metricsText = "0 FPS · GPU 0.00ms · CPU 0.00ms"
    @Published private(set) var intensity: Float = 0.65

    let renderer = MetalPreviewRenderer()

    private let cameraSession = CameraSession()
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
        renderer.setIntensity(intensity)
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
