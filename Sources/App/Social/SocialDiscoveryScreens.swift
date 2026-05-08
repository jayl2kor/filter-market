import DesignSystem
import FirebaseAuth
import FirebaseFirestore
import Foundation
import SwiftUI

// MARK: - Reviews

struct ReviewsListScreen: View {
    @AppStorage("isAuthenticated") private var isAuthenticated = false

    let filterID: String
    // (#37) 프로덕션은 Firestore /filters/{filterID}/reviews listener (.task에서 attach).
    // UI 테스트 (-ui-testing): 기존 mock 데이터로 fallback.
    @State private var reviews: [SocialReview] = isUITesting ? SocialReview.mock : []
    @State private var helpfulIDs: Set<UUID> = isUITesting ? Set(SocialReview.mock.filter(\.isHelpful).map(\.id)) : []
    @State private var moreMenuReview: SocialReview?
    @State private var reviewsListener: ListenerRegistration?

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
            NavigationLink(value: AppRoute.reportForm) {
                Text("이 리뷰 신고")
            }
            .accessibilityIdentifier("social.review.more.report")

            Button("작성자 차단", role: .destructive) {
                // Mock: remove all reviews from the same handle.
                reviews.removeAll { $0.handle == review.handle }
                FMHaptic.warning.play()
            }
            .accessibilityIdentifier("social.review.more.block")

            Button("리뷰 텍스트 복사") {
                UIPasteboard.general.string = review.body
                FMHaptic.success.play()
            }
            .accessibilityIdentifier("social.review.more.copy")

