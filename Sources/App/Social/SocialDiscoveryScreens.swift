import DesignSystem
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import Foundation
import Models
import SwiftUI

// MARK: - Reviews

struct ReviewsListScreen: View {
    @EnvironmentObject private var store: MooditStore

    let filterID: String
    // (#37) 프로덕션은 Firestore /filters/{filterID}/reviews listener (.task에서 attach).
    // UI 테스트 (-ui-testing): 기존 mock 데이터로 fallback.
    @State private var rawReviews: [SocialReview] = isUITesting ? SocialReview.mock : []
    @State private var reviews: [SocialReview] = isUITesting ? SocialReview.mock : []
    @State private var helpfulIDs: Set<String> = isUITesting ? Set(SocialReview.mock.filter(\.isHelpful).map(\.id)) : []
    @State private var blockedAuthorUIDs: Set<String> = []
    @State private var moreMenuReview: SocialReview?
    @State private var reviewsListener: ListenerRegistration?
    @State private var helpfulListener: ListenerRegistration?
    @State private var blocksListener: ListenerRegistration?
    @State private var filterSummary = ReviewFilterSummary()
    @State private var blockStatusMessage: String?
    @State private var editingReview: SocialReview?
    @State private var replyReview: SocialReview?
    @State private var deletingReview: SocialReview?

