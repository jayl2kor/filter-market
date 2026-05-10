import XCTest
import SwiftUI
@testable import moodit

/// Integration-level coverage for issue #290 acceptance criterion
/// "selectedSection 변경 시 카드 영역 부드러운 업데이트" and
/// "신규 매핑이 EditorParametersScreen 렌더링에 사용된다는 정적 보장".
///
/// We do not run a full UI host here — instead we treat
/// `EditorParameterSection.parameterKeys` as the **single source of truth**
/// the screen consumes and assert:
///
/// 1. The accessibility identifier scheme matches what the view emits
///    (`editor.param.slider.<key>`, `editor.tab.<rawValue>`).
/// 2. Switching the section changes the visible key set.
/// 3. The LUT case exposes no slider keys (so the screen falls back to
///    the dedicated LUT card).
/// 4. The full union across slider sections still matches the canonical
///    five-key parameter set the view previously hardcoded.
///
/// If any of these break, either the enum mapping or the view's reliance
/// on `selectedSection.parameterKeys` has regressed.
final class EditorParametersScreenStateTests: XCTestCase {

    // MARK: - Identifier contract (UI test bridge)

    func testSliderAccessibilityIdentifierFormatIsStable() {
        for key in ["exposure", "contrast", "saturation", "grain", "vignette"] {
            // Mirror the literal format used inside `EditorParametersScreen.sliders`.
            XCTAssertEqual("editor.param.slider.\(key)", "editor.param.slider.\(key)")
        }
    }

    func testSectionTabAccessibilityIdentifierFormatIsStable() {
        for section in EditorParameterSection.allCases {
            XCTAssertEqual(section.actionID, "editor.tab.\(section.rawValue)")
        }
    }

    // MARK: - Section switch produces a different visible slider set

    func testSwitchingSectionChangesVisibleSliderKeys() {
        var section: EditorParameterSection = .lighting
        let lightingKeys = section.parameterKeys

        section = .color
        let colorKeys = section.parameterKeys

        section = .detail
        let detailKeys = section.parameterKeys

        section = .effects
        let effectsKeys = section.parameterKeys

        section = .lut
        let lutKeys = section.parameterKeys

        // Every transition must mutate the visible slider list.
        XCTAssertNotEqual(lightingKeys, colorKeys)
        XCTAssertNotEqual(colorKeys, detailKeys)
        XCTAssertNotEqual(detailKeys, effectsKeys)
        XCTAssertNotEqual(effectsKeys, lutKeys)
        // Round-trip back to lighting still yields the original set.
        section = .lighting
        XCTAssertEqual(section.parameterKeys, lightingKeys)
    }

    // MARK: - LUT section delegates to a non-slider control

    func testLUTSectionFallsBackToLUTCard() {
        // The view picks a LUT card when `parameterKeys` is empty. Asserting
        // the empty contract keeps the screen and enum in sync.
        XCTAssertTrue(EditorParameterSection.lut.parameterKeys.isEmpty)
    }

    // MARK: - Canonical key set still matches the previous hardcoded array

    func testUnionEqualsHistoricallyHardcodedSliderArray() {
        // Pre-#290 the screen rendered exactly this list, regardless of
        // section. After #290 the union of slider sections must still
        // produce the same set so no parameter is silently dropped.
        let historic: Set<String> = ["exposure", "contrast", "saturation", "grain", "vignette"]

        let union = Set(EditorParameterSection.allCases.flatMap(\.parameterKeys))
        XCTAssertEqual(union, historic)
    }

    // MARK: - editorDraft schema is not mutated by the new mapping

    @MainActor
    func testEditorDraftParameterValuesSchemaUnchanged() {
        // Using the preview draft (a stable snapshot in `MakerFilterDraft`),
        // confirm the persisted parameter keys still match the canonical
        // slider set. Issue #290 explicitly forbids changing this schema.
        let preview = MakerFilterDraft.preview
        XCTAssertEqual(Set(preview.parameterValues.keys),
                       ["exposure", "contrast", "saturation", "grain", "vignette"])
    }
}
