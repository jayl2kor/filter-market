import SwiftUI

// MARK: - FMFilterCoverArt

/// 시드 필터의 procedural cover illustration.
///
/// 실제 사진 자산이 들어오기 전, 그라디언트 단색 fallback 보다 더 풍부한
/// 시각을 제공하기 위한 Canvas 기반 일러스트.
/// 카테고리에 맞춰 다음 모티프를 그린다:
///
/// - cinematic: 드넓은 하늘 + 실루엣 (영화 한 컷)
/// - vintage: 따뜻한 햇빛 + 가로선 (필름)
/// - pastel: 부드러운 그라디언트 + 점들 (꿈)
/// - monochrome: 고대비 명암 + 사선 빛
/// - portrait: 인물 실루엣 + 후광
/// - food: 따뜻한 그릇 톤 + 조각
/// - travel: 산 + 해 + 구름
/// - mood: 깊은 톤 + 물결
///
/// 실제 사진 도입 시 `FilterCoverAssetSource.image(for:)` 가 image asset 을
/// 우선 반환하고, 없을 때만 본 illustration 으로 fallback.
public struct FMFilterCoverArt: View {
    public enum Motif: String, Sendable {
        case cinematic
        case vintage
        case pastel
        case monochrome
        case portrait
        case food
        case travel
        case mood
    }

    private let motif: Motif

