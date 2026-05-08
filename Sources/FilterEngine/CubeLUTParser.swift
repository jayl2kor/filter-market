import Foundation

/// Parser for Adobe `.cube` LUT files.
///
/// Supports both `LUT_1D_SIZE` and `LUT_3D_SIZE` headers. `TITLE`, `DOMAIN_MIN`,
/// `DOMAIN_MAX` are recognized but not enforced — domain remapping is the renderer's job.
/// Comment lines (`# ...`) and blank lines are skipped.
///
/// 3D ordering matches `LUT3D` (`red` varies fastest, then `green`, then `blue`),
/// which is the convention used by Adobe and DaVinci Resolve.
public enum CubeLUTParser {
    public enum LUT: Sendable {
        case oneDimensional(samples: [RGBColor])
        case threeDimensional(LUT3D)

        public var size: Int {
            switch self {
            case .oneDimensional(let samples):
                return samples.count
            case .threeDimensional(let lut):
                return lut.size
            }
        }
    }

    public enum ParseError: Error, Equatable {
        case missingSizeHeader
        case duplicateSizeHeader
        case invalidSizeValue(line: Int, raw: String)
        case sizeOutOfRange(line: Int, size: Int, allowed: ClosedRange<Int>)
        case malformedDataLine(line: Int, raw: String)
        case rowCountMismatch(expected: Int, actual: Int)
        case valueNotFinite(line: Int)
    }

    /// 3D LUT size limits — Adobe's spec is 2..256, but moodit caps at 64 in practice.
    /// We accept up to 256 here; downstream code can reject larger sizes by policy.
    static let threeDSizeRange: ClosedRange<Int> = 2 ... 256

    /// 1D LUT size limits.
    static let oneDSizeRange: ClosedRange<Int> = 2 ... 65_536

    public static func parse(_ source: String) throws -> LUT {
        var sizeKind: SizeKind?
        var samples: [RGBColor] = []

        let lines = source.split(separator: "\n", omittingEmptySubsequences: false)

        for (index, rawLine) in lines.enumerated() {
            let lineNumber = index + 1
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty { continue }
            if trimmed.hasPrefix("#") { continue }

            let tokens = trimmed.split(whereSeparator: { $0.isWhitespace })
            guard let head = tokens.first else { continue }

            switch head.uppercased() {
            case "TITLE":
                continue
            case "DOMAIN_MIN", "DOMAIN_MAX":
                continue
            case "LUT_1D_SIZE":
                if sizeKind != nil { throw ParseError.duplicateSizeHeader }
                let size = try parseSize(
                    tokens: Array(tokens.dropFirst()),
                    line: lineNumber,
                    raw: trimmed,
                    allowed: oneDSizeRange
                )
                sizeKind = .oneD(size: size)
                samples.reserveCapacity(size)
            case "LUT_3D_SIZE":
                if sizeKind != nil { throw ParseError.duplicateSizeHeader }
                let size = try parseSize(
                    tokens: Array(tokens.dropFirst()),
                    line: lineNumber,
                    raw: trimmed,
                    allowed: threeDSizeRange
                )
                sizeKind = .threeD(size: size)
                samples.reserveCapacity(size * size * size)
            default:
                guard sizeKind != nil else { throw ParseError.missingSizeHeader }
                let color = try parseTriple(tokens: Array(tokens), line: lineNumber, raw: trimmed)
                samples.append(color)
            }
        }

        guard let sizeKind else { throw ParseError.missingSizeHeader }

        switch sizeKind {
        case .oneD(let size):
            guard samples.count == size else {
                throw ParseError.rowCountMismatch(expected: size, actual: samples.count)
            }
            return .oneDimensional(samples: samples)

        case .threeD(let size):
            let expected = size * size * size
            guard samples.count == expected else {
                throw ParseError.rowCountMismatch(expected: expected, actual: samples.count)
            }
            return .threeDimensional(LUT3D(size: size, values: samples))
        }
    }

    // MARK: - Internals

    private enum SizeKind: Equatable {
        case oneD(size: Int)
        case threeD(size: Int)
    }

    private static func parseSize(
        tokens: [Substring],
        line: Int,
        raw: String,
        allowed: ClosedRange<Int>
    ) throws -> Int {
        guard tokens.count == 1, let value = Int(tokens[0]) else {
            throw ParseError.invalidSizeValue(line: line, raw: raw)
        }
        guard allowed.contains(value) else {
            throw ParseError.sizeOutOfRange(line: line, size: value, allowed: allowed)
        }
        return value
    }

    private static func parseTriple(tokens: [Substring], line: Int, raw: String) throws -> RGBColor {
        guard tokens.count == 3 else {
            throw ParseError.malformedDataLine(line: line, raw: raw)
        }
        guard
            let r = Float(tokens[0]),
            let g = Float(tokens[1]),
            let b = Float(tokens[2])
        else {
            throw ParseError.malformedDataLine(line: line, raw: raw)
        }
        guard r.isFinite, g.isFinite, b.isFinite else {
            throw ParseError.valueNotFinite(line: line)
        }
        return RGBColor(red: r, green: g, blue: b)
    }
}
