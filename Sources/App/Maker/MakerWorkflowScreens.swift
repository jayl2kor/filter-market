import DesignSystem
import FilterEngine
import Foundation
import Marketplace
import Models
import PhotosUI
import SwiftUI
import UIKit

private struct EditorReferencePreview: View {
    @EnvironmentObject private var editorDraftStore: EditorDraftStore
    @State private var renderedImage: UIImage?
    @State private var sourceImage: UIImage?
    @State private var isRendering = false
    @State private var showingBefore = false

    let height: CGFloat

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let image = showingBefore ? sourceImage : (renderedImage ?? sourceImage) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                LinearGradient(
                    colors: editorDraftStore.editorDraft.category.swatch,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            LinearGradient(colors: [.clear, .black.opacity(0.48)], startPoint: .center, endPoint: .bottom)

            VStack(alignment: .leading, spacing: Sp.xs) {
                Text(showingBefore ? "BEFORE" : "AFTER")
                    .fmTypography(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Sp.sm)
                    .padding(.vertical, Sp.xs)
                    .background(.black.opacity(0.28), in: Capsule())
                    .accessibilityIdentifier("editor.compare.hold")

                Text(editorDraftStore.editorDraft.name.isEmpty ? "Untitled Filter" : editorDraftStore.editorDraft.name)
                    .fmTypography(.titleLarge)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .padding(Sp.md)
            .frame(maxWidth: .infinity, alignment: .leading)

            if isRendering && renderedImage == nil {
                ProgressView()
                    .tint(FMColors.Accent.primary)
                    .padding(Sp.sm)
                    .background(.regularMaterial, in: Capsule())
                    .padding(Sp.sm)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: R.lg))
        .overlay {
            RoundedRectangle(cornerRadius: R.lg)
                .strokeBorder(FMColors.Border.subtle, lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: R.lg))
        .onLongPressGesture(
            minimumDuration: 0.01,
            perform: {},
            onPressingChanged: { isPressing in
                showingBefore = isPressing
            }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(showingBefore ? "참조 사진 원본" : "참조 사진 현재 파라미터 적용 결과")
        .accessibilityIdentifier("editor.preview")
        .task(id: renderKey) {
            await scheduleRender()
        }
    }

    private var renderKey: EditorPreviewRenderKey {
        EditorPreviewRenderKey(
            category: editorDraftStore.editorDraft.category,
            sampleKind: editorDraftStore.editorReferenceSampleKind,
            referenceRevision: editorDraftStore.editorReferencePhotoRevision,
            lutRevision: editorDraftStore.editorImportedLUTRevision,
            exposure: quantized("exposure"),
            contrast: quantized("contrast"),
            saturation: quantized("saturation"),
            grain: quantized("grain"),
            vignette: quantized("vignette")
        )
    }

    private func quantized(_ key: String) -> Int {
        Int(((editorDraftStore.editorDraft.parameterValues[key] ?? 0) * 1_000).rounded())
    }

    @MainActor
    private func scheduleRender() async {
        try? await Task.sleep(nanoseconds: 16_000_000)
        guard !Task.isCancelled else { return }
        await render()
    }

    @MainActor
    private func render() async {
        let referenceData = previewReferenceData()
        sourceImage = UIImage(data: referenceData)

        let sourceLUT = editorDraftStore.editorImportedLUT
            ?? LUT3D.preset(LUTPreset.preset(for: editorDraftStore.editorDraft.category), size: 33)
        let parameters = editorDraftStore.editorPreviewParameters
        let grain = editorDraftStore.editorPreviewGrain
        let vignette = editorDraftStore.editorPreviewVignette

        isRendering = true
        defer { isRendering = false }

        do {
            let renderedCGImage = try await Task.detached(priority: .userInitiated) {
                let bakedLUT = LUTBake.bake(sourceLUT: sourceLUT, parameters: parameters)
                let renderer = PhotoFilterRenderer(jpegCompressionQuality: 0.86)
                return try renderer.renderImage(
                    from: referenceData,
                    sourceLUT: bakedLUT,
                    intensity: .full,
                    grain: grain,
                    vignette: vignette,
                    cropAspectRatio: nil
                )
            }.value
            renderedImage = UIImage(cgImage: renderedCGImage)
        } catch {
            renderedImage = sourceImage
        }
    }

    private func previewReferenceData() -> Data {
        if let data = editorDraftStore.editorReferencePhotoData,
           let image = UIImage(data: data),
           let resized = EditorReferenceSampleImage.normalizedJPEGData(from: image, maxLongEdge: 800) {
            return resized
        }
        return EditorReferenceSampleImage.makeJPEGData(kind: editorDraftStore.editorReferenceSampleKind)
    }
}

private struct EditorPreviewRenderKey: Hashable {
    let category: FilterCategory
    let sampleKind: EditorReferenceSampleKind
    let referenceRevision: Int
    let lutRevision: Int
    let exposure: Int
    let contrast: Int
    let saturation: Int
    let grain: Int
    let vignette: Int
}

struct FilterEditorScreen: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var editorDraftStore: EditorDraftStore
    @State private var showCancelAlert = false
    @State private var selectedReferenceItem: PhotosPickerItem?
    @State private var referenceLoadError: String?
    @State private var selectedParameterKey: String = EditorAdjustment.exposure.rawValue

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.lg) {
                makerProgress(active: .edit)
                editorPreview
                referenceSourceControls
            }
            .padding(Sp.md)
            .padding(.bottom, Sp.md)
        }
        .background(FMColors.Background.bg1)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                adjustmentDock
                stickyContinueBar
            }
        }
        .navigationTitle("필터 에디터")
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showCancelAlert = true
                } label: {
                    Image(systemName: "xmark")
                }
                .accessibilityLabel("닫기")
                .accessibilityIdentifier("editor.cancel")
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: AppRoute.editorDraft) {
                    Text("완료")
                        .fontWeight(.semibold)
                }
                .simultaneousGesture(TapGesture().onEnded {
                    editorDraftStore.saveEditorDraft()
                })
                .accessibilityIdentifier("editor.next")
            }
        }
        .fmConfirmationDialog(
            "작성 중인 내용",
            isPresented: $showCancelAlert
        ) {
            Button("임시 저장") {
                editorDraftStore.saveEditorDraft()
                dismiss()
            }
            Button("버리기", role: .destructive) {
                editorDraftStore.resetEditorDraft()
                dismiss()
            }
            Button("계속 작성", role: .cancel) {}
        } message: {
            Text("임시저장하면 다음에 이어 쓸 수 있어요. 버리면 변경 사항이 모두 사라져요.")
        }
        .onChange(of: selectedReferenceItem) { _, newItem in
            Task { await loadReferencePhoto(from: newItem) }
        }
    }

    private var editorPreview: some View {
        EditorReferencePreview(height: 360)
            .overlay(alignment: .topTrailing) {
                Label("길게 눌러 비교", systemImage: "rectangle.lefthalf.filled")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Sp.sm)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.42), in: Capsule())
                    .padding(Sp.md)
                    .accessibilityHidden(true)
            }
    }

    @ViewBuilder
    private var referenceSourceControls: some View {
        let hasReferencePhoto = editorDraftStore.editorReferencePhotoData != nil
        VStack(alignment: .leading, spacing: Sp.sm) {
            HStack(spacing: Sp.sm) {
                sectionLabel("참조 사진")
                Spacer()
                PhotosPicker(selection: $selectedReferenceItem, matching: .images) {
                    Label(hasReferencePhoto ? "사진 교체" : "사진 선택", systemImage: "photo.badge.plus")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(FMColors.Accent.primary)
                }
                .accessibilityIdentifier("editor.reference.photo.pick")

                if hasReferencePhoto {
                    Button {
                        editorDraftStore.setEditorReferencePhotoData(nil)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundStyle(FMColors.Text.tertiary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("참조 사진 제거")
                    .accessibilityIdentifier("editor.reference.photo.clear")
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Sp.xs) {
                    ForEach(EditorReferenceSampleKind.allCases) { kind in
                        FMChip(
                            kind.title,
                            isSelected: !hasReferencePhoto && editorDraftStore.editorReferenceSampleKind == kind
                        ) {
                            editorDraftStore.setEditorReferenceSampleKind(kind)
                            FMHaptic.selection.play()
                        }
                        .accessibilityIdentifier("editor.reference.sample.\(kind.rawValue)")
                    }
                }
            }

            if let referenceLoadError {
                Text(referenceLoadError)
                    .fmTypography(.caption)
                    .foregroundStyle(FMColors.Semantic.error)
            }
        }
    }

    @MainActor
    private func loadReferencePhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            guard
                let data = try await item.loadTransferable(type: Data.self),
                let image = UIImage(data: data),
                let normalized = EditorReferenceSampleImage.normalizedJPEGData(from: image)
            else {
                referenceLoadError = "사진 데이터를 읽지 못했어요."
                return
            }
            editorDraftStore.setEditorReferencePhotoData(normalized)
            referenceLoadError = nil
            FMHaptic.success.play()
        } catch {
            referenceLoadError = "사진을 불러오지 못했어요."
            FMHaptic.error.play()
        }
    }

    private var stickyContinueBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(FMColors.Border.subtle)
                .frame(height: 0.5)
            NavigationLink(value: AppRoute.uploadCover) {
                routeButton("마켓 공유로 계속", icon: "arrow.right")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("editor.next")
            .padding(.horizontal, Sp.md)
            .padding(.vertical, Sp.sm)
        }
        .background(FMColors.Background.bg1)
    }

    private var adjustmentDock: some View {
        VStack(spacing: Sp.md) {
            adjustmentSliderRow
            parameterStrip
        }
        .padding(.horizontal, Sp.md)
        .padding(.top, Sp.md)
        .padding(.bottom, Sp.sm)
        .background(FMColors.Background.bg2)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(FMColors.Border.subtle)
                .frame(height: 0.5)
        }
        .accessibilityIdentifier("editor.dock")
    }

    private var adjustmentSliderRow: some View {
        let key = selectedParameterKey
        let value = editorDraftStore.editorDraft.parameterValues[key] ?? 0
        let isAtZero = abs(value) < 0.0001
        return VStack(alignment: .leading, spacing: Sp.xs) {
            HStack {
                Text(parameterTitle(key))
                    .fmTypography(.subhead)
                    .fontWeight(.semibold)
                    .foregroundStyle(FMColors.Text.primary)
                Spacer()
                Button {
                    guard !isAtZero else { return }
                    editorDraftStore.updateEditorParameter(key, value: 0)
                    FMHaptic.light.play()
                } label: {
                    Text(parameterFormatted(value))
                        .fmTypography(.caption)
                        .monospacedDigit()
                        .foregroundStyle(isAtZero ? FMColors.Text.tertiary : FMColors.Accent.primary)
                        .padding(.horizontal, Sp.sm)
                        .frame(minHeight: 28)
                        .background(
                            isAtZero ? Color.clear : FMColors.Accent.bg,
                            in: Capsule()
                        )
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isAtZero)
                .accessibilityLabel(isAtZero ? "현재 원본" : "\(parameterTitle(key)) 원본으로 되돌리기")
                .accessibilityIdentifier("editor.param.reset.\(key)")
            }
            FMSlider(
                value: Binding(
                    get: { editorDraftStore.editorDraft.parameterValues[key] ?? 0 },
                    set: { editorDraftStore.updateEditorParameter(key, value: $0) }
                ),
                range: -1...1,
                label: nil,
                showValue: false
            )
            .id(key)
            .accessibilityIdentifier("editor.param.slider.\(key)")
        }
        .accessibilityIdentifier("editor.param.slider")
    }

    private var parameterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Sp.md) {
                ForEach(EditorAdjustment.allCases) { adjustment in
                    parameterStripItem(adjustment)
                }
                Divider()
                    .frame(height: 32)
                    .padding(.horizontal, Sp.xxs)
                lutStripItem
            }
            .padding(.vertical, Sp.xs)
        }
        .accessibilityIdentifier("editor.param.strip")
    }

    private func parameterStripItem(_ adjustment: EditorAdjustment) -> some View {
        let key = adjustment.rawValue
        let value = editorDraftStore.editorDraft.parameterValues[key] ?? 0
        let progress = min(1, abs(value))
        let isSelected = selectedParameterKey == key
        return Button {
            selectedParameterKey = key
            FMHaptic.selection.play()
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(isSelected ? FMColors.Accent.bg : Color.clear)
                        .frame(width: 44, height: 44)
                    Circle()
                        .stroke(FMColors.Border.subtle, lineWidth: 2)
                        .frame(width: 44, height: 44)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(FMColors.Accent.primary, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(-90))
                    Image(systemName: adjustment.systemImage)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isSelected ? FMColors.Accent.primary : FMColors.Text.secondary)
                }
                Text(adjustment.title)
                    .fmTypography(.caption)
                    .foregroundStyle(isSelected ? FMColors.Text.primary : FMColors.Text.tertiary)
                    .lineLimit(1)
            }
            .frame(width: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                editorDraftStore.updateEditorParameter(key, value: 0)
                selectedParameterKey = key
                FMHaptic.light.play()
            }
        )
        .accessibilityLabel("\(adjustment.title)\(isSelected ? ", 선택됨" : ""), 두 번 탭하면 원본으로 되돌립니다")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("editor.param.strip.\(key)")
    }

    private var lutStripItem: some View {
        let hasCustomLUT = editorDraftStore.editorDraft.lutFileName != nil
        return NavigationLink(value: AppRoute.editorLUT) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .stroke(FMColors.Border.subtle, lineWidth: 2)
                        .frame(width: 44, height: 44)
                    if hasCustomLUT {
                        Circle()
                            .stroke(FMColors.Accent.primary, lineWidth: 2)
                            .frame(width: 44, height: 44)
                    }
                    Image(systemName: "cube.transparent")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(hasCustomLUT ? FMColors.Accent.primary : FMColors.Text.secondary)
                }
                Text("LUT")
                    .fmTypography(.caption)
                    .foregroundStyle(FMColors.Text.tertiary)
                    .lineLimit(1)
            }
            .frame(width: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(hasCustomLUT ? "LUT 가져오기, 사용자 LUT 적용됨" : "LUT 가져오기")
        .accessibilityIdentifier("editor.lut")
    }

}

