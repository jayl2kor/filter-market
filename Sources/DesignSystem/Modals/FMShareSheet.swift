import SwiftUI
import UIKit

// MARK: - FMShareSheet
//
// Phase D6 — `MODAL_PATTERNS.md` M-04 Share Sheet 의 표준 wrapper.
//
// 시스템 `UIActivityViewController` 를 SwiftUI 에 안전하게 통합한다.
// `ShareLink` 와 달리 임의의 `[Any]` 아이템을 다룰 수 있어 이미지 + URL 복합 공유에 적합.

/// `UIActivityViewController` 의 SwiftUI 표상 (UIViewControllerRepresentable).
///
/// 일반적인 사용은 아래의 `.fmShareSheet(...)` modifier 또는 `FMShareLinkButton` 을 권장.
public struct FMShareSheet: UIViewControllerRepresentable {
    public let items: [Any]
    public let excludedActivityTypes: [UIActivity.ActivityType]
    public var onComplete: ((Bool) -> Void)?

    public init(
        items: [Any],
        excludedActivityTypes: [UIActivity.ActivityType] = [],
        onComplete: ((Bool) -> Void)? = nil
    ) {
        self.items = items
        self.excludedActivityTypes = excludedActivityTypes
        self.onComplete = onComplete
    }

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.excludedActivityTypes = excludedActivityTypes
        controller.completionWithItemsHandler = { _, completed, _, _ in
            onComplete?(completed)
        }
        return controller
    }

    public func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

// MARK: - View extension

public extension View {
    /// moodit 표준 share sheet.
    ///
    /// 시트 내부에 시스템 `UIActivityViewController` 를 띄운다.
    /// iOS 17+ 에서 `presentationDetents([.medium, .large])` 로 부드럽게 표시.
    ///
    /// ```swift
    /// .fmShareSheet(isPresented: $showShare, items: [filteredImage])
    /// ```
    func fmShareSheet(
        isPresented: Binding<Bool>,
        items: [Any],
        excludedActivityTypes: [UIActivity.ActivityType] = [],
        onComplete: ((Bool) -> Void)? = nil
    ) -> some View {
        sheet(isPresented: isPresented) {
            FMShareSheet(
                items: items,
                excludedActivityTypes: excludedActivityTypes,
                onComplete: onComplete
            )
        }
    }
}

// MARK: - FMShareLinkButton (ShareLink 표준화)

/// `ShareLink` 위에 moodit 표준 라벨/아이콘을 얹은 헬퍼 (URL 전용 단축).
///
/// 단순 URL 공유는 본 컴포넌트가 `UIActivityViewController` 보다 더 가볍다.
/// 이미지 + URL 복합 공유는 `FMShareSheet` / `.fmShareSheet(...)` 사용.
public struct FMShareLinkButton: View {
    private let url: URL
    private let title: String
    private let systemImage: String

    public init(
        url: URL,
        title: String = "공유",
        systemImage: String = "square.and.arrow.up"
    ) {
        self.url = url
        self.title = title
        self.systemImage = systemImage
    }

    public var body: some View {
        ShareLink(item: url) {
            Label(title, systemImage: systemImage)
        }
        .accessibilityLabel(Text(title))
    }
}

// MARK: - Preview

#Preview("FMShareLinkButton") {
    VStack(spacing: Sp.md) {
        if let url = URL(string: "https://moodit.app") {
            FMShareLinkButton(url: url)
        }
    }
    .padding(Sp.lg)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(FMColors.Background.bg1)
}
