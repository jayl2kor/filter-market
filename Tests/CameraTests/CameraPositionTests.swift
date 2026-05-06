import XCTest
@testable import Camera

final class CameraPositionTests: XCTestCase {
    func testToggledPositionAlternatesBetweenBackAndFront() {
        XCTAssertEqual(CameraPosition.back.toggled, .front)
        XCTAssertEqual(CameraPosition.front.toggled, .back)
    }
}
