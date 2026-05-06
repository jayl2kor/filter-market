@preconcurrency import CoreGraphics
import Foundation
@preconcurrency import ImageIO
import UniformTypeIdentifiers

public struct FilteredPhoto: Equatable, Sendable {
    public let originalData: Data
    public let filteredData: Data
    public let configuration: FilterRenderConfiguration
    public let createdAt: Date

    public var originalByteCount: Int {
        originalData.count
    }

    public var filteredByteCount: Int {
        filteredData.count
    }

    public init(
        originalData: Data,
        filteredData: Data,
        configuration: FilterRenderConfiguration,
        createdAt: Date = Date()
    ) {
        self.originalData = originalData
        self.filteredData = filteredData
        self.configuration = configuration
        self.createdAt = createdAt
    }
}

public enum PhotoFilterRendererError: Error, Equatable, Sendable {
    case invalidImageData
    case cannotReadPixels
    case cannotCreateImage
    case cannotEncodeJPEG
}

public final class PhotoFilterRenderer {
    private let lutResourceBundle: Bundle?
    private let jpegCompressionQuality: CGFloat

    public init(
        lutResourceBundle: Bundle? = nil,
        jpegCompressionQuality: CGFloat = 0.92
    ) {
        self.lutResourceBundle = lutResourceBundle
        self.jpegCompressionQuality = min(max(jpegCompressionQuality, 0), 1)
    }

    public func apply(
        to originalData: Data,
        configuration: FilterRenderConfiguration
    ) throws -> FilteredPhoto {
        guard !originalData.isEmpty else {
            throw PhotoFilterRendererError.invalidImageData
        }

        guard
            let source = CGImageSourceCreateWithData(originalData as CFData, nil),
            let sourceImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw PhotoFilterRendererError.invalidImageData
        }

        var pixelBuffer = try PixelBuffer(image: sourceImage)
        let lut = makeLUT(for: configuration.filter)

        pixelBuffer.apply(lut: lut, intensity: configuration.intensity)
        let filteredImage = try pixelBuffer.makeImage()
        let filteredData = try encodeJPEG(filteredImage)

        return FilteredPhoto(
            originalData: originalData,
            filteredData: filteredData,
            configuration: configuration
        )
    }

    private func makeLUT(for filter: RenderFilter) -> LUT3D {
        if
            let lutResourceBundle,
            let lutFile = filter.lutFile,
            let lut = try? loadLUT(file: lutFile, size: filter.lutSize, bundle: lutResourceBundle)
        {
            return lut
        }

        return LUT3D.preset(filter.fallbackPreset, size: filter.lutSize)
    }

    private func loadLUT(file: String, size: Int, bundle: Bundle) throws -> LUT3D {
        let url = try LUTResourceResolver.url(bundle: bundle, resourcePath: file)
        let data = try Data(contentsOf: url)
        let image = try LUTImageDecoder.decodePNG(data: data, size: size)
        return LUT3D(size: image.size, values: image.colors)
    }

    private func encodeJPEG(_ image: CGImage) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw PhotoFilterRendererError.cannotEncodeJPEG
        }

        let options = [
            kCGImageDestinationLossyCompressionQuality: jpegCompressionQuality
        ] as CFDictionary
        CGImageDestinationAddImage(destination, image, options)

        guard CGImageDestinationFinalize(destination) else {
            throw PhotoFilterRendererError.cannotEncodeJPEG
        }

        return data as Data
    }
}

private struct PixelBuffer {
    let width: Int
    let height: Int
    let bytesPerRow: Int
    var pixels: [UInt8]

    init(image: CGImage) throws {
        width = image.width
        height = image.height
        let bytesPerPixel = 4
        bytesPerRow = width * bytesPerPixel
        pixels = [UInt8](repeating: 0, count: height * bytesPerRow)

        guard let context = CGContext.rgbaContext(
            data: &pixels,
            width: width,
            height: height,
            bytesPerRow: bytesPerRow
        ) else {
            throw PhotoFilterRendererError.cannotReadPixels
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    }

    mutating func apply(lut: LUT3D, intensity: FilterIntensity) {
        let bytesPerPixel = 4
        for offset in stride(from: 0, to: pixels.count, by: bytesPerPixel) {
            let input = RGBColor(
                red: Float(pixels[offset]) / 255,
                green: Float(pixels[offset + 1]) / 255,
                blue: Float(pixels[offset + 2]) / 255
            )
            let output = LUTSampler.sample(lut, color: input, intensity: intensity)
            pixels[offset] = output.red.byteValue
            pixels[offset + 1] = output.green.byteValue
            pixels[offset + 2] = output.blue.byteValue
        }
    }

    func makeImage() throws -> CGImage {
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else {
            throw PhotoFilterRendererError.cannotCreateImage
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
            throw PhotoFilterRendererError.cannotCreateImage
        }

        return image
    }
}

private extension CGContext {
    static func rgbaContext(
        data: UnsafeMutableRawPointer?,
        width: Int,
        height: Int,
        bytesPerRow: Int
    ) -> CGContext? {
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        return CGContext(
            data: data,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo
        )
    }
}

private extension Float {
    var byteValue: UInt8 {
        UInt8((min(max(self, 0), 1) * 255).rounded())
    }
}