    var body: some View {
        VStack(spacing: 0) {
            filterMiniCard
            list
            composeBar
        }
        .background(FMColors.Background.bg1)
        .navigationTitle("리뷰 \(reviews.count)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: AppRoute.rating(filterId: filterID)) {
                    Image(systemName: "star")
                }
                .accessibilityLabel("평점 등록")
            }
        }
        .confirmationDialog(
            "리뷰 옵션",
            isPresented: Binding(
                get: { moreMenuReview != nil },
                set: { if !$0 { moreMenuReview = nil } }
            ),
            titleVisibility: .visible,
            presenting: moreMenuReview
        ) { review in
            if isOwnReview(review) {
                Button("리뷰 수정") {
                    editingReview = review
                }
                .accessibilityIdentifier("social.review.more.edit")

                Button("리뷰 삭제", role: .destructive) {
                    deletingReview = review
                }
                .accessibilityIdentifier("social.review.more.delete")
            } else {
                Button("답글") {
                    replyReview = review
                }
                .accessibilityIdentifier("social.review.more.reply")

                NavigationLink(value: AppRoute.reportForm(target: .review(id: review.id, filterId: filterID, authorUid: review.authorUid))) {
                    Text("이 리뷰 신고")
                }
                .accessibilityIdentifier("social.review.more.report")

                Button("작성자 차단", role: .destructive) {
                    Task { await blockAuthor(review) }
                }
                .accessibilityIdentifier("social.review.more.block")
            }

            Button("리뷰 텍스트 복사") {
                UIPasteboard.general.string = review.body
                FMHaptic.success.play()
            }
            .accessibilityIdentifier("social.review.more.copy")

            Button("취소", role: .cancel) {}
        } message: { review in
            Text("\(review.name) (\(review.handle))")
        }
        .confirmationDialog(
            "리뷰를 삭제할까요?",
            isPresented: Binding(
                get: { deletingReview != nil },
                set: { if !$0 { deletingReview = nil } }
            ),
            titleVisibility: .visible,
            presenting: deletingReview
        ) { review in
            Button("삭제", role: .destructive) {
                Task { await deleteReview(review) }
            }
            Button("취소", role: .cancel) {}
        } message: { _ in
            Text("삭제한 리뷰는 되돌릴 수 없습니다.")
        }
        .sheet(item: $editingReview) { review in
            NavigationStack {
                ReviewComposeScreen(filterID: filterID, initialReview: review)
            }
            .environmentObject(store)
        }
        .sheet(item: $replyReview) { review in
            NavigationStack {
                ReviewComposeScreen(filterID: filterID, initialText: "\(review.handle) ")
            }
            .environmentObject(store)
        }
        .task {
            // (#37) Firestore listener attach. UI test fallback은 mock 데이터를 그대로 사용.
            guard !isUITesting else { return }
            applyLocalFilterSummary()
            attachReviewsListener()
            attachHelpfulListener()
            attachBlocksListener()
            await loadFilterSummary()
        }
        .onDisappear {
            reviewsListener?.remove()
            reviewsListener = nil
            helpfulListener?.remove()
            helpfulListener = nil
            blocksListener?.remove()
            blocksListener = nil
        }
        .alert(
            "작성자 차단",
            isPresented: Binding(
                get: { blockStatusMessage != nil },
                set: { if !$0 { blockStatusMessage = nil } }
            )
        ) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(blockStatusMessage ?? "")
        }
    }

    /// /filters/{filterID}/reviews.order(by: createdAt desc).limit(50) listener.
    private func attachReviewsListener() {
        reviewsListener?.remove()
        reviewsListener = Firestore.firestore()
            .collection("filters").document(filterID)
            .collection("reviews")
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .addSnapshotListener { snapshot, _ in
                let docs = snapshot?.documents ?? []
                let decoded = docs.compactMap { doc -> SocialReview? in
                    let data = doc.data()
                    let body = data["body"] as? String ?? ""
                    let authorUid = data["authorUid"] as? String ?? "unknown"
                    let authorName = data["authorDisplayName"] as? String
                        ?? data["authorName"] as? String
                        ?? "사용자"
                    let authorHandle = data["authorHandle"] as? String
                        ?? "@\(authorUid.prefix(8))"
                    let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                    let initials = String(authorName.prefix(2)).uppercased()
                    let interval = Date().timeIntervalSince(createdAt)
                    let timeStr: String
                    if interval < 60 { timeStr = "방금 전" }
                    else if interval < 3600 { timeStr = "\(Int(interval / 60))분" }
                    else if interval < 86400 { timeStr = "\(Int(interval / 3600))시간" }
                    else { timeStr = "\(Int(interval / 86400))일" }
                    return SocialReview(
                        id: doc.documentID,
                        authorUid: authorUid,
                        name: authorName,
                        handle: authorHandle,
                        initials: initials,
                        avatarColors: [Color(hex: 0xF3DCC4), Color(hex: 0xD4A482)],
                        time: timeStr,
                        body: body,
                        stars: Self.intField(data["stars"], default: Self.intField(data["rating"], default: 0)),
                        photoURL: Self.urlField(data["photoUrl"])
                            ?? Self.urlField(data["imageURL"])
                            ?? Self.urlField(data["imageUrl"]),
                        helpfulCount: Self.intField(data["helpfulCount"], default: 0),
                        isHelpful: false,
                        isVerifiedDownload: data["isVerifiedDownload"] as? Bool ?? false,
                        makerReply: nil
                    )
                }
                Task { @MainActor in
                    self.rawReviews = decoded
                    self.applyBlockedReviewFilter()
                }
            }
    }

    private static func intField(_ value: Any?, default defaultValue: Int) -> Int {
        if let int = value as? Int { return int }
        if let number = value as? NSNumber { return number.intValue }
        if let double = value as? Double { return Int(double) }
        if let string = value as? String, let int = Int(string) { return int }
        return defaultValue
    }

    private static func doubleField(_ value: Any?) -> Double? {
        if let double = value as? Double { return double }
        if let int = value as? Int { return Double(int) }
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String { return Double(string) }
        return nil
    }

    private static func urlField(_ value: Any?) -> URL? {
        guard let string = value as? String else { return nil }
        return URL(string: string)
    }

    private func applyLocalFilterSummary() {
        guard let uuid = UUID(uuidString: filterID),
              let filter = store.filters.first(where: { $0.id == uuid }) else {
            return
        }
        filterSummary = ReviewFilterSummary(
            title: filter.title,
            makerName: filter.author.displayName,
            categoryRawValue: filter.category.rawValue,
            downloadCount: filter.downloadCount > 0 ? filter.downloadCount : filter.useCount,
            ratingAvg: filter.ratingAvg,
            coverURL: filter.coverURL
        )
    }

    private func loadFilterSummary() async {
        do {
            let snapshot = try await Firestore.firestore()
                .collection("filters").document(filterID)
                .getDocument()
            guard let data = snapshot.data() else { return }
            let author = data["author"] as? [String: Any]
            let coverURL = (data["coverURL"] as? String).flatMap(URL.init(string:))
            filterSummary = ReviewFilterSummary(
                title: data["title"] as? String,
                makerName: (author?["displayName"] as? String) ?? data["authorDisplayName"] as? String,
                categoryRawValue: data["category"] as? String,
                downloadCount: Self.intField(data["downloadCount"], default: Self.intField(data["useCount"], default: 0)),
                ratingAvg: Self.doubleField(data["ratingAvg"]),
                coverURL: coverURL
            )
        } catch {
            // Keep the local summary/fallback; the reviews listener still owns list content.
        }
    }

    private func attachHelpfulListener() {
        helpfulListener?.remove()
        guard let uid = Auth.auth().currentUser?.uid else {
            helpfulIDs = []
            return
        }
        helpfulListener = Firestore.firestore()
            .collection("users").document(uid)
            .collection("reviewHelpful")
            .whereField("filterId", isEqualTo: filterID)
            .addSnapshotListener { snapshot, _ in
                let ids = Set((snapshot?.documents ?? []).compactMap { $0.data()["reviewId"] as? String })
                Task { @MainActor in
                    self.helpfulIDs = ids
                }
            }
    }

    private func attachBlocksListener() {
        blocksListener?.remove()
        guard let uid = Auth.auth().currentUser?.uid else {
            blockedAuthorUIDs = []
            applyBlockedReviewFilter()
            return
        }
        blocksListener = Firestore.firestore()
            .collection("blocks")
            .whereField("actorUid", isEqualTo: uid)
            .limit(to: 200)
            .addSnapshotListener { snapshot, error in
                Task { @MainActor in
                    if let error {
                        blockStatusMessage = "차단 목록을 불러오지 못했어요: \(error.localizedDescription)"
                        return
                    }
                    blockedAuthorUIDs = Set((snapshot?.documents ?? []).compactMap { $0.data()["targetUid"] as? String })
                    applyBlockedReviewFilter()
                }
            }
    }

    private func applyBlockedReviewFilter() {
        reviews = rawReviews.filter { !blockedAuthorUIDs.contains($0.authorUid) }
    }

    private var filterMiniCard: some View {
        NavigationLink(value: AppRoute.filterDetail(id: filterID)) {
            HStack(spacing: Sp.sm) {
                filterMiniCover
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: R.sm))

                VStack(alignment: .leading, spacing: 2) {
                    Text(filterMiniTitle)
                        .fmTypography(.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(FMColors.Text.primary)
                        .lineLimit(1)
                    Text(isUITesting ? "@sample.maker · ★ 4.9 · ↓ 6.2K" : filterMiniSubtitle)
                        .fmTypography(.caption)
                        .foregroundStyle(FMColors.Text.tertiary)
                        .lineLimit(1)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FMColors.Text.tertiary)
            }
            .padding(.horizontal, Sp.md)
            .padding(.vertical, Sp.sm)
            .background(FMColors.Background.bg2)
            .overlay(alignment: .bottom) {
                Rectangle().fill(FMColors.Border.subtle).frame(height: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("social.reviews.filter")
    }

    @ViewBuilder
    private var filterMiniCover: some View {
        FMRemoteImage(
            url: filterSummary.coverURL,
            cornerRadius: R.sm,
            placeholder: {
                FMSkeleton.rect(height: 36, cornerRadius: R.sm)
            },
            failure: {
                filterMiniPlaceholder
            }
        )
    }

    private var filterMiniPlaceholder: some View {
        FMFilterCoverArt(
            motif: FilterCoverMotifResolver.motif(
                for: filterSummary.title ?? filterID,
                category: filterSummary.categoryRawValue
            )
        )
    }

    private var filterMiniTitle: String {
        if let title = filterSummary.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            return title
        }
        return UUID(uuidString: filterID) == nil ? filterID : "필터 정보 로딩 중"
    }

    private var filterMiniSubtitle: String {
        var parts: [String] = []
        if let makerName = filterSummary.makerName?.trimmingCharacters(in: .whitespacesAndNewlines), !makerName.isEmpty {
            parts.append("@\(makerName)")
        }
        if let ratingAvg = filterSummary.ratingAvg, ratingAvg > 0 {
            parts.append("★ \(String(format: "%.1f", ratingAvg))")
        }
        if let downloadCount = filterSummary.downloadCount {
            parts.append("↓ \(formattedDownloadCount(downloadCount))")
        }
        return parts.isEmpty ? "리뷰 목록" : parts.joined(separator: " · ")
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(reviews) { review in
                    reviewRow(review)
                    if let reply = review.makerReply {
                        makerReplyRow(reply)
                            .padding(.leading, 44)
                    }
                }
            }
            .padding(.horizontal, Sp.md)
            .padding(.bottom, Sp.lg)
        }
    }

    private var composeBar: some View {
        HStack(spacing: Sp.sm) {
            avatar(initials: "HB", colors: [Color(hex: 0xB9D2E8), Color(hex: 0x4A6A90)], size: 32)

            NavigationLink(value: store.isAuthenticated ? AppRoute.reviewCompose(filterId: filterID) : AppRoute.login) {
                Text(store.isAuthenticated ? "리뷰 추가..." : "로그인하고 리뷰 남기기")
                    .fmTypography(.subhead)
                    .foregroundStyle(FMColors.Text.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Sp.sm)
                    .frame(height: 40)
                    .background(FMColors.Background.bg2, in: Capsule())
                    .overlay {
                        Capsule().strokeBorder(FMColors.Border.default, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("social.reviews.compose")

            NavigationLink(value: store.isAuthenticated ? AppRoute.reviewCompose(filterId: filterID) : AppRoute.login) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(FMColors.Text.inverse)
                    .frame(width: 36, height: 36)
                    .background(FMColors.Accent.primary, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("리뷰 보내기")
        }
        .padding(.horizontal, Sp.md)
        .padding(.top, Sp.sm)
        .padding(.bottom, Sp.sm)
        .background(FMColors.Background.bg1)
        .overlay(alignment: .top) {
            Rectangle().fill(FMColors.Border.subtle).frame(height: 1)
        }
    }

    private func reviewRow(_ review: SocialReview) -> some View {
        let isOwn = isOwnReview(review)
        return HStack(alignment: .top, spacing: Sp.sm) {
            NavigationLink(value: AppRoute.otherProfile(uid: review.authorUid)) {
                avatar(initials: review.initials, colors: review.avatarColors, size: 36)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(review.name)
                        .fmTypography(.subhead)
                        .fontWeight(.semibold)
                        .foregroundStyle(FMColors.Text.primary)
                    Text(review.handle)
                        .fmTypography(.caption)
                        .foregroundStyle(FMColors.Text.tertiary)
                    if isOwn {
                        Text("내 리뷰")
                            .fmTypography(.caption)
                            .foregroundStyle(FMColors.Accent.primary)
                            .padding(.horizontal, Sp.xs)
                            .padding(.vertical, 2)
                            .background(FMColors.Accent.bg, in: Capsule())
                    }
                    Spacer()
                    Text(review.time)
                        .fmTypography(.caption)
                        .foregroundStyle(FMColors.Text.tertiary)
                }

                HStack(spacing: 6) {
                    starsRow(review.stars)
                    if review.isVerifiedDownload {
                        Text("다운로드 확인")
                            .fmTypography(.caption)
                            .foregroundStyle(FMColors.Accent.primary)
                            .accessibilityIdentifier("social.review.verified")
                    }
                }

                Text(review.body)
                    .fmTypography(.body)
                    .foregroundStyle(FMColors.Text.primary)
                    .fixedSize(horizontal: false, vertical: true)

                if let photoURL = review.photoURL {
                    reviewImage(url: photoURL)
                }

                HStack(spacing: Sp.md) {
                    Button {
                        Task { await toggleHelpful(review) }
                    } label: {
                        Label("\(review.helpfulCount)", systemImage: helpfulIDs.contains(review.id) ? "hand.thumbsup.fill" : "hand.thumbsup")
                    }
                    .foregroundStyle(helpfulIDs.contains(review.id) ? FMColors.Accent.primary : FMColors.Text.tertiary)
                    .accessibilityIdentifier("social.review.helpful")

                    Button("···") {
                        moreMenuReview = review
                    }
                    .foregroundStyle(FMColors.Text.tertiary)
                    .accessibilityIdentifier("social.review.more")
                }
                .fmTypography(.caption)
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, Sp.sm)
        .padding(.horizontal, isOwn ? Sp.xs : 0)
        .background(isOwn ? FMColors.Accent.bg.opacity(0.28) : Color.clear, in: RoundedRectangle(cornerRadius: R.md))
        .overlay(alignment: .bottom) {
            Rectangle().fill(FMColors.Border.subtle).frame(height: 1)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if isOwn {
                Button {
                    editingReview = review
                    FMHaptic.selection.play()
                } label: {
                    Label("수정", systemImage: "pencil")
                }
                .tint(.blue)

                Button(role: .destructive) {
                    deletingReview = review
                    FMHaptic.warning.play()
                } label: {
                    Label("삭제", systemImage: "trash")
                }
            } else {
                Button {
                    replyReview = review
                    FMHaptic.selection.play()
                } label: {
                    Label("답글", systemImage: "arrowshape.turn.up.left")
                }
                .tint(.blue)

                Button(role: .destructive) {
                    Task { await blockAuthor(review) }
                } label: {
                    Label("차단", systemImage: "person.crop.circle.badge.xmark")
                }

                Button(role: .destructive) {
                    moreMenuReview = review
                } label: {
                    Label("신고", systemImage: "exclamationmark.bubble")
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(reviewAccessibilityLabel(review))
        .accessibilityHint(isOwn ? "수정 또는 삭제할 수 있습니다" : "옵션에서 답글, 신고, 차단을 사용할 수 있습니다")
        .accessibilityIdentifier("social.review.row")
    }

    private func reviewImage(url: URL) -> some View {
        FMRemoteImage(
            url: url,
            cornerRadius: R.md,
            placeholder: {
                FMSkeleton.rect(height: 160, cornerRadius: R.md)
            },
            failure: {
                RoundedRectangle(cornerRadius: R.md)
                    .fill(FMColors.Background.bg2)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(FMColors.Text.tertiary)
                    }
            }
        )
        .frame(maxWidth: .infinity)
        .frame(height: 160)
        .accessibilityLabel("리뷰 첨부 사진")
        .accessibilityIdentifier("social.review.image")
    }

    private func makerReplyRow(_ reply: SocialMakerReply) -> some View {
        HStack(alignment: .top, spacing: Sp.sm) {
            avatar(initials: reply.initials, colors: reply.avatarColors, size: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("메이커 답글")
                        .fmTypography(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(FMColors.Accent.primary)
                    Text(reply.handle)
                        .fmTypography(.caption)
                        .foregroundStyle(FMColors.Text.tertiary)
                    Spacer()
                    Text(reply.time)
                        .fmTypography(.caption)
                        .foregroundStyle(FMColors.Text.tertiary)
                }

                Text(reply.body)
                    .fmTypography(.body)
                    .foregroundStyle(FMColors.Text.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, Sp.sm)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("social.review.makerReply.row")
    }

    private func starsRow(_ stars: Int) -> some View {
        HStack(spacing: 2) {
            ForEach(0 ..< 5, id: \.self) { index in
                Image(systemName: index < stars ? "star.fill" : "star")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(index < stars ? FMColors.Accent.primary : FMColors.Text.tertiary)
            }
        }
        .accessibilityIdentifier("social.review.stars")
        .accessibilityLabel("\(stars)점")
    }

    private func toggleHelpful(_ review: SocialReview) async {
        FMHaptic.selection.play()
        #if DEBUG
        guard !isUITesting else {
            if helpfulIDs.contains(review.id) {
                helpfulIDs.remove(review.id)
            } else {
                helpfulIDs.insert(review.id)
            }
            return
        }
        #endif
        guard Auth.auth().currentUser?.uid != nil else {
            FMHaptic.warning.play()
            return
        }

        let wasHelpful = helpfulIDs.contains(review.id)
        if wasHelpful {
            helpfulIDs.remove(review.id)
        } else {
            helpfulIDs.insert(review.id)
        }

        do {
            let callable = Functions.functions(region: "asia-northeast3").httpsCallable("markReviewHelpful")
            _ = try await callable.call([
                "filterId": filterID,
                "reviewId": review.id,
                "helpful": !wasHelpful,
            ])
            FMHaptic.success.play()
        } catch {
            if wasHelpful {
                helpfulIDs.insert(review.id)
            } else {
                helpfulIDs.remove(review.id)
            }
            FMHaptic.warning.play()
        }
    }

    @MainActor
    private func blockAuthor(_ review: SocialReview) async {
        FMHaptic.warning.play()
        #if DEBUG
        guard !isUITesting else {
            rawReviews.removeAll { $0.authorUid == review.authorUid }
            applyBlockedReviewFilter()
            blockStatusMessage = "\(review.handle) 작성자를 차단했어요."
            FMHaptic.success.play()
            return
        }
        #endif
        guard let uid = Auth.auth().currentUser?.uid else {
            blockStatusMessage = "로그인 후 작성자를 차단할 수 있어요."
            return
        }
        guard uid != review.authorUid, review.authorUid != "unknown" else {
            blockStatusMessage = "이 작성자는 차단할 수 없어요."
            return
        }

        rawReviews.removeAll { $0.authorUid == review.authorUid }
        applyBlockedReviewFilter()

        do {
            try await Firestore.firestore()
                .collection("blocks").document("\(uid)_\(review.authorUid)")
                .setData([
                    "actorUid": uid,
                    "targetUid": review.authorUid,
                    "targetHandle": review.handle,
                    "targetDisplayName": review.name,
                    "createdAt": FieldValue.serverTimestamp()
                ], merge: true)
            blockStatusMessage = "\(review.handle) 작성자를 차단했어요."
            FMHaptic.success.play()
        } catch {
            blockStatusMessage = "작성자를 차단하지 못했어요: \(error.localizedDescription)"
            FMHaptic.warning.play()
            attachReviewsListener()
        }
    }

    private func isOwnReview(_ review: SocialReview) -> Bool {
        #if DEBUG
        if isUITesting {
            return store.isAuthenticated && review.authorUid == "minji.lab"
        }
        #endif
        return Auth.auth().currentUser?.uid == review.authorUid
    }

    private func reviewAccessibilityLabel(_ review: SocialReview) -> String {
        let ownership = isOwnReview(review) ? "내 리뷰" : "리뷰"
        let verified = review.isVerifiedDownload ? ", 다운로드 확인" : ""
        return "\(ownership), \(review.name), \(review.time), 별점 \(review.stars)점\(verified), \(review.body)"
    }

    @MainActor
    private func deleteReview(_ review: SocialReview) async {
        FMHaptic.warning.play()
        guard isOwnReview(review) else {
            blockStatusMessage = "내 리뷰만 삭제할 수 있어요."
            deletingReview = nil
            return
        }
        let previousRaw = rawReviews
        rawReviews.removeAll { $0.id == review.id }
        applyBlockedReviewFilter()
        deletingReview = nil

        do {
            let callable = Functions.functions(region: "asia-northeast3").httpsCallable("deleteReview")
            _ = try await callable.call([
                "filterId": filterID,
                "reviewId": review.id,
            ])
            FMHaptic.success.play()
        } catch {
            rawReviews = previousRaw
            applyBlockedReviewFilter()
            blockStatusMessage = "리뷰를 삭제하지 못했어요: \(error.localizedDescription)"
            FMHaptic.warning.play()
        }
    }
}

private enum ReviewComposeError: LocalizedError {
    case imageEncodingFailed
    case imageTooLarge
    case invalidUploadResponse
    case imageUploadFailed

    var errorDescription: String? {
        switch self {
        case .imageEncodingFailed:
            "첨부 사진을 처리하지 못했어요."
        case .imageTooLarge:
            "첨부 사진 용량이 너무 커요. 다른 사진을 선택해주세요."
        case .invalidUploadResponse:
            "사진 업로드 정보를 읽지 못했어요."
        case .imageUploadFailed:
            "첨부 사진 업로드에 실패했어요."
        }
    }
}

struct ReviewComposeScreen: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: MooditStore

    let filterID: String
    private let initialReview: SocialReview?
    @State private var text = ""
    @State private var rating = 0
    @State private var selectedMention: UUID?
    @State private var showingPhotoPicker = false
    @State private var attachedImage: UIImage?
    @State private var showingEmojiPicker = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private let mentions = SocialUser.mentionSuggestions
    private let limit = 280

    init(filterID: String) {
        self.filterID = filterID
        self.initialReview = nil
        _text = State(initialValue: "")
        _rating = State(initialValue: 0)
    }

    fileprivate init(filterID: String, initialText: String = "", initialReview: SocialReview? = nil) {
        self.filterID = filterID
        self.initialReview = initialReview
        _text = State(initialValue: initialReview?.body ?? initialText)
        _rating = State(initialValue: initialReview?.stars ?? 0)
    }

    /// Curated emoji palette for review composition. Tied to the moodit
    /// aesthetic — warmth/light/film vocabulary, not generic chat emojis.
    private static let emojiPalette: [String] = [
        "✨", "🌅", "🌇", "🌙", "☕️", "📷", "🎞️", "🌿",
        "🌸", "💛", "🤎", "🔥", "✏️", "🖼", "🎨", "🌊",
    ]

    private func insertAtMention() {
        // Append "@" so the existing mention box (driven by `text.contains("@")`)
        // surfaces. Add a leading space if the text doesn't already end in
        // whitespace — keeps tokens visually separated.
        let separator = (text.last?.isWhitespace ?? true) ? "" : " "
        updateText("\(text)\(separator)@")
        FMHaptic.selection.play()
    }

    private func insertEmoji(_ emoji: String) {
        updateText("\(text)\(emoji)")
        FMHaptic.selection.play()
    }

    private func updateText(_ value: String) {
        text = String(value.prefix(limit))
        errorMessage = nil
    }

    private func selectRating(_ value: Int) {
        let next = min(max(value, 1), 5)
        guard next != rating else { return }
        rating = next
        errorMessage = nil
        if rating == 5 {
            FMHaptic.success.play()
        } else {
            FMHaptic.light.play()
        }
    }

    /// Cloud Function submitReview를 통해 다운로드/구매 이력이 검증된 리뷰만 작성/수정한다 (#64).
    /// 실패 시 화면 유지 + haptic 에러; 성공 시 dismiss.
    private func submitReview() async {
        guard !isSubmitting else { return }
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard body.count >= 5 else {
            errorMessage = "리뷰는 5자 이상 입력해주세요."
            FMHaptic.warning.play()
            return
        }
        guard rating > 0 else {
            errorMessage = "별점을 선택해주세요."
            FMHaptic.warning.play()
            return
        }
        #if DEBUG
        guard !isUITesting else {
            FMHaptic.success.play()
            dismiss()
            return
        }
        #endif
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "로그인이 필요합니다."
            FMHaptic.warning.play()
            return
        }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let upload = try await uploadAttachedImageIfNeeded(uid: uid)
            let callable = Functions.functions(region: "asia-northeast3").httpsCallable("submitReview")
            var payload: [String: Any] = [
                "filterId": filterID,
                "stars": rating,
                "body": body,
            ]
            if let upload {
                payload["photoUrl"] = upload.publicURL.absoluteString
                payload["photoObjectKey"] = upload.objectKey
            }
            _ = try await callable.call(payload)
            FMHaptic.success.play()
            dismiss()
        } catch {
            errorMessage = "리뷰 작성 실패: \(error.localizedDescription)"
            FMHaptic.warning.play()
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if store.isAuthenticated {
                editor
                toolbar
            } else {
                loginGate
            }
        }
        .background(FMColors.Background.bg1)
        .navigationTitle(initialReview == nil ? "새 리뷰" : "리뷰 수정")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("취소") { dismiss() }
                    .foregroundStyle(FMColors.Text.secondary)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(initialReview == nil ? "게시" : "저장") {
                    Task { await submitReview() }
                }
                .fontWeight(.bold)
                .foregroundStyle(canPost ? FMColors.Accent.primary : FMColors.Text.tertiary)
                .disabled(!canPost)
                .accessibilityIdentifier("social.compose.send")
            }
        }
        .sheet(isPresented: $showingPhotoPicker) {
            PhotoPicker { image in
                attachedImage = image
                errorMessage = nil
            }
        }
    }

    private var canPost: Bool {
        !isSubmitting &&
        rating > 0 &&
        text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 5 &&
        text.count <= limit
    }

    private struct ReviewImageUpload {
        let publicURL: URL
        let objectKey: String
    }

    private func uploadAttachedImageIfNeeded(uid: String) async throws -> ReviewImageUpload? {
        guard let attachedImage else { return nil }
        guard let imageData = normalizedJPEGData(from: attachedImage) else {
            throw ReviewComposeError.imageEncodingFailed
        }
        guard imageData.count <= 2_500_000 else {
            throw ReviewComposeError.imageTooLarge
        }

        let callable = Functions.functions(region: "asia-northeast3").httpsCallable("reviewImageUploadInit")
        let result = try await callable.call([
            "filterId": filterID,
            "contentType": "image/jpeg",
            "imageBytes": imageData.count,
        ])
        guard let data = result.data as? [String: Any],
              let uploadURLString = data["uploadUrl"] as? String,
              let uploadURL = URL(string: uploadURLString),
              let publicURLString = data["publicURL"] as? String,
              let publicURL = URL(string: publicURLString),
              let objectKey = data["objectKey"] as? String else {
            throw ReviewComposeError.invalidUploadResponse
        }

        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        request.httpBody = imageData
        let headers = data["uploadHeaders"] as? [String: String] ?? [:]
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw ReviewComposeError.imageUploadFailed
        }
        return ReviewImageUpload(publicURL: publicURL, objectKey: objectKey)
    }

    private func reviewAuthorDisplayName(uid: String) -> String {
        let profileName = store.editableProfile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !profileName.isEmpty { return profileName }
        #if DEBUG
        if isUITesting {
            return "테스트 사용자"
        }
        #endif
        return Auth.auth().currentUser?.displayName
            ?? Auth.auth().currentUser?.email?.split(separator: "@").first.map(String.init)
            ?? String(uid.prefix(8))
    }

    private func reviewAuthorHandle(uid: String) -> String {
        let handle = store.editableProfile.handle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !handle.isEmpty { return handle.hasPrefix("@") ? handle : "@\(handle)" }
        #if DEBUG
        if isUITesting {
            return "@tester"
        }
        #endif
        return "@\(uid.prefix(8))"
    }

    private func normalizedJPEGData(from image: UIImage) -> Data? {
        let maxLongEdge: CGFloat = 1600
        let sourceSize = image.size
        let longest = max(sourceSize.width, sourceSize.height)
        let scale = longest > maxLongEdge ? maxLongEdge / longest : 1
        let targetSize = CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let normalized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return normalized.jpegData(compressionQuality: 0.86)
    }

    private var editor: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.md) {
                HStack(spacing: Sp.xs) {
                    avatar(initials: "HB", colors: [Color(hex: 0xB9D2E8), Color(hex: 0x4A6A90)], size: 32)
                    Text(reviewAuthorDisplayName(uid: currentAuthorUID))
                        .fmTypography(.subhead)
                        .fontWeight(.semibold)
                        .foregroundStyle(FMColors.Text.primary)
                    Text(UUID(uuidString: filterID) != nil ? "필터에 답글" : "↩ \(filterID)에 답글")
                        .fmTypography(.caption)
                        .foregroundStyle(FMColors.Text.tertiary)
                }

                ratingInput

                VStack(alignment: .leading, spacing: Sp.xs) {
                    Text("리뷰 작성")
                        .fmTypography(.caption)
                        .foregroundStyle(FMColors.Text.secondary)

                    TextEditor(text: Binding(
                        get: { text },
                        set: { updateText($0) }
                    ))
                    .font(.system(size: 17))
                    .foregroundStyle(FMColors.Text.primary)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.return)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 180)
                    .overlay(alignment: .topLeading) {
                        if text.isEmpty {
                            Text("이 필터에 대한 의견을 남겨주세요")
                                .fmTypography(.body)
                                .foregroundStyle(FMColors.Text.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
                    .accessibilityLabel("리뷰 본문")
                    .accessibilityIdentifier("social.compose.input")

                    HStack {
                        Text(validationText)
                            .fmTypography(.caption)
                            .foregroundStyle(validationTint)
                        Spacer()
                        Text("\(text.count) / \(limit)")
                            .fmTypography(.caption)
                            .monospacedDigit()
                            .foregroundStyle(text.count >= limit ? FMColors.Semantic.warning : FMColors.Text.tertiary)
                            .accessibilityHidden(true)
                    }
                }

                if let image = attachedImage {
                    attachedImagePreview(image)
                }

                if let errorMessage {
                    inlineMessage(errorMessage, tint: FMColors.Semantic.error, icon: "exclamationmark.triangle.fill")
                }

                if showingEmojiPicker {
                    emojiPalette
                }

                if text.contains("@") || isUITesting {
                    mentionBox
                }
            }
            .padding(Sp.md)
        }
    }

    private var ratingInput: some View {
        VStack(alignment: .leading, spacing: Sp.xs) {
            Text("별점")
                .fmTypography(.caption)
                .foregroundStyle(FMColors.Text.secondary)

            HStack(spacing: Sp.xs) {
                ForEach(1...5, id: \.self) { value in
                    Button {
                        selectRating(value)
                    } label: {
                        Image(systemName: value <= rating ? "star.fill" : "star")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(value <= rating ? FMColors.Accent.primary : FMColors.Text.tertiary)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("별점 \(value)점")
                    .accessibilityValue("5점 만점")
                    .accessibilityIdentifier("social.compose.rating.star.\(value)")
                }
                Spacer()
                Text(ratingLabel)
                    .fmTypography(.caption)
                    .foregroundStyle(rating > 0 ? FMColors.Accent.primary : FMColors.Text.tertiary)
                    .accessibilityIdentifier("social.compose.rating.label")
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { value in
                        let starWidth: CGFloat = 44 + Sp.xs
                        let selected = Int((value.location.x / starWidth).rounded(.up))
                        selectRating(selected)
                    }
            )
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("social.compose.rating")
        }
    }

    private var ratingLabel: String {
        switch rating {
        case 1: "별로예요"
        case 2: "그저 그래요"
        case 3: "괜찮아요"
        case 4: "좋아요"
        case 5: "최고예요"
        default: "별점을 선택해주세요"
        }
    }

    private var validationText: String {
        let count = text.trimmingCharacters(in: .whitespacesAndNewlines).count
        if count == 0 { return "5자 이상 입력해주세요" }
        if count < 5 { return "조금만 더 자세히 적어주세요" }
        return "게시할 준비가 되었어요"
    }

    private var validationTint: Color {
        text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 5
            ? FMColors.Text.tertiary
            : FMColors.Semantic.warning
    }

    private func inlineMessage(_ message: String, tint: Color, icon: String) -> some View {
        Label(message, systemImage: icon)
            .fmTypography(.caption)
            .foregroundStyle(tint)
            .padding(Sp.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: R.sm))
            .accessibilityIdentifier("social.compose.error")
    }

    private var emojiPalette: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: Sp.sm), count: 8)
        return LazyVGrid(columns: columns, spacing: Sp.sm) {
            ForEach(Self.emojiPalette, id: \.self) { emoji in
                Button {
                    insertEmoji(emoji)
                } label: {
                    Text(emoji)
                        .font(.system(size: 22))
                        .frame(width: 36, height: 36)
                        .background(FMColors.Background.bg2, in: RoundedRectangle(cornerRadius: R.sm))
                }
                .accessibilityLabel(emoji)
                .accessibilityIdentifier("social.compose.emoji.\(emoji)")
            }
        }
        .padding(Sp.sm)
        .background(FMColors.Background.bg1, in: RoundedRectangle(cornerRadius: R.md))
        .overlay {
            RoundedRectangle(cornerRadius: R.md).strokeBorder(FMColors.Border.subtle, lineWidth: 1)
        }
        .accessibilityIdentifier("social.compose.emojiPalette")
    }

    private func attachedImagePreview(_ image: UIImage) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: 240)
                .clipShape(RoundedRectangle(cornerRadius: R.md))
                .accessibilityIdentifier("social.compose.attachedImage")
            Button {
                attachedImage = nil
                FMHaptic.light.play()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.white, .black.opacity(0.55))
                    .padding(Sp.xs)
            }
            .accessibilityLabel("첨부 사진 제거")
            .accessibilityIdentifier("social.compose.removeImage")
        }
        .overlay {
            RoundedRectangle(cornerRadius: R.md).strokeBorder(FMColors.Border.subtle, lineWidth: 1)
        }
    }

    private var mentionBox: some View {
        VStack(spacing: 0) {
            ForEach(mentions) { user in
                Button {
                    selectedMention = user.id
                    if let range = text.range(of: "@", options: .backwards) {
                        updateText(text.replacingCharacters(in: range.lowerBound..<text.endIndex, with: "\(user.handle) "))
                    }
                    FMHaptic.selection.play()
                } label: {
                    HStack(spacing: Sp.sm) {
                        avatar(initials: user.initials, colors: user.avatarColors, size: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.name)
                                .fmTypography(.subhead)
                                .fontWeight(.semibold)
                                .foregroundStyle(FMColors.Text.primary)
                            Text(user.handle + (user.badge.map { " · \($0)" } ?? ""))
                                .fmTypography(.caption)
                                .foregroundStyle(FMColors.Text.tertiary)
                        }
                        Spacer()
                        if let badge = user.badge {
                            Text(badge)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(FMColors.Accent.primary)
                                .padding(.horizontal, Sp.xs)
                                .padding(.vertical, 3)
                                .background(FMColors.Accent.bg, in: Capsule())
                        }
                    }
                    .padding(.horizontal, Sp.md)
                    .padding(.vertical, Sp.xs)
                    .background(selectedMention == user.id ? FMColors.Accent.bg : Color.clear)
                }
                .buttonStyle(.plain)

                if user.id != mentions.last?.id {
                    Rectangle().fill(FMColors.Border.subtle).frame(height: 1)
                }
            }
        }
        .background(FMColors.Background.bg2, in: RoundedRectangle(cornerRadius: R.md))
        .overlay {
            RoundedRectangle(cornerRadius: R.md).strokeBorder(FMColors.Border.default, lineWidth: 1)
        }
        .accessibilityIdentifier("social.compose.mentions")
    }

    private var toolbar: some View {
        HStack(spacing: Sp.md) {
            Button {
                insertAtMention()
            } label: {
                Image(systemName: "at")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(FMColors.Text.secondary)
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel("@멘션")
            .accessibilityIdentifier("social.compose.insertMention")
            Button {
                showingPhotoPicker = true
            } label: {
                Image(systemName: "photo")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(FMColors.Text.secondary)
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel("이미지 첨부")
            .accessibilityIdentifier("social.compose.attachImage")
            Button {
                showingEmojiPicker.toggle()
            } label: {
                Image(systemName: "face.smiling")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(showingEmojiPicker ? FMColors.Accent.primary : FMColors.Text.secondary)
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel("이모지")
            .accessibilityIdentifier("social.compose.emojiToggle")
            Spacer()
            Text("\(text.count) / \(limit)")
                .fmTypography(.caption)
                .monospacedDigit()
                .foregroundStyle(text.count > limit ? FMColors.Semantic.warning : FMColors.Text.tertiary)
        }
        .padding(.horizontal, Sp.md)
        .padding(.vertical, Sp.sm)
        .background(FMColors.Background.bg1)
        .overlay(alignment: .top) {
            Rectangle().fill(FMColors.Border.subtle).frame(height: 1)
        }
    }

    private var currentAuthorUID: String {
        #if DEBUG
        if isUITesting {
            return "ui-test-user"
        }
        #endif
        return Auth.auth().currentUser?.uid ?? ""
    }

    private var loginGate: some View {
        VStack(spacing: Sp.md) {
            FMEmptyState(.emptyReviews(isLoggedIn: false))
            NavigationLink(value: AppRoute.login) {
                FMButton("로그인하고 리뷰 쓰기", icon: "person.crop.circle", variant: .primary, size: .lg) {}
            }
            .buttonStyle(.plain)
        }
        .padding(Sp.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Rating

struct RatingFormScreen: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: MooditStore

    let filterID: String
    @State private var rating = 0
    @State private var selectedTags: Set<String> = []
    @State private var reviewBody = ""
    @State private var errorMessage: String?

    private let tags = ["자연스러움", "강도 조절 좋음", "카페 잘 어울림", "셀카 좋음", "여행", "실내 광원"]
    private let bodyLimit = 280

    /// (#28) Firestore /filters/{id}/ratings/{uid}에 평점 + 코멘트 저장.
    /// uid 키로 1개만 — 재제출 시 덮어쓰기.
    private func submitRating() async {
        guard rating > 0 else { return }
        guard let uid = Auth.auth().currentUser?.uid else {
            FMHaptic.warning.play()
            errorMessage = "로그인이 필요합니다."
            return
        }
        let payload: [String: Any] = [
            "authorUid": uid,
            "filterId": filterID,
            "rating": rating,
            "tags": Array(selectedTags),
            "body": reviewBody.trimmingCharacters(in: .whitespacesAndNewlines),
            "updatedAt": FieldValue.serverTimestamp(),
        ]
        do {
            try await Firestore.firestore()
                .collection("filters").document(filterID)
                .collection("ratings").document(uid)
                .setData(payload, merge: true)
            FMHaptic.success.play()
            dismiss()
        } catch {
            FMHaptic.warning.play()
            errorMessage = "평점 등록 실패: \(error.localizedDescription)"
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            FMFilterCoverArt(motif: FilterCoverMotifResolver.motif(for: filterID, category: nil))
                .opacity(0.28)
                .ignoresSafeArea()
            Color.black.opacity(0.34).ignoresSafeArea()

            if store.isAuthenticated {
                sheet
            } else {
                loginSheet
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var sheet: some View {
        VStack(spacing: Sp.md) {
            Capsule()
                .fill(FMColors.Background.bg3)
                .frame(width: 36, height: 4)

            VStack(spacing: 4) {
                Text("평점 남기기")
                    .fmTypography(.headline)
                    .foregroundStyle(FMColors.Text.primary)
                Text(UUID(uuidString: filterID) != nil ? "필터" : filterID)
                    .fmTypography(.subhead)
                    .foregroundStyle(FMColors.Text.secondary)
            }

            HStack(spacing: Sp.xs) {
                ForEach(1...5, id: \.self) { value in
                    Button {
                        rating = value
                        FMHaptic.selection.play()
                    } label: {
                        Image(systemName: value <= rating ? "star.fill" : "star")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(value <= rating ? FMColors.Accent.primary : FMColors.Text.tertiary)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("social.rating.star.\(value)")
                }
            }

            Text(rating == 0 ? "별점을 선택해주세요" : ratingLabel)
                .fmTypography(.headline)
                .fontWeight(.bold)
                .foregroundStyle(rating == 0 ? FMColors.Text.secondary : FMColors.Accent.primary)

            FlowLayout(spacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    FMChip(tag, isSelected: selectedTags.contains(tag), size: .sm) {
                        if selectedTags.contains(tag) {
                            selectedTags.remove(tag)
                        } else {
                            selectedTags.insert(tag)
                        }
                    }
                }
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: limitedReviewBody)
                    .font(.body)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.return)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 88)
                    .padding(Sp.xs)
                    .background(FMColors.Background.bg1, in: RoundedRectangle(cornerRadius: R.md))
                    .overlay {
                        RoundedRectangle(cornerRadius: R.md).strokeBorder(FMColors.Border.default, lineWidth: 1)
                    }
                    .accessibilityIdentifier("social.rating.body")
                if reviewBody.isEmpty {
                    Text("이 필터에 대한 의견을 남겨주세요 (선택)")
                        .font(.body)
                        .foregroundStyle(FMColors.Text.tertiary)
                        .padding(.horizontal, Sp.sm)
                        .padding(.vertical, Sp.sm)
                }
            }

            HStack {
                if let errorMessage {
                    Text(errorMessage)
                        .fmTypography(.caption)
                        .foregroundStyle(FMColors.Semantic.error)
                }
                Spacer()
                Text("\(reviewBody.count) / \(bodyLimit)")
                    .fmTypography(.caption)
                    .foregroundStyle(FMColors.Text.tertiary)
                    .monospacedDigit()
            }

            HStack(spacing: Sp.xs) {
                FMButton("건너뛰기", variant: .secondary, size: .lg) {
                    dismiss()
                }
                FMButton("평점 등록", variant: .primary, size: .lg) {
                    Task { await submitRating() }
                }
                .disabled(rating == 0)
                .accessibilityIdentifier("social.rating.submit")
            }
        }
        .padding(.horizontal, Sp.md)
        .padding(.top, 8)
        .padding(.bottom, Sp.md)
        .background(FMColors.Surface.raised)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: R.xl, topTrailingRadius: R.xl))
    }

    private var loginSheet: some View {
        VStack(spacing: Sp.md) {
            Capsule()
                .fill(FMColors.Background.bg3)
                .frame(width: 36, height: 4)
            FMEmptyState(.emptyReviews(isLoggedIn: false))
            NavigationLink(value: AppRoute.login) {
                FMButton("로그인하고 평점 남기기", icon: "star", variant: .primary, size: .lg) {}
            }
            .buttonStyle(.plain)
        }
        .padding(Sp.md)
        .background(FMColors.Surface.raised)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: R.xl, topTrailingRadius: R.xl))
    }

    private var ratingLabel: String {
        switch rating {
        case 0: "별점을 선택해주세요"
        case 1: "아쉬워요"
        case 2: "조금 아쉬워요"
        case 3: "괜찮아요"
        case 4: "좋아요"
        default: "최고예요!"
        }
    }

    private var limitedReviewBody: Binding<String> {
        Binding(
            get: { reviewBody },
            set: { reviewBody = String($0.prefix(bodyLimit)) }
        )
    }
}

