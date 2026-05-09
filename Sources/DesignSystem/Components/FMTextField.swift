import SwiftUI

// MARK: - FMTextField

/// 디자인 시스템 표준 입력 필드.
///
/// outlined: 흰 fill + 1px 보더, focus 시 골드 ring.
/// 라벨 + placeholder + helper text + error 메시지.
/// `DESIGN_SYSTEM.md` §8.2 TextField 스펙과 정합.
public struct FMTextField: View {
    public enum Style: Sendable {
        case plain
        case password
        case search
        case multiline(minHeight: CGFloat)
    }

    private let label: String?
    private let placeholder: String
    @Binding private var text: String
    private let helper: String?
    private let error: String?
    private let style: Style
    private let textContentType: UITextContentType?
    private let keyboardType: UIKeyboardType
    private let autocapitalization: TextInputAutocapitalization?
    private let submitLabel: SubmitLabel

    @FocusState private var isFocused: Bool
    @State private var isPasswordVisible = false

    public init(
        _ label: String? = nil,
        text: Binding<String>,
        placeholder: String = "",
        helper: String? = nil,
        error: String? = nil,
        style: Style = .plain,
        textContentType: UITextContentType? = nil,
        keyboardType: UIKeyboardType = .default,
        autocapitalization: TextInputAutocapitalization? = nil,
        submitLabel: SubmitLabel = .done
    ) {
        self.label = label
        self.placeholder = placeholder
        self._text = text
        self.helper = helper
        self.error = error
        self.style = style
        self.textContentType = textContentType
        self.keyboardType = keyboardType
        self.autocapitalization = autocapitalization
        self.submitLabel = submitLabel
    }

    // MARK: - Convenience

    public static func password(
        _ label: String? = nil,
        text: Binding<String>,
        placeholder: String = "",
        error: String? = nil
    ) -> FMTextField {
        FMTextField(
            label,
            text: text,
            placeholder: placeholder,
            error: error,
            style: .password,
            textContentType: .password,
            autocapitalization: .never,
            submitLabel: .go
        )
    }

    public static func search(
        text: Binding<String>,
        placeholder: String = "검색"
    ) -> FMTextField {
        FMTextField(
            text: text,
            placeholder: placeholder,
            style: .search,
            autocapitalization: .sentences,
            submitLabel: .search
        )
    }

    public static func handle(
        _ label: String? = "유저네임",
        text: Binding<String>,
        placeholder: String = "your.username",
        error: String? = nil
    ) -> FMTextField {
        FMTextField(
            label,
            text: text,
            placeholder: placeholder,
            error: error,
            textContentType: .nickname,
            keyboardType: .asciiCapable,
            autocapitalization: .never,
            submitLabel: .done
        )
    }

