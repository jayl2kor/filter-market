import Foundation

/// Editor parameters that get baked into a LUT.
///
/// Values are clamped at construction; `neutral` produces a no-op bake (output equals input).
public struct EditorParameters: Hashable, Sendable {
    /// Exposure stops, clamped to ±2.
    public let exposure: Float
    /// Contrast offset, clamped to ±1 (0 = no change).
    public let contrast: Float
    /// Saturation offset, clamped to ±1 (0 = no change, -1 = grayscale).
    public let saturation: Float
    /// Tint shift, clamped to ±1 (positive = warm/red, negative = cool/blue).
    public let tint: Float

    public static let neutral = EditorParameters()

    public init(
        exposure: Float = 0,
        contrast: Float = 0,
        saturation: Float = 0,
        tint: Float = 0
    ) {
        self.exposure = Self.clamp(exposure, range: -2 ... 2)
        self.contrast = Self.clamp(contrast, range: -1 ... 1)
        self.saturation = Self.clamp(saturation, range: -1 ... 1)
        self.tint = Self.clamp(tint, range: -1 ... 1)
    }

    public var isNeutral: Bool {
        exposure == 0 && contrast == 0 && saturation == 0 && tint == 0
    }

    private static func clamp(_ value: Float, range: ClosedRange<Float>) -> Float {
        min(max(value, range.lowerBound), range.upperBound)
    }
}

/// Deterministic LUT baking — combines a source LUT with editor parameters into a new LUT.
public enum LUTBake {
    /// Stable cache key for `(sourceLUT, parameters)` pair.
    ///
    /// Source LUT is fingerprinted using FNV-1a over (size + bit-patterns of all RGB values),
    /// so the digest is stable across processes and platforms — not affected by Swift's
    /// per-process Hasher seed.
    public struct CacheKey: Hashable, Sendable {
        public let sourceFingerprint: UInt64
        public let exposureQ: Int32
        public let contrastQ: Int32
        public let saturationQ: Int32
        public let tintQ: Int32
    }

    public static func cacheKey(sourceLUT: LUT3D, parameters: EditorParameters) -> CacheKey {
        CacheKey(
            sourceFingerprint: fingerprint(of: sourceLUT),
            exposureQ: quantize(parameters.exposure),
            contrastQ: quantize(parameters.contrast),
            saturationQ: quantize(parameters.saturation),
            tintQ: quantize(parameters.tint)
        )
    }

    /// Bake parameters into the source LUT. Output is byte-equal for identical inputs.
    public static func bake(sourceLUT: LUT3D, parameters: EditorParameters) -> LUT3D {
        let size = sourceLUT.size
        var values: [RGBColor] = []
        values.reserveCapacity(size * size * size)

        for b in 0 ..< size {
            for g in 0 ..< size {
                for r in 0 ..< size {
                    let original = sourceLUT.colorAt(red: r, green: g, blue: b)
                    values.append(apply(parameters, to: original))
                }
            }
        }

        return LUT3D(size: size, values: values)
    }

    // MARK: - Internals

    private static func apply(_ p: EditorParameters, to color: RGBColor) -> RGBColor {
        let exposureScale = Foundation.pow(2 as Float, p.exposure)
        var red = color.red * exposureScale
        var green = color.green * exposureScale
        var blue = color.blue * exposureScale

        // Contrast: pivot around mid-grey, factor (1 + contrast) ∈ [0, 2].
        let contrastFactor: Float = 1 + p.contrast
        let mid: Float = 0.5
        red = mid + (red - mid) * contrastFactor
        green = mid + (green - mid) * contrastFactor
        blue = mid + (blue - mid) * contrastFactor

        // Saturation: ITU BT.601 luma, factor (1 + saturation) ∈ [0, 2].
        let lumaR: Float = 0.299
        let lumaG: Float = 0.587
        let lumaB: Float = 0.114
        let luma: Float = lumaR * red + lumaG * green + lumaB * blue
        let satFactor: Float = 1 + p.saturation
        red = luma + (red - luma) * satFactor
        green = luma + (green - luma) * satFactor
        blue = luma + (blue - luma) * satFactor

        // Tint: warm shifts +R/-B, cool shifts -R/+B. 0.1 keeps the effect subtle.
        let tintScale: Float = 0.1
        red += p.tint * tintScale
        blue -= p.tint * tintScale

        return RGBColor(
            red: clamp01(red),
            green: clamp01(green),
            blue: clamp01(blue)
        )
    }

    private static func clamp01(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }

    private static func quantize(_ value: Float) -> Int32 {
        Int32((value * 1_000).rounded())
    }

    private static func fingerprint(of lut: LUT3D) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325 // FNV-1a offset basis
        let prime: UInt64 = 0x100_0000_01b3
        let size = lut.size
        mix(&hash, prime, withInt: size)

        for b in 0 ..< size {
            for g in 0 ..< size {
                for r in 0 ..< size {
                    let color = lut.colorAt(red: r, green: g, blue: b)
                    mix(&hash, prime, withFloat: color.red)
                    mix(&hash, prime, withFloat: color.green)
                    mix(&hash, prime, withFloat: color.blue)
                }
            }
        }
        return hash
    }

    private static func mix(_ hash: inout UInt64, _ prime: UInt64, withInt value: Int) {
        var bits = UInt64(bitPattern: Int64(value))
        for _ in 0 ..< 8 {
            hash ^= UInt64(bits & 0xff)
            hash &*= prime
            bits >>= 8
        }
    }

    private static func mix(_ hash: inout UInt64, _ prime: UInt64, withFloat value: Float) {
        var bits = UInt64(value.bitPattern)
        for _ in 0 ..< 4 {
            hash ^= UInt64(bits & 0xff)
            hash &*= prime
            bits >>= 8
        }
    }
}
