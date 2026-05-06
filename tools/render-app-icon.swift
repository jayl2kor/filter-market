// 한국어: Moodit 앱 아이콘 PNG 렌더러.
// SVG 의존성 없이 Core Graphics 로 알려진 두-원 (Twin Lens) 디자인을 1024×1024
// PNG 으로 직접 그린다. macOS 13+ 에서 동작. 임시 도구이므로 swift 스크립트로 유지.
//
// 사용:
//   swift tools/render-app-icon.swift <variant: light|dark|tinted> <out.png>
//
// 디자인 사양 (mockups/brand/app-icon-*.svg 와 정합):
//   - 캔버스 1024×1024
//   - 외곽 원: cx=384, cy=512, r=162, stroke-width=36 (외경 180u 매칭)
//   - 채움 원: cx=640, cy=512, r=180
//   - light: bg #F5F4EF, mark #B8853A
//   - dark:  bg #000000, mark #E8B86D
//   - tinted: bg #000000, mark #FFFFFF (시스템이 사용자 틴트 적용)

import AppKit
import CoreGraphics
import Foundation

struct Palette {
    let background: CGColor
    let mark: CGColor
}

func palette(for variant: String) -> Palette? {
    switch variant {
    case "light":
        return Palette(
            background: CGColor(red: 0xF5/255.0, green: 0xF4/255.0, blue: 0xEF/255.0, alpha: 1),
            mark: CGColor(red: 0xB8/255.0, green: 0x85/255.0, blue: 0x3A/255.0, alpha: 1)
        )
    case "dark":
        return Palette(
            background: CGColor(red: 0, green: 0, blue: 0, alpha: 1),
            mark: CGColor(red: 0xE8/255.0, green: 0xB8/255.0, blue: 0x6D/255.0, alpha: 1)
        )
    case "tinted":
        return Palette(
            background: CGColor(red: 0, green: 0, blue: 0, alpha: 1),
            mark: CGColor(red: 1, green: 1, blue: 1, alpha: 1)
        )
    default:
        return nil
    }
}

func render(variant: String, outURL: URL) throws {
    guard let palette = palette(for: variant) else {
        FileHandle.standardError.write("unknown variant: \(variant)\n".data(using: .utf8)!)
        exit(2)
    }

    let size = 1024
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let ctx = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        FileHandle.standardError.write("failed to create CGContext\n".data(using: .utf8)!)
        exit(3)
    }

    // 배경 채움.
    ctx.setFillColor(palette.background)
    ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

    // SVG 좌표계는 y-down, CGContext 은 y-up. y 축을 뒤집어 SVG 와 동일하게 작업.
    ctx.saveGState()
    ctx.translateBy(x: 0, y: CGFloat(size))
    ctx.scaleBy(x: 1, y: -1)

    // 외곽 원 — stroke 만 (cx=384, cy=512, r=162, stroke-width=36)
    ctx.setStrokeColor(palette.mark)
    ctx.setLineWidth(36)
    ctx.strokeEllipse(in: CGRect(x: 384 - 162, y: 512 - 162, width: 324, height: 324))

    // 채움 원 — fill (cx=640, cy=512, r=180)
    ctx.setFillColor(palette.mark)
    ctx.fillEllipse(in: CGRect(x: 640 - 180, y: 512 - 180, width: 360, height: 360))

    ctx.restoreGState()

    guard let cgImage = ctx.makeImage() else {
        FileHandle.standardError.write("failed to make CGImage\n".data(using: .utf8)!)
        exit(4)
    }

    let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
    guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write("failed to encode PNG\n".data(using: .utf8)!)
        exit(5)
    }

    try pngData.write(to: outURL)
}

let args = CommandLine.arguments
guard args.count == 3 else {
    FileHandle.standardError.write("usage: render-app-icon.swift <light|dark|tinted> <out.png>\n".data(using: .utf8)!)
    exit(1)
}

let variant = args[1]
let outURL = URL(fileURLWithPath: args[2])
try render(variant: variant, outURL: outURL)
print("rendered \(variant) → \(outURL.path)")
