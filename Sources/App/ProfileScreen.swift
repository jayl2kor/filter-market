import DesignSystem
import SwiftUI

struct ProfileScreen: View {
    @EnvironmentObject private var store: FilterMarketStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FMSpacing.large) {
                    ScreenHeader(
                        title: "Profile",
                        subtitle: "Creator and account surfaces are placeholders for later phases."
                    )

                    HStack(spacing: FMSpacing.medium) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(FMColor.accent)

                        VStack(alignment: .leading, spacing: FMSpacing.xSmall) {
                            Text("Guest Maker")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.white)
                            Text("Anonymous session")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.62))
                        }
                    }
                    .padding(FMSpacing.large)
                    .background(FMColor.surface, in: RoundedRectangle(cornerRadius: 8))

                    HStack(spacing: FMSpacing.medium) {
                        stat("Filters", value: "\(store.libraryFilters.count)")
                        stat("Published", value: "0")
                        stat("Likes", value: "0")
                    }
                }
                .padding(FMSpacing.large)
            }
            .background(FMColor.background)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func stat(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: FMSpacing.xSmall) {
            Text(value)
                .font(.title2.monospacedDigit().weight(.bold))
                .foregroundStyle(.white)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.58))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FMSpacing.medium)
        .background(FMColor.surface, in: RoundedRectangle(cornerRadius: 8))
    }
}