// MARK: - Follow Lists

struct FollowersListScreen: View {
    let userID: String
    @State private var query = ""
    // (#38) 프로덕션은 Firestore /users/{userID}/followers listener (별도 작업)에서 채워짐.
    // UI 테스트(-ui-testing): 기존 mock fallback.
    @State private var users: [SocialUser] = isUITesting ? SocialUser.followers : []

    var body: some View {
        FollowListScreen(
            mode: .followers,
            userID: userID,
            query: $query,
            users: $users
        )
    }
}

struct FollowingListScreen: View {
    let userID: String
    @State private var query = ""
    // (#38) 프로덕션은 Firestore /users/{userID}/following listener (별도 작업)에서 채워짐.
    // UI 테스트(-ui-testing): 기존 mock fallback.
    @State private var users: [SocialUser] = isUITesting ? SocialUser.following : []

    var body: some View {
        FollowListScreen(
            mode: .following,
            userID: userID,
            query: $query,
            users: $users
        )
    }
}

private struct FollowListScreen: View {
    enum Mode {
        case followers
        case following
    }

    let mode: Mode
    let userID: String
    @Binding var query: String
    @Binding var users: [SocialUser]
    @State private var titleHandle: String = ""
    @State private var followerCount: Int = 0
    @State private var followingCount: Int = 0
    @State private var isRefreshing = false
    @State private var listListener: ListenerRegistration?
    @State private var profileListener: ListenerRegistration?

