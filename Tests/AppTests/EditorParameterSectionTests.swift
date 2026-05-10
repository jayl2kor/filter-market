import XCTest
@testable import moodit

/// Regression coverage for `EditorParameterSection` — the enum that powers the
/// editor section tabs and now also drives the slider list shown for each
/// section (see issue #290). These assertions guarantee that the section →
/// parameter-key mapping matches the canonical 5-slider set with no missing,
/// duplicate, or stale keys, and that pre-existing identifiers used by the
/// view (`title`, `actionID`, `id`) do not regress.
final class EditorParameterSectionTests: XCTestCase {

    /// The canonical slider key set the editor exposes. Must match the keys
    /// that `EditorParametersScreen` previously hardcoded as `parameters`.
    private let canonicalSliderKeys: Set<String> = [
        "exposure", "contrast", "saturation", "grain", "vignette"
    ]

    // MARK: - parameterKeys mapping

    func testEverySectionExposesParameterKeys() {
        // Every case must answer the new API — even `.lut`, which returns [].
        for section in EditorParameterSection.allCases {
            // `.lut` is intentionally empty; the others must be non-empty.
            if section == .lut {
                XCTAssertTrue(section.parameterKeys.isEmpty,
                              "\(section) should not expose slider keys")
            } else {
                XCTAssertFalse(section.parameterKeys.isEmpty,
                               "\(section) must expose at least one slider key")
            }
        }
    }

    func testSliderSectionsUnionMatchesCanonicalKeys() {
        let sliderSections: [EditorParameterSection] = [.lighting, .color, .detail, .effects]
        let union = sliderSections.flatMap(\.parameterKeys)

        // Exact set equality — no stray or missing keys.
        XCTAssertEqual(Set(union), canonicalSliderKeys)
        // No duplicates across sections.
        XCTAssertEqual(union.count, canonicalSliderKeys.count,
                       "Duplicate slider keys across sections: \(union)")
    }

    func testLUTSectionExposesNoSliderKeys() {
        XCTAssertTrue(EditorParameterSection.lut.parameterKeys.isEmpty)
    }

    func testNoDuplicateKeysWithinASingleSection() {
        for section in EditorParameterSection.allCases {
            let keys = section.parameterKeys
            XCTAssertEqual(Set(keys).count, keys.count,
                           "\(section) has duplicate keys: \(keys)")
        }
    }

    func testKnownPerSectionMapping() {
        // Pinning the mapping locks the editor's section→slider contract.
        XCTAssertEqual(EditorParameterSection.lighting.parameterKeys, ["exposure", "contrast"])
        XCTAssertEqual(EditorParameterSection.color.parameterKeys, ["saturation"])
        XCTAssertEqual(EditorParameterSection.detail.parameterKeys, ["grain"])
        XCTAssertEqual(EditorParameterSection.effects.parameterKeys, ["vignette"])
        XCTAssertEqual(EditorParameterSection.lut.parameterKeys, [])
    }

    // MARK: - Identity / title regression (no changes to existing API)

    func testRawValuesUnchanged() {
        XCTAssertEqual(EditorParameterSection.lighting.rawValue, "lighting")
        XCTAssertEqual(EditorParameterSection.color.rawValue, "color")
        XCTAssertEqual(EditorParameterSection.detail.rawValue, "detail")
        XCTAssertEqual(EditorParameterSection.effects.rawValue, "effects")
        XCTAssertEqual(EditorParameterSection.lut.rawValue, "lut")
    }

    func testIDMatchesRawValue() {
        for section in EditorParameterSection.allCases {
            XCTAssertEqual(section.id, section.rawValue)
        }
    }

    func testTitlesUnchanged() {
        XCTAssertEqual(EditorParameterSection.lighting.title, "조명")
        XCTAssertEqual(EditorParameterSection.color.title, "색")
        XCTAssertEqual(EditorParameterSection.detail.title, "디테일")
        XCTAssertEqual(EditorParameterSection.effects.title, "효과")
        XCTAssertEqual(EditorParameterSection.lut.title, "LUT")
    }

    func testActionIDFormatUnchanged() {
        // Used for UI test accessibility: `editor.tab.<rawValue>`.
        for section in EditorParameterSection.allCases {
            XCTAssertEqual(section.actionID, "editor.tab.\(section.rawValue)")
        }
    }

    func testAllCasesCount() {
        // Guards against accidental case removal.
        XCTAssertEqual(EditorParameterSection.allCases.count, 5)
    }
}
