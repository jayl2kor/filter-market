import DesignSystem
import FirebaseAuth
import FirebaseFirestore
import SwiftUI

/// 30 Favorites Collection — `mockups/screens/30-favorites-collection.html` 정합.
///
/// 컬렉션 그리드 (2열) + 4-사진 모자이크 커버 + 새 컬렉션 만들기 + 편집 모드.
/// 첫 카드는 "전체 즐겨찾기" 자동 컬렉션 (accent.bg 배경).
struct FavoritesCollectionScreen: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var filterLibraryStore: FilterLibraryStore

    @State private var collections: [FilterCollection] = isUITesting ? FilterCollection.mock : []
    @State private var collectionsListener: ListenerRegistration?
    @State private var statusMessage: String?
    @State private var isEditing = false
    @State private var isSaving = false
    @State private var showingCreate = false
    @State private var newName = ""
    @State private var newIsPrivate = false

    private let columns = [
        GridItem(.flexible(), spacing: Sp.sm),
        GridItem(.flexible(), spacing: Sp.sm)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.md) {
                header

                createButton

                LazyVGrid(columns: columns, spacing: Sp.sm) {
                    ForEach(collections) { collection in
                        card(collection)
                    }
                }
            }
            .padding(.horizontal, Sp.md)
            .padding(.bottom, FMLayout.tabBarHeight + Sp.xxxl)
        }
        .background(FMColors.Background.bg1)
        .navigationTitle("컬렉션")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isEditing ? "완료" : "편집") {
                    FMHaptic.selection.play()
                    withAnimation(.fmFast.reducedIfNeeded(reduceMotion)) { isEditing.toggle() }
                }
                .accessibilityIdentifier("collection.edit")
                .foregroundStyle(FMColors.Accent.primary)
            }
        }
        .fmBottomSheet(isPresented: $showingCreate) {
            createSheet
        }
        .onAppear { attachCollectionsListener() }
        .onDisappear {
            collectionsListener?.remove()
            collectionsListener = nil
        }
        .alert(
            "컬렉션",
            isPresented: Binding(
                get: { statusMessage != nil },
                set: { if !$0 { statusMessage = nil } }
            )
        ) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(statusMessage ?? "")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("내 컬렉션")
                .fmTypography(.titleLarge)
                .foregroundStyle(FMColors.Text.primary)

            HStack(spacing: 8) {
                Text("즐겨찾기 \(totalFavorites)")
                Text("·")
                Text("컬렉션 \(customCollectionCount)개")
            }
            .fmTypography(.subhead)
            .foregroundStyle(FMColors.Text.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Sp.sm)
    }

    private var totalFavorites: Int {
        if isUITesting {
            return collections.first { $0.isAutoAll }?.count ?? 0
        }
        return filterLibraryStore.favoriteFilterIDs.count
    }

    private var customCollectionCount: Int {
        max(0, collections.filter { !$0.isAutoAll }.count)
    }

    // MARK: - Create button

    private var createButton: some View {
        Button {
            FMHaptic.light.play()
            newName = ""
            newIsPrivate = false
            showingCreate = true
        } label: {
            HStack(spacing: Sp.sm) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(FMColors.Accent.primary)
                    .frame(width: 40, height: 40)
                    .background(FMColors.Background.bg2, in: Circle())

                Text("새 컬렉션 만들기")
                    .fmTypography(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(FMColors.Accent.primary)

                Spacer()
            }
            .padding(Sp.md)
            .background(
                RoundedRectangle(cornerRadius: R.lg)
                    .fill(FMColors.Accent.bg)
            )
            .overlay {
                RoundedRectangle(cornerRadius: R.lg)
                    .strokeBorder(
                        FMColors.Accent.primary,
                        style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("collection.create")
    }

    // MARK: - Card

    private func card(_ collection: FilterCollection) -> some View {
        Button {
            FMHaptic.light.play()
        } label: {
            VStack(spacing: 0) {
                cover(collection)

                VStack(alignment: .leading, spacing: 2) {
                    Text(collection.name)
                        .fmTypography(.callout)
                        .fontWeight(.bold)
                        .foregroundStyle(FMColors.Text.primary)
                        .lineLimit(1)

                    Text(collection.metaText)
                        .fmTypography(.caption)
                        .foregroundStyle(FMColors.Text.tertiary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Sp.md)
                .padding(.vertical, Sp.sm)
            }
            .background(FMColors.Background.bg2)
            .clipShape(RoundedRectangle(cornerRadius: R.lg))
            .overlay {
                RoundedRectangle(cornerRadius: R.lg)
                    .strokeBorder(FMColors.Border.subtle, lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.04), radius: 1, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("collection.card.tap")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(collection.name), \(collection.metaText)")
        .accessibilityHint("탭하면 컬렉션을 봅니다")
        .accessibilityAddTraits(.isButton)
        .overlay(alignment: .topTrailing) {
            if isEditing && !collection.isAutoAll {
                deleteButton(collection)
            }
        }
    }

    @ViewBuilder
    private func cover(_ collection: FilterCollection) -> some View {
        ZStack(alignment: .topLeading) {
            if collection.isAutoAll {
                allFavoritesCover
            } else {
                photoMosaic(collection.tiles)
            }

            if collection.isAutoAll {
                pin("즐겨찾기")
                    .padding(Sp.xs)
            }

            if collection.isPrivate {
                privateBadge
                    .padding(Sp.xs)
                    .frame(maxWidth: .infinity, alignment: .topTrailing)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var allFavoritesCover: some View {
        ZStack {
            FMColors.Accent.bg

            VStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(FMColors.Accent.primary)
                Text("\(totalFavorites)")
                    .fmTypography(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(FMColors.Accent.primary)
            }
        }
    }

    private func photoMosaic(_ tiles: [CollectionTile]) -> some View {
        let padded = Array(tiles.prefix(4)) + Array(repeating: CollectionTile.placeholder, count: max(0, 4 - tiles.count))
        return LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 1), GridItem(.flexible(), spacing: 1)],
            spacing: 1
        ) {
            ForEach(padded.indices, id: \.self) { idx in
                LinearGradient(
                    colors: padded[idx].gradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .aspectRatio(1, contentMode: .fill)
            }
        }
    }

    private func pin(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .tracking(0.4)
            .textCase(.uppercase)
            .foregroundStyle(FMColors.Accent.primary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.94), in: RoundedRectangle(cornerRadius: R.sm))
    }

    private var privateBadge: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(Color.black.opacity(0.62), in: Circle())
    }

    private func deleteButton(_ collection: FilterCollection) -> some View {
        Button {
            FMHaptic.warning.play()
            deleteCollection(collection)
        } label: {
            Image(systemName: "minus.circle.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white, FMColors.Semantic.error)
                .background(Circle().fill(Color.white).padding(2))
        }
        .buttonStyle(.plain)
        .padding(Sp.xs)
        .accessibilityIdentifier("collection.delete")
    }

    // MARK: - Create sheet

    private var createSheet: some View {
        VStack(alignment: .leading, spacing: Sp.md) {
            Text("새 컬렉션 만들기")
                .fmTypography(.title)
                .foregroundStyle(FMColors.Text.primary)

            FMTextField(
                "이름",
                text: $newName,
                placeholder: "예: 가을 분위기",
                autocapitalization: .words,
                submitLabel: .done
            )

            Toggle(isOn: $newIsPrivate) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("비공개 컬렉션")
                        .fmTypography(.body)
                        .foregroundStyle(FMColors.Text.primary)
                    Text("나만 볼 수 있고 프로필에 표시되지 않아요")
                        .fmTypography(.caption)
                        .foregroundStyle(FMColors.Text.secondary)
                }
            }
            .tint(FMColors.Accent.primary)

            FMButton("만들기", icon: "checkmark", variant: .primary, size: .lg) {
                Task { await createCollection() }
            }
            .disabled(isSaving || newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(Sp.lg)
    }

    private func attachCollectionsListener() {
        #if DEBUG
        guard !isUITesting else { return }
        #endif
        collectionsListener?.remove()
        guard let uid = Auth.auth().currentUser?.uid else {
            collections = [allFavoritesCollection(count: filterLibraryStore.favoriteFilterIDs.count)]
            statusMessage = "로그인 후 컬렉션을 동기화할 수 있어요."
            return
        }
        collectionsListener = Firestore.firestore()
            .collection("users").document(uid)
            .collection("collections")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { snapshot, error in
                Task { @MainActor in
                    if let error {
                        statusMessage = "컬렉션을 불러오지 못했어요: \(error.localizedDescription)"
                        collections = [allFavoritesCollection(count: filterLibraryStore.favoriteFilterIDs.count)]
                        return
                    }
                    let custom = (snapshot?.documents ?? []).compactMap(FilterCollection.init(document:))
                    collections = [allFavoritesCollection(count: filterLibraryStore.favoriteFilterIDs.count)] + custom
                }
            }
    }

    @MainActor
    private func createCollection() async {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        #if DEBUG
        guard !isUITesting else {
            collections.append(FilterCollection(name: trimmed, count: 0, isPrivate: newIsPrivate, isAutoAll: false, tiles: []))
            FMHaptic.success.play()
            showingCreate = false
            return
        }
        #endif
        guard let uid = Auth.auth().currentUser?.uid else {
            statusMessage = "로그인 후 컬렉션을 만들 수 있어요."
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            try await Firestore.firestore()
                .collection("users").document(uid)
                .collection("collections").document()
                .setData([
                    "name": trimmed,
                    "isPrivate": newIsPrivate,
                    "filterIds": [],
                    "createdAt": FieldValue.serverTimestamp(),
                    "updatedAt": FieldValue.serverTimestamp()
                ])
            FMHaptic.success.play()
            showingCreate = false
        } catch {
            statusMessage = "컬렉션을 만들지 못했어요: \(error.localizedDescription)"
        }
    }

    private func deleteCollection(_ collection: FilterCollection) {
        #if DEBUG
        guard !isUITesting else {
            collections.removeAll { $0.id == collection.id }
            return
        }
        #endif
        guard let uid = Auth.auth().currentUser?.uid else {
            statusMessage = "로그인 후 컬렉션을 삭제할 수 있어요."
            return
        }
        let removed = collection
        collections.removeAll { $0.id == collection.id }
        Task {
            do {
                try await Firestore.firestore()
                    .collection("users").document(uid)
                    .collection("collections").document(collection.id)
                    .delete()
            } catch {
                await MainActor.run {
                    collections.append(removed)
                    collections.sort { lhs, rhs in
                        if lhs.isAutoAll != rhs.isAutoAll { return lhs.isAutoAll }
                        return lhs.name < rhs.name
                    }
                    statusMessage = "컬렉션을 삭제하지 못했어요: \(error.localizedDescription)"
                }
            }
        }
    }

    private func allFavoritesCollection(count: Int) -> FilterCollection {
        FilterCollection(
            id: "all",
            name: "전체 즐겨찾기",
            count: count,
            isPrivate: false,
            isAutoAll: true,
            tiles: favoriteTiles
        )
    }

    private var favoriteTiles: [CollectionTile] {
        let palette: [CollectionTile] = [.vintage, .cafe, .portrait, .moody, .travel, .nature]
        let count = max(1, filterLibraryStore.favoriteFilterIDs.count)
        return Array(palette.prefix(min(4, count)))
    }
}

// MARK: - Model

struct FilterCollection: Identifiable, Hashable {
    let id: String
    let name: String
    let count: Int
    let isPrivate: Bool
    let isAutoAll: Bool
    let tiles: [CollectionTile]

    var metaText: String {
        if isAutoAll {
            return "\(count) 필터 · 자동 생성"
        }
        return "\(count) 필터 · \(isPrivate ? "비공개" : "공개")"
    }

    init(
        id: String = UUID().uuidString,
        name: String,
        count: Int,
        isPrivate: Bool,
        isAutoAll: Bool,
        tiles: [CollectionTile]
    ) {
        self.id = id
        self.name = name
        self.count = count
        self.isPrivate = isPrivate
        self.isAutoAll = isAutoAll
        self.tiles = tiles
    }

    init?(document: QueryDocumentSnapshot) {
        let data = document.data()
        guard let name = (data["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else {
            return nil
        }
        let filterIds = data["filterIds"] as? [String] ?? []
        self.init(
            id: document.documentID,
            name: name,
            count: filterIds.count,
            isPrivate: data["isPrivate"] as? Bool ?? true,
            isAutoAll: false,
            tiles: Self.tiles(for: document.documentID, count: filterIds.count)
        )
    }

    private static func tiles(for seed: String, count: Int) -> [CollectionTile] {
        let palette: [CollectionTile] = [.cafe, .warm, .vintage, .portrait, .cinematic, .moody, .bw, .cool, .travel, .mountain, .nature, .city, .pastel]
        guard !palette.isEmpty else { return [] }
        let start = abs(seed.hashValue) % palette.count
        let tileCount = min(4, max(0, count))
        return (0 ..< tileCount).map { palette[(start + $0) % palette.count] }
    }

    static let mock: [FilterCollection] = [
        FilterCollection(
            id: "all",
            name: "전체 즐겨찾기",
            count: 12,
            isPrivate: false,
            isAutoAll: true,
            tiles: [.vintage, .cafe, .portrait, .moody]
        ),
        FilterCollection(
            id: "cafe",
            name: "카페 일상",
            count: 8,
            isPrivate: false,
            isAutoAll: false,
            tiles: [.cafe, .warm, .vintage, .portrait]
        ),
        FilterCollection(
            id: "cinematic",
            name: "시네마틱 무드",
            count: 6,
            isPrivate: true,
            isAutoAll: false,
            tiles: [.cinematic, .moody, .bw, .cool]
        ),
        FilterCollection(
            id: "travel",
            name: "여행",
            count: 5,
            isPrivate: false,
            isAutoAll: false,
            tiles: [.travel, .mountain, .nature, .city]
        ),
        FilterCollection(
            id: "autumn",
            name: "가을 분위기",
            count: 4,
            isPrivate: false,
            isAutoAll: false,
            tiles: [.pastel, .portrait, .warm, .cafe]
        )
    ]
}

struct CollectionTile: Hashable {
    let gradient: [Color]

    static let placeholder = CollectionTile(gradient: [Color(hex: 0xEDEBE5), Color(hex: 0xC8C5BE)])
    static let vintage = CollectionTile(gradient: [Color(hex: 0xC79A72), Color(hex: 0x8B5E1F)])
    static let cafe = CollectionTile(gradient: [Color(hex: 0xE8C9A0), Color(hex: 0x7A4F22)])
    static let portrait = CollectionTile(gradient: [Color(hex: 0xE8B89B), Color(hex: 0xA66B47)])
    static let moody = CollectionTile(gradient: [Color(hex: 0x6B7A8E), Color(hex: 0x2F3B4D)])
    static let warm = CollectionTile(gradient: [Color(hex: 0xF0C794), Color(hex: 0xB37A3D)])
    static let cinematic = CollectionTile(gradient: [Color(hex: 0x594878), Color(hex: 0x1F1832)])
    static let bw = CollectionTile(gradient: [Color(hex: 0x9A9A9A), Color(hex: 0x2A2A2A)])
    static let cool = CollectionTile(gradient: [Color(hex: 0x8FA8C4), Color(hex: 0x3D5A7C)])
    static let travel = CollectionTile(gradient: [Color(hex: 0xCBD4E0), Color(hex: 0xC79A72)])
    static let mountain = CollectionTile(gradient: [Color(hex: 0xA8B7C4), Color(hex: 0x4A5A6E)])
    static let nature = CollectionTile(gradient: [Color(hex: 0xAEC59A), Color(hex: 0x4A6A3C)])
    static let city = CollectionTile(gradient: [Color(hex: 0x7A8A9A), Color(hex: 0x2A3848)])
    static let pastel = CollectionTile(gradient: [Color(hex: 0xF6E2E8), Color(hex: 0xC485A6)])
}

// MARK: - Preview

#Preview("Favorites collection") {
    NavigationStack {
        FavoritesCollectionScreen()
            .environmentObject(FilterLibraryStore())
    }
}

#Preview("Favorites collection — Dark") {
    NavigationStack {
        FavoritesCollectionScreen()
            .environmentObject(FilterLibraryStore())
    }
    .preferredColorScheme(.dark)
}
