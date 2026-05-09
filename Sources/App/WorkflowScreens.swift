import Camera
import DesignSystem
import FilterEngine
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import Marketplace
import Models
import PhotosUI
import StoreKit
import SwiftUI
import UIKit
import UserNotifications

// MARK: - Camera / Download

private enum SignedFilterPackageDownloader {
    static func download(
        from url: URL,
        filterID: String,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        let (bytes, response) = try await URLSession.shared.bytes(from: url)
        if let http = response as? HTTPURLResponse,
           !(200 ..< 300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }

        let directory = try packageDirectory()
        let safeID = filterID.map { character -> Character in
            character.isLetter || character.isNumber || character == "-" || character == "_" ? character : "_"
        }
        .map(String.init)
        .joined()
        let destination = directory.appendingPathComponent("\(safeID).fmpkg")
        let temporary = directory.appendingPathComponent("\(safeID).fmpkg.download")
        FileManager.default.createFile(atPath: temporary.path, contents: nil)
        let handle = try FileHandle(forWritingTo: temporary)
        var receivedBytes = 0
        var buffer = Data()
        let expectedBytes = response.expectedContentLength

        do {
            for try await byte in bytes {
                try Task.checkCancellation()
                buffer.append(byte)
                receivedBytes += 1
                if buffer.count >= 64 * 1024 {
                    try handle.write(contentsOf: buffer)
                    buffer.removeAll(keepingCapacity: true)
                    reportProgress(receivedBytes: receivedBytes, expectedBytes: expectedBytes, onProgress: onProgress)
                }
            }
            if !buffer.isEmpty {
                try handle.write(contentsOf: buffer)
            }
            try handle.close()
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: temporary, to: destination)
            onProgress(1)
            return destination
        } catch {
            try? handle.close()
            try? FileManager.default.removeItem(at: temporary)
            throw error
        }
    }

    private static func packageDirectory() throws -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("moodit/downloaded-packages", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func reportProgress(
        receivedBytes: Int,
        expectedBytes: Int64,
        onProgress: @escaping @Sendable (Double) -> Void
    ) {
        guard expectedBytes > 0 else { return }
        onProgress(min(0.98, Double(receivedBytes) / Double(expectedBytes)))
    }
}

struct FilterDownloadProgressScreen: View {
    let filterID: String

