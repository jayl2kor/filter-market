import SwiftUI

// MARK: - FMEmptyState.Kind

/// 빈 상태 카탈로그 — `EMPTY_STATES.md` 참조.
public enum FMEmptyStateKind: Sendable {
    case emptyMarket
    case noSearchResults(query: String)
    case emptyProfile(isOwnProfile: Bool, makerName: String?)
    case emptyDownloads
    case emptyReviews(isLoggedIn: Bool)
    case emptyBlocklist
    case emptyFollowers
    case emptyFollowing

    var illustration: FMEmptyStateIllustration.Kind {
        switch self {
        case .emptyMarket: .market
        case .noSearchResults: .search
        case .emptyProfile: .profile
        case .emptyDownloads: .downloads
        case .emptyReviews: .comments
        case .emptyBlocklist: .blocklist
        case .emptyFollowers, .emptyFollowing: .profile
        }
    }

    var headline: String {
        switch self {
        case .emptyMarket:
            "아직 올라온 필터가 없어요"
        case .noSearchResults(let query):
            "\"\(query)\"에 맞는 필터가 없어요"
        case .emptyProfile(let isOwn, let maker):
            isOwn ? "아직 만든 필터가 없어요" : "\(maker ?? "메이커")의 필터가 곧 공개돼요"
        case .emptyDownloads:
            "다운로드한 필터가 없어요"
        case .emptyReviews:
            "첫 번째 리뷰를 남겨보세요"
        case .emptyBlocklist:
            "차단한 사용자가 없어요"
        case .emptyFollowers:
            "아직 팔로워가 없어요"
        case .emptyFollowing:
            "아직 팔로잉한 메이커가 없어요"
        }
    }

    var subtext: String? {
        switch self {
        case .emptyMarket:
            "첫 메이커가 되어보세요.\n독창적인 필터를 만들고 세상에 선보이세요."
        case .noSearchResults:
            "다른 검색어를 시도하거나\n카테고리에서 둘러볼까요?"
        case .emptyProfile(let isOwn, _):
            isOwn ? "나만의 감성을 담은 첫 필터를 만들어보세요.\n메이커로서의 여정을 시작하는 순간입니다." : nil
        case .emptyDownloads:
            "마켓에서 마음에 드는 필터를 찾아보세요.\n다운로드하면 오프라인에서도 사용할 수 있어요."
        case .emptyReviews(let isLoggedIn):
            isLoggedIn
                ? "메이커에게 감상을 전해주세요.\n별점과 함께 남기면 더욱 생생하게 전달돼요."
                : "리뷰를 남기려면 로그인이 필요해요."
        case .emptyBlocklist:
            "차단한 사용자는 이곳에 표시됩니다."
        case .emptyFollowers:
            "필터를 만들고 공유하면\n팬이 생기기 시작해요."
        case .emptyFollowing:
            "마음에 드는 메이커를 팔로우하면\n새 필터를 가장 먼저 만나볼 수 있어요."
        }
    }

    var primaryCTA: String? {
        switch self {
        case .emptyMarket: "필터 만들기"
        case .noSearchResults: "카테고리 둘러보기"
        case .emptyProfile(let isOwn, _): isOwn ? "첫 필터 만들기" : nil
        case .emptyDownloads: "마켓 둘러보기"
        case .emptyReviews(let isLoggedIn): isLoggedIn ? "리뷰 쓰기" : "로그인"
        case .emptyBlocklist: nil
        // 팔로우 빈 상태의 CTA는 NavigationLink로 호출 측에서 직접 그린다.
        case .emptyFollowers: nil
        case .emptyFollowing: nil
        }
    }
}

// MARK: - FMEmptyState

/// 빈 상태를 일관된 구조로 표시.
///
/// 일러스트 + 헤드라인 + 서브텍스트 + 1차 CTA.
public struct FMEmptyState: View {
    private let kind: FMEmptyStateKind
    private let ctaTitle: String?
    private let action: (() -> Void)?

    public init(
        _ kind: FMEmptyStateKind,
        ctaTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.kind = kind
        self.ctaTitle = ctaTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: Sp.xl) {
            illustration
                .frame(width: 96, height: 96)

            VStack(spacing: Sp.xs) {
                Text(kind.headline)
                    .fmTypography(.headline)
                    .foregroundStyle(FMColors.Text.primary)
                    .multilineTextAlignment(.center)

                if let subtext = kind.subtext {
                    Text(subtext)
                        .fmTypography(.body)
                        .foregroundStyle(FMColors.Text.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
            }

            if let cta = ctaTitle ?? kind.primaryCTA, let action {
                FMButton(cta, variant: .primary, size: .md, action: action)
                    .frame(maxWidth: 240)
            }
        }
        .padding(.horizontal, Sp.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(kind.headline)
    }

    @ViewBuilder
    private var illustration: some View {
        FMEmptyStateIllustration(kind.illustration, size: 96)
    }
}

// MARK: - Preview

#Preview("Empty market") {
    FMEmptyState(.emptyMarket) {}
        .background(FMColors.Background.bg1)
}

#Preview("No search results") {
    FMEmptyState(.noSearchResults(query: "야경")) {}
        .background(FMColors.Background.bg1)
}

#Preview("Empty profile (own)") {
    FMEmptyState(.emptyProfile(isOwnProfile: true, makerName: nil)) {}
        .background(FMColors.Background.bg1)
}

#Preview("Empty profile (other)") {
    FMEmptyState(.emptyProfile(isOwnProfile: false, makerName: "유나"), action: nil)
        .background(FMColors.Background.bg1)
}

#Preview("Empty downloads") {
    FMEmptyState(.emptyDownloads) {}
        .background(FMColors.Background.bg1)
}

#Preview("Empty reviews (logged in)") {
    FMEmptyState(.emptyReviews(isLoggedIn: true)) {}
        .background(FMColors.Background.bg1)
}

#Preview("Empty reviews (logged out)") {
    FMEmptyState(.emptyReviews(isLoggedIn: false)) {}
        .background(FMColors.Background.bg1)
}

#Preview("Empty blocklist") {
    FMEmptyState(.emptyBlocklist)
        .background(FMColors.Background.bg1)
}

#Preview("Empty followers") {
    FMEmptyState(.emptyFollowers)
        .background(FMColors.Background.bg1)
}

#Preview("Empty following") {
    FMEmptyState(.emptyFollowing)
        .background(FMColors.Background.bg1)
}

#Preview("Empty state — Dark") {
    FMEmptyState(.emptyMarket) {}
        .background(FMColors.Background.bg1)
        .preferredColorScheme(.dark)
}
