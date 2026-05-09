import DesignSystem
import FirebaseAuth
import FirebaseCore
import SwiftUI

/// 이메일 + 비밀번호 인증 화면. 토글로 로그인 ↔ 가입 모드 전환.
///
/// Phase 3 — `docs/QA_TEST_PLAN.md` §3.3.
///
/// 비밀번호 정책 (Firebase Console에서 강제):
/// - 8자 이상
/// - 소문자 + 숫자 + 특수문자 포함
///
/// Firebase Auth가 정책 위반을 서버 측에서 검증하지만, 클라이언트도 즉시 피드백
/// 위해 동일 규칙을 적용한다.
struct EmailLoginScreen: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sessionStore: SessionStore

    enum Mode {
        case signIn
        case signUp

        var ctaTitle: String {
            switch self {
            case .signIn: "로그인"
            case .signUp: "가입하기"
            }
        }

        var toggleTitle: String {
            switch self {
            case .signIn: "계정이 없으신가요? 가입하기"
            case .signUp: "이미 계정이 있으신가요? 로그인"
            }
        }

        var toggled: Mode {
            switch self {
            case .signIn: .signUp
            case .signUp: .signIn
            }
        }
    }

    @State private var mode: Mode = .signIn
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showPasswordReset: Bool = false
    @State private var resetEmailSent: Bool = false
    @State private var isPasswordVisible: Bool = false
    @State private var handle: String = ""
    @State private var handleStatus: HandleValidationStatus = .idle
    @State private var handleCheckTask: Task<Void, Never>?
    @State private var lastCheckedHandle = ""

    private var isFormValid: Bool {
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        switch mode {
        case .signIn:
            return password.count >= 1
        case .signUp:
            return Self.isValidPassword(password) && handleStatus == .available
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.lg) {
                header
                emailField
                if mode == .signUp {
                    handleField
                }
                passwordField
                if mode == .signUp {
                    passwordHint
                }
                ctaButton
                if mode == .signIn {
                    forgotPasswordButton
                }
                modeToggleButton
                if let errorMessage {
                    errorBanner(message: errorMessage)
                }
                if resetEmailSent {
                    resetSentBanner
                }
            }
            .padding(Sp.md)
        }
        .background(FMColors.Background.bg1)
        .navigationTitle(mode.ctaTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: handle) { _, newValue in
            scheduleHandleCheck(for: newValue)
        }
        .onDisappear {
            handleCheckTask?.cancel()
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: Sp.xs) {
            Text(mode == .signIn ? "moodit으로 돌아오신 걸 환영해요." : "moodit에 가입하고 메이커가 되어보세요.")
                .fmTypography(.body)
                .foregroundStyle(FMColors.Text.secondary)
        }
    }

    private var emailField: some View {
        VStack(alignment: .leading, spacing: Sp.xs) {
            Text("이메일")
                .fmTypography(.caption)
                .foregroundStyle(FMColors.Text.secondary)
            TextField("name@example.com", text: $email)
                .keyboardType(.emailAddress)
                .textContentType(.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(Sp.sm)
                .background(FMColors.Background.bg2, in: RoundedRectangle(cornerRadius: R.md))
                .overlay {
                    RoundedRectangle(cornerRadius: R.md)
                        .strokeBorder(FMColors.Border.default, lineWidth: 1)
                }
                .accessibilityIdentifier("auth.email.input")
        }
    }

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: Sp.xs) {
            Text("비밀번호")
                .fmTypography(.caption)
                .foregroundStyle(FMColors.Text.secondary)
            HStack(spacing: Sp.xs) {
                Group {
                    if isPasswordVisible {
                        TextField(mode == .signUp ? "새 비밀번호" : "비밀번호", text: $password)
                    } else {
                        SecureField(mode == .signUp ? "새 비밀번호" : "비밀번호", text: $password)
                    }
                }
                .textContentType(mode == .signUp ? .newPassword : .password)
                .submitLabel(mode == .signIn ? .go : .done)
                .accessibilityIdentifier("auth.password.input")

                Button {
                    isPasswordVisible.toggle()
                    FMHaptic.light.play()
                } label: {
                    Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(FMColors.Text.secondary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("auth.password.visibility")
                .accessibilityLabel(isPasswordVisible ? "비밀번호 숨기기" : "비밀번호 보기")
            }
            .padding(.leading, Sp.sm)
            .padding(.trailing, Sp.xs)
            .padding(.vertical, Sp.xs)
            .background(FMColors.Background.bg2, in: RoundedRectangle(cornerRadius: R.md))
            .overlay {
                RoundedRectangle(cornerRadius: R.md)
                    .strokeBorder(FMColors.Border.default, lineWidth: 1)
            }
        }
    }

    private var handleField: some View {
        VStack(alignment: .leading, spacing: Sp.xs) {
            Text("유저네임")
                .fmTypography(.caption)
                .foregroundStyle(FMColors.Text.secondary)

            HStack(spacing: Sp.xs) {
                Text("@")
                    .fmTypography(.body)
                    .foregroundStyle(FMColors.Text.tertiary)
                TextField("mood_maker", text: Binding(
                    get: { handle },
                    set: { handle = HandleValidator.normalized($0) }
                ))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.username)
                .accessibilityIdentifier("auth.handle.input")

                if handleStatus == .checking {
                    ProgressView()
                        .controlSize(.small)
                        .tint(handleStatus.tint)
                } else if let iconName = handleStatus.iconName {
                    Image(systemName: iconName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(handleStatus.tint)
                }
            }
            .padding(.leading, Sp.sm)
            .padding(.trailing, Sp.xs)
            .padding(.vertical, Sp.sm)
            .background(FMColors.Background.bg2, in: RoundedRectangle(cornerRadius: R.md))
            .overlay {
                RoundedRectangle(cornerRadius: R.md)
                    .strokeBorder(FMColors.Border.default, lineWidth: 1)
            }

            Text(handleStatus.message)
                .fmTypography(.caption)
                .foregroundStyle(handleStatus.tint)
                .accessibilityIdentifier("auth.handle.status")
        }
    }

    private var passwordHint: some View {
        VStack(alignment: .leading, spacing: Sp.xs) {
            HStack(spacing: Sp.xs) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(index < passwordStrength.level ? passwordStrength.color : FMColors.Border.subtle)
                        .frame(height: 4)
                }
            }

            Text("강도: \(passwordStrength.title) · 8자 이상, 소문자 + 숫자 + 특수문자 포함")
                .fmTypography(.caption)
                .foregroundStyle(FMColors.Text.tertiary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("auth.password.hint")
        .accessibilityLabel("비밀번호 강도 \(passwordStrength.title). 8자 이상, 소문자, 숫자, 특수문자를 포함해야 합니다.")
    }

    private var ctaButton: some View {
        FMButton(
            isLoading ? "처리 중..." : mode.ctaTitle,
            variant: .primary,
            size: .lg
        ) {
            performAuth()
        }
        .disabled(!isFormValid || isLoading)
        .accessibilityIdentifier(mode == .signIn ? "auth.signIn.submit" : "auth.signUp.submit")
    }

    private var forgotPasswordButton: some View {
        Button {
            sendPasswordReset()
        } label: {
            Text("비밀번호를 잊으셨나요?")
                .fmTypography(.subhead)
                .foregroundStyle(FMColors.Accent.primary)
        }
        .disabled(email.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
        .accessibilityIdentifier("auth.passwordReset.send")
    }

    private var modeToggleButton: some View {
        Button {
            mode = mode.toggled
            errorMessage = nil
            resetEmailSent = false
            if mode == .signIn {
                handleCheckTask?.cancel()
                handle = ""
                handleStatus = .idle
                lastCheckedHandle = ""
            }
        } label: {
            Text(mode.toggleTitle)
                .fmTypography(.subhead)
                .foregroundStyle(FMColors.Text.secondary)
        }
        .accessibilityIdentifier("auth.mode.toggle")
    }

    private func errorBanner(message: String) -> some View {
        Text(message)
            .fmTypography(.caption)
            .foregroundStyle(FMColors.Semantic.error)
            .padding(Sp.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FMColors.Semantic.errorBg, in: RoundedRectangle(cornerRadius: R.sm))
            .accessibilityIdentifier("auth.error.banner")
    }

    private var resetSentBanner: some View {
        Text("\(email)으로 비밀번호 재설정 메일을 보냈어요.")
            .fmTypography(.caption)
            .foregroundStyle(FMColors.Semantic.success)
            .padding(Sp.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FMColors.Semantic.successBg, in: RoundedRectangle(cornerRadius: R.sm))
            .accessibilityIdentifier("auth.passwordReset.sent")
    }

    // MARK: - Auth actions

    private func performAuth() {
        guard FirebaseApp.app() != nil else {
            errorMessage = "인증 서비스가 설정되지 않았어요. 잠시 후 다시 시도해주세요."
            return
        }
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        guard !trimmedEmail.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        resetEmailSent = false

        Task { @MainActor in
            do {
                switch mode {
                case .signIn:
                    _ = try await Auth.auth().signIn(withEmail: trimmedEmail, password: password)
                case .signUp:
                    let normalizedHandle = HandleValidator.normalized(handle)
                    let result = try await Auth.auth().createUser(withEmail: trimmedEmail, password: password)
                    do {
                        try await FirebaseSideEffects.reserveHandle(normalizedHandle, for: result.user.uid)
                        applySignedUpHandle(normalizedHandle, user: result.user)
                    } catch {
                        try? await result.user.delete()
                        throw error
                    }
                }
                FMHaptic.success.play()
                dismiss()
            } catch {
                errorMessage = friendlyMessage(for: error)
                FMHaptic.error.play()
            }
            isLoading = false
        }
    }

    private func sendPasswordReset() {
        guard FirebaseApp.app() != nil else {
            errorMessage = "인증 서비스가 설정되지 않았어요."
            return
        }
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        guard !trimmedEmail.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        Task { @MainActor in
            do {
                try await Auth.auth().sendPasswordReset(withEmail: trimmedEmail)
                resetEmailSent = true
                FMHaptic.success.play()
            } catch {
                errorMessage = friendlyMessage(for: error)
                FMHaptic.error.play()
            }
            isLoading = false
        }
    }

    private func scheduleHandleCheck(
        for value: String,
        delayNanoseconds: UInt64 = 400_000_000
    ) {
        handleCheckTask?.cancel()
        let normalized = HandleValidator.normalized(value)
        guard !normalized.isEmpty else {
            setHandleStatus(.idle)
            return
        }
        guard HandleValidator.isValid(normalized) else {
            setHandleStatus(.invalid)
            return
        }
        guard normalized != lastCheckedHandle else { return }

        setHandleStatus(.checking)
        handleCheckTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: delayNanoseconds)
                guard !Task.isCancelled else { return }
                let status = await HandleAvailabilityChecker.status(for: normalized)
                guard !Task.isCancelled, handle == normalized else { return }
                lastCheckedHandle = normalized
                setHandleStatus(status)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                setHandleStatus(.failed)
            }
        }
    }

    private func setHandleStatus(_ status: HandleValidationStatus) {
        guard handleStatus != status else { return }
        handleStatus = status
        UIAccessibility.post(notification: .announcement, argument: status.message)
    }

    private func applySignedUpHandle(_ normalizedHandle: String, user: User) {
        var profile = sessionStore.editableProfile
        if profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            profile.displayName = user.email?.split(separator: "@").first.map(String.init) ?? normalizedHandle
        }
        profile.handle = normalizedHandle
        sessionStore.editableProfile = profile
    }

    /// Map Firebase Auth `AuthErrorCode` to user-friendly Korean text.
    /// Email enumeration codes (e.g., `userNotFound`) are surfaced verbatim per
    /// Firebase's modern policy — protection is at the policy level.
    private func friendlyMessage(for error: Error) -> String {
        let nsError = error as NSError
        let code = AuthErrorCode(rawValue: nsError.code)
        switch code {
        case .invalidEmail:
            return "이메일 형식이 올바르지 않아요."
        case .wrongPassword, .invalidCredential:
            return "이메일 또는 비밀번호가 일치하지 않아요."
        case .userNotFound:
            return "가입된 계정이 없어요. '가입하기'를 눌러주세요."
        case .emailAlreadyInUse:
            return "이미 사용 중인 이메일이에요. 로그인을 시도해보세요."
        case .weakPassword:
            return "비밀번호가 정책을 만족하지 않아요. 8자 이상, 소문자 + 숫자 + 특수문자."
        case .userDisabled:
            return "이 계정은 비활성 상태예요. 고객센터에 문의해주세요."
        case .tooManyRequests:
            return "잠시 후 다시 시도해주세요."
        case .networkError:
            return "네트워크 연결을 확인해주세요."
        default:
            return error.localizedDescription
        }
    }

    // MARK: - Validation

    /// Mirrors Firebase Console password policy (8+ chars, lowercase + digit + special).
    /// Server-side check is authoritative — this is a UX shortcut for inline feedback.
    static func isValidPassword(_ password: String) -> Bool {
        guard password.count >= 8 else { return false }
        let lower = password.range(of: "[a-z]", options: .regularExpression) != nil
        let digit = password.range(of: "[0-9]", options: .regularExpression) != nil
        let special = password.range(
            of: "[^A-Za-z0-9]",
            options: .regularExpression
        ) != nil
        return lower && digit && special
    }

    private var passwordStrength: PasswordStrength {
        PasswordStrength(password)
    }

    private struct PasswordStrength {
        let level: Int
        let title: String
        let color: Color

        init(_ password: String) {
            let lower = password.range(of: "[a-z]", options: .regularExpression) != nil
            let upper = password.range(of: "[A-Z]", options: .regularExpression) != nil
            let digit = password.range(of: "[0-9]", options: .regularExpression) != nil
            let special = password.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil
            let length = password.count >= 8
            let score = [lower, upper, digit, special, length].filter { $0 }.count

            switch score {
            case 0...2:
                level = password.isEmpty ? 0 : 1
                title = password.isEmpty ? "입력 전" : "약함"
                color = FMColors.Semantic.error
            case 3...4:
                level = 2
                title = "보통"
                color = FMColors.Accent.primary
            default:
                level = 3
                title = "강함"
                color = FMColors.Semantic.success
            }
        }
    }
}