    @EnvironmentObject private var store: MooditStore
    @State private var phase: DownloadPhase = .preparing
    @State private var progress: Double = 0
    @State private var hasStarted = false
    @State private var toast: FMToastMessage?

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
        .fmToastOverlay(toast: $toast)
        .task {
            await startDownloadIfNeeded()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Sp.xs) {
            // (#36) 사람이 읽을 수 있는 필터 제목만 노출 — UUID 문자열은 숨김.
            // 매칭 실패 시 일반 헤더 사용.
            Text(humanReadableTitle)
                .fmTypography(.titleLarge)
                .foregroundStyle(FMColors.Text.primary)
            Text(phase.description)
                .fmTypography(.body)
                .foregroundStyle(FMColors.Text.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// store에서 매칭되는 Filter의 title을 반환. UUID 형식이면 일반 헤더로 fallback.
    private var humanReadableTitle: String {
        if let f = filter { return f.title }
        if UUID(uuidString: filterID) != nil { return "필터 다운로드" }
        return filterID
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

                NavigationLink(value: AppRoute.filterDetail(id: filterID)) {
                    HStack(spacing: Sp.xs) {
                        Image(systemName: "chevron.left")
                        Text("상세로 돌아가기")
                            .fmTypography(.headline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(FMColors.Text.tertiary)
                    }
                    .foregroundStyle(FMColors.Text.primary)
                    .padding(.horizontal, Sp.md)
                    .frame(height: 52)
                    .background(FMColors.Background.bg2, in: RoundedRectangle(cornerRadius: R.md))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("filter.download.cancel")
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
        guard let filterIDAsUUID = UUID(uuidString: filterID) else {
            await markDownloaded()
            return
        }
        if store.downloadedFilterIDs.contains(filterIDAsUUID) {
            progress = 1
            phase = .completed
            toast = FMToastMessage(.success, "다운로드 완료", detail: "카메라에서 적용해보세요")
            return
        }
        if let filter, store.isDownloaded(filter) {
            progress = 1
            phase = .completed
            toast = FMToastMessage(.success, "다운로드 완료", detail: "카메라에서 적용해보세요")
            return
        }
        phase = .downloading

        #if DEBUG
        if isUITesting {
            await markDownloaded()
            return
        }
        #endif

        do {
            let detail = try await FilterDetailLoaderScreen.fetchDetail(filterId: filterID)
            _ = try await SignedFilterPackageDownloader.download(
                from: detail.signedDownloadURL,
                filterID: filterID
            ) { value in
                Task { @MainActor in
                    progress = value
                }
            }
            try await markDownloadedAfterPackageFetch()
            FMHaptic.success.play()
            phase = .completed
            toast = FMToastMessage(.success, "다운로드 완료", detail: "카메라에서 적용해보세요")
        } catch {
            phase = .failed
            toast = FMToastMessage(.error, "다운로드 실패", detail: "네트워크를 확인하고 다시 시도하세요")
        }
    }

    @MainActor
    private func markDownloaded() async {
        phase = .downloading
        do {
            try await markDownloadedAfterPackageFetch()
            FMHaptic.success.play()
            progress = 1
            phase = .completed
            toast = FMToastMessage(.success, "다운로드 완료", detail: "카메라에서 적용해보세요")
        } catch {
            phase = .failed
            toast = FMToastMessage(.error, "다운로드 실패", detail: "네트워크를 확인하고 다시 시도하세요")
        }
    }

    private func markDownloadedAfterPackageFetch() async throws {
        if let filter {
            try await store.download(filter)
        } else {
            try await store.download(filterID: filterID)
        }
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
    @EnvironmentObject private var store: MooditStore
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var loadError: String?

    var body: some View {
        let hasSelectedImage = selectedImage != nil

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
                        Text(hasSelectedImage ? "다른 사진 선택" : "사진 선택")
                            .font(.headline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(FMColors.Accent.primary, in: RoundedRectangle(cornerRadius: R.md))
                }
                .accessibilityIdentifier("photo.import.cell.tap")

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
                            NavigationLink(value: AppRoute.filterDetail(id: filter.id.uuidString)) {
                                FMFilterTile(data: tileData(for: filter))
                            }
                            .buttonStyle(.plain)

                            HStack(spacing: Sp.xs) {
                                FMButton("적용", icon: "camera.fill", variant: .primary, size: .sm) {
                                    store.select(filter)
                                    isCameraPresented = true
                                }
                                .accessibilityIdentifier("builtin.filter.apply.\(filter.id.uuidString)")
                                NavigationLink(value: AppRoute.filterDetail(id: filter.id.uuidString)) {
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
            categoryHint: filter.category.swatch.first,
            categoryKey: filter.category.rawValue
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
    @State private var isDeletingAccount = false
    @State private var deletionErrorMessage: String?

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
            requestAccountDeletion()
        }
        .alert("삭제 요청 실패", isPresented: Binding(
            get: { deletionErrorMessage != nil },
            set: { if !$0 { deletionErrorMessage = nil } }
        )) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(deletionErrorMessage ?? "")
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
                    error: confirmation.isEmpty || isConfirmationValid ? nil : "핸들이 일치하지 않습니다.",
                    textContentType: .nickname,
                    keyboardType: .asciiCapable,
                    autocapitalization: .never,
                    submitLabel: .done
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
            .disabled(!isConfirmationValid || isDeletingAccount)
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

    private func requestAccountDeletion() {
        guard !isDeletingAccount else { return }
        isDeletingAccount = true
        Task {
            do {
                try await store.markAccountDeletionRequested()
                try? Auth.auth().signOut()
                await MainActor.run {
                    didRequestDeletion = true
                    isDeletingAccount = false
                }
            } catch {
                await MainActor.run {
                    deletionErrorMessage = error.localizedDescription
                    isDeletingAccount = false
                }
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
    /// 빈 상태에서 시작해 .onAppear에서 store.editableProfile (Firebase Auth + Firestore 합성)로 초기화.
    /// (이전: EditableProfile.preview = 강지수 — 사용자 본인 데이터로 자동 채워지도록 수정)
    @State private var draft = EditableProfile.empty
    @State private var handleStatus: HandleStatus = .available
    @State private var isAvatarPickerPresented = false

    private enum HandleStatus {
        case unchecked
        case checking
        case available
        case unavailable

        var message: String {
            switch self {
            case .unchecked: "유저네임 중복 확인이 필요합니다."
            case .checking: "확인 중..."
            case .available: "사용 가능한 유저네임입니다."
            case .unavailable: "이미 사용 중인 유저네임입니다."
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
        .sheet(isPresented: $isAvatarPickerPresented) {
            PhotoPicker { image in
                draft.avatarImageData = image.normalizedJPEGData(maxDimension: 512)
                draft.avatarURL = nil
            }
        }
    }

    private var avatarEditor: some View {
        VStack(spacing: Sp.sm) {
            ZStack(alignment: .bottomTrailing) {
                avatarPreview
                Button {
                    isAvatarPickerPresented = true
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
                isAvatarPickerPresented = true
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(FMColors.Accent.primary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var avatarPreview: some View {
        if let data = draft.avatarImageData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 104, height: 104)
                .clipShape(Circle())
        } else if let avatarURL = draft.avatarURL {
            FMAvatar(url: avatarURL, size: .xl, fallback: draft.initials)
                .frame(width: 104, height: 104)
        } else {
            Circle()
                .fill(avatarGradient)
                .frame(width: 104, height: 104)
                .overlay {
                    Text(draft.initials)
                        .fmTypography(.titleLarge)
                        .foregroundStyle(.white)
                }
        }
    }

    private var formFields: some View {
        VStack(alignment: .leading, spacing: Sp.md) {
            FMTextField(
                "이름",
                text: $draft.displayName,
                placeholder: "표시 이름",
                textContentType: .name,
                autocapitalization: .words,
                submitLabel: .next
            )
                .accessibilityIdentifier("profile.edit.name")
            VStack(alignment: .leading, spacing: Sp.xxs) {
                Text("유저네임")
                    .fmTypography(.caption)
                    .foregroundStyle(FMColors.Text.secondary)
                HStack(alignment: .center, spacing: Sp.xs) {
                    TextField(
                        "your.username",
                        text: Binding(
                            get: { draft.handle },
                            set: {
                                draft.handle = $0
                                    .replacingOccurrences(of: "@", with: "")
                                    .lowercased()
                                handleStatus = .unchecked
                            }
                        )
                    )
                    .textContentType(.nickname)
                    .keyboardType(.asciiCapable)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .font(Font.fmBody)
                    .foregroundStyle(FMColors.Text.primary)
                    .padding(.horizontal, Sp.sm)
                    .frame(height: 44)
                    .background(FMColors.Background.bg0, in: RoundedRectangle(cornerRadius: R.md))
                    .overlay {
                        RoundedRectangle(cornerRadius: R.md)
                            .strokeBorder(FMColors.Border.default, lineWidth: 1)
                    }
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
            FMTextField(
                "소개",
                text: $draft.bio,
                placeholder: "나를 소개해 주세요.",
                style: .multiline(minHeight: 96),
                submitLabel: .return
            )
                .accessibilityIdentifier("profile.edit.bio")
            FMTextField.url("링크", text: $draft.website, placeholder: "https://")
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

private extension UIImage {
    func normalizedJPEGData(maxDimension: CGFloat) -> Data? {
        let longest = max(size.width, size.height)
        let scale = longest > maxDimension ? maxDimension / longest : 1
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let rendered = renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return rendered.jpegData(compressionQuality: 0.82)
    }
}

struct UniversalLinkLandingScreen: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: MooditStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.lg) {
                workflowHeader(
                    title: "공유 링크",
                    subtitle: "링크를 열 수 없을 때 다음 이동 경로를 안내합니다.",
                    symbol: "link.badge.plus"
                )

                FMCard {
                    VStack(alignment: .center, spacing: Sp.md) {
                        FMEmptyStateIllustration(.search, size: 96)
                            .frame(width: 96, height: 96)

                        VStack(spacing: Sp.xs) {
                            Text("이 링크는 더 이상 사용할 수 없어요")
                                .fmTypography(.headline)
                                .foregroundStyle(FMColors.Text.primary)
                                .multilineTextAlignment(.center)
                            Text("잘못된 주소이거나 만료된 초대, 삭제된 필터 링크일 수 있어요. 마켓에서 필터를 다시 찾아보세요.")
                                .fmTypography(.body)
                                .foregroundStyle(FMColors.Text.secondary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("app.deeplink.fallback")
                }

                FMButton("마켓으로 이동", icon: "storefront", variant: .primary, size: .lg) {
                    dismiss()
                }
                .accessibilityIdentifier("app.deeplink.confirm")

                NavigationLink(value: AppRoute.search()) {
                    HStack(spacing: Sp.xs) {
                        Image(systemName: "magnifyingglass")
                        Text("검색으로 찾기")
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
    }
}

struct DataExportScreen: View {
    @EnvironmentObject private var store: MooditStore
    @Environment(\.openURL) private var openURL
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
                            if let downloadURL = request.downloadURL {
                                Button("다운로드") {
                                    openURL(downloadURL)
                                }
                                .fmTypography(.caption)
                                .foregroundStyle(FMColors.Accent.primary)
                                .accessibilityIdentifier("settings.export.download.\(request.id)")
                            } else {
                                Text(request.status)
                                    .fmTypography(.caption)
                                    .foregroundStyle(request.status == "만료" ? FMColors.Text.tertiary : FMColors.Accent.primary)
                            }
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

private struct EditorReferencePreview: View {
    @EnvironmentObject private var store: MooditStore
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
            } else {
                LinearGradient(
                    colors: store.editorDraft.category.swatch,
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

                Text(store.editorDraft.name.isEmpty ? "Untitled Filter" : store.editorDraft.name)
                    .fmTypography(.titleLarge)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .padding(Sp.md)

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
            category: store.editorDraft.category,
            sampleKind: store.editorReferenceSampleKind,
            referenceRevision: store.editorReferencePhotoRevision,
            lutRevision: store.editorImportedLUTRevision,
            exposure: quantized("exposure"),
            contrast: quantized("contrast"),
            saturation: quantized("saturation"),
            grain: quantized("grain"),
            vignette: quantized("vignette")
        )
    }

    private func quantized(_ key: String) -> Int {
        Int(((store.editorDraft.parameterValues[key] ?? 0) * 1_000).rounded())
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

        let sourceLUT = store.editorImportedLUT
            ?? LUT3D.preset(LUTPreset.preset(for: store.editorDraft.category), size: 33)
        let parameters = store.editorPreviewParameters
        let grain = store.editorPreviewGrain
        let vignette = store.editorPreviewVignette

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
        if let data = store.editorReferencePhotoData,
           let image = UIImage(data: data),
           let resized = EditorReferenceSampleImage.normalizedJPEGData(from: image, maxLongEdge: 800) {
            return resized
        }
        return EditorReferenceSampleImage.makeJPEGData(kind: store.editorReferenceSampleKind)
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
    @EnvironmentObject private var store: MooditStore
    @State private var showCancelAlert = false
    @State private var selectedReferenceItem: PhotosPickerItem?
    @State private var referenceLoadError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.lg) {
                editorPreview
                referenceSourceControls
                quickStats
                editorActions
                parameterPreview
            }
            .padding(Sp.md)
            .padding(.bottom, FMLayout.tabBarHeight + Sp.xxxl)
        }
        .background(FMColors.Background.bg1)
        .navigationTitle("필터 에디터")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("취소") { showCancelAlert = true }
                    .accessibilityIdentifier("editor.cancel")
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: AppRoute.editorDraft) {
                    Text("완료")
                        .fontWeight(.semibold)
                }
                .simultaneousGesture(TapGesture().onEnded {
                    store.saveEditorDraft()
                })
                .accessibilityIdentifier("editor.next")
            }
        }
        .fmConfirmationDialog(
            "작성 중인 내용",
            isPresented: $showCancelAlert
        ) {
            Button("임시 저장") {
                store.saveEditorDraft()
                dismiss()
            }
            Button("버리기", role: .destructive) {
                store.resetEditorDraft()
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
        EditorReferencePreview(height: 420)
    }

    @ViewBuilder
    private var referenceSourceControls: some View {
        let hasReferencePhoto = store.editorReferencePhotoData != nil
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
                        store.setEditorReferencePhotoData(nil)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(FMColors.Text.tertiary)
                    }
                    .accessibilityIdentifier("editor.reference.photo.clear")
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Sp.xs) {
                    ForEach(EditorReferenceSampleKind.allCases) { kind in
                        FMChip(
                            kind.title,
                            isSelected: !hasReferencePhoto && store.editorReferenceSampleKind == kind,
                            size: .sm
                        ) {
                            store.setEditorReferenceSampleKind(kind)
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
            store.setEditorReferencePhotoData(normalized)
            referenceLoadError = nil
            FMHaptic.success.play()
        } catch {
            referenceLoadError = "사진을 불러오지 못했어요."
            FMHaptic.error.play()
        }
    }

    private var quickStats: some View {
        HStack(spacing: Sp.sm) {
            editorMetric("LUT", value: store.editorDraft.lutFileName ?? "기본")
            editorMetric("커버", value: "\(store.editorDraft.coverCount)장")
            editorMetric("태그", value: "\(store.editorDraft.tags.count)개")
        }
    }

    private var editorActions: some View {
        VStack(spacing: Sp.sm) {
            NavigationLink(value: AppRoute.editorParameters) {
                routeButton("파라미터 편집", icon: "slider.horizontal.3")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("editor.params")

            HStack(spacing: Sp.sm) {
                NavigationLink(value: AppRoute.editorLUT) {
                    compactRouteButton("LUT", icon: "cube.transparent")
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("editor.lut")

                NavigationLink(value: AppRoute.editorDraft) {
                    compactRouteButton("초안 저장", icon: "tray.and.arrow.down")
                }
                .simultaneousGesture(TapGesture().onEnded {
                    store.saveEditorDraft()
                })
                .buttonStyle(.plain)
                .accessibilityIdentifier("editor.draft")
            }

            NavigationLink(value: AppRoute.uploadCover) {
                routeButton("마켓 공유로 계속", icon: "arrow.right")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("editor.next")
        }
    }

    private var parameterPreview: some View {
        FMCard {
            VStack(alignment: .leading, spacing: Sp.sm) {
                sectionLabel("주요 파라미터")
                ForEach(["exposure", "contrast", "saturation"], id: \.self) { key in
                    HStack {
                        Text(parameterTitle(key))
                            .fmTypography(.body)
                            .foregroundStyle(FMColors.Text.primary)
                        Spacer()
                        Text("\(Int((store.editorDraft.parameterValues[key] ?? 0) * 100))")
                            .fmTypography(.headline)
                            .foregroundStyle(FMColors.Accent.primary)
                    }
                    if key != "saturation" {
                        workflowDivider()
                    }
                }
            }
        }
    }

    private func editorMetric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .fmTypography(.caption)
                .foregroundStyle(FMColors.Text.tertiary)
            Text(value)
                .fmTypography(.headline)
                .foregroundStyle(FMColors.Text.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Sp.sm)
        .background(FMColors.Background.bg2, in: RoundedRectangle(cornerRadius: R.md))
    }
}

struct EditorParametersScreen: View {
    @EnvironmentObject private var store: MooditStore
    @State private var selectedSection: EditorParameterSection = .lighting

    private let parameters = ["exposure", "contrast", "saturation", "grain", "vignette"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.lg) {
                workflowHeader(
                    title: "파라미터",
                    subtitle: "조명, 색, 질감 값을 조정해 필터 룩을 만듭니다.",
                    symbol: "slider.horizontal.3"
                )
                EditorReferencePreview(height: 300)
                sectionTabs
                sliders
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
                    FMChip(section.title, isSelected: selectedSection == section, size: .sm) {
                        selectedSection = section
                    }
                    .accessibilityIdentifier(section.actionID)
                }
            }
        }
    }

    private var sliders: some View {
        FMCard {
            VStack(spacing: Sp.md) {
                ForEach(parameters, id: \.self) { key in
                    FMSlider(
                        value: Binding(
                            get: { store.editorDraft.parameterValues[key] ?? 0 },
                            set: { store.updateEditorParameter(key, value: $0) }
                        ),
                        range: -1...1,
                        label: parameterTitle(key),
                        valueFormatter: parameterValueLabel
                    )
                    .accessibilityIdentifier("editor.param.slider.\(key)")
                }
            }
            .accessibilityIdentifier("editor.param.slider")
        }
    }

    private func parameterValueLabel(_ value: Double) -> String {
        if abs(value) < 0.0001 {
            return "원본"
        }
        return String(format: "%+.2f", value)
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
    @EnvironmentObject private var store: MooditStore
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
            store.setEditorLUT(url.lastPathComponent, lut: previewLUT(from: parsed))
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
                        Text(store.editorDraft.lutFileName ?? "LUT 파일 없음")
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
        FMCard {
            VStack(alignment: .leading, spacing: Sp.sm) {
                sectionLabel("검증")
                validationRow("파일 형식", value: store.editorDraft.lutFileName == nil ? "검증 전" : "Cube LUT", isPassed: store.editorDraft.lutFileName != nil)
                workflowDivider()
                validationRow("권장 크기", value: "33x33x33", isPassed: store.editorDraft.lutFileName != nil)
                workflowDivider()
                validationRow("색공간", value: store.editorDraft.lutFileName == nil ? "검증 전" : "sRGB", isPassed: store.editorDraft.lutFileName != nil)
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
    @EnvironmentObject private var store: MooditStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.lg) {
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
    }

    private var draftForm: some View {
        VStack(spacing: Sp.md) {
            FMTextField(
                "필터 이름",
                text: $store.editorDraft.name,
                placeholder: "Amber Cafe",
                autocapitalization: .words,
                submitLabel: .next
            )
                .accessibilityIdentifier("editor.draft.name")
            FMTextField(
                "설명",
                text: $store.editorDraft.summary,
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
                    Text(store.editorDraft.category.displayTitle)
                    Spacer()
                    Text(store.editorDraft.lutFileName ?? "기본 LUT")
                }
                .fmTypography(.subhead)
                .foregroundStyle(FMColors.Text.secondary)
                workflowDivider()
                Text(store.editorDraft.tags.map { "#\($0)" }.joined(separator: " "))
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
                store.saveEditorDraft()
            })
            .buttonStyle(.plain)
            .accessibilityIdentifier("editor.draft.save")

            NavigationLink(value: AppRoute.uploadCover) {
                routeButton("바로 마켓 공유", icon: "paperplane")
            }
            .simultaneousGesture(TapGesture().onEnded {
                store.saveEditorDraft()
            })
            .buttonStyle(.plain)
            .accessibilityIdentifier("editor.draft.publish")
        }
    }
}

struct UploadCoverScreen: View {
    @EnvironmentObject private var store: MooditStore
    @Environment(\.dismiss) private var dismiss
    @State private var showCancelAlert = false
    @State private var selectedSignatureItem: PhotosPickerItem?
    @State private var signatureLoadError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.lg) {
                uploadProgress(active: .cover)
                workflowHeader(
                    title: "표지 사진 선택",
                    subtitle: "마켓 카드와 상세 화면에서 보일 샘플 이미지를 고릅니다.",
                    symbol: "photo.on.rectangle"
                )
                coverGrid
                signatureSampleSection
                Toggle("자동 비포/애프터 생성", isOn: $store.editorDraft.beforeAfterEnabled)
                    .tint(FMColors.Accent.primary)
                    .padding(Sp.md)
                    .background(FMColors.Background.bg2, in: RoundedRectangle(cornerRadius: R.md))
                    .accessibilityIdentifier("upload.cover.ba.toggle")
                NavigationLink(value: AppRoute.uploadTags) {
                    routeButton("다음", icon: "arrow.right")
                }
                .simultaneousGesture(TapGesture().onEnded {
                    store.saveCurrentUploadDraftIfNeeded()
                })
                .buttonStyle(.plain)
                .accessibilityIdentifier("upload.next")
            }
            .padding(Sp.md)
            .padding(.bottom, FMLayout.tabBarHeight + Sp.xxxl)
        }
        .background(FMColors.Background.bg1)
        .navigationTitle("커버 업로드")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("취소") { showCancelAlert = true }
                    .accessibilityIdentifier("upload.cancel")
            }
        }
        .alert("업로드를 취소할까요?", isPresented: $showCancelAlert) {
            Button("초안 저장하고 나가기") {
                store.saveEditorDraft()
                dismiss()
            }
            Button("초안 버리고 나가기", role: .destructive) {
                store.resetEditorDraft()
                dismiss()
            }
            Button("계속 작성", role: .cancel) {}
        } message: {
            Text("작성한 내용을 임시저장하면 다음에 이어 쓸 수 있어요.")
        }
        .onChange(of: selectedSignatureItem) { _, item in
            Task { await loadSignatureSample(from: item) }
        }
        .onDisappear {
            store.saveCurrentUploadDraftIfNeeded()
        }
    }

    private var coverGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Sp.sm) {
            ForEach(0..<store.editorDraft.coverCount, id: \.self) { index in
                coverTile(index: index)
            }
            Button {
                store.addUploadCover()
            } label: {
                VStack(spacing: Sp.xs) {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .semibold))
                    Text("사진 추가")
                        .fmTypography(.caption)
                }
                .foregroundStyle(FMColors.Accent.primary)
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .background(FMColors.Accent.bg, in: RoundedRectangle(cornerRadius: R.md))
                .overlay {
                    RoundedRectangle(cornerRadius: R.md)
                        .strokeBorder(FMColors.Accent.primary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [5]))
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("upload.cover.add")
        }
    }

    private func coverTile(index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: R.md)
                .fill(LinearGradient(colors: store.editorDraft.category.swatch, startPoint: .topLeading, endPoint: .bottomTrailing))
                .aspectRatio(1, contentMode: .fit)
            Button {
                store.removeUploadCover()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(.black.opacity(0.35), in: Circle())
                    .padding(Sp.xs)
            }
            .accessibilityIdentifier("upload.cover.remove")
        }
    }

    @ViewBuilder
    private var signatureSampleSection: some View {
        let hasSample = hasSignatureSample
        VStack(alignment: .leading, spacing: Sp.sm) {
            HStack(alignment: .firstTextBaseline) {
                sectionLabel("시그니처 샘플")
                Spacer()
                if hasSample {
                    Button("지우기") {
                        store.clearUploadSignatureSample()
                    }
                    .fmTypography(.caption)
                    .foregroundStyle(FMColors.Text.tertiary)
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

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Sp.xs) {
                            ForEach(EditorReferenceSampleKind.allCases) { kind in
                                FMChip(
                                    kind.title,
                                    isSelected: store.editorDraft.signatureSampleKind == kind
                                        && store.editorDraft.signatureSamplePhotoData == nil,
                                    size: .sm
                                ) {
                                    store.setUploadSignatureSampleKind(kind)
                                }
                                .accessibilityIdentifier("upload.signature.sample.\(kind.rawValue)")
                            }
                        }
                    }

                    Text("직접 올린 1장 또는 임시 샘플 1장을 상세 갤러리 첫 슬롯 기준으로 사용합니다.")
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

    private var hasSignatureSample: Bool {
        store.editorDraft.signatureSamplePhotoData != nil || store.editorDraft.signatureSampleKind != nil
    }

    private var signaturePreview: some View {
        ZStack {
            if let image = signaturePreviewImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: store.editorDraft.category.swatch,
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
        if let data = store.editorDraft.signatureSamplePhotoData {
            return UIImage(data: data)
        }
        if let kind = store.editorDraft.signatureSampleKind {
            return UIImage(data: EditorReferenceSampleImage.makeJPEGData(kind: kind))
        }
        return nil
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
            store.setUploadSignatureSampleData(normalized)
            signatureLoadError = nil
        } catch {
            signatureLoadError = "사진을 불러오지 못했어요."
        }
    }
}

struct UploadTagsCategoryScreen: View {
    @EnvironmentObject private var store: MooditStore
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
                    store.saveCurrentUploadDraftIfNeeded()
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("취소") { showCancelAlert = true }
                    .accessibilityIdentifier("upload.cancel")
            }
        }
        .alert("업로드를 취소할까요?", isPresented: $showCancelAlert) {
            Button("초안 저장하고 나가기") {
                store.saveCurrentUploadDraftIfNeeded()
                dismiss()
            }
            Button("초안 버리고 나가기", role: .destructive) {
                store.resetEditorDraft()
                dismiss()
            }
            Button("계속 작성", role: .cancel) {}
        } message: {
            Text("작성한 내용을 임시저장하면 다음에 이어 쓸 수 있어요.")
        }
        .onDisappear {
            store.saveCurrentUploadDraftIfNeeded()
        }
    }

    private var tagSection: some View {
        VStack(alignment: .leading, spacing: Sp.sm) {
            sectionLabel("태그")
            FMCard {
                VStack(alignment: .leading, spacing: Sp.sm) {
                    WorkflowFlowLayout(spacing: Sp.xs) {
                        ForEach(store.editorDraft.tags, id: \.self) { tag in
                            Button {
                                store.removeUploadTag(tag)
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
                            store.addUploadTag(pendingTag)
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
                    FMChip(category.displayTitle, isSelected: store.editorDraft.category == category, size: .sm) {
                        store.setUploadCategory(category)
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
            text: $store.editorDraft.summary,
            placeholder: "이 필터의 분위기와 추천 사용처",
            style: .multiline(minHeight: 112),
            submitLabel: .return
        )
    }
}

struct UploadTOSSubmitScreen: View {
    @EnvironmentObject private var store: MooditStore
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
                    store.submitCurrentDraft()
                })
                .buttonStyle(.plain)
                .disabled(!store.editorDraft.isReadyForSubmit)
                .accessibilityIdentifier("upload.submit")
            }
            .padding(Sp.md)
            .padding(.bottom, FMLayout.tabBarHeight + Sp.xxxl)
        }
        .background(FMColors.Background.bg1)
        .navigationTitle("약관 및 제출")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("취소") { showCancelAlert = true }
                    .accessibilityIdentifier("upload.cancel")
            }
        }
        .alert("업로드를 취소할까요?", isPresented: $showCancelAlert) {
            Button("초안 저장하고 나가기") {
                store.saveCurrentUploadDraftIfNeeded()
                dismiss()
            }
            Button("초안 버리고 나가기", role: .destructive) {
                store.resetEditorDraft()
                dismiss()
            }
            Button("계속 작성", role: .cancel) {}
        } message: {
            Text("작성한 내용을 임시저장하면 다음에 이어 쓸 수 있어요.")
        }
        .onDisappear {
            store.saveCurrentUploadDraftIfNeeded()
        }
    }

    private var summaryCard: some View {
        FMCard {
            VStack(alignment: .leading, spacing: Sp.sm) {
                sectionLabel("제출 요약")
                summaryRow("이름", value: store.editorDraft.name)
                workflowDivider()
                summaryRow("카테고리", value: store.editorDraft.category.displayTitle)
                workflowDivider()
                summaryRow("커버", value: "\(store.editorDraft.coverCount)장")
                workflowDivider()
                summaryRow("시그니처 샘플", value: signatureSummary)
                workflowDivider()
                summaryRow("태그", value: store.editorDraft.tags.map { "#\($0)" }.joined(separator: " "))
            }
        }
    }

    private var signatureSummary: String {
        if store.editorDraft.signatureSamplePhotoData != nil {
            return "직접 선택"
        }
        if let kind = store.editorDraft.signatureSampleKind {
            return kind.title
        }
        return "없음"
    }

    private var tosCard: some View {
        FMCard {
            VStack(spacing: 0) {
                Toggle("직접 만들었거나 사용 권한이 있습니다", isOn: $store.editorDraft.tosOriginal)
                    .tint(FMColors.Accent.primary)
                workflowDivider()
                Toggle("마켓 정책과 심사 기준을 확인했습니다", isOn: $store.editorDraft.tosPolicy)
                    .tint(FMColors.Accent.primary)
                workflowDivider()
                Toggle("상업적 배포 권한을 확인했습니다", isOn: $store.editorDraft.tosCommercial)
                    .tint(FMColors.Accent.primary)
            }
            .accessibilityIdentifier("upload.tos.toggle")
        }
    }

    private func summaryRow(_ title: String, value: String) -> some View {
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
}

struct UploadPendingReviewScreen: View {
    @EnvironmentObject private var store: MooditStore
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
                    summaryRow("필터", value: store.editorDraft.name)
                    workflowDivider()
                    summaryRow("상태", value: "검수중")
                    workflowDivider()
                    summaryRow("제출", value: workflowDateString(store.editorDraft.submittedAt ?? Date()))
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

    private func summaryRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .fmTypography(.subhead)
                .foregroundStyle(FMColors.Text.secondary)
            Spacer()
            Text(value)
                .fmTypography(.subhead)
                .foregroundStyle(FMColors.Text.primary)
        }
    }
}

// FilterRejectedScreen — `Sources/App/Moderation/FilterRejectedScreen.swift`

struct MyFiltersScreen: View {
    @EnvironmentObject private var store: MooditStore
    @State private var selectedDraft: MakerFilterDraft?
    @State private var showTakedownAlert = false

    private var visibleFilters: [MakerFilterDraft] {
        store.selectedMakerStatus == .all
            ? store.makerFilters
            : store.makerFilters.filter { $0.status == store.selectedMakerStatus }
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
                store.resetEditorDraft()
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
                    store.markMakerFilterPrivate(selectedDraft)
                }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("마켓 노출이 중지되고 초안 상태로 돌아갑니다.")
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
                    FMChip("\(status.title) \(count(for: status))", isSelected: store.selectedMakerStatus == status, size: .sm) {
                        store.selectedMakerStatus = status
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

                HStack(spacing: Sp.sm) {
                    NavigationLink(value: draft.status == .rejected ? AppRoute.filterRejected(id: draft.name) : AppRoute.editor) {
                        compactRouteButton(draft.status == .rejected ? "검수 결과" : "수정", icon: draft.status == .rejected ? "doc.text" : "slider.horizontal.3")
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        store.startEditing(draft)
                    })
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(draft.status == .rejected ? "mod.rejected.review" : "myfilters.row.edit")

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
        status == .all ? store.makerFilters.count : store.makerFilters.filter { $0.status == status }.count
    }
}

struct RemixFlowScreen: View {
    @EnvironmentObject private var store: MooditStore
    @Environment(\.dismiss) private var dismiss

    /// Parent filter — read from the store's currently selected filter so the
    /// remix flow inherits whatever the user was just looking at. Falls back
    /// to the first downloaded filter if nothing is selected (rare in practice
    /// since the entry point is FilterDetail's "리믹스" action).
    private var parent: Filter? {
        store.selectedFilter ?? store.libraryFilters.first ?? store.filters.first
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
        store.resetEditorDraft()
        store.editorDraft.name = "\(parentName) Remix"
        var seedTags: [String] = ["remix"]
        if let parent {
            seedTags.append(parent.category.rawValue.lowercased())
        }
        store.editorDraft.tags = seedTags
        FMHaptic.light.play()
    }
}

// MARK: - Social / Discovery

// NotificationsInboxScreen — `Sources/App/Notifications/NotificationsInboxScreen.swift`

struct NotificationSettingsScreen: View {
    @EnvironmentObject private var store: MooditStore
    @Environment(\.openURL) private var openURL
    @State private var systemAuthorizationStatus: UNAuthorizationStatus?

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
        .task {
            await refreshSystemAuthorizationStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task {
                await refreshSystemAuthorizationStatus()
            }
        }
    }

    private var systemCard: some View {
        FMCard {
            HStack(alignment: .top, spacing: Sp.sm) {
                Image(systemName: systemPermissionIcon)
                    .font(.system(size: IconSize.md, weight: .semibold))
                    .foregroundStyle(FMColors.Accent.primary)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 4) {
                    Text(systemPermissionTitle)
                        .fmTypography(.headline)
                        .foregroundStyle(FMColors.Text.primary)
                    Text(systemPermissionDetail)
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
                    preferenceToggle("소셜", detail: "팔로우, 좋아요, 메이커 활동", isOn: preferenceBinding(\.social))
                    workflowDivider()
                    preferenceToggle("리뷰 알림", detail: "내 필터에 새 리뷰 또는 메이커 답글이 달릴 때", isOn: preferenceBinding(\.reviews))
                    workflowDivider()
                    preferenceToggle("마켓", detail: "추천 필터, 컬렉션 업데이트", isOn: preferenceBinding(\.marketplace))
                    workflowDivider()
                    preferenceToggle("메이커", detail: "업로드한 필터의 검수 완료 알림", isOn: preferenceBinding(\.creator))
                    workflowDivider()
                    preferenceToggle("지갑과 결제", detail: "구매, 환불, 정산 상태", isOn: preferenceBinding(\.wallet))
                    workflowDivider()
                    preferenceToggle("제품 소식", detail: "새 기능과 이벤트", isOn: preferenceBinding(\.product))
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
                        isOn: preferenceBinding(\.quietHoursEnabled)
                    )
                    .accessibilityIdentifier("notif.quiet.toggle")
                    workflowDivider()
                    quietRow("시작", value: store.notificationPreferences.quietStart) {
                        store.setNotificationPreference(
                            \.quietStart,
                            to: nextQuietStart(after: store.notificationPreferences.quietStart)
                        )
                    }
                    workflowDivider()
                    quietRow("종료", value: store.notificationPreferences.quietEnd) {
                        store.setNotificationPreference(
                            \.quietEnd,
                            to: nextQuietEnd(after: store.notificationPreferences.quietEnd)
                        )
                    }
                }
            }
        }
    }

    private var systemPermissionIcon: String {
        switch systemAuthorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return "bell.fill"
        case .denied:
            return "bell.slash"
        case .notDetermined:
            return "bell.badge"
        case nil:
            return "bell"
        @unknown default:
            return "bell"
        }
    }

    private var systemPermissionTitle: String {
        switch systemAuthorizationStatus {
        case .authorized:
            return "시스템 알림 — 허용됨"
        case .provisional, .ephemeral:
            return "시스템 알림 — 임시 허용됨"
        case .denied:
            return "시스템 알림 — 차단됨"
        case .notDetermined:
            return "시스템 알림 — 권한 미결정"
        case nil:
            return "시스템 알림 — 확인 중"
        @unknown default:
            return "시스템 알림 — 확인 필요"
        }
    }

    private var systemPermissionDetail: String {
        switch systemAuthorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return "잠금화면, 배지, 소리는 iOS 설정에서 허용되어 있습니다."
        case .denied:
            return "푸시 알림을 받으려면 iOS 설정에서 moodit 알림을 허용해야 합니다."
        case .notDetermined:
            return "아직 iOS 알림 권한을 요청하지 않았습니다."
        case nil:
            return "iOS 알림 권한 상태를 확인하고 있습니다."
        @unknown default:
            return "iOS 설정에서 알림 권한 상태를 확인해 주세요."
        }
    }

    private func preferenceBinding(_ keyPath: WritableKeyPath<NotificationPreferences, Bool>) -> Binding<Bool> {
        Binding(
            get: { store.notificationPreferences[keyPath: keyPath] },
            set: { store.setNotificationPreference(keyPath, to: $0) }
        )
    }

    private func refreshSystemAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        systemAuthorizationStatus = settings.authorizationStatus
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

// MARK: - Safety / Moderation

struct ReportFormScreen: View {
    @Environment(\.dismiss) private var dismiss
    let target: ReportTarget

    @State private var reasonCode: String = "spam"
    @State private var detail: String = ""
    @State private var isProcessing = false
    @State private var statusMessage: String?

    private let reasonOptions: [(code: String, label: String)] = [
        ("spam", "스팸 / 무의미한 콘텐츠"),
        ("nsfw", "성적/노출 콘텐츠"),
        ("violence", "폭력 / 잔혹 콘텐츠"),
        ("hate", "혐오 발언"),
        ("ip", "저작권 침해"),
        ("other", "기타")
    ]

    var body: some View {
        Form {
            Section(header: Text("신고 대상")) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(targetTitle)
                        .font(Font.fmBody)
                        .foregroundStyle(FMColors.Text.primary)
                    Text(targetSubtitle)
                        .font(Font.fmCaption)
                        .foregroundStyle(FMColors.Text.tertiary)
                }
                .textSelection(.enabled)
                .accessibilityIdentifier("report.target")
            }
            Section(header: Text("사유")) {
                Picker("사유 선택", selection: $reasonCode) {
                    ForEach(reasonOptions, id: \.code) { opt in
                        Text(opt.label).tag(opt.code)
                    }
                }
                .accessibilityIdentifier("report.reason")
            }
            Section(header: Text("상세 설명 (선택)")) {
                TextEditor(text: $detail).frame(minHeight: 100)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.return)
                    .accessibilityIdentifier("report.detail")
            }
            if let statusMessage {
                Section { Text(statusMessage).foregroundStyle(FMColors.Text.secondary) }
            }
            Section {
                Button {
                    Task { await submit() }
                } label: {
                    if isProcessing { ProgressView() } else { Text("신고 제출") }
                }
                .disabled(isProcessing || !target.isSubmittable)
                .accessibilityIdentifier("report.submit")
            }
        }
        .navigationTitle("신고")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var targetTitle: String {
        switch target {
        case .filter:
            return "필터 신고"
        case .review:
            return "리뷰 신고"
        case .user:
            return "사용자 신고"
        }
    }

