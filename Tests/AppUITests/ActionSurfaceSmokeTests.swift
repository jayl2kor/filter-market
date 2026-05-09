import XCTest

@MainActor
final class ActionSurfaceSmokeTests: MooditUITestCase {
    func testRouteEditor() { assertRoute(.editor) }
    func testRouteEditorParameters() { assertRoute(.editorParameters) }
    func testRouteEditorLUT() { assertRoute(.editorLUT) }
    func testRouteEditorDraft() { assertRoute(.editorDraft) }
    func testRouteUploadCover() { assertRoute(.uploadCover) }
    func testRouteUploadTags() { assertRoute(.uploadTags) }
    func testRouteUploadSubmit() { assertRoute(.uploadSubmit) }
    func testRouteUploadPending() { assertRoute(.uploadPending) }
    func testRouteMyFilters() { assertRoute(.myFilters) }
    func testRouteRemixFlow() { assertRoute(.remixFlow) }

    func testRouteAccountDeletion() { assertRoute(.accountDeletion) }
    func testRouteDataExport() { assertRoute(.dataExport) }
    func testRouteNotifications() { assertRoute(.notifications) }
    func testRouteNotificationSettings() { assertRoute(.notificationSettings) }
    func testRouteReportForm() { assertRoute(.reportForm) }
    func testRouteFavoritesCollection() { assertRoute(.favoritesCollection) }
    func testRouteModQueue() { assertRoute(.modQueue) }
    func testRouteModDetail() { assertRoute(.modDetail) }
    func testRouteBlockList() { assertRoute(.blockList) }
    func testRouteFilterRejected() { assertRoute(.filterRejected) }

    func testRouteWallet() { assertRoute(.wallet) }
    func testRouteWalletTopup() { assertRoute(.walletTopup) }
    func testRouteWalletTransactions() { assertRoute(.walletTransactions) }
    func testRouteInsufficientBalance() { assertRoute(.insufficientBalance) }
    func testRoutePaymentFailed() { assertRoute(.paymentFailed) }
    func testRouteRefundRequest() { assertRoute(.refundRequest) }
    func testRouteOrdersHistory() { assertRoute(.ordersHistory) }
    func testRouteProSubscription() { assertRoute(.proSubscription) }
    func testRouteProStatus() { assertRoute(.proStatus) }
    func testRoutePayoutOnboarding() { assertRoute(.payoutOnboarding) }
    func testRoutePayoutTaxInfo() { assertRoute(.payoutTaxInfo) }
    func testRoutePayoutHistory() { assertRoute(.payoutHistory) }
    func testRouteEarningsWithdraw() { assertRoute(.earningsWithdraw) }

    func testRouteSearch() { assertRoute(.search) }
    func testRouteFilterDetail() { assertRoute(.filterDetail) }
    func testRouteFilterDownload() { assertRoute(.filterDownload) }
    func testRouteFilterAfterDownload() { assertRoute(.filterAfterDownload) }
    func testRoutePaywallSingle() { assertRoute(.paywallSingle) }
    func testRouteUniversalLinkLanding() { assertRoute(.universalLinkLanding) }
    func testRouteEditProfile() { assertRoute(.editProfile) }
    func testRouteHelpCenter() { assertRoute(.helpCenter) }
    func testRouteCapturePreview() { assertRoute(.capturePreview) }

    func testRouteCameraPermissionPriming() { assertRoute(.cameraPermissionPriming) }
    func testRouteCameraPermissionDenied() { assertRoute(.cameraPermissionDenied) }
    func testRoutePhotosPermissionPriming() { assertRoute(.photosPermissionPriming) }
    func testRoutePhotosPermissionDenied() { assertRoute(.photosPermissionDenied) }
    func testRouteNotificationsPermissionPriming() { assertRoute(.notificationsPermissionPriming) }
    func testRouteNotificationsPermissionDenied() { assertRoute(.notificationsPermissionDenied) }
    func testRouteLocationPermissionPriming() { assertRoute(.locationPermissionPriming) }
    func testRouteLocationPermissionDenied() { assertRoute(.locationPermissionDenied) }

    private func assertRoute(
        _ spec: RouteSpec,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        launch(route: spec.route, isAuthenticated: true)
        for identifier in spec.identifiers {
            assertExists(identifier, route: spec.route, file: file, line: line)
        }
    }
}

private struct RouteSpec {
    let route: String
    let identifiers: [String]
}

