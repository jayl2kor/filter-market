import XCTest
@testable import moodit

@MainActor
final class AuthValidationTests: XCTestCase {
    func testHandleValidatorNormalizesInput() {
        XCTAssertEqual(HandleValidator.normalized("  @Moodit_User.01  "), "moodit_user.01")
    }

    func testHandleValidatorRejectsInvalidSyntax() {
        XCTAssertFalse(HandleValidator.isValid("ab"))
        XCTAssertFalse(HandleValidator.isValid("has.space"))
        XCTAssertFalse(HandleValidator.isValid("has space"))
        XCTAssertFalse(HandleValidator.isValid("한글"))
    }

    func testHandleValidatorAcceptsSupportedCharacters() {
        XCTAssertTrue(HandleValidator.isValid("film_user_01"))
    }

    func testHandleAvailabilityRejectsReservedHandles() async {
        let status = await HandleAvailabilityChecker.status(for: "admin")
        XCTAssertEqual(status, .unavailable)
    }

    func testAppleSignInNonceHashUsesSHA256Hex() {
        XCTAssertEqual(
            AppleSignInCoordinator.sha256("abc"),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        )
    }

    func testAppleSignInNonceLength() {
        XCTAssertEqual(AppleSignInCoordinator.randomNonceString(length: 16).count, 16)
    }
}
