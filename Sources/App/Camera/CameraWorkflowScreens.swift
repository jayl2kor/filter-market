import Camera
import DesignSystem
import FilterEngine
import Marketplace
import Models
import Photos
import PhotosUI
import SwiftUI
import UIKit

struct CameraAspectPickerScreen: View {
    @EnvironmentObject private var filterLibraryStore: FilterLibraryStore
    @EnvironmentObject private var cameraStateStore: CameraStateStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.lg) {
                workflowHeader(
                    title: "촬영 비율",
                    subtitle: "카메라 프레임과 촬영 후 저장 비율을 선택합니다.",
                    symbol: "aspectratio"
                )

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Sp.sm) {
                    ForEach(PhotoCropAspectRatio.allCases) { ratio in
                        Button {
                            FMHaptic.selection.play()
                            cameraStateStore.aspectRatio = ratio
                        } label: {
                            VStack(alignment: .leading, spacing: Sp.sm) {
                                aspectPreview(ratio)
                                Text(ratio.label)
                                    .fmTypography(.headline)
                                    .foregroundStyle(FMColors.Text.primary)
                                Text(aspectDescription(ratio))
                                    .fmTypography(.caption)
                                    .foregroundStyle(FMColors.Text.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(Sp.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(FMColors.Background.bg2, in: RoundedRectangle(cornerRadius: R.lg))
                            .overlay {
                                RoundedRectangle(cornerRadius: R.lg)
                                    .strokeBorder(
                                        cameraStateStore.aspectRatio == ratio ? FMColors.Accent.primary : FMColors.Border.subtle,
                                        lineWidth: cameraStateStore.aspectRatio == ratio ? 2 : 1
                                    )
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("cam.aspect.set.\(aspectIdentifier(ratio))")
                    }
                }
            }
            .padding(Sp.md)
            .padding(.bottom, FMLayout.tabBarHeight + Sp.xxxl)
        }
        .background(FMColors.Background.bg1)
        .navigationTitle("촬영 비율")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func aspectPreview(_ ratio: PhotoCropAspectRatio) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: R.md)
                .fill(FMColors.Background.bg3)
                .frame(height: 104)
            RoundedRectangle(cornerRadius: 2)
                .stroke(FMColors.Accent.primary, lineWidth: 2)
                .aspectRatio(previewAspect(ratio), contentMode: .fit)
                .frame(width: 116, height: 88)
        }
    }

    private func previewAspect(_ ratio: PhotoCropAspectRatio) -> CGFloat {
        switch ratio {
        case .square: 1
        case .fourFive: 4.0 / 5.0
        case .fourThree: 4.0 / 3.0
        case .sixteenNine: 16.0 / 9.0
        }
    }

    private func aspectDescription(_ ratio: PhotoCropAspectRatio) -> String {
        switch ratio {
        case .square: "프로필과 컬렉션 커버에 적합"
        case .fourFive: "세로 피드와 인물 사진에 적합"
        case .fourThree: "기본 카메라 사진에 적합"
        case .sixteenNine: "스토리와 가로 장면에 적합"
        }
    }

    private func aspectIdentifier(_ ratio: PhotoCropAspectRatio) -> String {
        switch ratio {
        case .square: "1_1"
        case .fourFive: "4_5"
        case .fourThree: "4_3"
        case .sixteenNine: "16_9"
        }
    }
}

