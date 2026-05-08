import DesignSystem
import SwiftUI
import UIKit

// MARK: - AppRoute

enum ReportTarget: Hashable {
    case filter(id: String)
    case review(id: String, filterId: String, authorUid: String?)
    case user(uid: String)

    var isSubmittable: Bool {
        switch self {
        case .filter(let id):
            return !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .review(let id, let filterId, _):
            return !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !filterId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .user(let uid):
            return !uid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}

/// SwiftUI route map for `docs/NAVIGATION.md`.
///
/// Every case is a concrete screen target from the navigation document.
enum AppRoute: Hashable {
    case login
    case emailLogin
    case search(initialQuery: String? = nil, category: String? = nil)
    case filterDetail(id: String)
    case filterDownload(id: String)
    case filterAfterDownload(id: String)
    case otherProfile(uid: String)
    case otherProfileHandle(handle: String)
    case settings
    case cameraAspect
    case cameraTimer
    case photoImport
    case photoEdit
    case captureDetail(id: String)
    case savedFilters
    case builtinFilters
    case editor
    case editorParameters
    case editorLUT
    case editorDraft
    case uploadCover
    case uploadTags
    case uploadSubmit
    case uploadPending
    case accountDeletion
    case editProfile
    case universalLinkLanding
    case reviews(filterId: String)
    case reviewCompose(filterId: String)
    case rating(filterId: String)
    case followers(uid: String)
    case following(uid: String)
    case notifications
    case notificationSettings
    case makerDashboard
    case reportForm(target: ReportTarget)
    case favoritesCollection
    case forYou
    case followingFeed
    case modQueue
    case modDetail(id: String)
    case blockList
    case remixFlow
    case paywallSingle(filterId: String)
    case proSubscription
    case ordersHistory
    case payoutOnboarding
    case payoutTaxInfo
    case payoutHistory
    case wallet
    case walletTopup
    case walletTransactions
    case insufficientBalance(filterId: String)
    case earningsWithdraw
    case filterRejected(id: String)
    case proStatus
    case myFilters
    case paymentFailed
    case dataExport
    case refundRequest(orderId: String?)
    case helpCenter
}

extension AppRoute {
    /// 분석 이벤트용 case 라벨 — 연관 값 제거. 예) filterDetail(id: "x") → "filterDetail".
    var telemetryKind: String {
        String(describing: self)
            .split(separator: "(")
            .first
            .map(String.init) ?? "unknown"
    }
}

extension View {
    /// Defines every `NavigationStack` destination in one place.
    func appRouteDestinations() -> some View {
        navigationDestination(for: AppRoute.self) { route in
            switch route {
            case .login:
                LoginScreen()

            case .emailLogin:
                EmailLoginScreen()

            case .search(let initialQuery, let category):
                SearchScreen(initialQuery: initialQuery, initialCategory: category)

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

            case .settings:
                SettingsScreen()

            case .otherProfile(let uid):
                ProfileScreen(otherUid: uid)

            case .otherProfileHandle(let handle):
                ProfileHandleResolverScreen(handle: handle)

            case .savedFilters:
                SavedScreen()

            case .filterDownload(let id):
                FilterDownloadProgressScreen(filterID: id)

            case .filterAfterDownload(let id):
                FilterAfterDownloadScreen(filterID: id)

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

            case .reviews(let filterId):
                ReviewsListScreen(filterID: filterId)

            case .reviewCompose(let filterId):
                ReviewComposeScreen(filterID: filterId)

            case .rating(let filterId):
                RatingFormScreen(filterID: filterId)

            case .followers(let uid):
                FollowersListScreen(userID: uid)

            case .following(let uid):
                FollowingListScreen(userID: uid)

            case .notifications:
                NotificationsInboxScreen()

            case .notificationSettings:
                NotificationSettingsScreen()

            case .makerDashboard:
                MakerDashboardScreen()

            case .reportForm(let target):
                ReportFormScreen(target: target)

            case .favoritesCollection:
                FavoritesCollectionScreen()

            case .forYou:
                ForYouFeedScreen()

            case .followingFeed:
                FollowingFeedScreen()

            case .modQueue:
                ModerationQueueScreen()

            case .modDetail(let id):
                ModerationDetailScreen(itemID: id)

            case .blockList:
                BlockListScreen()

            case .remixFlow:
                RemixFlowScreen()

            case .paywallSingle(let filterId):
                PaywallSingleScreen(filterID: filterId)

            case .proSubscription:
                ProSubscriptionScreen()

            case .ordersHistory:
                OrdersHistoryScreen()

            case .payoutOnboarding:
                PayoutOnboardingScreen()

            case .payoutTaxInfo:
                PayoutTaxInfoScreen()

            case .payoutHistory:
                PayoutHistoryScreen()

            case .wallet:
                WalletScreen()

            case .walletTopup:
                WalletTopupScreen()

            case .walletTransactions:
                WalletTransactionsScreen()

            case .insufficientBalance(let filterId):
                InsufficientBalanceScreen(filterID: filterId)

            case .earningsWithdraw:
                EarningsWithdrawScreen()

            case .filterRejected(let id):
                FilterRejectedScreen(filterID: id)

            case .proStatus:
                ProStatusScreen()

            case .myFilters:
                MyFiltersScreen()

            case .paymentFailed:
                PaymentFailedScreen()

            case .dataExport:
                DataExportScreen()

            case .refundRequest(let orderId):
                RefundRequestScreen(prefilledOrderId: orderId)

            case .helpCenter:
                HelpCenterScreen()
            }
        }
    }
}

// MARK: - Route metadata

struct RouteAction: Identifiable {
    let id: String
    let label: String
    let systemImage: String
    let target: AppRoute?
    let externalURL: URL?

    init(_ id: String, _ label: String, systemImage: String, target: AppRoute? = nil) {
        self.id = id
        self.label = label
        self.systemImage = systemImage
        self.target = target
        self.externalURL = nil
    }

    init(_ id: String, _ label: String, systemImage: String, externalURL: URL) {
        self.id = id
        self.label = label
        self.systemImage = systemImage
        self.target = nil
        self.externalURL = externalURL
    }
}

extension AppRoute {
    var title: String {
        switch self {
        case .login: "로그인"
        case .emailLogin: "이메일로 로그인"
        case .search: "검색"
        case .filterDetail: "필터 상세"
        case .filterDownload: "다운로드"
        case .filterAfterDownload: "다운로드 완료"
        case .otherProfile: "메이커 프로필"
        case .otherProfileHandle: "메이커 프로필"
        case .settings: "설정"
        case .cameraAspect: "촬영 비율"
        case .cameraTimer: "타이머"
        case .photoImport: "사진 가져오기"
        case .photoEdit: "사진 편집"
        case .captureDetail: "촬영 상세"
        case .savedFilters: "저장됨"
        case .builtinFilters: "기본 필터"
        case .editor: "필터 에디터"
        case .editorParameters: "파라미터"
        case .editorLUT: "LUT 가져오기"
        case .editorDraft: "초안 저장"
        case .uploadCover: "커버 업로드"
        case .uploadTags: "태그와 카테고리"
        case .uploadSubmit: "약관 및 제출"
        case .uploadPending: "검수 대기"
        case .accountDeletion: "계정 삭제"
        case .editProfile: "프로필 편집"
        case .universalLinkLanding: "공유 링크"
        case .reviews: "리뷰"
        case .reviewCompose: "리뷰 작성"
        case .rating: "평점 등록"
        case .followers: "팔로워"
        case .following: "팔로잉"
        case .notifications: "알림"
        case .notificationSettings: "알림 설정"
        case .makerDashboard: "메이커 대시보드"
        case .reportForm: "신고"
        case .favoritesCollection: "컬렉션"
        case .forYou: "For You"
        case .followingFeed: "팔로잉 피드"
        case .modQueue: "검수 큐"
        case .modDetail: "검수 상세"
        case .blockList: "차단 목록"
        case .remixFlow: "리믹스"
        case .paywallSingle: "필터 구매"
        case .proSubscription: "Pro 멤버십"
        case .ordersHistory: "주문 내역"
        case .payoutOnboarding: "정산 연결"
        case .payoutTaxInfo: "세금 정보"
        case .payoutHistory: "정산 내역"
        case .wallet: "지갑"
        case .walletTopup: "코인 충전"
        case .walletTransactions: "거래 내역"
        case .insufficientBalance: "잔액 부족"
        case .earningsWithdraw: "출금 신청"
        case .filterRejected: "검수 반려"
        case .proStatus: "Pro 상태"
        case .myFilters: "내 필터"
        case .paymentFailed: "결제 실패"
        case .dataExport: "데이터 내보내기"
        case .refundRequest: "환불 요청"
        case .helpCenter: "도움말"
        }
    }

    var subtitle: String {
        switch self {
        case .cameraAspect: "1:1, 4:3, 16:9 촬영 가이드를 선택합니다."
        case .cameraTimer: "OFF, 3초, 10초 타이머를 선택하고 카운트다운을 시작합니다."
        case .photoImport: "사진 접근 권한 이후 후보정할 이미지를 선택합니다."
        case .photoEdit: "필터와 강도를 조정하고 저장 또는 공유합니다."
        case .editor, .editorParameters, .editorLUT, .editorDraft:
            "LUT와 파라미터를 조합해 마켓에 올릴 필터 초안을 만듭니다."
        case .uploadCover, .uploadTags, .uploadSubmit, .uploadPending:
            "커버, 태그, 약관 동의를 거쳐 검수 대기 상태로 제출합니다."
        case .wallet, .walletTopup, .walletTransactions, .insufficientBalance, .paymentFailed, .refundRequest:
            "Coin 잔액, 충전, 구매 복원, 환불 안내를 처리합니다."
        case .payoutOnboarding, .payoutTaxInfo, .earningsWithdraw, .payoutHistory:
            "메이커 수익을 Stripe Connect 기반 정산 플로우로 연결합니다."
        case .modQueue, .modDetail, .filterRejected:
            "UGC 필터 검수와 승인, 반려, 이의 제기 흐름입니다."
        case .accountDeletion, .dataExport:
            "계정 삭제와 개인정보 사본 요청을 정책 요구사항에 맞춰 처리합니다."
        default:
            "NAVIGATION.md에 정의된 액션과 다음 화면을 실제 앱 라우트로 연결했습니다."
        }
    }

    var symbol: String {
        switch self {
        case .wallet, .walletTopup, .walletTransactions, .insufficientBalance: "creditcard"
        case .editor, .editorParameters, .editorLUT, .editorDraft, .remixFlow: "slider.horizontal.3"
        case .uploadCover, .uploadTags, .uploadSubmit, .uploadPending: "square.and.arrow.up"
        case .reviews, .reviewCompose: "bubble.left.and.bubble.right"
        case .notifications, .notificationSettings: "bell"
        case .modQueue, .modDetail, .filterRejected, .reportForm, .blockList: "shield.lefthalf.filled"
        case .proSubscription, .proStatus: "sparkles"
        case .cameraAspect, .cameraTimer, .photoImport, .photoEdit, .captureDetail: "camera"
        case .payoutOnboarding, .payoutTaxInfo, .earningsWithdraw, .payoutHistory: "banknote"
        default: "app.connected.to.app.below.fill"
        }
    }

    var primaryActions: [RouteAction] {
        switch self {
        case .filterDownload(let id):
            [
                .init("filter.download.cancel", "상세로 돌아가기", systemImage: "chevron.left", target: .filterDetail(id: id)),
                .init("filter.download.retry", "다운로드 다시 시도", systemImage: "arrow.clockwise"),
                .init("filter.apply", "카메라로 적용", systemImage: "camera.fill", target: .filterAfterDownload(id: id))
            ]

        case .filterAfterDownload:
            [
                .init("filter.apply", "카메라로 적용", systemImage: "camera.fill"),
                .init("filter.favorite.toggle", "즐겨찾기 토글", systemImage: "heart"),
                .init("filter.collection.add", "컬렉션에 추가", systemImage: "folder.badge.plus", target: .favoritesCollection),
                .init("filter.remove", "다운로드 제거", systemImage: "trash")
            ]

        case .cameraAspect:
            [
                .init("cam.aspect.set.1_1", "1:1 선택", systemImage: "square"),
                .init("cam.aspect.set.4_3", "4:3 선택", systemImage: "rectangle"),
                .init("cam.aspect.set.16_9", "16:9 선택", systemImage: "rectangle.compress.vertical")
            ]

        case .cameraTimer:
            [
                .init("cam.timer.set.off", "타이머 끄기", systemImage: "timer"),
                .init("cam.timer.set.3", "3초 타이머", systemImage: "3.circle"),
                .init("cam.timer.set.10", "10초 타이머", systemImage: "10.circle"),
                .init("cam.timer.cancel", "카운트다운 취소", systemImage: "xmark.circle")
            ]

        case .photoImport:
            [
                .init("photo.import.cell.tap", "사진 선택", systemImage: "photo.on.rectangle"),
                .init("photo.import.next", "필터 적용", systemImage: "wand.and.stars", target: .photoEdit)
            ]

        case .photoEdit:
            [
                .init("photo.edit.filter.tap", "필터 변경", systemImage: "camera.filters"),
                .init("photo.edit.intensity", "강도 조정", systemImage: "slider.horizontal.3"),
                .init("photo.edit.save_share", "저장 / 공유", systemImage: "square.and.arrow.up")
            ]

        case .editor:
            [
                .init("editor.params", "파라미터 편집", systemImage: "slider.horizontal.3", target: .editorParameters),
                .init("editor.lut", "LUT 가져오기", systemImage: "cube.transparent", target: .editorLUT),
                .init("editor.draft", "초안 저장", systemImage: "tray.and.arrow.down", target: .editorDraft),
                .init("editor.next", "마켓 공유로 계속", systemImage: "arrow.right", target: .uploadCover)
            ]

        case .editorParameters:
            [
                .init("editor.param.slider", "노출 / 대비 / 채도 조정", systemImage: "slider.horizontal.below.rectangle"),
                .init("editor.compare.hold", "비포 보기", systemImage: "rectangle.lefthalf.filled"),
                .init("editor.next", "LUT 단계로 이동", systemImage: "arrow.right", target: .editorLUT)
            ]

        case .editorLUT:
            [
                .init("editor.lut.import", "Files에서 LUT 가져오기", systemImage: "folder", target: nil),
                .init("editor.lut.replace", "LUT 교체", systemImage: "arrow.triangle.2.circlepath"),
                .init("editor.next", "초안 저장", systemImage: "arrow.right", target: .editorDraft)
            ]

        case .editorDraft:
            [
                .init("editor.draft.save", "초안 저장 후 내 필터", systemImage: "tray", target: .myFilters),
                .init("editor.draft.publish", "바로 마켓 공유", systemImage: "paperplane", target: .uploadCover)
            ]

        case .uploadCover:
            [
                .init("upload.cover.add", "커버 사진 추가", systemImage: "photo.badge.plus"),
                .init("upload.cover.ba.toggle", "자동 비포/애프터 토글", systemImage: "rectangle.split.2x1"),
                .init("upload.next", "태그와 카테고리", systemImage: "arrow.right", target: .uploadTags)
            ]

        case .uploadTags:
            [
                .init("upload.tag.add", "태그 추가", systemImage: "number"),
                .init("upload.cat.tap", "카테고리 선택", systemImage: "square.grid.2x2"),
                .init("upload.next", "약관 및 제출", systemImage: "arrow.right", target: .uploadSubmit)
            ]

        case .uploadSubmit:
            [
                .init("upload.tos.toggle", "약관 동의", systemImage: "checkmark.square"),
                .init("upload.submit", "검수 제출", systemImage: "paperplane.fill", target: .uploadPending)
            ]

        case .uploadPending:
            [
                .init("upload.pending.view_filter", "내 필터 보기", systemImage: "rectangle.stack", target: .myFilters),
                .init("upload.pending.dismiss", "닫기", systemImage: "xmark")
            ]

        case .accountDeletion:
            [
                .init("auth.delete.confirm.input", "유저네임 확인 입력", systemImage: "keyboard"),
                .init("auth.delete.submit", "계정 영구 삭제", systemImage: "trash"),
                .init("auth.delete.cancel", "취소", systemImage: "xmark")
            ]

        case .editProfile:
            [
                .init("profile.edit.avatar.change", "사진 변경", systemImage: "person.crop.circle.badge.plus"),
                .init("profile.edit.handle.check", "유저네임 중복 확인", systemImage: "checkmark.seal"),
                .init("profile.edit.save", "저장", systemImage: "checkmark")
            ]

        case .reviews(let id):
            [
                .init("social.reviews.compose", "리뷰 작성", systemImage: "square.and.pencil", target: .reviewCompose(filterId: id)),
                .init("social.rating.open", "평점 등록", systemImage: "star", target: .rating(filterId: id)),
                .init("social.review.author", "작성자 프로필", systemImage: "person", target: .otherProfile(uid: "review-author"))
            ]

        case .reviewCompose:
            [
                .init("social.compose.send", "게시", systemImage: "paperplane.fill"),
                .init("social.review.makerReply", "메이커 답글", systemImage: "arrowshape.turn.up.left")
            ]

        case .rating:
            [
                .init("social.rating.star", "별점 선택", systemImage: "star.fill"),
                .init("social.rating.submit", "평점 등록", systemImage: "checkmark")
            ]

        case .followers(let uid):
            [
                .init("social.user.tap", "사용자 프로필", systemImage: "person", target: .otherProfile(uid: uid)),
                .init("social.follow.toggle", "팔로우 토글", systemImage: "person.badge.plus")
            ]

        case .following(let uid):
            [
                .init("social.user.tap", "사용자 프로필", systemImage: "person", target: .otherProfile(uid: uid)),
                .init("social.follow.toggle", "팔로잉 토글", systemImage: "person.badge.minus")
            ]

        case .notifications:
            [
                .init("notif.settings", "알림 설정", systemImage: "gearshape", target: .notificationSettings),
                .init("notif.tap", "필터 알림 열기", systemImage: "bell.badge", target: .filterDetail(id: "sample-filter")),
                .init("notif.follow.action", "팔로우 수락", systemImage: "person.badge.plus")
            ]

        case .notificationSettings:
            [
                .init("notif.system.open", "iOS 설정 열기", systemImage: "gearshape", externalURL: URL(string: UIApplication.openSettingsURLString)!),
                .init("notif.cat.toggle", "카테고리별 알림 토글", systemImage: "switch.2"),
                .init("notif.quiet.toggle", "방해 금지 토글", systemImage: "moon")
            ]

        case .makerDashboard:
            [
                .init("maker.dashboard.withdraw", "출금 신청", systemImage: "banknote", target: .earningsWithdraw),
                .init("maker.period.set", "기간 변경", systemImage: "calendar"),
                .init("maker.filter.row", "필터 상세 보기", systemImage: "camera.filters", target: .filterDetail(id: "sample-filter"))
            ]

        case .reportForm:
            [
                .init("report.target", "신고 대상 확인", systemImage: "number"),
                .init("report.reason", "신고 사유 선택", systemImage: "list.bullet.circle"),
                .init("report.detail", "상세 설명 입력", systemImage: "square.and.pencil"),
                .init("report.submit", "신고 제출", systemImage: "paperplane.fill")
            ]

        case .favoritesCollection:
            [
                .init("collection.create", "새 컬렉션 만들기", systemImage: "folder.badge.plus"),
                .init("collection.card.tap", "컬렉션 열기", systemImage: "folder", target: .search(initialQuery: nil, category: "컬렉션")),
                .init("collection.edit", "편집 모드", systemImage: "pencil")
            ]

        case .forYou:
            [
                .init("social.foryou.hero.apply", "추천 필터 열기", systemImage: "sparkles", target: .filterDetail(id: "recommended-filter")),
                .init("social.foryou.hero.save", "추천 필터 저장", systemImage: "bookmark"),
                .init("market.tile.tap", "추천 필터 열기", systemImage: "sparkles", target: .filterDetail(id: "recommended-filter")),
                .init("market.maker.tap", "추천 메이커", systemImage: "person", target: .otherProfile(uid: "maker")),
                .init("social.foryou.maker.follow", "추천 메이커 팔로우", systemImage: "person.badge.plus")
            ]

        case .followingFeed:
            [
                .init("market.tile.tap", "팔로잉 필터 열기", systemImage: "camera.filters", target: .filterDetail(id: "Honey Glow")),
                .init("profile.following", "팔로잉 목록", systemImage: "person.2", target: .following(uid: "me")),
                .init("social.following.post.more", "피드 옵션", systemImage: "ellipsis"),
                .init("social.following.post.hide", "피드에서 숨기기", systemImage: "eye.slash")
            ]

        case .modQueue:
            [
                .init("mod.queue.filter.tap", "큐 필터 변경", systemImage: "line.3.horizontal.decrease.circle"),
                .init("mod.queue.row", "검수 항목 열기", systemImage: "doc.text.magnifyingglass", target: .modDetail(id: "pending-filter"))
            ]

        case .modDetail(let id):
            [
                .init("modDetail.approve", "승인", systemImage: "checkmark.seal"),
                .init("modDetail.reason", "거부 사유", systemImage: "square.and.pencil"),
                .init("modDetail.reject", "거부", systemImage: "xmark.seal", target: .filterRejected(id: id)),
                .init("modDetail.undo", "되돌리기", systemImage: "arrow.uturn.backward"),
                .init("mod.detail.takedown", "Takedown", systemImage: "trash")
            ]

        case .blockList:
            [
                .init("social.block.tab", "차단/뮤트 탭 전환", systemImage: "rectangle.2.swap"),
                .init("social.block.toggle", "차단 해제", systemImage: "person.crop.circle.badge.xmark")
            ]

        case .remixFlow:
            [
                .init("editor.remix.open_editor", "에디터 열기", systemImage: "slider.horizontal.3", target: .editor),
                .init("editor.remix.cancel", "취소", systemImage: "xmark")
            ]

        case .paywallSingle(let id):
            [
                .init("filter.purchase.confirm", "Coin으로 구매", systemImage: "creditcard", target: .filterDownload(id: id)),
                .init("filter.purchase.pro_upgrade", "Pro 멤버십 보기", systemImage: "sparkles", target: .proSubscription)
            ]

        case .proSubscription:
            [
                .init("pro.plan.toggle", "월간/연간 전환", systemImage: "arrow.left.arrow.right"),
                .init("pro.subscribe.\(IAPProductIDs.proMonthly)", "월간 Pro 시작", systemImage: "sparkles"),
                .init("pro.subscribe.\(IAPProductIDs.proYearly)", "연간 Pro 시작", systemImage: "sparkles"),
                .init("pro.invoice", "영수증", systemImage: "doc.text", target: .refundRequest(orderId: nil))
            ]

        case .proStatus:
            [
                .init("pro.cancel", "App Store 구독 관리", systemImage: "gearshape", externalURL: URL(string: "https://apps.apple.com/account/subscriptions")!),
                .init("pro.invoice", "영수증 / 환불 안내", systemImage: "doc.text", target: .refundRequest(orderId: nil))
            ]

        case .ordersHistory:
            [
                .init("wallet.transactions", "거래 내역", systemImage: "list.bullet.rectangle", target: .walletTransactions),
                .init("wallet.refund_request", "환불 요청", systemImage: "arrow.uturn.backward.circle", target: .refundRequest(orderId: nil))
            ]

        case .wallet:
            // Closed-loop virtual currency 모델 — 메이커 출금은 Phase 6+ 후보 (ADR-0006).
            // payoutOnboarding/earningsWithdraw 라우트는 enum에 유지하되 진입점 노출 X.
            [
                .init("wallet.topup", "충전하기", systemImage: "plus.circle", target: .walletTopup),
                .init("wallet.transactions", "거래내역", systemImage: "list.bullet.rectangle", target: .walletTransactions),
                .init("wallet.pro", "Pro 시작", systemImage: "sparkles", target: .proSubscription)
            ]

        case .walletTopup:
            [
                .init("wallet.topup.package.\(IAPProductIDs.coins100)", "100 C 충전", systemImage: "creditcard"),
                .init("wallet.topup.package.\(IAPProductIDs.coins550)", "550 C 충전", systemImage: "creditcard.fill"),
                .init("wallet.topup.package.\(IAPProductIDs.coins1200)", "1200 C 충전", systemImage: "creditcard.fill"),
                .init("wallet.topup.package.\(IAPProductIDs.coins3000)", "3000 C 충전", systemImage: "creditcard.fill"),
                .init("wallet.topup.restore", "이전 구매 복원", systemImage: "arrow.clockwise"),
                .init("wallet.topup.failed_demo", "결제 실패 화면 보기", systemImage: "exclamationmark.triangle", target: .paymentFailed)
            ]

        case .walletTransactions:
            [
                .init("wallet.tx.filter.cat", "거래 유형 필터", systemImage: "line.3.horizontal.decrease.circle"),
                .init("orders.history", "주문 내역", systemImage: "cart", target: .ordersHistory),
                .init("wallet.refund_request", "환불 요청", systemImage: "arrow.uturn.backward.circle", target: .refundRequest(orderId: nil))
            ]

        case .insufficientBalance:
            [
                .init("insufficient.purchase.retry", "지금 구매하기", systemImage: "creditcard"),
                .init("insufficient.topup", "충전 화면으로", systemImage: "plus.circle", target: .walletTopup),
                .init("wallet.insufficient.cancel", "취소", systemImage: "xmark")
            ]

        case .paymentFailed:
            [
                .init("wallet.topup.retry", "다시 시도", systemImage: "arrow.clockwise", target: .walletTopup),
                .init("payment.failed.restore", "이전 구매 복원", systemImage: "clock.arrow.circlepath"),
                .init("wallet.topup.support", "고객지원", systemImage: "envelope", externalURL: URL(string: "mailto:support@moodit.app")!)
            ]

        case .earningsWithdraw:
            [
                .init("payout.bank.change", "은행 변경", systemImage: "building.columns", target: .payoutOnboarding),
                .init("payout.amount.quick", "빠른 금액 선택", systemImage: "plusminus.circle"),
                .init("payout.submit", "출금 신청", systemImage: "paperplane.fill", target: .payoutHistory)
            ]

        case .payoutOnboarding:
            [
                .init("payout.stripe.connect", "Stripe Connect 열기", systemImage: "safari", target: .payoutTaxInfo)
            ]

        case .payoutTaxInfo:
            [
                .init("payout.tax.save", "세금 정보 저장", systemImage: "checkmark", target: .earningsWithdraw)
            ]

        case .payoutHistory:
            [
                .init("payout.history.row", "정산 상세 보기", systemImage: "doc.text.magnifyingglass")
            ]

        case .filterRejected(let id):
            [
                .init("mod.rejected.review", "검수 결과 확인", systemImage: "doc.text"),
                .init("mod.rejected.edit", "에디터에서 수정", systemImage: "slider.horizontal.3", target: .editor),
                .init("mod.rejected.appeal", "이의 제기", systemImage: "safari", externalURL: URL(string: "https://moodit.app/appeal")!),
                .init("mod.rejected.detail", "상세로 돌아가기", systemImage: "camera.filters", target: .filterDetail(id: id))
            ]

        case .myFilters:
            [
                .init("myfilters.status.filter", "상태 필터", systemImage: "line.3.horizontal.decrease.circle"),
                .init("myfilters.fab.create", "새 필터 만들기", systemImage: "plus", target: .editor),
                .init("myfilters.row.dashboard", "통계 보기", systemImage: "chart.bar", target: .makerDashboard),
                .init("myfilters.row.takedown", "비공개 전환", systemImage: "eye.slash")
            ]

        case .dataExport:
            [
                .init("settings.export.cat.toggle", "내보낼 데이터 선택", systemImage: "checklist"),
                .init("settings.export.format", "JSON / CSV / HTML", systemImage: "doc.on.doc"),
                .init("settings.export.submit", "데이터 사본 요청", systemImage: "paperplane.fill")
            ]

        case .refundRequest:
            [
                .init("refund.orderId", "주문 ID 입력", systemImage: "number"),
                .init("refund.reason", "환불 사유 입력", systemImage: "square.and.pencil"),
                .init("refund.submit", "환불 요청 제출", systemImage: "paperplane.fill")
            ]

        case .builtinFilters:
            [
                .init("builtin.filter.tap", "기본 필터 상세", systemImage: "camera.filters", target: .filterDetail(id: "Soft Portra")),
                .init("builtin.manage", "메이커 필터 관리", systemImage: "rectangle.stack", target: .myFilters)
            ]

        case .universalLinkLanding:
            [
                .init("app.deeplink.confirm", "다운로드 + 카메라 열기", systemImage: "arrow.down.circle", target: .filterDownload(id: "sample-filter")),
                .init("app.deeplink.detail", "상세 페이지", systemImage: "doc.text.magnifyingglass", target: .filterDetail(id: "sample-filter"))
            ]

        default:
            []
        }
    }
}

// MARK: - ScreenWorkflowScaffold

struct ScreenWorkflowScaffold: View {
    let route: AppRoute

    @Environment(\.dismiss) private var dismiss
    @State private var statusMessage: String?
    @State private var primaryToggle = true
    @State private var secondaryToggle = false
    @State private var textValue = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.lg) {
                hero
                stateCard
                actionsCard
                sampleContent
            }
            .padding(Sp.md)
            .padding(.bottom, FMLayout.tabBarHeight + Sp.xxxl)
        }
        .background(FMColors.Background.bg1)
        .navigationTitle(route.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    statusMessage = "공유 링크를 만들었습니다."
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("공유")
            }
        }
        .alert("처리 완료", isPresented: Binding(
            get: { statusMessage != nil },
            set: { if !$0 { statusMessage = nil } }
        )) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(statusMessage ?? "")
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: Sp.md) {
            Image(systemName: route.symbol)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(FMColors.Accent.primary)
                .frame(width: 56, height: 56)
                .background(FMColors.Accent.bg, in: RoundedRectangle(cornerRadius: R.lg))
                .overlay {
                    RoundedRectangle(cornerRadius: R.lg)
                        .strokeBorder(FMColors.Accent.primary.opacity(0.25), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: Sp.xs) {
                Text(route.title)
                    .fmTypography(.titleLarge)
                    .foregroundStyle(FMColors.Text.primary)
                Text(route.subtitle)
                    .fmTypography(.body)
                    .foregroundStyle(FMColors.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var stateCard: some View {
        FMCard {
            VStack(alignment: .leading, spacing: Sp.md) {
                Text("화면 상태")
                    .fmTypography(.headline)
                    .foregroundStyle(FMColors.Text.primary)

                Toggle("기본 옵션", isOn: $primaryToggle)
                    .tint(FMColors.Accent.primary)
                Toggle("추가 옵션", isOn: $secondaryToggle)
                    .tint(FMColors.Accent.primary)

                FMTextField(
                    "입력값",
                    text: $textValue,
                    placeholder: "유저네임, 태그, 금액, 사유 등"
                )
            }
        }
    }

    private var actionsCard: some View {
        FMCard {
            VStack(alignment: .leading, spacing: Sp.sm) {
                Text("액션")
                    .fmTypography(.headline)
                    .foregroundStyle(FMColors.Text.primary)

                ForEach(route.primaryActions) { action in
                    actionRow(action)
                }

                if route.primaryActions.isEmpty {
                    Text("이 화면의 세부 액션은 전용 화면에서 직접 처리됩니다.")
                        .fmTypography(.body)
                        .foregroundStyle(FMColors.Text.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, Sp.sm)
                }
            }
        }
    }

    @ViewBuilder
    private func actionRow(_ action: RouteAction) -> some View {
        if let target = action.target {
            NavigationLink(value: target) {
                rowLabel(action, trailing: "chevron.right")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(action.id)
        } else {
            Button {
                FMHaptic.light.play()
                if let url = action.externalURL {
                    UIApplication.shared.open(url)
                } else {
                    statusMessage = "\(action.label) 액션을 처리했습니다."
                }
            } label: {
                rowLabel(action, trailing: action.externalURL == nil ? nil : "arrow.up.forward")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(action.id)
        }
    }

    private func rowLabel(_ action: RouteAction, trailing: String?) -> some View {
        HStack(spacing: Sp.sm) {
            Image(systemName: action.systemImage)
                .font(.system(size: IconSize.md, weight: .regular))
                .foregroundStyle(FMColors.Accent.primary)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(action.label)
                    .fmTypography(.body)
                    .foregroundStyle(FMColors.Text.primary)
                Text(action.id)
                    .fmTypography(.caption)
                    .foregroundStyle(FMColors.Text.tertiary)
            }

            Spacer(minLength: Sp.xs)

            if let trailing {
                Image(systemName: trailing)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FMColors.Text.tertiary)
            }
        }
        .padding(.vertical, Sp.xs)
        .contentShape(Rectangle())
    }

    private var sampleContent: some View {
        VStack(alignment: .leading, spacing: Sp.sm) {
            Text("콘텐츠")
                .fmTypography(.headline)
                .foregroundStyle(FMColors.Text.primary)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: Sp.sm),
                    GridItem(.flexible(), spacing: Sp.sm)
                ],
                spacing: Sp.sm
            ) {
                ForEach(sampleCards, id: \.0) { card in
                    sampleCard(title: card.0, subtitle: card.1, symbol: card.2)
                }
            }
        }
    }

    private var sampleCards: [(String, String, String)] {
        switch route {
        case .wallet, .walletTopup, .walletTransactions:
            [("1,240 C", "사용 가능 잔액", "circle.hexagongrid"), ("300 C", "이번 달 충전", "plus.circle"), ("-80 C", "필터 구매", "cart"), ("복원 가능", "IAP 상태", "arrow.clockwise")]
        case .makerDashboard, .earningsWithdraw, .payoutHistory:
            [("₩126,000", "출금 가능", "banknote"), ("18", "판매 필터", "camera.filters"), ("4.8", "평균 평점", "star"), ("30일", "선택 기간", "calendar")]
        case .modQueue, .modDetail, .filterRejected:
            [("7건", "신규 검수", "doc.badge.clock"), ("2건", "사용자 신고", "exclamationmark.bubble"), ("1건", "반려 대기", "xmark.seal"), ("자동", "우선순위", "wand.and.stars")]
        default:
            [("준비 중", "콘텐츠", "camera.filters"), ("연결 예정", "데이터", "link"), ("-", "평점", "star"), ("-", "다운로드", "arrow.down.circle")]
        }
    }

    private func sampleCard(title: String, subtitle: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: Sp.sm) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(FMColors.Accent.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fmTypography(.headline)
                    .foregroundStyle(FMColors.Text.primary)
                    .lineLimit(1)
                Text(subtitle)
                    .fmTypography(.caption)
                    .foregroundStyle(FMColors.Text.secondary)
            }
        }
        .padding(Sp.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FMColors.Background.bg2, in: RoundedRectangle(cornerRadius: R.lg))
        .overlay {
            RoundedRectangle(cornerRadius: R.lg)
                .strokeBorder(FMColors.Border.subtle, lineWidth: 1)
        }
    }
}

