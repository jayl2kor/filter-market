import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import FilterEngine

final class PhotoFilterRendererTests: XCTestCase {
    func testInvalidImageDataThrows() {
        let renderer = PhotoFilterRenderer(jpegCompressionQuality: 1)

        XCTAssertThrowsError(try renderer.apply(to: Data(), configuration: makeConfiguration())) { error in
            XCTAssertEqual(error as? PhotoFilterRendererError, .invalidImageData)
        }
    }

    func testIdentityFilterPreservesSolidColor() throws {
        let inputColor = TestColor(red: 0.42, green: 0.36, blue: 0.28)
        let inputData = try makeSolidPNG(color: inputColor)
        let renderer = PhotoFilterRenderer(jpegCompressionQuality: 1)

        let output = try renderer.apply(to: inputData, configuration: makeConfiguration(preset: .identity))
        let outputColor = try decodeCenterPixel(from: output.filteredData)

        XCTAssertEqual(output.originalData, inputData)
        XCTAssertGreaterThan(output.filteredData.count, 0)
        XCTAssertColor(outputColor, matches: inputColor, accuracy: 0.04)
    }

    func testPresetFilterChangesSolidColor() throws {
        let inputColor = TestColor(red: 0.4, green: 0.4, blue: 0.4)
        let inputData = try makeSolidPNG(color: inputColor)
        let renderer = PhotoFilterRenderer(jpegCompressionQuality: 1)

        let output = try renderer.apply(to: inputData, configuration: makeConfiguration(preset: .warm))
        let outputColor = try decodeCenterPixel(from: output.filteredData)

        XCTAssertGreaterThan(outputColor.red, inputColor.red + 0.02)
        XCTAssertLessThan(outputColor.blue, inputColor.blue - 0.02)
    }

    func testIntensityZeroPreservesSolidColor() throws {
        let inputColor = TestColor(red: 0.22, green: 0.48, blue: 0.66)
        let inputData = try makeSolidPNG(color: inputColor)
        let renderer = PhotoFilterRenderer(jpegCompressionQuality: 1)

        let output = try renderer.apply(
            to: inputData,
            configuration: makeConfiguration(preset: .warm, intensity: .zero)
        )
        let outputColor = try decodeCenterPixel(from: output.filteredData)

        XCTAssertColor(outputColor, matches: inputColor, accuracy: 0.04)
    }

    func testSquareCropProducesSquareJPEG() throws {
        let inputData = try makeSolidPNG(color: TestColor(red: 0.3, green: 0.4, blue: 0.5), width: 12, height: 8)
        let renderer = PhotoFilterRenderer(jpegCompressionQuality: 1)

        let output = try renderer.apply(
            to: inputData,
            configuration: makeConfiguration(preset: .identity),
            cropAspectRatio: .square
        )
        let outputSize = try decodeImageSize(from: output.filteredData)

        XCTAssertEqual(outputSize.width, 8)
        XCTAssertEqual(outputSize.height, 8)
    }

    func testExifOrientationIsAppliedBeforeRendering() throws {
        let inputData = try makeSolidJPEGWithOrientation(
            color: TestColor(red: 0.3, green: 0.4, blue: 0.5),
            width: 12,
            height: 8,
            orientation: 6
        )
        let renderer = PhotoFilterRenderer(jpegCompressionQuality: 1)

        let output = try renderer.apply(to: inputData, configuration: makeConfiguration(preset: .identity))
        let outputSize = try decodeImageSize(from: output.filteredData)

        XCTAssertEqual(outputSize.width, 8)
        XCTAssertEqual(outputSize.height, 12)
    }

    func testAspectRatioUsesPortraitOrientationWhenHeightIsGreaterThanWidth() {
        XCTAssertEqual(
            PhotoCropAspectRatio.fourThree.targetAspectRatio(for: CGSize(width: 300, height: 400)),
            3.0 / 4.0
        )
        XCTAssertEqual(
            PhotoCropAspectRatio.fourFive.targetAspectRatio(for: CGSize(width: 400, height: 700)),
            4.0 / 5.0
        )
        XCTAssertEqual(
            PhotoCropAspectRatio.sixteenNine.targetAspectRatio(for: CGSize(width: 900, height: 1600)),
            9.0 / 16.0
        )
    }

    func testRenderJPEGWithSourceLUTAndVignetteDarkensEdges() throws {
        let inputData = try makeSolidPNG(color: TestColor(red: 0.72, green: 0.72, blue: 0.72), width: 32, height: 32)
        let renderer = PhotoFilterRenderer(jpegCompressionQuality: 1)

        let output = try renderer.renderJPEG(
            to: inputData,
            sourceLUT: LUT3D.identity(size: 5),
            vignette: 1
        )
        let center = try decodePixel(from: output, x: 16, y: 16)
        let corner = try decodePixel(from: output, x: 1, y: 1)

        XCTAssertGreaterThan(center.red, corner.red + 0.18)
        XCTAssertGreaterThan(center.green, corner.green + 0.18)
        XCTAssertGreaterThan(center.blue, corner.blue + 0.18)
    }