private func parameterFormatted(_ value: Double) -> String {
    abs(value) < 0.0001 ? "원본" : String(format: "%+.2f", value)
}

@MainActor @ViewBuilder
private func makerSummaryRow(_ title: String, value: String) -> some View {
    HStack(alignment: .top) {
        Text(title)
            .fmTypography(.subhead)
            .foregroundStyle(FMColors.Text.secondary)
        Spacer()
        Text(value)
            .fmTypography(.subhead)
            .foregroundStyle(FMColors.Text.primary)
            .multilineTextAlignment(.trailing)
    }
}

private enum EditorAdjustment: String, CaseIterable, Identifiable {
    case exposure
    case contrast
    case saturation
    case grain
    case vignette

    var id: String { rawValue }
    var title: String { parameterTitle(rawValue) }

    var systemImage: String {
        switch self {
        case .exposure: "sun.max"
        case .contrast: "circle.lefthalf.filled"
        case .saturation: "drop.fill"
        case .grain: "circle.dotted"
        case .vignette: "circle.dashed"
        }
    }
}

struct EditorParametersScreen: View {
    @EnvironmentObject private var editorDraftStore: EditorDraftStore
    @State private var selectedSection: EditorParameterSection = .lighting
    /// Local UI-only LUT strength (0…1). Intentionally not persisted to
    /// `editorDraft.parameterValues` — issue #290 explicitly forbids
    /// changing the persisted parameter schema. Adds an affordance to the
    /// LUT section without polluting slider storage.
    @State private var lutStrength: Double = 1.0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.lg) {
                Text("조명, 색, 질감 값을 조정해 필터 룩을 만듭니다.")
                    .fmTypography(.subhead)
                    .foregroundStyle(FMColors.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                EditorReferencePreview(height: 300)
                sectionTabs
                sectionContent
                compareCard
                NavigationLink(value: AppRoute.editorLUT) {
                    routeButton("계속", icon: "arrow.right")
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("editor.next")
            }
            .padding(Sp.md)
            .padding(.bottom, FMLayout.tabBarHeight + Sp.xxxl)
        }
        .background(FMColors.Background.bg1)
        .navigationTitle("파라미터")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var sectionTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Sp.xs) {
                ForEach(EditorParameterSection.allCases) { section in
                    FMChip(section.title, isSelected: selectedSection == section) {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selectedSection = section
                        }
                    }
                    .accessibilityIdentifier(section.actionID)
                }
            }
        }
    }

    @ViewBuilder
    private var sectionContent: some View {
        if selectedSection == .lut {
            lutCard
        } else {
            sliders(for: selectedSection.parameterKeys)
        }
    }

    private func sliders(for keys: [String]) -> some View {
        FMCard {
            VStack(spacing: Sp.md) {
                ForEach(keys, id: \.self) { key in
                    FMSlider(
                        value: Binding(
                            get: { editorDraftStore.editorDraft.parameterValues[key] ?? 0 },
                            set: { editorDraftStore.updateEditorParameter(key, value: $0) }
                        ),
                        range: -1...1,
                        label: parameterTitle(key),
                        valueFormatter: parameterFormatted
                    )
                    .accessibilityIdentifier("editor.param.slider.\(key)")
                }
            }
            .accessibilityIdentifier("editor.param.slider")
        }
    }

    private var lutCard: some View {
        FMCard {
            VStack(alignment: .leading, spacing: Sp.md) {
                HStack(spacing: Sp.sm) {
                    Image(systemName: "cube.transparent")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(FMColors.Accent.primary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(editorDraftStore.editorDraft.lutFileName ?? "LUT 파일 없음")
                            .fmTypography(.headline)
                            .foregroundStyle(FMColors.Text.primary)
                        Text("LUT 파일을 가져오거나 강도를 조절해 색감을 정밀 제어합니다.")
                            .fmTypography(.caption)
                            .foregroundStyle(FMColors.Text.secondary)
                    }
                }

                NavigationLink(value: AppRoute.editorLUT) {
                    routeButton("LUT 가져오기", icon: "tray.and.arrow.down")
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("editor.lut.entry")

                VStack(alignment: .leading, spacing: Sp.xs) {
                    HStack {
                        Text("LUT 강도")
                            .fmTypography(.body)
                            .foregroundStyle(FMColors.Text.primary)
                        Spacer()
                        Text("\(Int(lutStrength * 100))")
                            .fmTypography(.caption)
                            .foregroundStyle(FMColors.Text.tertiary)
                    }
                    Slider(value: $lutStrength, in: 0...1)
                        .tint(FMColors.Accent.primary)
                        .accessibilityIdentifier("editor.lut.intensity")
                }
            }
            .accessibilityIdentifier("editor.lut.card")
        }
    }

    private var compareCard: some View {
        HStack(spacing: Sp.sm) {
            Image(systemName: "rectangle.lefthalf.filled")
                .foregroundStyle(FMColors.Accent.primary)
            Text("비포 보기는 프리뷰를 길게 눌러 확인합니다.")
                .fmTypography(.subhead)
                .foregroundStyle(FMColors.Text.secondary)
        }
        .padding(Sp.md)
        .background(FMColors.Accent.bg, in: RoundedRectangle(cornerRadius: R.md))
        .accessibilityIdentifier("editor.compare.hold")
    }
}

