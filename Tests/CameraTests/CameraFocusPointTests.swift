import CoreGraphics
import XCTest
@testable import Camera

final class CameraFocusPointTests: XCTestCase {
    func testFocusPointClampsNormalizedCoordinates() {
        let point = CameraFocusPoint(x: -0.25, y: 1.4)

        XCTAssertEqual(point.x, 0)
        XCTAssertEqual(point.y, 1)
    }

    func testFocusPointNormalizesViewLocation() {
        let point = CameraFocusPoint(
            viewLocation: CGPoint(x: 120, y: 320),
            viewSize: CGSize(width: 240, height: 640)
        )

        XCTAssertEqual(point.x, 0.5)
        XCTAssertEqual(point.y, 0.5)
    }

    func testFocusPointMirrorsHorizontalCoordinateForFrontCamera() {
        let point = CameraFocusPoint(
            viewLocation: CGPoint(x: 60, y: 320),
            viewSize: CGSize(width: 240, height: 640),
            isMirrored: true
        )

        XCTAssertEqual(point.x, 0.75)
        XCTAssertEqual(point.y, 0.5)
    }
}