    private var normalizedUserID: String {
        userID.replacingOccurrences(of: "@", with: "")
    }

    private var filteredUsers: [SocialUser] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return users }
        return users.filter {
            $0.name.lowercased().contains(normalized) || $0.handle.lowercased().contains(normalized)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            segment
            searchField
            list
        }
        .background(FMColors.Background.bg1)
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            attachRealtimeData()
        }
        .onDisappear {
            listListener?.remove()
            profileListener?.remove()
            listListener = nil
            profileListener = nil
        }
    }

    private var segment: some View {
        HStack(spacing: 0) {
            segmentLink(title: "팔로워 \(followerCount.formatted())", route: .followers(uid: userID), isActive: mode == .followers)
            segmentLink(title: "팔로잉 \(followingCount.formatted())", route: .following(uid: userID), isActive: mode == .following)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(FMColors.Border.subtle).frame(height: 1)
        }
    }

    private func segmentLink(title: String, route: AppRoute, isActive: Bool) -> some View {
        NavigationLink(value: route) {
            Text(title)
                .fmTypography(.callout)
                .fontWeight(isActive ? .semibold : .medium)
                .foregroundStyle(isActive ? FMColors.Text.primary : FMColors.Text.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Sp.sm)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(isActive ? FMColors.Accent.primary : Color.clear)
                        .frame(height: 2)
                }
        }
        .buttonStyle(.plain)
    }

    private var searchField: some View {
        HStack(spacing: Sp.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(FMColors.Text.tertiary)
            TextField(mode == .followers ? "팔로워 검색" : "팔로잉 검색", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .accessibilityIdentifier(mode == .followers ? "social.followers.search" : "social.following.search")
        }
        .padding(.horizontal, Sp.sm)
        .frame(height: 44)
        .background(FMColors.Background.bg2, in: RoundedRectangle(cornerRadius: R.md))
        .overlay {
            RoundedRectangle(cornerRadius: R.md).strokeBorder(FMColors.Border.default, lineWidth: 1)
        }
        .padding(.horizontal, Sp.md)
        .padding(.top, Sp.sm)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if filteredUsers.isEmpty {
                    FMEmptyState(.emptyMarket)
                        .padding(.vertical, Sp.lg)
                        .accessibilityIdentifier(mode == .followers ? "social.followers.empty" : "social.following.empty")
                } else if mode == .following {
                    groupLabel("최근 활동 있음")
                    ForEach(filteredUsers.filter { $0.newFilterCount > 0 }) { user in
                        userRow(user)
                    }
                    groupLabel("전체")
                }

                ForEach(mode == .following ? filteredUsers.filter { $0.newFilterCount == 0 } : filteredUsers) { user in
                    userRow(user)
                }
            }
            .padding(.horizontal, Sp.md)
            .padding(.bottom, FMLayout.tabBarHeight + Sp.xxxl)
        }
        .refreshable {
            await refreshFollowList()
        }
    }

    private func userRow(_ user: SocialUser) -> some View {
        HStack(spacing: Sp.sm) {
            NavigationLink(value: AppRoute.otherProfile(uid: user.handle)) {
                HStack(spacing: Sp.sm) {
                    ZStack(alignment: .bottomTrailing) {
                        avatar(initials: user.initials, colors: user.avatarColors, size: 44)
                        if user.newFilterCount > 0 {
                            Text("\(user.newFilterCount)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 16, height: 16)
                                .background(FMColors.Accent.primary, in: Circle())
                                .overlay {
                                    Circle().strokeBorder(FMColors.Background.bg1, lineWidth: 2)
                                }
                                .accessibilityHidden(true)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(user.name)
                                .fmTypography(.callout)
                                .fontWeight(.semibold)
                                .foregroundStyle(FMColors.Text.primary)
                            if user.newFilterCount > 0 {
                                Text("새 필터 \(user.newFilterCount)")
                                    .fmTypography(.caption)
                                    .foregroundStyle(FMColors.Accent.primary)
                            }
                        }
                        Text(user.meta)
                            .fmTypography(.caption)
                            .foregroundStyle(FMColors.Text.tertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(userAccessibilityLabel(user))
            .accessibilityHint("탭하면 프로필을 봅니다")

            followButton(user)
        }
        .padding(.vertical, Sp.sm)
        .overlay(alignment: .bottom) {
            Rectangle().fill(FMColors.Border.subtle).frame(height: 1)
        }
        .accessibilityIdentifier("social.user.row")
    }

    private func userAccessibilityLabel(_ user: SocialUser) -> String {
        var parts = [user.name, user.meta]
        if user.newFilterCount > 0 {
            parts.append("새 필터 \(user.newFilterCount)")
        }
        return parts.joined(separator: ", ")
    }

    private func followButton(_ user: SocialUser) -> some View {
        Button {
            Task { await toggleFollow(user) }
        } label: {
            Text(user.relationship.label)
                .fmTypography(.subhead)
                .fontWeight(.semibold)
                .foregroundStyle(user.relationship.foreground)
                .padding(.horizontal, Sp.md)
                .frame(height: 32)
                .background(user.relationship.background, in: RoundedRectangle(cornerRadius: R.md))
                .overlay {
                    RoundedRectangle(cornerRadius: R.md)
                        .strokeBorder(user.relationship.border, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("social.follow.toggle")
    }

    private var navigationTitle: String {
        if !titleHandle.isEmpty { return titleHandle }
        if userID == "me" { return "@me" }
        return normalizedUserID.hasPrefix("@") ? normalizedUserID : "@\(normalizedUserID)"
    }

    private func attachRealtimeData() {
        guard !isUITesting else {
            followerCount = SocialUser.followers.count
            followingCount = SocialUser.following.count
            titleHandle = userID == "me" ? "@me" : "@sample.maker"
            return
        }
        let db = Firestore.firestore()
        profileListener?.remove()
        profileListener = db.collection("users").document(normalizedUserID)
            .addSnapshotListener { snapshot, _ in
                let data = snapshot?.data() ?? [:]
                let handle = (data["handle"] as? String) ?? ""
                titleHandle = handle.isEmpty ? "@\(normalizedUserID.prefix(8))" : (handle.hasPrefix("@") ? handle : "@\(handle)")
                followerCount = (data["followerCount"] as? Int) ?? 0
                followingCount = (data["followingCount"] as? Int) ?? 0
            }

        listListener?.remove()
        let field = mode == .followers ? "targetUid" : "actorUid"
        listListener = db.collection("follows")
            .whereField(field, isEqualTo: normalizedUserID)
            .limit(to: 100)
            .addSnapshotListener { snapshot, _ in
                let docs = snapshot?.documents ?? []
                Task {
                    let loaded = await loadUsers(for: docs)
                    await MainActor.run {
                        users = loaded
                    }
                }
            }
    }

    private func loadUsers(for docs: [QueryDocumentSnapshot]) async -> [SocialUser] {
        let db = Firestore.firestore()
        var result: [SocialUser] = []
        for doc in docs {
            let data = doc.data()
            guard let uid = (mode == .followers ? data["actorUid"] : data["targetUid"]) as? String else {
                continue
            }
            do {
                let profile = try await db.collection("users").document(uid).getDocument().data() ?? [:]
                let name = (profile["displayName"] as? String) ?? String(uid.prefix(8))
                let handleRaw = (profile["handle"] as? String) ?? String(uid.prefix(8))
                let handle = handleRaw.hasPrefix("@") ? handleRaw : "@\(handleRaw)"
                result.append(SocialUser(
                    uid: uid,
                    name: name,
                    handle: handle,
                    initials: String(name.prefix(2)).uppercased(),
                    avatarColors: [FMColors.Category.portrait, FMColors.Category.mood],
                    filterCount: (profile["filterCount"] as? Int) ?? 0,
                    role: (profile["roleLabel"] as? String) ?? "",
                    badge: nil,
                    newFilterCount: 0,
                    relationship: .notFollowing
                ))
            } catch {
                continue
            }
        }
        return result.sorted { $0.handle < $1.handle }
    }

    @MainActor
    private func refreshFollowList() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        guard !isUITesting else {
            users = mode == .followers ? SocialUser.followers : SocialUser.following
            followerCount = SocialUser.followers.count
            followingCount = SocialUser.following.count
            return
        }

        let db = Firestore.firestore()
        do {
            let profile = try await db.collection("users").document(normalizedUserID).getDocument()
            let data = profile.data() ?? [:]
            let handle = (data["handle"] as? String) ?? ""
            titleHandle = handle.isEmpty ? "@\(normalizedUserID.prefix(8))" : (handle.hasPrefix("@") ? handle : "@\(handle)")
            followerCount = (data["followerCount"] as? Int) ?? followerCount
            followingCount = (data["followingCount"] as? Int) ?? followingCount

            let field = mode == .followers ? "targetUid" : "actorUid"
            let snapshot = try await db.collection("follows")
                .whereField(field, isEqualTo: normalizedUserID)
                .limit(to: 100)
                .getDocuments()
            users = await loadUsers(for: snapshot.documents)
        } catch {
            // Realtime listeners remain attached, so preserve the last visible state on manual refresh failure.
        }
    }

    @MainActor
    private func toggleFollow(_ user: SocialUser) async {
        #if DEBUG
        if isUITesting {
            guard let index = users.firstIndex(where: { $0.id == user.id }) else { return }
            users[index].relationship = users[index].relationship.toggled
            FMHaptic.selection.play()
            return
        }
        #endif
        guard let actorUid = Auth.auth().currentUser?.uid, let targetUid = user.uid, actorUid != targetUid else {
            guard let index = users.firstIndex(where: { $0.id == user.id }) else { return }
            users[index].relationship = users[index].relationship.toggled
            FMHaptic.selection.play()
            return
        }
        guard let index = users.firstIndex(where: { $0.id == user.id }) else { return }
        let next = users[index].relationship.toggled
        users[index].relationship = next
        FMHaptic.selection.play()

        let edgeRef = Firestore.firestore().collection("follows").document("\(actorUid)_\(targetUid)")
        do {
            if next == .notFollowing {
                try await edgeRef.delete()
            } else {
                let snapshot = try await edgeRef.getDocument()
                if !snapshot.exists {
                    try await edgeRef.setData([
                        "actorUid": actorUid,
                        "targetUid": targetUid,
                        "createdAt": FieldValue.serverTimestamp()
                    ])
                }
            }
        } catch {
            users[index].relationship = user.relationship
        }
    }

    private func groupLabel(_ text: String) -> some View {
        Text(text)
            .fmTypography(.caption)
            .fontWeight(.bold)
            .tracking(0.4)
            .foregroundStyle(FMColors.Text.tertiary)
            .padding(.top, Sp.sm)
            .padding(.bottom, Sp.xs)
    }
}

// MARK: - Discovery Feeds

struct ForYouFeedScreen: View {
    @EnvironmentObject private var store: MooditStore
    @State private var followedMakerIDs: Set<String> = []

    private var rankedFilters: [Filter] {
        let source = store.trendingFilters.isEmpty ? store.filters : store.trendingFilters
        return source.sorted { lhs, rhs in
            let lhsScore = (lhs.downloadCount > 0 ? lhs.downloadCount : lhs.useCount) + Int((lhs.ratingAvg ?? 0) * 100)
            let rhsScore = (rhs.downloadCount > 0 ? rhs.downloadCount : rhs.useCount) + Int((rhs.ratingAvg ?? 0) * 100)
            return lhsScore == rhsScore ? lhs.title < rhs.title : lhsScore > rhsScore
        }
    }

    private var heroFilter: Filter? {
        rankedFilters.first
    }

    private var railFilters: [Filter] {
        Array(rankedFilters.dropFirst().prefix(8))
    }

    private var spotlightMakers: [ForYouMaker] {
        let grouped = Dictionary(grouping: rankedFilters) { $0.author.uid }
        return grouped.compactMap { uid, filters in
            guard let first = filters.first else { return nil }
            let totalDownloads = filters.reduce(0) { partial, filter in
                partial + (filter.downloadCount > 0 ? filter.downloadCount : filter.useCount)
            }
            return ForYouMaker(
                id: uid,
                name: first.author.displayName,
                role: first.category.displayTitle,
                filterCount: filters.count,
                downloadCount: totalDownloads
            )
        }
        .sorted { lhs, rhs in
            lhs.downloadCount == rhs.downloadCount ? lhs.name < rhs.name : lhs.downloadCount > rhs.downloadCount
        }
        .prefix(5)
        .map { $0 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.lg) {
                discoveryHeader(active: .forYou)
                reasonChip
                if let heroFilter {
                    heroCard(heroFilter)
                    railSection
                } else {
                    emptyRecommendations
                }
                makerSpotlight
            }
            .padding(.horizontal, Sp.md)
            .padding(.bottom, FMLayout.tabBarHeight + Sp.xxxl)
        }
        .background(FMColors.Background.bg1)
        .navigationTitle("발견")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: AppRoute.search(initialQuery: nil, category: nil)) {
                    Image(systemName: "magnifyingglass")
                }
                .accessibilityLabel("검색")
            }
        }
        .task {
            await store.load()
        }
    }

    private var reasonChip: some View {
        Label(recommendationReason, systemImage: "sparkles")
            .fmTypography(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(FMColors.Accent.primary)
            .padding(.horizontal, Sp.sm)
            .padding(.vertical, 5)
            .background(FMColors.Accent.bg, in: Capsule())
    }

    private var recommendationReason: String {
        guard let heroFilter else { return "마켓에서 첫 필터를 둘러보세요" }
        let favoriteCategories = store.filters
            .filter { store.favoriteFilterIDs.contains($0.id) }
            .map(\.category)
        if favoriteCategories.contains(heroFilter.category) {
            return "\(heroFilter.category.displayTitle) 취향과 비슷"
        }
        if !store.downloadedFilterIDs.isEmpty {
            return "최근 저장한 필터와 어울림"
        }
        return "지금 인기 있는 필터"
    }

    private func heroCard(_ filter: Filter) -> some View {
        ZStack(alignment: .bottomLeading) {
            filterCover(filter)
            LinearGradient(colors: [.clear, Color.black.opacity(0.85)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: Sp.sm) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(filter.title)
                        .fmTypography(.titleLarge)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    Text(heroSubtitle(filter))
                        .fmTypography(.subhead)
                        .foregroundStyle(.white.opacity(0.78))
                }
                HStack(spacing: Sp.xs) {
                    NavigationLink(value: AppRoute.filterDetail(id: filter.id.uuidString)) {
                        Text("카메라로 적용")
                            .fmTypography(.callout)
                            .fontWeight(.bold)
                            .foregroundStyle(FMColors.Accent.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(Color.white.opacity(0.94), in: RoundedRectangle(cornerRadius: R.md))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("social.foryou.hero.apply")

                    Button {
                        store.toggleFavorite(filter)
                        FMHaptic.selection.play()
                    } label: {
                        Image(systemName: store.isFavorite(filter) ? "bookmark.fill" : "bookmark")
                            .frame(width: 40, height: 40)
                            .background(Color.white.opacity(0.20), in: RoundedRectangle(cornerRadius: R.md))
                    }
                    .accessibilityIdentifier("social.foryou.hero.save")

                    Button {} label: {
                        Image(systemName: "ellipsis")
                            .frame(width: 40, height: 40)
                            .background(Color.white.opacity(0.20), in: RoundedRectangle(cornerRadius: R.md))
                    }
                }
                .foregroundStyle(.white)
            }
            .padding(Sp.md)
        }
        .aspectRatio(4.0 / 5.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: R.lg))
        .shadow(color: Color.black.opacity(0.12), radius: 8, y: 4)
    }

    @ViewBuilder
    private func filterCover(_ filter: Filter) -> some View {
        FMRemoteImage(
            url: filter.coverURL,
            cornerRadius: R.lg,
            placeholder: {
                GeometryReader { proxy in
                    FMSkeleton.rect(height: proxy.size.height, cornerRadius: R.lg)
                }
            },
            failure: {
                FMFilterCoverArt(motif: FilterCoverMotifResolver.motif(for: filter.title, category: filter.category.rawValue))
            }
        )
    }

    private func heroSubtitle(_ filter: Filter) -> String {
        var parts = ["@\(filter.author.displayName)"]
        if let ratingAvg = filter.ratingAvg, ratingAvg > 0 {
            parts.append("★ \(String(format: "%.1f", ratingAvg))")
        }
        let downloadCount = filter.downloadCount > 0 ? filter.downloadCount : filter.useCount
        if downloadCount > 0 {
            parts.append("↓ \(formattedDownloadCount(downloadCount))")
        }
        return parts.joined(separator: " · ")
    }

    private var railSection: some View {
        VStack(alignment: .leading, spacing: Sp.sm) {
            HStack {
                Text("추천 필터를 좋아한 사람들이 본 필터")
                    .fmTypography(.headline)
                    .foregroundStyle(FMColors.Text.primary)
                Spacer()
                NavigationLink("모두 보기", value: AppRoute.search(initialQuery: heroFilter?.category.displayTitle, category: heroFilter?.category.displayTitle))
                    .fmTypography(.caption)
                    .foregroundStyle(FMColors.Text.tertiary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Sp.sm) {
                    ForEach(railFilters) { filter in
                        NavigationLink(value: AppRoute.filterDetail(id: filter.id.uuidString)) {
                            VStack(alignment: .leading, spacing: 0) {
                                filterCover(filter)
                                    .aspectRatio(4.0 / 5.0, contentMode: .fit)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(filter.title)
                                        .fmTypography(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(FMColors.Text.primary)
                                    Text("@\(filter.author.displayName) · ↓ \(formattedDownloadCount(filter.downloadCount > 0 ? filter.downloadCount : filter.useCount))")
                                        .font(.system(size: 10))
                                        .foregroundStyle(FMColors.Text.tertiary)
                                }
                                .padding(8)
                            }
                            .frame(width: 130)
                            .background(FMColors.Background.bg2)
                            .clipShape(RoundedRectangle(cornerRadius: R.md))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var emptyRecommendations: some View {
        VStack(alignment: .leading, spacing: Sp.sm) {
            Text("아직 추천할 필터가 없어요")
                .fmTypography(.headline)
                .foregroundStyle(FMColors.Text.primary)
            Text("마켓에서 필터를 둘러보고 저장하면 여기 추천이 채워집니다.")
                .fmTypography(.subhead)
                .foregroundStyle(FMColors.Text.tertiary)
            NavigationLink(value: AppRoute.search(initialQuery: nil, category: nil)) {
                Text("마켓 둘러보기")
                    .fmTypography(.callout)
                    .fontWeight(.bold)
                    .foregroundStyle(FMColors.Text.inverse)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(FMColors.Accent.primary, in: RoundedRectangle(cornerRadius: R.md))
            }
            .buttonStyle(.plain)
        }
        .padding(Sp.md)
        .background(FMColors.Background.bg2, in: RoundedRectangle(cornerRadius: R.lg))
        .accessibilityIdentifier("social.foryou.empty")
    }

    private var makerSpotlight: some View {
        VStack(alignment: .leading, spacing: Sp.sm) {
            Text("새로 떠오르는 메이커")
                .fmTypography(.headline)
                .foregroundStyle(FMColors.Text.primary)
            if spotlightMakers.isEmpty {
                Text("아직 추천할 실제 메이커 데이터가 없어요.")
                    .fmTypography(.subhead)
                    .foregroundStyle(FMColors.Text.tertiary)
                    .padding(.vertical, Sp.xs)
                    .accessibilityIdentifier("social.foryou.makers.empty")
            } else {
                ForEach(spotlightMakers) { user in
                    HStack(spacing: Sp.sm) {
                        avatar(initials: user.initials, colors: user.avatarColors, size: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.name + " · " + user.role)
                                .fmTypography(.callout)
                                .fontWeight(.semibold)
                                .foregroundStyle(FMColors.Text.primary)
                            Text(user.meta)
                                .fmTypography(.caption)
                                .foregroundStyle(FMColors.Text.tertiary)
                        }
                        Spacer()
                        Button {
                            toggleFollow(user.id)
                        } label: {
                            Text(followedMakerIDs.contains(user.id) ? "팔로잉" : "팔로우")
                                .fmTypography(.subhead)
                                .fontWeight(.semibold)
                                .foregroundStyle(followedMakerIDs.contains(user.id) ? FMColors.Text.primary : FMColors.Text.inverse)
                                .padding(.horizontal, Sp.md)
                                .frame(height: 32)
                                .background(followedMakerIDs.contains(user.id) ? FMColors.Background.bg1 : FMColors.Accent.primary, in: RoundedRectangle(cornerRadius: R.md))
                        }
                        .accessibilityIdentifier("social.foryou.maker.follow")
                    }
                    .padding(Sp.sm)
                    .background(FMColors.Background.bg2, in: RoundedRectangle(cornerRadius: R.lg))
                    .overlay {
                        RoundedRectangle(cornerRadius: R.lg).strokeBorder(FMColors.Border.subtle, lineWidth: 1)
                    }
                }
            }
        }
    }

    private func toggleFollow(_ id: String) {
        if followedMakerIDs.contains(id) {
            followedMakerIDs.remove(id)
        } else {
            followedMakerIDs.insert(id)
        }
        FMHaptic.selection.play()
    }
}

struct FollowingFeedScreen: View {
    @EnvironmentObject private var store: MooditStore
    @State private var posts: [FollowingFeedPost] = []
    @State private var likedFilterIDs: Set<String> = []
    @State private var hiddenFilterIDs: Set<String> = []
    @State private var followsListener: ListenerRegistration?
    @State private var feedActionsListener: ListenerRegistration?
    @State private var moreMenuPost: FollowingFeedPost?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.md) {
                discoveryHeader(active: .following)
                if let latestPost = posts.first {
                    newFilterCard(latestPost)
                }
                if posts.isEmpty {
                    FMEmptyState(.emptyMarket)
                        .padding(.vertical, Sp.lg)
                        .accessibilityIdentifier("social.following.empty")
                } else {
                    ForEach(posts) { post in
                        postCard(post)
                    }
                }
            }
            .padding(.horizontal, Sp.md)
            .padding(.bottom, FMLayout.tabBarHeight + Sp.xxxl)
        }
        .background(FMColors.Background.bg1)
        .navigationTitle("팔로잉")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: AppRoute.notifications) {
                    Image(systemName: "bell")
                }
                .accessibilityLabel("알림")
            }
        }
        .confirmationDialog(
            "피드 옵션",
            isPresented: Binding(
                get: { moreMenuPost != nil },
                set: { if !$0 { moreMenuPost = nil } }
            ),
            titleVisibility: .visible,
            presenting: moreMenuPost
        ) { post in
            Button("피드에서 숨기기", role: .destructive) {
                Task { await hidePost(post) }
            }
            .accessibilityIdentifier("social.following.post.hide")

            Button("필터 ID 복사") {
                UIPasteboard.general.string = post.filter.id.uuidString
                FMHaptic.success.play()
            }

            Button("취소", role: .cancel) {}
        } message: { post in
            Text(post.filter.title)
        }
        .task {
            await store.load()
            attachFeedListeners()
        }
        .onDisappear {
            followsListener?.remove()
            followsListener = nil
            feedActionsListener?.remove()
            feedActionsListener = nil
        }
    }

    private func newFilterCard(_ post: FollowingFeedPost) -> some View {
        NavigationLink(value: AppRoute.filterDetail(id: post.filter.id.uuidString)) {
            HStack(spacing: Sp.sm) {
                followingFilterCover(post.filter)
                    .frame(width: 60, height: 75)
                    .clipShape(RoundedRectangle(cornerRadius: R.md))
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(post.authorName) 새 필터 게시")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.4)
                        .foregroundStyle(FMColors.Accent.primary)
                    Text(post.filter.title)
                        .fmTypography(.headline)
                        .foregroundStyle(FMColors.Text.primary)
                    Text("\(post.filter.category.displayTitle) · \(post.time) · ↓ \(formattedDownloadCount(post.downloadCount))")
                        .fmTypography(.caption)
                        .foregroundStyle(FMColors.Text.secondary)
                }
                Spacer()
                Text("보기")
                    .fmTypography(.subhead)
                    .fontWeight(.bold)
                    .foregroundStyle(FMColors.Text.inverse)
                    .padding(.horizontal, Sp.md)
                    .frame(height: 32)
                    .background(FMColors.Accent.primary, in: Capsule())
            }
            .padding(Sp.md)
            .background(FMColors.Accent.bg, in: RoundedRectangle(cornerRadius: R.lg))
            .overlay {
                RoundedRectangle(cornerRadius: R.lg).strokeBorder(FMColors.Accent.primary, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("social.following.newFilter")
    }

    private func postCard(_ post: FollowingFeedPost) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: Sp.sm) {
                avatar(initials: post.initials, colors: post.avatarColors, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.authorName)
                        .fmTypography(.subhead)
                        .fontWeight(.semibold)
                        .foregroundStyle(FMColors.Text.primary)
                    Text(post.handle + " · " + post.time)
                        .fmTypography(.caption)
                        .foregroundStyle(FMColors.Text.tertiary)
                }
                Spacer()
                Button {
                    moreMenuPost = post
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(FMColors.Text.secondary)
                }
                .accessibilityIdentifier("social.following.post.more")
            }
            .padding(Sp.md)

            ZStack(alignment: .bottomLeading) {
                followingFilterCover(post.filter)
                Text("\(post.filter.title) · \(post.intensity)% · ↓ \(formattedDownloadCount(post.downloadCount))")
                    .fmTypography(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Sp.sm)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.62), in: Capsule())
                    .padding(Sp.sm)
            }
            .aspectRatio(4.0 / 5.0, contentMode: .fit)

            HStack(spacing: Sp.md) {
                Button {
                    Task { await toggleLike(post) }
                } label: {
                    Label("\(post.likeCount + (likedFilterIDs.contains(post.id) ? 1 : 0))", systemImage: likedFilterIDs.contains(post.id) ? "heart.fill" : "heart")
                }
                .foregroundStyle(likedFilterIDs.contains(post.id) ? FMColors.Semantic.error : FMColors.Text.secondary)
                .accessibilityIdentifier("social.following.post.like")

                NavigationLink(value: AppRoute.reviews(filterId: post.filter.id.uuidString)) {
                    Label("\(post.reviewCount)", systemImage: "bubble.left")
                }
                .accessibilityIdentifier("social.following.post.reviews")

                Button {} label: {
                    Image(systemName: "square.and.arrow.up")
                }

                Spacer()
                Button {
                    store.toggleFavorite(post.filter)
                } label: {
                    Image(systemName: store.isFavorite(post.filter) ? "bookmark.fill" : "bookmark")
                }
                .accessibilityIdentifier("social.following.post.save")
            }
            .fmTypography(.subhead)
            .foregroundStyle(FMColors.Text.secondary)
            .padding(.horizontal, Sp.md)
            .padding(.vertical, Sp.sm)

            if let caption = post.caption {
                Text(caption)
                    .fmTypography(.subhead)
                    .foregroundStyle(FMColors.Text.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Sp.md)
                    .padding(.bottom, Sp.sm)
            }
        }
        .background(FMColors.Background.bg2, in: RoundedRectangle(cornerRadius: R.lg))
        .overlay {
            RoundedRectangle(cornerRadius: R.lg).strokeBorder(FMColors.Border.subtle, lineWidth: 1)
        }
    }

    @ViewBuilder
    private func followingFilterCover(_ filter: Filter) -> some View {
        FMRemoteImage(
            url: filter.coverURL,
            cornerRadius: R.lg,
            placeholder: {
                GeometryReader { proxy in
                    FMSkeleton.rect(height: proxy.size.height, cornerRadius: R.lg)
                }
            },
            failure: {
                FMFilterCoverArt(motif: FilterCoverMotifResolver.motif(for: filter.title, category: filter.category.rawValue))
            }
        )
    }

    private func attachFeedListeners() {
        guard !isUITesting else {
            posts = SocialPost.mock.compactMap { $0.toFollowingFeedPost(store: store) }
            return
        }
        guard let uid = Auth.auth().currentUser?.uid else {
            posts = []
            return
        }

        followsListener?.remove()
        followsListener = Firestore.firestore().collection("follows")
            .whereField("actorUid", isEqualTo: uid)
            .addSnapshotListener { snapshot, _ in
                let targetUIDs = Array(Set((snapshot?.documents ?? []).compactMap { $0.data()["targetUid"] as? String }))
                Task {
                    let loadedPosts = await loadPosts(for: targetUIDs)
                    await MainActor.run {
                        posts = loadedPosts.filter { !hiddenFilterIDs.contains($0.id) }
                    }
                }
            }

        feedActionsListener?.remove()
        feedActionsListener = Firestore.firestore()
            .collection("users").document(uid)
            .collection("feedActions")
            .addSnapshotListener { snapshot, _ in
                let docs = snapshot?.documents ?? []
                let liked = Set(docs.filter { ($0.data()["liked"] as? Bool) == true }.map(\.documentID))
                let hidden = Set(docs.filter { ($0.data()["hidden"] as? Bool) == true }.map(\.documentID))
                Task { @MainActor in
                    likedFilterIDs = liked
                    hiddenFilterIDs = hidden
                    posts.removeAll { hidden.contains($0.id) }
                }
            }
    }

    private func loadPosts(for targetUIDs: [String]) async -> [FollowingFeedPost] {
        guard !targetUIDs.isEmpty else { return [] }
        let db = Firestore.firestore()
        var loaded: [FollowingFeedPost] = []
        for uid in targetUIDs.prefix(25) {
            do {
                let snapshot = try await db.collection("filters")
                    .whereField("authorUid", isEqualTo: uid)
                    .whereField("status", isEqualTo: FilterStatus.approved.rawValue)
                    .order(by: "createdAt", descending: true)
                    .limit(to: 5)
                    .getDocuments()
                loaded.append(contentsOf: snapshot.documents.compactMap { doc in
                    FirestoreFilterRepository.decode(doc).map { filter in
                        FollowingFeedPost(filter: filter)
                    }
                })
            } catch {
                continue
            }
        }
        return loaded.sorted { lhs, rhs in
            (lhs.filter.createdAt ?? .distantPast) > (rhs.filter.createdAt ?? .distantPast)
        }
    }

    private func toggleLike(_ post: FollowingFeedPost) async {
        #if DEBUG
        if isUITesting {
            if likedFilterIDs.contains(post.id) {
                likedFilterIDs.remove(post.id)
            } else {
                likedFilterIDs.insert(post.id)
            }
            return
        }
        #endif
        guard let uid = Auth.auth().currentUser?.uid else {
            if likedFilterIDs.contains(post.id) {
                likedFilterIDs.remove(post.id)
            } else {
                likedFilterIDs.insert(post.id)
            }
            return
        }
        let willLike = !likedFilterIDs.contains(post.id)
        if willLike {
            likedFilterIDs.insert(post.id)
        } else {
            likedFilterIDs.remove(post.id)
        }
        do {
            try await Firestore.firestore()
                .collection("users").document(uid)
                .collection("feedActions").document(post.id)
                .setData([
                    "filterId": post.id,
                    "liked": willLike,
                    "updatedAt": FieldValue.serverTimestamp()
                ], merge: true)
        } catch {
            if willLike {
                likedFilterIDs.remove(post.id)
            } else {
                likedFilterIDs.insert(post.id)
            }
        }
    }

    private func hidePost(_ post: FollowingFeedPost) async {
        #if DEBUG
        if isUITesting {
            posts.removeAll { $0.id == post.id }
            return
        }
        #endif
        guard let uid = Auth.auth().currentUser?.uid else {
            posts.removeAll { $0.id == post.id }
            return
        }
        hiddenFilterIDs.insert(post.id)
        posts.removeAll { $0.id == post.id }
        do {
            try await Firestore.firestore()
                .collection("users").document(uid)
                .collection("feedActions").document(post.id)
                .setData([
                    "filterId": post.id,
                    "hidden": true,
                    "updatedAt": FieldValue.serverTimestamp()
                ], merge: true)
        } catch {
            hiddenFilterIDs.remove(post.id)
            posts.insert(post, at: 0)
        }
    }
}

