import DesignSystem
import Models
import SwiftUI

// MARK: - FilterDetailScreen

/// 필터 상세 — 7번 화면.
///
/// Phase D3 — `mockups/screens/07-filter-detail.html` 와 정합.
/// 비포/애프터 슬라이더 + 메이커 정보 + 통계 + 설명/태그 + 샘플 그리드 + 댓글 + 하단 CTA.
struct FilterDetailScreen: View {
    @EnvironmentObject private var store: FilterMarketStore
    @Environment(\.dismiss) private var dismiss

    private let filter: Filter?
    private let mock: FilterDetailMock

    @State private var sliderProgress: CGFloat = 0.5
    @State private var downloadState: DownloadState = .ready
    @State private var isFollowing: Bool = false

    init(filter: Filter, mock: FilterDetailMock? = nil) {
        self.filter = filter
        self.mock = mock ?? FilterDetailMock.mock(for: filter)
    }

    init(mock: FilterDetailMock) {
        self.filter = nil
        self.mock = mock
    }

    /// `MarketplaceScreen` 의 navigationDestination 에서 호출.
    init(mock: FilterDetailMockHashable) {
        self.filter = nil
        self.mock = mock.mock
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            scrollContent
            ctaBar
        }
        .background(FMColors.Background.bg0)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                backButton
            }
            ToolbarItem(placement: .topBarTrailing) {
                shareButton
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    // MARK: - Scroll content

    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.lg) {
                beforeAfterSection

                makerSection
                    .padding(.horizontal, Sp.md)

                statsRow
                    .padding(.horizontal, Sp.md)

                Text(mock.description)
                    .fmTypography(.body)
                    .foregroundStyle(FMColors.Text.secondary)
                    .padding(.horizontal, Sp.md)
                    .fixedSize(horizontal: false, vertical: true)

                tagsRow
                    .padding(.horizontal, Sp.md)

                samplesSection

                commentsSection
                    .padding(.horizontal, Sp.md)
                    .padding(.bottom, 100)
            }
            .padding(.bottom, Sp.xl)
        }
    }

    // MARK: - Before/After

    private var beforeAfterSection: some View {
        GeometryReader { geo in
            ZStack {
                // BEFORE — 더 어두운 placeholder
                LinearGradient(
                    colors: [
                        FMColors.Background.bg3,
                        FMColors.Background.bg1
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay {
                    Image(systemName: "photo")
                        .font(.system(size: 56, weight: .ultraLight))
                        .foregroundStyle(FMColors.Text.tertiary)
                }

                // AFTER — mock 의 카테고리 색을 반영한 그라디언트
                LinearGradient(
                    colors: [
                        mock.categoryHint.opacity(0.55),
                        Color.black.opacity(0.7)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay {
                    Image(systemName: "sparkles")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .mask(alignment: .leading) {
                    Rectangle()
                        .frame(width: max(0, geo.size.width * sliderProgress))
                }

                // 라벨
                HStack {
                    Text("BEFORE")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.5)
                        .padding(.horizontal, Sp.xs + 2)
                        .padding(.vertical, 4)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: R.sm))
                        .foregroundStyle(FMColors.Text.primary)
                    Spacer()
                    Text("AFTER · \(mock.displayTitle.uppercased())")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.5)
                        .lineLimit(1)
                        .padding(.horizontal, Sp.xs + 2)
                        .padding(.vertical, 4)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: R.sm))
                        .foregroundStyle(FMColors.Accent.primary)
                }
                .padding(Sp.sm)
                .frame(maxHeight: .infinity, alignment: .top)

                // 핸들
                handle(in: geo.size)
            }
            .clipped()
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let raw = drag.location.x / max(1, geo.size.width)
                        sliderProgress = min(1, max(0, raw))
                    }
            )
        }
        .aspectRatio(4.0/5.0, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel("비포/애프터 슬라이더")
        .accessibilityValue("\(Int(sliderProgress * 100))%")
        .accessibilityAdjustableAction { direction in
            let step: CGFloat = 0.05
            switch direction {
            case .increment: sliderProgress = min(1, sliderProgress + step)
            case .decrement: sliderProgress = max(0, sliderProgress - step)
            @unknown default: break
            }
        }
    }

    private func handle(in size: CGSize) -> some View {
        let x = max(0, min(size.width, size.width * sliderProgress))
        return ZStack {
            Rectangle()
                .fill(.white)
                .frame(width: 2)
                .shadow(color: Color.black.opacity(0.2), radius: 1, x: 0, y: 0)

            Circle()
                .fill(.white)
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: "arrow.left.and.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(FMColors.Text.primary)
                }
                .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 2)
        }
        .position(x: x, y: size.height / 2)
    }

    // MARK: - Maker

    private var makerSection: some View {
        VStack(alignment: .leading, spacing: Sp.xs) {
            Text(mock.displayTitle)
                .fmTypography(.titleLarge)
                .foregroundStyle(FMColors.Text.primary)

            HStack(spacing: Sp.xs) {
                FMAvatar(initials: mock.makerInitials, size: .xs)

                Text(mock.makerHandle.replacingOccurrences(of: "@", with: ""))
                    .fmTypography(.subhead)
                    .foregroundStyle(FMColors.Text.primary)
                    .fontWeight(.semibold)

                Text("·")
                    .foregroundStyle(FMColors.Text.tertiary)

                Text(mock.categoryLabel)
                    .fmTypography(.subhead)
                    .foregroundStyle(FMColors.Text.tertiary)

                Spacer(minLength: Sp.xs)

                followButton
            }
        }
    }

    private var followButton: some View {
        Button {
            isFollowing.toggle()
            FMHaptic.light.play()
        } label: {
            Text(isFollowing ? "팔로잉" : "팔로우")
                .fmTypography(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, Sp.sm + 2)
                .padding(.vertical, Sp.xxs + 2)
                .foregroundStyle(isFollowing ? FMColors.Text.secondary : FMColors.Accent.primary)
                .background(
                    isFollowing ? FMColors.Background.bg2 : FMColors.Accent.bg,
                    in: RoundedRectangle(cornerRadius: R.md)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: R.md)
                        .strokeBorder(
                            isFollowing ? FMColors.Border.default : FMColors.Accent.primary,
                            lineWidth: 1
                        )
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isFollowing ? "팔로잉 중" : "팔로우")
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(alignment: .top, spacing: Sp.xl) {
            stat(value: formattedCount(mock.downloadCount), label: "다운로드")
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("★")
                    .foregroundStyle(FMColors.Accent.primary)
                stat(value: String(format: "%.1f", mock.rating), label: "\(mock.reviewCount) 리뷰")
                    .padding(.leading, 2)
            }
            stat(value: formattedCount(mock.likeCount), label: "좋아요")
            Spacer(minLength: 0)
        }
        .padding(.vertical, Sp.md)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(FMColors.Border.subtle)
                .frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(FMColors.Border.subtle)
                .frame(height: 1)
        }
    }

    private func stat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .fmTypography(.title)
                .foregroundStyle(FMColors.Text.primary)
                .monospacedDigit()
            Text(label.uppercased())
                .font(.system(size: 10, weight: .medium))
                .tracking(0.4)
                .foregroundStyle(FMColors.Text.tertiary)
        }
    }

    // MARK: - Tags

    private var tagsRow: some View {
        // 가로 스크롤이 아니라 wrap 가능한 flow — 간단한 HStack 래핑.
        let columns = [GridItem(.adaptive(minimum: 60, maximum: 200), spacing: Sp.xs, alignment: .leading)]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: Sp.xs) {
            ForEach(mock.tags, id: \.self) { tag in
                FMTag(tag, style: .outlined, size: .sm)
            }
        }
    }

    // MARK: - Samples

    private var samplesSection: some View {
        VStack(alignment: .leading, spacing: Sp.sm) {
            sectionHeader(title: "샘플", more: "\(mock.sampleSymbols.count + 3)개 모두 →")
                .padding(.horizontal, Sp.md)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 4),
                    GridItem(.flexible(), spacing: 4),
                    GridItem(.flexible(), spacing: 4)
                ],
                spacing: 4
            ) {
                ForEach(Array(mock.sampleSymbols.enumerated()), id: \.offset) { _, symbol in
                    sampleTile(symbol: symbol)
                }
            }
            .padding(.horizontal, Sp.md)
        }
    }

    private func sampleTile(symbol: String) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    mock.categoryHint.opacity(0.4),
                    Color.black.opacity(0.45)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(.white.opacity(0.85))
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: R.sm))
        .accessibilityHidden(true)
    }

    // MARK: - Comments

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: Sp.sm) {
            sectionHeader(title: "댓글", more: "\(mock.reviewCount)개 →")

            FMCard {
                VStack(spacing: 0) {
                    ForEach(Array(mock.comments.prefix(3).enumerated()), id: \.element.id) { offset, comment in
                        if offset > 0 {
                            Rectangle()
                                .fill(FMColors.Border.subtle)
                                .frame(height: 1)
                                .padding(.vertical, Sp.xs)
                        }
                        commentRow(comment)
                    }
                }
            }
        }
    }

    private func commentRow(_ comment: FilterDetailMock.Comment) -> some View {
        HStack(alignment: .top, spacing: Sp.sm) {
            ZStack {
                Circle().fill(comment.avatarTint)
                Text(comment.initials)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: Sp.xs) {
                    Text(comment.name)
                        .fmTypography(.subhead)
                        .fontWeight(.semibold)
                        .foregroundStyle(FMColors.Text.primary)

                    Text(comment.timeAgo)
                        .font(.system(size: 10))
                        .foregroundStyle(FMColors.Text.tertiary)
                }

                Text(comment.body)
                    .fmTypography(.subhead)
                    .foregroundStyle(FMColors.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Toolbar buttons

    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(FMColors.Text.primary)
                .frame(width: 36, height: 36)
                .background(.regularMaterial, in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(FMColors.Border.subtle, lineWidth: 1)
                }
        }
        .accessibilityLabel("뒤로")
    }

    private var shareButton: some View {
        Button {
            // 공유 — 후속 Phase.
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(FMColors.Text.primary)
                .frame(width: 36, height: 36)
                .background(.regularMaterial, in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(FMColors.Border.subtle, lineWidth: 1)
                }
        }
        .accessibilityLabel("공유")
    }

    // MARK: - CTA

    private var ctaBar: some View {
        HStack(spacing: Sp.xs) {
            Button {
                // 좋아요 — 후속 Phase.
                FMHaptic.light.play()
            } label: {
                Image(systemName: "heart")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(FMColors.Text.primary)
                    .frame(width: 52, height: 52)
                    .background(FMColors.Background.bg2, in: RoundedRectangle(cornerRadius: R.md))
                    .overlay {
                        RoundedRectangle(cornerRadius: R.md)
                            .strokeBorder(FMColors.Border.default, lineWidth: 1)
                    }
            }
            .accessibilityLabel("좋아요")

            FMButton(
                ctaTitle,
                icon: ctaIcon,
                variant: .primary,
                size: .lg,
                isLoading: downloadState == .downloading
            ) {
                triggerDownload()
            }
        }
        .padding(.horizontal, Sp.md)
        .padding(.top, Sp.sm)
        .padding(.bottom, Sp.xs)
        .background(.regularMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(FMColors.Border.subtle)
                .frame(height: 1)
        }
    }

    // MARK: - Sub-helpers

    private func sectionHeader(title: String, more: String?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .fmTypography(.title)
                .foregroundStyle(FMColors.Text.primary)
            Spacer()
            if let more {
                Button {
                    // 후속 Phase.
                } label: {
                    Text(more)
                        .fmTypography(.subhead)
                        .foregroundStyle(FMColors.Accent.primary)
                }
            }
        }
    }

    private var ctaTitle: String {
        switch downloadState {
        case .ready:
            mock.isPaid ? (mock.priceLabel.map { "\($0) 구매" } ?? "구매") : "무료 다운로드"
        case .downloading:
            "다운로드 중..."
        case .completed:
            "촬영하기"
        }
    }

    private var ctaIcon: String? {
        switch downloadState {
        case .ready: "arrow.down.to.line"
        case .downloading: nil
        case .completed: "camera.fill"
        }
    }

    @MainActor
    private func triggerDownload() {
        switch downloadState {
        case .ready:
            downloadState = .downloading
            if let filter {
                store.download(filter)
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 900_000_000)
                downloadState = .completed
            }
        case .downloading:
            break
        case .completed:
            // 카메라로 이동 — 후속 Phase 에서 라우팅.
            dismiss()
        }
    }

    private func formattedCount(_ count: Int) -> String {
        switch count {
        case ..<1_000: "\(count)"
        case 1_000..<10_000: String(format: "%.1fK", Double(count) / 1_000)
        default: "\(count / 1_000)K"
        }
    }

    // MARK: - Download state

    private enum DownloadState: Equatable {
        case ready
        case downloading
        case completed
    }
}

// MARK: - Preview

#Preview("FilterDetailScreen — Free") {
    NavigationStack {
        FilterDetailScreen(mock: FilterDetailMock.preview)
            .environmentObject(FilterMarketStore())
    }
}

#Preview("FilterDetailScreen — Paid") {
    NavigationStack {
        FilterDetailScreen(mock: {
            var m = FilterDetailMock.preview
            m = FilterDetailMock(
                displayTitle: "Velvet Dusk",
                makerHandle: "@yuna.studio",
                makerInitials: "YN",
                categoryLabel: "시네마틱",
                downloadCount: 6_320,
                rating: 4.9,
                reviewCount: 142,
                likeCount: 1_200,
                description: m.description,
                tags: m.tags,
                sampleSymbols: m.sampleSymbols,
                comments: m.comments,
                categoryHint: FMColors.Category.cinematic,
                isPaid: true,
                priceLabel: "₩2,900"
            )
            return m
        }())
        .environmentObject(FilterMarketStore())
    }
}

#Preview("FilterDetailScreen — Dark") {
    NavigationStack {
        FilterDetailScreen(mock: FilterDetailMock.preview)
            .environmentObject(FilterMarketStore())
    }
    .preferredColorScheme(.dark)
}
