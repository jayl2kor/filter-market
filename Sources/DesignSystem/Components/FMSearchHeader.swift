import SwiftUI

// MARK: - FMSearchHeader

/// 마켓 / 발견 화면 공통 검색 헤더 입력 영역.
///
/// 두 가지 모드를 지원한다.
/// - Display: `text` 미지정. 자체적으로 인터랙션을 갖지 않으며,
///   부모가 `NavigationLink` 혹은 `Button` 으로 감싸 검색 화면으로 이동시킨다.
/// - Input: `text` 바인딩 지정. 실제 입력이 가능한 검색 필드로 동작하며,
///   `onSubmit` 으로 검색 제출을 받는다.
///
/// 시각적으로는 마켓 헤더 스타일(라운드 + bg2 + 1px border + 좌측 magnifyingglass)을
/// 따르고, placeholder 글자색은 발견 화면의 톤(secondary)을 사용해 두 화면이 동일하게 보이도록 한다.
public struct FMSearchHeader: View {
    private let placeholder: String
    private let text: Binding<String>?
    private let onSubmit: (() -> Void)?

    /// Display variant — 부모가 `NavigationLink` 등으로 감싸서 사용.
    public init(placeholder: String) {
        self.placeholder = placeholder
        self.text = nil
        self.onSubmit = nil
    }

    /// Input variant — 실제 검색어 입력.
    public init(
        placeholder: String,
        text: Binding<String>,
        onSubmit: @escaping () -> Void = {}
    ) {
        self.placeholder = placeholder
        self.text = text
        self.onSubmit = onSubmit
    }

    public var body: some View {
        HStack(spacing: Sp.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: IconSize.sm, weight: .medium))
                .foregroundStyle(FMColors.Text.tertiary)

            if let text {
                editableField(text: text)
            } else {
                Text(placeholder)
                    .fmTypography(.body)
                    .foregroundStyle(FMColors.Text.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, Sp.sm)
        .frame(height: 44)
        .frame(maxWidth: .infinity)
        .background(FMColors.Background.bg2, in: RoundedRectangle(cornerRadius: R.md))
        .overlay {
            RoundedRectangle(cornerRadius: R.md)
                .strokeBorder(FMColors.Border.default, lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: R.md))
    }

    @ViewBuilder
    private func editableField(text: Binding<String>) -> some View {
        ZStack(alignment: .leading) {
            if text.wrappedValue.isEmpty {
                Text(placeholder)
                    .fmTypography(.body)
                    .foregroundStyle(FMColors.Text.secondary)
                    .lineLimit(1)
                    .allowsHitTesting(false)
            }
            TextField("", text: text)
                .fmTypography(.body)
                .foregroundStyle(FMColors.Text.primary)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.sentences)
                .onSubmit { onSubmit?() }
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        if !text.wrappedValue.isEmpty {
            Button {
                text.wrappedValue = ""
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(FMColors.Text.tertiary)
            }
            .accessibilityLabel("검색어 지우기")
        }
    }
}

// MARK: - Preview

#Preview("FMSearchHeader — Light") {
    FMSearchHeaderPreview()
}

#Preview("FMSearchHeader — Dark") {
    FMSearchHeaderPreview()
        .preferredColorScheme(.dark)
}

private struct FMSearchHeaderPreview: View {
    @State private var query = ""

    var body: some View {
        VStack(spacing: Sp.lg) {
            FMSearchHeader(placeholder: "필터, 메이커, 분위기 검색")

            FMSearchHeader(
                placeholder: "필터, 메이커, 분위기 검색",
                text: $query
            )
        }
        .padding(Sp.md)
        .background(FMColors.Background.bg0)
    }
}