// MARK: - Shared Views

private enum DiscoveryTab {
    case trending
    case forYou
    case following
    case newest
}

@MainActor
private func discoveryHeader(active: DiscoveryTab) -> some View {
    HStack(spacing: Sp.md) {
        discoveryTab("트렌딩", route: .forYou, isActive: active == .trending)
        discoveryTab("For You", route: .forYou, isActive: active == .forYou)
        discoveryTab("팔로잉", route: .followingFeed, isActive: active == .following)
        discoveryTab("신규", route: .search(initialQuery: nil, category: "신규"), isActive: active == .newest)
    }
    .padding(.top, Sp.sm)
    .overlay(alignment: .bottom) {
        Rectangle().fill(FMColors.Border.subtle).frame(height: 1).offset(y: Sp.sm)
    }
}

@MainActor
private func discoveryTab(_ title: String, route: AppRoute, isActive: Bool) -> some View {
    NavigationLink(value: route) {
        Text(title)
            .fmTypography(.callout)
            .fontWeight(isActive ? .bold : .medium)
            .foregroundStyle(isActive ? FMColors.Text.primary : FMColors.Text.tertiary)
            .padding(.vertical, Sp.sm)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(isActive ? FMColors.Accent.primary : Color.clear)
                    .frame(height: 2)
            }
    }
    .buttonStyle(.plain)
}

