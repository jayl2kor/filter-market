import DesignSystem
import Foundation
import Marketplace
import Models
import SwiftUI

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
                .interactiveDismissDisabled(true)
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

struct BuiltinFilterLibraryScreen: View {
    @EnvironmentObject private var store: MooditStore
    @State private var isCameraPresented = false
    @State private var query = ""
    @State private var selectedCategory: FilterCategory?
    @State private var lockedFilter: Filter?

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

                searchAndCategoryControls

                if visibleFilters.isEmpty {
                    FMEmptyState(.noSearchResults(query: query.isEmpty ? selectedCategory?.displayTitle ?? "기본 필터" : query)) {
                        query = ""
                        selectedCategory = nil
                    }
                    .frame(minHeight: 320)
                } else {
                    LazyVStack(alignment: .leading, spacing: Sp.lg, pinnedViews: [.sectionHeaders]) {
                        ForEach(visibleCategories, id: \.rawValue) { category in
                            Section {
                                LazyVGrid(columns: columns, spacing: Sp.sm) {
                                    ForEach(filters(in: category)) { filter in
                                        filterCard(filter)
                                    }
                                }
                            } header: {
                                sectionHeader(category)
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
        .sheet(item: $lockedFilter) { filter in
            NavigationStack {
                BuiltinFilterLockedSheet(filter: filter)
                    .environmentObject(store)
                    .appRouteDestinations()
            }
        }
        .fullScreenCover(isPresented: $isCameraPresented) {
            CameraScreen(isPresentedAsCover: true)
                .environmentObject(store)
                .interactiveDismissDisabled(true)
        }
    }

    private var searchAndCategoryControls: some View {
        VStack(alignment: .leading, spacing: Sp.sm) {
            FMTextField.search(text: $query, placeholder: "필터 검색")
                .accessibilityIdentifier("builtin.search")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Sp.xs) {
                    FMChip("전체", isSelected: selectedCategory == nil, size: .sm) {
                        selectedCategory = nil
                        FMHaptic.selection.play()
                    }
                    .accessibilityIdentifier("builtin.category.all")

                    ForEach(FilterCategory.allCases, id: \.rawValue) { category in
                        FMChip(category.displayTitle, isSelected: selectedCategory == category, size: .sm) {
                            selectedCategory = category
                            FMHaptic.selection.play()
                        }
                        .accessibilityIdentifier("builtin.category.\(category.rawValue)")
                    }
                }
                .padding(.vertical, Sp.xxs)
            }
        }
    }

    private var normalizedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var matchingFilters: [Filter] {
        let filteredBySearch = store.filters.filter { filter in
            guard !normalizedQuery.isEmpty else { return true }
            return filter.title.lowercased().contains(normalizedQuery)
                || filter.author.displayName.lowercased().contains(normalizedQuery)
                || filter.category.displayTitle.lowercased().contains(normalizedQuery)
                || filter.category.rawValue.lowercased().contains(normalizedQuery)
                || filter.tags.contains { $0.lowercased().contains(normalizedQuery) }
        }

        guard let selectedCategory else { return filteredBySearch }
        return filteredBySearch.filter { $0.category == selectedCategory }
    }

    private var visibleFilters: [Filter] {
        matchingFilters
    }

    private var visibleCategories: [FilterCategory] {
        FilterCategory.allCases.filter { category in
            visibleFilters.contains { $0.category == category }
        }
    }

    private func filters(in category: FilterCategory) -> [Filter] {
        visibleFilters.filter { $0.category == category }
    }

    private func sectionHeader(_ category: FilterCategory) -> some View {
        HStack {
            Text(category.displayTitle)
                .fmTypography(.headline)
                .foregroundStyle(FMColors.Text.primary)
            Spacer()
            Text("\(filters(in: category).count)")
                .fmTypography(.caption)
                .foregroundStyle(FMColors.Text.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, Sp.xs)
        .background(FMColors.Background.bg1)
        .accessibilityElement(children: .combine)
    }

    private func filterCard(_ filter: Filter) -> some View {
        let locked = isLocked(filter)

        return VStack(alignment: .leading, spacing: Sp.sm) {
            Group {
                if locked {
                    Button {
                        lockedFilter = filter
                        FMHaptic.selection.play()
                    } label: {
                        tileView(for: filter, locked: true)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("builtin.filter.locked.\(filter.id.uuidString)")
                    .accessibilityHint("Pro 필터입니다. 가입 안내를 봅니다.")
                } else {
                    NavigationLink(value: AppRoute.filterDetail(id: filter.id.uuidString)) {
                        tileView(for: filter, locked: false)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("builtin.filter.tap.\(filter.id.uuidString)")
                }
            }
            .accessibilityValue(locked ? "Pro 잠김" : "사용 가능")

            HStack(spacing: Sp.xs) {
                FMButton(locked ? "Pro" : "적용", icon: locked ? "lock.fill" : "camera.fill", variant: locked ? .secondary : .primary, size: .sm) {
                    if locked {
                        lockedFilter = filter
                    } else {
                        store.select(filter)
                        isCameraPresented = true
                    }
                }
                .accessibilityIdentifier("builtin.filter.apply.\(filter.id.uuidString)")
                .accessibilityHint(locked ? "Pro 가입 안내를 봅니다." : "카메라에 이 필터를 적용합니다.")

                NavigationLink(value: AppRoute.filterDetail(id: filter.id.uuidString)) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(FMColors.Text.primary)
                        .frame(width: 36, height: 36)
                        .background(FMColors.Background.bg2, in: RoundedRectangle(cornerRadius: R.md))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(filter.title) 정보")
                .accessibilityIdentifier("builtin.filter.info.\(filter.id.uuidString)")
            }
        }
    }

    private func tileView(for filter: Filter, locked: Bool) -> some View {
        FMFilterTile(data: tileData(for: filter))
            .overlay(alignment: .topTrailing) {
                if filter.priceCoins > 0 {
                    Label("Pro", systemImage: locked ? "lock.fill" : "sparkles")
                        .font(.caption.weight(.bold))
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(locked ? FMColors.Semantic.warning : FMColors.Accent.primary)
                        .padding(.horizontal, Sp.xs)
                        .padding(.vertical, 6)
                        .background(.regularMaterial, in: Capsule())
                        .padding(Sp.xs)
                }
            }
    }

    private func isLocked(_ filter: Filter) -> Bool {
        filter.priceCoins > 0 && !store.isProActive
    }

    private func tileData(for filter: Filter) -> FMFilterTileData {
        FMFilterTileData(
            title: filter.title,
            makerName: filter.author.displayName,
            downloadCount: 0,
            priceLabel: tilePriceLabel(for: filter),
            categoryHint: filter.category.swatch.first,
            categoryKey: filter.category.rawValue
        )
    }

    private func tilePriceLabel(for filter: Filter) -> String {
        if store.isDownloaded(filter) { return "저장됨" }
        if filter.priceCoins > 0 { return store.isProActive ? "Pro 포함" : "Pro" }
        return "무료"
    }
}

private struct BuiltinFilterLockedSheet: View {
    @Environment(\.dismiss) private var dismiss
    let filter: Filter

    var body: some View {
        VStack(alignment: .leading, spacing: Sp.lg) {
            Label("Pro 전용 필터", systemImage: "lock.fill")
                .font(.title3.weight(.bold))
                .foregroundStyle(FMColors.Semantic.warning)

            VStack(alignment: .leading, spacing: Sp.xs) {
                Text(filter.title)
                    .fmTypography(.title)
                    .foregroundStyle(FMColors.Text.primary)
                Text("\(filter.category.displayTitle) 카테고리")
                    .fmTypography(.subhead)
                    .foregroundStyle(FMColors.Text.secondary)
            }

            Text("Pro 멤버십을 활성화하면 이 필터를 카메라와 편집 화면에서 바로 사용할 수 있습니다.")
                .fmTypography(.body)
                .foregroundStyle(FMColors.Text.secondary)

            NavigationLink(value: AppRoute.proSubscription) {
                Label("Pro 멤버십 보기", systemImage: "sparkles")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(FMColors.Accent.primary, in: RoundedRectangle(cornerRadius: R.md))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("builtin.filter.locked.pro")

            Button("닫기") {
                dismiss()
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("builtin.filter.locked.close")
        }
        .padding(Sp.lg)
        .presentationDetents([.medium])
        .navigationTitle("Pro 필터")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Account / Profile