struct EditorLUTImportScreen: View {
    @EnvironmentObject private var editorDraftStore: EditorDraftStore
    @State private var importCount = 0
    @State private var showingImporter = false
    @State private var importError: ImportErrorMessage?

    struct ImportErrorMessage: Identifiable {
        let id = UUID()
        let message: String
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.lg) {
                makerProgress(active: .lut)
                workflowHeader(
                    title: "LUT 파일 추가",
                    subtitle: "Cube LUT 파일을 연결하고 검증 상태를 확인합니다.",
                    symbol: "cube.transparent"
                )
                lutCard
                lutGuideCard
                validationCard
                EditorReferencePreview(height: 300)
                NavigationLink(value: AppRoute.editorDraft) {
                    routeButton("초안 저장 단계로", icon: "arrow.right")
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("editor.next")
            }
            .padding(Sp.md)
            .padding(.bottom, FMLayout.tabBarHeight + Sp.xxxl)
        }
        .background(FMColors.Background.bg1)
        .navigationTitle("LUT 가져오기")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingImporter) {
            DocumentPicker(allowedTypes: [.cube]) { url in
                handleImportedLUT(at: url)
            }
        }
        .alert(item: $importError) { error in
            Alert(
                title: Text("이 LUT는 지원되지 않아요"),
                message: Text(error.message),
                primaryButton: .default(Text("다시 선택")) {
                    showingImporter = true
                },
                secondaryButton: .cancel(Text("닫기"))
            )
        }
    }

    private func handleImportedLUT(at url: URL) {
        // Coordinate access for security-scoped resources from the file picker.
        let needsAccess = url.startAccessingSecurityScopedResource()
        defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }

        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            let parsed = try CubeLUTParser.parse(text)
            importCount += 1
            editorDraftStore.setEditorLUT(url.lastPathComponent, lut: previewLUT(from: parsed))
            FMHaptic.success.play()
        } catch {
            importError = ImportErrorMessage(message: friendlyMessage(for: error))
            FMHaptic.error.play()
        }
    }

    private func friendlyMessage(for error: Error) -> String {
        let recovery = "\n\n지원 포맷은 .cube 1D/3D이고, 권장 크기는 33x33x33입니다. 영상, 이미지, .3dl, 손상된 파일은 가져올 수 없어요."
        if let parseError = error as? CubeLUTParser.ParseError {
            switch parseError {
            case .missingSizeHeader:
                return "LUT_1D_SIZE 또는 LUT_3D_SIZE 헤더를 찾을 수 없어요." + recovery
            case .duplicateSizeHeader:
                return "1D와 3D LUT 헤더가 모두 있어요. 둘 중 하나만 남겨주세요." + recovery
            case .invalidSizeValue(let line, _):
                return "LUT 크기 값을 읽을 수 없어요 (\(line)번째 줄)." + recovery
            case .sizeOutOfRange(_, let size, let allowed):
                return "지원 범위(\(allowed.lowerBound)~\(allowed.upperBound)) 밖의 크기예요: \(size)." + recovery
            case .malformedDataLine(let line, _):
                return "데이터 줄 형식이 잘못됐어요 (\(line)번째 줄). 각 줄은 R G B 세 값이어야 합니다." + recovery
            case .rowCountMismatch(let expected, let actual):
                return "데이터 행 수가 맞지 않아요. 예상 \(expected) / 실제 \(actual)." + recovery
            case .valueNotFinite(let line):
                return "유효하지 않은 숫자가 포함돼 있어요 (\(line)번째 줄)." + recovery
            }
        }
        return error.localizedDescription + recovery
    }

    private func previewLUT(from parsed: CubeLUTParser.LUT) -> LUT3D? {
        switch parsed {
        case .threeDimensional(let lut):
            return lut
        case .oneDimensional(let samples):
            guard samples.count >= 2 else { return nil }
            let size = 17
            var values: [RGBColor] = []
            values.reserveCapacity(size * size * size)
            for b in 0 ..< size {
                for g in 0 ..< size {
                    for r in 0 ..< size {
                        values.append(
                            RGBColor(
                                red: sample1D(samples, value: Float(r) / Float(size - 1), channel: \.red),
                                green: sample1D(samples, value: Float(g) / Float(size - 1), channel: \.green),
                                blue: sample1D(samples, value: Float(b) / Float(size - 1), channel: \.blue)
                            )
                        )
                    }
                }
            }
            return LUT3D(size: size, values: values)
        }
    }

    private func sample1D(_ samples: [RGBColor], value: Float, channel: KeyPath<RGBColor, Float>) -> Float {
        let clamped = min(max(value, 0), 1)
        let scaled = clamped * Float(samples.count - 1)
        let lower = Int(floor(scaled))
        let upper = min(lower + 1, samples.count - 1)
        let t = scaled - Float(lower)
        return samples[lower][keyPath: channel] * (1 - t) + samples[upper][keyPath: channel] * t
    }

    private var lutCard: some View {
        FMCard {
            VStack(alignment: .leading, spacing: Sp.md) {
                HStack {
                    Image(systemName: "doc.badge.gearshape")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(FMColors.Accent.primary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(editorDraftStore.editorDraft.lutFileName ?? "LUT 파일 없음")
                            .fmTypography(.headline)
                            .foregroundStyle(FMColors.Text.primary)
                        Text("33x33 Cube · sRGB · 1.2MB")
                            .fmTypography(.caption)
                            .foregroundStyle(FMColors.Text.secondary)
                    }
                    Spacer()
                }

                HStack(spacing: Sp.sm) {
                    FMButton("가져오기", icon: "folder", variant: .secondary) {
                        showingImporter = true
                    }
                    .accessibilityIdentifier("editor.lut.import")
                    .accessibilityLabel("LUT 파일 가져오기")

                    FMButton("교체", icon: "arrow.triangle.2.circlepath", variant: .secondary) {
                        showingImporter = true
                    }
                    .accessibilityIdentifier("editor.lut.replace")
                    .accessibilityLabel("LUT 파일 교체")
                }
            }
        }
    }

    private var lutGuideCard: some View {
        FMCard {
            VStack(alignment: .leading, spacing: Sp.sm) {
                sectionLabel("가져오기 가이드")
                guideRow("지원 포맷", "Adobe .cube 1D/3D")
                workflowDivider()
                guideRow("권장 크기", "33x33x33 · 최대 64x64x64")
                workflowDivider()
                guideRow("실패 원인", "손상 파일, 비표준 행 수, 영상/이미지/.3dl 파일")
            }
        }
        .accessibilityIdentifier("editor.lut.guide")
    }

    private var validationCard: some View {
        let hasLUT = editorDraftStore.editorDraft.lutFileName != nil
        return FMCard {
            VStack(alignment: .leading, spacing: Sp.sm) {
                sectionLabel("검증")
                validationRow("파일 형식", value: hasLUT ? "Cube LUT" : "검증 전", isPassed: hasLUT)
                workflowDivider()
                validationRow("권장 크기", value: "33x33x33", isPassed: hasLUT)
                workflowDivider()
                validationRow("색공간", value: hasLUT ? "sRGB" : "검증 전", isPassed: hasLUT)
                workflowDivider()
                validationRow("앱 호환성", value: "iOS 17+", isPassed: true)
            }
        }
    }

    private func guideRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .fmTypography(.subhead)
                .foregroundStyle(FMColors.Text.secondary)
            Spacer(minLength: Sp.md)
            Text(value)
                .fmTypography(.subhead)
                .foregroundStyle(FMColors.Text.primary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func validationRow(_ title: String, value: String, isPassed: Bool) -> some View {
        HStack {
            Image(systemName: isPassed ? "checkmark.circle.fill" : "exclamationmark.circle")
                .foregroundStyle(isPassed ? FMColors.Accent.primary : FMColors.Text.tertiary)
            Text(title)
                .fmTypography(.body)
                .foregroundStyle(FMColors.Text.primary)
            Spacer()
            Text(value)
                .fmTypography(.caption)
                .foregroundStyle(FMColors.Text.secondary)
        }
    }
}

