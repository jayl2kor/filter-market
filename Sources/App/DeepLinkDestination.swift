import SwiftUI

/// Renders the destination view for a deep-link route. Mirrors
/// `appRouteDestinations()` but for the *initial* destination of a deep-link
/// presentation — `appRouteDestinations()` only handles `navigationDestination(for:)`
/// which is invoked by `NavigationLink` push, not by initial root content.
///
/// Keep this in sync with `appRouteDestinations()` for the routes we expect
/// to receive as deep links (filter detail, reviews, profile, notifications, search).
struct DeepLinkDestination: View {
    let route: AppRoute

    var body: some View {
        switch route {
        case .filterDetail(let id):
            if UUID(uuidString: id) != nil {
                FilterDetailLoaderScreen(filterId: id)
            } else {
                FilterDetailScreen(mock: FilterDetailMock.mock(forRouteID: id))
            }
        case .reviews(let filterId):
            ReviewsListScreen(filterID: filterId)
        case .reviewCompose(let filterId):
            ReviewComposeScreen(filterID: filterId)
        case .otherProfile:
            ProfileScreen(user: .other)
        case .notifications:
            NotificationsInboxScreen()
        case .search(let initialQuery, let category):
            SearchScreen(initialQuery: initialQuery, initialCategory: category)
        case .wallet:
            WalletScreen()
        case .walletTopup:
            WalletTopupScreen()
        case .walletTransactions:
            WalletTransactionsScreen()
        case .ordersHistory:
            OrdersHistoryScreen()
        case .refundRequest:
            RefundRequestScreen()
        case .proStatus:
            ProStatusScreen()
        case .proSubscription:
            ProSubscriptionScreen()
        case .myFilters:
            ProfileScreen()
        case .helpCenter:
            HelpCenterScreen()
        case .settings:
            SettingsScreen()
        case .notificationSettings:
            NotificationSettingsScreen()
        case .savedFilters:
            SavedScreen()
        default:
            // Truly unsupported routes — render a small fallback for QA debugging.
            VStack(spacing: 12) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
                Text("이 링크는 아직 지원되지 않아요.")
                    .foregroundStyle(.secondary)
                Text(String(describing: route))
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

extension AppRoute: Identifiable {
    /// Stable id derived from the route's stringified form so `.sheet(item:)`
    /// can deduplicate presentations.
    public var id: String {
        String(describing: self)
    }
}