    private var targetSubtitle: String {
        switch target {
        case .filter(let id):
            return id.isEmpty ? "신고 대상 필터가 지정되지 않았습니다." : "필터 ID: \(id)"
        case .review(let id, let filterId, let authorUid):
            let author = authorUid.map { " · 작성자 \($0)" } ?? ""
            return "필터 \(filterId) · 리뷰 \(id)\(author)"
        case .user(let uid):
            return uid.isEmpty ? "신고 대상 사용자가 지정되지 않았습니다." : "사용자 UID: \(uid)"
        }
    }

    private func submit() async {
        isProcessing = true
        defer { isProcessing = false }
        do {
            let functions = Functions.functions(region: "asia-northeast3")
            let trimmedDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
            switch target {
            case .filter(let id):
                let callable = functions.httpsCallable("reportFilter")
                _ = try await callable.call([
                    "filterId": id,
                    "reasonCode": reasonCode,
                    "detail": trimmedDetail
                ])
            case .review(let id, let filterId, let authorUid):
                let callable = functions.httpsCallable("reportReview")
                var payload: [String: Any] = [
                    "filterId": filterId,
                    "reviewId": id,
                    "reasonCode": reasonCode,
                    "detail": trimmedDetail
                ]
                if let authorUid {
                    payload["authorUid"] = authorUid
                }
                _ = try await callable.call(payload)
            case .user(let uid):
                let callable = functions.httpsCallable("reportUser")
                _ = try await callable.call([
                    "targetUid": uid,
                    "reasonCode": reasonCode,
                    "detail": trimmedDetail
                ])
            }
            statusMessage = "신고가 접수되었습니다. 24시간 내 검토합니다."
            detail = ""
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            dismiss()
        } catch {
            statusMessage = "오류: \(error.localizedDescription)"
        }
    }
}

struct ModerationQueueScreen: View {
    @State private var pendingFilters: [Models.Filter] = []
    @State private var isLoading = false
    @State private var listener: ListenerRegistration?