struct EditorDraftSaveScreen: View {
    @EnvironmentObject private var editorDraftStore: EditorDraftStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.lg) {
                makerProgress(active: .draft)
                workflowHeader(
                    title: "초안 저장",
                    subtitle: "마켓 공유 전에 이름과 설명을 정리합니다.",
                    symbol: "tray.and.arrow.down"
                )
                draftForm
                draftSummary
                actionButtons
            }
            .padding(Sp.md)
            .padding(.bottom, FMLayout.tabBarHeight + Sp.xxxl)
        }
        .background(FMColors.Background.bg1)
        .navigationTitle("초안 저장")
        .navigationBarTitleDisplayMode(.inline)
        .storeErrorToast(
            message: editorDraftStore.lastSubmitErrorMessage,
            title: "초안 저장 실패"
        ) {
            editorDraftStore.clearLastSubmitError()
        }
    }

    private var draftForm: some View {
        VStack(spacing: Sp.md) {
            FMTextField(
                "필터 이름",
                text: Binding(
                    get: { editorDraftStore.editorDraft.name },
                    set: { value in
                        editorDraftStore.updateEditorDraft { draft in
                            draft.name = value
                        }
                    }
                ),
                placeholder: "Amber Cafe",
                autocapitalization: .words,
                submitLabel: .next
            )
                .accessibilityIdentifier("editor.draft.name")
            FMTextField(
                "설명",
                text: Binding(
                    get: { editorDraftStore.editorDraft.summary },
                    set: { value in
                        editorDraftStore.updateEditorDraft { draft in
                            draft.summary = value
                        }
                    }
                ),
                placeholder: "분위기와 추천 사용처",
                style: .multiline(minHeight: 112),
                submitLabel: .return
            )
            .accessibilityIdentifier("editor.draft.description")
        }
    }

    private var draftSummary: some View {
        FMCard {
            VStack(alignment: .leading, spacing: Sp.sm) {
                sectionLabel("초안 상태")
                HStack {
                    Text(editorDraftStore.editorDraft.category.displayTitle)
                    Spacer()
                    Text(editorDraftStore.editorDraft.lutFileName ?? "기본 LUT")
                }
                .fmTypography(.subhead)
                .foregroundStyle(FMColors.Text.secondary)
                workflowDivider()
                Text(editorDraftStore.editorDraft.tags.map { "#\($0)" }.joined(separator: " "))
                    .fmTypography(.caption)
                    .foregroundStyle(FMColors.Text.tertiary)
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: Sp.sm) {
            NavigationLink(value: AppRoute.myFilters) {
                routeButton("초안 저장 후 내 필터", icon: "tray")
            }
            .simultaneousGesture(TapGesture().onEnded {
                editorDraftStore.saveEditorDraft()
            })
            .buttonStyle(.plain)
            .accessibilityIdentifier("editor.draft.save")

            NavigationLink(value: AppRoute.uploadCover) {
                routeButton("바로 마켓 공유", icon: "paperplane")
            }
            .simultaneousGesture(TapGesture().onEnded {
                editorDraftStore.saveEditorDraft()
            })
            .buttonStyle(.plain)
            .accessibilityIdentifier("editor.draft.publish")
        }
    }
}

