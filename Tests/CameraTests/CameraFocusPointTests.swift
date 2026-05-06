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

    func testFocusPointNormalizesAgainstActiveFrame() {
        let point = CameraFocusPoint(
            viewLocation: CGPoint(x: 150, y: 250),
            activeFrame: CGRect(x: 100, y: 50, width: 200, height: 400)
        )

        XCTAssertEqual(point.x, 0.25)
        XCTAssertEqual(point.y, 0.5)
    }

    func testFocusPointClampsAgainstActiveFrame() {
        let point = CameraFocusPoint(
            viewLocation: CGPoint(x: 20, y: 500),
            activeFrame: CGRect(x: 100, y: 50, width: 200, height: 400),
            isMirrored: true
        )

        XCTAssertEqual(point.x, 1)
        XCTAssertEqual(point.y, 1)
    }
}