    var body: some View {
        Group {
            if pendingFilters.isEmpty {
                FMEmptyState(.emptyMarket)
                    .padding(.horizontal, Sp.md)
                    .accessibilityIdentifier("modqueue.empty")
            } else {
                List(pendingFilters) { filter in
                    NavigationLink(value: AppRoute.modDetail(id: filter.id.uuidString)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(filter.title).font(Font.fmHeadline)
                            Text(filter.author.displayName).font(Font.fmCaption)
                                .foregroundStyle(FMColors.Text.secondary)
                            if let createdAt = filter.createdAt {
                                Text(createdAt, style: .date)
                                    .font(Font.fmCaption).foregroundStyle(FMColors.Text.tertiary)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable { await load() }
            }
        }
        .background(FMColors.Background.bg1.ignoresSafeArea())
        .navigationTitle("검수 큐")
        .navigationBarTitleDisplayMode(.inline)
        .task { attachListener() }
        .onDisappear {
            listener?.remove()
            listener = nil
        }
    }

    private func load() async {
        #if DEBUG
        guard !isUITesting else { return }
        #endif
        isLoading = true
        defer { isLoading = false }
        do {
            let snapshot = try await Firestore.firestore()
                .collection("filters")
                .whereField("status", isEqualTo: "pending_review")
                .order(by: "createdAt", descending: true)
                .limit(to: 100)
                .getDocuments()
            pendingFilters = snapshot.documents.compactMap { FirestoreFilterRepository.decode($0) }
        } catch {
            pendingFilters = []
        }
    }

    private func attachListener() {
        #if DEBUG
        guard !isUITesting else { return }
        #endif
        listener?.remove()
        isLoading = true
        listener = Firestore.firestore()
            .collection("filters")
            .whereField("status", isEqualTo: "pending_review")
            .order(by: "createdAt", descending: true)
            .limit(to: 100)
            .addSnapshotListener { snapshot, _ in
                let filters = snapshot?.documents.compactMap { FirestoreFilterRepository.decode($0) } ?? []
                Task { @MainActor in
                    pendingFilters = filters
                    isLoading = false
                }
            }
    }
}

struct ModerationDetailScreen: View {
    let itemID: String

    @Environment(\.dismiss) private var dismiss
    @State private var filter: Models.Filter?
    @State private var filterDescription: String?
    @State private var isProcessing = false
    @State private var isLoading = false
    @State private var hasCompletedAction = false
    @State private var statusMessage: String?
    @State private var rejectReason: String = ""
    @State private var lastAction: ModerationAction?
    @State private var dismissTask: Task<Void, Never>?

    var body: some View {
        Form {
            if isLoading {
                Section {
                    HStack {
                        ProgressView()
                        Text("검수 정보를 불러오는 중")
                            .foregroundStyle(FMColors.Text.secondary)
                    }
                }
            }

            if let filter {
                previewSection(filter)
                metadataSection(filter)
                engineSection(filter)
            } else {
                Section(header: Text("필터 정보")) {
                    Text(itemID.isEmpty ? "필터 ID가 없습니다." : "필터 정보를 불러올 수 없습니다.")
                        .foregroundStyle(FMColors.Text.secondary)
                }
            }

            Section(header: Text("필터 ID")) {
                Text(itemID).font(Font.fmCaption).foregroundStyle(FMColors.Text.secondary)
            }
            Section {
                Button {
                    Task { await approve() }
                } label: {
                    if isProcessing { ProgressView() } else { Text("승인 (Approve)") }
                }
                .disabled(itemID.isEmpty || filter == nil || isProcessing || hasCompletedAction)
                .accessibilityIdentifier("modDetail.approve")
            }
            Section(header: Text("거부 사유")) {
                TextEditor(text: $rejectReason).frame(minHeight: 80)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.return)
                    .accessibilityIdentifier("modDetail.reason")
                Button {
                    Task { await reject() }
                } label: {
                    if isProcessing { ProgressView() } else { Text("거부 (Reject)").foregroundStyle(FMColors.Semantic.error) }
                }
                .disabled(itemID.isEmpty || filter == nil || rejectReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing || hasCompletedAction)
                .accessibilityIdentifier("modDetail.reject")
            }
            if let statusMessage {
                Section {
                    Text(statusMessage).foregroundStyle(FMColors.Text.secondary)
                    if lastAction != nil {
                        Button("되돌리기") {
                            Task { await undoLastAction() }
                        }
                        .disabled(isProcessing)
                        .accessibilityIdentifier("modDetail.undo")
                    }
                }
            }
        }
        .navigationTitle("검수 상세")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadDetail() }
        .onDisappear {
            dismissTask?.cancel()
            dismissTask = nil
        }
    }

    private func approve() async {
        isProcessing = true
        defer { isProcessing = false }
        do {
            let callable = Functions.functions(region: "asia-northeast3").httpsCallable("approveFilter")
            _ = try await callable.call(["filterId": itemID])
            completeAction(.approved)
        } catch {
            statusMessage = "오류: \(error.localizedDescription)"
        }
    }

    private func reject() async {
        isProcessing = true
        defer { isProcessing = false }
        do {
            let callable = Functions.functions(region: "asia-northeast3").httpsCallable("rejectFilter")
            let reason = rejectReason.trimmingCharacters(in: .whitespacesAndNewlines)
            _ = try await callable.call(["filterId": itemID, "reason": reason])
            completeAction(.rejected)
            rejectReason = ""
        } catch {
            statusMessage = "오류: \(error.localizedDescription)"
        }
    }

    private func undoLastAction() async {
        dismissTask?.cancel()
        dismissTask = nil
        isProcessing = true
        defer { isProcessing = false }
        do {
            let callable = Functions.functions(region: "asia-northeast3").httpsCallable("undoModerationDecision")
            _ = try await callable.call(["filterId": itemID])
            hasCompletedAction = false
            lastAction = nil
            statusMessage = "되돌렸습니다. 다시 검수할 수 있습니다."
            await loadDetail()
        } catch {
            statusMessage = "되돌리기 실패: \(error.localizedDescription)"
            scheduleDismiss()
        }
    }

    private func completeAction(_ action: ModerationAction) {
        hasCompletedAction = true
        lastAction = action
        statusMessage = "\(action.label) 완료. 5초 안에 되돌릴 수 있습니다."
        scheduleDismiss()
    }

    private func scheduleDismiss() {
        dismissTask?.cancel()
        dismissTask = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { dismiss() }
        }
    }

    private func loadDetail() async {
        #if DEBUG
        guard !isUITesting else { return }
        #endif
        guard !itemID.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let snapshot = try await Firestore.firestore()
                .collection("filters").document(itemID)
                .getDocument()
            filter = FirestoreFilterRepository.decode(snapshot)
            filterDescription = snapshot.data()?["description"] as? String
                ?? snapshot.data()?["summary"] as? String
        } catch {
            statusMessage = "필터 정보 로드 실패: \(error.localizedDescription)"
        }
    }

    private func previewSection(_ filter: Models.Filter) -> some View {
        Section(header: Text("콘텐츠 미리보기")) {
            HStack(spacing: Sp.sm) {
                moderationPreviewTile(title: "커버", url: filter.coverURL, fallbackTitle: filter.title, category: filter.category.rawValue)
                moderationPreviewTile(title: "시그니처 샘플", url: filter.signatureSampleURL ?? filter.coverURL, fallbackTitle: filter.title, category: filter.category.rawValue)
            }
            if let filterDescription, !filterDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(filterDescription)
                    .font(Font.fmBody)
                    .foregroundStyle(FMColors.Text.primary)
            }
        }
    }

    private func metadataSection(_ filter: Models.Filter) -> some View {
        Section(header: Text("필터 메타데이터")) {
            moderationInfoRow("제목", filter.title)
            moderationInfoRow("메이커", "\(filter.author.displayName) · \(filter.author.uid)")
            moderationInfoRow("카테고리", filter.category.rawValue)
            moderationInfoRow("상태", filter.status.rawValue)
            moderationInfoRow("가격", filter.priceCoins > 0 ? "\(filter.priceCoins) 코인" : "무료")
            moderationInfoRow("다운로드", "\(filter.downloadCount > 0 ? filter.downloadCount : filter.useCount)")
            if let ratingAvg = filter.ratingAvg {
                moderationInfoRow("평점", String(format: "%.1f", ratingAvg))
            }
            if let createdAt = filter.createdAt {
                moderationInfoRow("제출일", createdAt.formatted(date: .abbreviated, time: .shortened))
            }
            if !filter.tags.isEmpty {
                Text(filter.tags.map { $0.hasPrefix("#") ? $0 : "#\($0)" }.joined(separator: " "))
                    .font(Font.fmCaption)
                    .foregroundStyle(FMColors.Text.secondary)
            }
        }
    }

    private func engineSection(_ filter: Models.Filter) -> some View {
        Section(header: Text("엔진 / 패키지")) {
            moderationInfoRow("엔진", filter.engine.type.rawValue)
            moderationInfoRow("버전", filter.version)
            moderationInfoRow("최소 앱", filter.engine.minAppVersion)
            moderationInfoRow("최소 iOS", filter.engine.minIOSVersion)
            if let lutSize = filter.engine.lutSize {
                moderationInfoRow("LUT", "\(lutSize)^3")
            }
            if let lutFile = filter.engine.lutFile, !lutFile.isEmpty {
                moderationInfoRow("LUT 파일", lutFile)
            }
        }
    }

    private func moderationInfoRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(Font.fmCaption)
                .foregroundStyle(FMColors.Text.tertiary)
            Spacer()
            Text(value)
                .font(Font.fmCaption)
                .foregroundStyle(FMColors.Text.primary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func moderationPreviewTile(title: String, url: URL?, fallbackTitle: String, category: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            FMRemoteImage(
                url: url,
                cornerRadius: R.md,
                placeholder: {
                    GeometryReader { proxy in
                        FMSkeleton.rect(height: proxy.size.height, cornerRadius: R.md)
                    }
                },
                failure: {
                    FMFilterCoverArt(motif: FilterCoverMotifResolver.motif(for: fallbackTitle, category: category))
                }
            )
            .frame(height: 120)
            .overlay {
                RoundedRectangle(cornerRadius: R.md)
                    .strokeBorder(FMColors.Border.subtle, lineWidth: 1)
            }

            Text(title)
                .font(Font.fmCaption)
                .foregroundStyle(FMColors.Text.secondary)
        }
    }
}

private enum ModerationAction {
    case approved
    case rejected

    var label: String {
        switch self {
        case .approved: "승인"
        case .rejected: "거부"
        }
    }
}

struct BlockListScreen: View {
    @State private var blockedUsers: [BlockedUserEntry] = []
    @State private var listener: ListenerRegistration?
    @State private var loadError: String?
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            if let loadError {
                VStack(alignment: .leading, spacing: Sp.sm) {
                    Text(loadError)
                        .font(Font.fmCaption)
                        .foregroundStyle(FMColors.Semantic.error)
                    Button("다시 시도") { attachListener() }
                        .font(Font.fmCaption)
                        .foregroundStyle(FMColors.Accent.primary)
                        .accessibilityIdentifier("blocklist.retry")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Sp.md)
            }

            if isLoading {
                ProgressView()
                    .padding(.top, Sp.lg)
            } else if blockedUsers.isEmpty {
                FMEmptyState(.emptyMarket)
                    .padding(.horizontal, Sp.md)
                    .accessibilityIdentifier("blocklist.empty")
            } else {
                List {
                    ForEach(blockedUsers) { user in
                        HStack {
                            Image(systemName: "person.crop.circle.badge.xmark")
                                .foregroundStyle(FMColors.Semantic.error)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.displayName).font(Font.fmBody)
                                Text(user.subtitle).font(Font.fmCaption)
                                    .foregroundStyle(FMColors.Text.tertiary)
                            }
                            Spacer()
                            Button("차단 해제") { unblock(user) }
                                .font(Font.fmCaption)
                                .foregroundStyle(FMColors.Accent.primary)
                                .accessibilityIdentifier("social.block.toggle")
                        }
                    }
                }
                .listStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .background(FMColors.Background.bg1.ignoresSafeArea())
        .navigationTitle("차단 목록")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { attachListener() }
        .onDisappear {
            listener?.remove()
            listener = nil
        }
    }

    private func attachListener() {
        #if DEBUG
        guard !isUITesting else {
            blockedUsers = []
            loadError = nil
            isLoading = false
            return
        }
        #endif
        listener?.remove()
        guard let uid = Auth.auth().currentUser?.uid else {
            blockedUsers = []
            loadError = "로그인 후 차단 목록을 볼 수 있어요."
            return
        }
        isLoading = true
        loadError = nil
        listener = Firestore.firestore()
            .collection("blocks")
            .whereField("actorUid", isEqualTo: uid)
            .limit(to: 200)
            .addSnapshotListener { snapshot, error in
                Task { @MainActor in
                    isLoading = false
                    if let error {
                        loadError = "차단 목록을 불러오지 못했어요: \(error.localizedDescription)"
                        return
                    }
                    loadError = nil
                    blockedUsers = (snapshot?.documents ?? [])
                        .compactMap(BlockedUserEntry.init(document:))
                        .sorted { $0.displayName < $1.displayName }
                }
            }
    }

    private func unblock(_ user: BlockedUserEntry) {
        #if DEBUG
        guard !isUITesting else {
            blockedUsers.removeAll { $0.id == user.id }
            return
        }
        #endif
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Task {
            do {
                try await Firestore.firestore()
                    .collection("blocks").document("\(uid)_\(user.targetUid)")
                    .delete()
            } catch {
                await MainActor.run {
                    loadError = "차단 해제에 실패했어요: \(error.localizedDescription)"
                }
            }
        }
    }
}

private struct BlockedUserEntry: Identifiable {
    let id: String
    let targetUid: String
    let handle: String?
    let displayName: String

    var subtitle: String {
        handle ?? targetUid
    }

    init?(document: QueryDocumentSnapshot) {
        let data = document.data()
        guard let targetUid = data["targetUid"] as? String, !targetUid.isEmpty else {
            return nil
        }
        self.id = document.documentID
        self.targetUid = targetUid
        let rawHandle = (data["targetHandle"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let rawHandle, !rawHandle.isEmpty {
            self.handle = rawHandle.hasPrefix("@") ? rawHandle : "@\(rawHandle)"
        } else {
            self.handle = nil
        }
        if let rawName = (data["targetDisplayName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !rawName.isEmpty {
            self.displayName = rawName
        } else {
            self.displayName = self.handle ?? String(targetUid.prefix(8))
        }
    }
}

// MARK: - Monetization

struct PaywallSingleScreen: View {
    let filterID: String

    @EnvironmentObject private var store: MooditStore
    @Environment(\.dismiss) private var dismiss

    @State private var filterTitle: String = "필터"
    @State private var priceCoins: Int = 0
    @State private var loadError: String?
    @State private var isProcessing = false
    @State private var purchaseError: String?
    @State private var showInsufficient = false
    @State private var didPurchase = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.lg) {
                titleSection
                priceCard
                cta
            }
            .padding(Sp.md)
        }
        .background(FMColors.Background.bg1.ignoresSafeArea())
        .navigationTitle("필터 구매")
        .navigationBarTitleDisplayMode(.inline)
        .alert("결제 오류", isPresented: errorBinding, actions: {
            Button("확인", role: .cancel) { purchaseError = nil }
        }, message: { Text(purchaseError ?? "") })
        .navigationDestination(isPresented: $showInsufficient) {
            InsufficientBalanceScreen(filterID: filterID, requiredCoins: priceCoins, currentBalance: store.coinBalance)
        }
        .navigationDestination(isPresented: $didPurchase) {
            FilterAfterDownloadScreen(filterID: filterID)
        }
        .task {
            store.subscribeToWallet()
            await loadFilterDetail()
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { purchaseError != nil }, set: { if !$0 { purchaseError = nil } })
    }

