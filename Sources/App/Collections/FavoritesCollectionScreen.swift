import DesignSystem
import SwiftUI

/// 30 Favorites Collection — `mockups/screens/30-favorites-collection.html` 정합.
///
/// 컬렉션 그리드 (2열) + 4-사진 모자이크 커버 + 새 컬렉션 만들기 + 편집 모드.
/// 첫 카드는 "전체 즐겨찾기" 자동 컬렉션 (accent.bg 배경).
struct FavoritesCollectionScreen: View {
    // 프로덕션은 /users/{uid}/collections Firestore listener (별도 작업)에서 채워짐.
    // UI 테스트(-ui-testing): 기존 mock fallback.
    @State private var collections: [FilterCollection] = isUITesting ? FilterCollection.mock : []
    @State private var isEditing = false
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
                    withAnimation(.fmFast) { isEditing.toggle() }
                }
                .accessibilityIdentifier("collection.edit")
                .foregroundStyle(FMColors.Accent.primary)
            }
        }
        .fmBottomSheet(isPresented: $showingCreate) {
            createSheet
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
                Text("컬렉션 \(collections.count - 1)개")
            }
            .fmTypography(.subhead)
            .foregroundStyle(FMColors.Text.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Sp.sm)
    }

    private var totalFavorites: Int {
        collections.first { $0.isAutoAll }?.count ?? 0
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
            collections.removeAll { $0.id == collection.id }
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
                placeholder: "예: 가을 분위기"
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
                let trimmed = newName.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                let collection = FilterCollection(
                    name: trimmed,
                    count: 0,
                    isPrivate: newIsPrivate,
                    isAutoAll: false,
                    tiles: []
                )
                collections.append(collection)
                FMHaptic.success.play()
                showingCreate = false
            }
            .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(Sp.lg)
    }
}

// MARK: - Model

struct FilterCollection: Identifiable, Hashable {
    let id = UUID()
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

    static let mock: [FilterCollection] = [
        FilterCollection(
            name: "전체 즐겨찾기",
            count: 12,
            isPrivate: false,
            isAutoAll: true,
            tiles: [.vintage, .cafe, .portrait, .moody]
        ),
        FilterCollection(
            name: "카페 일상",
            count: 8,
            isPrivate: false,
            isAutoAll: false,
            tiles: [.cafe, .warm, .vintage, .portrait]
        ),
        FilterCollection(
            name: "시네마틱 무드",
            count: 6,
            isPrivate: true,
            isAutoAll: false,
            tiles: [.cinematic, .moody, .bw, .cool]
        ),
        FilterCollection(
            name: "여행",
            count: 5,
            isPrivate: false,
            isAutoAll: false,
            tiles: [.travel, .mountain, .nature, .city]
        ),
        FilterCollection(
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
            .environmentObject(MooditStore())
    }
}

#Preview("Favorites collection — Dark") {
    NavigationStack {
        FavoritesCollectionScreen()
            .environmentObject(MooditStore())
    }
    .preferredColorScheme(.dark)
}
