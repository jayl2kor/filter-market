import Camera
import DesignSystem
import FilterEngine
import Marketplace
import Models
import PhotosUI
import SwiftUI
import UIKit

// MARK: - Camera / Download

struct FilterDownloadProgressScreen: View {
    let filterID: String

    @EnvironmentObject private var store: MooditStore
    @State private var phase: DownloadPhase = .preparing
    @State private var progress: Double = 0
    @State private var hasStarted = false

    private var filter: Filter? {
        store.filter(matching: filterID) ?? store.filters.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.lg) {
                header
                progressCard
                metadataCard
                actionCard
            }
            .padding(Sp.md)
            .padding(.bottom, FMLayout.tabBarHeight + Sp.xxxl)
        }
        .background(FMColors.Background.bg1)
        .navigationTitle("다운로드")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await startDownloadIfNeeded()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Sp.xs) {
            Text(filterID)
                .fmTypography(.titleLarge)
                .foregroundStyle(FMColors.Text.primary)
            Text(phase.description)
                .fmTypography(.body)
                .foregroundStyle(FMColors.Text.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var progressCard: some View {
        FMCard {
            VStack(alignment: .leading, spacing: Sp.md) {
                HStack(spacing: Sp.md) {
                    statusIcon

                    VStack(alignment: .leading, spacing: 2) {
                        Text(phase.title)
                            .fmTypography(.headline)
                            .foregroundStyle(FMColors.Text.primary)
                        Text("\(Int(progress * 100))%")
                            .fmTypography(.caption)
                            .foregroundStyle(FMColors.Text.secondary)
                            .monospacedDigit()
                    }

                    Spacer()
                }

                ProgressView(value: progress)
                    .tint(FMColors.Accent.primary)
                    .accessibilityLabel("다운로드 진행률")
                    .accessibilityValue("\(Int(progress * 100))퍼센트")
            }
        }
    }

    private var statusIcon: some View {
        Image(systemName: phase.systemImage)
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(FMColors.Accent.primary)
            .frame(width: 52, height: 52)
            .background(FMColors.Accent.bg, in: RoundedRectangle(cornerRadius: R.lg))
            .overlay {
                RoundedRectangle(cornerRadius: R.lg)
                    .strokeBorder(FMColors.Accent.primary.opacity(0.22), lineWidth: 1)
            }
    }

    private var metadataCard: some View {
        FMCard {
            if let filter {
                HStack(spacing: Sp.md) {
                    FilterThumbnail(filter: filter)
                        .frame(width: 72, height: 72)
                    VStack(alignment: .leading, spacing: Sp.xxs) {
                        Text(filter.title)
                            .fmTypography(.headline)
                            .foregroundStyle(FMColors.Text.primary)
                        Text(filter.author.displayName)
                            .fmTypography(.subhead)
                            .foregroundStyle(FMColors.Text.secondary)
                        Text(filter.category.displayTitle)
                            .fmTypography(.caption)
                            .foregroundStyle(FMColors.Text.tertiary)
                    }
                    Spacer()
                }
            } else {
                Text("필터 정보를 불러오지 못했어요.")
                    .fmTypography(.body)
                    .foregroundStyle(FMColors.Text.secondary)
            }
        }
    }

    private var actionCard: some View {
        FMCard {
            VStack(alignment: .leading, spacing: Sp.sm) {
                if phase == .completed {
                    NavigationLink(value: AppRoute.filterAfterDownload(id: filterID)) {
                        routeButtonLabel("다음", icon: "checkmark.circle.fill")
                            .accessibilityIdentifier("filter.download.completed.next")
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("filter.download.completed.next")
                } else if phase == .failed {
                    FMButton("다시 시도", icon: "arrow.clockwise", variant: .primary, size: .lg) {
                        Task { await retryDownload() }
                    }
                    .accessibilityIdentifier("filter.download.retry")
                } else {
                    Text("필터 패키지와 LUT 리소스를 저장하는 중입니다.")
                        .fmTypography(.body)
                        .foregroundStyle(FMColors.Text.secondary)
                }
            }
        }
    }

    private func routeButtonLabel(_ title: String, icon: String) -> some View {
        HStack(spacing: Sp.xs) {
            Image(systemName: icon)
            Text(title)
                .fmTypography(.headline)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, Sp.md)
        .frame(height: 52)
        .background(FMColors.Accent.primary, in: RoundedRectangle(cornerRadius: R.md))
    }

    @MainActor
    private func startDownloadIfNeeded() async {
        guard !hasStarted else { return }
        hasStarted = true
        await store.load()
        await runDownload()
    }

    @MainActor
    private func retryDownload() async {
        phase = .preparing
        progress = 0
        await runDownload()
    }

    @MainActor
    private func runDownload() async {
        guard let filter else {
            phase = .failed
            return
        }
        if store.isDownloaded(filter) {
            progress = 1
            phase = .completed
            return
        }
        phase = .downloading
        for step in 1...6 {
            try? await Task.sleep(nanoseconds: 130_000_000)
            progress = Double(step) / 6
        }
        store.download(filter)
        FMHaptic.success.play()
        phase = .completed
    }
}

struct FilterAfterDownloadScreen: View {
    let filterID: String

    @EnvironmentObject private var store: MooditStore
    @State private var isCameraPresented = false
    @State private var showRemoveAlert = false

    private var filter: Filter? {
        store.filter(matching: filterID) ?? store.filters.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.lg) {
                successHeader
                filterCard
                actionList
            }
            .padding(Sp.md)
            .padding(.bottom, FMLayout.tabBarHeight + Sp.xxxl)
        }
        .background(FMColors.Background.bg1)
        .navigationTitle("다운로드 완료")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await store.load()
        }
        .fullScreenCover(isPresented: $isCameraPresented) {
            CameraScreen(isPresentedAsCover: true)
                .environmentObject(store)
        }
        .fmDestructiveAlert(
            "필터를 제거할까요?",
            message: "저장됨 탭에서 사라지지만 언제든 다시 다운로드할 수 있어요.",
            destructiveTitle: "제거",
            isPresented: $showRemoveAlert
        ) {
            if let filter {
                store.removeDownload(filter)
            }
        }
    }

    private var successHeader: some View {
        VStack(alignment: .leading, spacing: Sp.xs) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(FMColors.Accent.primary)
            Text("필터가 저장됐어요")
                .fmTypography(.titleLarge)
                .foregroundStyle(FMColors.Text.primary)
            Text("카메라로 바로 적용하거나 저장됨 탭에서 다시 열 수 있습니다.")
                .fmTypography(.body)
                .foregroundStyle(FMColors.Text.secondary)
        }
    }

    private var filterCard: some View {
        FMCard {
            if let filter {
                HStack(spacing: Sp.md) {
                    FilterThumbnail(filter: filter)
                        .frame(width: 84, height: 84)
                    VStack(alignment: .leading, spacing: Sp.xxs) {
                        Text(filter.title)
                            .fmTypography(.headline)
                            .foregroundStyle(FMColors.Text.primary)
                        Text(filter.author.displayName)
                            .fmTypography(.subhead)
                            .foregroundStyle(FMColors.Text.secondary)
                        HStack(spacing: Sp.xs) {
                            PillText("Downloaded")
                            if store.isFavorite(filter) {
                                PillText("Favorite")
                            }
                        }
                    }
                    Spacer()
                }
            } else {
                Text("필터 정보를 불러오고 있습니다.")
                    .fmTypography(.body)
                    .foregroundStyle(FMColors.Text.secondary)
            }
        }
    }

    private var actionList: some View {
        FMCard {
            VStack(spacing: 0) {
                actionRow("카메라로 적용", icon: "camera.fill", identifier: "filter.apply") {
                    applyFilter()
                }
                divider
                actionRow("즐겨찾기", icon: favoriteIcon, identifier: "filter.favorite.toggle") {
                    if let filter {
                        store.toggleFavorite(filter)
                        FMHaptic.light.play()
                    }
                }
                divider
                NavigationLink(value: AppRoute.favoritesCollection) {
                    rowContent("컬렉션에 추가", icon: "folder.badge.plus", trailing: "chevron.right")
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("filter.collection.add")
                divider
                actionRow("다운로드 제거", icon: "trash", isDestructive: true, identifier: "filter.remove") {
                    showRemoveAlert = true
                }
            }
        }
    }

    private var favoriteIcon: String {
        guard let filter, store.isFavorite(filter) else { return "heart" }
        return "heart.fill"
    }

    private var divider: some View {
        Rectangle()
            .fill(FMColors.Border.subtle)
            .frame(height: 1)
            .padding(.leading, Sp.md + 28 + Sp.sm)
    }

    private func actionRow(
        _ title: String,
        icon: String,
        isDestructive: Bool = false,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            rowContent(title, icon: icon, isDestructive: isDestructive, trailing: nil)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    private func rowContent(
        _ title: String,
        icon: String,
        isDestructive: Bool = false,
        trailing: String?
    ) -> some View {
        HStack(spacing: Sp.sm) {
            Image(systemName: icon)
                .font(.system(size: IconSize.md, weight: .regular))
                .foregroundStyle(isDestructive ? FMColors.Semantic.error : FMColors.Accent.primary)
                .frame(width: 28, height: 28)
            Text(title)
                .fmTypography(.body)
                .foregroundStyle(isDestructive ? FMColors.Semantic.error : FMColors.Text.primary)
            Spacer()
            if let trailing {
                Image(systemName: trailing)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FMColors.Text.tertiary)
            }
        }
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }

    private func applyFilter() {
        guard let filter else { return }
        store.select(filter)
        FMHaptic.success.play()
        isCameraPresented = true
    }
}

