import DesignSystem
import Models
import SwiftUI

// MARK: - Camera / Download

struct FilterDownloadProgressScreen: View {
    let filterID: String

    @EnvironmentObject private var store: MooditStore
    @State private var phase: DownloadPhase = .preparing
    @State private var progress: Double = 0
    @State private var hasStarted = false

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
        .task {
            await startDownloadIfNeeded()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Sp.xs) {
            Text(filterID)
                .fmTypography(.titleLarge)
                .foregroundStyle(FMColors.Text.primary)
            Text(phase.description)
                .fmTypography(.body)
                .foregroundStyle(FMColors.Text.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        guard let filter else {
            phase = .failed
            return
        }
        if store.isDownloaded(filter) {
            progress = 1
            phase = .completed
            return
        }
        phase = .downloading
        for step in 1...6 {
            try? await Task.sleep(nanoseconds: 130_000_000)
            progress = Double(step) / 6
        }
        store.download(filter)
        FMHaptic.success.play()
        phase = .completed
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
