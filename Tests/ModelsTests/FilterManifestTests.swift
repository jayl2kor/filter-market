import XCTest
@testable import Models

final class FilterManifestTests: XCTestCase {
    func testDecodeMinimalManifest() throws {
        let json = """
        {
          "schemaVersion": 1,
          "id": "01900b14-7b1c-7c1e-a4f4-9b2c1d2e3f4a",
          "version": "1.0.0",
          "title": "Sunset Vibes",
          "author": { "uid": "fb_uid_alex_1234", "displayName": "Alex" },
          "category": "cinematic",
          "license": "CC-BY-4.0",
          "engine": {
            "type": "lut+params",
            "minAppVersion": "1.0.0",
            "minIOSVersion": "17.0",
            "lutSize": 33,
            "lutFile": "luts/lut.png"
          },
          "parameters": [
            { "key": "intensity", "label": "Intensity", "type": "float", "min": 0, "max": 1, "default": 1.0 }
          ],
          "createdAt": "2026-05-06T09:00:00Z",
          "checksum": "sha256:0000000000000000000000000000000000000000000000000000000000000000"
        }
        """

        let manifest = try MooditJSON.decoder.decode(FilterManifest.self, from: Data(json.utf8))

        XCTAssertEqual(manifest.schemaVersion, 1)
        XCTAssertEqual(manifest.title, "Sunset Vibes")
        XCTAssertEqual(manifest.engine.type, .lutParams)
        XCTAssertEqual(manifest.parameters?.first?.defaultValue, 1.0)
    }
}