@MainActor
private func iconButton(_ systemImage: String, label: String) -> some View {
    Button {} label: {
        Image(systemName: systemImage)
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(FMColors.Text.secondary)
            .frame(width: 36, height: 36)
    }
    .accessibilityLabel(label)
}

@MainActor
private func avatar(initials: String, colors: [Color], size: CGFloat) -> some View {
    ZStack {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
        Text(initials)
            .font(.system(size: max(9, size * 0.28), weight: .bold))
            .foregroundStyle(.white)
    }
    .frame(width: size, height: size)
    .clipShape(Circle())
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = Sp.xs
    var lineSpacing: CGFloat = Sp.xs

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth > 0, rowWidth + spacing + size.width > maxWidth {
                totalHeight += rowHeight + lineSpacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += (rowWidth > 0 ? spacing : 0) + size.width
            rowHeight = max(rowHeight, size.height)
        }

        totalHeight += rowHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + lineSpacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Shared Models

private struct SocialMakerReply: Identifiable {
    let id = UUID()
    let handle: String
    let initials: String
    let avatarColors: [Color]
    let time: String
    let body: String
}

private struct ReviewFilterSummary {
    var title: String?
    var makerName: String?
    var categoryRawValue: String?
    var downloadCount: Int?
    var ratingAvg: Double?
    var coverURL: URL?
}

private struct SocialReview: Identifiable {
    let id: String
    let authorUid: String
    let name: String
    let handle: String
    let initials: String
    let avatarColors: [Color]
    let time: String
    let body: String
    let stars: Int
    let photoURL: URL?
    let helpfulCount: Int
    let isHelpful: Bool
    let isVerifiedDownload: Bool
    let makerReply: SocialMakerReply?

    static let mock: [SocialReview] = [
        SocialReview(
            id: UUID().uuidString,
            authorUid: "minji.lab",
            name: "민지",
            handle: "@minji.lab",
            initials: "MJ",
            avatarColors: [Color(hex: 0xF3DCC4), Color(hex: 0xD4A482)],
            time: "2시간",
            body: "카페 사진에 진짜 잘 어울려요. 강도 80%가 베스트네요.",
            stars: 5,
            photoURL: nil,
            helpfulCount: 24,
            isHelpful: true,
            isVerifiedDownload: true,
            makerReply: SocialMakerReply(
                handle: "@sample.maker",
                initials: "JS",
                avatarColors: [Color(hex: 0xE0C39A), Color(hex: 0x8E6A4A)],
                time: "1시간",
                body: "민지님 감사합니다! 아침 햇빛에서도 한번 써보세요."
            )
        ),
        SocialReview(
            id: UUID().uuidString,
            authorUid: "alex.grade",
            name: "Alex",
            handle: "@alex.grade",
            initials: "AL",
            avatarColors: [Color(hex: 0xAEC59A), Color(hex: 0x4A6A3C)],
            time: "5시간",
            body: "Mid-tone에 살짝 마젠타가 도는 느낌이 좋네요. 어떤 LUT 사이즈로 만드셨어요? 33³ 인가요?",
            stars: 4,
            photoURL: nil,
            helpfulCount: 12,
            isHelpful: false,
            isVerifiedDownload: true,
            makerReply: nil
        ),
        SocialReview(
            id: UUID().uuidString,
            authorUid: "yuna.diary",
            name: "유나",
            handle: "@yuna.diary",
            initials: "YN",
            avatarColors: [Color(hex: 0xAAB5CB), Color(hex: 0x3A4560)],
            time: "어제",
            body: "제 셀카에는 강도 60%가 자연스러웠어요. 추천!",
            stars: 4,
            photoURL: nil,
            helpfulCount: 6,
            isHelpful: false,
            isVerifiedDownload: true,
            makerReply: nil
        ),
        SocialReview(
            id: UUID().uuidString,
            authorUid: "emma.travel",
            name: "Emma",
            handle: "@emma.travel",
            initials: "EM",
            avatarColors: [Color(hex: 0xCBD4E0), Color(hex: 0xC79A72)],
            time: "2일",
            body: "유럽 여행 사진들에 진짜 다 잘 맞네요. 다른 비슷한 톤도 있나요?",
            stars: 5,
            photoURL: nil,
            helpfulCount: 4,
            isHelpful: false,
            isVerifiedDownload: false,
            makerReply: nil
        )
    ]
}

private struct SocialUser: Identifiable {
    var id = UUID()
    var uid: String?
    let name: String
    let handle: String
    let initials: String
    let avatarColors: [Color]
    let filterCount: Int
    let role: String
    let badge: String?
    let newFilterCount: Int
    var relationship: FollowRelationship

    var meta: String {
        if role.isEmpty {
            return "\(handle) · 필터 \(filterCount)"
        }
        return "\(handle) · \(role)"
    }

    static let followers: [SocialUser] = [
        .init(name: "민지", handle: "@minji.lab", initials: "MJ", avatarColors: [Color(hex: 0xF3DCC4), Color(hex: 0xD4A482)], filterCount: 8, role: "", badge: nil, newFilterCount: 0, relationship: .mutual),
        .init(name: "Alex", handle: "@alex.grade", initials: "AL", avatarColors: [Color(hex: 0xAEC59A), Color(hex: 0x4A6A3C)], filterCount: 24, role: "시네마틱 메이커", badge: nil, newFilterCount: 3, relationship: .following),
        .init(name: "유나", handle: "@yuna.diary", initials: "YN", avatarColors: [Color(hex: 0xE0C39A), Color(hex: 0x8E6A4A)], filterCount: 6, role: "", badge: nil, newFilterCount: 0, relationship: .notFollowing),
        .init(name: "Emma", handle: "@emma.travel", initials: "EM", avatarColors: [Color(hex: 0xAAB5CB), Color(hex: 0x3A4560)], filterCount: 12, role: "", badge: nil, newFilterCount: 0, relationship: .notFollowing),
        .init(name: "Sarah", handle: "@sarah.lens", initials: "SR", avatarColors: [Color(hex: 0xF6E2E8), Color(hex: 0xB39EC2)], filterCount: 18, role: "파스텔 메이커", badge: nil, newFilterCount: 2, relationship: .mutual),
        .init(name: "한별", handle: "@hanbyul.cam", initials: "HB", avatarColors: [Color(hex: 0xB9D2E8), Color(hex: 0x4A6A90)], filterCount: 3, role: "", badge: nil, newFilterCount: 0, relationship: .notFollowing)
    ]

    static let following: [SocialUser] = [
        .init(name: "Alex", handle: "@alex.grade", initials: "AL", avatarColors: [Color(hex: 0xAEC59A), Color(hex: 0x4A6A3C)], filterCount: 24, role: "시네마틱 메이커", badge: nil, newFilterCount: 3, relationship: .following),
        .init(name: "Studio Haru", handle: "@studio.haru", initials: "SH", avatarColors: [Color(hex: 0xCBD4E0), Color(hex: 0xC79A72)], filterCount: 67, role: "", badge: nil, newFilterCount: 1, relationship: .following),
        .init(name: "민지", handle: "@minji.lab", initials: "MJ", avatarColors: [Color(hex: 0xF3DCC4), Color(hex: 0xD4A482)], filterCount: 8, role: "", badge: nil, newFilterCount: 0, relationship: .following),
        .init(name: "Sarah", handle: "@sarah.lens", initials: "SR", avatarColors: [Color(hex: 0xF6E2E8), Color(hex: 0xB39EC2)], filterCount: 18, role: "파스텔 메이커", badge: nil, newFilterCount: 0, relationship: .following),
        .init(name: "Kihyeon", handle: "@kihyeon", initials: "KH", avatarColors: [Color(hex: 0xE09A78), Color(hex: 0x4A4060)], filterCount: 5, role: "", badge: nil, newFilterCount: 0, relationship: .following)
    ]

    static let mentionSuggestions: [SocialUser] = [
        .init(name: "샘플 메이커", handle: "@sample.maker", initials: "SM", avatarColors: [Color(hex: 0xE0C39A), Color(hex: 0x8E6A4A)], filterCount: 24, role: "", badge: "메이커", newFilterCount: 0, relationship: .following),
        .init(name: "jisook", handle: "@jisook.daily", initials: "JD", avatarColors: [Color(hex: 0xF6E2E8), Color(hex: 0xB39EC2)], filterCount: 2, role: "", badge: nil, newFilterCount: 0, relationship: .notFollowing),
        .init(name: "jisoo_studio", handle: "@jisoo.studio", initials: "JS", avatarColors: [Color(hex: 0xAEC59A), Color(hex: 0x4A6A3C)], filterCount: 9, role: "", badge: nil, newFilterCount: 0, relationship: .notFollowing)
    ]

    static let spotlight: [SocialUser] = [
        .init(name: "Alex", handle: "@alex.grade", initials: "AL", avatarColors: [Color(hex: 0xAEC59A), Color(hex: 0x4A6A3C)], filterCount: 24, role: "시네마틱 메이커", badge: nil, newFilterCount: 3, relationship: .notFollowing),
        .init(name: "Sarah", handle: "@sarah.lens", initials: "SR", avatarColors: [Color(hex: 0xF6E2E8), Color(hex: 0xB39EC2)], filterCount: 18, role: "파스텔 메이커", badge: nil, newFilterCount: 2, relationship: .notFollowing)
    ]
}

private enum FollowRelationship: Hashable {
    case notFollowing
    case following
    case mutual

    var label: String {
        switch self {
        case .notFollowing: "팔로우"
        case .following: "팔로잉"
        case .mutual: "맞팔"
        }
    }

    var toggled: FollowRelationship {
        switch self {
        case .notFollowing: .following
        case .following, .mutual: .notFollowing
        }
    }

    var foreground: Color {
        switch self {
        case .notFollowing: FMColors.Text.inverse
        case .following: FMColors.Text.primary
        case .mutual: FMColors.Text.secondary
        }
    }

    var background: Color {
        switch self {
        case .notFollowing: FMColors.Accent.primary
        case .following, .mutual: FMColors.Background.bg2
        }
    }

    var border: Color {
        switch self {
        case .notFollowing: FMColors.Accent.primary
        case .following, .mutual: FMColors.Border.default
        }
    }
}

private func formattedDownloadCount(_ count: Int) -> String {
    count.fmCompactCount()
}

private struct ForYouMaker: Identifiable {
    let id: String
    let name: String
    let role: String
    let filterCount: Int
    let downloadCount: Int

    var initials: String {
        let prefix = name.prefix(2)
        return prefix.isEmpty ? "MK" : String(prefix).uppercased()
    }

    var meta: String {
        "\(filterCount)개 필터 · ↓ \(formattedDownloadCount(downloadCount))"
    }

    var avatarColors: [Color] {
        [FMColors.Category.cinematic, FMColors.Category.vintage]
    }
}

private struct FollowingFeedPost: Identifiable {
    let filter: Filter
    let caption: String?
    let displayIntensity: Int
    let baseLikeCount: Int
    let baseReviewCount: Int

    var id: String { filter.id.uuidString }
    var authorName: String { filter.author.displayName }
    var handle: String { "@\(filter.author.displayName)" }
    var initials: String {
        let prefix = filter.author.displayName.prefix(2)
        return prefix.isEmpty ? "MK" : String(prefix).uppercased()
    }
    var avatarColors: [Color] { [FMColors.Category.portrait, FMColors.Category.mood] }
    var time: String { filter.createdAt.map(Self.relativeTimeString) ?? "방금" }
    var intensity: Int { displayIntensity }
    var downloadCount: Int { filter.downloadCount > 0 ? filter.downloadCount : filter.useCount }
    var likeCount: Int { baseLikeCount }
    var reviewCount: Int { baseReviewCount }

    init(
        filter: Filter,
        caption: String? = nil,
        intensity: Int = 100,
        likeCount: Int = 0,
        reviewCount: Int = 0
    ) {
        self.filter = filter
        self.caption = caption
        self.displayIntensity = intensity
        self.baseLikeCount = likeCount
        self.baseReviewCount = reviewCount
    }

    private static func relativeTimeString(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "방금" }
        if interval < 3600 { return "\(Int(interval / 60))분 전" }
        if interval < 86_400 { return "\(Int(interval / 3600))시간 전" }
        return "\(Int(interval / 86_400))일 전"
    }
}

