import XCTest

@MainActor
final class P0CoreActionTests: MooditUITestCase {
    func testLoginContract() {
        launch(route: "login")

        assertExists("auth.apple", timeout: 4)
        assertExists("auth.google")
        XCTAssertTrue(element("auth.email.continue").exists)
        XCTAssertTrue(element("auth.guest.continue").exists)
        XCTAssertTrue(element("auth.terms").exists)
    }

    func testEmailAuthContract() {
        launch(route: "emailLogin")
        assertExists("auth.email.input", timeout: 4)
        assertExists("auth.password.input")
        assertExists("auth.signIn.submit")
        assertExists("auth.passwordReset.send")
        assertExists("auth.mode.toggle")

        tap("auth.mode.toggle")

        assertExists("auth.signUp.submit", timeout: 2)
        assertExists("auth.password.hint")
    }

    func testRootTabShellExposesCoreTabs() {
        launch(isAuthenticated: false)

        assertExists("tab.market", timeout: 8)
        assertExists("tab.search")
        assertExists("tab.shutter")
        assertExists("tab.saved")
        assertExists("tab.profile")
    }

    func testRootTabShellSearchSavedAndProfileGuestFlow() {
        launch(isAuthenticated: false)
        tap("tab.search")
        XCTAssertTrue(app.staticTexts["발견"].waitForExistence(timeout: 4))
        assertExists("discover.feed")

        tap("tab.saved")
        XCTAssertTrue(app.staticTexts["저장됨"].waitForExistence(timeout: 4))

        tap("tab.profile")
        XCTAssertTrue(app.staticTexts["로그인이 필요해요"].waitForExistence(timeout: 4))
        assertExists("profile.login")
    }

    func testGuestProfileCanOpenSettings() {
        launch(isAuthenticated: false)

        tap("tab.profile")
        tap("profile.settings", timeout: 4)

        XCTAssertTrue(app.staticTexts["설정"].waitForExistence(timeout: 4))
        assertExists("settings.row.그리드 표시")
        assertExists("settings.row.이용약관")
        assertExists("settings.locked.프로필 편집")
        assertExists("settings.login")
    }

    func testProfileLoginCanContinueAsGuestWithoutTabBarLeak() {
        launch(isAuthenticated: false)

        tap("tab.profile")
        tap("profile.login", timeout: 4)

        assertExists("auth.apple", timeout: 4)
        XCTAssertFalse(element("tab.market").exists)

        tap("auth.guest.continue")
        XCTAssertTrue(element("tab.profile").waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["로그인이 필요해요"].waitForExistence(timeout: 4))
    }

    func testRootTabShellReturnsToMarket() {
        launch(isAuthenticated: false)
        tap("tab.search")
        tap("tab.market")
        XCTAssertTrue(app.staticTexts["오늘의 빛,"].waitForExistence(timeout: 4))
    }

    func testMarketplaceSearchPushCanReturnWithBackButton() {
        launch(isAuthenticated: false)

        XCTAssertTrue(app.staticTexts["필터, 메이커, 분위기 검색"].waitForExistence(timeout: 8))
        app.staticTexts["필터, 메이커, 분위기 검색"].tap()

        assertExists("search.back", timeout: 4)
        tap("search.back")
        XCTAssertTrue(app.staticTexts["오늘의 빛,"].waitForExistence(timeout: 4))
    }

    func testProfileWalletEntrypoint() {
        launch(route: "profile", isAuthenticated: true)

        assertExists("profile.settings", timeout: 6)
        assertExists("profile.edit.open")
        assertExists("profile.shortcut.create")
        assertExists("profile.shortcut.wallet")
        assertExists("profile.shortcut.myFilters")
        assertExists("profile.shortcut.dashboard")

        tap("profile.shortcut.wallet")
        assertExists("wallet.balance", timeout: 4)
        assertExists("wallet.action.코인 충전")
        assertExists("wallet.action.거래 내역")
    }

    func testProfileCreateFilterEntrypoint() {
        launch(route: "profile", isAuthenticated: true)

        tap("profile.shortcut.create", timeout: 6)
        assertExists("editor.params", timeout: 4)
        assertExists("editor.lut")
        assertExists("editor.next")
    }

    func testMakerDashboardCreateEntrypoint() {
        launch(route: "makerDashboard", isAuthenticated: true)

        assertExists("dashboard.create", timeout: 6)
        tap("dashboard.create")
        assertExists("editor.params", timeout: 4)
    }

    func testProfileEditEntrypoint() {
        launch(route: "profile", isAuthenticated: true)
        assertExists("profile.edit.open", timeout: 6)
        tap("profile.edit.open", timeout: 6)
        assertExists("profile.edit.save", timeout: 4)
        assertExists("profile.edit.name")
        assertExists("profile.edit.handle")
    }

    func testSettingsDataRightsAndHelpEntrypoints() {
        launch(route: "settings", isAuthenticated: true)

        XCTAssertTrue(app.staticTexts["설정"].waitForExistence(timeout: 4))
        assertExists("settings.nav.프로필 편집")
        assertExists("settings.nav.지갑")
        assertExists("settings.nav.데이터 내보내기")
        assertExists("settings.nav.알림 설정")
        assertExists("settings.nav.도움말")
        assertExists("settings.row.로그아웃")
        assertExists("settings.nav.계정 삭제")
    }

    func testProfilePushedSettingsProfileInfoNavigates() {
        launch(route: "profile", isAuthenticated: true)

        tap("profile.settings", timeout: 6)
        assertExists("settings.nav.프로필 편집", timeout: 4)

        tap("settings.nav.프로필 편집")
        assertExists("profile.edit.save", timeout: 4)
        assertExists("profile.edit.name")
    }

    func testProfilePushedSettingsWalletNavigates() {
        launch(route: "profile", isAuthenticated: true)

        tap("profile.settings", timeout: 6)
        assertExists("settings.nav.지갑", timeout: 4)

        tap("settings.nav.지갑")
        assertExists("wallet.balance", timeout: 4)
    }

    func testProfilePushedSettingsHelpNavigates() {
        launch(route: "profile", isAuthenticated: true)

        tap("profile.settings", timeout: 6)
        assertExists("settings.nav.도움말", timeout: 4)

        tap("settings.nav.도움말")
        assertExists("help.faq.coin", timeout: 4)
    }

}
