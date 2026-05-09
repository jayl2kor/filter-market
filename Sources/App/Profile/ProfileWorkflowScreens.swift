import DesignSystem
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Foundation
import PhotosUI
import SwiftUI
import UIKit

struct AccountDeletionScreen: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirmation = ""
    @State private var didAcknowledgePolicy = false
    @State private var showDeleteAlert = false
    @State private var didRequestDeletion = false
    @State private var isDeletingAccount = false
    @State private var deletionErrorMessage: String?

    private var expectedUsername: String {
        sessionStore.editableProfile.handle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var expectedDisplayUsername: String {
        expectedUsername.isEmpty ? "등록된 이메일" : "@\(expectedUsername)"
    }

    private var expectedEmail: String {
        #if DEBUG
        if isUITesting {
            return "tester@moodit.app"
        }
        #endif
        return Auth.auth().currentUser?.email?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var isConfirmationValid: Bool {
        let normalized = confirmation.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return false }
        let usernameMatches = !expectedUsername.isEmpty
            && (normalized == expectedUsername.lowercased() || normalized == "@\(expectedUsername.lowercased())")
        let emailMatches = !expectedEmail.isEmpty && normalized == expectedEmail.lowercased()
        return usernameMatches || emailMatches
    }

    private var canSubmitDeletion: Bool {
        didAcknowledgePolicy && isConfirmationValid && !isDeletingAccount
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.lg) {
                workflowHeader(
                    title: "계정 삭제",
                    subtitle: "삭제 요청 전 사라지는 데이터와 유지되는 항목을 확인합니다.",
                    symbol: "person.crop.circle.badge.xmark"
                )

                if didRequestDeletion || sessionStore.accountDeletionRequestedAt != nil {
                    deletionReceipt
                } else {
                    warningCard
                    policyAcknowledgementCard
                    confirmationCard
                    actionButtons
                }
            }
            .padding(Sp.md)
            .padding(.bottom, FMLayout.tabBarHeight + Sp.xxxl)
        }
        .background(FMColors.Background.bg1)
        .navigationTitle("계정 삭제")
        .navigationBarTitleDisplayMode(.inline)
        .fmDestructiveAlert(
            "계정을 영구 삭제할까요?",
            message: "이 작업은 로그인 계정을 즉시 비활성화하고 공개 프로필 데이터를 삭제 상태로 전환합니다.",
            destructiveTitle: "계정 삭제",
            isPresented: $showDeleteAlert
        ) {
            requestAccountDeletion()
        }
        .alert("삭제 요청 실패", isPresented: Binding(
            get: { deletionErrorMessage != nil },
            set: { if !$0 { deletionErrorMessage = nil } }
        )) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(deletionErrorMessage ?? "")
        }
    }

    private var warningCard: some View {
        FMCard {
            VStack(alignment: .leading, spacing: Sp.md) {
                deletionImpactRow("로그인 계정 즉시 비활성화", detail: "삭제 요청이 성공하면 현재 계정은 로그아웃되고 다시 로그인할 수 없습니다.", icon: "person.crop.circle.badge.xmark")
                workflowDivider()
                deletionImpactRow("프로필·팔로우 정보 삭제", detail: "프로필, 유저네임, 바이오, 팔로워/팔로잉 관계가 삭제 상태로 전환됩니다.", icon: "person.2")
                workflowDivider()
                deletionImpactRow("업로드한 필터 처리", detail: "검수 중이거나 공개된 필터는 비공개 처리 및 후속 정리 대상이 됩니다.", icon: "camera.filters")
                workflowDivider()
                deletionImpactRow("다운로드한 필터와 구매 내역", detail: "기기에 저장된 파일은 자동 삭제되지 않을 수 있으며, 구매·환불 기록은 법적 보관 기간 동안 유지될 수 있습니다.", icon: "checkmark.seal")
                workflowDivider()
                deletionImpactRow("코인·정산·환불", detail: "남은 코인, 메이커 정산, 환불 요청은 지원팀 검토 후 정책에 따라 처리됩니다.", icon: "creditcard")
                workflowDivider()
                deletionImpactRow("복구 유예 없음", detail: "현재 30일 복구 유예 기간은 제공되지 않습니다. 삭제 전 데이터 내보내기를 먼저 진행하세요.", icon: "exclamationmark.triangle")
            }
        }
    }

    private var policyAcknowledgementCard: some View {
        FMCard {
            Toggle("위 내용을 이해했고 계정 삭제를 계속 진행합니다.", isOn: $didAcknowledgePolicy)
                .tint(FMColors.Semantic.error)
                .fmTypography(.body)
                .foregroundStyle(FMColors.Text.primary)
                .accessibilityIdentifier("auth.delete.policy.ack")
        }
    }

    private var confirmationCard: some View {
        FMCard {
            VStack(alignment: .leading, spacing: Sp.sm) {
                Text("확인을 위해 \(expectedDisplayUsername) 또는 이메일을 정확히 입력하세요.")
                    .fmTypography(.body)
                    .foregroundStyle(FMColors.Text.primary)
                FMTextField(
                    nil,
                    text: $confirmation,
                    placeholder: expectedEmail.isEmpty ? expectedDisplayUsername : expectedEmail,
                    error: confirmation.isEmpty || isConfirmationValid ? nil : "유저네임 또는 이메일이 일치하지 않습니다.",
                    textContentType: .nickname,
                    keyboardType: .asciiCapable,
                    autocapitalization: .never,
                    submitLabel: .done
                )
                .accessibilityIdentifier("auth.delete.confirm.input")
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: Sp.sm) {
            FMButton("계정 영구 삭제", icon: "trash", variant: .primary, size: .lg) {
                showDeleteAlert = true
            }
            .disabled(!canSubmitDeletion)
            .accessibilityIdentifier("auth.delete.submit")

            FMButton("취소", variant: .secondary, size: .lg) {
                dismiss()
            }
            .accessibilityIdentifier("auth.delete.cancel")
        }
    }

    private var deletionReceipt: some View {
        FMCard {
            VStack(alignment: .leading, spacing: Sp.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(FMColors.Accent.primary)
                Text("삭제 요청이 접수됐습니다")
                    .fmTypography(.headline)
                    .foregroundStyle(FMColors.Text.primary)
                Text("보안 확인과 정산 상태 점검 후 계정 삭제 절차가 진행됩니다.")
                    .fmTypography(.body)
                    .foregroundStyle(FMColors.Text.secondary)
            }
        }
    }

    private func requestAccountDeletion() {
        guard !isDeletingAccount else { return }
        isDeletingAccount = true
        Task {
            do {
                try await sessionStore.markAccountDeletionRequested()
                #if DEBUG
                if !isUITesting {
                    try? Auth.auth().signOut()
                }
                #else
                try? Auth.auth().signOut()
                #endif
                await MainActor.run {
                    didRequestDeletion = true
                    isDeletingAccount = false
                }
            } catch {
                await MainActor.run {
                    deletionErrorMessage = error.localizedDescription
                    isDeletingAccount = false
                }
            }
        }
    }

    private func deletionImpactRow(_ title: String, detail: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: Sp.sm) {
            Image(systemName: icon)
                .font(.system(size: IconSize.md, weight: .semibold))
                .foregroundStyle(FMColors.Semantic.error)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fmTypography(.headline)
                    .foregroundStyle(FMColors.Text.primary)
                Text(detail)
                    .fmTypography(.subhead)
                    .foregroundStyle(FMColors.Text.secondary)
            }
        }
    }
}

