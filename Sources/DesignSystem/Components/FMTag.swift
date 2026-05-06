import SwiftUI

// MARK: - FMTag

/// 작은 라벨 — 트렌딩 키워드, 메타 정보 표시.
/// 비인터랙티브 디스플레이용.
public struct FMTag: View {
    public enum Style: Sendable {
        case `default`
        case accent
        case outlined
    }

    public enum Size: Sendable {
        case sm
        case md
    }

    private let text: String
    private let icon: String?
    private let style: Style
    private let size: Size

    public init(
        _ text: String,
        icon: String? = nil,
        style: Style = .default,
        size: Size = .sm
    ) {
        self.text = text
        self.icon = icon
        self.style = style
        self.size = size
    }

    public var body: some View {
        HStack(spacing: Sp.xxs) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: typography.size - 1, weight: .medium))
            }
            Text(text)
                .fmTypography(typography)
                .lineLimit(1)
        }
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: R.sm))
        .overlay {
            if case .outlined = style {
                RoundedRectangle(cornerRadius: R.sm)
                    .strokeBorder(FMColors.Border.default, lineWidth: 1)
            }
        }
    }

    private var typography: FMTypography.Style {
        size == .sm ? FMTypography.caption : FMTypography.subhead
    }

    private var horizontalPadding: CGFloat {
        size == .sm ? Sp.xs : Sp.sm
    }

    private var verticalPadding: CGFloat {
        size == .sm ? 2 : Sp.xxs
    }

    private var foregroundColor: Color {
        switch style {
        case .default: FMColors.Text.secondary
        case .accent: FMColors.Accent.primary
        case .outlined: FMColors.Text.primary
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .default: FMColors.Background.bg3
        case .accent: FMColors.Accent.bg
        case .outlined: .clear
        }
    }
}

// MARK: - FMChip

/// 인터랙티브 칩 — 카테고리 토글, 선택 인터랙션.
/// `DESIGN_SYSTEM.md` §8.10 Tag/Chip 스펙과 정합.
public struct FMChip: View {
    public enum Size: Sendable {
        case sm
        case md
    }

    private let text: String
    private let icon: String?
    private let isSelected: Bool
    private let size: Size
    private let action: () -> Void

    public init(
        _ text: String,
        icon: String? = nil,
        isSelected: Bool = false,
        size: Size = .md,
        action: @escaping () -> Void
    ) {
        self.text = text
        self.icon = icon
        self.isSelected = isSelected
        self.size = size
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Sp.xxs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: typography.size, weight: .medium))
                }
                Text(text)
                    .fmTypography(typography)
                    .lineLimit(1)
            }
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, horizontalPadding)
            .frame(height: height)
            .background(backgroundColor, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(borderColor, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(text)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var typography: FMTypography.Style {
        size == .sm ? FMTypography.subhead : FMTypography.callout
    }

    private var height: CGFloat {
        size == .sm ? 28 : 36
    }

    private var horizontalPadding: CGFloat {
        size == .sm ? Sp.sm : Sp.md
    }

    private var foregroundColor: Color {
        isSelected ? FMColors.Accent.primary : FMColors.Text.secondary
    }

    private var backgroundColor: Color {
        isSelected ? FMColors.Accent.bg : FMColors.Background.bg2
    }

    private var borderColor: Color {
        isSelected ? FMColors.Accent.primary : FMColors.Border.default
    }
}

// MARK: - Preview

#Preview("FMTag — variants") {
    ScrollView {
        VStack(alignment: .leading, spacing: Sp.md) {
            Text("Tags").fmTypography(.headline)
            HStack(spacing: Sp.xs) {
                FMTag("#필름")
                FMTag("Cinematic", style: .accent)
                FMTag("KR", icon: "globe", style: .outlined)
            }

            Text("Sizes").fmTypography(.headline)
            HStack(spacing: Sp.xs) {
                FMTag("작은", size: .sm)
                FMTag("기본", size: .md)
            }
        }
        .padding(Sp.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .background(FMColors.Background.bg1)
}

#Preview("FMChip — interactive") {
    @Previewable @State var selected: Set<String> = ["Cinematic"]
    let categories = ["전체", "Cinematic", "Vintage", "Pastel", "B&W", "Portrait"]

    ScrollView {
        VStack(alignment: .leading, spacing: Sp.md) {
            Text("카테고리 (단일 선택)").fmTypography(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Sp.xs) {
                    ForEach(categories, id: \.self) { cat in
                        FMChip(
                            cat,
                            isSelected: selected.contains(cat)
                        ) {
                            selected = [cat]
                        }
                    }
                }
            }

            Text("아이콘 칩").fmTypography(.headline)
            HStack(spacing: Sp.xs) {
                FMChip("좋아요", icon: "heart", isSelected: false) {}
                FMChip("저장됨", icon: "bookmark.fill", isSelected: true) {}
            }
        }
        .padding(Sp.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .background(FMColors.Background.bg1)
}

#Preview("FMChip — Dark") {
    HStack(spacing: Sp.xs) {
        FMChip("선택됨", isSelected: true) {}
        FMChip("미선택") {}
    }
    .padding(Sp.md)
    .background(FMColors.Background.bg1)
    .preferredColorScheme(.dark)
}
