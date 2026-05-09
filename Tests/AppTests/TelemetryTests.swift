import XCTest
@testable import moodit

final class TelemetryTests: XCTestCase {
    func testSanitizedParametersNormalizeKeysAndSupportedValues() {
        let parameters = Telemetry.sanitizedParameters([
            "Screen Name": "marketplace_home",
            "is paid": true,
            "position": 3,
            "ratio": 0.75,
            "url": URL(string: "https://moodit.app/f/sample") as Any
        ])

        XCTAssertEqual(parameters["screen_name"] as? String, "marketplace_home")
        XCTAssertEqual(parameters["is_paid"] as? Int, 1)
        XCTAssertEqual(parameters["position"] as? Int, 3)
        XCTAssertEqual(parameters["ratio"] as? Double, 0.75)
        XCTAssertEqual(parameters["url"] as? String, "moodit.app")
    }

    func testSanitizedParametersDropUnsupportedAndNonFiniteValues() {
        let parameters = Telemetry.sanitizedParameters([
            "bad value": ["nested"],
            "bad double": Double.infinity,
            "good": "ok"
        ])

        XCTAssertNil(parameters["bad_value"])
        XCTAssertNil(parameters["bad_double"])
        XCTAssertEqual(parameters["good"] as? String, "ok")
    }

    func testSanitizedParametersLimitStringAndKeyLengths() {
        let longKey = String(repeating: "a", count: 80)
        let longValue = String(repeating: "b", count: 180)

        let parameters = Telemetry.sanitizedParameters([longKey: longValue])
        let key = String(repeating: "a", count: 40)

        XCTAssertEqual((parameters[key] as? String)?.count, 100)
    }
}
