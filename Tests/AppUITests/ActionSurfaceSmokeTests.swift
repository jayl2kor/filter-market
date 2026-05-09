import XCTest

@MainActor
final class ActionSurfaceSmokeTests: MooditUITestCase {
    func testMakerEditorAndUploadSurfaces() {
        assertRoute("editor", exposes: [
            "editor.preview",
            "editor.reference.photo.pick",
            "editor.reference.sample.portrait",
            "editor.params",
            "editor.lut",
            "editor.draft",
            "editor.next"
        ])

        assertRoute("editorParameters", exposes: [
            "editor.preview",
            "editor.param.slider",
            "editor.compare.hold",
            "editor.next"
        ])

        assertRoute("editorLUT", exposes: [
            "editor.preview",
            "editor.lut.import",
            "editor.lut.replace",
            "editor.next"
        ])

        assertRoute("editorDraft", exposes: [
            "editor.draft.name",
            "editor.draft.description",
            "editor.draft.save",
            "editor.draft.publish"
        ])

        assertRoute("uploadCover", exposes: [
            "upload.cover.add",
            "upload.signature.preview",
            "upload.signature.photo.pick",
            "upload.signature.sample.portrait",
            "upload.cover.ba.toggle",
            "upload.next",
            "upload.cancel"
        ])

        assertRoute("uploadTags", exposes: [
            "upload.tag.add",
            "upload.cat.tap",
            "upload.next"
        ])

        assertRoute("uploadSubmit", exposes: [
            "upload.tos.toggle",
            "upload.submit"
        ])

        assertRoute("uploadPending", exposes: [
            "upload.pending.view_filter",
            "upload.pending.dismiss"
        ])

        assertRoute("myFilters", exposes: [
            "myfilters.fab.create",
            "myfilters.status.filter"
        ])

        assertRoute("remixFlow", exposes: [
            "editor.remix.cancel",
            "editor.remix.open_editor"
        ])
    }

    func testGovernanceNotificationAndModerationSurfaces() {
        assertRoute("accountDeletion", exposes: [
            "auth.delete.confirm.input",
            "auth.delete.submit",
            "auth.delete.cancel"
        ])

        assertRoute("dataExport", exposes: [
            "settings.export.cat.toggle",
            "settings.export.format",
            "settings.export.submit"
        ])

        assertRoute("notifications", exposes: [
            "notif.cat.all",
            "notif.settings"
        ])

        assertRoute("notificationSettings", exposes: [
            "notif.system.open",
            "notif.cat.toggle",
            "notif.quiet.toggle"
        ])

        assertRoute("reportForm", exposes: [
            "report.target",
            "report.reason",
            "report.detail",
            "report.submit"
        ])

        assertRoute("favoritesCollection", exposes: [
            "collection.create",
            "collection.edit",
            "collection.card.tap"
        ])

        assertRoute("modQueue", exposes: [
            "modqueue.empty"
        ])

        assertRoute("modDetail", exposes: [
            "modDetail.approve",
            "modDetail.reason",
            "modDetail.reject"
        ])

        assertRoute("blockList", exposes: [
            "blocklist.empty"
        ])

        assertRoute("filterRejected", exposes: [
            "mod.rejected.review",
            "mod.rejected.detail",
            "mod.rejected.support",
            "mod.rejected.appeal",
            "mod.rejected.delete",
            "mod.rejected.edit"
        ])
    }