    @ViewBuilder
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: Sp.xs) {
            Text(filterTitle).font(Font.fmTitleLarge).foregroundStyle(FMColors.Text.primary)
            if let loadError {
                Text(loadError).font(Font.fmCaption).foregroundStyle(FMColors.Semantic.error)
            }
        }
    }

    @ViewBuilder
    private var priceCard: some View {
        VStack(alignment: .leading, spacing: Sp.sm) {
            HStack {
                Text("가격").font(Font.fmCaption).foregroundStyle(FMColors.Text.secondary)
                Spacer()
                Text(isIncludedWithPro ? "Pro 멤버십에 포함" : "\(priceCoins.formatted()) 코인")
                    .font(Font.fmHeadline)
                    .foregroundStyle(isIncludedWithPro ? FMColors.Accent.primary : FMColors.Text.primary)
            }
            Rectangle().fill(FMColors.Border.subtle).frame(height: 0.5)
            HStack {
                Text("현재 잔액").font(Font.fmCaption).foregroundStyle(FMColors.Text.secondary)
                Spacer()
                Text("\(store.coinBalance.formatted()) 코인")
                    .font(Font.fmHeadline)
                    .foregroundStyle(FMColors.Text.primary)
            }
            HStack {
                Text("결제 후 잔액").font(Font.fmCaption).foregroundStyle(FMColors.Text.secondary)
                Spacer()
                let after = isIncludedWithPro ? store.coinBalance : store.coinBalance - priceCoins
                Text(isIncludedWithPro ? "\(after.formatted()) 코인 · 차감 없음" : "\(after.formatted()) 코인")
                    .font(Font.fmCaption)
                    .foregroundStyle(after < 0 ? FMColors.Semantic.error : FMColors.Text.secondary)
            }
        }
        .padding(Sp.md)
        .background(FMColors.Background.bg2)
        .clipShape(RoundedRectangle(cornerRadius: R.lg))
    }

    @ViewBuilder
    private var cta: some View {
        VStack(spacing: Sp.sm) {
            FMButton(
                isIncludedWithPro ? "Pro로 다운로드" : "구매하기",
                icon: isIncludedWithPro ? "sparkles" : "circle.hexagongrid.circle.fill",
                variant: .primary,
                size: .lg,
                isLoading: isProcessing
            ) {
                Task { await purchase() }
            }
            .disabled(isProcessing || (priceCoins == 0 && !isIncludedWithPro))
            .accessibilityIdentifier("filter.purchase.confirm")

            NavigationLink(value: AppRoute.proSubscription) {
                HStack(spacing: Sp.xs) {
                    Image(systemName: "sparkles")
                    Text("Pro 멤버십 보기")
                        .font(Font.fmHeadline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(FMColors.Text.tertiary)
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
            .accessibilityIdentifier("filter.purchase.pro_upgrade")
        }
    }

    private var isIncludedWithPro: Bool {
        store.isProActive && priceCoins > 0
    }

    private func loadFilterDetail() async {
        if isUITesting {
            filterTitle = "테스트 필터"
            priceCoins = 120
            loadError = nil
            return
        }

        do {
            let detail = try await FilterDetailLoaderScreen.fetchDetail(filterId: filterID)
            filterTitle = detail.title
            priceCoins = detail.priceCoins
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func purchase() async {
        guard !isProcessing else { return }
        Telemetry.log(
            .filterPurchaseAttempted,
            parameters: ["filter_id": filterID, "price_coins": priceCoins, "pro_included": isIncludedWithPro]
        )
        if isIncludedWithPro {
            isProcessing = true
            defer { isProcessing = false }
            do {
                if let filter = store.filter(matching: filterID) {
                    try await store.download(filter)
                } else {
                    try await store.download(filterID: filterID)
                }
                Telemetry.log(
                    .filterPurchaseSucceeded,
                    parameters: ["filter_id": filterID, "price_coins": 0, "pro_included": true]
                )
                didPurchase = true
            } catch {
                Telemetry.log(.filterPurchaseFailed, parameters: ["filter_id": filterID, "reason": "pro_download_error"])
                Telemetry.record(error: error, context: ["where": "proIncludedDownload", "filter_id": filterID])
                purchaseError = error.localizedDescription
            }
            return
        }
        if store.coinBalance < priceCoins {
            Telemetry.log(.filterPurchaseInsufficient, parameters: ["filter_id": filterID, "price_coins": priceCoins, "balance": store.coinBalance])
            showInsufficient = true
            return
        }
        isProcessing = true
        defer { isProcessing = false }
        do {
            let callable = Functions.functions(region: "asia-northeast3").httpsCallable("purchaseFilter")
            _ = try await callable.call(["filterId": filterID])
            // (#31) 구매 성공 → 자동 다운로드 마크 + 잔액 차감 (낙관적). filterAfterDownload로 이동.
            store.creditCoinsOptimistically(-priceCoins)  // 음수 가산으로 차감
            if let filter = store.filter(matching: filterID) {
                try? await store.download(filter)
            }
            Telemetry.log(.filterPurchaseSucceeded, parameters: ["filter_id": filterID, "price_coins": priceCoins])
            didPurchase = true
        } catch let error as NSError where error.localizedDescription.contains("insufficient_balance") {
            Telemetry.log(.filterPurchaseInsufficient, parameters: ["filter_id": filterID, "price_coins": priceCoins])
            showInsufficient = true
        } catch {
            Telemetry.log(.filterPurchaseFailed, parameters: ["filter_id": filterID, "reason": "callable_error"])
            Telemetry.record(error: error, context: ["where": "purchaseFilter", "filter_id": filterID])
            purchaseError = error.localizedDescription
        }
    }
}

struct ProSubscriptionScreen: View {
    @EnvironmentObject private var store: MooditStore
    @StateObject private var storeKit = StoreKitManager()
    @Environment(\.dismiss) private var dismiss
    @State private var purchaseError: String?
    @State private var processingProductID: String?
    @State private var navigateToStatus = false
    @State private var selectedPlan: ProPlan = .yearly

    private enum ProPlan: String, CaseIterable, Identifiable {
        case monthly
        case yearly

        var id: String { rawValue }

        var title: String {
            switch self {
            case .monthly: "월간"
            case .yearly: "연간"
            }
        }

        var productID: String {
            switch self {
            case .monthly: IAPProductIDs.proMonthly
            case .yearly: IAPProductIDs.proYearly
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.lg) {
                header
                planToggle
                if isUITesting {
                    testSubscriptionList
                } else if storeKit.products.isEmpty {
                    if let lastError = storeKit.lastError {
                        Text(lastError).font(Font.fmCaption).foregroundStyle(FMColors.Semantic.error)
                    } else {
                        ProgressView().frame(maxWidth: .infinity)
                    }
                } else {
                    ForEach(orderedProducts, id: \.id) { product in
                        productCard(product: product)
                    }
                }
                invoiceLink
                policy
            }
            .padding(Sp.md)
        }
        .background(FMColors.Background.bg1.ignoresSafeArea())
        .navigationTitle("Pro 멤버십")
        .navigationBarTitleDisplayMode(.inline)
        .alert("결제 오류", isPresented: errorBinding, actions: {
            Button("확인", role: .cancel) { purchaseError = nil }
        }, message: { Text(purchaseError ?? "") })
        .navigationDestination(isPresented: $navigateToStatus) {
            ProStatusScreen()
        }
        .task {
            if storeKit.products.isEmpty {
                await storeKit.loadProducts(ids: IAPProductIDs.proIDs)
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { purchaseError != nil }, set: { if !$0 { purchaseError = nil } })
    }

    private var orderedProducts: [StoreKit.Product] {
        storeKit.products.sorted { lhs, rhs in
            if lhs.id == selectedPlan.productID { return true }
            if rhs.id == selectedPlan.productID { return false }
            return lhs.id < rhs.id
        }
    }

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: Sp.xs) {
            Label("Pro 혜택", systemImage: "sparkles")
                .font(Font.fmHeadline)
                .foregroundStyle(FMColors.Accent.primary)
            VStack(alignment: .leading, spacing: 4) {
                Text("• 광고 없이 사용").font(Font.fmBody)
                Text("• 메이커 분석 도구").font(Font.fmBody)
                Text("• Pro 전용 필터 무제한").font(Font.fmBody)
            }
            .foregroundStyle(FMColors.Text.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Sp.md)
        .background(FMColors.Background.bg2)
        .clipShape(RoundedRectangle(cornerRadius: R.lg))
    }

    @ViewBuilder
    private var planToggle: some View {
        Picker("플랜", selection: $selectedPlan) {
            ForEach(ProPlan.allCases) { plan in
                Text(plan.title).tag(plan)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("pro.plan.toggle")
    }

    @ViewBuilder
    private var testSubscriptionList: some View {
        VStack(spacing: Sp.sm) {
            testSubscriptionCard(productID: IAPProductIDs.proMonthly, title: "월간", subtitle: "월 단위로 결제", price: "테스트 KRW 4,900")
            testSubscriptionCard(productID: IAPProductIDs.proYearly, title: "연간", subtitle: "12개월 - 가장 합리적", price: "테스트 KRW 39,000")
        }
    }

    @ViewBuilder
    private func testSubscriptionCard(productID: String, title: String, subtitle: String, price: String) -> some View {
        Button {
            navigateToStatus = true
        } label: {
            HStack(spacing: Sp.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Font.fmHeadline)
                        .foregroundStyle(FMColors.Text.primary)
                    Text(subtitle)
                        .font(Font.fmCaption)
                        .foregroundStyle(FMColors.Text.secondary)
                }
                Spacer()
                Text(price)
                    .font(Font.fmHeadline)
                    .foregroundStyle(FMColors.Text.primary)
            }
            .padding(Sp.md)
            .frame(maxWidth: .infinity)
            .background(FMColors.Background.bg2)
            .clipShape(RoundedRectangle(cornerRadius: R.lg))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("pro.subscribe.\(productID)")
    }

    @ViewBuilder
    private var invoiceLink: some View {
        NavigationLink(value: AppRoute.refundRequest(orderId: nil)) {
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                Text("영수증 및 환불 문의")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FMColors.Text.tertiary)
            }
            .font(Font.fmBody)
            .foregroundStyle(FMColors.Text.primary)
            .padding(Sp.md)
            .background(FMColors.Background.bg2)
            .clipShape(RoundedRectangle(cornerRadius: R.lg))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("pro.invoice")
    }

    @ViewBuilder
    private func productCard(product: StoreKit.Product) -> some View {
        let isProcessing = processingProductID == product.id
        Button {
            Task { await purchase(product) }
        } label: {
            HStack(spacing: Sp.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(product.id == IAPProductIDs.proYearly ? "연간" : "월간")
                        .font(Font.fmHeadline)
                        .foregroundStyle(FMColors.Text.primary)
                    Text(product.id == IAPProductIDs.proYearly ? "12개월 — 가장 합리적" : "월 단위로 결제")
                        .font(Font.fmCaption)
                        .foregroundStyle(FMColors.Text.secondary)
                }
                Spacer()
                if isProcessing {
                    ProgressView()
                } else {
                    Text(product.displayPrice)
                        .font(Font.fmHeadline)
                        .foregroundStyle(FMColors.Text.primary)
                }
            }
            .padding(Sp.md)
            .frame(maxWidth: .infinity)
            .background(FMColors.Background.bg2)
            .clipShape(RoundedRectangle(cornerRadius: R.lg))
        }
        .buttonStyle(.plain)
        .disabled(isProcessing || storeKit.isProcessing)
        .accessibilityIdentifier("pro.subscribe.\(product.id)")
    }

    private func purchase(_ product: StoreKit.Product) async {
        processingProductID = product.id
        defer { processingProductID = nil }
        let outcome = await storeKit.purchase(product)
        switch outcome {
        case .success:
            // (#27) 낙관적 Pro 활성화 — listener 도착 전이라도 ProStatusScreen으로 즉시 이동.
            store.markProActiveOptimistically()
            navigateToStatus = true
        case .userCancelled:
            break
        case .pending:
            purchaseError = "결제가 보류 중입니다."
        case .failed(let message):
            purchaseError = message
            store.lastPaymentErrorMessage = message  // (#41) PaymentFailedScreen 진입 시 활용
        }
    }

    @ViewBuilder
    private var policy: some View {
        Text("Apple ID로 결제. 자동 갱신은 App Store 설정에서 관리할 수 있습니다.")
            .font(Font.fmCaption)
            .foregroundStyle(FMColors.Text.tertiary)
    }
}

struct ProStatusScreen: View {
    @EnvironmentObject private var store: MooditStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.lg) {
                statusCard
                manageLink
                invoiceLink
            }
            .padding(Sp.md)
        }
        .background(FMColors.Background.bg1.ignoresSafeArea())
        .navigationTitle("Pro 상태")
        .navigationBarTitleDisplayMode(.inline)
        .task { store.subscribeToWallet() }
    }

    @ViewBuilder
    private var statusCard: some View {
        VStack(alignment: .leading, spacing: Sp.sm) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(FMColors.Accent.primary)
                Text(store.isProActive ? "Pro 활성" : "Pro 비활성")
                    .font(Font.fmHeadline)
                    .foregroundStyle(FMColors.Text.primary)
            }
            Text(store.isProActive
                 ? "현재 Pro 멤버십이 활성화되어 있습니다."
                 : "Pro에 가입하지 않았습니다.")
                .font(Font.fmBody)
                .foregroundStyle(FMColors.Text.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Sp.md)
        .background(FMColors.Background.bg2)
        .clipShape(RoundedRectangle(cornerRadius: R.lg))
    }

    @ViewBuilder
    private var manageLink: some View {
        Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
            HStack {
                Image(systemName: "arrow.up.right.square")
                Text("App Store에서 구독 관리")
            }
            .font(Font.fmBody)
            .foregroundStyle(FMColors.Accent.primary)
            .padding(Sp.md)
            .frame(maxWidth: .infinity)
            .background(FMColors.Background.bg2)
            .clipShape(RoundedRectangle(cornerRadius: R.lg))
        }
        .accessibilityIdentifier("pro.cancel")
    }

    @ViewBuilder
    private var invoiceLink: some View {
        NavigationLink(value: AppRoute.refundRequest(orderId: nil)) {
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                Text("영수증 및 환불 문의")
            }
            .font(Font.fmBody)
            .foregroundStyle(FMColors.Text.primary)
            .padding(Sp.md)
            .frame(maxWidth: .infinity)
            .background(FMColors.Background.bg2)
            .clipShape(RoundedRectangle(cornerRadius: R.lg))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("pro.invoice")
    }
}

struct OrdersHistoryScreen: View {
    @StateObject private var ledger = WalletLedgerStore()

    var body: some View {
        VStack(spacing: 0) {
            let orders = ledger.entries.filter { $0.kind == .purchase }
            if orders.isEmpty {
                FMEmptyState(.emptyMarket)
                    .padding(.horizontal, Sp.md)
                    .accessibilityIdentifier("orders.empty")
            } else {
                List {
                    ForEach(orders) { entry in
                        orderRow(entry)
                    }
                }
                .listStyle(.plain)
                .refreshable { await ledger.refresh() }
            }
            orderSupportActions
                .padding(.horizontal, Sp.md)
                .padding(.vertical, Sp.md)
            Spacer(minLength: 0)
        }
        .background(FMColors.Background.bg1.ignoresSafeArea())
        .navigationTitle("주문 내역")
        .navigationBarTitleDisplayMode(.inline)
        .task { ledger.start() }
    }

