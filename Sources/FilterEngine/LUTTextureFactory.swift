import Foundation
import Metal

enum LUTTextureFactory {
    static func makeLUT(device: MTLDevice, bundle: Bundle, resourcePath: String, size: Int) throws -> MTLTexture {
        let url = try LUTResourceResolver.url(bundle: bundle, resourcePath: resourcePath)
        let data = try Data(contentsOf: url)
        let image = try LUTImageDecoder.decodePNG(data: data, size: size)
        guard let texture = makeLUT(device: device, size: image.size, colors: image.colors) else {
            throw LUTImageLoaderError.cannotCreateTexture
        }
        return texture
    }

    static func makeLUT(device: MTLDevice, preset: LUTPreset, size: Int = 33) -> MTLTexture? {
        makeLUT(device: device, size: size) { red, green, blue in
            let color = preset.transform(red: red, green: green, blue: blue)
            return (color.red, color.green, color.blue)
        }
    }

    static func makeWarmLUT(device: MTLDevice, size: Int = 33) -> MTLTexture? {
        makeLUT(device: device, preset: .warm, size: size)
    }

    static func makeIdentityLUT(device: MTLDevice, size: Int = 33) -> MTLTexture? {
        makeLUT(device: device, preset: .identity, size: size)
    }

    private static func makeLUT(device: MTLDevice, size: Int, colors: [RGBColor]) -> MTLTexture? {
        makeLUT(device: device, size: size) { red, green, blue in
            let redIndex = Int((red * Float(size - 1)).rounded())
            let greenIndex = Int((green * Float(size - 1)).rounded())
            let blueIndex = Int((blue * Float(size - 1)).rounded())
            let color = colors[blueIndex * size * size + greenIndex * size + redIndex]
            return (color.red, color.green, color.blue)
        }
    }

    private static func makeLUT(
        device: MTLDevice,
        size: Int,
        transform: (Float, Float, Float) -> (Float, Float, Float)
    ) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = .type3D
        descriptor.pixelFormat = .rgba32Float
        descriptor.width = size
        descriptor.height = size
        descriptor.depth = size
        descriptor.mipmapLevelCount = 1
        descriptor.usage = .shaderRead
        descriptor.storageMode = .shared

        guard let texture = device.makeTexture(descriptor: descriptor) else {
            return nil
        }

        var values: [Float] = []
        values.reserveCapacity(size * size * size * 4)

        for blueIndex in 0..<size {
            for greenIndex in 0..<size {
                for redIndex in 0..<size {
                    let red = Float(redIndex) / Float(size - 1)
                    let green = Float(greenIndex) / Float(size - 1)
                    let blue = Float(blueIndex) / Float(size - 1)
                    let color = transform(red, green, blue)
                    values.append(color.0)
                    values.append(color.1)
                    values.append(color.2)
                    values.append(1)
                }
            }
        }

        let bytesPerPixel = 4 * MemoryLayout<Float>.size
        let bytesPerRow = size * bytesPerPixel
        let bytesPerImage = size * bytesPerRow
        let region = MTLRegionMake3D(0, 0, 0, size, size, size)

        values.withUnsafeBytes { buffer in
            texture.replace(
                region: region,
                mipmapLevel: 0,
                slice: 0,
                withBytes: buffer.baseAddress!,
                bytesPerRow: bytesPerRow,
                bytesPerImage: bytesPerImage
            )
        }

        return texture
    }
}
