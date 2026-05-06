import SwiftUI
import UIKit

// MARK: - FMSlider

/// 디자인 시스템 표준 슬라이더 — 강도(0~100%) 조절용.
///
/// 골드 트랙 + 흰 썸 + soft shadow.
/// `DESIGN_SYSTEM.md` §8.11 Slider 스펙과 정합.
public struct FMSlider: View {
    @Binding private var value: Double
    private let range: ClosedRange<Double>
    private let label: String?
    private let showValue: Bool
    private let valueFormatter: (Double) -> String

    @State private var isDragging = false
    @State private var lastHapticAnchor: Int? = nil

    public init(
        value: Binding<Double>,
        range: ClosedRange<Double> = 0...1,
        label: String? = nil,
        showValue: Bool = true,
        valueFormatter: @escaping (Double) -> String = { value in
            "\(Int(value * 100))%"
        }
    ) {
        self._value = value
        self.range = range
        self.label = label
        self.showValue = showValue
        self.valueFormatter = valueFormatter
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Sp.xs) {
            if label != nil || showValue {
                HStack {
                    if let label {
                        Text(label)
                            .fmTypography(.subhead)
                            .foregroundStyle(FMColors.Text.secondary)
                    }
                    Spacer()
                    if showValue {
                        Text(valueFormatter(value))
                            .fmTypography(.caption)
                            .monospacedDigit()
                            .foregroundStyle(FMColors.Accent.primary)
                    }
                }
            }

            sliderTrack
        }
        .accessibilityElement()
        .accessibilityLabel(label ?? "슬라이더")
        .accessibilityValue(valueFormatter(value))
        .accessibilityAdjustableAction { direction in
            let step = (range.upperBound - range.lowerBound) * 0.05
            switch direction {
            case .increment:
                value = min(range.upperBound, value + step)
            case .decrement:
                value = max(range.lowerBound, value - step)
            @unknown default:
                break
            }
        }
    }

    private var sliderTrack: some View {
        GeometryReader { geo in
            let thumbSize: CGFloat = 20
            let usable = max(0, geo.size.width - thumbSize)
            let progress = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
            let thumbX = usable * progress

            ZStack(alignment: .leading) {
                // 트랙 배경
                Capsule()
                    .fill(FMColors.Background.bg3)
                    .frame(height: 4)

                // 채움
                Capsule()
                    .fill(FMColors.Accent.primary)
                    .frame(width: thumbX + thumbSize / 2, height: 4)

                // 썸
                Circle()
                    .fill(Color.white)
                    .frame(width: thumbSize, height: thumbSize)
                    .overlay {
                        Circle()
                            .strokeBorder(FMColors.Accent.primary, lineWidth: 2)
                    }
                    .shadow(
                        color: FMColors.Accent.primary.opacity(0.25),
                        radius: 4,
                        x: 0,
                        y: 1
                    )
                    .scaleEffect(isDragging ? 1.15 : 1.0)
                    .offset(x: thumbX)
                    .animation(.fmFast, value: isDragging)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        isDragging = true
                        let raw = max(0, min(1, drag.location.x / max(1, geo.size.width)))
                        let newValue = range.lowerBound + raw * (range.upperBound - range.lowerBound)
                        value = newValue
                        triggerHapticIfNeeded(progress: raw)
                    }
                    .onEnded { _ in
                        isDragging = false
                        lastHapticAnchor = nil
                    }
            )
        }
        .frame(height: 24)
    }

    @MainActor
    private func triggerHapticIfNeeded(progress: Double) {
        let anchor: Int? = switch progress {
        case 0..<0.02: 0
        case 0.48..<0.52: 50
        case 0.98...1.0: 100
        default: nil
        }
        if let anchor, anchor != lastHapticAnchor {
            UISelectionFeedbackGenerator().selectionChanged()
            lastHapticAnchor = anchor
        }
    }
}

// MARK: - Preview

private struct FMSliderPreview: View {
    @State private var intensity: Double = 0.65
    @State private var brightness: Double = 0.0

    var body: some View {
        VStack(alignment: .leading, spacing: Sp.xl) {
            FMSlider(value: $intensity, label: "강도")
            FMSlider(
                value: $brightness,
                range: -1...1,
                label: "밝기",
                valueFormatter: { String(format: "%+.2f", $0) }
            )
        }
        .padding(Sp.md)
    }
}

#Preview("FMSlider — Light") {
    FMSliderPreview()
        .background(FMColors.Background.bg1)
}

#Preview("FMSlider — Dark") {
    FMSliderPreview()
        .background(FMColors.Background.bg1)
        .preferredColorScheme(.dark)
}