private enum DownloadPhase: Equatable {
    case preparing
    case downloading
    case completed
    case failed

    var title: String {
        switch self {
        case .preparing: "준비 중"
        case .downloading: "다운로드 중"
        case .completed: "완료"
        case .failed: "실패"
        }
    }

    var description: String {
        switch self {
        case .preparing: "필터 패키지를 확인하고 있습니다."
        case .downloading: "LUT와 필터 메타데이터를 저장하고 있습니다."
        case .completed: "저장됨 탭에서 사용할 수 있습니다."
        case .failed: "필터 정보를 찾지 못했습니다. 다시 시도해 주세요."
        }
    }

    var systemImage: String {
        switch self {
        case .preparing: "arrow.down.circle"
        case .downloading: "arrow.down.circle.fill"
        case .completed: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        }
    }
}

struct CameraAspectPickerScreen: View {
    @EnvironmentObject private var store: MooditStore

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
                            store.cameraAspectRatio = ratio
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
                                        store.cameraAspectRatio == ratio ? FMColors.Accent.primary : FMColors.Border.subtle,
                                        lineWidth: store.cameraAspectRatio == ratio ? 2 : 1
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
        case .fourThree: 4.0 / 3.0
        case .sixteenNine: 16.0 / 9.0
        }
    }

    private func aspectDescription(_ ratio: PhotoCropAspectRatio) -> String {
        switch ratio {
        case .square: "프로필과 컬렉션 커버에 적합"
        case .fourThree: "기본 카메라 사진에 적합"
        case .sixteenNine: "스토리와 가로 장면에 적합"
        }
    }

    private func aspectIdentifier(_ ratio: PhotoCropAspectRatio) -> String {
        switch ratio {
        case .square: "1_1"
        case .fourThree: "4_3"
        case .sixteenNine: "16_9"
        }
    }
}