    func testCommerceWalletAndPayoutSurfaces() {
        assertRoute("wallet", exposes: [
            "wallet.balance",
            "wallet.action.코인 충전",
            "wallet.action.거래 내역"
        ])

        assertRoute("walletTopup", exposes: [
            "wallet.topup.package.com.jayl2kor.moodit.coins.100",
            "wallet.topup.package.com.jayl2kor.moodit.coins.550",
            "wallet.topup.package.com.jayl2kor.moodit.coins.1200",
            "wallet.topup.package.com.jayl2kor.moodit.coins.3000",
            "wallet.topup.restore",
            "wallet.topup.failed_demo"
        ])

        assertRoute("walletTransactions", exposes: [
            "wallet.tx.filter.cat",
            "orders.history",
            "wallet.refund_request",
            "wallet.transactions.empty"
        ])

        assertRoute("insufficientBalance", exposes: [
            "insufficient.topup",
            "wallet.insufficient.cancel"
        ])

        assertRoute("paymentFailed", exposes: [
            "wallet.topup.retry",
            "payment.failed.restore",
            "wallet.topup.support"
        ])

        assertRoute("refundRequest", exposes: [
            "refund.orderId",
            "refund.reason",
            "refund.submit"
        ])

        assertRoute("ordersHistory", exposes: [
            "orders.empty",
            "wallet.transactions",
            "wallet.refund_request"
        ])

        assertRoute("proSubscription", exposes: [
            "pro.plan.toggle",
            "pro.subscribe.com.jayl2kor.moodit.pro.monthly",
            "pro.subscribe.com.jayl2kor.moodit.pro.yearly",
            "pro.invoice"
        ])

        assertRoute("proStatus", exposes: [
            "pro.cancel",
            "pro.invoice"
        ])

        assertRoute("payoutOnboarding", exposes: [
            "payout.placeholder.정산 연결"
        ])

        assertRoute("payoutTaxInfo", exposes: [
            "payout.placeholder.세금 정보"
        ])

        assertRoute("payoutHistory", exposes: [
            "payout.placeholder.정산 내역"
        ])

        assertRoute("earningsWithdraw", exposes: [
            "payout.placeholder.출금 신청"
        ])
    }

    func testMarketplaceSupportPermissionAndPreviewSurfaces() {
        assertRoute("search", exposes: [
            "search.suggested.#골든아워",
            "search.makers"
        ])

        assertRoute("filterDetail", exposes: [
            "filter.detail.share",
            "filter.detail.follow",
            "filter.detail.sample.gallery",
            "filter.detail.sample.reference.portrait",
            "filter.detail.reviews",
            "filter.detail.tags",
            "filter.detail.download"
        ])

        assertRoute("filterDownload", exposes: [
            "filter.download.cancel",
            "filter.download.completed.next"
        ])

        assertRoute("filterAfterDownload", exposes: [
            "filter.apply",
            "filter.favorite.toggle",
            "filter.collection.add",
            "filter.remove"
        ])

        assertRoute("paywallSingle", exposes: [
            "filter.purchase.confirm",
            "filter.purchase.pro_upgrade"
        ])

        assertRoute("universalLinkLanding", exposes: [
            "app.deeplink.confirm",
            "app.deeplink.detail"
        ])

        assertRoute("editProfile", exposes: [
            "profile.edit.avatar.change",
            "profile.edit.name",
            "profile.edit.handle",
            "profile.edit.handle.check",
            "profile.edit.bio",
            "profile.edit.website",
            "profile.edit.save"
        ])

        assertRoute("helpCenter", exposes: [
            "help.faq.coin",
            "help.email",
            "help.refund",
            "help.terms",
            "help.privacy"
        ])

        assertRoute("capturePreview", exposes: [
            "preview.dismiss",
            "preview.more",
            "preview.retake",
            "preview.changeFilter",
            "preview.edit",
            "preview.discard",
            "preview.save",
            "preview.share"
        ])
    }

    func testPermissionSurfaces() {
        assertRoute("cameraPermissionPriming", exposes: [
            "permission.camera.priming.allow",
            "permission.camera.priming.skip"
        ])

        assertRoute("cameraPermissionDenied", exposes: [
            "permission.camera.denied.openSettings",
            "permission.camera.denied.dismiss"
        ])

        assertRoute("photosPermissionPriming", exposes: [
            "permission.photos.priming.allow",
            "permission.photos.priming.skip"
        ])

        assertRoute("photosPermissionDenied", exposes: [
            "permission.photos.denied.openSettings",
            "permission.photos.denied.dismiss"
        ])

        assertRoute("notificationsPermissionPriming", exposes: [
            "permission.notifications.priming.allow",
            "permission.notifications.priming.skip"
        ])

        assertRoute("notificationsPermissionDenied", exposes: [
            "permission.notifications.denied.openSettings",
            "permission.notifications.denied.dismiss"
        ])

        assertRoute("locationPermissionPriming", exposes: [
            "permission.location.priming.allow",
            "permission.location.priming.skip"
        ])

        assertRoute("locationPermissionDenied", exposes: [
            "permission.location.denied.openSettings",
            "permission.location.denied.dismiss"
        ])
    }

    private func assertRoute(
        _ route: String,
        exposes identifiers: [String],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        launch(route: route, isAuthenticated: true)
        for identifier in identifiers {
            assertExists(identifier, route: route, file: file, line: line)
        }
    }
}
