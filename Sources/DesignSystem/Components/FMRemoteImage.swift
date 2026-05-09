import SwiftUI

// MARK: - FMRemoteImage

/// Standard remote image surface with fixed sizing, loading, and failure states.
public struct FMRemoteImage<Placeholder: View, Failure: View>: View {
    private let url: URL?
    private let aspectRatio: CGFloat?
    private let cornerRadius: CGFloat
    private let contentMode: ContentMode
    private let placeholder: () -> Placeholder
    private let failure: () -> Failure

    public init(
        url: URL?,
        aspectRatio: CGFloat? = nil,
        cornerRadius: CGFloat = 0,
        contentMode: ContentMode = .fill,
        @ViewBuilder placeholder: @escaping () -> Placeholder,
        @ViewBuilder failure: @escaping () -> Failure
    ) {
        self.url = url
        self.aspectRatio = aspectRatio
        self.cornerRadius = cornerRadius
        self.contentMode = contentMode
        self.placeholder = placeholder
        self.failure = failure
    }

    public var body: some View {
        content
            .modifier(FMRemoteImageAspect(aspectRatio: aspectRatio, contentMode: contentMode))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    @ViewBuilder
    private var content: some View {
        if let url {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    placeholder()
                case .success(let image):
                    image
                        .resizable()
                        .modifier(FMRemoteImageScaling(contentMode: contentMode))
                case .failure:
                    failure()
                @unknown default:
                    placeholder()
                }
            }
        } else {
            failure()
        }
    }
}

private struct FMRemoteImageAspect: ViewModifier {
    let aspectRatio: CGFloat?
    let contentMode: ContentMode

    @ViewBuilder
    func body(content: Content) -> some View {
        if let aspectRatio {
            content.aspectRatio(aspectRatio, contentMode: contentMode)
        } else {
            content
        }
    }
}

private struct FMRemoteImageScaling: ViewModifier {
    let contentMode: ContentMode

    @ViewBuilder
    func body(content: Content) -> some View {
        switch contentMode {
        case .fit:
            content.scaledToFit()
        case .fill:
            content.scaledToFill()
        }
    }
}
