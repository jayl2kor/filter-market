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
    var body: some View { ScreenWorkflowScaffold(route: .accountDeletion) }
}

struct EditProfileScreen: View {
    var body: some View { ScreenWorkflowScaffold(route: .editProfile) }
}

struct UniversalLinkLandingScreen: View {
    var body: some View { ScreenWorkflowScaffold(route: .universalLinkLanding) }
}

struct DataExportScreen: View {
    var body: some View { ScreenWorkflowScaffold(route: .dataExport) }
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

struct FilterRejectedScreen: View {
    let filterID: String
    var body: some View { ScreenWorkflowScaffold(route: .filterRejected(id: filterID)) }
}

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

struct NotificationsInboxScreen: View {
    var body: some View { ScreenWorkflowScaffold(route: .notifications) }
}

struct NotificationSettingsScreen: View {
    var body: some View { ScreenWorkflowScaffold(route: .notificationSettings) }
}

struct FavoritesCollectionScreen: View {
    var body: some View { ScreenWorkflowScaffold(route: .favoritesCollection) }
}

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