// MARK: - Filter route lookup

extension FilterDetailMock {
    static func mock(forRouteID id: String) -> FilterDetailMock {
        #if DEBUG
        let tiles = MarketplaceMockData.trending + MarketplaceMockData.newFilters
        guard let tile = tiles.first(where: { $0.title == id }) else {
            return .preview
        }

        return FilterDetailMock(
            sourceID: id,
            displayTitle: tile.title,
            makerHandle: tile.makerName,
            makerInitials: String(tile.makerName.replacingOccurrences(of: "@", with: "").prefix(2)).uppercased(),
            categoryLabel: tile.priceLabel == nil ? "무료 필터" : "유료 필터",
            downloadCount: tile.downloadCount,
            rating: 4.7,
            reviewCount: max(24, tile.downloadCount / 40),
            likeCount: tile.downloadCount / 6,
            description: "NAVIGATION.md 라우트에서 열린 필터입니다. 무료 다운로드, Coin 구매, 리뷰, 신고, 공유 흐름을 이 상세 화면에서 이어갈 수 있습니다.",
            tags: ["#mood", "#daily", "#route", "#moodit"],
            coverURL: tile.previewImageURL,
            signatureSampleURL: nil,
            filterCategory: .cinematic,
            reviews: [],
            categoryHint: tile.categoryHint ?? FMColors.Category.cinematic,
            isPaid: tile.priceLabel != nil,
            priceLabel: tile.priceLabel
        )
        #else
        FilterDetailMock(
            sourceID: id.isEmpty ? nil : id,
            displayTitle: id.isEmpty ? "필터" : id,
            makerHandle: "@maker",
            makerInitials: "M",
            categoryLabel: "필터",
            downloadCount: 0,
            rating: 0,
            reviewCount: 0,
            likeCount: 0,
            description: "필터 정보를 불러올 수 없습니다.",
            tags: [],
            coverURL: nil,
            signatureSampleURL: nil,
            filterCategory: .cinematic,
            reviews: [],
            categoryHint: FMColors.Category.cinematic,
            isPaid: false,
            priceLabel: nil
        )
        #endif
    }
}

struct FilterUnavailableScreen: View {
    let filterID: String

    var body: some View {
        FMEmptyState(.noSearchResults(query: filterID.isEmpty ? "필터" : filterID))
            .padding(Sp.xl)
            .navigationTitle("필터를 찾을 수 없어요")
            .navigationBarTitleDisplayMode(.inline)
    }
}