private extension RouteSpec {
    static let editor = RouteSpec(route: "editor", identifiers: [
        "editor.preview",
        "editor.reference.photo.pick",
        "editor.reference.sample.portrait",
        "editor.params",
        "editor.lut",
        "editor.draft",
        "editor.next"
    ])
    static let editorParameters = RouteSpec(route: "editorParameters", identifiers: [
        "editor.preview",
        "editor.param.slider",
        "editor.compare.hold",
        "editor.next"
    ])
    static let editorLUT = RouteSpec(route: "editorLUT", identifiers: [
        "editor.preview",
        "editor.lut.import",
        "editor.lut.replace",
        "editor.next"
    ])
    static let editorDraft = RouteSpec(route: "editorDraft", identifiers: [
        "editor.draft.name",
        "editor.draft.description",
        "editor.draft.save",
        "editor.draft.publish"
    ])
    static let uploadCover = RouteSpec(route: "uploadCover", identifiers: [
        "upload.cover.add",
        "upload.signature.preview",
        "upload.signature.photo.pick",
        "upload.signature.sample.portrait",
        "upload.cover.ba.toggle",
        "upload.next",
        "upload.cancel"
    ])
    static let uploadTags = RouteSpec(route: "uploadTags", identifiers: [
        "upload.tag.add",
        "upload.cat.tap",
        "upload.next"
    ])
    static let uploadSubmit = RouteSpec(route: "uploadSubmit", identifiers: [
        "upload.tos.toggle",
        "upload.submit"
    ])
    static let uploadPending = RouteSpec(route: "uploadPending", identifiers: [
        "upload.pending.view_filter",
        "upload.pending.dismiss"
    ])
    static let myFilters = RouteSpec(route: "myFilters", identifiers: [
        "myfilters.fab.create",
        "myfilters.status.filter"
    ])
    static let remixFlow = RouteSpec(route: "remixFlow", identifiers: [
        "editor.remix.cancel",
        "editor.remix.open_editor"
    ])

    static let accountDeletion = RouteSpec(route: "accountDeletion", identifiers: [
        "auth.delete.confirm.input",
        "auth.delete.submit",
        "auth.delete.cancel"
    ])
    static let dataExport = RouteSpec(route: "dataExport", identifiers: [
        "settings.export.cat.toggle",
        "settings.export.format",
        "settings.export.submit"
    ])
    static let notifications = RouteSpec(route: "notifications", identifiers: [
        "notif.cat.all",
        "notif.settings"
    ])
    static let notificationSettings = RouteSpec(route: "notificationSettings", identifiers: [
        "notif.system.open",
        "notif.cat.toggle",
        "notif.quiet.toggle"
    ])
    static let reportForm = RouteSpec(route: "reportForm", identifiers: [
        "report.target",
        "report.reason",
        "report.detail",
        "report.submit"
    ])
    static let favoritesCollection = RouteSpec(route: "favoritesCollection", identifiers: [
        "collection.create",
        "collection.edit",
        "collection.card.tap"
    ])
    static let modQueue = RouteSpec(route: "modQueue", identifiers: [
        "modqueue.empty"
    ])
    static let modDetail = RouteSpec(route: "modDetail", identifiers: [
        "modDetail.approve",
        "modDetail.reason",
        "modDetail.reject"
    ])
    static let blockList = RouteSpec(route: "blockList", identifiers: [
        "blocklist.empty"
    ])
    static let filterRejected = RouteSpec(route: "filterRejected", identifiers: [
        "mod.rejected.review",
        "mod.rejected.detail",
        "mod.rejected.support",
        "mod.rejected.appeal",
        "mod.rejected.delete",
        "mod.rejected.edit"
    ])

    static let wallet = RouteSpec(route: "wallet", identifiers: [
        "wallet.balance",
        "wallet.action.코인 충전",
        "wallet.action.거래 내역"
    ])
    static let walletTopup = RouteSpec(route: "walletTopup", identifiers: [
        "wallet.topup.package.com.jayl2kor.moodit.coins.100",
        "wallet.topup.package.com.jayl2kor.moodit.coins.550",
        "wallet.topup.package.com.jayl2kor.moodit.coins.1200",
        "wallet.topup.package.com.jayl2kor.moodit.coins.3000",
        "wallet.topup.restore",
        "wallet.topup.failed_demo"
    ])
    static let walletTransactions = RouteSpec(route: "walletTransactions", identifiers: [
        "wallet.tx.filter.cat",
        "orders.history",
        "wallet.refund_request",
        "wallet.transactions.empty"
    ])
    static let insufficientBalance = RouteSpec(route: "insufficientBalance", identifiers: [
        "insufficient.topup",
        "wallet.insufficient.cancel"
    ])
    static let paymentFailed = RouteSpec(route: "paymentFailed", identifiers: [
        "wallet.topup.retry",
        "payment.failed.restore",
        "wallet.topup.support"
    ])
    static let refundRequest = RouteSpec(route: "refundRequest", identifiers: [
        "refund.orderId",
        "refund.reason",
        "refund.submit"
    ])
    static let ordersHistory = RouteSpec(route: "ordersHistory", identifiers: [
        "orders.empty",
        "wallet.transactions",
        "wallet.refund_request"
    ])
    static let proSubscription = RouteSpec(route: "proSubscription", identifiers: [
        "pro.plan.toggle",
        "pro.subscribe.com.jayl2kor.moodit.pro.monthly",
        "pro.subscribe.com.jayl2kor.moodit.pro.yearly",
        "pro.invoice"
    ])
    static let proStatus = RouteSpec(route: "proStatus", identifiers: [
        "pro.cancel",
        "pro.invoice"
    ])
    static let payoutOnboarding = RouteSpec(route: "payoutOnboarding", identifiers: [
        "payout.placeholder.정산 연결"
    ])
    static let payoutTaxInfo = RouteSpec(route: "payoutTaxInfo", identifiers: [
        "payout.placeholder.세금 정보"
    ])
    static let payoutHistory = RouteSpec(route: "payoutHistory", identifiers: [
        "payout.placeholder.정산 내역"
    ])
    static let earningsWithdraw = RouteSpec(route: "earningsWithdraw", identifiers: [
        "payout.placeholder.출금 신청"
    ])