struct UploadCoverScreen: View {
    @EnvironmentObject private var editorDraftStore: EditorDraftStore
    @Environment(\.dismiss) private var dismiss
    @State private var showCancelAlert = false
    @State private var showCoverRemovalConfirmation = false
    @State private var pendingCoverRemovalIndex: Int?
    @State private var selectedCoverItem: PhotosPickerItem?
    @State private var coverLoadError: String?
    @State private var selectedSignatureItem: PhotosPickerItem?
    @State private var signatureLoadError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.lg) {
                uploadProgress(active: .cover)
                coverHeader
                coverSection
                signatureSampleSection
                beforeAfterToggle
            }
            .padding(Sp.md)
            .padding(.bottom, Sp.lg)
        }
        .background(FMColors.Background.bg1)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            nextActionBar
        }
        .navigationTitle("썸네일 업로드")
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(true)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCancelAlert = true
                } label: {
                    Image(systemName: "xmark")
                }
                .accessibilityLabel("닫기")
                .accessibilityIdentifier("upload.cancel")
            }
        }
        .confirmationDialog("업로드를 취소할까요?", isPresented: $showCancelAlert, titleVisibility: .visible) {
            Button("초안 저장하고 나가기") {
                editorDraftStore.saveEditorDraft()
                dismiss()
            }
            Button("초안 버리고 나가기", role: .destructive) {
                editorDraftStore.resetEditorDraft()
                dismiss()
            }
            Button("계속 작성", role: .cancel) {}
        } message: {
            Text("작성한 내용을 임시저장하면 다음에 이어 쓸 수 있어요.")
        }
        .confirmationDialog("마켓 썸네일을 삭제할까요?", isPresented: $showCoverRemovalConfirmation, titleVisibility: .visible) {
            Button("삭제", role: .destructive) {
                if pendingCoverRemovalIndex != nil {
                    editorDraftStore.removeUploadCover()
                }
                pendingCoverRemovalIndex = nil
            }
            Button("취소", role: .cancel) {
                pendingCoverRemovalIndex = nil
            }
        } message: {
            Text("삭제하면 마켓 카드에 표시할 대표 이미지가 비어 있습니다.")
        }
        .onChange(of: selectedSignatureItem) { _, item in
            Task {
                await loadSignatureSample(from: item)
                await MainActor.run {
                    selectedSignatureItem = nil
                }
            }
        }
        .onChange(of: selectedCoverItem) { _, item in
            Task {
                await loadCoverPhoto(from: item)
                await MainActor.run {
                    selectedCoverItem = nil
                }
            }
        }
        .onDisappear {
            editorDraftStore.saveCurrentUploadDraftIfNeeded()
        }
        .storeErrorToast(
            message: editorDraftStore.lastSubmitErrorMessage,
            title: "초안 저장 실패"
        ) {
            editorDraftStore.clearLastSubmitError()
        }
    }

    private var coverHeader: some View {
        HStack(alignment: .top, spacing: Sp.sm) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(FMColors.Accent.primary)
                .frame(width: 44, height: 44)
                .background(FMColors.Accent.bg, in: RoundedRectangle(cornerRadius: R.md))
                .overlay {
                    RoundedRectangle(cornerRadius: R.md)
                        .strokeBorder(FMColors.Accent.primary.opacity(0.24), lineWidth: 1)
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Sp.xs) {
                Text("썸네일 선택")
                    .fmTypography(.titleLarge)
                    .foregroundStyle(FMColors.Text.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("마켓 카드에서 보일 대표 이미지 1장을 고릅니다.")
                    .fmTypography(.body)
                    .foregroundStyle(FMColors.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var coverSection: some View {
        FMCard {
            VStack(alignment: .leading, spacing: Sp.sm) {
                sectionLabel("마켓 썸네일")
                coverThumbnailSlot

                if let coverLoadError {
                    Text(coverLoadError)
                        .fmTypography(.caption)
                        .foregroundStyle(FMColors.Semantic.error)
                }
            }
        }
    }

    @ViewBuilder
    private var coverThumbnailSlot: some View {
        if editorDraftStore.editorDraft.coverCount > 0 {
            VStack(alignment: .leading, spacing: Sp.sm) {
                coverTile(index: 0)
                PhotosPicker(selection: $selectedCoverItem, matching: .images) {
                    Label("사진 교체", systemImage: "photo.badge.plus")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(FMColors.Accent.primary)
                }
                .accessibilityIdentifier("upload.cover.add")
            }
        } else {
            PhotosPicker(selection: $selectedCoverItem, matching: .images) {
                ZStack {
                    RoundedRectangle(cornerRadius: R.md)
                        .fill(FMColors.Accent.bg)
                        .overlay {
                            RoundedRectangle(cornerRadius: R.md)
                                .strokeBorder(FMColors.Accent.primary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [5]))
                        }

                    VStack(spacing: Sp.xs) {
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .semibold))
                        Text("썸네일 추가")
                            .font(.caption.weight(.semibold))
                            .minimumScaleFactor(0.85)
                    }
                    .foregroundStyle(FMColors.Accent.primary)
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .contentShape(RoundedRectangle(cornerRadius: R.md))
            .accessibilityLabel("마켓 썸네일 추가")
            .accessibilityIdentifier("upload.cover.add")
        }
    }

    private func coverTile(index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            ZStack {
                if let image = coverPreviewImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                } else {
                    LinearGradient(colors: editorDraftStore.editorDraft.category.swatch, startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: R.md))
            Button {
                pendingCoverRemovalIndex = index
                showCoverRemovalConfirmation = true
            } label: {
                ZStack {
                    Circle()
                        .fill(.black.opacity(0.35))
                        .frame(width: 28, height: 28)
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("마켓 썸네일 제거")
            .accessibilityIdentifier("upload.cover.remove")
            .padding(2)
        }
    }

    private var coverPreviewImage: UIImage? {
        guard let data = editorDraftStore.editorDraft.coverPhotoData else { return nil }
        return UIImage(data: data)
    }

    @ViewBuilder
    private var signatureSampleSection: some View {
        let hasSample = hasSignatureSample
        VStack(alignment: .leading, spacing: Sp.sm) {
            HStack(alignment: .firstTextBaseline) {
                sectionLabel("시그니처 샘플")
                Spacer()
                if hasSample {
                    Button(role: .destructive) {
                        editorDraftStore.clearUploadSignatureSample()
                    } label: {
                        Label("지우기", systemImage: "trash")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(FMColors.Semantic.error)
                    .accessibilityIdentifier("upload.signature.clear")
                }
            }

            HStack(alignment: .top, spacing: Sp.sm) {
                signaturePreview

                VStack(alignment: .leading, spacing: Sp.sm) {
                    PhotosPicker(selection: $selectedSignatureItem, matching: .images) {
                        Label(hasSample ? "사진 교체" : "내 사진 선택", systemImage: "photo.badge.plus")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(FMColors.Accent.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .accessibilityIdentifier("upload.signature.photo.pick")

                    DisclosureGroup {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: Sp.xs)], alignment: .leading, spacing: Sp.xs) {
                            ForEach(EditorReferenceSampleKind.allCases) { kind in
                                FMChip(
                                    kind.title,
                                    isSelected: editorDraftStore.editorDraft.signatureSampleKind == kind
                                        && editorDraftStore.editorDraft.signatureSamplePhotoData == nil,
                                    size: .sm
                                ) {
                                    editorDraftStore.setUploadSignatureSampleKind(kind)
                                }
                                .accessibilityIdentifier("upload.signature.sample.\(kind.rawValue)")
                            }
                        }
                        .padding(.top, Sp.xs)
                    } label: {
                        Label("빠르게 시작하기", systemImage: "sparkles")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(FMColors.Text.secondary)
                    }
                    .tint(FMColors.Text.secondary)

                    Text("마켓 썸네일은 정사각형 대표 이미지 1장이고, 시그니처 샘플은 상세 갤러리 첫 슬롯 비율로 보여줍니다.")
                        .fmTypography(.caption)
                        .foregroundStyle(FMColors.Text.tertiary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let signatureLoadError {
                        Text(signatureLoadError)
                            .fmTypography(.caption)
                            .foregroundStyle(FMColors.Semantic.error)
                    }
                }
            }
            .padding(Sp.md)
            .background(FMColors.Background.bg2, in: RoundedRectangle(cornerRadius: R.md))
        }
    }

    private var beforeAfterToggle: some View {
        VStack(alignment: .leading, spacing: Sp.xs) {
            Toggle("자동 비포/애프터 생성", isOn: Binding(
                get: { editorDraftStore.editorDraft.beforeAfterEnabled },
                set: { value in
                    editorDraftStore.updateEditorDraft { draft in
                        draft.beforeAfterEnabled = value
                    }
                }
            ))
            .tint(FMColors.Accent.primary)

            Text("최근 편집과 원본을 비교한 슬라이드를 자동으로 만들어 갤러리에 추가합니다.")
                .fmTypography(.caption)
                .foregroundStyle(FMColors.Text.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Sp.md)
        .background(FMColors.Background.bg2, in: RoundedRectangle(cornerRadius: R.md))
        .accessibilityIdentifier("upload.cover.ba.toggle")
    }

    private var nextActionBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(FMColors.Border.subtle)
                .frame(height: 0.5)
            NavigationLink(value: AppRoute.uploadTags) {
                routeButton("다음", icon: "arrow.right")
            }
            .simultaneousGesture(TapGesture().onEnded {
                editorDraftStore.saveCurrentUploadDraftIfNeeded()
            })
            .buttonStyle(.plain)
            .accessibilityIdentifier("upload.next")
            .padding(.horizontal, Sp.md)
            .padding(.vertical, Sp.sm)
        }
        .background(FMColors.Background.bg1)
    }

    private var hasSignatureSample: Bool {
        let draft = editorDraftStore.editorDraft
        return draft.signatureSamplePhotoData != nil || draft.signatureSampleKind != nil
    }

    private var signaturePreview: some View {
        ZStack {
            if let image = signaturePreviewImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                LinearGradient(
                    colors: editorDraftStore.editorDraft.category.swatch,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .frame(width: 96, height: 128)
        .clipShape(RoundedRectangle(cornerRadius: R.md))
        .overlay {
            RoundedRectangle(cornerRadius: R.md)
                .strokeBorder(FMColors.Border.subtle, lineWidth: 1)
        }
        .accessibilityIdentifier("upload.signature.preview")
    }

    private var signaturePreviewImage: UIImage? {
        let draft = editorDraftStore.editorDraft
        if let data = draft.signatureSamplePhotoData { return UIImage(data: data) }
        if let kind = draft.signatureSampleKind { return UIImage(data: EditorReferenceSampleImage.makeJPEGData(kind: kind)) }
        return nil
    }

    @MainActor
    private func loadCoverPhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            guard
                let data = try await item.loadTransferable(type: Data.self),
                let image = UIImage(data: data),
                let normalized = EditorReferenceSampleImage.normalizedJPEGData(from: image)
            else {
                coverLoadError = "사진 데이터를 읽지 못했어요."
                return
            }
            editorDraftStore.setUploadCoverPhotoData(normalized)
            coverLoadError = nil
        } catch {
            coverLoadError = "사진을 불러오지 못했어요."
        }
    }

    @MainActor
    private func loadSignatureSample(from item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            guard
                let data = try await item.loadTransferable(type: Data.self),
                let image = UIImage(data: data),
                let normalized = EditorReferenceSampleImage.normalizedJPEGData(from: image)
            else {
                signatureLoadError = "사진 데이터를 읽지 못했어요."
                return
            }
            editorDraftStore.setUploadSignatureSampleData(normalized)
            signatureLoadError = nil
        } catch {
            signatureLoadError = "사진을 불러오지 못했어요."
        }
    }
}

struct UploadTagsCategoryScreen: View {
    @EnvironmentObject private var editorDraftStore: EditorDraftStore
    @Environment(\.dismiss) private var dismiss
    @State private var pendingTag = ""
    @State private var showCancelAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.lg) {
                uploadProgress(active: .tags)
                tagSection
                categorySection
                descriptionSection
                NavigationLink(value: AppRoute.uploadSubmit) {
                    routeButton("다음", icon: "arrow.right")
                }
                .simultaneousGesture(TapGesture().onEnded {
                    editorDraftStore.saveCurrentUploadDraftIfNeeded()
                })
                .buttonStyle(.plain)
                .accessibilityIdentifier("upload.next")
            }
            .padding(Sp.md)
            .padding(.bottom, FMLayout.tabBarHeight + Sp.xxxl)
        }
        .background(FMColors.Background.bg1)
        .navigationTitle("태그와 카테고리")
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showCancelAlert = true
                } label: {
                    Image(systemName: "xmark")
                }
                .accessibilityLabel("닫기")
                .accessibilityIdentifier("upload.cancel")
            }
        }
        .confirmationDialog("업로드를 취소할까요?", isPresented: $showCancelAlert, titleVisibility: .visible) {
            Button("초안 저장하고 나가기") {
                editorDraftStore.saveCurrentUploadDraftIfNeeded()
                dismiss()
            }
            Button("초안 버리고 나가기", role: .destructive) {
                editorDraftStore.resetEditorDraft()
                dismiss()
            }
            Button("계속 작성", role: .cancel) {}
        } message: {
            Text("작성한 내용을 임시저장하면 다음에 이어 쓸 수 있어요.")
        }
        .onDisappear {
            editorDraftStore.saveCurrentUploadDraftIfNeeded()
        }
        .storeErrorToast(
            message: editorDraftStore.lastSubmitErrorMessage,
            title: "초안 저장 실패"
        ) {
            editorDraftStore.clearLastSubmitError()
        }
    }

    private var tagSection: some View {
        VStack(alignment: .leading, spacing: Sp.sm) {
            sectionLabel("태그")
            FMCard {
                VStack(alignment: .leading, spacing: Sp.sm) {
                    WorkflowFlowLayout(spacing: Sp.xs) {
                        ForEach(editorDraftStore.editorDraft.tags, id: \.self) { tag in
                            Button {
                                editorDraftStore.removeUploadTag(tag)
                            } label: {
                                HStack(spacing: 4) {
                                    Text("#\(tag)")
                                    Image(systemName: "xmark")
                                }
                                .fmTypography(.caption)
                                .foregroundStyle(FMColors.Accent.primary)
                                .padding(.horizontal, Sp.xs)
                                .padding(.vertical, 5)
                                .background(FMColors.Accent.bg, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("upload.tag.remove")
                        }
                    }
                    HStack {
                        TextField("태그 입력", text: $pendingTag)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.next)
                        Button("추가") {
                            editorDraftStore.addUploadTag(pendingTag)
                            pendingTag = ""
                        }
                        .disabled(pendingTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("upload.tag.add")
                    }
                    .padding(Sp.sm)
                    .background(FMColors.Background.bg3, in: RoundedRectangle(cornerRadius: R.md))
                }
            }
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: Sp.sm) {
            sectionLabel("카테고리")
            WorkflowFlowLayout(spacing: Sp.xs) {
                ForEach(FilterCategory.allCases, id: \.rawValue) { category in
                    FMChip(category.displayTitle, isSelected: editorDraftStore.editorDraft.category == category, size: .sm) {
                        editorDraftStore.setUploadCategory(category)
                    }
                    .accessibilityIdentifier("upload.cat.tap.\(category.rawValue)")
                }
            }
            .accessibilityIdentifier("upload.cat.tap")
        }
    }

    private var descriptionSection: some View {
        FMTextField(
            "설명",
            text: Binding(
                get: { editorDraftStore.editorDraft.summary },
                set: { value in
                    editorDraftStore.updateEditorDraft { draft in
                        draft.summary = value
                    }
                }
            ),
            placeholder: "이 필터의 분위기와 추천 사용처",
            style: .multiline(minHeight: 112),
            submitLabel: .return
        )
    }
}

struct UploadTOSSubmitScreen: View {
    @EnvironmentObject private var editorDraftStore: EditorDraftStore
    @Environment(\.dismiss) private var dismiss
    @State private var showCancelAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.lg) {
                uploadProgress(active: .submit)
                workflowHeader(
                    title: "검토 후 제출",
                    subtitle: "마켓 공개 전 표시 정보와 정책 동의를 확인합니다.",
                    symbol: "checkmark.seal"
                )
                summaryCard
                tosCard
                NavigationLink(value: AppRoute.uploadPending) {
                    routeButton("검수 제출", icon: "paperplane.fill")
                }
                .simultaneousGesture(TapGesture().onEnded {
                    editorDraftStore.submitCurrentDraft()
                })
                .buttonStyle(.plain)
                .disabled(!editorDraftStore.editorDraft.isReadyForSubmit)
                .accessibilityIdentifier("upload.submit")
            }
            .padding(Sp.md)
            .padding(.bottom, FMLayout.tabBarHeight + Sp.xxxl)
        }
        .background(FMColors.Background.bg1)
        .navigationTitle("약관 및 제출")
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showCancelAlert = true
                } label: {
                    Image(systemName: "xmark")
                }
                .accessibilityLabel("닫기")
                .accessibilityIdentifier("upload.cancel")
            }
        }
        .confirmationDialog("업로드를 취소할까요?", isPresented: $showCancelAlert, titleVisibility: .visible) {
            Button("초안 저장하고 나가기") {
                editorDraftStore.saveCurrentUploadDraftIfNeeded()
                dismiss()
            }
            Button("초안 버리고 나가기", role: .destructive) {
                editorDraftStore.resetEditorDraft()
                dismiss()
            }
            Button("계속 작성", role: .cancel) {}
        } message: {
            Text("작성한 내용을 임시저장하면 다음에 이어 쓸 수 있어요.")
        }
        .onDisappear {
            editorDraftStore.saveCurrentUploadDraftIfNeeded()
        }
        .storeErrorToast(
            message: editorDraftStore.lastSubmitErrorMessage,
            title: "검수 제출 실패"
        ) {
            editorDraftStore.clearLastSubmitError()
        }
    }

    private var summaryCard: some View {
        FMCard {
            VStack(alignment: .leading, spacing: Sp.sm) {
                sectionLabel("제출 요약")
                makerSummaryRow("이름", value: editorDraftStore.editorDraft.name)
                workflowDivider()
                makerSummaryRow("카테고리", value: editorDraftStore.editorDraft.category.displayTitle)
                workflowDivider()
                makerSummaryRow("커버", value: "\(editorDraftStore.editorDraft.coverCount)장")
                workflowDivider()
                makerSummaryRow("시그니처 샘플", value: signatureSummary)
                workflowDivider()
                makerSummaryRow("태그", value: editorDraftStore.editorDraft.tags.map { "#\($0)" }.joined(separator: " "))
            }
        }
    }

    private var signatureSummary: String {
        let draft = editorDraftStore.editorDraft
        if draft.signatureSamplePhotoData != nil { return "직접 선택" }
        if let kind = draft.signatureSampleKind { return kind.title }
        return "없음"
    }

    private var tosCard: some View {
        FMCard {
            VStack(spacing: 0) {
                Toggle("직접 만들었거나 사용 권한이 있습니다", isOn: Binding(
                    get: { editorDraftStore.editorDraft.tosOriginal },
                    set: { value in
                        editorDraftStore.updateEditorDraft { draft in
                            draft.tosOriginal = value
                        }
                    }
                ))
                    .tint(FMColors.Accent.primary)
                workflowDivider()
                Toggle("마켓 정책과 심사 기준을 확인했습니다", isOn: Binding(
                    get: { editorDraftStore.editorDraft.tosPolicy },
                    set: { value in
                        editorDraftStore.updateEditorDraft { draft in
                            draft.tosPolicy = value
                        }
                    }
                ))
                    .tint(FMColors.Accent.primary)
                workflowDivider()
                Toggle("상업적 배포 권한을 확인했습니다", isOn: Binding(
                    get: { editorDraftStore.editorDraft.tosCommercial },
                    set: { value in
                        editorDraftStore.updateEditorDraft { draft in
                            draft.tosCommercial = value
                        }
                    }
                ))
                    .tint(FMColors.Accent.primary)
            }
            .accessibilityIdentifier("upload.tos.toggle")
        }
    }

}

