import DesignSystem
import FilterEngine
import Models
import OSLog
import SwiftUI
import UIKit

// MARK: - FilterDetailScreen

/// 필터 상세 — 7번 화면.
///
/// Phase D3 — `mockups/screens/07-filter-detail.html` 와 정합.
/// 비포/애프터 슬라이더 + 메이커 정보 + 통계 + 설명/태그 + 샘플 갤러리 + 댓글 + 하단 CTA.
struct FilterDetailScreen: View {
    @EnvironmentObject private var store: MooditStore
    @Environment(\.dismiss) private var dismiss

    private let filter: Filter?
    private let mock: FilterDetailMock

    @State private var sliderProgress: CGFloat = 0.5
    @State private var downloadState: DownloadState = .ready
    @State private var downloadTask: Task<Void, Never>?
    @State private var downloadErrorMessage: String?
    @State private var isFollowing: Bool = false
    @State private var didLikeMockFilter = false
    @State private var sharePayload: SharePayload?
    @State private var isDescriptionExpanded = false

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
        scrollContent
            .safeAreaInset(edge: .bottom, spacing: 0) {
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
        .sheet(item: $sharePayload) { payload in
            ShareSheet(activityItems: payload.items)
        }
        .onDisappear {
            downloadTask?.cancel()
            downloadTask = nil
        }
        .alert("다운로드 실패", isPresented: Binding(
            get: { downloadErrorMessage != nil },
            set: { if !$0 { downloadErrorMessage = nil } }
        )) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(downloadErrorMessage ?? "")
        }
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

                descriptionSection
                    .padding(.horizontal, Sp.md)

                tagsRow
                    .padding(.horizontal, Sp.md)

                samplesSection