    public static func url(
        _ label: String? = "링크",
        text: Binding<String>,
        placeholder: String = "https://"
    ) -> FMTextField {
        FMTextField(
            label,
            text: text,
            placeholder: placeholder,
            textContentType: .URL,
            keyboardType: .URL,
            autocapitalization: .never,
            submitLabel: .done
        )
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: Sp.xxs) {
            if let label {
                Text(label)
                    .fmTypography(.subhead)
                    .foregroundStyle(FMColors.Text.secondary)
            }

            fieldBody
                .padding(.horizontal, Sp.sm)
                .frame(minHeight: minHeight, alignment: .center)
                .background(FMColors.Background.bg2)
                .clipShape(RoundedRectangle(cornerRadius: R.md))
                .overlay {
                    RoundedRectangle(cornerRadius: R.md)
                        .strokeBorder(borderColor, lineWidth: 1)
                }
                .overlay {
                    if isFocused, error == nil {
                        RoundedRectangle(cornerRadius: R.md)
                            .strokeBorder(FMColors.Accent.ring, lineWidth: 4)
                            .padding(-2)
                    }
                }
                .animation(.fmFast, value: isFocused)

            if let error, !error.isEmpty {
                Text(error)
                    .fmTypography(.caption)
                    .foregroundStyle(FMColors.Semantic.error)
            } else if let helper, !helper.isEmpty {
                Text(helper)
                    .fmTypography(.caption)
                    .foregroundStyle(FMColors.Text.tertiary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var fieldBody: some View {
        HStack(spacing: Sp.xs) {
            if case .search = style {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(FMColors.Text.tertiary)
            }

            Group {
                switch style {
                case .password:
                    if isPasswordVisible {
                        TextField(placeholder, text: $text)
                    } else {
                        SecureField(placeholder, text: $text)
                    }
                case .multiline:
                    TextEditor(text: $text)
                        .scrollContentBackground(.hidden)
                        .padding(.vertical, Sp.xs)
                        .overlay(alignment: .topLeading) {
                            if text.isEmpty {
                                Text(placeholder)
                                    .foregroundStyle(FMColors.Text.tertiary)
                                    .padding(.top, Sp.xs + 4)
                                    .padding(.leading, 4)
                                    .allowsHitTesting(false)
                            }
                        }
                default:
                    TextField(placeholder, text: $text)
                }
            }
            .fmTypography(.body)
            .foregroundStyle(FMColors.Text.primary)
            .textContentType(textContentType)
            .keyboardType(keyboardType)
            .focused($isFocused)
            .autocorrectionDisabled()
            .textInputAutocapitalization(autocapitalization ?? defaultAutocapitalization)
            .submitLabel(submitLabel)

            if case .password = style {
                Button {
                    isPasswordVisible.toggle()
                } label: {
                    Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                        .foregroundStyle(FMColors.Text.tertiary)
                }
                .accessibilityLabel(isPasswordVisible ? "비밀번호 숨기기" : "비밀번호 보기")
            }

            if case .search = style, !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(FMColors.Text.tertiary)
                }
                .accessibilityLabel("검색어 지우기")
            }
        }
    }

    private var borderColor: Color {
        if error != nil {
            FMColors.Semantic.error
        } else if isFocused {
            FMColors.Accent.primary
        } else {
            FMColors.Border.default
        }
    }

    private var minHeight: CGFloat {
        if case .multiline(let height) = style {
            return height
        }
        return 44
    }

    private var defaultAutocapitalization: TextInputAutocapitalization {
        switch textContentType {
        case .emailAddress, .username, .password, .newPassword, .nickname, .URL:
            return .never
        default:
            switch style {
            case .search, .multiline:
                return .sentences
            case .password:
                return .never
            case .plain:
                return .sentences
            }
        }
    }
}

// MARK: - Preview

private struct FMTextFieldPreview: View {
    @State private var email = ""
    @State private var password = ""
    @State private var query = ""
    @State private var bio = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.lg) {
                FMTextField(
                    "이메일",
                    text: $email,
                    placeholder: "you@example.com",
                    helper: "로그인에 사용할 이메일을 입력하세요",
                    textContentType: .emailAddress,
                    keyboardType: .emailAddress
                )

                FMTextField.password(
                    "비밀번호",
                    text: $password,
                    placeholder: "8자 이상 입력"
                )

                FMTextField.search(text: $query, placeholder: "필터, 메이커 검색")

                FMTextField(
                    "자기소개",
                    text: $bio,
                    placeholder: "여러 줄을 입력할 수 있어요",
                    style: .multiline(minHeight: 96)
                )

                FMTextField(
                    "오류 예시",
                    text: .constant("잘못된 입력"),
                    error: "유효하지 않은 형식입니다"
                )
            }
            .padding(Sp.md)
        }
        .background(FMColors.Background.bg1)
    }
}

#Preview("FMTextField — Light") {
    FMTextFieldPreview()
}

#Preview("FMTextField — Dark") {
    FMTextFieldPreview()
        .preferredColorScheme(.dark)
}