struct UploadPendingReviewScreen: View {
    @EnvironmentObject private var editorDraftStore: EditorDraftStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: Sp.lg) {
            uploadProgress(active: .pending)

            Spacer()
            Image(systemName: "hourglass.circle.fill")
                .font(.system(size: 64, weight: .semibold))
                .foregroundStyle(FMColors.Accent.primary)
            VStack(spacing: Sp.xs) {
                Text("검수 중입니다")
                    .fmTypography(.titleLarge)
                    .foregroundStyle(FMColors.Text.primary)
                Text("제출한 필터는 보통 24시간 안에 검수됩니다. 상태는 내 필터에서 확인할 수 있습니다.")
                    .fmTypography(.body)
                    .foregroundStyle(FMColors.Text.secondary)
                    .multilineTextAlignment(.center)
            }
            FMCard {
                VStack(alignment: .leading, spacing: Sp.sm) {
                    makerSummaryRow("필터", value: editorDraftStore.editorDraft.name)
                    workflowDivider()
                    makerSummaryRow("상태", value: "검수중")
                    workflowDivider()
                    makerSummaryRow("제출", value: workflowDateString(editorDraftStore.editorDraft.submittedAt ?? Date()))
                }
            }
            NavigationLink(value: AppRoute.myFilters) {
                routeButton("내 필터 보기", icon: "rectangle.stack")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("upload.pending.view_filter")

            FMButton("닫기", variant: .secondary, size: .lg) {
                dismiss()
            }
            .accessibilityIdentifier("upload.pending.dismiss")
            Spacer()
        }
        .padding(Sp.md)
        .background(FMColors.Background.bg1)
        .navigationTitle("검수 대기")
        .navigationBarTitleDisplayMode(.inline)
    }

}

