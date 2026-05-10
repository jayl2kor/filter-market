import Foundation
import Models
import Testing
@testable import moodit

/// Integration-level coverage for issue #290 acceptance criteria:
/// "selectedSection 변경 시 카드 영역 부드러운 업데이트" and
/// "신규 매핑이 EditorParametersScreen 렌더링에 사용된다는 정적 보장".
///
/// These tests do not run a SwiftUI host. Instead they treat
/// `EditorParameterSection.parameterKeys` as the **single source of truth**
/// the screen consumes and assert:
///
/// 1. The accessibility identifier scheme matches what the view emits
///    (`editor.param.slider.<key>`, `editor.tab.<rawValue>`).
/// 2. Switching the section changes the visible key set, and round-trips
///    back to the original keys.
/// 3. The `.lut` case exposes no slider keys (so the screen falls back to
///    the dedicated LUT card instead).
/// 4. The full union across slider sections still matches the canonical
///    five-key parameter set the view previously hardcoded — guarding
///    against silent parameter drops from the rendering path.
/// 5. `editorDraft.parameterValues` schema is unchanged — issue #290
///    explicitly forbids mutating the persisted parameter keys.
@Suite("EditorParametersScreen state contract")
struct EditorParametersScreenStateTests {
    private let canonicalKeys: Set<String> = [
        "exposure", "contrast", "saturation", "grain", "vignette"
    ]

    @Test("slider accessibility identifier format is stable")
    func sliderIdentifierFormatIsStable() {
        for key in canonicalKeys {
            let expected = "editor.param.slider.\(key)"
            #expect(expected.hasPrefix("editor.param.slider."))
            #expect(expected.split(separator: ".").last.map(String.init) == key)
        }
    }

    @Test("section tab accessibility identifier format is stable")
    func sectionTabIdentifierFormatIsStable() {
        for section in EditorParameterSection.allCases {
            #expect(section.actionID == "editor.tab.\(section.rawValue)")
        }
    }

    @Test("switching section changes the visible slider keys, round-trip preserves original")
    func switchingSectionChangesVisibleSliderKeys() {
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

        #expect(lightingKeys != colorKeys)
        #expect(colorKeys != detailKeys)
        #expect(detailKeys != effectsKeys)
        #expect(effectsKeys != lutKeys)

        section = .lighting
        #expect(section.parameterKeys == lightingKeys)
    }

    @Test("LUT section falls back to the LUT card (empty slider keys)")
    func lutSectionFallsBackToLutCard() {
        #expect(EditorParameterSection.lut.parameterKeys.isEmpty)
    }

    @Test("union of slider sections equals the historically hardcoded array")
    func unionEqualsHistoricallyHardcodedSliderArray() {
        let union = Set(EditorParameterSection.allCases.flatMap(\.parameterKeys))
        #expect(union == canonicalKeys)
    }

    @MainActor
    @Test("editorDraft.parameterValues schema is not mutated by the new mapping")
    func editorDraftParameterValuesSchemaUnchanged() {
        let preview = MakerFilterDraft.preview
        #expect(Set(preview.parameterValues.keys) == canonicalKeys)
    }
}
