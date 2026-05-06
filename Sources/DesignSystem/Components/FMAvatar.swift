import SwiftUI

// MARK: - FMAvatar

/// 원형 아바타 — 이미지/URL/이니셜 fallback 지원.
///
/// `DESIGN_SYSTEM.md` §8.9 Avatar 정합.
public struct FMAvatar: View {
    public enum Size: Sendable {
        case xs   // 24
        case sm   // 32
        case md   // 48
        case lg   // 64
        case xl   // 96

        var diameter: CGFloat {
            switch self {
            case .xs: 24
            case .sm: 32
            case .md: 48
            case .lg: 64
            case .xl: 96
            }
        }

        var fontSize: CGFloat {
            switch self {
            case .xs: 10
            case .sm: 13
            case .md: 18
            case .lg: 24
            case .xl: 36
            }
        }
    }

    public enum Source: Sendable {
        case image(Image)
        case url(URL?)
        case initials(String)
        case symbol(String)
    }

    private let source: Source
    private let size: Size
    private let fallback: String?

    public init(image: Image, size: Size = .md) {
        self.source = .image(image)
        self.size = size
        self.fallback = nil
    }

    public init(url: URL?, size: Size = .md, fallback: String? = nil) {
        self.source = .url(url)
        self.size = size
        self.fallback = fallback
    }

    public init(initials: String, size: Size = .md) {
        self.source = .initials(initials)
        self.size = size
        self.fallback = nil
    }

    public init(symbol: String, size: Size = .md) {
        self.source = .symbol(symbol)
        self.size = size
        self.fallback = nil
    }

    public var body: some View {
        content
            .frame(width: size.diameter, height: size.diameter)
            .clipShape(Circle())
            .overlay {
                Circle()
                    .strokeBorder(FMColors.Border.subtle, lineWidth: 1)
            }
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        switch source {
        case .image(let image):
            image
                .resizable()
                .scaledToFill()
        case .url(let url):
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure, .empty:
                        fallbackContent
                    @unknown default:
                        fallbackContent
                    }
                }
            } else {
                fallbackContent
            }
        case .initials(let text):
            initialsContent(text)
        case .symbol(let name):
            symbolContent(name)
        }
    }

    @ViewBuilder
    private var fallbackContent: some View {
        if let fallback, !fallback.isEmpty {
            initialsContent(fallback)
        } else {
            symbolContent("person.fill")
        }
    }

    private func initialsContent(_ text: String) -> some View {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(2)
            .uppercased()
        return ZStack {
            FMColors.Background.bg3
            Text(normalized)
                .font(.system(size: size.fontSize, weight: .semibold))
                .foregroundStyle(FMColors.Text.secondary)
        }
    }

    private func symbolContent(_ name: String) -> some View {
        ZStack {
            FMColors.Background.bg3
            Image(systemName: name)
                .font(.system(size: size.fontSize, weight: .regular))
                .foregroundStyle(FMColors.Text.tertiary)
        }
    }
}

// MARK: - Preview

#Preview("FMAvatar — sizes") {
    HStack(spacing: Sp.md) {
        FMAvatar(initials: "유", size: .xs)
        FMAvatar(initials: "JL", size: .sm)
        FMAvatar(initials: "MK", size: .md)
        FMAvatar(symbol: "person.fill", size: .lg)
        FMAvatar(initials: "NY", size: .xl)
    }
    .padding(Sp.md)
    .background(FMColors.Background.bg1)
}

#Preview("FMAvatar — sources") {
    VStack(spacing: Sp.md) {
        HStack(spacing: Sp.md) {
            FMAvatar(initials: "이정민", size: .lg)
            FMAvatar(symbol: "camera.fill", size: .lg)
            FMAvatar(url: URL(string: "https://invalid.example.com/x.jpg"), size: .lg, fallback: "유나")
        }
    }
    .padding(Sp.md)
    .background(FMColors.Background.bg1)
}

#Preview("FMAvatar — Dark") {
    HStack(spacing: Sp.md) {
        FMAvatar(initials: "JL", size: .md)
        FMAvatar(symbol: "person.fill", size: .md)
    }
    .padding(Sp.md)
    .background(FMColors.Background.bg1)
    .preferredColorScheme(.dark)
}