// FilterRejectedScreen — `Sources/App/Moderation/FilterRejectedScreen.swift`

struct MyFiltersScreen: View {
    @EnvironmentObject private var editorDraftStore: EditorDraftStore
    @State private var selectedDraft: MakerFilterDraft?
    @State private var showTakedownAlert = false

    private var visibleFilters: [MakerFilterDraft] {
        let status = editorDraftStore.selectedMakerStatus
        let filters = editorDraftStore.makerFilters
        return status == .all ? filters : filters.filter { $0.status == status }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: Sp.lg) {
                    header
                    statusChips
                    filterList
                }
                .padding(Sp.md)
                .padding(.bottom, FMLayout.tabBarHeight + 96)
            }
            NavigationLink(value: AppRoute.editor) {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 60)
                    .background(FMColors.Accent.primary, in: Circle())
                    .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 6)
            }
            .simultaneousGesture(TapGesture().onEnded {
                editorDraftStore.resetEditorDraft()
            })
            .accessibilityIdentifier("myfilters.fab.create")
            .padding(.trailing, Sp.lg)
            .padding(.bottom, FMLayout.tabBarHeight + Sp.lg)
        }
        .background(FMColors.Background.bg1)
        .navigationTitle("내 필터")
        .navigationBarTitleDisplayMode(.inline)
        .alert("비공개로 전환할까요?", isPresented: $showTakedownAlert) {
            Button("전환", role: .destructive) {
                if let selectedDraft {
                    editorDraftStore.markMakerFilterPrivate(selectedDraft)
                }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("마켓 노출이 중지되고 초안 상태로 돌아갑니다.")
        }
        .storeErrorToast(
            message: editorDraftStore.lastSubmitErrorMessage,
            title: "상태 변경 실패"
        ) {
            editorDraftStore.clearLastSubmitError()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Sp.xs) {
            Text("메이커 필터")
                .fmTypography(.titleLarge)
                .foregroundStyle(FMColors.Text.primary)
            Text("공개, 검수, 반려, 초안을 한 곳에서 관리합니다.")
                .fmTypography(.body)
                .foregroundStyle(FMColors.Text.secondary)
        }
    }

    private var statusChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Sp.xs) {
                ForEach(MakerFilterStatus.allCases) { status in
                    FMChip("\(status.title) \(count(for: status))", isSelected: editorDraftStore.selectedMakerStatus == status, size: .sm) {
                        editorDraftStore.selectedMakerStatus = status
                    }
                    .accessibilityIdentifier("myfilters.status.filter.\(status.rawValue)")
                }
            }
        }
        .accessibilityIdentifier("myfilters.status.filter")
    }

    private var filterList: some View {
        VStack(spacing: Sp.sm) {
            ForEach(visibleFilters) { draft in
                makerFilterRow(draft)
            }
        }
    }

    private func makerFilterRow(_ draft: MakerFilterDraft) -> some View {
        FMCard {
            VStack(alignment: .leading, spacing: Sp.sm) {
                HStack(spacing: Sp.sm) {
                    RoundedRectangle(cornerRadius: R.sm)
                        .fill(LinearGradient(colors: draft.category.swatch, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 58, height: 72)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(draft.name)
                            .fmTypography(.headline)
                            .foregroundStyle(FMColors.Text.primary)
                        Text(workflowDateString(draft.updatedAt))
                            .fmTypography(.caption)
                            .foregroundStyle(FMColors.Text.tertiary)
                        statusBadge(draft.status)
                    }
                    Spacer()
                }

                let isRejected = draft.status == .rejected
                HStack(spacing: Sp.sm) {
                    NavigationLink(value: isRejected ? AppRoute.filterRejected(id: draft.id.uuidString) : AppRoute.editor) {
                        compactRouteButton(isRejected ? "검수 결과" : "수정", icon: isRejected ? "doc.text" : "slider.horizontal.3")
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        editorDraftStore.startEditing(draft)
                    })
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(isRejected ? "mod.rejected.review" : "myfilters.row.edit")

                    Button {
                        selectedDraft = draft
                        showTakedownAlert = true
                    } label: {
                        compactRouteButton("비공개", icon: "eye.slash")
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("myfilters.row.takedown")
                }
            }
        }
        .accessibilityIdentifier("myfilters.row.tap")
    }

    private func statusBadge(_ status: MakerFilterStatus) -> some View {
        Text(status.title)
            .fmTypography(.caption)
            .foregroundStyle(status == .rejected ? FMColors.Semantic.error : FMColors.Accent.primary)
            .padding(.horizontal, Sp.xs)
            .padding(.vertical, 3)
            .background(status == .rejected ? FMColors.Semantic.errorBg : FMColors.Accent.bg, in: Capsule())
    }

    private func count(for status: MakerFilterStatus) -> Int {
        let filters = editorDraftStore.makerFilters
        return status == .all ? filters.count : filters.filter { $0.status == status }.count
    }
}

struct RemixFlowScreen: View {
    @EnvironmentObject private var editorDraftStore: EditorDraftStore
    @EnvironmentObject private var filterLibraryStore: FilterLibraryStore
    @Environment(\.dismiss) private var dismiss