    private func orderRow(_ entry: WalletLedgerEntry) -> some View {
        VStack(alignment: .leading, spacing: Sp.sm) {
            HStack {
                Image(systemName: "cart.fill")
                    .foregroundStyle(FMColors.Text.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.relatedItemTitle ?? "필터 구매").font(Font.fmBody)
                    Text(entry.createdAt, style: .date).font(Font.fmCaption)
                        .foregroundStyle(FMColors.Text.tertiary)
                }
                Spacer()
                Text("\(entry.amount.formatted())")
                    .font(Font.fmHeadline)
                    .foregroundStyle(FMColors.Text.primary)
            }

            NavigationLink(value: AppRoute.refundRequest(orderId: entry.id)) {
                Label("이 주문 환불 요청", systemImage: "arrow.uturn.backward.circle")
                    .font(Font.fmCaption)
                    .foregroundStyle(FMColors.Accent.primary)
            }
            .accessibilityIdentifier("orders.refund_request.\(entry.id)")
        }
        .padding(.vertical, Sp.xs)
    }

    @ViewBuilder
    private var orderSupportActions: some View {
        VStack(spacing: Sp.sm) {
            NavigationLink(value: AppRoute.walletTransactions) {
                workflowRouteRow("거래 내역 보기", icon: "list.bullet.rectangle")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("wallet.transactions")

            NavigationLink(value: AppRoute.refundRequest(orderId: nil)) {
                workflowRouteRow("환불 요청", icon: "arrow.uturn.backward.circle")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("wallet.refund_request")
        }
    }
}

struct WalletScreen: View {
    @EnvironmentObject private var store: MooditStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.lg) {
                balanceCard
                actions
                policyNote
            }
            .padding(Sp.md)
        }
        .background(FMColors.Background.bg1.ignoresSafeArea())
        .navigationTitle("지갑")
        .navigationBarTitleDisplayMode(.inline)
        .task { store.subscribeToWallet() }
    }

    @ViewBuilder
    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: Sp.xs) {
            Text("코인 잔액")
                .font(Font.fmCaption)
                .foregroundStyle(FMColors.Text.secondary)
            HStack(alignment: .firstTextBaseline, spacing: Sp.xs) {
                Image(systemName: "circle.hexagongrid.circle.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(FMColors.Accent.primary)
                Text("\(store.coinBalance.formatted())")
                    .font(Font.fmTitleLarge)
                    .foregroundStyle(FMColors.Text.primary)
                Text("코인")
                    .font(Font.fmBody)
                    .foregroundStyle(FMColors.Text.secondary)
            }
            if store.isProActive {
                Label("Pro 멤버십 활성", systemImage: "sparkles")
                    .font(Font.fmCaption)
                    .foregroundStyle(FMColors.Accent.primary)
                    .padding(.top, Sp.xs)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Sp.md)
        .background(FMColors.Background.bg2)
        .clipShape(RoundedRectangle(cornerRadius: R.lg))
        .accessibilityIdentifier("wallet.balance")
    }

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: 0) {
            walletAction(icon: "plus.circle.fill", title: "충전하기", subtitle: "코인 패키지로 결제", route: .walletTopup)
            divider
            walletAction(icon: "list.bullet.rectangle", title: "거래 내역", subtitle: "충전 / 사용 / 환불 기록", route: .walletTransactions)
            divider
            walletAction(icon: "sparkles", title: store.isProActive ? "Pro 상태" : "Pro 시작",
                         subtitle: store.isProActive ? "현재 구독 정보" : "Pro 멤버십 가입",
                         route: store.isProActive ? .proStatus : .proSubscription)
            divider
            walletAction(icon: "doc.text.magnifyingglass", title: "주문 내역", subtitle: "필터 구매 내역", route: .ordersHistory)
        }
        .background(FMColors.Background.bg2)
        .clipShape(RoundedRectangle(cornerRadius: R.lg))
    }

    @ViewBuilder
    private func walletAction(icon: String, title: String, subtitle: String, route: AppRoute) -> some View {
        NavigationLink(value: route) {
            HStack(spacing: Sp.md) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(FMColors.Accent.primary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Font.fmBody).foregroundStyle(FMColors.Text.primary)
                    Text(subtitle).font(Font.fmCaption).foregroundStyle(FMColors.Text.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FMColors.Text.tertiary)
            }
            .padding(Sp.md)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("wallet.action.\(route.title)")
    }

    private var divider: some View {
        Rectangle()
            .fill(FMColors.Border.subtle)
            .frame(height: 0.5)
            .padding(.leading, Sp.lg)
    }

    @ViewBuilder
    private var policyNote: some View {
        Text("코인은 moodit 안에서만 사용 가능하며 환불은 Apple 정책 + 도움말 환불 폼을 통해 처리합니다 (ADR-0006).")
            .font(Font.fmCaption)
            .foregroundStyle(FMColors.Text.tertiary)
            .padding(.horizontal, Sp.xs)
    }
}

struct WalletTopupScreen: View {
    @EnvironmentObject private var store: MooditStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var storeKit = StoreKitManager()

    @State private var purchasingProductID: String?
    @State private var purchaseError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.lg) {
                header
                if isUITesting {
                    testPackageList
                } else if storeKit.products.isEmpty {
                    if let lastError = storeKit.lastError {
                        loadErrorBanner(lastError)
                    } else {
                        loadingBanner
                    }
                } else {
                    packageList
                }
                policyNote
                topupSupportActions
            }
            .padding(Sp.md)
        }
        .background(FMColors.Background.bg1.ignoresSafeArea())
        .navigationTitle("코인 충전")
        .navigationBarTitleDisplayMode(.inline)
        .alert("결제 오류", isPresented: errorBinding, actions: {
            Button("확인", role: .cancel) { purchaseError = nil }
        }, message: {
            Text(purchaseError ?? "")
        })
        .task {
            store.subscribeToWallet()
            if storeKit.products.isEmpty {
                await storeKit.loadProducts(ids: IAPProductIDs.coinIDs)
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { purchaseError != nil }, set: { if !$0 { purchaseError = nil } })
    }

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: Sp.xs) {
            Text("현재 잔액")
                .font(Font.fmCaption)
                .foregroundStyle(FMColors.Text.secondary)
            HStack(spacing: Sp.xs) {
                Image(systemName: "circle.hexagongrid.circle.fill")
                    .foregroundStyle(FMColors.Accent.primary)
                Text("\(store.coinBalance.formatted()) 코인")
                    .font(Font.fmTitle)
                    .foregroundStyle(FMColors.Text.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Sp.md)
        .background(FMColors.Background.bg2)
        .clipShape(RoundedRectangle(cornerRadius: R.lg))
    }

    @ViewBuilder
    private var testPackageList: some View {
        VStack(spacing: Sp.sm) {
            testPackageRow(productID: IAPProductIDs.coins100, displayPrice: "테스트 KRW 1,200")
            testPackageRow(productID: IAPProductIDs.coins550, displayPrice: "테스트 KRW 5,900")
            testPackageRow(productID: IAPProductIDs.coins1200, displayPrice: "테스트 KRW 12,000")
            testPackageRow(productID: IAPProductIDs.coins3000, displayPrice: "테스트 KRW 29,000")
        }
    }

    @ViewBuilder
    private func testPackageRow(productID: String, displayPrice: String) -> some View {
        let coins = IAPProductIDs.coinAmount(for: productID) ?? 0
        let bonusLabel = bonusLabel(for: productID)
        Button {
            FMHaptic.light.play()
            if let credit = IAPProductIDs.coinAmount(for: productID) {
                store.creditCoinsOptimistically(credit)
            }
            dismiss()
        } label: {
            HStack(spacing: Sp.md) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Sp.xs) {
                        Text("\(coins.formatted()) 코인")
                            .font(Font.fmHeadline)
                            .foregroundStyle(FMColors.Text.primary)
                        if let bonusLabel {
                            Text(bonusLabel)
                                .font(Font.fmCaption.weight(.semibold))
                                .foregroundStyle(FMColors.Accent.primary)
                                .lineLimit(1)
                                .padding(.horizontal, Sp.xs)
                                .padding(.vertical, 2)
                                .background(FMColors.Accent.primary.opacity(0.18))
                                .clipShape(Capsule())
                        }
                    }
                    Text(packageLabel(for: productID))
                        .font(Font.fmCaption)
                        .foregroundStyle(FMColors.Text.secondary)
                }
                Spacer()
                Text(displayPrice)
                    .font(Font.fmHeadline)
                    .foregroundStyle(FMColors.Text.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: 112, alignment: .trailing)
            }
            .padding(Sp.md)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 76)
            .contentShape(RoundedRectangle(cornerRadius: R.lg))
        }
        .buttonStyle(CoinPackageRowButtonStyle())
        .accessibilityIdentifier("wallet.topup.package.\(productID)")
    }

    @ViewBuilder
    private var packageList: some View {
        VStack(spacing: Sp.sm) {
            ForEach(storeKit.products, id: \.id) { product in
                packageRow(product: product)
            }
        }
    }

    @ViewBuilder
    private func packageRow(product: StoreKit.Product) -> some View {
        let coins = IAPProductIDs.coinAmount(for: product.id) ?? 0
        let bonusLabel = bonusLabel(for: product.id)
        let isProcessing = purchasingProductID == product.id
        Button {
            FMHaptic.light.play()
            Task { await initiatePurchase(product) }
        } label: {
            HStack(spacing: Sp.md) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Sp.xs) {
                        Text("\(coins.formatted()) 코인")
                            .font(Font.fmHeadline)
                            .foregroundStyle(FMColors.Text.primary)
                        if let bonusLabel {
                            Text(bonusLabel)
                                .font(Font.fmCaption.weight(.semibold))
                                .foregroundStyle(FMColors.Accent.primary)
                                .lineLimit(1)
                                .padding(.horizontal, Sp.xs)
                                .padding(.vertical, 2)
                                .background(FMColors.Accent.primary.opacity(0.18))
                                .clipShape(Capsule())
                        }
                    }
                    Text(packageLabel(for: product.id))
                        .font(Font.fmCaption)
                        .foregroundStyle(FMColors.Text.secondary)
                }
                Spacer()
                if isProcessing {
                    ProgressView()
                        .frame(width: 112, alignment: .trailing)
                } else {
                    Text(product.displayPrice)
                        .font(Font.fmHeadline)
                        .foregroundStyle(FMColors.Text.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(width: 112, alignment: .trailing)
                }
            }
            .padding(Sp.md)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 76)
            .contentShape(RoundedRectangle(cornerRadius: R.lg))
        }
        .buttonStyle(CoinPackageRowButtonStyle())
        .disabled(isProcessing || storeKit.isProcessing)
        .accessibilityIdentifier("wallet.topup.package.\(product.id)")
    }

    private func packageLabel(for productId: String) -> String {
        switch productId {
        case IAPProductIDs.coins100: "Starter — 가벼운 시도"
        case IAPProductIDs.coins550: "Popular — 가장 인기"
        case IAPProductIDs.coins1200: "Best Value — 효율적"
        case IAPProductIDs.coins3000: "Pro Pack — 가장 큰 보너스"
        default: "코인 패키지"
        }
    }

    private func bonusLabel(for productId: String) -> String? {
        switch productId {
        case IAPProductIDs.coins550: "+10%"
        case IAPProductIDs.coins1200: "+20%"
        case IAPProductIDs.coins3000: "+30%"
        default: nil
        }
    }

    private func initiatePurchase(_ product: StoreKit.Product) async {
        purchasingProductID = product.id
        defer { purchasingProductID = nil }
        let outcome = await storeKit.purchase(product)
        switch outcome {
        case .success:
            if let creditResult = storeKit.lastCoinCreditResult {
                store.reconcileCoinBalance(creditResult.balance)
            } else if let credit = IAPProductIDs.coinAmount(for: product.id) {
                // Fallback for local StoreKit/test paths where callable response parsing is unavailable.
                store.creditCoinsOptimistically(credit)
            }
            dismiss()
        case .userCancelled:
            break
        case .pending:
            purchaseError = "결제가 보류 중입니다. 약관 승인 후 자동 완료됩니다."
        case .failed(let message):
            purchaseError = message
            store.lastPaymentErrorMessage = message  // (#41) PaymentFailedScreen 진입 시 활용
        }
    }

    @ViewBuilder
    private var loadingBanner: some View {
        VStack(spacing: Sp.sm) {
            ProgressView()
            Text("패키지를 불러오는 중…")
                .font(Font.fmCaption)
                .foregroundStyle(FMColors.Text.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding(Sp.md)
    }

    @ViewBuilder
    private func loadErrorBanner(_ message: String) -> some View {
        VStack(spacing: Sp.sm) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 28))
                .foregroundStyle(FMColors.Semantic.error)
            Text("패키지를 불러오지 못했어요")
                .font(Font.fmHeadline)
                .foregroundStyle(FMColors.Text.primary)
            Text(message)
                .font(Font.fmCaption)
                .foregroundStyle(FMColors.Text.secondary)
                .multilineTextAlignment(.center)
            FMButton("다시 시도", variant: .secondary, size: .md) {
                Task { await storeKit.loadProducts(ids: IAPProductIDs.coinIDs) }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Sp.md)
    }

    @ViewBuilder
    private var policyNote: some View {
        VStack(alignment: .leading, spacing: Sp.xs) {
            Text("Apple ID 결제. 충전한 코인은 moodit 내에서만 사용 가능하며, 환불은 Apple 정책 + 도움말 환불 폼을 통해 처리합니다.")
                .font(Font.fmCaption)
                .foregroundStyle(FMColors.Text.tertiary)
            Text("결제를 계속하면 코인 약관과 환불 정책에 동의하는 것으로 간주됩니다 (ADR-0006).")
                .font(Font.fmCaption)
                .foregroundStyle(FMColors.Text.tertiary)
        }
        .padding(.horizontal, Sp.xs)
    }

    @ViewBuilder
    private var topupSupportActions: some View {
        VStack(spacing: Sp.sm) {
            Button {
                Task { await storeKit.restore() }
            } label: {
                Label("구매 복원", systemImage: "arrow.clockwise.circle")
                    .font(Font.fmBody)
                    .foregroundStyle(FMColors.Accent.primary)
                    .frame(maxWidth: .infinity)
                    .padding(Sp.md)
                    .background(FMColors.Background.bg2)
                    .clipShape(RoundedRectangle(cornerRadius: R.lg))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("wallet.topup.restore")

            NavigationLink(value: AppRoute.paymentFailed) {
                Label("결제 문제 해결", systemImage: "exclamationmark.triangle")
                    .font(Font.fmBody)
                    .foregroundStyle(FMColors.Text.primary)
                    .frame(maxWidth: .infinity)
                    .padding(Sp.md)
                    .background(FMColors.Background.bg2)
                    .clipShape(RoundedRectangle(cornerRadius: R.lg))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("wallet.topup.failed_demo")
        }
    }
}

private struct CoinPackageRowButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed ? FMColors.Background.bg3 : FMColors.Background.bg2,
                in: RoundedRectangle(cornerRadius: R.lg)
            )
            .overlay {
                RoundedRectangle(cornerRadius: R.lg)
                    .strokeBorder(FMColors.Border.subtle, lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.fmFast.reducedIfNeeded(reduceMotion), value: configuration.isPressed)
    }
}