            Button("취소", role: .cancel) {}
        } message: { review in
            Text("\(review.name) (\(review.handle))")
        }
        .task {
            // (#37) Firestore listener attach. UI test fallback은 mock 데이터를 그대로 사용.
            guard !isUITesting else { return }
            attachReviewsListener()
        }
        .onDisappear {
            reviewsListener?.remove()
            reviewsListener = nil
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
                    let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                    let initials = String(authorName.prefix(2)).uppercased()
                    let interval = Date().timeIntervalSince(createdAt)
                    let timeStr: String
                    if interval < 60 { timeStr = "방금 전" }
                    else if interval < 3600 { timeStr = "\(Int(interval / 60))분" }
                    else if interval < 86400 { timeStr = "\(Int(interval / 3600))시간" }
                    else { timeStr = "\(Int(interval / 86400))일" }
                    return SocialReview(
                        name: authorName,
                        handle: "@\(authorUid.prefix(8))",
                        initials: initials,
                        avatarColors: [Color(hex: 0xF3DCC4), Color(hex: 0xD4A482)],
                        time: timeStr,
                        body: body,
                        stars: Self.intField(data["stars"], default: Self.intField(data["rating"], default: 0)),
                        helpfulCount: Self.intField(data["helpfulCount"], default: 0),
                        isHelpful: false,
                        isVerifiedDownload: data["isVerifiedDownload"] as? Bool ?? false,
                        makerReply: nil
                    )
                }
                Task { @MainActor in
                    self.reviews = decoded
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

    private var filterMiniCard: some View {
        NavigationLink(value: AppRoute.filterDetail(id: filterID)) {
            HStack(spacing: Sp.sm) {
                FMFilterCoverArt(motif: FilterCoverMotifResolver.motif(for: filterID, category: nil))
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: R.sm))

                VStack(alignment: .leading, spacing: 2) {
                    // (#36) UUID 노출 방지 — UUID 형식이면 일반 라벨 사용.
                    Text(UUID(uuidString: filterID) != nil ? "필터" : filterID)
                        .fmTypography(.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(FMColors.Text.primary)
                    // UI 테스트는 정적 메이커 라벨 유지 (어시드 호환). 프로덕션은 일반 텍스트.
                    Text(isUITesting ? "@sample.maker · ★ 4.9 · ↓ \(formattedDownloadCount(6_200))" : "리뷰 목록")
                        .fmTypography(.caption)
                        .foregroundStyle(FMColors.Text.tertiary)
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

            NavigationLink(value: isAuthenticated ? AppRoute.reviewCompose(filterId: filterID) : AppRoute.login) {
                Text(isAuthenticated ? "리뷰 추가..." : "로그인하고 리뷰 남기기")
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

            NavigationLink(value: isAuthenticated ? AppRoute.reviewCompose(filterId: filterID) : AppRoute.login) {
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
        HStack(alignment: .top, spacing: Sp.sm) {
            NavigationLink(value: AppRoute.otherProfile(uid: review.handle)) {
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

                HStack(spacing: Sp.md) {
                    Button {
                        toggleHelpful(review)
                    } label: {
                        let bumpedCount = review.helpfulCount + (helpfulIDs.contains(review.id) && !review.isHelpful ? 1 : 0)
                        Label("\(bumpedCount)", systemImage: helpfulIDs.contains(review.id) ? "hand.thumbsup.fill" : "hand.thumbsup")
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
        .overlay(alignment: .bottom) {
            Rectangle().fill(FMColors.Border.subtle).frame(height: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("social.review.row")
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

    private func toggleHelpful(_ review: SocialReview) {
        FMHaptic.selection.play()
        if helpfulIDs.contains(review.id) {
            helpfulIDs.remove(review.id)
        } else {
            helpfulIDs.insert(review.id)
        }
    }
}

struct ReviewComposeScreen: View {
    @AppStorage("isAuthenticated") private var isAuthenticated = false
    @Environment(\.dismiss) private var dismiss

    let filterID: String
    @State private var text = "이 필터 너무 좋아요! @jiso"
    @State private var selectedMention: UUID?
    @State private var showingPhotoPicker = false
    @State private var attachedImage: UIImage?
    @State private var showingEmojiPicker = false

    private let mentions = SocialUser.mentionSuggestions
    private let limit = 280

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
        text += "\(separator)@"
        FMHaptic.selection.play()
    }

    private func insertEmoji(_ emoji: String) {
        text += emoji
        FMHaptic.selection.play()
    }

    /// Firestore /filters/{filterID}/reviews/{auto}에 리뷰 작성 (#26).
    /// 실패 시 화면 유지 + haptic 에러; 성공 시 dismiss.
    private func submitReview() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            FMHaptic.warning.play()
            return
        }
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        let payload: [String: Any] = [
            "authorUid": uid,
            "body": body,
            "filterId": filterID,
            "createdAt": FieldValue.serverTimestamp(),
        ]
        do {
            try await Firestore.firestore()
                .collection("filters").document(filterID)
                .collection("reviews").document()
                .setData(payload)
            FMHaptic.success.play()
            dismiss()
        } catch {
            FMHaptic.warning.play()
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if isAuthenticated {
                editor
                toolbar
            } else {
                loginGate
            }
        }
        .background(FMColors.Background.bg1)
        .navigationTitle("새 리뷰")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("취소") { dismiss() }
                    .foregroundStyle(FMColors.Text.secondary)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("게시") {
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
            }
        }
    }

    private var canPost: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && text.count <= limit
    }

    private var editor: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.md) {
                HStack(spacing: Sp.xs) {
                    avatar(initials: "HB", colors: [Color(hex: 0xB9D2E8), Color(hex: 0x4A6A90)], size: 32)
                    Text("한별")
                        .fmTypography(.subhead)
                        .fontWeight(.semibold)
                        .foregroundStyle(FMColors.Text.primary)
                    Text(UUID(uuidString: filterID) != nil ? "필터에 답글" : "↩ \(filterID)에 답글")
                        .fmTypography(.caption)
                        .foregroundStyle(FMColors.Text.tertiary)
                }

                TextEditor(text: $text)
                    .font(.system(size: 17))
                    .foregroundStyle(FMColors.Text.primary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 180)
                    .accessibilityIdentifier("social.compose.input")

                if let image = attachedImage {
                    attachedImagePreview(image)
                }

                if showingEmojiPicker {
                    emojiPalette
                }

                if text.contains("@") {
                    mentionBox
                }
            }
            .padding(Sp.md)
        }
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
                    text = text.replacingOccurrences(of: "@jiso", with: user.handle + " ")
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
                .foregroundStyle(text.count > limit ? FMColors.Semantic.warning : FMColors.Text.tertiary)
        }
        .padding(.horizontal, Sp.md)
        .padding(.vertical, Sp.sm)
        .background(FMColors.Background.bg1)
        .overlay(alignment: .top) {
            Rectangle().fill(FMColors.Border.subtle).frame(height: 1)
        }
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
    @AppStorage("isAuthenticated") private var isAuthenticated = false
    @Environment(\.dismiss) private var dismiss

    let filterID: String
    @State private var rating = 5
    @State private var selectedTags: Set<String> = ["자연스러움", "강도 조절 좋음"]
    @State private var reviewBody = "필름 카페 사진에 정말 잘 어울려요. 강도 80%가 베스트."

    private let tags = ["자연스러움", "강도 조절 좋음", "카페 잘 어울림", "셀카 좋음", "여행", "실내 광원"]

    /// (#28) Firestore /filters/{id}/ratings/{uid}에 평점 + 코멘트 저장.
    /// uid 키로 1개만 — 재제출 시 덮어쓰기.
    private func submitRating() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            FMHaptic.warning.play()
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
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            FMFilterCoverArt(motif: FilterCoverMotifResolver.motif(for: filterID, category: nil))
                .opacity(0.28)
                .ignoresSafeArea()
            Color.black.opacity(0.34).ignoresSafeArea()

            if isAuthenticated {
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

            Text(ratingLabel)
                .fmTypography(.headline)
                .fontWeight(.bold)
                .foregroundStyle(FMColors.Accent.primary)

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

            TextEditor(text: $reviewBody)
                .font(.body)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 88)
                .padding(Sp.xs)
                .background(FMColors.Background.bg1, in: RoundedRectangle(cornerRadius: R.md))
                .overlay {
                    RoundedRectangle(cornerRadius: R.md).strokeBorder(FMColors.Border.default, lineWidth: 1)
                }
                .accessibilityIdentifier("social.rating.body")

            HStack(spacing: Sp.xs) {
                FMButton("건너뛰기", variant: .secondary, size: .lg) {
                    dismiss()
                }
                FMButton("평점 등록", variant: .primary, size: .lg) {
                    Task { await submitRating() }
                }
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
        case 1: "아쉬워요"
        case 2: "조금 아쉬워요"
        case 3: "괜찮아요"
        case 4: "좋아요"
        default: "최고예요!"
        }
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
    }

    private func userRow(_ user: SocialUser) -> some View {
        HStack(spacing: Sp.sm) {
            NavigationLink(value: AppRoute.otherProfile(uid: user.handle)) {
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
                    }
                }
            }
            .buttonStyle(.plain)

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

            followButton(user)
        }
        .padding(.vertical, Sp.sm)
        .overlay(alignment: .bottom) {
            Rectangle().fill(FMColors.Border.subtle).frame(height: 1)
        }
        .accessibilityIdentifier("social.user.row")
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
    private func toggleFollow(_ user: SocialUser) async {
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
    @State private var followedMakerIDs: Set<UUID> = []
    @State private var savedHero = false

    private var spotlightMakers: [SocialUser] {
        isUITesting ? SocialUser.spotlight : []
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.lg) {
                discoveryHeader(active: .forYou)
                reasonChip
                heroCard
                railSection
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
    }

    private var reasonChip: some View {
        Label("좋아한 빈티지 톤과 비슷", systemImage: "sparkles")
            .fmTypography(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(FMColors.Accent.primary)
            .padding(.horizontal, Sp.sm)
            .padding(.vertical, 5)
            .background(FMColors.Accent.bg, in: Capsule())
    }

    private var heroCard: some View {
        ZStack(alignment: .bottomLeading) {
            FMFilterCoverArt(motif: .vintage)
            LinearGradient(colors: [.clear, Color.black.opacity(0.85)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: Sp.sm) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Amber Café")
                        .fmTypography(.titleLarge)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    Text("@sample.maker · ★ 4.8 · ↓ \(formattedDownloadCount(6_200))")
                        .fmTypography(.subhead)
                        .foregroundStyle(.white.opacity(0.78))
                }
                HStack(spacing: Sp.xs) {
                    NavigationLink(value: AppRoute.filterDetail(id: "Amber Café")) {
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
                        savedHero.toggle()
                        FMHaptic.selection.play()
                    } label: {
                        Image(systemName: savedHero ? "bookmark.fill" : "bookmark")
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

    private var railSection: some View {
        VStack(alignment: .leading, spacing: Sp.sm) {
            HStack {
                Text("추천 필터를 좋아한 사람들이 본 필터")
                    .fmTypography(.headline)
                    .foregroundStyle(FMColors.Text.primary)
                Spacer()
                NavigationLink("모두 보기", value: AppRoute.search(initialQuery: "vintage", category: nil))
                    .fmTypography(.caption)
                    .foregroundStyle(FMColors.Text.tertiary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Sp.sm) {
                    ForEach(SocialFeedItem.recommendations) { item in
                        NavigationLink(value: AppRoute.filterDetail(id: item.title)) {
                            VStack(alignment: .leading, spacing: 0) {
                                FMFilterCoverArt(motif: item.motif)
                                    .aspectRatio(4.0 / 5.0, contentMode: .fit)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .fmTypography(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(FMColors.Text.primary)
                                    Text("\(item.author) · ↓ \(formattedDownloadCount(item.downloadCount))")
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

    private func toggleFollow(_ id: UUID) {
        if followedMakerIDs.contains(id) {
            followedMakerIDs.remove(id)
        } else {
            followedMakerIDs.insert(id)
        }
        FMHaptic.selection.play()
    }
}

struct FollowingFeedScreen: View {
    // 프로덕션은 /users/{uid}/feed Firestore listener (별도 작업)에서 채워짐.
    // UI 테스트(-ui-testing): 기존 mock fallback.
    @State private var posts: [SocialPost] = isUITesting ? SocialPost.mock : []
    @State private var likedPostIDs: Set<UUID> = []
    @State private var savedPostIDs: Set<UUID> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.md) {
                discoveryHeader(active: .following)
                newFilterCard
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
    }

    private var newFilterCard: some View {
        NavigationLink(value: AppRoute.filterDetail(id: "Tokyo Night")) {
            HStack(spacing: Sp.sm) {
                FMFilterCoverArt(motif: .cinematic)
                    .frame(width: 60, height: 75)
                    .clipShape(RoundedRectangle(cornerRadius: R.md))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Alex 새 필터 게시")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.4)
                        .foregroundStyle(FMColors.Accent.primary)
                    Text("Tokyo Night")
                        .fmTypography(.headline)
                        .foregroundStyle(FMColors.Text.primary)
                    Text("시네마틱 · 1시간 전 · ↓ \(formattedDownloadCount(0))")
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

    private func postCard(_ post: SocialPost) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: Sp.sm) {
                avatar(initials: post.initials, colors: post.avatarColors, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.author)
                        .fmTypography(.subhead)
                        .fontWeight(.semibold)
                        .foregroundStyle(FMColors.Text.primary)
                    Text(post.handle + " · " + post.time)
                        .fmTypography(.caption)
                        .foregroundStyle(FMColors.Text.tertiary)
                }
                Spacer()
                Button {} label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(FMColors.Text.secondary)
                }
            }
            .padding(Sp.md)

            ZStack(alignment: .bottomLeading) {
                FMFilterCoverArt(motif: post.motif)
                Text("\(post.filterName) · \(post.intensity)% · ↓ \(formattedDownloadCount(post.downloadCount))")
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
                    toggle(&likedPostIDs, id: post.id)
                } label: {
                    Label("\(post.likeCount + (likedPostIDs.contains(post.id) && !post.isLiked ? 1 : 0))", systemImage: likedPostIDs.contains(post.id) ? "heart.fill" : "heart")
                }
                .foregroundStyle(likedPostIDs.contains(post.id) ? FMColors.Semantic.error : FMColors.Text.secondary)
                .accessibilityIdentifier("social.following.post.like")

                NavigationLink(value: AppRoute.reviews(filterId: post.filterName)) {
                    Label("\(post.reviewCount)", systemImage: "bubble.left")
                }
                .accessibilityIdentifier("social.following.post.reviews")

                Button {} label: {
                    Image(systemName: "square.and.arrow.up")
                }

                Spacer()
                Button {
                    toggle(&savedPostIDs, id: post.id)
                } label: {
                    Image(systemName: savedPostIDs.contains(post.id) ? "bookmark.fill" : "bookmark")
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

    private func toggle(_ set: inout Set<UUID>, id: UUID) {
        if set.contains(id) {
            set.remove(id)
        } else {
            set.insert(id)
        }
        FMHaptic.selection.play()
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

private struct SocialReview: Identifiable {
    let id = UUID()
    let name: String
    let handle: String
    let initials: String
    let avatarColors: [Color]
    let time: String
    let body: String
    let stars: Int
    let helpfulCount: Int
    let isHelpful: Bool
    let isVerifiedDownload: Bool
    let makerReply: SocialMakerReply?

    static let mock: [SocialReview] = [
        SocialReview(
            name: "민지",
            handle: "@minji.lab",
            initials: "MJ",
            avatarColors: [Color(hex: 0xF3DCC4), Color(hex: 0xD4A482)],
            time: "2시간",
            body: "카페 사진에 진짜 잘 어울려요. 강도 80%가 베스트네요.",
            stars: 5,
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
            name: "Alex",
            handle: "@alex.grade",
            initials: "AL",
            avatarColors: [Color(hex: 0xAEC59A), Color(hex: 0x4A6A3C)],
            time: "5시간",
            body: "Mid-tone에 살짝 마젠타가 도는 느낌이 좋네요. 어떤 LUT 사이즈로 만드셨어요? 33³ 인가요?",
            stars: 4,
            helpfulCount: 12,
            isHelpful: false,
            isVerifiedDownload: true,
            makerReply: nil
        ),
        SocialReview(
            name: "유나",
            handle: "@yuna.diary",
            initials: "YN",
            avatarColors: [Color(hex: 0xAAB5CB), Color(hex: 0x3A4560)],
            time: "어제",
            body: "제 셀카에는 강도 60%가 자연스러웠어요. 추천!",
            stars: 4,
            helpfulCount: 6,
            isHelpful: false,
            isVerifiedDownload: true,
            makerReply: nil
        ),
        SocialReview(
            name: "Emma",
            handle: "@emma.travel",
            initials: "EM",
            avatarColors: [Color(hex: 0xCBD4E0), Color(hex: 0xC79A72)],
            time: "2일",
            body: "유럽 여행 사진들에 진짜 다 잘 맞네요. 다른 비슷한 톤도 있나요?",
            stars: 5,
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
    switch count {
    case ..<1_000:
        return "\(count)"
    case 1_000..<10_000:
        return String(format: "%.1fK", Double(count) / 1_000.0)
    default:
        return "\(count / 1_000)K"
    }
}

private struct SocialFeedItem: Identifiable {
    let id = UUID()
    let title: String
    let author: String
    let downloadCount: Int
    let motif: FMFilterCoverArt.Motif

    static let recommendations: [SocialFeedItem] = [
        .init(title: "Honey Hour", author: "@hellofilms", downloadCount: 3_420, motif: .vintage),
        .init(title: "Brown Sugar", author: "@minji.lab", downloadCount: 2_180, motif: .food),
        .init(title: "Old Polaroid", author: "@studio.haru", downloadCount: 8_760, motif: .vintage),
        .init(title: "Hokkaido", author: "@yuna.diary", downloadCount: 1_090, motif: .travel)
    ]
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
