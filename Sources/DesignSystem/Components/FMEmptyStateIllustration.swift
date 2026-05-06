import SwiftUI

// MARK: - FMEmptyStateIllustration

/// `EMPTY_STATES.md` 기반 5종 빈 상태 일러스트.
///
/// SF Symbol 한 개로 표현하던 placeholder 를 SwiftUI Path/Canvas 로 그린 procedural illustration 으로 교체.
/// 모든 일러스트는 `accent.bg` 둥근 배경 + `accent` 라인 / fill 로 라이트 모드 톤 유지.
public struct FMEmptyStateIllustration: View {
    public enum Kind {
        case market
        case search
        case profile
        case downloads
        case comments
    }

    public let kind: Kind
    public let size: CGFloat

    public init(_ kind: Kind, size: CGFloat = 96) {
        self.kind = kind
        self.size = size
    }

    public var body: some View {
        ZStack {
            Circle()
                .fill(FMColors.Accent.bg)

            content
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        switch kind {
        case .market:
            MarketIllustration(stroke: FMColors.Accent.primary)
                .frame(width: size * 0.6, height: size * 0.6)
        case .search:
            SearchIllustration(stroke: FMColors.Accent.primary)
                .frame(width: size * 0.62, height: size * 0.62)
        case .profile:
            ProfileIllustration(stroke: FMColors.Accent.primary)
                .frame(width: size * 0.6, height: size * 0.6)
        case .downloads:
            DownloadsIllustration(stroke: FMColors.Accent.primary)
                .frame(width: size * 0.6, height: size * 0.6)
        case .comments:
            CommentsIllustration(stroke: FMColors.Accent.primary)
                .frame(width: size * 0.62, height: size * 0.62)
        }
    }
}

// MARK: - Market — 카메라 본체 + 셔터 + 별표 (첫 메이커 강조)

private struct MarketIllustration: View {
    let stroke: Color
    var body: some View {
        ZStack {
            Canvas { ctx, size in
                let w = size.width
                let h = size.height
                let camRect = CGRect(x: w * 0.08, y: h * 0.28, width: w * 0.84, height: h * 0.55)

                let body = Path(roundedRect: camRect, cornerRadius: w * 0.10)
                ctx.stroke(body, with: .color(stroke), lineWidth: 2)

                let lensCenter = CGPoint(x: camRect.midX, y: camRect.midY + h * 0.04)
                let lensOuter = Path(ellipseIn: CGRect(
                    x: lensCenter.x - w * 0.18,
                    y: lensCenter.y - w * 0.18,
                    width: w * 0.36,
                    height: w * 0.36
                ))
                ctx.stroke(lensOuter, with: .color(stroke), lineWidth: 2)

                let lensInner = Path(ellipseIn: CGRect(
                    x: lensCenter.x - w * 0.10,
                    y: lensCenter.y - w * 0.10,
                    width: w * 0.20,
                    height: w * 0.20
                ))
                ctx.fill(lensInner, with: .color(stroke.opacity(0.18)))

                var view = Path()
                view.addRoundedRect(
                    in: CGRect(x: w * 0.32, y: h * 0.18, width: w * 0.36, height: h * 0.12),
                    cornerSize: CGSize(width: 4, height: 4)
                )
                ctx.stroke(view, with: .color(stroke), lineWidth: 2)
            }

            // 별표 (첫 메이커 격려)
            StarMark(stroke: stroke)
                .frame(width: 18, height: 18)
                .offset(x: -28, y: -22)
        }
    }
}

private struct StarMark: View {
    let stroke: Color
    var body: some View {
        Canvas { ctx, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            var path = Path()
            for i in 0..<10 {
                let angle = Double(i) * .pi / 5 - .pi / 2
                let radius = i.isMultiple(of: 2) ? size.width / 2 : size.width / 5
                let pt = CGPoint(
                    x: center.x + cos(angle) * radius,
                    y: center.y + sin(angle) * radius
                )
                if i == 0 {
                    path.move(to: pt)
                } else {
                    path.addLine(to: pt)
                }
            }
            path.closeSubpath()
            ctx.fill(path, with: .color(stroke))
        }
    }
}

// MARK: - Search — 돋보기 + ? 기호

private struct SearchIllustration: View {
    let stroke: Color
    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height
            let lensCenter = CGPoint(x: w * 0.42, y: h * 0.42)
            let lensRadius = w * 0.30

            let circle = Path(ellipseIn: CGRect(
                x: lensCenter.x - lensRadius,
                y: lensCenter.y - lensRadius,
                width: lensRadius * 2,
                height: lensRadius * 2
            ))
            ctx.stroke(circle, with: .color(stroke), lineWidth: 2.5)

            // 손잡이
            var handle = Path()
            handle.move(to: CGPoint(x: lensCenter.x + lensRadius * 0.7, y: lensCenter.y + lensRadius * 0.7))
            handle.addLine(to: CGPoint(x: w * 0.92, y: h * 0.92))
            ctx.stroke(
                handle,
                with: .color(stroke),
                style: StrokeStyle(lineWidth: 3, lineCap: .round)
            )

            // ? 기호 (렌즈 안)
            var question = Path()
            let qx = lensCenter.x
            let qy = lensCenter.y
            let qSize = w * 0.10
            question.addArc(
                center: CGPoint(x: qx, y: qy - qSize * 0.3),
                radius: qSize * 0.45,
                startAngle: .degrees(180),
                endAngle: .degrees(45),
                clockwise: false
            )
            question.addLine(to: CGPoint(x: qx, y: qy + qSize * 0.2))
            ctx.stroke(
                question,
                with: .color(stroke),
                style: StrokeStyle(lineWidth: 2, lineCap: .round)
            )
            // 점
            let dot = Path(ellipseIn: CGRect(
                x: qx - 1.5,
                y: qy + qSize * 0.5,
                width: 3,
                height: 3
            ))
            ctx.fill(dot, with: .color(stroke))
        }
    }
}

