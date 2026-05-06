@preconcurrency import CoreGraphics
import Foundation
@preconcurrency import ImageIO

enum LUTImageLoaderError: Error, Equatable, Sendable {
    case missingResource(String)
    case invalidImage
    case unsupportedDimensions(width: Int, height: Int, expectedWidth: Int, expectedHeight: Int)
    case cannotReadPixels
    case cannotCreateTexture
}

struct DecodedLUTImage: Equatable, Sendable {
    let size: Int
    let colors: [RGBColor]
}

enum LUTImageDecoder {
    static func decodePNG(data: Data, size: Int) throws -> DecodedLUTImage {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw LUTImageLoaderError.invalidImage
        }

        let expectedWidth = size * size
        let expectedHeight = size
        guard image.width == expectedWidth, image.height == expectedHeight else {
            throw LUTImageLoaderError.unsupportedDimensions(
                width: image.width,
                height: image.height,
                expectedWidth: expectedWidth,
                expectedHeight: expectedHeight
            )
        }

        let bytesPerPixel = 4
        let bytesPerRow = image.width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: image.height * bytesPerRow)

        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        guard
            let context = CGContext(
                data: &pixels,
                width: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: bitmapInfo
            )
        else {
            throw LUTImageLoaderError.cannotReadPixels
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))

        var colors: [RGBColor] = []
        colors.reserveCapacity(size * size * size)

        for blue in 0..<size {
            for green in 0..<size {
                for red in 0..<size {
                    let x = blue * size + red
                    let y = green
                    let offset = y * bytesPerRow + x * bytesPerPixel
                    colors.append(
                        RGBColor(
                            red: Float(pixels[offset]) / 255,
                            green: Float(pixels[offset + 1]) / 255,
                            blue: Float(pixels[offset + 2]) / 255
                        )
                    )
                }
            }
        }

        return DecodedLUTImage(size: size, colors: colors)
    }
}
