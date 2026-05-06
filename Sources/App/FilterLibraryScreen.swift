import DesignSystem
import SwiftUI

struct FilterLibraryScreen: View {
    @EnvironmentObject private var store: FilterMarketStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FMSpacing.large) {
                    ScreenHeader(
                        title: "Filters",
                        subtitle: "Downloaded and seed filters ready for the camera."
                    )

                    if store.libraryFilters.isEmpty {
                        Text("Downloaded filters will appear here.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.64))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(FMSpacing.large)
                            .background(FMColor.surface, in: RoundedRectangle(cornerRadius: 8))
                    } else {
                        VStack(spacing: FMSpacing.medium) {
                            ForEach(store.libraryFilters) { filter in
                                NavigationLink {
                                    FilterDetailScreen(filter: filter)
                                } label: {
                                    FilterRow(
                                        filter: filter,
                                        isSelected: store.selectedFilterID == filter.id,
                                        isDownloaded: true
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(FMSpacing.large)
            }
            .background(FMColor.background)
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