    /// Parent filter — read from the store's currently selected filter so the
    /// remix flow inherits whatever the user was just looking at. Falls back
    /// to the first downloaded filter if nothing is selected (rare in practice
    /// since the entry point is FilterDetail's "리믹스" action).
    private var parent: Filter? {
        filterLibraryStore.selectedFilter ?? filterLibraryStore.libraryFilters.first ?? filterLibraryStore.filters.first
    }

    private var parentName: String {
        parent?.title ?? "원본 필터"
    }

    private var parentMaker: String {
        parent.map { "@" + $0.author.displayName.lowercased() } ?? ""
    }

    private var parentSwatch: [Color] {
        parent?.category.swatch ?? [FMColors.Accent.bg, FMColors.Accent.primary]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Sp.lg) {
            workflowHeader(
                title: "이 필터를 베이스로 새로 만들기",
                subtitle: "원본 메이커 크레딧을 유지한 채 파라미터와 LUT를 조정합니다.",
                symbol: "arrow.triangle.branch"
            )
            FMCard {
                VStack(alignment: .leading, spacing: Sp.sm) {
                    HStack(spacing: Sp.sm) {
                        RoundedRectangle(cornerRadius: R.sm)
                            .fill(LinearGradient(colors: parentSwatch, startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 44, height: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(parentName)
                                .fmTypography(.headline)
                                .foregroundStyle(FMColors.Text.primary)
                                .accessibilityIdentifier("remix.parent.name")
                            if !parentMaker.isEmpty {
                                Text(parentMaker)
                                    .fmTypography(.caption)
                                    .foregroundStyle(FMColors.Text.tertiary)
                                    .accessibilityIdentifier("remix.parent.maker")
                            }
                        }
                        Spacer()
                        FMTag("Remix OK", style: .accent)
                    }
                    workflowDivider()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("리믹스는 새 초안으로 저장되며, 원본 필터의 판매 파일은 복사되지 않습니다.")
                            .fmTypography(.body)
                            .foregroundStyle(FMColors.Text.secondary)
                        Text("저장 시 manifest의 `remix.parentId`에 원본 필터 ID가 기록되어 메이커 크레딧이 유지됩니다.")
                            .fmTypography(.caption)
                            .foregroundStyle(FMColors.Text.tertiary)
                    }
                }
            }
            Spacer()
            HStack(spacing: Sp.sm) {
                FMButton("취소", variant: .secondary, size: .lg) {
                    dismiss()
                }
                .accessibilityIdentifier("editor.remix.cancel")

                NavigationLink(value: AppRoute.editor) {
                    routeButton("에디터 열기", icon: "slider.horizontal.3")
                }
                .simultaneousGesture(TapGesture().onEnded {
                    seedRemixDraft()
                })
                .buttonStyle(.plain)
                .accessibilityIdentifier("editor.remix.open_editor")
            }
        }
        .padding(Sp.md)
        .background(FMColors.Background.bg1)
        .navigationTitle("리믹스")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Pre-populate the editor draft with parent metadata. The draft's name
    /// becomes "<parent> Remix"; tags inherit "remix" + parent category as a
    /// starting point. Parameter values stay at neutral so the user shapes
    /// their own variation.
    private func seedRemixDraft() {
        var seedTags: [String] = ["remix"]
        if let parent {
            seedTags.append(parent.category.rawValue.lowercased())
        }
        editorDraftStore.resetEditorDraft()
        editorDraftStore.updateEditorDraft { draft in
            draft.name = "\(parentName) Remix"
            draft.tags = seedTags
        }
        FMHaptic.light.play()
    }
}

// MARK: - Social / Discovery

// NotificationsInboxScreen — `Sources/App/Notifications/NotificationsInboxScreen.swift`

// MARK: - Maker / Payout

struct MakerDashboardScreen: View {
    @StateObject private var profileStore = ProfileSelfStore()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.lg) {
                if profileStore.myFilters.isEmpty {
                    emptyState
                } else {
                    statsCard
                    filterList
                }
            }
            .padding(Sp.md)
        }
        .background(FMColors.Background.bg1.ignoresSafeArea())
        .navigationTitle("메이커 대시보드")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: AppRoute.editor) {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(FMColors.Text.primary)
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel("필터 만들기")
                .accessibilityIdentifier("dashboard.create")
            }
        }
        .task { profileStore.start() }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: Sp.lg) {
            Spacer().frame(height: Sp.xxxl)
            Image(systemName: "wand.and.stars")
                .font(.system(size: 48))
                .foregroundStyle(FMColors.Accent.primary)
            Text("아직 등록한 필터가 없어요")
                .font(Font.fmTitle)
                .foregroundStyle(FMColors.Text.primary)
            Text("필터를 만들어 마켓에 공유해보세요")
                .font(Font.fmBody)
                .foregroundStyle(FMColors.Text.secondary)
            NavigationLink(value: AppRoute.editor) {
                Text("필터 만들기")
                    .font(Font.fmHeadline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Sp.md)
                    .background(FMColors.Accent.primary)
                    .clipShape(RoundedRectangle(cornerRadius: R.lg))
            }
            .accessibilityIdentifier("maker.dashboard.create")
            .padding(.top, Sp.md)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var statsCard: some View {
        let totalDownloads = profileStore.myFilters.reduce(0) { $0 + $1.downloadCount }
        let totalUseCount = profileStore.myFilters.reduce(0) { $0 + $1.useCount }
        VStack(alignment: .leading, spacing: Sp.sm) {
            Text("통계")
                .font(Font.fmCaption)
                .foregroundStyle(FMColors.Text.secondary)
            HStack(spacing: Sp.md) {
                statTile(value: "\(profileStore.myFilters.count)", label: "필터")
                statTile(value: totalDownloads.formatted(), label: "다운로드")
                statTile(value: totalUseCount.formatted(), label: "사용")
            }
        }
        .padding(Sp.md)
        .background(FMColors.Background.bg2)
        .clipShape(RoundedRectangle(cornerRadius: R.lg))
    }

    @ViewBuilder
    private func statTile(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Font.fmTitle)
                .foregroundStyle(FMColors.Text.primary)
                .monospacedDigit()
            Text(label)
                .font(Font.fmCaption)
                .foregroundStyle(FMColors.Text.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var filterList: some View {
        VStack(alignment: .leading, spacing: Sp.sm) {
            Text("내 필터")
                .font(Font.fmCaption)
                .foregroundStyle(FMColors.Text.secondary)
            VStack(spacing: 0) {
                ForEach(Array(profileStore.myFilters.enumerated()), id: \.element.id) { index, filter in
                    NavigationLink(value: AppRoute.filterDetail(id: filter.id.uuidString)) {
                        HStack(spacing: Sp.md) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(filter.title).font(Font.fmBody).foregroundStyle(FMColors.Text.primary)
                                Text("\(filter.status.rawValue) · 다운로드 \(filter.downloadCount.formatted())")
                                    .font(Font.fmCaption)
                                    .foregroundStyle(FMColors.Text.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(FMColors.Text.tertiary)
                        }
                        .padding(Sp.md)
                    }
                    .buttonStyle(.plain)
                    if index < profileStore.myFilters.count - 1 {
                        Rectangle()
                            .fill(FMColors.Border.subtle)
                            .frame(height: 0.5)
                            .padding(.leading, Sp.md)
                    }
                }
            }
            .background(FMColors.Background.bg2)
            .clipShape(RoundedRectangle(cornerRadius: R.lg))
        }
    }
}

// MARK: - Payout placeholders (Phase 6+ — see ADR-0006)
//
// Closed-loop virtual currency 모델 채택 (ADR-0006). Phase 1~5에서 메이커는
// moodit 안에서만 소비 가능한 코인으로 정산받고, 원화 출금은 미지원.
// 본 화면들은 deep-link 도착 시에도 일관된 UX를 위해 placeholder로 유지.

struct PayoutOnboardingScreen: View {
    var body: some View { closedLoopPayoutPlaceholder(title: "정산 연결") }
}

struct PayoutTaxInfoScreen: View {
    var body: some View { closedLoopPayoutPlaceholder(title: "세금 정보") }
}

struct PayoutHistoryScreen: View {
    var body: some View { closedLoopPayoutPlaceholder(title: "정산 내역") }
}

struct EarningsWithdrawScreen: View {
    var body: some View { closedLoopPayoutPlaceholder(title: "출금 신청") }
}
