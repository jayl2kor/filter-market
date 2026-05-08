@preconcurrency import CoreGraphics
@preconcurrency import CoreImage
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

public enum PhotoCropAspectRatio: String, CaseIterable, Hashable, Identifiable, Sendable {
    case square
    case fourThree
    case sixteenNine

    public var id: String {
        rawValue
    }

    public var label: String {
        switch self {
        case .square:
            "1:1"
        case .fourThree:
            "4:3"
        case .sixteenNine:
            "16:9"
        }
    }

    public func targetAspectRatio(for size: CGSize) -> CGFloat {
        let landscapeAspectRatio: CGFloat = switch self {
        case .square:
            1
        case .fourThree:
            4.0 / 3.0
        case .sixteenNine:
            16.0 / 9.0
        }

        guard self != .square, size.height > size.width else {
            return landscapeAspectRatio
        }

        return 1 / landscapeAspectRatio
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
    private let ciContext = CIContext()

    public init(
        lutResourceBundle: Bundle? = nil,
        jpegCompressionQuality: CGFloat = 0.92
    ) {
        self.lutResourceBundle = lutResourceBundle
        self.jpegCompressionQuality = min(max(jpegCompressionQuality, 0), 1)
    }

    public func apply(
        to originalData: Data,
        configuration: FilterRenderConfiguration,
        cropAspectRatio: PhotoCropAspectRatio? = nil
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

        let normalizedImage = try normalizeOrientation(sourceImage, source: source)
        var pixelBuffer = try PixelBuffer(image: normalizedImage)
        let lut = makeLUT(for: configuration.filter)

        pixelBuffer.apply(lut: lut, intensity: configuration.intensity)
        let filteredImage = try pixelBuffer.makeImage()
        let outputImage = try crop(filteredImage, aspectRatio: cropAspectRatio)
        let filteredData = try encodeJPEG(outputImage)

        return FilteredPhoto(
            originalData: originalData,
            filteredData: filteredData,
            configuration: configuration
        )
    }

    public func renderJPEG(
        to originalData: Data,
        sourceLUT: LUT3D,
        intensity: FilterIntensity = .full,
        grain: Float = 0,
        vignette: Float = 0,
        cropAspectRatio: PhotoCropAspectRatio? = nil
    ) throws -> Data {
        guard !originalData.isEmpty else {
            throw PhotoFilterRendererError.invalidImageData
        }

        guard
            let source = CGImageSourceCreateWithData(originalData as CFData, nil),
            let sourceImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw PhotoFilterRendererError.invalidImageData
        }

        let normalizedImage = try normalizeOrientation(sourceImage, source: source)
        var pixelBuffer = try PixelBuffer(image: normalizedImage)

        pixelBuffer.apply(lut: sourceLUT, intensity: intensity)
        pixelBuffer.applySpatialAdjustments(grain: grain, vignette: vignette)

        let filteredImage = try pixelBuffer.makeImage()
        let outputImage = try crop(filteredImage, aspectRatio: cropAspectRatio)
        return try encodeJPEG(outputImage)
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

    private func normalizeOrientation(_ image: CGImage, source: CGImageSource) throws -> CGImage {
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let orientation = properties?[kCGImagePropertyOrientation] as? UInt32 ?? 1
        guard orientation != 1 else {
            return image
        }

        let orientedImage = CIImage(cgImage: image).oriented(forExifOrientation: Int32(orientation))
        let extent = orientedImage.extent.integral
        let translatedImage = orientedImage.transformed(
            by: CGAffineTransform(translationX: -extent.origin.x, y: -extent.origin.y)
        )
        let outputRect = CGRect(origin: .zero, size: extent.size)

        guard let normalizedImage = ciContext.createCGImage(translatedImage, from: outputRect) else {
            throw PhotoFilterRendererError.cannotCreateImage
        }

        return normalizedImage
    }

    private func crop(_ image: CGImage, aspectRatio: PhotoCropAspectRatio?) throws -> CGImage {
        guard let aspectRatio else {
            return image
        }

        let imageSize = CGSize(width: image.width, height: image.height)
        let targetAspectRatio = aspectRatio.targetAspectRatio(for: imageSize)
        let currentAspectRatio = CGFloat(image.width) / CGFloat(max(image.height, 1))

        let cropSize: CGSize
        if currentAspectRatio > targetAspectRatio {
            cropSize = CGSize(width: CGFloat(image.height) * targetAspectRatio, height: CGFloat(image.height))
        } else {
            cropSize = CGSize(width: CGFloat(image.width), height: CGFloat(image.width) / targetAspectRatio)
        }

        let cropRect = CGRect(
            x: (CGFloat(image.width) - cropSize.width) / 2,
            y: (CGFloat(image.height) - cropSize.height) / 2,
            width: cropSize.width,
            height: cropSize.height
        ).integral

        guard let croppedImage = image.cropping(to: cropRect) else {
            throw PhotoFilterRendererError.cannotCreateImage
        }

        return croppedImage
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

    mutating func applySpatialAdjustments(grain: Float, vignette: Float) {
        let grainStrength = max(0, min(grain, 1))
        let vignetteStrength = min(max(vignette, -1), 1)
        guard grainStrength > 0 || vignetteStrength != 0 else { return }

        let bytesPerPixel = 4
        let centerX = Float(max(width - 1, 1)) / 2
        let centerY = Float(max(height - 1, 1)) / 2
        let maxDistance = sqrt(centerX * centerX + centerY * centerY)

        for y in 0 ..< height {
            for x in 0 ..< width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                var red = Float(pixels[offset]) / 255
                var green = Float(pixels[offset + 1]) / 255
                var blue = Float(pixels[offset + 2]) / 255

                if vignetteStrength != 0 {
                    let dx = Float(x) - centerX
                    let dy = Float(y) - centerY
                    let normalizedDistance = min(sqrt(dx * dx + dy * dy) / maxDistance, 1)
                    let edgeWeight = normalizedDistance * normalizedDistance
                    let factor = 1 - vignetteStrength * 0.55 * edgeWeight
                    red *= factor
                    green *= factor
                    blue *= factor
                }

                if grainStrength > 0 {
                    let noise = deterministicNoise(x: x, y: y) * grainStrength * 0.12
                    red += noise
                    green += noise
                    blue += noise
                }

                pixels[offset] = red.byteValue
                pixels[offset + 1] = green.byteValue
                pixels[offset + 2] = blue.byteValue
            }
        }
    }

    private func deterministicNoise(x: Int, y: Int) -> Float {
        var value = UInt32(truncatingIfNeeded: x &* 374_761_393)
        value &+= UInt32(truncatingIfNeeded: y &* 668_265_263)
        value = (value ^ (value >> 13)) &* 1_274_126_177
        let normalized = Float(value & 0xffff) / Float(UInt16.max)
        return normalized * 2 - 1
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