struct CameraTimerCountdownScreen: View {
    @EnvironmentObject private var filterLibraryStore: FilterLibraryStore
    @EnvironmentObject private var cameraStateStore: CameraStateStore
    @State private var previewValue: Int?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.lg) {
                workflowHeader(
                    title: "타이머",
                    subtitle: "셔터를 누른 뒤 촬영까지의 지연 시간을 설정합니다.",
                    symbol: "timer"
                )

                FMCard {
                    VStack(spacing: 0) {
                        ForEach(CameraTimerOption.allCases) { option in
                            Button {
                                FMHaptic.selection.play()
                                cameraStateStore.timerOption = option
                                previewValue = option.rawValue == 0 ? nil : option.rawValue
                            } label: {
                                HStack(spacing: Sp.sm) {
                                    Image(systemName: option == .off ? "timer" : "\(option.rawValue).circle")
                                        .font(.system(size: IconSize.md, weight: .semibold))
                                        .foregroundStyle(FMColors.Accent.primary)
                                        .frame(width: 28, height: 28)
                                    Text(option.label)
                                        .fmTypography(.body)
                                        .foregroundStyle(FMColors.Text.primary)
                                    Spacer()
                                    if option == cameraStateStore.timerOption {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(FMColors.Accent.primary)
                                    }
                                }
                                .frame(minHeight: 54)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier(option == .off ? "cam.timer.set.off" : "cam.timer.set.\(option.rawValue)")
                        }
                    }
                }

                if let previewValue {
                    FMCard {
                        HStack(spacing: Sp.md) {
                            Text("\(previewValue)")
                                .font(.system(size: 46, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(FMColors.Accent.primary)
                                .frame(width: 72)
                            VStack(alignment: .leading, spacing: Sp.xxs) {
                                Text("카운트다운 미리보기")
                                    .fmTypography(.headline)
                                    .foregroundStyle(FMColors.Text.primary)
                                Text("카메라에서 셔터를 누르면 이 숫자부터 촬영까지 카운트다운합니다.")
                                    .fmTypography(.subhead)
                                    .foregroundStyle(FMColors.Text.secondary)
                            }
                        }
                    }
                }
            }
            .padding(Sp.md)
            .padding(.bottom, FMLayout.tabBarHeight + Sp.xxxl)
        }
        .background(FMColors.Background.bg1)
        .navigationTitle("타이머")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PhotoImportScreen: View {
    @EnvironmentObject private var filterLibraryStore: FilterLibraryStore
    @EnvironmentObject private var cameraStateStore: CameraStateStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var loadError: String?
    @State private var photoLibraryStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @State private var visibleImageCount: Int?

    var body: some View {
        let hasSelectedImage = selectedImage != nil

        ScrollView {
            VStack(alignment: .leading, spacing: Sp.lg) {
                workflowHeader(
                    title: "사진 가져오기",
                    subtitle: "앨범에서 사진을 선택해 moodit 필터를 적용합니다.",
                    symbol: "photo.on.rectangle"
                )

                photoLibraryAccessNotice

                selectedPreview

                PhotosPicker(selection: $selectedItem, matching: .images) {
                    HStack(spacing: Sp.xs) {
                        Image(systemName: "photo.badge.plus")
                        Text(hasSelectedImage ? "다른 사진 선택" : "사진 선택")
                            .font(.headline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(FMColors.Accent.primary, in: RoundedRectangle(cornerRadius: R.md))
                }
                .accessibilityIdentifier("photo.import.cell.tap")
                .accessibilityLabel(hasSelectedImage ? "다른 사진 선택" : "사진 선택")
                .accessibilityHint("한 번에 한 장만 선택합니다.")

                if hasSelectedImage {
                    NavigationLink(value: AppRoute.photoEdit) {
                        routeButton("필터 적용", icon: "wand.and.stars")
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("photo.import.next")
                }

                if let loadError {
                    Text(loadError)
                        .fmTypography(.subhead)
                        .foregroundStyle(FMColors.Semantic.error)
                }
            }
            .padding(Sp.md)
            .padding(.bottom, FMLayout.tabBarHeight + Sp.xxxl)
        }
        .background(FMColors.Background.bg1)
        .navigationTitle("사진 가져오기")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedItem) { _, newItem in
            Task { await loadPhoto(from: newItem) }
        }
        .onAppear(perform: refreshPhotoLibraryState)
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            refreshPhotoLibraryState()
        }
    }

    @ViewBuilder
    private var photoLibraryAccessNotice: some View {
        if photoLibraryStatus == .limited {
            FMCard {
                VStack(alignment: .leading, spacing: Sp.sm) {
                    HStack(spacing: Sp.sm) {
                        Image(systemName: "person.crop.rectangle.stack")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(FMColors.Accent.primary)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: Sp.xxs) {
                            Text("선택한 사진만 보여요")
                                .fmTypography(.headline)
                                .foregroundStyle(FMColors.Text.primary)
                            Text(limitedLibraryMessage)
                                .fmTypography(.subhead)
                                .foregroundStyle(FMColors.Text.secondary)
                        }
                    }

                    Button {
                        presentLimitedLibraryPicker()
                    } label: {
                        Label("사진 더 선택", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .accessibilityIdentifier("photo.import.limited.manage")
                    .accessibilityHint("iOS 사진 선택 관리 화면을 엽니다.")
                }
            }
        } else if photoLibraryStatus == .authorized, visibleImageCount == 0 {
            FMCard {
                VStack(alignment: .leading, spacing: Sp.sm) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(FMColors.Text.tertiary)
                        .accessibilityHidden(true)
                    Text("가져올 수 있는 사진이 없어요")
                        .fmTypography(.headline)
                        .foregroundStyle(FMColors.Text.primary)
                    Text("사진 앱에 이미지를 추가한 뒤 다시 시도하거나 카메라로 새 사진을 촬영해 주세요.")
                        .fmTypography(.subhead)
                        .foregroundStyle(FMColors.Text.secondary)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var limitedLibraryMessage: String {
        if let visibleImageCount {
            return "현재 moodit에서 볼 수 있는 사진은 \(visibleImageCount)장입니다. 더 추가하려면 사진 더 선택을 눌러 주세요."
        }
        return "더 추가하려면 사진 더 선택을 눌러 주세요."
    }

    @ViewBuilder
    private var selectedPreview: some View {
        if let selectedImage {
            Image(uiImage: selectedImage)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 360)
                .clipShape(RoundedRectangle(cornerRadius: R.lg))
                .overlay {
                    RoundedRectangle(cornerRadius: R.lg)
                        .strokeBorder(FMColors.Border.subtle, lineWidth: 1)
                }
                .accessibilityLabel("선택한 가져오기 사진 미리보기")
                .accessibilityHint("필터 적용 버튼으로 후보정 화면으로 이동할 수 있습니다.")
        } else {
            FMCard {
                VStack(alignment: .leading, spacing: Sp.sm) {
                    Image(systemName: "photo")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(FMColors.Text.tertiary)
                    Text("아직 선택한 사진이 없어요")
                        .fmTypography(.headline)
                        .foregroundStyle(FMColors.Text.primary)
                    Text("사진을 선택하면 후보정 화면에서 필터, 강도, 저장/공유를 조정할 수 있습니다.")
                        .fmTypography(.body)
                        .foregroundStyle(FMColors.Text.secondary)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func refreshPhotoLibraryState() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        photoLibraryStatus = status

        guard status == .authorized || status == .limited else {
            visibleImageCount = nil
            return
        }

        let options = PHFetchOptions()
        options.includeHiddenAssets = false
        visibleImageCount = PHAsset.fetchAssets(with: .image, options: options).count
    }

    private func presentLimitedLibraryPicker() {
        guard let viewController = UIApplication.shared.fmActiveTopViewController() else { return }
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: viewController)
    }

    @MainActor
    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                loadError = "사진 데이터를 읽지 못했어요."
                return
            }
            selectedImage = image
            cameraStateStore.setImportedPhotoData(data)
            loadError = nil
            FMHaptic.success.play()
        } catch {
            loadError = "사진을 불러오지 못했어요."
            FMHaptic.error.play()
        }
    }
}

private extension UIApplication {
    func fmActiveTopViewController() -> UIViewController? {
        let rootViewController = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .windows
            .first { $0.isKeyWindow }?
            .rootViewController

        return rootViewController?.fmTopPresentedViewController()
    }
}

private extension UIViewController {
    func fmTopPresentedViewController() -> UIViewController {
        if let navigationController = self as? UINavigationController,
           let visibleViewController = navigationController.visibleViewController {
            return visibleViewController.fmTopPresentedViewController()
        }

        if let tabBarController = self as? UITabBarController,
           let selectedViewController = tabBarController.selectedViewController {
            return selectedViewController.fmTopPresentedViewController()
        }

        if let presentedViewController {
            return presentedViewController.fmTopPresentedViewController()
        }

        return self
    }
}

struct PhotoEditScreen: View {
    @EnvironmentObject private var filterLibraryStore: FilterLibraryStore
    @EnvironmentObject private var cameraStateStore: CameraStateStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var intensity: Double = 0.65
    @State private var selectedFilterID: Filter.ID?
    @State private var renderedImage: UIImage?
    @State private var isRendering = false
    @State private var showShareSheet = false
    @State private var saveMessage: String?
    @State private var undoStack: [PhotoEditState] = []
    @State private var redoStack: [PhotoEditState] = []
    @State private var initialEditState: PhotoEditState?
    @State private var showResetConfirmation = false
    @State private var isShowingOriginal = false

    private let renderer = PhotoFilterRenderer(lutResourceBundle: MarketplaceResources.bundle)
    private let saver: any PhotoLibrarySaving = PhotoLibrarySaver.live()

    private var selectedFilter: Filter? {
        if let selectedFilterID,
           let filter = filterLibraryStore.filters.first(where: { $0.id == selectedFilterID }) {
            return filter
        }
        return filterLibraryStore.selectedFilter ?? filterLibraryStore.filters.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.lg) {
                workflowHeader(
                    title: "사진 편집",
                    subtitle: "선택한 사진에 필터를 적용하고 저장 또는 공유합니다.",
                    symbol: "slider.horizontal.3"
                )

                preview
                filterStrip
                intensityControl
                actionButtons

                if let saveMessage {
                    Text(saveMessage)
                        .fmTypography(.subhead)
                        .foregroundStyle(FMColors.Text.secondary)
                }
            }
            .padding(Sp.md)
            .padding(.bottom, FMLayout.tabBarHeight + Sp.xxxl)
        }
        .background(FMColors.Background.bg1)
        .navigationTitle("사진 편집")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarLeading) {
                Button {
                    undoEdit()
                } label: {
                    Label("되돌리기", systemImage: "arrow.uturn.backward")
                        .labelStyle(.iconOnly)
                }
                .disabled(undoStack.isEmpty)
                .accessibilityIdentifier("photo.edit.undo")

                Button {
                    redoEdit()
                } label: {
                    Label("다시 실행", systemImage: "arrow.uturn.forward")
                        .labelStyle(.iconOnly)
                }
                .disabled(redoStack.isEmpty)
                .accessibilityIdentifier("photo.edit.redo")
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button("초기화", role: .destructive) {
                    showResetConfirmation = true
                }
                .disabled(!hasUnsavedEdits)
                .accessibilityIdentifier("photo.edit.reset")
            }
        }
        .task {
            await filterLibraryStore.load()
            selectedFilterID = filterLibraryStore.selectedFilter?.id ?? filterLibraryStore.filters.first?.id
            initialEditState = currentEditState
            await render()
        }
        .onChange(of: selectedFilterID) { _, _ in Task { await render() } }
        .onChange(of: intensity) { _, _ in Task { await render() } }
        .confirmationDialog(
            "편집을 초기화할까요?",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("초기화", role: .destructive) {
                resetEdits()
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("필터와 강도 변경 사항을 처음 상태로 되돌립니다.")
        }
        .fmShareSheet(isPresented: $showShareSheet, items: shareItems)
        .accessibilityAction(named: "되돌리기") { undoEdit() }
        .accessibilityAction(named: "다시 실행") { redoEdit() }
        .accessibilityAction(named: "초기화") { showResetConfirmation = true }
    }

    private var preview: some View {
        ZStack(alignment: .topLeading) {
            if isShowingOriginal, let image = UIImage(data: sourcePhotoData()) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            } else if let renderedImage {
                Image(uiImage: renderedImage)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            } else if let image = UIImage(data: sourcePhotoData()) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .opacity(0.8)
            } else {
                LinearGradient(
                    colors: [FMColors.Category.cinematic.opacity(0.5), .black.opacity(0.58)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            if isRendering {
                ProgressView()
                    .tint(FMColors.Accent.primary)
                    .padding(Sp.md)
                    .background(.regularMaterial, in: Capsule())
            }

            if isShowingOriginal {
                Text("원본")
                    .fmTypography(.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Sp.sm)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.62), in: Capsule())
                    .padding(Sp.sm)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 420)
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
                guard isShowingOriginal != isPressing else { return }
                FMHaptic.light.play()
                withAnimation(reduceMotion ? nil : .fmFast) {
                    isShowingOriginal = isPressing
                }
            }
        )
        .accessibilityIdentifier("photo.edit.compare.hold")
        .accessibilityLabel(isShowingOriginal ? "원본 사진" : "필터 적용 미리보기")
        .accessibilityHint("누르고 있는 동안 원본 사진을 봅니다")
    }

    private var filterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Sp.xs) {
                ForEach(filterLibraryStore.filters) { filter in
                    let isSelected = selectedFilter?.id == filter.id
                    Button {
                        FMHaptic.selection.play()
                        applyUserEdit {
                            selectedFilterID = filter.id
                        }
                    } label: {
                        VStack(spacing: 6) {
                            FilterThumbnail(filter: filter)
                                .frame(width: 64, height: 64)
                                .overlay {
                                    RoundedRectangle(cornerRadius: R.md)
                                        .strokeBorder(isSelected ? FMColors.Accent.primary : FMColors.Border.subtle, lineWidth: isSelected ? 2 : 1)
                                }
                            Text(filter.title)
                                .font(.system(size: 10, weight: .semibold))
                                .lineLimit(1)
                                .foregroundStyle(isSelected ? FMColors.Accent.primary : FMColors.Text.secondary)
                                .frame(width: 76)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("photo.edit.filter.\(filter.id.uuidString)")
                }
            }
            .padding(.vertical, Sp.xs)
        }
    }

    private var intensityControl: some View {
        FMCard {
            VStack(alignment: .leading, spacing: Sp.sm) {
                HStack {
                    Text("강도")
                        .fmTypography(.headline)
                        .foregroundStyle(FMColors.Text.primary)
                    Spacer()
                    Text("\(Int((intensity * 100).rounded()))%")
                        .fmTypography(.subhead)
                        .foregroundStyle(FMColors.Accent.primary)
                        .monospacedDigit()
                }
                FMSlider(
                    value: Binding(
                        get: { intensity },
                        set: { newValue in
                            applyUserEdit {
                                intensity = newValue
                            }
                        }
                    )
                )
                    .accessibilityIdentifier("photo.edit.intensity")
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: Sp.sm) {
            FMButton("저장", icon: "square.and.arrow.down", variant: .primary, size: .lg) {
                Task { await save() }
            }
            .accessibilityIdentifier("photo.edit.done")

            FMButton("공유", icon: "square.and.arrow.up", variant: .secondary, size: .lg) {
                showShareSheet = true
            }
            .accessibilityIdentifier("photo.edit.save_share")
        }
    }

    private var shareItems: [Any] {
        if let renderedImage { return [renderedImage] }
        return [sourcePhotoData()]
    }

    private var currentEditState: PhotoEditState {
        PhotoEditState(
            filterID: selectedFilterID ?? filterLibraryStore.selectedFilter?.id ?? filterLibraryStore.filters.first?.id,
            intensity: intensity
        )
    }

    private var hasUnsavedEdits: Bool {
        guard let initialEditState else { return false }
        return currentEditState.normalized != initialEditState.normalized
    }

    private func applyUserEdit(_ update: () -> Void) {
        let before = currentEditState.normalized
        update()
        let after = currentEditState.normalized
        guard before != after else { return }
        undoStack.append(before)
        redoStack.removeAll()
        saveMessage = nil
    }

    private func undoEdit() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(currentEditState.normalized)
        applyEditState(previous)
        FMHaptic.selection.play()
    }

    private func redoEdit() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(currentEditState.normalized)
        applyEditState(next)
        FMHaptic.selection.play()
    }

    private func resetEdits() {
        let target = initialEditState?.normalized ?? PhotoEditState(
            filterID: filterLibraryStore.selectedFilter?.id ?? filterLibraryStore.filters.first?.id,
            intensity: 0.65
        ).normalized
        let before = currentEditState.normalized
        guard before != target else { return }
        undoStack.append(before)
        redoStack.removeAll()
        applyEditState(target)
        saveMessage = nil
        FMHaptic.warning.play()
    }

    private func applyEditState(_ state: PhotoEditState) {
        withAnimation(reduceMotion ? nil : .fmFast) {
            selectedFilterID = state.filterID
            intensity = state.intensity
        }
    }

    @MainActor
    private func render() async {
        guard let selectedFilter else { return }
        isRendering = true
        defer { isRendering = false }
        do {
            let renderFilter = RenderFilter(
                id: selectedFilter.id,
                title: selectedFilter.title,
                lutFile: selectedFilter.engine.lutFile,
                lutSize: selectedFilter.engine.lutSize ?? 33,
                fallbackPreset: LUTPreset.preset(for: selectedFilter.category)
            )
            let configuration = FilterRenderConfiguration(
                filter: renderFilter,
                intensityValue: Float(intensity)
            )
            let filtered = try renderer.apply(
                to: sourcePhotoData(),
                configuration: configuration,
                cropAspectRatio: cameraStateStore.aspectRatio
            )
            renderedImage = UIImage(data: filtered.filteredData)
        } catch {
            renderedImage = UIImage(data: sourcePhotoData())
        }
    }

    @MainActor
    private func save() async {
        let data: Data
        if let renderedImage, let jpeg = renderedImage.jpegData(compressionQuality: 0.92) {
            data = jpeg
        } else {
            data = sourcePhotoData()
        }
        let result = await saver.savePhoto(data: data)
        switch result {
        case .saved:
            saveMessage = "사진을 저장했어요."
            FMHaptic.success.play()
        default:
            saveMessage = "사진을 저장하지 못했어요. 사진 권한을 확인해 주세요."
            FMHaptic.error.play()
        }
    }

    private func sourcePhotoData() -> Data {
        cameraStateStore.importedPhotoData ?? PlaceholderPhoto.makeJPEGData()
    }
}

private struct PhotoEditState: Equatable {
    var filterID: Filter.ID?
    var intensity: Double

    var normalized: PhotoEditState {
        PhotoEditState(
            filterID: filterID,
            intensity: (intensity * 100).rounded() / 100
        )
    }
}
