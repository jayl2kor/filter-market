import XCTest

@MainActor
final class P0CoreActionTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        app = nil
    }

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
        XCTAssertTrue(app.staticTexts["최근 검색"].waitForExistence(timeout: 4))

        tap("tab.saved")
        XCTAssertTrue(app.staticTexts["저장됨"].waitForExistence(timeout: 4))

        tap("tab.profile")
        XCTAssertTrue(app.staticTexts["로그인이 필요해요"].waitForExistence(timeout: 4))
        assertExists("profile.login")
    }

    func testRootTabShellReturnsToMarket() {
        launch(isAuthenticated: false)
        tap("tab.search")
        tap("tab.market")
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

    private func launch(route: String? = nil, isAuthenticated: Bool = false) {
        app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing",
            "-hasOnboarded", "YES",
            "-isAuthenticated", isAuthenticated ? "YES" : "NO"
        ]
        if let route {
            app.launchArguments += ["-ui-route", route]
        }
        app.launch()
    }

    private func tap(_ identifier: String, timeout: TimeInterval = 2) {
        let target = element(identifier)
        if target.waitForExistence(timeout: timeout) {
            target.tap()
            return
        }

        let attempts = max(1, Int(timeout.rounded(.up)))
        for _ in 0..<attempts {
            app.swipeUp()
            if target.waitForExistence(timeout: 1) {
                target.tap()
                return
            }
        }

        XCTFail("Missing element: \(identifier)")
    }

    private func assertExists(
        _ identifier: String,
        timeout: TimeInterval = 2,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let target = element(identifier)
        if target.waitForExistence(timeout: timeout) {
            return
        }

        let attempts = max(1, Int(timeout.rounded(.up)))
        for _ in 0..<attempts {
            app.swipeUp()
            if target.waitForExistence(timeout: 1) {
                return
            }
        }

        XCTAssertTrue(
            target.exists,
            "Missing element: \(identifier)",
            file: file,
            line: line
        )
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }
}
