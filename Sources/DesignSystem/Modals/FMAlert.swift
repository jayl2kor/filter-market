import SwiftUI

// MARK: - FMAlert
//
// Phase D6 — `MODAL_PATTERNS.md` M-03 Confirmation Alert 의 표준 wrapper.
//
// SwiftUI `.alert` 위에 filterMarket 표준 호출 형태를 얹는다.
// 가장 자주 등장하는 destructive 확인 패턴을 위한 단축 API 도 제공.

public extension View {
    /// filterMarket 표준 alert wrapper.
    ///
    /// 일반 / 정보성 alert. 파괴적 액션 단축 API 는 `fmDestructiveAlert` 참조.
    ///
    /// ```swift
    /// .fmAlert("로그아웃 하시겠어요?", isPresented: $showLogout) {
    ///     Button("취소", role: .cancel) {}
    ///     Button("로그아웃", role: .destructive) { signOut() }
    /// } message: {
    ///     Text("다시 로그인하면 다운로드 받은 필터를 그대로 이용할 수 있어요.")
    /// }
    /// ```
    func fmAlert<Actions: View, Message: View>(
        _ title: LocalizedStringKey,
        isPresented: Binding<Bool>,
        @ViewBuilder actions: () -> Actions,
        @ViewBuilder message: () -> Message
    ) -> some View {
        alert(title, isPresented: isPresented, actions: actions, message: message)
    }

    /// `message` 가 없는 단축 형태.
    func fmAlert<Actions: View>(
        _ title: LocalizedStringKey,
        isPresented: Binding<Bool>,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        alert(title, isPresented: isPresented, actions: actions)
    }

    /// 파괴적 액션 (삭제·신고·탈퇴 등) 의 표준 confirmation alert.
    ///
    /// 자동으로 빨간색 destructive 버튼 + 취소(cancel) 버튼을 구성하고
    /// destructive 탭 시 warning 햅틱을 재생한다.
    ///
    /// ```swift
    /// .fmDestructiveAlert(
    ///     "정말 삭제할까요?",
    ///     message: "삭제한 필터는 복구할 수 없어요.",
    ///     destructiveTitle: "삭제",
    ///     isPresented: $showDelete,
    ///     onConfirm: { delete() }
    /// )
    /// ```
    func fmDestructiveAlert(
        _ title: LocalizedStringKey,
        message: LocalizedStringKey? = nil,
        destructiveTitle: LocalizedStringKey,
        cancelTitle: LocalizedStringKey = "취소",
        isPresented: Binding<Bool>,
        onConfirm: @escaping () -> Void
    ) -> some View {
        alert(title, isPresented: isPresented) {
            Button(cancelTitle, role: .cancel) {}
            Button(destructiveTitle, role: .destructive) {
                FMHaptic.warning.play()
                onConfirm()
            }
        } message: {
            if let message {
                Text(message)
            }
        }
    }
}

// MARK: - Preview

private struct FMAlertPreview: View {
    @State private var showInfo = false
    @State private var showDelete = false

    var body: some View {
        VStack(spacing: Sp.md) {
            FMButton("정보성 Alert", variant: .secondary, size: .md) {
                showInfo = true
            }
            FMButton("파괴적 Alert", variant: .destructive, size: .md) {
                showDelete = true
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FMColors.Background.bg1)
        .fmAlert("필터를 다운로드했어요", isPresented: $showInfo) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("저장됨 탭에서 다시 볼 수 있어요.")
        }
        .fmDestructiveAlert(
            "정말 삭제할까요?",
            message: "삭제한 필터는 복구할 수 없어요.",
            destructiveTitle: "삭제",
            isPresented: $showDelete
        ) {
            // delete()
        }
    }
}

#Preview("FMAlert") {
    FMAlertPreview()
}