struct CameraTimerCountdownScreen: View {
    @EnvironmentObject private var store: MooditStore
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
                                store.cameraTimerOption = option
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
                                    if option == store.cameraTimerOption {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(FMColors.Accent.primary)
                                    }
                                }
                                .frame(minHeight: 54)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("cam.timer.set.\(option.rawValue)")
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
    @EnvironmentObject private var store: MooditStore
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var loadError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.lg) {
                workflowHeader(
                    title: "사진 가져오기",
                    subtitle: "앨범에서 사진을 선택해 moodit 필터를 적용합니다.",
                    symbol: "photo.on.rectangle"
                )

                selectedPreview

                PhotosPicker(selection: $selectedItem, matching: .images) {
                    HStack(spacing: Sp.xs) {
                        Image(systemName: "photo.badge.plus")
                        Text(selectedImage == nil ? "사진 선택" : "다른 사진 선택")
                            .font(.headline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(FMColors.Accent.primary, in: RoundedRectangle(cornerRadius: R.md))
                }
                .accessibilityIdentifier("photo.import.cell.tap")

                if selectedImage != nil {
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
        }
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
            store.setImportedPhotoData(data)
            loadError = nil
            FMHaptic.success.play()
        } catch {
            loadError = "사진을 불러오지 못했어요."
            FMHaptic.error.play()
        }
    }
}

struct PhotoEditScreen: View {
    @EnvironmentObject private var store: MooditStore
    @State private var intensity: Double = 0.65
    @State private var selectedFilterID: Filter.ID?
    @State private var renderedImage: UIImage?
    @State private var isRendering = false
    @State private var showShareSheet = false
    @State private var saveMessage: String?

    private let renderer = PhotoFilterRenderer(lutResourceBundle: MarketplaceResources.bundle)
    private let saver: any PhotoLibrarySaving = PhotoLibrarySaver.live()

    private var selectedFilter: Filter? {
        if let selectedFilterID,
           let filter = store.filters.first(where: { $0.id == selectedFilterID }) {
            return filter
        }
        return store.selectedFilter ?? store.filters.first
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
        .task {
            await store.load()
            selectedFilterID = store.selectedFilter?.id
            await render()
        }
        .onChange(of: selectedFilterID) { _, _ in Task { await render() } }
        .onChange(of: intensity) { _, _ in Task { await render() } }
        .fmShareSheet(isPresented: $showShareSheet, items: shareItems)
    }

    private var preview: some View {
        ZStack {
            if let renderedImage {
                Image(uiImage: renderedImage)
                    .resizable()
                    .scaledToFill()
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
        }
        .frame(maxWidth: .infinity)
        .frame(height: 420)
        .clipShape(RoundedRectangle(cornerRadius: R.lg))
        .overlay {
            RoundedRectangle(cornerRadius: R.lg)
                .strokeBorder(FMColors.Border.subtle, lineWidth: 1)
        }
    }

    private var filterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Sp.xs) {
                ForEach(store.filters) { filter in
                    let isSelected = selectedFilter?.id == filter.id
                    Button {
                        FMHaptic.selection.play()
                        selectedFilterID = filter.id
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
                FMSlider(value: $intensity)
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
                cropAspectRatio: store.cameraAspectRatio
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
        store.importedPhotoData ?? PlaceholderPhoto.makeJPEGData()
    }
}

struct BuiltinFilterLibraryScreen: View {
    @EnvironmentObject private var store: MooditStore
    @State private var isCameraPresented = false

    private let columns = [
        GridItem(.flexible(), spacing: Sp.sm),
        GridItem(.flexible(), spacing: Sp.sm)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.lg) {
                workflowHeader(
                    title: "기본 필터",
                    subtitle: "moodit에 포함된 seed 필터를 바로 적용하거나 상세를 확인합니다.",
                    symbol: "camera.filters"
                )

                LazyVGrid(columns: columns, spacing: Sp.sm) {
                    ForEach(store.filters) { filter in
                        VStack(alignment: .leading, spacing: Sp.sm) {
                            NavigationLink(value: AppRoute.filterDetail(id: filter.title)) {
                                FMFilterTile(data: tileData(for: filter))
                            }
                            .buttonStyle(.plain)

                            HStack(spacing: Sp.xs) {
                                FMButton("적용", icon: "camera.fill", variant: .primary, size: .sm) {
                                    store.select(filter)
                                    isCameraPresented = true
                                }
                                .accessibilityIdentifier("builtin.filter.apply.\(filter.id.uuidString)")
                                NavigationLink(value: AppRoute.filterDetail(id: filter.title)) {
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(FMColors.Text.primary)
                                        .frame(width: 36, height: 36)
                                        .background(FMColors.Background.bg2, in: RoundedRectangle(cornerRadius: R.md))
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("builtin.filter.info.\(filter.id.uuidString)")
                            }
                        }
                    }
                }
            }
            .padding(Sp.md)
            .padding(.bottom, FMLayout.tabBarHeight + Sp.xxxl)
        }
        .background(FMColors.Background.bg1)
        .navigationTitle("기본 필터")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: AppRoute.myFilters) {
                    Image(systemName: "rectangle.stack")
                }
                .accessibilityLabel("내 필터 관리")
            }
        }
        .task {
            await store.load()
        }
        .fullScreenCover(isPresented: $isCameraPresented) {
            CameraScreen(isPresentedAsCover: true)
                .environmentObject(store)
        }
    }

    private func tileData(for filter: Filter) -> FMFilterTileData {
        FMFilterTileData(
            title: filter.title,
            makerName: filter.author.displayName,
            downloadCount: 0,
            priceLabel: store.isDownloaded(filter) ? "저장됨" : "기본",
            categoryHint: filter.category.swatch.first
        )
    }
}

// MARK: - Account / Profile

struct AccountDeletionScreen: View {
    @EnvironmentObject private var store: MooditStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirmation = ""
    @State private var showDeleteAlert = false
    @State private var didRequestDeletion = false

    private var expectedHandle: String {
        store.editableProfile.displayHandle
    }

