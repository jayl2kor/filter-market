import SwiftUI

public extension Int {
    func fmDecimal(locale: Locale = .current) -> String {
        formatted(.number.locale(locale))
    }

    func fmCompactCount(locale: Locale = .current) -> String {
        let language = locale.language.languageCode?.identifier ?? ""
        if language == "ko" {
            switch self {
            case 10_000...:
                return Self.fmCompactDecimal(Double(self) / 10_000, suffix: "만")
            case 1_000...:
                return Self.fmCompactDecimal(Double(self) / 1_000, suffix: "천")
            default:
                return fmDecimal(locale: locale)
            }
        }

        switch self {
        case 1_000_000...:
            return Self.fmCompactDecimal(Double(self) / 1_000_000, suffix: "M")
        case 1_000...:
            return Self.fmCompactDecimal(Double(self) / 1_000, suffix: "K")
        default:
            return fmDecimal(locale: locale)
        }
    }

    private static func fmCompactDecimal(_ value: Double, suffix: String) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded.rounded() == rounded {
            return "\(Int(rounded))\(suffix)"
        }
        return String(format: "%.1f%@", rounded, suffix)
    }
}

public extension View {
    func fmCounter() -> some View {
        self
            .monospacedDigit()
            .contentTransition(.numericText())
    }
}
