import Foundation
import Models

public struct RGBColor: Equatable, Sendable {
    public let red: Float
    public let green: Float
    public let blue: Float

    public init(red: Float, green: Float, blue: Float) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

public struct LUT3D: Sendable {
    public let size: Int
    private let values: [RGBColor]

    public init(size: Int, values: [RGBColor]) {
        precondition(size > 1, "LUT size must be greater than 1")
        precondition(values.count == size * size * size, "LUT value count must match size^3")
        self.size = size
        self.values = values
    }

    public static func identity(size: Int = 33) -> LUT3D {
        var values: [RGBColor] = []
        values.reserveCapacity(size * size * size)

        for b in 0..<size {
            for g in 0..<size {
                for r in 0..<size {
                    values.append(
                        RGBColor(
                            red: Float(r) / Float(size - 1),
                            green: Float(g) / Float(size - 1),
                            blue: Float(b) / Float(size - 1)
                        )
                    )
                }
            }
        }

        return LUT3D(size: size, values: values)
    }

    public func colorAt(red: Int, green: Int, blue: Int) -> RGBColor {
        let index = blue * size * size + green * size + red
        return values[index]
    }
}

public enum LUTSampler {
    public static func sample(_ lut: LUT3D, color: RGBColor, intensity: FilterIntensity = .full) -> RGBColor {
        let scale = Float(lut.size - 1)
        let r = clamp(color.red) * scale
        let g = clamp(color.green) * scale
        let b = clamp(color.blue) * scale

        let r0 = Int(floor(r))
        let g0 = Int(floor(g))
        let b0 = Int(floor(b))
        let r1 = min(r0 + 1, lut.size - 1)
        let g1 = min(g0 + 1, lut.size - 1)
        let b1 = min(b0 + 1, lut.size - 1)

        let fr = r - Float(r0)
        let fg = g - Float(g0)
        let fb = b - Float(b0)

        let c000 = lut.colorAt(red: r0, green: g0, blue: b0)
        let c100 = lut.colorAt(red: r1, green: g0, blue: b0)
        let c010 = lut.colorAt(red: r0, green: g1, blue: b0)
        let c110 = lut.colorAt(red: r1, green: g1, blue: b0)
        let c001 = lut.colorAt(red: r0, green: g0, blue: b1)
        let c101 = lut.colorAt(red: r1, green: g0, blue: b1)
        let c011 = lut.colorAt(red: r0, green: g1, blue: b1)
        let c111 = lut.colorAt(red: r1, green: g1, blue: b1)

        let sampled = interpolate(
            c000,
            c100,
            c010,
            c110,
            c001,
            c101,
            c011,
            c111,
            fr: fr,
            fg: fg,
            fb: fb
        )

        return mix(color, sampled, t: intensity.value)
    }

    private static func interpolate(
        _ c000: RGBColor,
        _ c100: RGBColor,
        _ c010: RGBColor,
        _ c110: RGBColor,
        _ c001: RGBColor,
        _ c101: RGBColor,
        _ c011: RGBColor,
        _ c111: RGBColor,
        fr: Float,
        fg: Float,
        fb: Float
    ) -> RGBColor {
        let c00 = mix(c000, c100, t: fr)
        let c10 = mix(c010, c110, t: fr)
        let c01 = mix(c001, c101, t: fr)
        let c11 = mix(c011, c111, t: fr)
        let c0 = mix(c00, c10, t: fg)
        let c1 = mix(c01, c11, t: fg)
        return mix(c0, c1, t: fb)
    }

    private static func mix(_ lhs: RGBColor, _ rhs: RGBColor, t: Float) -> RGBColor {
        RGBColor(
            red: lhs.red + (rhs.red - lhs.red) * t,
            green: lhs.green + (rhs.green - lhs.green) * t,
            blue: lhs.blue + (rhs.blue - lhs.blue) * t
        )
    }

    private static func clamp(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }
}

public struct FilterIntensity: Equatable, Sendable {
    public static let zero = FilterIntensity(0)
    public static let full = FilterIntensity(1)

    public let value: Float

    public init(_ value: Float) {
        self.value = min(max(value, 0), 1)
    }
}
