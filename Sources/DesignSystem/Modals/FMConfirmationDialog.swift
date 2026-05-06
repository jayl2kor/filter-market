import SwiftUI

// MARK: - FMConfirmationDialog
//
// Phase D6 — `MODAL_PATTERNS.md` M-02 Action Sheet 의 표준 wrapper.
//
// 사진 액션 / 신고 옵션 등 1차원 액션 시트.
// 시스템 `confirmationDialog` 위에 filterMarket 표준 호출 형태(제목 + actions + message) 를 제공한다.

public extension View {
    /// filterMarket 표준 action sheet.
    ///
    /// - Parameters:
    ///   - title: 시트 상단 제목 (회색 소형 텍스트로 표시).
    ///   - isPresented: 표시 상태 binding.
    ///   - titleVisibility: 제목 표시 정책 (기본 `.visible`).
    ///   - actions: 버튼들. 파괴적 액션은 `role: .destructive` 명시.
    ///   - message: 추가 설명 (선택). 시트 상단 보조 텍스트.
    ///
    /// ```swift
    /// .fmConfirmationDialog(
    ///     "방금 촬영한 사진",
    ///     isPresented: $show
    /// ) {
    ///     Button("사진에 저장") { save() }
    ///     Button("공유") { share() }
    ///     Button("삭제", role: .destructive) { delete() }
    ///     Button("취소", role: .cancel) {}
    /// } message: {
    ///     Text("저장하지 않은 사진은 복구할 수 없어요.")
    /// }
    /// ```
    func fmConfirmationDialog<Actions: View, Message: View>(
        _ title: LocalizedStringKey,
        isPresented: Binding<Bool>,
        titleVisibility: Visibility = .visible,
        @ViewBuilder actions: () -> Actions,
        @ViewBuilder message: () -> Message
    ) -> some View {
        confirmationDialog(
            title,
            isPresented: isPresented,
            titleVisibility: titleVisibility,
            actions: actions,
            message: message
        )
    }

    /// `message` 가 없는 단축 형태.
    func fmConfirmationDialog<Actions: View>(
        _ title: LocalizedStringKey,
        isPresented: Binding<Bool>,
        titleVisibility: Visibility = .visible,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        confirmationDialog(
            title,
            isPresented: isPresented,
            titleVisibility: titleVisibility,
            actions: actions
        )
    }
}

// MARK: - Preview

private struct FMConfirmationDialogPreview: View {
    @State private var show = false

    var body: some View {
        VStack(spacing: Sp.md) {
            FMButton("Action sheet 열기", variant: .primary, size: .md) {
                show = true
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FMColors.Background.bg1)
        .fmConfirmationDialog(
            "방금 촬영한 사진",
            isPresented: $show
        ) {
            Button("사진에 저장") {}
            Button("공유") {}
            Button("삭제", role: .destructive) {}
            Button("취소", role: .cancel) {}
        } message: {
            Text("저장하지 않은 사진은 복구할 수 없어요.")
        }
    }
}

#Preview("FMConfirmationDialog") {
    FMConfirmationDialogPreview()
}
