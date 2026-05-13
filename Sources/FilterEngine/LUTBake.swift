import Foundation
import os

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
            sourceFingerprint: sourceLUT.fingerprint,
            exposureQ: quantize(parameters.exposure),
            contrastQ: quantize(parameters.contrast),
            saturationQ: quantize(parameters.saturation),
            tintQ: quantize(parameters.tint)
        )
    }

    /// Bake parameters into the source LUT. Output is byte-equal for identical inputs.
    /// Memoized by (source LUT fingerprint, quantized parameters) — repeated calls with the
    /// same inputs return the cached result without re-iterating 33³ entries. Cap 32 entries (FIFO).
    public static func bake(sourceLUT: LUT3D, parameters: EditorParameters) -> LUT3D {
        let key = cacheKey(sourceLUT: sourceLUT, parameters: parameters)
        if let cached = cache.withLock({ state -> LUT3D? in
            if let hit = state.entries[key] {
                state.hits &+= 1
                return hit
            }
            state.misses &+= 1
            return nil
        }) {
            return cached
        }

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

        let result = LUT3D(size: size, values: values)

        cache.withLock { state in
            state.entries[key] = result
            state.order.append(key)
            if state.order.count > cacheCapacity {
                let evict = state.order.removeFirst()
                state.entries.removeValue(forKey: evict)
            }
        }

        return result
    }

    // MARK: - Cache

    private struct CacheState {
        var entries: [CacheKey: LUT3D] = [:]
        var order: [CacheKey] = []
        var hits: UInt64 = 0
        var misses: UInt64 = 0
    }

    private static let cacheCapacity = 32
    private static let cache = OSAllocatedUnfairLock<CacheState>(initialState: CacheState())

    /// Test-only stats. Resets and reads behind the same lock so tests stay deterministic.
    public struct CacheStats: Sendable {
        public let hits: UInt64
        public let misses: UInt64
        public let entries: Int
    }

    public static func _cacheStatsForTesting() -> CacheStats {
        cache.withLock { state in
            CacheStats(hits: state.hits, misses: state.misses, entries: state.entries.count)
        }
    }

    public static func _resetCacheForTesting() {
        cache.withLock { state in
            state.entries.removeAll()
            state.order.removeAll()
            state.hits = 0
            state.misses = 0
        }
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
}
