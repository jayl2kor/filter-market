import Foundation
import Models
import Testing
@testable import moodit

@Suite("EditorParameterSection mapping")
struct EditorParameterSectionTests {
    @Test("every case exposes a parameterKeys array")
    func everyCaseExposesParameterKeys() {
        for section in EditorParameterSection.allCases {
            _ = section.parameterKeys
        }
    }

    @Test("non-lut sections cover the canonical 5 slider parameters exactly")
    func nonLutSectionsCoverCanonicalSliderParameters() {
        let canonical: Set<String> = ["exposure", "contrast", "saturation", "grain", "vignette"]
        let union = Set(
            EditorParameterSection.allCases
                .filter { $0 != .lut }
                .flatMap(\.parameterKeys)
        )
        #expect(union == canonical)
    }

    @Test("no parameter key appears in more than one section")
    func parameterKeysAreUniqueAcrossSections() {
        let allKeys = EditorParameterSection.allCases.flatMap(\.parameterKeys)
        let unique = Set(allKeys)
        #expect(allKeys.count == unique.count, "Parameter keys must not be duplicated across sections")
    }

    @Test(".lut section exposes no slider keys")
    func lutSectionExposesNoSliderKeys() {
        #expect(EditorParameterSection.lut.parameterKeys.isEmpty)
    }

    @Test("section title regression")
    func sectionTitleRegression() {
        #expect(EditorParameterSection.lighting.title == "조명")
        #expect(EditorParameterSection.color.title == "색")
        #expect(EditorParameterSection.detail.title == "디테일")
        #expect(EditorParameterSection.effects.title == "효과")
        #expect(EditorParameterSection.lut.title == "LUT")
    }

    @Test("section actionID regression")
    func sectionActionIDRegression() {
        for section in EditorParameterSection.allCases {
            #expect(section.actionID == "editor.tab.\(section.rawValue)")
        }
    }

    @Test("section id matches rawValue")
    func sectionIdMatchesRawValue() {
        for section in EditorParameterSection.allCases {
            #expect(section.id == section.rawValue)
        }
    }

    /// Integration-level: simulates section selection by walking each section
    /// and confirming the keys that would drive `EditorParametersScreen.sliders`
    /// change between sections (proving the bug — same sliders for every tab —
    /// is fixed at the data source that the SwiftUI view renders from).
    @Test("simulating section selection produces section-specific slider key sets")
    func sectionSelectionProducesSectionSpecificKeys() {
        let keysBySection: [EditorParameterSection: [String]] = Dictionary(
            uniqueKeysWithValues: EditorParameterSection.allCases.map { ($0, $0.parameterKeys) }
        )

        #expect(keysBySection[.lighting] == ["exposure", "contrast"])
        #expect(keysBySection[.color] == ["saturation"])
        #expect(keysBySection[.detail] == ["grain"])
        #expect(keysBySection[.effects] == ["vignette"])
        #expect(keysBySection[.lut] == [])

        let nonLutPairs: [(EditorParameterSection, EditorParameterSection)] = [
            (.lighting, .color),
            (.lighting, .detail),
            (.lighting, .effects),
            (.color, .detail),
            (.color, .effects),
            (.detail, .effects)
        ]
        for (a, b) in nonLutPairs {
            #expect(
                keysBySection[a] != keysBySection[b],
                "\(a) and \(b) should not produce the same slider keys"
            )
        }
    }
}