private struct SocialPost: Identifiable {
    let id = UUID()
    let author: String
    let handle: String
    let initials: String
    let avatarColors: [Color]
    let time: String
    let filterName: String
    let intensity: Int
    let motif: FMFilterCoverArt.Motif
    let downloadCount: Int
    let likeCount: Int
    let reviewCount: Int
    let isLiked: Bool
    let caption: String?

    static let mock: [SocialPost] = [
        .init(
            author: "Alex",
            handle: "@alex.grade",
            initials: "AL",
            avatarColors: [Color(hex: 0xAEC59A), Color(hex: 0x4A6A3C)],
            time: "2시간 전",
            filterName: "Tokyo Night",
            intensity: 88,
            motif: .cinematic,
            downloadCount: 128,
            likeCount: 42,
            reviewCount: 8,
            isLiked: true,
            caption: "새 필터 첫 시도. 도쿄 야경에 진짜 찰떡이네요."
        ),
        .init(
            author: "Sarah",
            handle: "@sarah.lens",
            initials: "SR",
            avatarColors: [Color(hex: 0xF6E2E8), Color(hex: 0xB39EC2)],
            time: "4시간 전",
            filterName: "Cotton Candy",
            intensity: 70,
            motif: .pastel,
            downloadCount: 2_430,
            likeCount: 28,
            reviewCount: 4,
            isLiked: false,
            caption: nil
        )
    ]
}