                reviewsSection
                    .padding(.horizontal, Sp.md)
            }
            .padding(.bottom, Sp.xl)
        }
    }

    // MARK: - Before/After

    private var beforeAfterSection: some View {
        GeometryReader { geo in
            ZStack {
                beforeHeroLayer

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
                .overlay {
                    LinearGradient(
                        colors: [.clear, Color.black.opacity(0.25)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
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

    @ViewBuilder
    private var beforeHeroLayer: some View {
        if let url = mock.signatureSampleURL ?? mock.coverURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .overlay {
                            Color.black.opacity(0.18)
                        }
                default:
                    placeholderHeroLayer
                }
            }
        } else {
            placeholderHeroLayer
        }
    }

    private var placeholderHeroLayer: some View {
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
                FMAvatar(initials: mock.makerInitials, size: .md)

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
                .padding(.horizontal, Sp.md)
                .frame(minHeight: 44)
                .foregroundStyle(isFollowing ? FMColors.Text.secondary : .white)
                .background(
                    isFollowing ? FMColors.Background.bg2 : FMColors.Accent.primary,
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
        .buttonStyle(TagPressStyle())
        .accessibilityIdentifier("filter.detail.follow")
        .accessibilityLabel(isFollowing ? "팔로잉" : "팔로우")
        .accessibilityValue(isFollowing ? "선택됨" : "미선택")
        .accessibilityHint(isFollowing ? "이 메이커 팔로우를 해제합니다" : "이 메이커를 팔로우합니다")
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(alignment: .top, spacing: Sp.lg) {
            stat(value: formattedCount(mock.downloadCount), label: "다운로드", isPrimary: true)
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

    private func stat(value: String, label: String, isPrimary: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .fmTypography(isPrimary ? .titleLarge : .title)
                .foregroundStyle(isPrimary ? FMColors.Accent.primary : FMColors.Text.primary)
                .monospacedDigit()
            Text(label.uppercased())
                .font(.system(size: 10, weight: .medium))
                .tracking(0.4)
                .foregroundStyle(FMColors.Text.tertiary)
        }
    }

    // MARK: - Description

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: Sp.xs) {
            Text(mock.description)
                .fmTypography(.body)
                .foregroundStyle(FMColors.Text.secondary)
                .lineLimit(isDescriptionExpanded ? nil : 4)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(mock.description)

            if shouldShowDescriptionToggle {
                Button {
                    isDescriptionExpanded.toggle()
                    FMHaptic.light.play()
                } label: {
                    Text(isDescriptionExpanded ? "접기" : "더 보기")
                        .fmTypography(.subhead)
                        .fontWeight(.semibold)
                        .foregroundStyle(FMColors.Accent.primary)
                        .frame(minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("filter.detail.description.toggle")
                .accessibilityLabel(isDescriptionExpanded ? "설명 접기" : "설명 더 보기")
            }
        }
    }

    private var shouldShowDescriptionToggle: Bool {
        mock.description.count > 120
    }

    // MARK: - Tags

    private var tagsRow: some View {
        // 가로 스크롤이 아니라 wrap 가능한 flow — 간단한 HStack 래핑.
        let columns = [GridItem(.adaptive(minimum: 60, maximum: 200), spacing: Sp.xs, alignment: .leading)]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: Sp.xs) {
            ForEach(mock.tags, id: \.self) { tag in
                NavigationLink(value: AppRoute.search(initialQuery: searchQuery(forTag: tag), category: nil)) {
                    FMTag(tag, style: .accent, size: .sm)
                        .frame(minHeight: 44)
                        .contentShape(Capsule())
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("filter.detail.tag.\(tag)")
                }
                .buttonStyle(TagPressStyle())
                .simultaneousGesture(TapGesture().onEnded { FMHaptic.light.play() })
                .accessibilityIdentifier("filter.detail.tag.\(tag)")
                .accessibilityLabel("\(tag.replacingOccurrences(of: "#", with: "")) 태그")
                .accessibilityHint("이 태그로 검색합니다")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("filter.detail.tags")
    }

    // MARK: - Samples

    private var samplesSection: some View {
        VStack(alignment: .leading, spacing: Sp.sm) {
            sectionHeader(title: "샘플", more: "\(sampleCount)개 모두 →")
                .padding(.horizontal, Sp.md)

            SampleGalleryView(mock: mock)
        }
    }

    private var sampleCount: Int {
        let signatureCount = (mock.signatureSampleURL ?? mock.coverURL) == nil ? 0 : 1
        return signatureCount + EditorReferenceSampleKind.allCases.count
    }

    // MARK: - Reviews

    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: Sp.sm) {
            sectionHeader(title: "리뷰", more: "\(mock.reviewCount)개 →")

            FMCard {
                VStack(spacing: 0) {
                    ForEach(Array(mock.reviews.prefix(3).enumerated()), id: \.element.id) { offset, review in
                        if offset > 0 {
                            Rectangle()
                                .fill(FMColors.Border.subtle)
                                .frame(height: 1)
                                .padding(.vertical, Sp.xs)
                        }
                        reviewRow(review)
                    }
                }
            }
        }
    }

    private func reviewRow(_ review: FilterDetailMock.Review) -> some View {
        HStack(alignment: .top, spacing: Sp.sm) {
            ZStack {
                Circle().fill(review.avatarTint)
                Text(review.initials)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: Sp.xs) {
                    Text(review.name)
                        .fmTypography(.subhead)
                        .fontWeight(.semibold)
                        .foregroundStyle(FMColors.Text.primary)

                    Text(review.timeAgo)
                        .font(.system(size: 10))
                        .foregroundStyle(FMColors.Text.tertiary)

                    Spacer()

                    HStack(spacing: 1) {
                        ForEach(0 ..< 5, id: \.self) { index in
                            Image(systemName: index < review.stars ? "star.fill" : "star")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(index < review.stars ? FMColors.Accent.primary : FMColors.Text.tertiary)
                        }
                    }
                    .accessibilityLabel("\(review.stars)점")

                    if review.isVerifiedDownload {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(FMColors.Accent.primary)
                            .accessibilityLabel("다운로드 확인된 리뷰")
                    }
                }

                Text(review.body)
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
            sharePayload = makeSharePayload()
            FMHaptic.light.play()
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(FMColors.Text.primary)
                .frame(width: 44, height: 44)
                .background(.regularMaterial, in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(FMColors.Border.subtle, lineWidth: 1)
                }
        }
        .accessibilityIdentifier("filter.detail.share")
        .accessibilityLabel("필터 공유")
        .accessibilityHint("이 필터의 링크를 공유합니다")
    }

    /// Universal-link compatible share payload. Server-side parser:
    /// `docs/SCREENS_PLAN.md` Universal Link section. Slug fallback uses the
    /// display title until backend slug propagation lands.
    private func makeSharePayload() -> SharePayload {
        let slug = mock.displayTitle.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "_", with: "-")
        let urlString = "https://moodit.app/f/\(slug)"
        let title = "\(mock.displayTitle) by \(mock.makerHandle)"
        if let url = URL(string: urlString) {
            return SharePayload(items: [title, url])
        }
        return SharePayload(items: [title])
    }

    // MARK: - CTA

    private var ctaBar: some View {
        HStack(spacing: Sp.sm) {
            Button {
                if let filter {
                    store.toggleFavorite(filter)
                } else {
                    didLikeMockFilter.toggle()
                }
                FMHaptic.light.play()
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 17, weight: .semibold))
                    Text(formattedCount(likeDisplayCount))
                        .font(.system(size: 10, weight: .semibold).monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                    .foregroundStyle(isLiked ? FMColors.Accent.primary : FMColors.Text.primary)
                    .frame(width: 52, height: 52)
                    .background(isLiked ? FMColors.Accent.bg : FMColors.Background.bg2, in: RoundedRectangle(cornerRadius: R.md))
                    .overlay {
                        RoundedRectangle(cornerRadius: R.md)
                            .strokeBorder(isLiked ? FMColors.Accent.primary : FMColors.Border.default, lineWidth: 1)
                    }
            }
            .buttonStyle(TagPressStyle())
            .accessibilityLabel(isLiked ? "좋아요 취소" : "좋아요")
            .accessibilityIdentifier("filter.detail.like")
            .accessibilityValue("\(likeDisplayCount)개")

            if downloadState == .ready {
                NavigationLink(value: mock.isPaid ? AppRoute.paywallSingle(filterId: filterRouteID) : AppRoute.filterDownload(id: filterRouteID)) {
                    HStack(spacing: Sp.xs) {
                        Image(systemName: ctaIcon ?? "arrow.right")
                            .font(.system(size: IconSize.sm, weight: .semibold))
                        Text(ctaTitle)
                            .fmTypography(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(FMColors.Accent.primary, in: RoundedRectangle(cornerRadius: R.md))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(mock.isPaid ? "filter.detail.purchase" : "filter.detail.download")
            } else {
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
        }
        .padding(.horizontal, Sp.md)
        .padding(.top, Sp.sm)
        .padding(.bottom, FMLayout.tabBarHeight + Sp.sm)
        .background(FMColors.Background.bg0.opacity(0.96))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(FMColors.Border.default)
                .frame(height: 0.5)
        }
        .shadow(color: Color.black.opacity(0.08), radius: 10, y: -2)
    }

    // MARK: - Sub-helpers

    private func sectionHeader(title: String, more: String?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .fmTypography(.title)
                .foregroundStyle(FMColors.Text.primary)
            Spacer()
            if let more {
                NavigationLink(value: sectionRoute(for: title)) {
                    Text(more)
                        .fmTypography(.subhead)
                        .foregroundStyle(FMColors.Accent.primary)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(title == "리뷰" ? "filter.detail.reviews" : "filter.detail.samples")
            }
        }
    }

    private func sectionRoute(for title: String) -> AppRoute {
        if title == "리뷰" {
            return .reviews(filterId: filterRouteID)
        }
        return .search(initialQuery: mock.displayTitle, category: nil)
    }

    private var filterRouteID: String {
        if let sourceID = mock.sourceID?.trimmingCharacters(in: .whitespacesAndNewlines),
           !sourceID.isEmpty {
            return sourceID
        }
        if let filter {
            return filter.id.uuidString
        }
        return mock.displayTitle
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

    private var isLiked: Bool {
        if let filter {
            return store.isFavorite(filter)
        }
        return didLikeMockFilter
    }

    private var likeDisplayCount: Int {
        mock.likeCount + (isLiked ? 1 : 0)
    }

    private func searchQuery(forTag tag: String) -> String {
        let normalized = tag.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        return "#\(normalized)"
    }

    @MainActor
    private func triggerDownload() {
        switch downloadState {
        case .ready:
            downloadTask?.cancel()
            downloadState = .downloading
            downloadTask = Task { @MainActor in
                do {
                    if let filter {
                        try await store.download(filter)
                    } else {
                        try await Task.sleep(nanoseconds: 300_000_000)
                    }
                    guard !Task.isCancelled else { return }
                    downloadState = .completed
                } catch is CancellationError {
                    return
                } catch {
                    guard !Task.isCancelled else { return }
                    downloadErrorMessage = error.localizedDescription
                    downloadState = .ready
                }
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

// MARK: - Sample Gallery

private struct SampleGalleryView: View {
    let mock: FilterDetailMock

    private var signatureURL: URL? {
        mock.signatureSampleURL ?? mock.coverURL
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Sp.sm) {
                if let signatureURL {
                    SignatureSampleTile(url: signatureURL, categoryHint: mock.categoryHint)
                }

                ForEach(EditorReferenceSampleKind.allCases) { kind in
                    ReferenceSampleTile(
                        kind: kind,
                        category: mock.filterCategory,
                        filterKey: "\(mock.displayTitle)-\(mock.filterCategory.rawValue)"
                    )
                }
            }
            .padding(.horizontal, Sp.md)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("filter.detail.sample.gallery")
    }
}

private struct SignatureSampleTile: View {
    let url: URL
    let categoryHint: Color

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            default:
                samplePlaceholder
            }
        }
        .frame(width: 172, height: 220)
        .clipShape(RoundedRectangle(cornerRadius: R.md))
        .overlay(alignment: .topLeading) {
            sampleBadge("SIGNATURE")
                .padding(Sp.xs)
        }
        .accessibilityLabel("메이커 시그니처 샘플")
        .accessibilityIdentifier("filter.detail.sample.signature")
    }

    private var samplePlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [categoryHint.opacity(0.45), Color.black.opacity(0.55)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "photo")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.white.opacity(0.85))
        }
    }
}

private struct ReferenceSampleTile: View {
    let kind: EditorReferenceSampleKind
    let category: FilterCategory
    let filterKey: String

    @State private var sourceImage: UIImage?
    @State private var renderedImage: UIImage?
    @State private var isRendering = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let image = renderedImage ?? sourceImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.black.opacity(0.08)
            }

            if isRendering {
                Color.black.opacity(0.18)
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            sampleBadge(kind.title)
                .padding(Sp.xs)
        }
        .frame(width: 172, height: 220)
        .clipShape(RoundedRectangle(cornerRadius: R.md))
        .overlay {
            RoundedRectangle(cornerRadius: R.md)
                .strokeBorder(FMColors.Border.subtle, lineWidth: 1)
        }
        .task(id: cacheKey) {
            await render()
        }
        .accessibilityLabel("\(kind.title) 기준 샘플")
        .accessibilityIdentifier("filter.detail.sample.reference.\(kind.rawValue)")
    }

    private var cacheKey: String {
        "detail-reference-\(filterKey)-\(kind.rawValue)"
    }

    @MainActor
    private func render() async {
        let sourceData = EditorReferenceSampleImage.makeJPEGData(kind: kind)
        sourceImage = UIImage(data: sourceData)

        if let cached = await SampleReferenceRenderCache.shared.data(for: cacheKey) {
            renderedImage = UIImage(data: cached)
            return
        }

        isRendering = true
        defer { isRendering = false }

        do {
            let renderedData = try await Task.detached(priority: .userInitiated) {
                let sourceLUT = LUT3D.preset(LUTPreset.preset(for: category), size: 33)
                let renderer = PhotoFilterRenderer(jpegCompressionQuality: 0.86)
                return try renderer.renderJPEG(
                    to: sourceData,
                    sourceLUT: sourceLUT,
                    intensity: .full,
                    cropAspectRatio: nil
                )
            }.value
            await SampleReferenceRenderCache.shared.store(renderedData, for: cacheKey)
            renderedImage = UIImage(data: renderedData)
        } catch {
            renderedImage = sourceImage
        }
    }
}

@ViewBuilder
private func sampleBadge(_ title: String) -> some View {
    Text(title.uppercased())
        .font(.system(size: 10, weight: .bold))
        .foregroundStyle(.white)
        .padding(.horizontal, Sp.xs)
        .padding(.vertical, 4)
        .background(.black.opacity(0.36), in: Capsule())
}

private actor SampleReferenceRenderCache {
    static let shared = SampleReferenceRenderCache()
    private static let logger = Logger(subsystem: "moodit", category: "SampleReferenceRenderCache")

    private var memory: [String: Data] = [:]

    func data(for key: String) -> Data? {
        if let data = memory[key] {
            return data
        }
        guard let url = fileURL(for: key), let data = try? Data(contentsOf: url) else {
            return nil
        }
        memory[key] = data
        return data
    }

    func store(_ data: Data, for key: String) {
        memory[key] = data
        guard let url = fileURL(for: key) else { return }
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: url, options: [.atomic])
        } catch {
            Self.logger.error("Failed to store rendered sample cache: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func fileURL(for key: String) -> URL? {
        guard let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        return base
            .appendingPathComponent("moodit-reference-previews", isDirectory: true)
            .appendingPathComponent(Self.stableFileName(for: key))
    }

    private static func stableFileName(for key: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return String(format: "%016llx.jpg", hash)
    }
}

private struct TagPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.fmFast, value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview("FilterDetailScreen — Free") {
    NavigationStack {
        FilterDetailScreen(mock: FilterDetailMock.preview)
            .environmentObject(MooditStore())
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
                coverURL: m.coverURL,
                signatureSampleURL: m.signatureSampleURL,
                filterCategory: .cinematic,
                reviews: m.reviews,
                categoryHint: FMColors.Category.cinematic,
                isPaid: true,
                priceLabel: "₩2,900"
            )
            return m
        }())
        .environmentObject(MooditStore())
    }
}

#Preview("FilterDetailScreen — Dark") {
    NavigationStack {
        FilterDetailScreen(mock: FilterDetailMock.preview)
            .environmentObject(MooditStore())
    }
    .preferredColorScheme(.dark)
}
