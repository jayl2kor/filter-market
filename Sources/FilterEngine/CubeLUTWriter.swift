import Foundation

/// Serializes an `LUT3D` (or 1D LUT samples) to Adobe `.cube` text.
///
/// Round-trip with `CubeLUTParser` preserves: size, ordering (red-fastest), and value
/// precision (printed with 6-decimal precision — well below visible Float quantization).
public enum CubeLUTWriter {
    public static func text(for lut: LUT3D, title: String? = nil) -> String {
        var lines: [String] = []
        if let title { lines.append("TITLE \"\(escape(title))\"") }
        lines.append("LUT_3D_SIZE \(lut.size)")

        for b in 0 ..< lut.size {
            for g in 0 ..< lut.size {
                for r in 0 ..< lut.size {
                    let color = lut.colorAt(red: r, green: g, blue: b)
                    lines.append(formatRow(color))
                }
            }
        }

        return lines.joined(separator: "\n") + "\n"
    }

    public static func text(for samples: [RGBColor], title: String? = nil) -> String {
        var lines: [String] = []
        if let title { lines.append("TITLE \"\(escape(title))\"") }
        lines.append("LUT_1D_SIZE \(samples.count)")
        for color in samples {
            lines.append(formatRow(color))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func formatRow(_ color: RGBColor) -> String {
        String(format: "%.6f %.6f %.6f", color.red, color.green, color.blue)
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\"", with: "\\\"")
    }
}