struct WalletTransactionsScreen: View {
    @StateObject private var ledger = WalletLedgerStore()
    @State private var selectedKind: WalletLedgerEntry.Kind?

    var body: some View {
        VStack(spacing: 0) {
            transactionFilter
                .padding(.horizontal, Sp.md)
                .padding(.top, Sp.sm)

            if filteredEntries.isEmpty {
                if let loadError = ledger.loadError {
                    errorView(loadError)
                } else if ledger.isLoading {
                    loadingView
                } else {
                    transactionEmptyState
                        .padding(.horizontal, Sp.md)
                        .accessibilityIdentifier("wallet.transactions.empty")
                }
                transactionSupportActions
                    .padding(.horizontal, Sp.md)
                    .padding(.top, Sp.md)
            } else {
                List {
                    ForEach(filteredEntries) { entry in
                        ledgerRow(entry: entry)
                    }
                }
                .listStyle(.plain)
                .refreshable { await ledger.refresh() }
            }
            Spacer(minLength: 0)
        }
        .background(FMColors.Background.bg1.ignoresSafeArea())
        .navigationTitle("거래 내역")
        .navigationBarTitleDisplayMode(.inline)
        .task { ledger.start() }
    }

    private var filteredEntries: [WalletLedgerEntry] {
        guard let selectedKind else { return ledger.entries }
        return ledger.entries.filter { $0.kind == selectedKind }
    }

