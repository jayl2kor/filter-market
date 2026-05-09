import SwiftUI

// MARK: - FMToggle

/// `DESIGN_SYSTEM.md` §8.12 Toggle / Switch.
///
/// 51×31 라운드 캡슐 + 27×27 흰색 노브 + soft shadow.
/// Off: `bg/3` + 1px subtle border. On: `accent`. 노브 슬라이드 200ms.
///
/// SwiftUI 기본 `Toggle()` 의 시각만 교체하고 라벨 영역은 그대로 사용.
public struct FMToggle<Label: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    @Binding private var isOn: Bool
    private let label: () -> Label

    public init(
        isOn: Binding<Bool>,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self._isOn = isOn
        self.label = label
    }

    public var body: some View {
        HStack {
            label()
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(isEnabled ? 1.0 : Opacity.textDisabled)

            switchControl
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard isEnabled else { return }
            FMHaptic.selection.play()
            withAnimation(.fmFast.reducedIfNeeded(reduceMotion)) {
                isOn.toggle()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
        .accessibilityValue(isOn ? "켜짐" : "꺼짐")
    }

    private var switchControl: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(isOn ? FMColors.Accent.primary : FMColors.Background.bg3)
                .frame(width: 51, height: 31)
                .overlay {
                    Capsule()
                        .strokeBorder(
                            isOn ? Color.clear : FMColors.Border.subtle,
                            lineWidth: 1
                        )
                }

            Circle()
                .fill(Color.white)
                .frame(width: 27, height: 27)
                .shadow(color: .black.opacity(0.16), radius: 2, x: 0, y: 1)
                .shadow(color: .black.opacity(0.04), radius: 1, x: 0, y: 0)
                .padding(2)
        }
        .frame(width: 51, height: 31)
        .opacity(isEnabled ? 1.0 : Opacity.fillDisabled)
    }
}

public extension FMToggle where Label == Text {
    /// 텍스트 라벨 단축 init. Text 변종 — 추가 modifier 가 필요하면 trailing closure init 사용.
    init(_ title: String, isOn: Binding<Bool>) {
        self.init(isOn: isOn) {
            Text(title)
                .font(.fmBody)
                .foregroundColor(FMColors.Text.primary)
        }
    }
}

// MARK: - Preview

private struct FMTogglePreview: View {
    @State private var notifications = true
    @State private var quietHours = false
    @State private var disabledOn = true

    var body: some View {
        VStack(alignment: .leading, spacing: Sp.lg) {
            FMToggle("푸시 알림", isOn: $notifications)

            FMToggle(isOn: $quietHours) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("방해 금지 시간")
                        .fmTypography(.body)
                        .foregroundStyle(FMColors.Text.primary)
                    Text("21:00 ~ 07:00 사이 알림 차단")
                        .fmTypography(.caption)
                        .foregroundStyle(FMColors.Text.secondary)
                }
            }

            FMToggle("비활성 (켜짐)", isOn: $disabledOn)
                .disabled(true)
        }
        .padding(Sp.lg)
        .frame(maxWidth: .infinity)
        .background(FMColors.Background.bg2, in: RoundedRectangle(cornerRadius: R.lg))
        .padding(Sp.md)
        .background(FMColors.Background.bg1)
    }
}

#Preview("FMToggle — Light") {
    FMTogglePreview()
}

#Preview("FMToggle — Dark") {
    FMTogglePreview()
        .preferredColorScheme(.dark)
}
