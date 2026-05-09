import DesignSystem
import SwiftUI

extension View {
    func storeErrorToast(
        message: String?,
        title: String = "작업 실패",
        clear: @escaping @MainActor () -> Void
    ) -> some View {
        modifier(StoreErrorToastModifier(message: message, title: title, clear: clear))
    }
}

private struct StoreErrorToastModifier: ViewModifier {
    let message: String?
    let title: String
    let clear: @MainActor () -> Void

    @State private var toast: FMToastMessage?

    func body(content: Content) -> some View {
        content
            .fmToastOverlay(toast: $toast)
            .onChange(of: message) { _, newMessage in
                let detail = newMessage?.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let detail, !detail.isEmpty else { return }
                toast = FMToastMessage(.error, title, detail: detail)
                clear()
            }
    }
}
