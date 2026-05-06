import DesignSystem
import SwiftUI

// MARK: - Camera / Download

struct FilterDownloadProgressScreen: View {
    let filterID: String
    var body: some View { ScreenWorkflowScaffold(route: .filterDownload(id: filterID)) }
}

struct FilterAfterDownloadScreen: View {
    let filterID: String
    var body: some View { ScreenWorkflowScaffold(route: .filterAfterDownload(id: filterID)) }
}

struct CameraAspectPickerScreen: View {
    var body: some View { ScreenWorkflowScaffold(route: .cameraAspect) }
}

struct CameraTimerCountdownScreen: View {
    var body: some View { ScreenWorkflowScaffold(route: .cameraTimer) }
}

struct PhotoImportScreen: View {
    var body: some View { ScreenWorkflowScaffold(route: .photoImport) }
}

struct PhotoEditScreen: View {
    var body: some View { ScreenWorkflowScaffold(route: .photoEdit) }
}

struct BuiltinFilterLibraryScreen: View {
    var body: some View { ScreenWorkflowScaffold(route: .builtinFilters) }
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