    private var isConfirmationValid: Bool {
        confirmation.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == expectedHandle.lowercased()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.lg) {
                workflowHeader(
                    title: "계정 삭제",
                    subtitle: "삭제 요청 전 사라지는 데이터와 유지되는 항목을 확인합니다.",
                    symbol: "person.crop.circle.badge.xmark"
                )

                if didRequestDeletion || store.accountDeletionRequestedAt != nil {
                    deletionReceipt
                } else {
                    warningCard
                    confirmationCard
                    actionButtons
                }
            }
            .padding(Sp.md)
            .padding(.bottom, FMLayout.tabBarHeight + Sp.xxxl)
        }
        .background(FMColors.Background.bg1)
        .navigationTitle("계정 삭제")
        .navigationBarTitleDisplayMode(.inline)
        .fmDestructiveAlert(
            "계정을 영구 삭제할까요?",
            message: "요청이 접수되면 프로필과 업로드한 필터가 삭제 대기 상태로 전환됩니다.",
            destructiveTitle: "삭제 요청",
            isPresented: $showDeleteAlert
        ) {
            store.markAccountDeletionRequested()
            didRequestDeletion = true
        }
    }

    private var warningCard: some View {
        FMCard {
            VStack(alignment: .leading, spacing: Sp.md) {
                deletionImpactRow("업로드한 필터 삭제", detail: "검수 중이거나 공개된 필터가 비공개 처리 후 삭제됩니다.", icon: "camera.filters")
                workflowDivider()
                deletionImpactRow("프로필·팔로우 정보 삭제", detail: "프로필, 바이오, 팔로워/팔로잉 관계가 영구 삭제됩니다.", icon: "person.2")
                workflowDivider()
                deletionImpactRow("다운로드한 필터 유지", detail: "다른 메이커에게 구매한 필터는 기기와 구매 내역에 유지됩니다.", icon: "checkmark.seal")
            }
        }
    }

    private var confirmationCard: some View {
        FMCard {
            VStack(alignment: .leading, spacing: Sp.sm) {
                Text("확인을 위해 \(expectedHandle)를 입력하세요.")
                    .fmTypography(.body)
                    .foregroundStyle(FMColors.Text.primary)
                FMTextField(
                    nil,
                    text: $confirmation,
                    placeholder: expectedHandle,
                    error: confirmation.isEmpty || isConfirmationValid ? nil : "핸들이 일치하지 않습니다."
                )
                .accessibilityIdentifier("auth.delete.confirm.input")
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: Sp.sm) {
            FMButton("계정 영구 삭제", icon: "trash", variant: .primary, size: .lg) {
                showDeleteAlert = true
            }
            .disabled(!isConfirmationValid)
            .accessibilityIdentifier("auth.delete.submit")

            FMButton("취소", variant: .secondary, size: .lg) {
                dismiss()
            }
            .accessibilityIdentifier("auth.delete.cancel")
        }
    }

    private var deletionReceipt: some View {
        FMCard {
            VStack(alignment: .leading, spacing: Sp.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(FMColors.Accent.primary)
                Text("삭제 요청이 접수됐습니다")
                    .fmTypography(.headline)
                    .foregroundStyle(FMColors.Text.primary)
                Text("보안 확인과 정산 상태 점검 후 계정 삭제 절차가 진행됩니다.")
                    .fmTypography(.body)
                    .foregroundStyle(FMColors.Text.secondary)
            }
        }
    }

    private func deletionImpactRow(_ title: String, detail: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: Sp.sm) {
            Image(systemName: icon)
                .font(.system(size: IconSize.md, weight: .semibold))
                .foregroundStyle(FMColors.Semantic.error)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fmTypography(.headline)
                    .foregroundStyle(FMColors.Text.primary)
                Text(detail)
                    .fmTypography(.subhead)
                    .foregroundStyle(FMColors.Text.secondary)
            }
        }
    }
}

struct EditProfileScreen: View {
    @EnvironmentObject private var store: MooditStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft = EditableProfile.preview
    @State private var handleStatus: HandleStatus = .available

    private enum HandleStatus {
        case unchecked
        case checking
        case available
        case unavailable

        var message: String {
            switch self {
            case .unchecked: "핸들 중복 확인이 필요합니다."
            case .checking: "확인 중..."
            case .available: "사용 가능한 핸들입니다."
            case .unavailable: "이미 사용 중인 핸들입니다."
            }
        }

        var tint: Color {
            switch self {
            case .available: FMColors.Accent.primary
            case .unavailable: FMColors.Semantic.error
            default: FMColors.Text.tertiary
            }
        }
    }