    static let search = RouteSpec(route: "search", identifiers: [
        "search.suggested.#골든아워",
        "search.makers"
    ])
    static let filterDetail = RouteSpec(route: "filterDetail", identifiers: [
        "filter.detail.share",
        "filter.detail.follow",
        "filter.detail.sample.upload",
        "filter.detail.sample.gallery",
        "filter.detail.sample.reference.portrait",
        "filter.detail.reviews",
        "filter.detail.tags",
        "filter.detail.download"
    ])
    static let filterDownload = RouteSpec(route: "filterDownload", identifiers: [
        "filter.download.cancel",
        "filter.download.completed.next"
    ])
    static let filterAfterDownload = RouteSpec(route: "filterAfterDownload", identifiers: [
        "filter.apply",
        "filter.favorite.toggle",
        "filter.collection.add",
        "filter.remove"
    ])
    static let paywallSingle = RouteSpec(route: "paywallSingle", identifiers: [
        "filter.purchase.confirm",
        "filter.purchase.pro_upgrade"
    ])
    static let universalLinkLanding = RouteSpec(route: "universalLinkLanding", identifiers: [
        "app.deeplink.confirm",
        "app.deeplink.detail"
    ])
    static let editProfile = RouteSpec(route: "editProfile", identifiers: [
        "profile.edit.avatar.change",
        "profile.edit.name",
        "profile.edit.handle",
        "profile.edit.handle.check",
        "profile.edit.bio",
        "profile.edit.website",
        "profile.edit.save"
    ])
    static let helpCenter = RouteSpec(route: "helpCenter", identifiers: [
        "help.faq.coin",
        "help.email",
        "help.refund",
        "help.terms",
        "help.privacy"
    ])
    static let capturePreview = RouteSpec(route: "capturePreview", identifiers: [
        "preview.dismiss",
        "preview.more",
        "preview.retake",
        "preview.changeFilter",
        "preview.edit",
        "preview.discard",
        "preview.save",
        "preview.share"
    ])

    static let cameraPermissionPriming = RouteSpec(route: "cameraPermissionPriming", identifiers: [
        "permission.camera.priming.allow",
        "permission.camera.priming.skip"
    ])
    static let cameraPermissionDenied = RouteSpec(route: "cameraPermissionDenied", identifiers: [
        "permission.camera.denied.openSettings",
        "permission.camera.denied.dismiss"
    ])
    static let photosPermissionPriming = RouteSpec(route: "photosPermissionPriming", identifiers: [
        "permission.photos.priming.allow",
        "permission.photos.priming.skip"
    ])
    static let photosPermissionDenied = RouteSpec(route: "photosPermissionDenied", identifiers: [
        "permission.photos.denied.openSettings",
        "permission.photos.denied.dismiss"
    ])
    static let notificationsPermissionPriming = RouteSpec(route: "notificationsPermissionPriming", identifiers: [
        "permission.notifications.priming.allow",
        "permission.notifications.priming.skip"
    ])
    static let notificationsPermissionDenied = RouteSpec(route: "notificationsPermissionDenied", identifiers: [
        "permission.notifications.denied.openSettings",
        "permission.notifications.denied.dismiss"
    ])
    static let locationPermissionPriming = RouteSpec(route: "locationPermissionPriming", identifiers: [
        "permission.location.priming.allow",
        "permission.location.priming.skip"
    ])
    static let locationPermissionDenied = RouteSpec(route: "locationPermissionDenied", identifiers: [
        "permission.location.denied.openSettings",
        "permission.location.denied.dismiss"
    ])
}
