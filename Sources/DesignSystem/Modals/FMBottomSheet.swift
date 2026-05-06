import SwiftUI

// MARK: - FMBottomSheet
//
// Phase D6 — `MOTION_SPEC.md` §2.2 Modal Sheet + `MODAL_PATTERNS.md` M-01 의 표준 wrapper.
//
// SwiftUI 표준 `.sheet` 위에 filterMarket 표준 detent / drag indicator / corner radius 를 적용한다.
// iOS 17+ 에서 `presentationCornerRadius`, `presentationBackground` 사용.

/// Bottom sheet 가 사용할 수 있는 detent 종류.
public enum FMBottomSheetDetent: Sendable, Hashable {
    case medium
    case large
    case fraction(Double)
    case height(CGFloat)

    var presentationDetent: PresentationDetent {
        switch self {
        case .medium: .medium
        case .large: .large
        case .fraction(let value): .fraction(value)
        case .height(let value): .height(value)
        }
    }
}

// MARK: - View extension

public extension View {
    /// filterMarket 표준 bottom sheet.
    ///
    /// - Parameters:
    ///   - isPresented: 표시 상태 binding.
    ///   - detents: 허용 detent 들. 기본 `[.medium, .large]`.
    ///   - showsDragIndicator: drag handle 노출 여부 (기본 true).
    ///   - cornerRadius: 상단 모서리 radius (기본 `R.lg = 16pt` — `MODAL_PATTERNS.md` 와 정합).
    ///   - onDismiss: 사용자가 닫았을 때 호출.
    ///   - content: 시트 본문.
    ///
    /// ```swift
    /// .fmBottomSheet(isPresented: $showSheet, detents: [.medium]) {
    ///     FilterDetailSheet(filter: filter)
    /// }
    /// ```
    func fmBottomSheet<SheetContent: View>(
        isPresented: Binding<Bool>,
        detents: [FMBottomSheetDetent] = [.medium, .large],
        showsDragIndicator: Bool = true,
        cornerRadius: CGFloat = R.lg,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> SheetContent
    ) -> some View {
        sheet(isPresented: isPresented, onDismiss: onDismiss) {
            content()
                .presentationDetents(Set(detents.map(\.presentationDetent)))
                .presentationDragIndicator(showsDragIndicator ? .visible : .hidden)
                .presentationCornerRadius(cornerRadius)
                .presentationBackground(FMColors.Background.bg2)
        }
    }

    /// Identifiable item 기반 bottom sheet.
    func fmBottomSheet<Item: Identifiable, SheetContent: View>(
        item: Binding<Item?>,
        detents: [FMBottomSheetDetent] = [.medium, .large],
        showsDragIndicator: Bool = true,
        cornerRadius: CGFloat = R.lg,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> SheetContent
    ) -> some View {
        sheet(item: item, onDismiss: onDismiss) { item in
            content(item)
                .presentationDetents(Set(detents.map(\.presentationDetent)))
                .presentationDragIndicator(showsDragIndicator ? .visible : .hidden)
                .presentationCornerRadius(cornerRadius)
                .presentationBackground(FMColors.Background.bg2)
        }
    }
}

// MARK: - Preview

private struct FMBottomSheetPreview: View {
    @State private var show = false
    var body: some View {
        VStack(spacing: Sp.md) {
            FMButton("바텀 시트 열기", variant: .primary, size: .md) {
                show = true
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FMColors.Background.bg1)
        .fmBottomSheet(isPresented: $show, detents: [.medium]) {
            VStack(alignment: .leading, spacing: Sp.md) {
                Text("필터 빠른 정보")
                    .fmTypography(.title)
                    .foregroundStyle(FMColors.Text.primary)
                Text("바텀 시트는 부가 정보, 빠른 액션, 부가 설정에 사용한다.")
                    .fmTypography(.body)
                    .foregroundStyle(FMColors.Text.secondary)
                Spacer()
            }
            .padding(Sp.md)
        }
    }
}

#Preview("FMBottomSheet — Light") {
    FMBottomSheetPreview()
}

#Preview("FMBottomSheet — Dark") {
    FMBottomSheetPreview()
        .preferredColorScheme(.dark)
}
