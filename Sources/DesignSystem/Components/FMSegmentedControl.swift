import SwiftUI

// MARK: - FMSegmentedControl

/// iOS 스타일 + 골드 강조의 세그먼트 컨트롤.
///
/// `DESIGN_SYSTEM.md` §8.13 — `bg/3` 컨테이너, 흰 fill 활성, soft shadow.
public struct FMSegmentedControl<Option: Hashable>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding private var selection: Option
    private let options: [Option]
    private let title: (Option) -> String

    @Namespace private var animation

    public init(
        selection: Binding<Option>,
        options: [Option],
        title: @escaping (Option) -> String
    ) {
        self._selection = selection
        self.options = options
        self.title = title
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                let isActive = option == selection
                Button {
                    withAnimation(.fmSpringTap.reducedIfNeeded(reduceMotion)) {
                        selection = option
                    }
                } label: {
                    Text(title(option))
                        .fmTypography(.subhead)
                        .foregroundStyle(isActive ? FMColors.Text.primary : FMColors.Text.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Sp.xs)
                        .contentShape(Rectangle())
                        .background {
                            if isActive {
                                RoundedRectangle(cornerRadius: R.md - 2)
                                    .fill(FMColors.Background.bg2)
                                    .shadow(color: Color.black.opacity(0.06), radius: 2, x: 0, y: 1)
                                    .matchedGeometryEffect(id: "segment", in: animation)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(title(option))
                .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(2)
        .background(FMColors.Background.bg3, in: RoundedRectangle(cornerRadius: R.md))
    }
}

// MARK: - String convenience

public extension FMSegmentedControl where Option == String {
    init(selection: Binding<String>, options: [String]) {
        self.init(selection: selection, options: options) { $0 }
    }
}

// MARK: - Preview

private struct FMSegmentedControlPreview: View {
    enum SortKey: String, CaseIterable {
        case all = "전체"
        case photos = "사진"
        case videos = "비디오"
    }

    @State private var sort: SortKey = .all
    @State private var period: String = "이번 주"

    var body: some View {
        VStack(spacing: Sp.lg) {
            FMSegmentedControl(
                selection: $sort,
                options: SortKey.allCases,
                title: \.rawValue
            )

            FMSegmentedControl(
                selection: $period,
                options: ["오늘", "이번 주", "이번 달", "전체"]
            )
        }
        .padding(Sp.md)
    }
}

#Preview("FMSegmentedControl — Light") {
    FMSegmentedControlPreview()
        .background(FMColors.Background.bg1)
}

#Preview("FMSegmentedControl — Dark") {
    FMSegmentedControlPreview()
        .background(FMColors.Background.bg1)
        .preferredColorScheme(.dark)
}