// MARK: - Profile — 사람 실루엣 + 빈 카드 placeholder

private struct ProfileIllustration: View {
    let stroke: Color
    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height

            // 머리
            let head = Path(ellipseIn: CGRect(
                x: w * 0.36,
                y: h * 0.10,
                width: w * 0.28,
                height: w * 0.28
            ))
            ctx.stroke(head, with: .color(stroke), lineWidth: 2.5)

            // 어깨
            var shoulders = Path()
            shoulders.addArc(
                center: CGPoint(x: w * 0.5, y: h * 0.78),
                radius: w * 0.32,
                startAngle: .degrees(200),
                endAngle: .degrees(340),
                clockwise: false
            )
            ctx.stroke(
                shoulders,
                with: .color(stroke),
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
            )

            // 빈 사각 placeholder (필터 슬롯 비어있음)
            for index in 0..<3 {
                let x = w * 0.20 + CGFloat(index) * w * 0.22
                let rect = CGRect(x: x, y: h * 0.85, width: w * 0.14, height: w * 0.06)
                let path = Path(roundedRect: rect, cornerRadius: 2)
                ctx.stroke(
                    path,
                    with: .color(stroke.opacity(0.45)),
                    style: StrokeStyle(lineWidth: 1.5, dash: [3, 2])
                )
            }
        }
    }
}

// MARK: - Downloads — 빈 트레이 + 다운로드 화살표

private struct DownloadsIllustration: View {
    let stroke: Color
    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height

            // 트레이 (빈 폴더)
            var tray = Path()
            tray.move(to: CGPoint(x: w * 0.10, y: h * 0.55))
            tray.addLine(to: CGPoint(x: w * 0.10, y: h * 0.85))
            tray.addLine(to: CGPoint(x: w * 0.90, y: h * 0.85))
            tray.addLine(to: CGPoint(x: w * 0.90, y: h * 0.55))
            ctx.stroke(
                tray,
                with: .color(stroke),
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
            )

            // 다운로드 화살표
            var arrow = Path()
            arrow.move(to: CGPoint(x: w * 0.5, y: h * 0.10))
            arrow.addLine(to: CGPoint(x: w * 0.5, y: h * 0.55))
            arrow.move(to: CGPoint(x: w * 0.32, y: h * 0.40))
            arrow.addLine(to: CGPoint(x: w * 0.5, y: h * 0.58))
            arrow.addLine(to: CGPoint(x: w * 0.68, y: h * 0.40))
            ctx.stroke(
                arrow,
                with: .color(stroke),
                style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
            )
        }
    }
}

// MARK: - Comments — 말풍선 2개 (대화)

private struct CommentsIllustration: View {
    let stroke: Color
    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height

            // 첫 번째 말풍선 (큰 것, 좌상단)
            var bubble1 = Path(roundedRect: CGRect(
                x: w * 0.06,
                y: h * 0.10,
                width: w * 0.62,
                height: h * 0.42
            ), cornerRadius: w * 0.08)
            // 꼬리
            bubble1.move(to: CGPoint(x: w * 0.18, y: h * 0.52))
            bubble1.addLine(to: CGPoint(x: w * 0.14, y: h * 0.62))
            bubble1.addLine(to: CGPoint(x: w * 0.26, y: h * 0.52))
            ctx.stroke(
                bubble1,
                with: .color(stroke),
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
            )

            // 점 3개 (typing)
            for i in 0..<3 {
                let dot = Path(ellipseIn: CGRect(
                    x: w * (0.20 + CGFloat(i) * 0.10),
                    y: h * 0.28,
                    width: 5,
                    height: 5
                ))
                ctx.fill(dot, with: .color(stroke.opacity(0.6)))
            }

            // 두 번째 말풍선 (작은 것, 우하단)
            var bubble2 = Path(roundedRect: CGRect(
                x: w * 0.40,
                y: h * 0.55,
                width: w * 0.52,
                height: h * 0.34
            ), cornerRadius: w * 0.06)
            // 꼬리 (반대 방향)
            bubble2.move(to: CGPoint(x: w * 0.78, y: h * 0.89))
            bubble2.addLine(to: CGPoint(x: w * 0.84, y: h * 0.97))
            bubble2.addLine(to: CGPoint(x: w * 0.70, y: h * 0.89))
            ctx.stroke(
                bubble2,
                with: .color(stroke.opacity(0.65)),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )
        }
    }
}

// MARK: - Preview

#Preview("FMEmptyStateIllustration") {
    ScrollView {
        VStack(spacing: Sp.lg) {
            row("market", .market)
            row("search", .search)
            row("profile", .profile)
            row("downloads", .downloads)
            row("comments", .comments)
        }
        .padding(Sp.xl)
    }
    .background(FMColors.Background.bg1)
}

@MainActor
private func row(_ title: String, _ kind: FMEmptyStateIllustration.Kind) -> some View {
    HStack(spacing: Sp.lg) {
        FMEmptyStateIllustration(kind, size: 96)
        Text(title)
            .fmTypography(.headline)
            .foregroundStyle(FMColors.Text.primary)
        Spacer()
    }
}

#Preview("FMEmptyStateIllustration — Dark") {
    ScrollView {
        VStack(spacing: Sp.lg) {
            row("market", .market)
            row("search", .search)
            row("profile", .profile)
            row("downloads", .downloads)
            row("comments", .comments)
        }
        .padding(Sp.xl)
    }
    .background(FMColors.Background.bg1)
    .preferredColorScheme(.dark)
}
