import SwiftUI
import UIKit

// MARK: - FMSlider

/// 디자인 시스템 표준 슬라이더 — 강도(0~100%) 조절용.
///
/// 골드 트랙 + 흰 썸 + soft shadow.
/// `DESIGN_SYSTEM.md` §8.11 Slider 스펙과 정합.
public struct FMSlider: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding private var value: Double
    private let range: ClosedRange<Double>
    private let label: String?
    private let showValue: Bool
    private let valueFormatter: (Double) -> String

    @State private var isDragging = false
    @State private var isPrecisionMode = false
    @State private var dragStartValue: Double?
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
            let progress = normalizedProgress(value)
            let thumbX = usable * progress
            let zeroX = usable * normalizedProgress(0)
            let canResetToZero = range.contains(0)

            ZStack(alignment: .leading) {
                // 트랙 배경
                Capsule()
                    .fill(FMColors.Background.bg3)
                    .frame(height: 4)

                // 채움
                Capsule()
                    .fill(FMColors.Accent.primary)
                    .frame(width: thumbX + thumbSize / 2, height: 4)

                if canResetToZero {
                    VStack(spacing: 3) {
                        Capsule()
                            .fill(FMColors.Border.strong)
                            .frame(width: 2, height: 12)
                        Text("원본")
                            .fmTypography(.caption)
                            .foregroundStyle(FMColors.Text.tertiary)
                    }
                    .offset(x: zeroX + thumbSize / 2 - 13, y: 14)
                    .accessibilityHidden(true)
                }

                if isDragging || isPrecisionMode {
                    Text(floatingValueLabel)
                        .font(.system(size: 11, weight: .bold).monospacedDigit())
                        .foregroundStyle(FMColors.Text.primary)
                        .padding(.horizontal, Sp.xs)
                        .padding(.vertical, 5)
                        .background(FMColors.Background.bg2, in: Capsule())
                        .overlay {
                            Capsule().strokeBorder(FMColors.Border.subtle, lineWidth: 1)
                        }
                        .offset(x: min(max(thumbX - 28, 0), max(0, geo.size.width - 72)), y: -32)
                        .accessibilityHidden(true)
                }

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
                    .animation(.fmFast.reducedIfNeeded(reduceMotion), value: isDragging)
            }
            .contentShape(Rectangle())
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.35)
                    .onEnded { _ in
                        isPrecisionMode.toggle()
                        FMHaptic.medium.play()
                    }
            )
            .simultaneousGesture(
                TapGesture(count: 2)
                    .onEnded {
                        guard canResetToZero else { return }
                        value = 0
                        isPrecisionMode = false
                        FMHaptic.medium.play()
                    }
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        isDragging = true
                        let raw = max(0, min(1, drag.location.x / max(1, geo.size.width)))
                        if dragStartValue == nil {
                            dragStartValue = value
                        }
                        let newValue: Double
                        if isPrecisionMode, let dragStartValue {
                            let delta = Double(drag.translation.width / max(1, geo.size.width))
                            newValue = dragStartValue + delta * rangeLength * 0.25
                        } else {
                            newValue = range.lowerBound + raw * rangeLength
                        }
                        value = snappedIfNeeded(clamp(newValue))
                        triggerHapticIfNeeded(progress: normalizedProgress(value))
                    }
                    .onEnded { _ in
                        if canResetToZero, shouldSnapToZero(value) {
                            value = 0
                            FMHaptic.medium.play()
                        }
                        isDragging = false
                        dragStartValue = nil
                        lastHapticAnchor = nil
                    }
            )
        }
        .frame(height: 52)
    }

    @MainActor
    private func triggerHapticIfNeeded(progress: Double) {
        let anchor = Int((progress * 20).rounded())
        if anchor != lastHapticAnchor {
            FMHaptic.selection.play()
            lastHapticAnchor = anchor
        }
    }

    private var rangeLength: Double {
        range.upperBound - range.lowerBound
    }

    private var zeroSnapThreshold: Double {
        rangeLength * 0.025
    }

    private var floatingValueLabel: String {
        let valueLabel = range.contains(0) && shouldSnapToZero(value) ? "원본" : valueFormatter(value)
        return isPrecisionMode ? "\(valueLabel) · 정밀" : valueLabel
    }

    private func normalizedProgress(_ value: Double) -> Double {
        guard rangeLength > 0 else { return 0 }
        return max(0, min(1, (value - range.lowerBound) / rangeLength))
    }

    private func clamp(_ value: Double) -> Double {
        min(range.upperBound, max(range.lowerBound, value))
    }

    private func snappedIfNeeded(_ value: Double) -> Double {
        range.contains(0) && shouldSnapToZero(value) ? 0 : value
    }

    private func shouldSnapToZero(_ value: Double) -> Bool {
        abs(value) <= zeroSnapThreshold
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
