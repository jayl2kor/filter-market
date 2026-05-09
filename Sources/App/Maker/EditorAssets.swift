import DesignSystem
import SwiftUI
import UIKit

enum PlaceholderPhoto {
    static func makeJPEGData() -> Data {
        let size = CGSize(width: 1200, height: 1600)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            let colors = [
                UIColor(red: 0.12, green: 0.14, blue: 0.19, alpha: 1).cgColor,
                UIColor(red: 0.64, green: 0.42, blue: 0.26, alpha: 1).cgColor
            ]
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: [0, 1]
            )
            context.cgContext.drawLinearGradient(
                gradient!,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )
            UIColor.white.withAlphaComponent(0.16).setStroke()
            UIBezierPath(roundedRect: rect.insetBy(dx: 120, dy: 160), cornerRadius: 42).stroke()
        }
        return image.jpegData(compressionQuality: 0.92) ?? Data()
    }
}

struct WorkflowFlowLayout: Layout {
    var spacing: CGFloat = Sp.xs

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth > 0, rowWidth + spacing + size.width > maxWidth {
                totalHeight += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += (rowWidth > 0 ? spacing : 0) + size.width
            rowHeight = max(rowHeight, size.height)
        }

        totalHeight += rowHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

enum EditorReferenceSampleImage {
    static func makeJPEGData(kind: EditorReferenceSampleKind) -> Data {
        let size = CGSize(width: 960, height: 1200)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            drawBase(kind: kind, in: rect, context: context.cgContext)
            drawDetail(kind: kind, in: rect)
        }
        return image.jpegData(compressionQuality: 0.88) ?? PlaceholderPhoto.makeJPEGData()
    }

    static func normalizedJPEGData(from image: UIImage, maxLongEdge: CGFloat = 1280) -> Data? {
        let sourceSize = image.size
        guard sourceSize.width > 0, sourceSize.height > 0 else { return nil }
        let scale = min(1, maxLongEdge / max(sourceSize.width, sourceSize.height))
        let targetSize = CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let normalized = renderer.image { _ in
            UIColor.black.setFill()
            UIRectFill(CGRect(origin: .zero, size: targetSize))
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return normalized.jpegData(compressionQuality: 0.86)
    }

    private static func drawBase(kind: EditorReferenceSampleKind, in rect: CGRect, context: CGContext) {
        let colors: [UIColor] = switch kind {
        case .portrait:
            [
                UIColor(red: 0.70, green: 0.62, blue: 0.55, alpha: 1),
                UIColor(red: 0.25, green: 0.29, blue: 0.35, alpha: 1)
            ]
        case .landscape:
            [
                UIColor(red: 0.35, green: 0.56, blue: 0.78, alpha: 1),
                UIColor(red: 0.78, green: 0.71, blue: 0.47, alpha: 1),
                UIColor(red: 0.25, green: 0.39, blue: 0.28, alpha: 1)
            ]
        case .indoor:
            [
                UIColor(red: 0.22, green: 0.19, blue: 0.18, alpha: 1),
                UIColor(red: 0.58, green: 0.42, blue: 0.29, alpha: 1)
            ]
        case .lifestyle:
            [
                UIColor(red: 0.72, green: 0.66, blue: 0.57, alpha: 1),
                UIColor(red: 0.45, green: 0.36, blue: 0.29, alpha: 1)
            ]
        }

        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors.map(\.cgColor) as CFArray,
            locations: nil
        )
        context.drawLinearGradient(
            gradient!,
            start: CGPoint(x: rect.minX, y: rect.minY),
            end: CGPoint(x: rect.maxX, y: rect.maxY),
            options: []
        )
    }

    private static func drawDetail(kind: EditorReferenceSampleKind, in rect: CGRect) {
        switch kind {
        case .portrait:
            UIColor(red: 0.88, green: 0.66, blue: 0.52, alpha: 1).setFill()
            UIBezierPath(ovalIn: CGRect(x: rect.midX - 150, y: 210, width: 300, height: 340)).fill()
            UIColor(red: 0.18, green: 0.15, blue: 0.13, alpha: 1).setFill()
            UIBezierPath(roundedRect: CGRect(x: rect.midX - 210, y: 520, width: 420, height: 440), cornerRadius: 120).fill()
            UIColor.white.withAlphaComponent(0.20).setStroke()
            UIBezierPath(roundedRect: rect.insetBy(dx: 110, dy: 145), cornerRadius: 52).stroke()
        case .landscape:
            UIColor.white.withAlphaComponent(0.85).setFill()
            UIBezierPath(ovalIn: CGRect(x: 660, y: 145, width: 120, height: 120)).fill()
            UIColor(red: 0.12, green: 0.23, blue: 0.18, alpha: 1).setFill()
            UIBezierPath(rect: CGRect(x: 0, y: 780, width: rect.width, height: 420)).fill()
            UIColor(red: 0.30, green: 0.45, blue: 0.30, alpha: 1).setFill()
            UIBezierPath(roundedRect: CGRect(x: 130, y: 650, width: 720, height: 220), cornerRadius: 110).fill()
        case .indoor:
            UIColor(red: 0.94, green: 0.70, blue: 0.36, alpha: 1).setFill()
            UIBezierPath(roundedRect: CGRect(x: 120, y: 180, width: 240, height: 360), cornerRadius: 18).fill()
            UIColor(red: 0.18, green: 0.15, blue: 0.14, alpha: 1).setFill()
            UIBezierPath(roundedRect: CGRect(x: 420, y: 360, width: 360, height: 560), cornerRadius: 36).fill()
            UIColor.white.withAlphaComponent(0.16).setStroke()
            UIBezierPath(roundedRect: CGRect(x: 170, y: 720, width: 280, height: 160), cornerRadius: 28).stroke()
        case .lifestyle:
            UIColor(red: 0.32, green: 0.24, blue: 0.18, alpha: 1).setFill()
            UIBezierPath(roundedRect: CGRect(x: 90, y: 760, width: 780, height: 210), cornerRadius: 38).fill()
            UIColor(red: 0.96, green: 0.89, blue: 0.76, alpha: 1).setFill()
            UIBezierPath(ovalIn: CGRect(x: 180, y: 330, width: 270, height: 270)).fill()
            UIColor(red: 0.22, green: 0.18, blue: 0.14, alpha: 1).setStroke()
            UIBezierPath(ovalIn: CGRect(x: 240, y: 390, width: 150, height: 150)).stroke()
            UIColor(red: 0.72, green: 0.28, blue: 0.20, alpha: 1).setFill()
            UIBezierPath(roundedRect: CGRect(x: 530, y: 430, width: 170, height: 250), cornerRadius: 32).fill()
        }
    }
}
