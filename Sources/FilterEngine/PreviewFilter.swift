import Foundation
import Models

public struct PreviewFilter: Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let category: FilterCategory
    public let preset: LUTPreset

    public init(id: UUID, title: String, category: FilterCategory, preset: LUTPreset) {
        self.id = id
        self.title = title
        self.category = category
        self.preset = preset
    }
}

public enum LUTPreset: String, CaseIterable, Sendable {
    case identity
    case warm
    case cool
    case mono
    case vivid
    case soft

    public static func preset(for category: FilterCategory) -> LUTPreset {
        switch category {
        case .cinematic, .food:
            .warm
        case .travel, .bright:
            .vivid
        case .pastel, .portrait, .skin:
            .soft
        case .bw:
            .mono
        case .anime, .mood, .moody, .vintage:
            .cool
        }
    }

    public func transform(red: Float, green: Float, blue: Float) -> RGBColor {
        switch self {
        case .identity:
            return RGBColor(red: red, green: green, blue: blue)
        case .warm:
            return RGBColor(
                red: clamp(red * 1.08 + 0.025),
                green: clamp(green * 1.02 + 0.008),
                blue: clamp(blue * 0.92 - 0.012)
            )
        case .cool:
            return RGBColor(
                red: clamp(red * 0.92 - 0.01),
                green: clamp(green * 1.01),
                blue: clamp(blue * 1.10 + 0.025)
            )
        case .mono:
            let luminance = red * 0.299 + green * 0.587 + blue * 0.114
            return RGBColor(red: luminance, green: luminance, blue: luminance)
        case .vivid:
            let average = (red + green + blue) / 3
            return RGBColor(
                red: clamp(average + (red - average) * 1.24 + 0.012),
                green: clamp(average + (green - average) * 1.18 + 0.008),
                blue: clamp(average + (blue - average) * 1.18)
            )
        case .soft:
            return RGBColor(
                red: clamp(red * 0.96 + 0.035),
                green: clamp(green * 0.98 + 0.025),
                blue: clamp(blue * 1.02 + 0.018)
            )
        }
    }

    private func clamp(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }
}