    @ViewBuilder
    private var transactionFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Sp.xs) {
                transactionFilterChip("전체", isSelected: selectedKind == nil) {
                    FMHaptic.light.play()
                    selectedKind = nil
                }
                ForEach([WalletLedgerEntry.Kind.topup, .purchase, .refund, .bonus], id: \.self) { kind in
                    transactionFilterChip(label(for: kind), isSelected: selectedKind == kind) {
                        FMHaptic.light.play()
                        selectedKind = kind
                    }
                }
            }
            .padding(.vertical, Sp.xs)
        }
        .accessibilityIdentifier("wallet.tx.filter.cat")
    }

    @ViewBuilder
    private func transactionFilterChip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(isSelected ? Font.fmCaption.weight(.semibold) : Font.fmCaption)
                .foregroundStyle(isSelected ? FMColors.Text.inverse : FMColors.Text.tertiary)
                .lineLimit(1)
                .padding(.horizontal, Sp.sm)
                .frame(minHeight: 32)
                .background(isSelected ? FMColors.Accent.primary : Color.clear, in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(isSelected ? Color.clear : FMColors.Border.default, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? "선택됨" : "선택 안 됨")
    }

    @ViewBuilder
    private var transactionEmptyState: some View {
        VStack(spacing: Sp.md) {
            FMEmptyStateIllustration(.downloads, size: 96)
                .frame(width: 96, height: 96)

            VStack(spacing: Sp.xs) {
                Text(selectedKind == nil ? "아직 거래 내역이 없어요" : "\(label(for: selectedKind ?? .unknown)) 내역이 없어요")
                    .font(Font.fmHeadline)
                    .foregroundStyle(FMColors.Text.primary)
                    .multilineTextAlignment(.center)
                Text(selectedKind == nil ? "코인을 충전하거나 필터를 구매하면 이곳에 기록돼요." : "다른 거래 유형을 선택하거나 전체 내역을 확인해 보세요.")
                    .font(Font.fmBody)
                    .foregroundStyle(FMColors.Text.secondary)
                    .multilineTextAlignment(.center)
            }

            if ledger.entries.isEmpty {
                NavigationLink(value: AppRoute.walletTopup) {
                    Text("코인 충전하기")
                        .font(Font.fmCallout.weight(.semibold))
                        .foregroundStyle(FMColors.Text.inverse)
                        .frame(maxWidth: 240)
                        .frame(height: 44)
                        .background(FMColors.Accent.primary, in: RoundedRectangle(cornerRadius: R.md))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("wallet.transactions.empty.topup")
            } else {
                Button {
                    FMHaptic.light.play()
                    selectedKind = nil
                } label: {
                    Text("전체 거래 보기")
                        .font(Font.fmCallout.weight(.semibold))
                        .foregroundStyle(FMColors.Accent.primary)
                        .frame(maxWidth: 240)
                        .frame(height: 44)
                        .background(FMColors.Background.bg2, in: RoundedRectangle(cornerRadius: R.md))
                        .overlay {
                            RoundedRectangle(cornerRadius: R.md)
                                .strokeBorder(FMColors.Border.default, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("wallet.transactions.empty.clearFilter")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, Sp.xxl)
    }

    @ViewBuilder
    private var transactionSupportActions: some View {
        VStack(spacing: Sp.sm) {
            NavigationLink(value: AppRoute.ordersHistory) {
                workflowRouteRow("주문 내역", icon: "cart")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("orders.history")

            NavigationLink(value: AppRoute.refundRequest(orderId: nil)) {
                workflowRouteRow("환불 요청", icon: "arrow.uturn.backward.circle")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("wallet.refund_request")
        }
    }

    @ViewBuilder
    private func ledgerRow(entry: WalletLedgerEntry) -> some View {
        HStack(spacing: Sp.md) {
            Image(systemName: iconName(for: entry.kind))
                .font(.system(size: 18))
                .foregroundStyle(iconColor(for: entry.kind))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(label(for: entry.kind))
                    .font(Font.fmBody)
                    .foregroundStyle(FMColors.Text.primary)
                if let item = entry.relatedItemTitle, !item.isEmpty {
                    Text(item)
                        .font(Font.fmCaption)
                        .foregroundStyle(FMColors.Text.secondary)
                }
                Text(entry.createdAt, style: .date)
                    .font(Font.fmCaption)
                    .foregroundStyle(FMColors.Text.tertiary)
            }
            Spacer()
            Text(amountText(entry.amount))
                .font(Font.fmHeadline)
                .monospacedDigit()
                .foregroundStyle(amountColor(entry.amount))
        }
        .padding(.vertical, Sp.xs)
        .accessibilityIdentifier("wallet.transactions.row.\(entry.id)")
    }

    private func iconName(for kind: WalletLedgerEntry.Kind) -> String {
        switch kind {
        case .topup: "plus.circle.fill"
        case .purchase: "cart.fill"
        case .refund: "arrow.uturn.backward.circle"
        case .bonus: "gift.fill"
        case .unknown: "questionmark.circle"
        }
    }

    private func iconColor(for kind: WalletLedgerEntry.Kind) -> Color {
        switch kind {
        case .topup, .bonus: FMColors.Accent.primary
        case .purchase: FMColors.Text.secondary
        case .refund: FMColors.Semantic.error
        case .unknown: FMColors.Text.tertiary
        }
    }

    private func label(for kind: WalletLedgerEntry.Kind) -> String {
        switch kind {
        case .topup: "충전"
        case .purchase: "사용"
        case .refund: "환불"
        case .bonus: "보너스"
        case .unknown: "기록"
        }
    }

    private func amountText(_ amount: Int) -> String {
        amount > 0 ? "+\(amount.formatted())" : "\(amount.formatted())"
    }

    private func amountColor(_ amount: Int) -> Color {
        amount > 0 ? FMColors.Accent.primary : FMColors.Text.primary
    }

    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: Sp.md) {
            ProgressView()
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func errorView(_ message: String) -> some View {
        VStack(spacing: Sp.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundStyle(FMColors.Semantic.error)
            Text("거래 내역을 불러오지 못했어요")
                .font(Font.fmHeadline)
                .foregroundStyle(FMColors.Text.primary)
            Text(message)
                .font(Font.fmCaption)
                .foregroundStyle(FMColors.Text.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Sp.md)
    }
}

struct InsufficientBalanceScreen: View {
    @EnvironmentObject private var store: MooditStore
    @Environment(\.dismiss) private var dismiss

    let filterID: String
    var requiredCoins: Int = 0
    var currentBalance: Int = 0

    @State private var isRetryingPurchase = false
    @State private var didCompletePurchase = false
    @State private var purchaseError: String?
    @State private var didAutoRetry = false

    var body: some View {
        VStack(spacing: Sp.lg) {
            Spacer()
            Image(systemName: "exclamationmark.bubble.fill")
                .font(.system(size: 48))
                .foregroundStyle(FMColors.Semantic.error)
            Text("코인이 부족해요")
                .font(Font.fmTitle)
                .foregroundStyle(FMColors.Text.primary)
            if requiredCoins > 0 {
                let shortfall = max(requiredCoins - displayedBalance, 0)
                Text("\(shortfall.formatted())코인 부족")
                    .font(Font.fmBody)
                    .foregroundStyle(shortfall == 0 ? FMColors.Accent.primary : FMColors.Text.secondary)
                Text("현재 잔액 \(displayedBalance.formatted())코인 · 필터 \(filterIDLabel)")
                    .font(Font.fmCaption)
                    .foregroundStyle(FMColors.Text.tertiary)
            }
            VStack(spacing: Sp.sm) {
                if canRetryPurchase {
                    FMButton(
                        "지금 구매하기",
                        icon: "creditcard.fill",
                        variant: .primary,
                        size: .lg,
                        isLoading: isRetryingPurchase
                    ) {
                        Task { await retryPurchase() }
                    }
                    .disabled(isRetryingPurchase)
                    .accessibilityIdentifier("insufficient.purchase.retry")
                }

                NavigationLink(value: AppRoute.walletTopup) {
                    Text(canRetryPurchase ? "추가 충전하기" : "충전하기")
                        .font(Font.fmHeadline)
                        .foregroundStyle(canRetryPurchase ? FMColors.Accent.primary : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Sp.md)
                        .background(canRetryPurchase ? FMColors.Background.bg2 : FMColors.Accent.primary)
                        .clipShape(RoundedRectangle(cornerRadius: R.lg))
                        .overlay {
                            if canRetryPurchase {
                                RoundedRectangle(cornerRadius: R.lg)
                                    .strokeBorder(FMColors.Border.default, lineWidth: 1)
                            }
                        }
                }
                .accessibilityIdentifier("insufficient.topup")
            }
            Button("취소") {
                dismiss()
            }
            .font(Font.fmBody)
            .foregroundStyle(FMColors.Text.secondary)
            .accessibilityIdentifier("wallet.insufficient.cancel")
            Spacer()
        }
        .padding(Sp.md)
        .background(FMColors.Background.bg1.ignoresSafeArea())
        .navigationTitle("잔액 부족")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $didCompletePurchase) {
            FilterAfterDownloadScreen(filterID: filterID)
        }
        .alert("구매 오류", isPresented: errorBinding, actions: {
            Button("확인", role: .cancel) { purchaseError = nil }
        }, message: { Text(purchaseError ?? "") })
        .task {
            store.subscribeToWallet()
            await retryIfBalanceIsReady()
        }
        .onChange(of: store.coinBalance) { _, _ in
            Task { await retryIfBalanceIsReady() }
        }
    }

    private var displayedBalance: Int {
        store.coinBalance == 0 && currentBalance > 0 ? currentBalance : store.coinBalance
    }

    private var canRetryPurchase: Bool {
        requiredCoins > 0 && displayedBalance >= requiredCoins
    }

    private var filterIDLabel: String {
        UUID(uuidString: filterID) == nil ? filterID : String(filterID.prefix(8))
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { purchaseError != nil }, set: { if !$0 { purchaseError = nil } })
    }

    private func retryIfBalanceIsReady() async {
        guard canRetryPurchase, !didAutoRetry, !isRetryingPurchase, !didCompletePurchase else { return }
        didAutoRetry = true
        await retryPurchase()
    }

    private func retryPurchase() async {
        guard !isRetryingPurchase, canRetryPurchase else { return }
        isRetryingPurchase = true
        defer { isRetryingPurchase = false }
        do {
            let callable = Functions.functions(region: "asia-northeast3").httpsCallable("purchaseFilter")
            _ = try await callable.call(["filterId": filterID])
            store.creditCoinsOptimistically(-requiredCoins)
            if let filter = store.filter(matching: filterID) {
                try? await store.download(filter)
            } else {
                try? await store.download(filterID: filterID)
            }
            Telemetry.log(.filterPurchaseSucceeded, parameters: ["filter_id": filterID, "price_coins": requiredCoins, "source": "insufficient_balance_retry"])
            didCompletePurchase = true
        } catch let error as NSError where error.localizedDescription.contains("insufficient_balance") {
            didAutoRetry = false
            Telemetry.log(.filterPurchaseInsufficient, parameters: ["filter_id": filterID, "price_coins": requiredCoins, "balance": store.coinBalance])
            purchaseError = "아직 코인이 부족합니다."
        } catch {
            didAutoRetry = false
            Telemetry.log(.filterPurchaseFailed, parameters: ["filter_id": filterID, "reason": "insufficient_retry_error"])
            Telemetry.record(error: error, context: ["where": "insufficientBalanceRetry", "filter_id": filterID])
            purchaseError = error.localizedDescription
        }
    }
}

struct PaymentFailedScreen: View {
    @EnvironmentObject private var store: MooditStore
    @Environment(\.openURL) private var openURL
    @StateObject private var storeKit = StoreKitManager()
    /// (#41) store.lastPaymentErrorMessage 우선, fallback은 일반 텍스트.
    private var lastErrorMessage: String {
        store.lastPaymentErrorMessage ?? "결제가 처리되지 않았습니다."
    }

    var body: some View {
        VStack(spacing: Sp.lg) {
            Spacer()
            Image(systemName: "xmark.octagon.fill")
                .font(.system(size: 48))
                .foregroundStyle(FMColors.Semantic.error)
            Text("결제 실패")
                .font(Font.fmTitle)
                .foregroundStyle(FMColors.Text.primary)
            Text(lastErrorMessage)
                .font(Font.fmBody)
                .foregroundStyle(FMColors.Text.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Sp.md)
            VStack(spacing: Sp.sm) {
                NavigationLink(value: AppRoute.walletTopup) {
                    Text("다시 시도")
                        .font(Font.fmHeadline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Sp.md)
                        .background(FMColors.Accent.primary)
                        .clipShape(RoundedRectangle(cornerRadius: R.lg))
                }
                .accessibilityIdentifier("wallet.topup.retry")

                Button {
                    Task { await storeKit.restore() }
                } label: {
                    Text("구매 복원")
                        .font(Font.fmHeadline)
                        .foregroundStyle(FMColors.Accent.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Sp.md)
                }
                .accessibilityIdentifier("payment.failed.restore")

                Button("지원팀에 문의") {
                    openURL(URL(string: "mailto:support@moodit.app?subject=Payment%20Issue")!)
                }
                .font(Font.fmBody)
                .foregroundStyle(FMColors.Text.secondary)
                .accessibilityIdentifier("wallet.topup.support")
            }
            Spacer()
        }
        .padding(Sp.md)
        .background(FMColors.Background.bg1.ignoresSafeArea())
        .navigationTitle("결제 실패")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            // (#41 후속) 화면 떠날 때 에러 메시지 reset — 다음 진입 시 stale 에러 노출 방지.
            store.lastPaymentErrorMessage = nil
        }
    }
}

struct RefundRequestScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var orderId: String = ""
    @State private var reason: String = ""
    @State private var isProcessing = false
    @State private var statusMessage: String?

    private let prefilledOrderId: String?
    private let maxReasonLength = 2_000

    init(prefilledOrderId: String? = nil) {
        self.prefilledOrderId = prefilledOrderId
        _orderId = State(initialValue: prefilledOrderId ?? "")
    }

    var body: some View {
        Form {
            Section(header: Text("주문 ID")) {
                if let prefilledOrderId {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(prefilledOrderId)
                            .font(Font.fmCaption)
                            .foregroundStyle(FMColors.Text.primary)
                            .textSelection(.enabled)
                        Text("주문 내역에서 선택한 주문입니다.")
                            .font(Font.fmCaption)
                            .foregroundStyle(FMColors.Text.tertiary)
                    }
                    .accessibilityIdentifier("refund.orderId")
                } else {
                    TextField("orders/abc-123 형식", text: $orderId)
                        .textContentType(.URL)
                        .keyboardType(.asciiCapable)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .accessibilityIdentifier("refund.orderId")
                }
            }
            Section(header: Text("환불 사유"), footer: reasonFooter) {
                TextEditor(text: reasonBinding)
                    .frame(minHeight: 120)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.return)
                    .accessibilityIdentifier("refund.reason")
            }
            if let statusMessage {
                Section { Text(statusMessage).foregroundStyle(FMColors.Text.secondary) }
            }
            Section {
                Button {
                    Task { await submit() }
                } label: {
                    if isProcessing {
                        ProgressView()
                    } else {
                        Text("환불 요청 제출")
                    }
                }
                .disabled(isProcessing || normalizedOrderId.isEmpty || normalizedReason.isEmpty || reason.count > maxReasonLength)
                .accessibilityIdentifier("refund.submit")
            }
        }
        .navigationTitle("환불 요청")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var normalizedOrderId: String {
        orderId.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedReason: String {
        reason.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var reasonBinding: Binding<String> {
        Binding(
            get: { reason },
            set: { reason = String($0.prefix(maxReasonLength)) }
        )
    }

    private var reasonFooter: some View {
        HStack {
            Text("최대 2000자")
            Spacer()
            Text("\(reason.count) / \(maxReasonLength)")
                .monospacedDigit()
                .foregroundStyle(reason.count > 1_900 ? FMColors.Semantic.warning : FMColors.Text.tertiary)
        }
    }

    private func submit() async {
        isProcessing = true
        defer { isProcessing = false }
        do {
            let callable = Functions.functions(region: "asia-northeast3").httpsCallable("refundRequest")
            _ = try await callable.call(["orderId": normalizedOrderId, "reason": normalizedReason])
            statusMessage = "환불 요청이 접수되었습니다. 24시간 내 검토합니다."
            orderId = ""
            reason = ""
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            dismiss()
        } catch {
            statusMessage = "오류: \(error.localizedDescription)"
        }
    }
}

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

@ViewBuilder
@MainActor
private func closedLoopPayoutPlaceholder(title: String) -> some View {
    ScrollView {
        VStack(alignment: .leading, spacing: Sp.lg) {
            HStack(spacing: Sp.md) {
                Image(systemName: "tray.full")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(FMColors.Accent.primary)
                    .frame(width: 56, height: 56)
                    .background(FMColors.Accent.bg, in: RoundedRectangle(cornerRadius: R.md))
                VStack(alignment: .leading, spacing: 4) {
                    Text("출금은 추후 지원 예정이에요")
                        .fmTypography(.headline)
                        .foregroundStyle(FMColors.Text.primary)
                    Text("적립한 코인은 moodit 안에서 자유롭게 사용할 수 있어요.")
                        .fmTypography(.subhead)
                        .foregroundStyle(FMColors.Text.secondary)
                }
            }

            FMCard {
                VStack(alignment: .leading, spacing: Sp.sm) {
                    Text("적립 코인 사용처")
                        .fmTypography(.subhead)
                        .fontWeight(.semibold)
                        .foregroundStyle(FMColors.Text.primary)
                    bulletRow(icon: "camera.filters", text: "다른 메이커의 유료 필터 다운로드")
                    bulletRow(icon: "sparkles", text: "Pro 멤버십 결제 (Phase 5+ 예정)")
                    bulletRow(icon: "star.circle", text: "프로필 강조 / 우선 노출 슬롯 (Phase 5+ 예정)")
                }
            }

            Text("원화 출금 기능은 Phase 6에서 메이커 누적 잔액과 운영 환경을 보고 다시 평가합니다. 자세한 정책은 ADR-0006(closed-loop virtual currency)에 기록되어 있어요.")
                .fmTypography(.caption)
                .foregroundStyle(FMColors.Text.tertiary)
                .padding(.horizontal, Sp.xs)
        }
        .padding(Sp.md)
        .padding(.bottom, FMLayout.tabBarHeight + Sp.xxxl)
    }
    .background(FMColors.Background.bg1)
    .navigationTitle(title)
    .navigationBarTitleDisplayMode(.inline)
    .accessibilityIdentifier("payout.placeholder.\(title)")
}

@MainActor
private func bulletRow(icon: String, text: String) -> some View {
    HStack(alignment: .top, spacing: Sp.sm) {
        Image(systemName: icon)
            .foregroundStyle(FMColors.Accent.primary)
            .frame(width: 20)
        Text(text)
            .fmTypography(.body)
            .foregroundStyle(FMColors.Text.secondary)
        Spacer(minLength: 0)
    }
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
private func workflowRouteRow(_ title: String, icon: String) -> some View {
    HStack(spacing: Sp.sm) {
        Image(systemName: icon)
            .font(.system(size: IconSize.md, weight: .regular))
            .foregroundStyle(FMColors.Accent.primary)
            .frame(width: 28, height: 28)
        Text(title)
            .fmTypography(.body)
            .foregroundStyle(FMColors.Text.primary)
        Spacer()
        Image(systemName: "chevron.right")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(FMColors.Text.tertiary)
    }
    .padding(Sp.md)
    .background(FMColors.Background.bg2, in: RoundedRectangle(cornerRadius: R.lg))
}

@MainActor
private func compactRouteButton(_ title: String, icon: String) -> some View {
    HStack(spacing: Sp.xs) {
        Image(systemName: icon)
        Text(title)
            .fmTypography(.subhead)
            .lineLimit(1)
        Spacer(minLength: 0)
    }
    .foregroundStyle(FMColors.Text.primary)
    .padding(.horizontal, Sp.sm)
    .frame(maxWidth: .infinity)
    .frame(height: 44)
    .background(FMColors.Background.bg2, in: RoundedRectangle(cornerRadius: R.md))
    .overlay {
        RoundedRectangle(cornerRadius: R.md)
            .strokeBorder(FMColors.Border.default, lineWidth: 1)
    }
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
    DateFormatter.workflowDate.string(from: date)
}

private func workflowTimeString(_ date: Date) -> String {
    DateFormatter.workflowTime.string(from: date)
}

private extension DateFormatter {
    static let workflowDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy. M. d. HH:mm"
        return formatter
    }()

    static let workflowTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

private func parameterTitle(_ key: String) -> String {
    switch key {
    case "exposure": "노출"
    case "contrast": "대비"
    case "saturation": "채도"
    case "grain": "필름 그레인"
    case "vignette": "비네트"
    default: key.capitalized
    }
}

@MainActor
private func uploadProgress(active: UploadStep) -> some View {
    HStack(spacing: Sp.xs) {
        ForEach(UploadStep.allCases) { step in
            VStack(spacing: 4) {
                Circle()
                    .fill(uploadStepIndex(step) <= uploadStepIndex(active) ? FMColors.Accent.primary : FMColors.Background.bg3)
                    .frame(width: 26, height: 26)
                    .overlay {
                        Text("\(uploadStepIndex(step) + 1)")
                            .fmTypography(.caption)
                            .foregroundStyle(uploadStepIndex(step) <= uploadStepIndex(active) ? .white : FMColors.Text.tertiary)
                    }
                Text(step.title)
                    .fmTypography(.caption)
                    .foregroundStyle(step == active ? FMColors.Text.primary : FMColors.Text.tertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
    }
    .padding(Sp.sm)
    .background(FMColors.Background.bg2, in: RoundedRectangle(cornerRadius: R.md))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("업로드 \(UploadStep.allCases.count)단계 중 \(uploadStepIndex(active) + 1)단계")
    .accessibilityValue(active.title)
}

private func uploadStepIndex(_ step: UploadStep) -> Int {
    switch step {
    case .cover: 0
    case .tags: 1
    case .submit: 2
    case .pending: 3
    }
}

private struct WorkflowFlowLayout: Layout {
    var spacing: CGFloat = Sp.xs

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth > 0, rowWidth + spacing + size.width > maxWidth {
                totalHeight += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += (rowWidth > 0 ? spacing : 0) + size.width
            rowHeight = max(rowHeight, size.height)
        }

        totalHeight += rowHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
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

enum EditorReferenceSampleImage {
    static func makeJPEGData(kind: EditorReferenceSampleKind) -> Data {
        let size = CGSize(width: 960, height: 1200)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            drawBase(kind: kind, in: rect, context: context.cgContext)
            drawDetail(kind: kind, in: rect)
        }
        return image.jpegData(compressionQuality: 0.88) ?? PlaceholderPhoto.makeJPEGData()
    }

    static func normalizedJPEGData(from image: UIImage, maxLongEdge: CGFloat = 1280) -> Data? {
        let sourceSize = image.size
        guard sourceSize.width > 0, sourceSize.height > 0 else { return nil }
        let scale = min(1, maxLongEdge / max(sourceSize.width, sourceSize.height))
        let targetSize = CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let normalized = renderer.image { _ in
            UIColor.black.setFill()
            UIRectFill(CGRect(origin: .zero, size: targetSize))
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return normalized.jpegData(compressionQuality: 0.86)
    }

    private static func drawBase(kind: EditorReferenceSampleKind, in rect: CGRect, context: CGContext) {
        let colors: [UIColor] = switch kind {
        case .portrait:
            [
                UIColor(red: 0.70, green: 0.62, blue: 0.55, alpha: 1),
                UIColor(red: 0.25, green: 0.29, blue: 0.35, alpha: 1)
            ]
        case .landscape:
            [
                UIColor(red: 0.35, green: 0.56, blue: 0.78, alpha: 1),
                UIColor(red: 0.78, green: 0.71, blue: 0.47, alpha: 1),
                UIColor(red: 0.25, green: 0.39, blue: 0.28, alpha: 1)
            ]
        case .indoor:
            [
                UIColor(red: 0.22, green: 0.19, blue: 0.18, alpha: 1),
                UIColor(red: 0.58, green: 0.42, blue: 0.29, alpha: 1)
            ]
        case .lifestyle:
            [
                UIColor(red: 0.72, green: 0.66, blue: 0.57, alpha: 1),
                UIColor(red: 0.45, green: 0.36, blue: 0.29, alpha: 1)
            ]
        }

        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors.map(\.cgColor) as CFArray,
            locations: nil
        )
        context.drawLinearGradient(
            gradient!,
            start: CGPoint(x: rect.minX, y: rect.minY),
            end: CGPoint(x: rect.maxX, y: rect.maxY),
            options: []
        )
    }

    private static func drawDetail(kind: EditorReferenceSampleKind, in rect: CGRect) {
        switch kind {
        case .portrait:
            UIColor(red: 0.88, green: 0.66, blue: 0.52, alpha: 1).setFill()
            UIBezierPath(ovalIn: CGRect(x: rect.midX - 150, y: 210, width: 300, height: 340)).fill()
            UIColor(red: 0.18, green: 0.15, blue: 0.13, alpha: 1).setFill()
            UIBezierPath(roundedRect: CGRect(x: rect.midX - 210, y: 520, width: 420, height: 440), cornerRadius: 120).fill()
            UIColor.white.withAlphaComponent(0.20).setStroke()
            UIBezierPath(roundedRect: rect.insetBy(dx: 110, dy: 145), cornerRadius: 52).stroke()
        case .landscape:
            UIColor.white.withAlphaComponent(0.85).setFill()
            UIBezierPath(ovalIn: CGRect(x: 660, y: 145, width: 120, height: 120)).fill()
            UIColor(red: 0.12, green: 0.23, blue: 0.18, alpha: 1).setFill()
            UIBezierPath(rect: CGRect(x: 0, y: 780, width: rect.width, height: 420)).fill()
            UIColor(red: 0.30, green: 0.45, blue: 0.30, alpha: 1).setFill()
            UIBezierPath(roundedRect: CGRect(x: 130, y: 650, width: 720, height: 220), cornerRadius: 110).fill()
        case .indoor:
            UIColor(red: 0.94, green: 0.70, blue: 0.36, alpha: 1).setFill()
            UIBezierPath(roundedRect: CGRect(x: 120, y: 180, width: 240, height: 360), cornerRadius: 18).fill()
            UIColor(red: 0.18, green: 0.15, blue: 0.14, alpha: 1).setFill()
            UIBezierPath(roundedRect: CGRect(x: 420, y: 360, width: 360, height: 560), cornerRadius: 36).fill()
            UIColor.white.withAlphaComponent(0.16).setStroke()
            UIBezierPath(roundedRect: CGRect(x: 170, y: 720, width: 280, height: 160), cornerRadius: 28).stroke()
        case .lifestyle:
            UIColor(red: 0.32, green: 0.24, blue: 0.18, alpha: 1).setFill()
            UIBezierPath(roundedRect: CGRect(x: 90, y: 760, width: 780, height: 210), cornerRadius: 38).fill()
            UIColor(red: 0.96, green: 0.89, blue: 0.76, alpha: 1).setFill()
            UIBezierPath(ovalIn: CGRect(x: 180, y: 330, width: 270, height: 270)).fill()
            UIColor(red: 0.22, green: 0.18, blue: 0.14, alpha: 1).setStroke()
            UIBezierPath(ovalIn: CGRect(x: 240, y: 390, width: 150, height: 150)).stroke()
            UIColor(red: 0.72, green: 0.28, blue: 0.20, alpha: 1).setFill()
            UIBezierPath(roundedRect: CGRect(x: 530, y: 430, width: 170, height: 250), cornerRadius: 32).fill()
        }
    }
}
