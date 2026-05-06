import DesignSystem
import Models
import SwiftUI

struct MarketplaceScreen: View {
    @EnvironmentObject private var store: FilterMarketStore
    @State private var selectedCategory = "Featured"

    private let categories = ["Featured", "Cinematic", "Portrait", "Travel", "Food"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FMSpacing.large) {
                    ScreenHeader(
                        title: "Market",
                        subtitle: "Browse mock filters before Firebase and R2 are connected."
                    )

                    categoryPicker

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 152), spacing: FMSpacing.medium)], spacing: FMSpacing.medium) {
                        ForEach(filteredFilters) { filter in
                            NavigationLink {
                                FilterDetailScreen(filter: filter)
                            } label: {
                                marketCard(filter)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(FMSpacing.large)
            }
            .background(FMColor.background)
            .navigationTitle("Market")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FMSpacing.small) {
                ForEach(categories, id: \.self) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        Text(category)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, FMSpacing.medium)
                            .padding(.vertical, FMSpacing.small)
                            .background(
                                selectedCategory == category ? FMColor.accent : FMColor.surface,
                                in: Capsule()
                            )
                            .foregroundStyle(selectedCategory == category ? .black : .white)
                    }
                    .accessibilityIdentifier("market.category.\(category)")
                }
            }
        }
    }

    private var filteredFilters: [Filter] {
        guard selectedCategory != "Featured" else { return store.filters }
        return store.filters.filter { $0.category.displayTitle == selectedCategory }
    }

    private func marketCard(_ filter: Filter) -> some View {
        VStack(alignment: .leading, spacing: FMSpacing.small) {
            FilterThumbnail(filter: filter)

            Text(filter.title)
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(filter.author.displayName)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(1)

            HStack {
                PillText(filter.category.displayTitle)
                Spacer()
                Image(systemName: store.isDownloaded(filter) ? "checkmark.circle.fill" : "arrow.down.circle")
                    .foregroundStyle(store.isDownloaded(filter) ? FMColor.accent : .white.opacity(0.68))
            }
        }
        .padding(FMSpacing.medium)
        .background(FMColor.surface, in: RoundedRectangle(cornerRadius: 8))
    }
}