private extension SocialPost {
    @MainActor
    func toFollowingFeedPost(store: MooditStore) -> FollowingFeedPost? {
        if let existing = store.filters.first(where: { $0.title.socialMockLookupKey == filterName.socialMockLookupKey }) {
            return FollowingFeedPost(
                filter: existing,
                caption: caption,
                intensity: intensity,
                likeCount: likeCount,
                reviewCount: reviewCount
            )
        }
        let fallbackFilter = Filter(
            id: UUID(),
            title: filterName,
            version: "1.0.0",
            author: FilterAuthor(uid: handle.replacingOccurrences(of: "@", with: ""), displayName: author),
            category: .cinematic,
            engine: FilterEngineDescriptor(type: .lutParams, minAppVersion: "1.0.0", minIOSVersion: "17.0", lutSize: 33, lutFile: nil),
            useCount: downloadCount,
            createdAt: Date(),
            status: .approved,
            priceCoins: 0,
            coverURL: nil,
            signatureSampleURL: nil,
            ratingAvg: nil,
            downloadCount: downloadCount,
            tags: []
        )
        return FollowingFeedPost(
            filter: fallbackFilter,
            caption: caption,
            intensity: intensity,
            likeCount: likeCount,
            reviewCount: reviewCount
        )
    }
}

private extension String {
    var socialMockLookupKey: String {
        lowercased()
            .replacingOccurrences(of: "@", with: "")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
