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
        case .login:
            LoginScreen()
        case .emailLogin:
            EmailLoginScreen()
        case .filterDetail(let id):
            if UUID(uuidString: id) != nil {
                FilterDetailLoaderScreen(filterId: id)
            } else {
                #if DEBUG
                if isUITesting {
                    FilterDetailScreen(mock: FilterDetailMock.mock(forRouteID: id))
                } else {
                    FilterUnavailableScreen(filterID: id)
                }
                #else
                FilterUnavailableScreen(filterID: id)
                #endif
            }
        case .filterDownload(let id):
            FilterDownloadProgressScreen(filterID: id)
        case .filterAfterDownload(let id):
            FilterAfterDownloadScreen(filterID: id)
        case .reviews(let filterId):
            ReviewsListScreen(filterID: filterId)
        case .reviewCompose(let filterId):
            ReviewComposeScreen(filterID: filterId)
        case .rating(let filterId):
            RatingFormScreen(filterID: filterId)
        case .otherProfile(let uid, let seed):
            ProfileScreen(otherUid: uid, seed: seed, ownsNavigationStack: false)
        case .otherProfileHandle(let handle):
            ProfileHandleResolverScreen(handle: handle)
        case .followers(let uid):
            FollowersListScreen(userID: uid)
        case .following(let uid):
            FollowingListScreen(userID: uid)
        case .notifications:
            NotificationsInboxScreen()
        case .search(let initialQuery, let category):
            SearchScreen(initialQuery: initialQuery, initialCategory: category, showsBackButton: true)
        case .cameraAspect:
            CameraAspectPickerScreen()
        case .cameraTimer:
            CameraTimerCountdownScreen()
        case .photoImport:
            PhotoImportScreen()
        case .photoEdit:
            PhotoEditScreen()
        case .captureDetail(let id):
            CaptureDetailScreen(captureID: id)
        case .builtinFilters:
            BuiltinFilterLibraryScreen()
        case .editor:
            FilterEditorScreen()
        case .editorParameters:
            EditorParametersScreen()
        case .editorLUT:
            EditorLUTImportScreen()
        case .editorDraft:
            EditorDraftSaveScreen()
        case .uploadCover:
            UploadCoverScreen()
        case .uploadTags:
            UploadTagsCategoryScreen()
        case .uploadSubmit:
            UploadTOSSubmitScreen()
        case .uploadPending:
            UploadPendingReviewScreen()
        case .accountDeletion:
            AccountDeletionScreen()
        case .editProfile:
            EditProfileScreen()
        case .universalLinkLanding:
            UniversalLinkLandingScreen()
        case .wallet:
            WalletScreen()
        case .walletTopup:
            WalletTopupScreen()
        case .walletTransactions:
            WalletTransactionsScreen()
        case .insufficientBalance(let filterId):
            InsufficientBalanceScreen(filterID: filterId)
        case .ordersHistory:
            OrdersHistoryScreen()
        case .paymentFailed:
            PaymentFailedScreen()
        case .refundRequest(let orderId):
            RefundRequestScreen(prefilledOrderId: orderId)
        case .proStatus:
            ProStatusScreen()
        case .proSubscription:
            ProSubscriptionScreen()
        case .paywallSingle(let filterId):
            PaywallSingleScreen(filterID: filterId)
        case .myFilters:
            MyFiltersScreen()
        case .makerDashboard:
            MakerDashboardScreen()
        case .reportForm(let target):
            ReportFormScreen(target: target)
        case .favoritesCollection:
            FavoritesCollectionScreen()
        case .forYou:
            DiscoveryScreen(initialTab: .forYou)
        case .followingFeed:
            DiscoveryScreen(initialTab: .following)
        case .modQueue:
            ModerationQueueScreen()
        case .modDetail(let id):
            ModerationDetailScreen(itemID: id)
        case .blockList:
            BlockListScreen()
        case .remixFlow:
            RemixFlowScreen()
        case .payoutOnboarding:
            PayoutOnboardingScreen()
        case .payoutTaxInfo:
            PayoutTaxInfoScreen()
        case .payoutHistory:
            PayoutHistoryScreen()
        case .earningsWithdraw:
            EarningsWithdrawScreen()
        case .filterRejected(let id):
            FilterRejectedScreen(filterID: id)
        case .dataExport:
            DataExportScreen()
        case .helpCenter:
            HelpCenterScreen()
        case .settings:
            SettingsScreen()
        case .notificationSettings:
            NotificationSettingsScreen()
        case .savedFilters:
            SavedScreen(ownsNavigationStack: false)
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
