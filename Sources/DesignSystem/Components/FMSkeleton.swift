import SwiftUI

// MARK: - FMSkeleton

/// 시머 애니메이션이 적용된 스켈레톤 placeholder.
///
/// `MOTION_SPEC.md` §5 — 1.5s 사이클, 5도 기울기, 30% 폭 하이라이트.
/// Reduce Motion 시 정적 회색 채움.
public struct FMSkeleton: View {
    public enum Shape: Sendable {
        case line(width: CGFloat?, height: CGFloat)
        case rect(width: CGFloat?, height: CGFloat, cornerRadius: CGFloat)
        case circle(diameter: CGFloat)
    }

    private let shape: Shape

    public init(shape: Shape) {
        self.shape = shape
    }

    // MARK: - Convenience

    public static func line(width: CGFloat? = nil, height: CGFloat = 14) -> FMSkeleton {
        FMSkeleton(shape: .line(width: width, height: height))
    }

    public static func rect(
        width: CGFloat? = nil,
        height: CGFloat,
        cornerRadius: CGFloat = R.md
    ) -> FMSkeleton {
        FMSkeleton(shape: .rect(width: width, height: height, cornerRadius: cornerRadius))
    }

    public static func circle(diameter: CGFloat) -> FMSkeleton {
        FMSkeleton(shape: .circle(diameter: diameter))
    }

    public var body: some View {
        baseShape
            .frame(width: explicitWidth, height: explicitHeight)
            .frame(maxWidth: explicitWidth == nil ? .infinity : nil)
            .modifier(ShimmerModifier())
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var baseShape: some View {
        switch shape {
        case .line(_, let height):
            RoundedRectangle(cornerRadius: height / 2)
                .fill(FMColors.Skeleton.base)
        case .rect(_, _, let cornerRadius):
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(FMColors.Skeleton.base)
        case .circle:
            Circle()
                .fill(FMColors.Skeleton.base)
        }
    }

    private var explicitWidth: CGFloat? {
        switch shape {
        case .line(let width, _): width
        case .rect(let width, _, _): width
        case .circle(let diameter): diameter
        }
    }

    private var explicitHeight: CGFloat? {
        switch shape {
        case .line(_, let height): height
        case .rect(_, let height, _): height
        case .circle(let diameter): diameter
        }
    }
}

// MARK: - Shimmer modifier

private struct ShimmerModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1.0

    func body(content: Content) -> some View {
        if reduceMotion {
            // Reduce Motion: 정적 회색 채움
            content
        } else {
            content
                .overlay {
                    GeometryReader { geo in
                        let width = geo.size.width
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: FMColors.Skeleton.highlight.opacity(0.7), location: 0.5),
                                .init(color: .clear, location: 1.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: width * 0.4)
                        .offset(x: phase * width)
                        .rotationEffect(.degrees(5), anchor: .center)
                    }
                }
                .clipped()
                .onAppear {
                    withAnimation(
                        .linear(duration: FMMotion.Shimmer.duration)
                            .repeatForever(autoreverses: false)
                    ) {
                        phase = 1.5
                    }
                }
        }
    }
}

// MARK: - Preview

#Preview("FMSkeleton — variants") {
    ScrollView {
        VStack(alignment: .leading, spacing: Sp.lg) {
            Text("Lines").fmTypography(.headline)
            VStack(alignment: .leading, spacing: Sp.xs) {
                FMSkeleton.line(width: 200, height: 18)
                FMSkeleton.line(height: 14)
                FMSkeleton.line(width: 140, height: 12)
            }

            Text("Rects").fmTypography(.headline)
            HStack(spacing: Sp.sm) {
                FMSkeleton.rect(width: 120, height: 80, cornerRadius: R.lg)
                FMSkeleton.rect(width: 120, height: 80, cornerRadius: R.lg)
            }

            Text("Circles & Card").fmTypography(.headline)
            HStack(spacing: Sp.sm) {
                FMSkeleton.circle(diameter: 48)
                VStack(alignment: .leading, spacing: Sp.xs) {
                    FMSkeleton.line(width: 140, height: 14)
                    FMSkeleton.line(width: 80, height: 12)
                }
            }
            .fmCard()
        }
        .padding(Sp.md)
    }
    .background(FMColors.Background.bg1)
}

#Preview("FMSkeleton — Dark") {
    VStack(spacing: Sp.sm) {
        FMSkeleton.rect(height: 120, cornerRadius: R.lg)
        FMSkeleton.line(width: 200, height: 14)
    }
    .padding(Sp.md)
    .background(FMColors.Background.bg1)
    .preferredColorScheme(.dark)
}
