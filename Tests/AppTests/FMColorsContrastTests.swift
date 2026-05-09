import DesignSystem
import SwiftUI
import UIKit
import XCTest

final class FMColorsContrastTests: XCTestCase {
    func testTextTokensMeetContrastInLightAndDark() {
        let backgrounds: [(String, Color)] = [
            ("bg0", FMColors.Background.bg0),
            ("bg1", FMColors.Background.bg1),
            ("bg2", FMColors.Background.bg2),
            ("bg3", FMColors.Background.bg3),
        ]
        let foregrounds: [(String, Color, Double)] = [
            ("primary", FMColors.Text.primary, 4.5),
            ("secondary", FMColors.Text.secondary, 3.0),
            ("tertiary", FMColors.Text.tertiary, 3.0),
        ]

        assertContrast(foregrounds: foregrounds, backgrounds: backgrounds)
    }

    func testAccentAndSemanticTokensMeetContrastInLightAndDark() {
        let backgrounds: [(String, Color)] = [
            ("bg0", FMColors.Background.bg0),
            ("bg2", FMColors.Background.bg2),
        ]
        let foregrounds: [(String, Color, Double)] = [
            ("accent.primary", FMColors.Accent.primary, 3.0),
            ("semantic.success", FMColors.Semantic.success, 4.5),
            ("semantic.warning", FMColors.Semantic.warning, 4.5),
            ("semantic.error", FMColors.Semantic.error, 4.5),
            ("semantic.info", FMColors.Semantic.info, 4.5),
        ]

        assertContrast(foregrounds: foregrounds, backgrounds: backgrounds)
    }

    private func assertContrast(
        foregrounds: [(String, Color, Double)],
        backgrounds: [(String, Color)],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for scheme in [UIUserInterfaceStyle.light, .dark] {
            for (foregroundName, foreground, threshold) in foregrounds {
                for (backgroundName, background) in backgrounds {
                    let ratio = contrastRatio(
                        foreground: resolvedComponents(foreground, scheme: scheme),
                        background: resolvedComponents(background, scheme: scheme)
                    )
                    XCTAssertGreaterThanOrEqual(
                        ratio,
                        threshold,
                        "\(scheme.testName) \(foregroundName) on \(backgroundName) contrast \(ratio) is below \(threshold)",
                        file: file,
                        line: line
                    )
                }
            }
        }
    }

    private func resolvedComponents(_ color: Color, scheme: UIUserInterfaceStyle) -> RGB {
        let trait = UITraitCollection(userInterfaceStyle: scheme)
        let resolved = UIColor(color).resolvedColor(with: trait)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        XCTAssertTrue(resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
        return RGB(red: Double(red), green: Double(green), blue: Double(blue))
    }

    private func contrastRatio(foreground: RGB, background: RGB) -> Double {
        let lighter = max(foreground.relativeLuminance, background.relativeLuminance)
        let darker = min(foreground.relativeLuminance, background.relativeLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }
}

private struct RGB {
    let red: Double
    let green: Double
    let blue: Double

    var relativeLuminance: Double {
        0.2126 * red.linearized + 0.7152 * green.linearized + 0.0722 * blue.linearized
    }
}

private extension Double {
    var linearized: Double {
        self <= 0.04045 ? self / 12.92 : pow((self + 0.055) / 1.055, 2.4)
    }
}

private extension UIUserInterfaceStyle {
    var testName: String {
        switch self {
        case .light: "light"
        case .dark: "dark"
        default: "unspecified"
        }
    }
}