    public init(motif: Motif) {
        self.motif = motif
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack {
                background
                Canvas { ctx, size in
                    drawMotif(ctx: ctx, size: size)
                }
                vignette
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Background gradient

    @ViewBuilder
    private var background: some View {
        LinearGradient(
            colors: gradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var gradientColors: [Color] {
        switch motif {
        case .cinematic: [Color(hex: 0x594878), Color(hex: 0x1F1832)]
        case .vintage: [Color(hex: 0xC79A72), Color(hex: 0x6E4827)]
        case .pastel: [Color(hex: 0xF6E2E8), Color(hex: 0xC485A6)]
        case .monochrome: [Color(hex: 0x9A9A9A), Color(hex: 0x1F1F1F)]
        case .portrait: [Color(hex: 0xE8B89B), Color(hex: 0xA66B47)]
        case .food: [Color(hex: 0xE0B279), Color(hex: 0x8E5D2E)]
        case .travel: [Color(hex: 0xA8C9D9), Color(hex: 0x4A7896)]
        case .mood: [Color(hex: 0x5A6E96), Color(hex: 0x2A3848)]
        }
    }

    private var vignette: some View {
        RadialGradient(
            colors: [Color.clear, Color.black.opacity(0.32)],
            center: .center,
            startRadius: 60,
            endRadius: 220
        )
        .blendMode(.multiply)
    }

    // MARK: - Motif drawing

    private func drawMotif(ctx: GraphicsContext, size: CGSize) {
        switch motif {
        case .cinematic: drawCinematic(ctx: ctx, size: size)
        case .vintage: drawVintage(ctx: ctx, size: size)
        case .pastel: drawPastel(ctx: ctx, size: size)
        case .monochrome: drawMonochrome(ctx: ctx, size: size)
        case .portrait: drawPortrait(ctx: ctx, size: size)
        case .food: drawFood(ctx: ctx, size: size)
        case .travel: drawTravel(ctx: ctx, size: size)
        case .mood: drawMood(ctx: ctx, size: size)
        }
    }

    private func drawCinematic(ctx: GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height
        // 영화 한 장면 — 가로 띠 (시네마스코프) + 실루엣
        var stripe = Path()
        stripe.addRect(CGRect(x: 0, y: 0, width: w, height: h * 0.18))
        stripe.addRect(CGRect(x: 0, y: h * 0.82, width: w, height: h * 0.18))
        ctx.fill(stripe, with: .color(.black.opacity(0.55)))

        // 도시 실루엣
        var city = Path()
        city.move(to: CGPoint(x: 0, y: h * 0.82))
        let buildings: [(CGFloat, CGFloat)] = [
            (0.08, 0.66), (0.16, 0.74), (0.22, 0.60),
            (0.32, 0.56), (0.40, 0.70), (0.48, 0.50),
            (0.58, 0.66), (0.66, 0.58), (0.78, 0.70),
            (0.88, 0.62), (1.0, 0.74)
        ]
        for (x, y) in buildings {
            city.addLine(to: CGPoint(x: w * x, y: h * y))
        }
        city.addLine(to: CGPoint(x: w, y: h * 0.82))
        city.closeSubpath()
        ctx.fill(city, with: .color(.black.opacity(0.7)))
    }

    private func drawVintage(ctx: GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height
        // 햇살 + 필름 그레인 줄
        let sun = Path(ellipseIn: CGRect(
            x: w * 0.62, y: h * 0.12,
            width: w * 0.30, height: w * 0.30
        ))
        ctx.fill(sun, with: .color(Color(hex: 0xF6E2C0).opacity(0.85)))

        // 빛줄기
        for i in 0..<6 {
            var ray = Path()
            let angle = Double(i) * .pi / 6
            let cx = w * 0.77
            let cy = h * 0.27
            ray.move(to: CGPoint(x: cx, y: cy))
            ray.addLine(to: CGPoint(
                x: cx + cos(angle) * w,
                y: cy + sin(angle) * w
            ))
            ctx.stroke(ray, with: .color(Color(hex: 0xF6E2C0).opacity(0.16)), lineWidth: 12)
        }

        // 가로 필름 흠집
        for y in stride(from: h * 0.5, to: h, by: h * 0.08) {
            var line = Path()
            line.move(to: CGPoint(x: 0, y: y))
            line.addLine(to: CGPoint(x: w, y: y))
            ctx.stroke(line, with: .color(.white.opacity(0.06)), lineWidth: 1)
        }
    }

    private func drawPastel(ctx: GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height
        // 부드러운 점들 (보케)
        let dots: [(CGFloat, CGFloat, CGFloat)] = [
            (0.20, 0.30, 0.18), (0.65, 0.18, 0.12),
            (0.42, 0.55, 0.22), (0.78, 0.65, 0.16),
            (0.18, 0.78, 0.14), (0.55, 0.85, 0.10)
        ]
        for (cx, cy, radius) in dots {
            let r = w * radius
            let dot = Path(ellipseIn: CGRect(
                x: w * cx - r / 2, y: h * cy - r / 2,
                width: r, height: r
            ))
            ctx.fill(dot, with: .color(.white.opacity(0.25)))
        }
    }

    private func drawMonochrome(ctx: GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height
        // 사선 빛 + 그림자 블록
        var stripe = Path()
        stripe.move(to: CGPoint(x: -w * 0.2, y: h * 0.3))
        stripe.addLine(to: CGPoint(x: w * 0.4, y: -h * 0.1))
        stripe.addLine(to: CGPoint(x: w * 0.5, y: 0))
        stripe.addLine(to: CGPoint(x: -w * 0.1, y: h * 0.4))
        stripe.closeSubpath()
        ctx.fill(stripe, with: .color(.white.opacity(0.16)))

        // 어두운 블록
        let dark = Path(roundedRect: CGRect(
            x: w * 0.55, y: h * 0.55,
            width: w * 0.40, height: h * 0.35
        ), cornerRadius: 4)
        ctx.fill(dark, with: .color(.black.opacity(0.4)))
    }

    private func drawPortrait(ctx: GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height
        // 인물 실루엣
        let head = Path(ellipseIn: CGRect(
            x: w * 0.36, y: h * 0.20,
            width: w * 0.28, height: w * 0.32
        ))
        ctx.fill(head, with: .color(.black.opacity(0.5)))

        var shoulders = Path()
        shoulders.move(to: CGPoint(x: w * 0.20, y: h))
        shoulders.addQuadCurve(
            to: CGPoint(x: w * 0.80, y: h),
            control: CGPoint(x: w * 0.5, y: h * 0.55)
        )
        shoulders.addLine(to: CGPoint(x: w * 0.20, y: h))
        ctx.fill(shoulders, with: .color(.black.opacity(0.5)))

        // 후광 (rim light)
        let halo = Path(ellipseIn: CGRect(
            x: w * 0.28, y: h * 0.10,
            width: w * 0.44, height: w * 0.50
        ))
        ctx.stroke(halo, with: .color(Color(hex: 0xF8DCAF).opacity(0.6)), lineWidth: 6)
    }

    private func drawFood(ctx: GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height
        // 그릇 (위에서 본 원형)
        let bowl = Path(ellipseIn: CGRect(
            x: w * 0.20, y: h * 0.40,
            width: w * 0.60, height: w * 0.60
        ))
        ctx.fill(bowl, with: .color(Color(hex: 0xF1D29A).opacity(0.55)))
        ctx.stroke(bowl, with: .color(.white.opacity(0.32)), lineWidth: 2)

        // 토핑 점들
        for i in 0..<5 {
            let angle = Double(i) * .pi * 2 / 5
            let cx = w * 0.5 + cos(angle) * w * 0.18
            let cy = h * 0.7 + sin(angle) * w * 0.18
            let dot = Path(ellipseIn: CGRect(
                x: cx - 6, y: cy - 6,
                width: 12, height: 12
            ))
            ctx.fill(dot, with: .color(Color(hex: 0xC15B2A).opacity(0.7)))
        }
    }

    private func drawTravel(ctx: GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height
        // 산 라인
        var mountain = Path()
        mountain.move(to: CGPoint(x: 0, y: h * 0.78))
        mountain.addLine(to: CGPoint(x: w * 0.18, y: h * 0.50))
        mountain.addLine(to: CGPoint(x: w * 0.30, y: h * 0.65))
        mountain.addLine(to: CGPoint(x: w * 0.50, y: h * 0.42))
        mountain.addLine(to: CGPoint(x: w * 0.62, y: h * 0.55))
        mountain.addLine(to: CGPoint(x: w * 0.84, y: h * 0.36))
        mountain.addLine(to: CGPoint(x: w, y: h * 0.50))
        mountain.addLine(to: CGPoint(x: w, y: h))
        mountain.addLine(to: CGPoint(x: 0, y: h))
        mountain.closeSubpath()
        ctx.fill(mountain, with: .color(.black.opacity(0.40)))

        // 해
        let sun = Path(ellipseIn: CGRect(
            x: w * 0.66, y: h * 0.20,
            width: w * 0.20, height: w * 0.20
        ))
        ctx.fill(sun, with: .color(Color(hex: 0xF8E0A0).opacity(0.85)))
    }

    private func drawMood(ctx: GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height
        // 물결
        for i in 0..<3 {
            var wave = Path()
            let baseY = h * (0.55 + CGFloat(i) * 0.12)
            let amplitude = h * 0.04
            wave.move(to: CGPoint(x: 0, y: baseY))
            for x in stride(from: 0, through: w, by: 4) {
                let y = baseY + sin(Double(x) * .pi * 2 / Double(w / 1.5)) * amplitude
                wave.addLine(to: CGPoint(x: x, y: y))
            }
            ctx.stroke(
                wave,
                with: .color(.white.opacity(0.18 - Double(i) * 0.04)),
                style: StrokeStyle(lineWidth: 2, lineCap: .round)
            )
        }
    }
}

// MARK: - Filter ID -> Motif resolution

public enum FilterCoverMotifResolver {
    /// 시드 필터 title 또는 category 기반 모티프 결정.
    public static func motif(for title: String, category: String?) -> FMFilterCoverArt.Motif {
        let t = title.lowercased()
        if t.contains("sunset") || t.contains("golden") { return .vintage }
        if t.contains("portra") || t.contains("skin") { return .portrait }
        if t.contains("seoul") || t.contains("night") || t.contains("midnight") || t.contains("indigo") { return .mood }
        if t.contains("cafe") || t.contains("cream") || t.contains("honey") { return .food }
        if t.contains("airy") || t.contains("trip") || t.contains("blue") || t.contains("mountain") { return .travel }
        if t.contains("pastel") || t.contains("mint") { return .pastel }
        if t.contains("mono") || t.contains("bw") || t.contains("b&w") { return .monochrome }
        return motif(forCategory: category ?? "")
    }

    private static func motif(forCategory category: String) -> FMFilterCoverArt.Motif {
        switch category.lowercased() {
        case "cinematic": .cinematic
        case "vintage": .vintage
        case "pastel", "bright", "anime": .pastel
        case "monochrome", "mono", "bw", "b&w": .monochrome
        case "portrait", "skin": .portrait
        case "food": .food
        case "travel": .travel
        case "mood", "moody": .mood
        default: .cinematic
        }
    }
}

// MARK: - Preview

#Preview("FMFilterCoverArt — All motifs") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: Sp.sm), GridItem(.flexible(), spacing: Sp.sm)], spacing: Sp.sm) {
            ForEach(["cinematic", "vintage", "pastel", "monochrome", "portrait", "food", "travel", "mood"], id: \.self) { name in
                VStack(alignment: .leading, spacing: Sp.xs) {
                    FMFilterCoverArt(motif: motif(named: name))
                        .aspectRatio(4.0 / 5.0, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: R.lg))
                    Text(name)
                        .fmTypography(.subhead)
                        .foregroundStyle(FMColors.Text.secondary)
                }
            }
        }
        .padding(Sp.md)
    }
    .background(FMColors.Background.bg1)
}

private func motif(named name: String) -> FMFilterCoverArt.Motif {
    FMFilterCoverArt.Motif(rawValue: name) ?? .cinematic
}