    private var canSave: Bool {
        !draft.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !draft.handle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && handleStatus == .available
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.lg) {
                avatarEditor
                formFields
                visibilitySettings
                saveReceipt
            }
            .padding(Sp.md)
            .padding(.bottom, FMLayout.tabBarHeight + Sp.xxxl)
        }
        .background(FMColors.Background.bg1)
        .navigationTitle("프로필 편집")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("취소") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("저장") { save() }
                    .disabled(!canSave)
                    .accessibilityIdentifier("profile.edit.save")
            }
        }
        .onAppear {
            draft = store.editableProfile
            handleStatus = .available
        }
    }

    private var avatarEditor: some View {
        VStack(spacing: Sp.sm) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(avatarGradient)
                    .frame(width: 104, height: 104)
                    .overlay {
                        Text(draft.initials)
                            .fmTypography(.titleLarge)
                            .foregroundStyle(.white)
                    }
                Button {
                    draft.avatarVariant = (draft.avatarVariant + 1) % 4
                } label: {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(FMColors.Accent.primary, in: Circle())
                }
                .accessibilityIdentifier("profile.edit.avatar.change")
            }
            Button("사진 변경") {
                draft.avatarVariant = (draft.avatarVariant + 1) % 4
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(FMColors.Accent.primary)
        }
        .frame(maxWidth: .infinity)
    }

    private var formFields: some View {
        VStack(alignment: .leading, spacing: Sp.md) {
            FMTextField("이름", text: $draft.displayName, placeholder: "표시 이름")
                .accessibilityIdentifier("profile.edit.name")
            VStack(alignment: .leading, spacing: Sp.xxs) {
                HStack(spacing: Sp.xs) {
                    FMTextField(
                        "핸들",
                        text: Binding(
                            get: { draft.handle },
                            set: {
                                draft.handle = $0
                                    .replacingOccurrences(of: "@", with: "")
                                    .lowercased()
                                handleStatus = .unchecked
                            }
                        ),
                        placeholder: "jisoo.films"
                    )
                    .accessibilityIdentifier("profile.edit.handle")
                    Button {
                        checkHandle()
                    } label: {
                        Image(systemName: "checkmark.seal")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(FMColors.Accent.primary, in: RoundedRectangle(cornerRadius: R.md))
                    }
                    .accessibilityIdentifier("profile.edit.handle.check")
                }
                Text(handleStatus.message)
                    .fmTypography(.caption)
                    .foregroundStyle(handleStatus.tint)
            }
            FMTextField("소개", text: $draft.bio, placeholder: "나를 소개해 주세요.", style: .multiline(minHeight: 96))
                .accessibilityIdentifier("profile.edit.bio")
            FMTextField("링크", text: $draft.website, placeholder: "https://", keyboardType: .URL)
                .accessibilityIdentifier("profile.edit.website")
        }
    }

    private var visibilitySettings: some View {
        FMCard {
            VStack(spacing: 0) {
                Toggle("메이커 페이지 노출", isOn: $draft.makerPageVisible)
                    .tint(FMColors.Accent.primary)
                workflowDivider()
                Toggle("필터 적용 사진 공유 허용", isOn: $draft.photoSharingAllowed)
                    .tint(FMColors.Accent.primary)
            }
            .fmTypography(.body)
            .foregroundStyle(FMColors.Text.primary)
        }
    }

    @ViewBuilder
    private var saveReceipt: some View {
        if let savedAt = store.lastProfileSavedAt {
            Text("저장됨 · \(workflowTimeString(savedAt))")
                .fmTypography(.caption)
                .foregroundStyle(FMColors.Text.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var avatarGradient: LinearGradient {
        let colors: [[Color]] = [
            [FMColors.Category.vintage, FMColors.Category.cinematic],
            [FMColors.Category.travel, FMColors.Category.pastel],
            [FMColors.Category.food, FMColors.Accent.primary],
            [FMColors.Category.mood, FMColors.Category.portrait]
        ]
        return LinearGradient(
            colors: colors[draft.avatarVariant % colors.count],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func checkHandle() {
        handleStatus = .checking
        let normalized = draft.handle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            handleStatus = ["admin", "moodit", "support"].contains(normalized) ? .unavailable : .available
        }
    }

    private func save() {
        store.saveProfile(draft)
        dismiss()
    }
}

struct UniversalLinkLandingScreen: View {
    @EnvironmentObject private var store: MooditStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.lg) {
                workflowHeader(
                    title: "공유 링크",
                    subtitle: "공유받은 필터를 확인하고 바로 다운로드하거나 상세로 이동합니다.",
                    symbol: "link"
                )

                FMCard {
                    VStack(alignment: .leading, spacing: Sp.md) {
                        landingThumbnail
                        VStack(alignment: .leading, spacing: Sp.xs) {
                            Text("Sunset 1973")
                                .fmTypography(.titleLarge)
                                .foregroundStyle(FMColors.Text.primary)
                            HStack(spacing: Sp.xs) {
                                FMAvatar(initials: "JS", size: .xs)
                                Text("@jisoo.films")
                                    .fmTypography(.subhead)
                                    .foregroundStyle(FMColors.Text.secondary)
                                Text("무료 필터")
                                    .fmTypography(.caption)
                                    .foregroundStyle(FMColors.Accent.primary)
                                    .padding(.horizontal, Sp.xs)
                                    .padding(.vertical, 4)
                                    .background(FMColors.Accent.bg, in: Capsule())
                            }
                            Text("따뜻한 황혼과 필름 입자를 담은 추천 필터입니다.")
                                .fmTypography(.body)
                                .foregroundStyle(FMColors.Text.secondary)
                        }
                    }
                }

                NavigationLink(value: AppRoute.filterDownload(id: "Sunset 1973")) {
                    routeButton("다운로드 + 카메라 열기", icon: "arrow.down.circle")
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("app.deeplink.confirm")

                NavigationLink(value: AppRoute.filterDetail(id: "Sunset 1973")) {
                    HStack(spacing: Sp.xs) {
                        Image(systemName: "doc.text.magnifyingglass")
                        Text("상세 페이지 보기")
                            .fmTypography(.headline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(FMColors.Text.primary)
                    .padding(.horizontal, Sp.md)
                    .frame(height: 52)
                    .background(FMColors.Background.bg2, in: RoundedRectangle(cornerRadius: R.md))
                    .overlay {
                        RoundedRectangle(cornerRadius: R.md)
                            .strokeBorder(FMColors.Border.default, lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("app.deeplink.detail")
            }
            .padding(Sp.md)
            .padding(.bottom, FMLayout.tabBarHeight + Sp.xxxl)
        }
        .background(FMColors.Background.bg1)
        .navigationTitle("공유 링크")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await store.load()
        }
    }

    @ViewBuilder
    private var landingThumbnail: some View {
        if let filter = store.filter(matching: "Sunset 1973") ?? store.filters.first {
            FilterThumbnail(filter: filter)
                .frame(height: 180)
        } else {
            RoundedRectangle(cornerRadius: R.md)
                .fill(FMColors.Background.bg2)
                .frame(height: 180)
                .overlay {
                    Image(systemName: "camera.filters")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(FMColors.Text.tertiary)
                }
        }
    }
}

struct DataExportScreen: View {
    @EnvironmentObject private var store: MooditStore
    @State private var showSubmitAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.lg) {
                workflowHeader(
                    title: "내 데이터 사본 받기",
                    subtitle: "계정과 활동 데이터를 요청하면 보안 링크로 전달됩니다.",
                    symbol: "doc.zipper"
                )

                categorySection
                formatSection
                historySection
                noticeCard

                FMButton("데이터 사본 요청", icon: "paperplane.fill", variant: .primary, size: .lg) {
                    showSubmitAlert = true
                }
                .disabled(store.selectedExportCategories.isEmpty)
                .accessibilityIdentifier("settings.export.submit")
            }
            .padding(Sp.md)
            .padding(.bottom, FMLayout.tabBarHeight + Sp.xxxl)
        }
        .background(FMColors.Background.bg1)
        .navigationTitle("데이터 다운로드")
        .navigationBarTitleDisplayMode(.inline)
        .alert("데이터 사본을 요청할까요?", isPresented: $showSubmitAlert) {
            Button("요청") {
                store.requestDataExport()
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("요청 후 최대 30일 이내 보안 링크로 안내됩니다.")
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: Sp.sm) {
            sectionLabel("포함할 데이터")
            FMCard {
                VStack(spacing: 0) {
                    ForEach(DataExportCategory.allCases) { category in
                        Button {
                            store.toggleExportCategory(category)
                        } label: {
                            HStack(alignment: .top, spacing: Sp.sm) {
                                Image(systemName: store.selectedExportCategories.contains(category) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(store.selectedExportCategories.contains(category) ? FMColors.Accent.primary : FMColors.Text.tertiary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(category.title)
                                        .fmTypography(.headline)
                                        .foregroundStyle(FMColors.Text.primary)
                                    Text(category.detail)
                                        .fmTypography(.caption)
                                        .foregroundStyle(FMColors.Text.secondary)
                                }
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, Sp.xs)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("settings.export.cat.toggle.\(category.rawValue)")
                        if category.id != DataExportCategory.allCases.last?.id {
                            workflowDivider()
                        }
                    }
                }
            }
            .accessibilityIdentifier("settings.export.cat.toggle")
        }
    }

    private var formatSection: some View {
        VStack(alignment: .leading, spacing: Sp.sm) {
            sectionLabel("파일 형식")
            HStack(spacing: Sp.xs) {
                ForEach(DataExportFormat.allCases) { format in
                    Button {
                        store.selectedExportFormat = format
                    } label: {
                        VStack(spacing: 2) {
                            Text(format.rawValue)
                                .fmTypography(.headline)
                            Text(format.description)
                                .font(.caption2)
                                .lineLimit(1)
                        }
                        .foregroundStyle(store.selectedExportFormat == format ? .white : FMColors.Text.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(
                            store.selectedExportFormat == format ? FMColors.Accent.primary : FMColors.Background.bg2,
                            in: RoundedRectangle(cornerRadius: R.md)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: R.md)
                                .strokeBorder(FMColors.Border.default, lineWidth: store.selectedExportFormat == format ? 0 : 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .accessibilityIdentifier("settings.export.format")
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: Sp.sm) {
            sectionLabel("이전 요청")
            FMCard {
                VStack(spacing: 0) {
                    ForEach(store.exportRequests) { request in
                        HStack(spacing: Sp.sm) {
                            Image(systemName: request.status == "만료" ? "clock.badge.exclamationmark" : "doc.text")
                                .foregroundStyle(request.status == "만료" ? FMColors.Text.tertiary : FMColors.Accent.primary)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(request.title) — \(request.format.rawValue)")
                                    .fmTypography(.subhead)
                                    .foregroundStyle(FMColors.Text.primary)
                                Text(workflowDateString(request.requestedAt))
                                    .fmTypography(.caption)
                                    .foregroundStyle(FMColors.Text.secondary)
                            }
                            Spacer()
                            Text(request.status)
                                .fmTypography(.caption)
                                .foregroundStyle(request.status == "만료" ? FMColors.Text.tertiary : FMColors.Accent.primary)
                        }
                        .padding(.vertical, Sp.xs)
                        if request.id != store.exportRequests.last?.id {
                            workflowDivider()
                        }
                    }
                }
            }
        }
    }

    private var noticeCard: some View {
        HStack(alignment: .top, spacing: Sp.sm) {
            Image(systemName: "lock.shield")
                .foregroundStyle(FMColors.Accent.primary)
            Text("보안 링크는 7일간 유효합니다. 다운로드 URL은 이메일과 알림 인박스에 동시에 발송됩니다.")
                .fmTypography(.caption)
                .foregroundStyle(FMColors.Text.secondary)
        }
        .padding(Sp.md)
        .background(FMColors.Accent.bg, in: RoundedRectangle(cornerRadius: R.md))
    }
}

// MARK: - Editor / Upload

struct FilterEditorScreen: View {
    var body: some View { ScreenWorkflowScaffold(route: .editor) }
}

struct EditorParametersScreen: View {
    var body: some View { ScreenWorkflowScaffold(route: .editorParameters) }
}

struct EditorLUTImportScreen: View {
    var body: some View { ScreenWorkflowScaffold(route: .editorLUT) }
}

struct EditorDraftSaveScreen: View {
    var body: some View { ScreenWorkflowScaffold(route: .editorDraft) }
}

struct UploadCoverScreen: View {
    var body: some View { ScreenWorkflowScaffold(route: .uploadCover) }
}

struct UploadTagsCategoryScreen: View {
    var body: some View { ScreenWorkflowScaffold(route: .uploadTags) }
}

struct UploadTOSSubmitScreen: View {
    var body: some View { ScreenWorkflowScaffold(route: .uploadSubmit) }
}

struct UploadPendingReviewScreen: View {
    var body: some View { ScreenWorkflowScaffold(route: .uploadPending) }
}

// FilterRejectedScreen — `Sources/App/Moderation/FilterRejectedScreen.swift`

struct MyFiltersScreen: View {
    var body: some View { ScreenWorkflowScaffold(route: .myFilters) }
}

struct RemixFlowScreen: View {
    var body: some View { ScreenWorkflowScaffold(route: .remixFlow) }
}

// MARK: - Social / Discovery

struct CommentsListScreen: View {
    let filterID: String
    var body: some View { ScreenWorkflowScaffold(route: .comments(filterId: filterID)) }
}

struct CommentComposeScreen: View {
    let filterID: String
    var body: some View { ScreenWorkflowScaffold(route: .commentCompose(filterId: filterID)) }
}

struct RatingFormScreen: View {
    let filterID: String
    var body: some View { ScreenWorkflowScaffold(route: .rating(filterId: filterID)) }
}

struct FollowersListScreen: View {
    let userID: String
    var body: some View { ScreenWorkflowScaffold(route: .followers(uid: userID)) }
}

struct FollowingListScreen: View {
    let userID: String
    var body: some View { ScreenWorkflowScaffold(route: .following(uid: userID)) }
}

// NotificationsInboxScreen — `Sources/App/Notifications/NotificationsInboxScreen.swift`

struct NotificationSettingsScreen: View {
    @EnvironmentObject private var store: MooditStore
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.lg) {
                workflowHeader(
                    title: "알림 설정",
                    subtitle: "시스템 권한과 앱 안의 알림 카테고리를 함께 관리합니다.",
                    symbol: "bell.badge"
                )

                systemCard
                categoryCard
                quietHoursCard
            }
            .padding(Sp.md)
            .padding(.bottom, FMLayout.tabBarHeight + Sp.xxxl)
        }
        .background(FMColors.Background.bg1)
        .navigationTitle("알림 설정")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var systemCard: some View {
        FMCard {
            HStack(alignment: .top, spacing: Sp.sm) {
                Image(systemName: store.notificationPreferences.systemEnabled ? "bell.fill" : "bell.slash")
                    .font(.system(size: IconSize.md, weight: .semibold))
                    .foregroundStyle(FMColors.Accent.primary)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 4) {
                    Text("시스템 알림 — \(store.notificationPreferences.systemEnabled ? "켜짐" : "확인 필요")")
                        .fmTypography(.headline)
                        .foregroundStyle(FMColors.Text.primary)
                    Text("잠금화면, 배지, 소리는 iOS 설정에서 관리합니다.")
                        .fmTypography(.subhead)
                        .foregroundStyle(FMColors.Text.secondary)
                }
                Spacer()
                Button("설정 열기") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(FMColors.Accent.primary)
                .accessibilityIdentifier("notif.system.open")
            }
        }
    }

    private var categoryCard: some View {
        VStack(alignment: .leading, spacing: Sp.sm) {
            sectionLabel("카테고리")
            FMCard {
                VStack(spacing: 0) {
                    preferenceToggle("소셜", detail: "팔로우, 좋아요, 메이커 활동", isOn: $store.notificationPreferences.social)
                    workflowDivider()
                    preferenceToggle("댓글과 멘션", detail: "@멘션과 답글은 항상 알림", isOn: $store.notificationPreferences.comments)
                    workflowDivider()
                    preferenceToggle("마켓", detail: "추천 필터, 컬렉션 업데이트", isOn: $store.notificationPreferences.marketplace)
                    workflowDivider()
                    preferenceToggle("메이커", detail: "업로드한 필터의 검수 완료 알림", isOn: $store.notificationPreferences.creator)
                    workflowDivider()
                    preferenceToggle("지갑과 결제", detail: "구매, 환불, 정산 상태", isOn: $store.notificationPreferences.wallet)
                    workflowDivider()
                    preferenceToggle("제품 소식", detail: "새 기능과 이벤트", isOn: $store.notificationPreferences.product)
                }
            }
            .accessibilityIdentifier("notif.cat.toggle")
        }
    }

    private var quietHoursCard: some View {
        VStack(alignment: .leading, spacing: Sp.sm) {
            sectionLabel("방해 금지 시간")
            FMCard {
                VStack(spacing: 0) {
                    preferenceToggle(
                        "방해 금지 시간 사용",
                        detail: "시스템 알림 외 모두 차단",
                        isOn: $store.notificationPreferences.quietHoursEnabled
                    )
                    .accessibilityIdentifier("notif.quiet.toggle")
                    workflowDivider()
                    quietRow("시작", value: store.notificationPreferences.quietStart) {
                        store.notificationPreferences.quietStart = nextQuietStart(after: store.notificationPreferences.quietStart)
                    }
                    workflowDivider()
                    quietRow("종료", value: store.notificationPreferences.quietEnd) {
                        store.notificationPreferences.quietEnd = nextQuietEnd(after: store.notificationPreferences.quietEnd)
                    }
                }
            }
        }
    }

    private func preferenceToggle(_ title: String, detail: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fmTypography(.body)
                    .foregroundStyle(FMColors.Text.primary)
                Text(detail)
                    .fmTypography(.caption)
                    .foregroundStyle(FMColors.Text.secondary)
            }
        }
        .tint(FMColors.Accent.primary)
        .padding(.vertical, Sp.xs)
    }

    private func quietRow(_ title: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .fmTypography(.body)
                    .foregroundStyle(FMColors.Text.primary)
                Spacer()
                Text(value)
                    .fmTypography(.headline)
                    .foregroundStyle(FMColors.Accent.primary)
            }
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func nextQuietStart(after value: String) -> String {
        switch value {
        case "21:00": "22:00"
        case "22:00": "23:00"
        default: "21:00"
        }
    }

    private func nextQuietEnd(after value: String) -> String {
        switch value {
        case "06:00": "07:00"
        case "07:00": "08:00"
        default: "06:00"
        }
    }
}

// FavoritesCollectionScreen — `Sources/App/Collections/FavoritesCollectionScreen.swift`

struct ForYouFeedScreen: View {
    var body: some View { ScreenWorkflowScaffold(route: .forYou) }
}

struct FollowingFeedScreen: View {
    var body: some View { ScreenWorkflowScaffold(route: .followingFeed) }
}

// MARK: - Safety / Moderation

struct ReportFormScreen: View {
    var body: some View { ScreenWorkflowScaffold(route: .reportForm) }
}

struct ModerationQueueScreen: View {
    var body: some View { ScreenWorkflowScaffold(route: .modQueue) }
}

struct ModerationDetailScreen: View {
    let itemID: String
    var body: some View { ScreenWorkflowScaffold(route: .modDetail(id: itemID)) }
}

struct BlockListScreen: View {
    var body: some View { ScreenWorkflowScaffold(route: .blockList) }
}

// MARK: - Monetization

struct PaywallSingleScreen: View {
    let filterID: String
    var body: some View { ScreenWorkflowScaffold(route: .paywallSingle(filterId: filterID)) }
}

struct ProSubscriptionScreen: View {
    var body: some View { ScreenWorkflowScaffold(route: .proSubscription) }
}

struct ProStatusScreen: View {
    var body: some View { ScreenWorkflowScaffold(route: .proStatus) }
}

struct OrdersHistoryScreen: View {
    var body: some View { ScreenWorkflowScaffold(route: .ordersHistory) }
}

struct WalletScreen: View {
    var body: some View { ScreenWorkflowScaffold(route: .wallet) }
}

struct WalletTopupScreen: View {
    var body: some View { ScreenWorkflowScaffold(route: .walletTopup) }
}

struct WalletTransactionsScreen: View {
    var body: some View { ScreenWorkflowScaffold(route: .walletTransactions) }
}

struct InsufficientBalanceScreen: View {
    let filterID: String
    var body: some View { ScreenWorkflowScaffold(route: .insufficientBalance(filterId: filterID)) }
}

struct PaymentFailedScreen: View {
    var body: some View { ScreenWorkflowScaffold(route: .paymentFailed) }
}

struct RefundRequestScreen: View {
    var body: some View { ScreenWorkflowScaffold(route: .refundRequest) }
}

struct MakerDashboardScreen: View {
    var body: some View { ScreenWorkflowScaffold(route: .makerDashboard) }
}

struct PayoutOnboardingScreen: View {
    var body: some View { ScreenWorkflowScaffold(route: .payoutOnboarding) }
}

struct PayoutTaxInfoScreen: View {
    var body: some View { ScreenWorkflowScaffold(route: .payoutTaxInfo) }
}

struct PayoutHistoryScreen: View {
    var body: some View { ScreenWorkflowScaffold(route: .payoutHistory) }
}

struct EarningsWithdrawScreen: View {
    var body: some View { ScreenWorkflowScaffold(route: .earningsWithdraw) }
}

// MARK: - Phase A shared helpers

@MainActor
private func workflowHeader(title: String, subtitle: String, symbol: String) -> some View {
    VStack(alignment: .leading, spacing: Sp.md) {
        Image(systemName: symbol)
            .font(.system(size: 28, weight: .semibold))
            .foregroundStyle(FMColors.Accent.primary)
            .frame(width: 56, height: 56)
            .background(FMColors.Accent.bg, in: RoundedRectangle(cornerRadius: R.lg))
            .overlay {
                RoundedRectangle(cornerRadius: R.lg)
                    .strokeBorder(FMColors.Accent.primary.opacity(0.24), lineWidth: 1)
            }

        VStack(alignment: .leading, spacing: Sp.xs) {
            Text(title)
                .fmTypography(.titleLarge)
                .foregroundStyle(FMColors.Text.primary)
            Text(subtitle)
                .fmTypography(.body)
                .foregroundStyle(FMColors.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
}

@MainActor
private func routeButton(_ title: String, icon: String) -> some View {
    HStack(spacing: Sp.xs) {
        Image(systemName: icon)
        Text(title)
            .fmTypography(.headline)
        Spacer()
        Image(systemName: "chevron.right")
            .font(.system(size: 12, weight: .semibold))
    }
    .foregroundStyle(.white)
    .padding(.horizontal, Sp.md)
    .frame(height: 52)
    .background(FMColors.Accent.primary, in: RoundedRectangle(cornerRadius: R.md))
}

@MainActor
private func sectionLabel(_ title: String) -> some View {
    Text(title)
        .fmTypography(.caption)
        .foregroundStyle(FMColors.Text.tertiary)
        .textCase(.uppercase)
}

@MainActor
private func workflowDivider() -> some View {
    Rectangle()
        .fill(FMColors.Border.subtle)
        .frame(height: 1)
}

private func workflowDateString(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "yyyy. M. d. HH:mm"
    return formatter.string(from: date)
}

private func workflowTimeString(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "HH:mm"
    return formatter.string(from: date)
}

private enum PlaceholderPhoto {
    static func makeJPEGData() -> Data {
        let size = CGSize(width: 1200, height: 1600)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            let colors = [
                UIColor(red: 0.12, green: 0.14, blue: 0.19, alpha: 1).cgColor,
                UIColor(red: 0.64, green: 0.42, blue: 0.26, alpha: 1).cgColor
            ]
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: [0, 1]
            )
            context.cgContext.drawLinearGradient(
                gradient!,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )
            UIColor.white.withAlphaComponent(0.16).setStroke()
            UIBezierPath(roundedRect: rect.insetBy(dx: 120, dy: 160), cornerRadius: 42).stroke()
        }
        return image.jpegData(compressionQuality: 0.92) ?? Data()
    }
}