struct EditProfileScreen: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 빈 상태에서 시작해 .onAppear에서 sessionStore.editableProfile (Firebase Auth + Firestore 합성)로 초기화.
    /// (이전: EditableProfile.preview = 강지수 — 사용자 본인 데이터로 자동 채워지도록 수정)
    @State private var draft = EditableProfile.empty
    @State private var initialHandle = ""
    @State private var handleStatus: HandleStatus = .idle
    @State private var handleCheckTask: Task<Void, Never>?
    @State private var lastCheckedHandle = ""
    @State private var isAvatarPickerPresented = false
    @State private var showDiscardChangesDialog = false

    private enum HandleStatus: Equatable {
        case idle
        case checking
        case available
        case unavailable
        case invalid
        case failed

        var message: String {
            switch self {
            case .idle: "유저네임을 입력해 주세요."
            case .checking: "확인 중..."
            case .available: "이 이름 사용 가능해요."
            case .unavailable: "이미 사용 중이에요."
            case .invalid: "3~20자, 영문/숫자/_ 만 사용할 수 있어요."
            case .failed: "확인하지 못했어요. 다시 시도해 주세요."
            }
        }

        var tint: Color {
            switch self {
            case .available: FMColors.Accent.primary
            case .unavailable: FMColors.Semantic.error
            case .invalid: FMColors.Semantic.warning
            case .checking: FMColors.Text.secondary
            case .idle, .failed: FMColors.Text.tertiary
            }
        }

        var iconName: String? {
            switch self {
            case .idle: nil
            case .checking: nil
            case .available: "checkmark.circle.fill"
            case .unavailable: "xmark.circle.fill"
            case .invalid, .failed: "exclamationmark.circle.fill"
            }
        }
    }

    private var canSave: Bool {
        !draft.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !draft.handle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && handleStatus == .available
    }

    private var hasUnsavedChanges: Bool {
        draft != sessionStore.editableProfile
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.lg) {
                avatarEditor
                formFields
                visibilitySettings
                saveReceipt
            }
            .padding(Sp.md)
            .padding(.bottom, FMLayout.tabBarHeight + Sp.xxxl)
        }
        .background(FMColors.Background.bg1)
        .navigationTitle("프로필 편집")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    closeEditor()
                } label: {
                    Image(systemName: "xmark")
                }
                .accessibilityLabel("닫기")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("저장") { save() }
                    .disabled(!canSave)
                    .accessibilityIdentifier("profile.edit.save")
            }
        }
        .onAppear {
            draft = sessionStore.editableProfile
            initialHandle = normalizedHandle(sessionStore.editableProfile.handle)
            handleStatus = initialHandle.isEmpty ? .idle : .available
            lastCheckedHandle = initialHandle
        }
        .onDisappear {
            handleCheckTask?.cancel()
        }
        .interactiveDismissDisabled(hasUnsavedChanges)
        .confirmationDialog(
            "변경사항을 버릴까요?",
            isPresented: $showDiscardChangesDialog,
            titleVisibility: .visible
        ) {
            Button("버리고 닫기", role: .destructive) {
                dismiss()
            }
            Button("계속 편집", role: .cancel) {}
        } message: {
            Text("저장하지 않은 프로필 변경사항이 사라집니다.")
        }
        .sheet(isPresented: $isAvatarPickerPresented) {
            PhotoPicker { image in
                draft.avatarImageData = image.normalizedJPEGData(maxDimension: 512)
                draft.avatarURL = nil
            }
        }
    }

    private func closeEditor() {
        if hasUnsavedChanges {
            showDiscardChangesDialog = true
        } else {
            dismiss()
        }
    }

    private var avatarEditor: some View {
        VStack(spacing: Sp.sm) {
            ZStack(alignment: .bottomTrailing) {
                avatarPreview
                Button {
                    isAvatarPickerPresented = true
                } label: {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(FMColors.Accent.primary, in: Circle())
                }
                .accessibilityIdentifier("profile.edit.avatar.change")
            }
            Button("사진 변경") {
                isAvatarPickerPresented = true
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(FMColors.Accent.primary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var avatarPreview: some View {
        if let data = draft.avatarImageData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 104, height: 104)
                .clipShape(Circle())
        } else if let avatarURL = draft.avatarURL {
            FMAvatar(url: avatarURL, size: .xl, fallback: draft.initials)
                .frame(width: 104, height: 104)
        } else {
            Circle()
                .fill(avatarGradient)
                .frame(width: 104, height: 104)
                .overlay {
                    Text(draft.initials)
                        .fmTypography(.titleLarge)
                        .foregroundStyle(.white)
                }
        }
    }

    private var formFields: some View {
        VStack(alignment: .leading, spacing: Sp.md) {
            FMTextField(
                "이름",
                text: $draft.displayName,
                placeholder: "표시 이름",
                textContentType: .name,
                autocapitalization: .words,
                submitLabel: .next
            )
                .accessibilityIdentifier("profile.edit.name")
            VStack(alignment: .leading, spacing: Sp.xxs) {
                Text("유저네임")
                    .fmTypography(.caption)
                    .foregroundStyle(FMColors.Text.secondary)
                HStack(alignment: .center, spacing: Sp.xs) {
                    TextField(
                        "your.username",
                        text: Binding(
                            get: { draft.handle },
                            set: {
                                updateHandleInput($0)
                            }
                        )
                    )
                    .textContentType(.nickname)
                    .keyboardType(.asciiCapable)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .font(Font.fmBody)
                    .foregroundStyle(FMColors.Text.primary)
                    .padding(.horizontal, Sp.sm)
                    .frame(height: 44)
                    .background(FMColors.Background.bg0, in: RoundedRectangle(cornerRadius: R.md))
                    .overlay {
                        RoundedRectangle(cornerRadius: R.md)
                            .strokeBorder(FMColors.Border.default, lineWidth: 1)
                    }
                    .accessibilityIdentifier("profile.edit.handle")
                    .accessibilityValue(handleStatus.message)
                    Button {
                        scheduleHandleCheck(for: draft.handle, delayNanoseconds: 0, force: true)
                    } label: {
                        Image(systemName: "checkmark.seal")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(FMColors.Accent.primary, in: RoundedRectangle(cornerRadius: R.md))
                    }
                    .accessibilityIdentifier("profile.edit.handle.check")
                    .disabled(handleStatus == .checking)
                }
                HStack(spacing: Sp.xxs) {
                    handleStatusIndicator
                    Text(handleStatus.message)
                        .fmTypography(.caption)
                }
                .foregroundStyle(handleStatus.tint)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("profile.edit.handle.status")
                .accessibilityValue(handleStatus.message)
            }
            FMTextField(
                "소개",
                text: $draft.bio,
                placeholder: "나를 소개해 주세요.",
                style: .multiline(minHeight: 96),
                submitLabel: .return
            )
                .accessibilityIdentifier("profile.edit.bio")
            FMTextField.url("링크", text: $draft.website, placeholder: "https://")
                .accessibilityIdentifier("profile.edit.website")
        }
    }

    private var visibilitySettings: some View {
        FMCard {
            VStack(spacing: 0) {
                Toggle("메이커 페이지 노출", isOn: $draft.makerPageVisible)
                    .tint(FMColors.Accent.primary)
                workflowDivider()
                Toggle("필터 적용 사진 공유 허용", isOn: $draft.photoSharingAllowed)
                    .tint(FMColors.Accent.primary)
            }
            .fmTypography(.body)
            .foregroundStyle(FMColors.Text.primary)
        }
    }

    @ViewBuilder
    private var saveReceipt: some View {
        if let savedAt = sessionStore.lastProfileSavedAt {
            Text("저장됨 · \(workflowTimeString(savedAt))")
                .fmTypography(.caption)
                .foregroundStyle(FMColors.Text.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var avatarGradient: LinearGradient {
        let colors: [[Color]] = [
            [FMColors.Category.vintage, FMColors.Category.cinematic],
            [FMColors.Category.travel, FMColors.Category.pastel],
            [FMColors.Category.food, FMColors.Accent.primary],
            [FMColors.Category.mood, FMColors.Category.portrait]
        ]
        return LinearGradient(
            colors: colors[draft.avatarVariant % colors.count],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    @ViewBuilder
    private var handleStatusIndicator: some View {
        if handleStatus == .checking {
            if reduceMotion {
                Image(systemName: "clock")
                    .font(.system(size: 12, weight: .semibold))
            } else {
                ProgressView()
                    .controlSize(.small)
                    .tint(handleStatus.tint)
            }
        } else if let iconName = handleStatus.iconName {
            Image(systemName: iconName)
                .font(.system(size: 12, weight: .semibold))
        }
    }

    private func updateHandleInput(_ value: String) {
        let normalized = normalizedHandle(value)
        guard normalized != draft.handle else { return }
        draft.handle = normalized
        scheduleHandleCheck(for: normalized)
    }

    private func scheduleHandleCheck(
        for value: String,
        delayNanoseconds: UInt64 = 400_000_000,
        force: Bool = false
    ) {
        handleCheckTask?.cancel()
        let normalized = normalizedHandle(value)

        guard !normalized.isEmpty else {
            setHandleStatus(.idle)
            return
        }
        guard isValidHandle(normalized) else {
            setHandleStatus(.invalid)
            return
        }
        guard force || normalized != lastCheckedHandle else {
            setHandleStatus(normalized == initialHandle ? .available : handleStatus)
            return
        }

        setHandleStatus(.checking)
        handleCheckTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: delayNanoseconds)
                guard !Task.isCancelled else { return }
                let status = await resolveHandleStatus(for: normalized)
                guard !Task.isCancelled, draft.handle == normalized else { return }
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

    private func resolveHandleStatus(for handle: String) async -> HandleStatus {
        if reservedHandles.contains(handle) {
            return .unavailable
        }
        if handle == initialHandle {
            return .available
        }
        guard !isUITesting, FirebaseApp.app() != nil else {
            return .available
        }

        do {
            let snapshot = try await Firestore.firestore()
                .collection("handles")
                .document(handle)
                .getDocument()
            guard snapshot.exists else { return .available }
            let ownerUID = snapshot.data()?["uid"] as? String
            if ownerUID == Auth.auth().currentUser?.uid {
                return .available
            }
            return .unavailable
        } catch {
            return .failed
        }
    }

    private func setHandleStatus(_ status: HandleStatus) {
        guard handleStatus != status else { return }
        handleStatus = status
        UIAccessibility.post(notification: .announcement, argument: status.message)
    }

    private var reservedHandles: Set<String> {
        ["admin", "moodit", "support"]
    }

    private func normalizedHandle(_ value: String) -> String {
        value
            .replacingOccurrences(of: "@", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func isValidHandle(_ value: String) -> Bool {
        guard (3 ... 20).contains(value.count) else { return false }
        return value.range(of: #"^[a-z0-9_]+$"#, options: .regularExpression) != nil
    }

    private func save() {
        guard canSave else { return }
        sessionStore.saveProfile(draft)
        dismiss()
    }
}

private extension UIImage {
    func normalizedJPEGData(maxDimension: CGFloat) -> Data? {
        let longest = max(size.width, size.height)
        let scale = longest > maxDimension ? maxDimension / longest : 1
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let rendered = renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return rendered.jpegData(compressionQuality: 0.82)
    }
}
