import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import FilterEngine

final class LUTImageDecoderTests: XCTestCase {
    func testDecodePackedIdentityPNG() throws {
        let data = try makePackedPNG(size: 3)

        let image = try LUTImageDecoder.decodePNG(data: data, size: 3)

        XCTAssertEqual(image.size, 3)
        XCTAssertEqual(image.colors.count, 27)
        XCTAssertColor(image.colors[0], red: 0, green: 0, blue: 0)
        XCTAssertColor(image.colors[2], red: 1, green: 0, blue: 0)
        XCTAssertColor(image.colors[6], red: 0, green: 1, blue: 0)
        XCTAssertColor(image.colors[18], red: 0, green: 0, blue: 1)
        XCTAssertColor(image.colors[26], red: 1, green: 1, blue: 1)
    }

    func testDimensionMismatchThrows() throws {
        let data = try makePackedPNG(size: 2)

        XCTAssertThrowsError(try LUTImageDecoder.decodePNG(data: data, size: 3)) { error in
            XCTAssertEqual(
                error as? LUTImageLoaderError,
                .unsupportedDimensions(width: 4, height: 2, expectedWidth: 9, expectedHeight: 3)
            )
        }
    }

    private func XCTAssertColor(
        _ color: RGBColor,
        red: Float,
        green: Float,
        blue: Float,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(color.red, red, accuracy: 0.01, file: file, line: line)
        XCTAssertEqual(color.green, green, accuracy: 0.01, file: file, line: line)
        XCTAssertEqual(color.blue, blue, accuracy: 0.01, file: file, line: line)
    }

    private func makePackedPNG(size: Int) throws -> Data {
        let width = size * size
        let height = size
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 255, count: height * bytesPerRow)

        for blue in 0..<size {
            for green in 0..<size {
                for red in 0..<size {
                    let x = blue * size + red
                    let y = green
                    let offset = y * bytesPerRow + x * bytesPerPixel
                    pixels[offset] = byte(red, size: size)
                    pixels[offset + 1] = byte(green, size: size)
                    pixels[offset + 2] = byte(blue, size: size)
                    pixels[offset + 3] = 255
                }
            }
        }

        let data = Data(pixels) as CFData
        guard let provider = CGDataProvider(data: data) else {
            throw TestPNGError.cannotCreateProvider
        }

        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        guard
            let image = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )
        else {
            throw TestPNGError.cannotCreateImage
        }

        let pngData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(pngData, UTType.png.identifier as CFString, 1, nil) else {
            throw TestPNGError.cannotCreateDestination
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw TestPNGError.cannotFinalize
        }

        return pngData as Data
    }

    private func byte(_ value: Int, size: Int) -> UInt8 {
        UInt8((Float(value) / Float(size - 1) * 255).rounded())
    }
}

private enum TestPNGError: Error {
    case cannotCreateProvider
    case cannotCreateImage
    case cannotCreateDestination
    case cannotFinalize
}