    func testRenderImageAvoidsJPEGRoundTripForPreview() throws {
        let inputData = try makeSolidPNG(color: TestColor(red: 0.42, green: 0.42, blue: 0.42), width: 8, height: 6)
        let renderer = PhotoFilterRenderer(jpegCompressionQuality: 1)

        let output = try renderer.renderImage(
            from: inputData,
            sourceLUT: LUT3D.identity(size: 5)
        )

        XCTAssertEqual(output.width, 8)
        XCTAssertEqual(output.height, 6)
    }

    func testRenderJPEGWithGrainIsDeterministic() throws {
        let inputData = try makeSolidPNG(color: TestColor(red: 0.42, green: 0.42, blue: 0.42), width: 24, height: 24)
        let renderer = PhotoFilterRenderer(jpegCompressionQuality: 1)

        let first = try renderer.renderJPEG(
            to: inputData,
            sourceLUT: LUT3D.identity(size: 5),
            grain: 0.5
        )
        let second = try renderer.renderJPEG(
            to: inputData,
            sourceLUT: LUT3D.identity(size: 5),
            grain: 0.5
        )

        XCTAssertEqual(first, second)
    }

    private func makeConfiguration(
        preset: LUTPreset = .identity,
        intensity: FilterIntensity = .full
    ) -> FilterRenderConfiguration {
        FilterRenderConfiguration(
            filter: RenderFilter(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                title: "Test",
                lutFile: nil,
                lutSize: 17,
                fallbackPreset: preset
            ),
            intensity: intensity
        )
    }

    private func makeSolidPNG(color: TestColor, width: Int = 8, height: Int = 8) throws -> Data {
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 255, count: height * bytesPerRow)

        for offset in stride(from: 0, to: pixels.count, by: bytesPerPixel) {
            pixels[offset] = color.redByte
            pixels[offset + 1] = color.greenByte
            pixels[offset + 2] = color.blueByte
        }

        let data = Data(pixels) as CFData
        guard let provider = CGDataProvider(data: data) else {
            throw TestImageError.cannotCreateProvider
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
            throw TestImageError.cannotCreateImage
        }

        return try encode(image: image, type: UTType.png)
    }

    private func makeSolidJPEGWithOrientation(
        color: TestColor,
        width: Int,
        height: Int,
        orientation: Int
    ) throws -> Data {
        let imageData = makeSolidImageData(color: color, width: width, height: height)
        guard let provider = CGDataProvider(data: imageData as CFData) else {
            throw TestImageError.cannotCreateProvider
        }

        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        guard
            let image = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )
        else {
            throw TestImageError.cannotCreateImage
        }

        let properties = [
            kCGImagePropertyOrientation: orientation
        ] as CFDictionary
        return try encode(image: image, type: UTType.jpeg, properties: properties)
    }

    private func makeSolidImageData(color: TestColor, width: Int, height: Int) -> Data {
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 255, count: height * bytesPerRow)

        for offset in stride(from: 0, to: pixels.count, by: bytesPerPixel) {
            pixels[offset] = color.redByte
            pixels[offset + 1] = color.greenByte
            pixels[offset + 2] = color.blueByte
        }

        return Data(pixels)
    }

    private func decodeCenterPixel(from data: Data) throws -> TestColor {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw TestImageError.cannotDecodeImage
        }

        return try decodePixel(from: image, x: image.width / 2, y: image.height / 2)
    }

    private func decodePixel(from data: Data, x: Int, y: Int) throws -> TestColor {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw TestImageError.cannotDecodeImage
        }

        return try decodePixel(from: image, x: x, y: y)
    }

    private func decodePixel(from image: CGImage, x: Int, y: Int) throws -> TestColor {
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
            throw TestImageError.cannotReadPixels
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))

        let offset = y * bytesPerRow + x * bytesPerPixel
        return TestColor(
            red: Float(pixels[offset]) / 255,
            green: Float(pixels[offset + 1]) / 255,
            blue: Float(pixels[offset + 2]) / 255
        )
    }

    private func decodeImageSize(from data: Data) throws -> CGSize {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw TestImageError.cannotDecodeImage
        }

        return CGSize(width: image.width, height: image.height)
    }

    private func encode(image: CGImage, type: UTType, properties: CFDictionary? = nil) throws -> Data {
        let encodedData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            encodedData,
            type.identifier as CFString,
            1,
            nil
        ) else {
            throw TestImageError.cannotCreateDestination
        }

        CGImageDestinationAddImage(destination, image, properties)
        guard CGImageDestinationFinalize(destination) else {
            throw TestImageError.cannotFinalize
        }

        return encodedData as Data
    }

    private func XCTAssertColor(
        _ color: TestColor,
        matches expected: TestColor,
        accuracy: Float,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(color.red, expected.red, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(color.green, expected.green, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(color.blue, expected.blue, accuracy: accuracy, file: file, line: line)
    }
}

private struct TestColor {
    let red: Float
    let green: Float
    let blue: Float

    var redByte: UInt8 {
        red.byteValue
    }

    var greenByte: UInt8 {
        green.byteValue
    }

    var blueByte: UInt8 {
        blue.byteValue
    }
}

private extension Float {
    var byteValue: UInt8 {
        UInt8((min(max(self, 0), 1) * 255).rounded())
    }
}

private enum TestImageError: Error {
    case cannotCreateProvider
    case cannotCreateImage
    case cannotCreateDestination
    case cannotFinalize
    case cannotDecodeImage
    case cannotReadPixels
}
