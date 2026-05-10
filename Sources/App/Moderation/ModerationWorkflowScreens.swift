import DesignSystem
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import Models
import SwiftUI

struct ReportFormScreen: View {
    @Environment(\.dismiss) private var dismiss
    let target: ReportTarget

    @State private var reasonCode: String = "spam"
    @State private var detail: String = ""
    @State private var isProcessing = false
    @State private var statusMessage: String?

    private let reasonOptions: [(code: String, label: String)] = [
        ("spam", "스팸 / 무의미한 콘텐츠"),
        ("nsfw", "성적/노출 콘텐츠"),
        ("violence", "폭력 / 잔혹 콘텐츠"),
        ("hate", "혐오 발언"),
        ("ip", "저작권 침해"),
        ("other", "기타")
    ]

    var body: some View {
        Form {
            Section(header: Text("신고 대상")) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(targetTitle)
                        .font(Font.fmBody)
                        .foregroundStyle(FMColors.Text.primary)
                    Text(targetSubtitle)
                        .font(Font.fmCaption)
                        .foregroundStyle(FMColors.Text.tertiary)
                }
                .textSelection(.enabled)
                .accessibilityIdentifier("report.target")
            }
            Section(header: Text("사유")) {
                Picker("사유 선택", selection: $reasonCode) {
                    ForEach(reasonOptions, id: \.code) { opt in
                        Text(opt.label).tag(opt.code)
                    }
                }
                .accessibilityIdentifier("report.reason")
            }
            Section(header: Text("상세 설명 (선택)")) {
                TextEditor(text: $detail).frame(minHeight: 100)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.return)
                    .accessibilityIdentifier("report.detail")
            }
            if let statusMessage {
                Section { Text(statusMessage).foregroundStyle(FMColors.Text.secondary) }
            }
            Section {
                Button {
                    Task { await submit() }
                } label: {
                    if isProcessing { ProgressView() } else { Text("신고 제출") }
                }
                .disabled(isProcessing || !target.isSubmittable)
                .accessibilityIdentifier("report.submit")
            }
        }
        .navigationTitle("신고")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var targetTitle: String {
        switch target {
        case .filter:
            return "필터 신고"
        case .review:
            return "리뷰 신고"
        case .user:
            return "사용자 신고"
        }
    }

    private var targetSubtitle: String {
        switch target {
        case .filter(let id):
            return id.isEmpty ? "신고 대상 필터가 지정되지 않았습니다." : "필터 ID: \(id)"
        case .review(let id, let filterId, let authorUid):
            let author = authorUid.map { " · 작성자 \($0)" } ?? ""
            return "필터 \(filterId) · 리뷰 \(id)\(author)"
        case .user(let uid):
            return uid.isEmpty ? "신고 대상 사용자가 지정되지 않았습니다." : "사용자 UID: \(uid)"
        }
    }

    private func submit() async {
        isProcessing = true
        defer { isProcessing = false }
        do {
            let functions = Functions.functions(region: "asia-northeast3")
            let trimmedDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
            switch target {
            case .filter(let id):
                let callable = functions.httpsCallable("reportFilter")
                _ = try await callable.call([
                    "filterId": id,
                    "reasonCode": reasonCode,
                    "detail": trimmedDetail
                ])
            case .review(let id, let filterId, let authorUid):
                let callable = functions.httpsCallable("reportReview")
                var payload: [String: Any] = [
                    "filterId": filterId,
                    "reviewId": id,
                    "reasonCode": reasonCode,
                    "detail": trimmedDetail
                ]
                if let authorUid {
                    payload["authorUid"] = authorUid
                }
                _ = try await callable.call(payload)
            case .user(let uid):
                let callable = functions.httpsCallable("reportUser")
                _ = try await callable.call([
                    "targetUid": uid,
                    "reasonCode": reasonCode,
                    "detail": trimmedDetail
                ])
            }
            statusMessage = "신고가 접수되었습니다. 24시간 내 검토합니다."
            detail = ""
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            dismiss()
        } catch {
            statusMessage = "오류: \(error.localizedDescription)"
        }
    }
}

struct ModerationQueueScreen: View {
    @State private var pendingFilters: [Models.Filter] = []
    @State private var isLoading = false
    @State private var listener: ListenerRegistration?

    var body: some View {
        Group {
            if pendingFilters.isEmpty {
                FMEmptyState(.emptyMarket)
                    .padding(.horizontal, Sp.md)
                    .accessibilityIdentifier("modqueue.empty")
            } else {
                List(pendingFilters) { filter in
                    NavigationLink(value: AppRoute.modDetail(id: filter.id.uuidString)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(filter.title).font(Font.fmHeadline)
                            Text(filter.author.displayName).font(Font.fmCaption)
                                .foregroundStyle(FMColors.Text.secondary)
                            if let createdAt = filter.createdAt {
                                Text(createdAt, style: .date)
                                    .font(Font.fmCaption).foregroundStyle(FMColors.Text.tertiary)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable { await load() }
            }
        }
        .background(FMColors.Background.bg1.ignoresSafeArea())
        .navigationTitle("검수 큐")
        .navigationBarTitleDisplayMode(.inline)
        .task { attachListener() }
        .onDisappear {
            listener?.remove()
            listener = nil
        }
    }

    private func load() async {
        #if DEBUG
        guard !isUITesting else { return }
        #endif
        isLoading = true
        defer { isLoading = false }
        do {
            let snapshot = try await Firestore.firestore()
                .collection("filters")
                .whereField("status", isEqualTo: "pending_review")
                .order(by: "createdAt", descending: true)
                .limit(to: 100)
                .getDocuments()
            pendingFilters = snapshot.documents.compactMap { FirestoreFilterRepository.decode($0) }
        } catch {
            pendingFilters = []
        }
    }

    private func attachListener() {
        #if DEBUG
        guard !isUITesting else { return }
        #endif
        listener?.remove()
        isLoading = true
        listener = Firestore.firestore()
            .collection("filters")
            .whereField("status", isEqualTo: "pending_review")
            .order(by: "createdAt", descending: true)
            .limit(to: 100)
            .addSnapshotListener { snapshot, _ in
                let filters = snapshot?.documents.compactMap { FirestoreFilterRepository.decode($0) } ?? []
                Task { @MainActor in
                    pendingFilters = filters
                    isLoading = false
                }
            }
    }
}

struct ModerationDetailScreen: View {
    let itemID: String

    @Environment(\.dismiss) private var dismiss
    @State private var filter: Models.Filter?
    @State private var filterDescription: String?
    @State private var isProcessing = false
    @State private var isLoading = false
    @State private var hasCompletedAction = false
    @State private var statusMessage: String?
    @State private var rejectReason: String = ""
    @State private var lastAction: ModerationAction?
    @State private var dismissTask: Task<Void, Never>?

    var body: some View {
        Form {
            if isLoading {
                Section {
                    HStack {
                        ProgressView()
                        Text("검수 정보를 불러오는 중")
                            .foregroundStyle(FMColors.Text.secondary)
                    }
                }
            }

            if let filter {
                previewSection(filter)
                metadataSection(filter)
                engineSection(filter)
            } else {
                Section(header: Text("필터 정보")) {
                    Text(itemID.isEmpty ? "필터 ID가 없습니다." : "필터 정보를 불러올 수 없습니다.")
                        .foregroundStyle(FMColors.Text.secondary)
                }
            }

            Section(header: Text("필터 ID")) {
                Text(itemID).font(Font.fmCaption).foregroundStyle(FMColors.Text.secondary)
            }
            Section {
                Button {
                    Task { await approve() }
                } label: {
                    if isProcessing { ProgressView() } else { Text("승인 (Approve)") }
                }
                .disabled(itemID.isEmpty || filter == nil || isProcessing || hasCompletedAction)
                .accessibilityIdentifier("modDetail.approve")
            }
            Section(header: Text("거부 사유")) {
                TextEditor(text: $rejectReason).frame(minHeight: 80)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.return)
                    .accessibilityIdentifier("modDetail.reason")
                Button {
                    Task { await reject() }
                } label: {
                    if isProcessing { ProgressView() } else { Text("거부 (Reject)").foregroundStyle(FMColors.Semantic.error) }
                }
                .disabled(itemID.isEmpty || filter == nil || rejectReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing || hasCompletedAction)
                .accessibilityIdentifier("modDetail.reject")
            }
            if let statusMessage {
                Section {
                    Text(statusMessage).foregroundStyle(FMColors.Text.secondary)
                    if lastAction != nil {
                        Button("되돌리기") {
                            Task { await undoLastAction() }
                        }
                        .disabled(isProcessing)
                        .accessibilityIdentifier("modDetail.undo")
                    }
                }
            }
        }
        .navigationTitle("검수 상세")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadDetail() }
        .onDisappear {
            dismissTask?.cancel()
            dismissTask = nil
        }
    }

    private func approve() async {
        isProcessing = true
        defer { isProcessing = false }
        do {
            let callable = Functions.functions(region: "asia-northeast3").httpsCallable("approveFilter")
            _ = try await callable.call(["filterId": itemID])
            completeAction(.approved)
        } catch {
            statusMessage = "오류: \(error.localizedDescription)"
        }
    }

    private func reject() async {
        isProcessing = true
        defer { isProcessing = false }
        do {
            let callable = Functions.functions(region: "asia-northeast3").httpsCallable("rejectFilter")
            let reason = rejectReason.trimmingCharacters(in: .whitespacesAndNewlines)
            _ = try await callable.call(["filterId": itemID, "reason": reason])
            completeAction(.rejected)
            rejectReason = ""
        } catch {
            statusMessage = "오류: \(error.localizedDescription)"
        }
    }

    private func undoLastAction() async {
        dismissTask?.cancel()
        dismissTask = nil
        isProcessing = true
        defer { isProcessing = false }
        do {
            let callable = Functions.functions(region: "asia-northeast3").httpsCallable("undoModerationDecision")
            _ = try await callable.call(["filterId": itemID])
            hasCompletedAction = false
            lastAction = nil
            statusMessage = "되돌렸습니다. 다시 검수할 수 있습니다."
            await loadDetail()
        } catch {
            statusMessage = "되돌리기 실패: \(error.localizedDescription)"
            scheduleDismiss()
        }
    }

    private func completeAction(_ action: ModerationAction) {
        hasCompletedAction = true
        lastAction = action
        statusMessage = "\(action.label) 완료. 5초 안에 되돌릴 수 있습니다."
        scheduleDismiss()
    }

    private func scheduleDismiss() {
        dismissTask?.cancel()
        dismissTask = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { dismiss() }
        }
    }

    private func loadDetail() async {
        #if DEBUG
        guard !isUITesting else { return }
        #endif
        guard !itemID.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let snapshot = try await Firestore.firestore()
                .collection("filters").document(itemID)
                .getDocument()
            filter = FirestoreFilterRepository.decode(snapshot)
            filterDescription = snapshot.data()?["description"] as? String
                ?? snapshot.data()?["summary"] as? String
        } catch {
            statusMessage = "필터 정보 로드 실패: \(error.localizedDescription)"
        }
    }

    private func previewSection(_ filter: Models.Filter) -> some View {
        Section(header: Text("콘텐츠 미리보기")) {
            HStack(spacing: Sp.sm) {
                moderationPreviewTile(title: "커버", url: filter.coverURL, fallbackTitle: filter.title, category: filter.category.rawValue)
                moderationPreviewTile(title: "시그니처 샘플", url: filter.signatureSampleURL ?? filter.coverURL, fallbackTitle: filter.title, category: filter.category.rawValue)
            }
            if let filterDescription, !filterDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(filterDescription)
                    .font(Font.fmBody)
                    .foregroundStyle(FMColors.Text.primary)
            }
        }
    }

    private func metadataSection(_ filter: Models.Filter) -> some View {
        Section(header: Text("필터 메타데이터")) {
            moderationInfoRow("제목", filter.title)
            moderationInfoRow("메이커", "\(filter.author.displayName) · \(filter.author.uid)")
            moderationInfoRow("카테고리", filter.category.rawValue)
            moderationInfoRow("상태", filter.status.rawValue)
            moderationInfoRow("가격", filter.priceCoins > 0 ? "\(filter.priceCoins) 코인" : "무료")
            moderationInfoRow("다운로드", "\(filter.downloadCount > 0 ? filter.downloadCount : filter.useCount)")
            if let ratingAvg = filter.ratingAvg {
                moderationInfoRow("평점", String(format: "%.1f", ratingAvg))
            }
            if let createdAt = filter.createdAt {
                moderationInfoRow("제출일", createdAt.formatted(date: .abbreviated, time: .shortened))
            }
            if !filter.tags.isEmpty {
                Text(filter.tags.map { $0.hasPrefix("#") ? $0 : "#\($0)" }.joined(separator: " "))
                    .font(Font.fmCaption)
                    .foregroundStyle(FMColors.Text.secondary)
            }
        }
    }

    private func engineSection(_ filter: Models.Filter) -> some View {
        Section(header: Text("엔진 / 패키지")) {
            moderationInfoRow("엔진", filter.engine.type.rawValue)
            moderationInfoRow("버전", filter.version)
            moderationInfoRow("최소 앱", filter.engine.minAppVersion)
            moderationInfoRow("최소 iOS", filter.engine.minIOSVersion)
            if let lutSize = filter.engine.lutSize {
                moderationInfoRow("LUT", "\(lutSize)^3")
            }
            if let lutFile = filter.engine.lutFile, !lutFile.isEmpty {
                moderationInfoRow("LUT 파일", lutFile)
            }
        }
    }

    private func moderationInfoRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(Font.fmCaption)
                .foregroundStyle(FMColors.Text.tertiary)
            Spacer()
            Text(value)
                .font(Font.fmCaption)
                .foregroundStyle(FMColors.Text.primary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func moderationPreviewTile(title: String, url: URL?, fallbackTitle: String, category: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            FMRemoteImage(
                url: url,
                cornerRadius: R.md,
                placeholder: {
                    GeometryReader { proxy in
                        FMSkeleton.rect(height: proxy.size.height, cornerRadius: R.md)
                    }
                },
                failure: {
                    FMFilterCoverArt(motif: FilterCoverMotifResolver.motif(for: fallbackTitle, category: category))
                }
            )
            .frame(height: 120)
            .overlay {
                RoundedRectangle(cornerRadius: R.md)
                    .strokeBorder(FMColors.Border.subtle, lineWidth: 1)
            }

            Text(title)
                .font(Font.fmCaption)
                .foregroundStyle(FMColors.Text.secondary)
        }
    }
}

private enum ModerationAction {
    case approved
    case rejected

    var label: String {
        switch self {
        case .approved: "승인"
        case .rejected: "거부"
        }
    }
}

struct BlockListScreen: View {
    @State private var blockedUsers: [BlockedUserEntry] = []
    @State private var listener: ListenerRegistration?
    @State private var loadError: String?
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            if let loadError {
                VStack(alignment: .leading, spacing: Sp.sm) {
                    Text(loadError)
                        .font(Font.fmCaption)
                        .foregroundStyle(FMColors.Semantic.error)
                    Button("다시 시도") { attachListener() }
                        .font(Font.fmCaption)
                        .foregroundStyle(FMColors.Accent.primary)
                        .accessibilityIdentifier("blocklist.retry")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Sp.md)
            }

            if isLoading {
                ProgressView()
                    .padding(.top, Sp.lg)
            } else if blockedUsers.isEmpty {
                FMEmptyState(.emptyBlocklist)
                    .padding(.horizontal, Sp.md)
                    .accessibilityIdentifier("blocklist.empty")
            } else {
                List {
                    ForEach(blockedUsers) { user in
                        HStack {
                            Image(systemName: "person.crop.circle.badge.xmark")
                                .foregroundStyle(FMColors.Semantic.error)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.displayName).font(Font.fmBody)
                                Text(user.subtitle).font(Font.fmCaption)
                                    .foregroundStyle(FMColors.Text.tertiary)
                            }
                            Spacer()
                            Button("차단 해제") { unblock(user) }
                                .font(Font.fmCaption)
                                .foregroundStyle(FMColors.Accent.primary)
                                .accessibilityIdentifier("social.block.toggle")
                        }
                    }
                }
                .listStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .background(FMColors.Background.bg1.ignoresSafeArea())
        .navigationTitle("차단 목록")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { attachListener() }
        .onDisappear {
            listener?.remove()
            listener = nil
        }
    }

    private func attachListener() {
        #if DEBUG
        guard !isUITesting else {
            blockedUsers = []
            loadError = nil
            isLoading = false
            return
        }
        #endif
        listener?.remove()
        guard let uid = Auth.auth().currentUser?.uid else {
            blockedUsers = []
            loadError = "로그인 후 차단 목록을 볼 수 있어요."
            return
        }
        isLoading = true
        loadError = nil
        listener = Firestore.firestore()
            .collection("blocks")
            .whereField("actorUid", isEqualTo: uid)
            .limit(to: 200)
            .addSnapshotListener { snapshot, error in
                Task { @MainActor in
                    isLoading = false
                    if let error {
                        loadError = "차단 목록을 불러오지 못했어요: \(error.localizedDescription)"
                        return
                    }
                    loadError = nil
                    blockedUsers = (snapshot?.documents ?? [])
                        .compactMap(BlockedUserEntry.init(document:))
                        .sorted { $0.displayName < $1.displayName }
                }
            }
    }

    private func unblock(_ user: BlockedUserEntry) {
        #if DEBUG
        guard !isUITesting else {
            blockedUsers.removeAll { $0.id == user.id }
            return
        }
        #endif
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Task {
            do {
                try await Firestore.firestore()
                    .collection("blocks").document("\(uid)_\(user.targetUid)")
                    .delete()
            } catch {
                await MainActor.run {
                    loadError = "차단 해제에 실패했어요: \(error.localizedDescription)"
                }
            }
        }
    }
}

private struct BlockedUserEntry: Identifiable {
    let id: String
    let targetUid: String
    let handle: String?
    let displayName: String

    var subtitle: String {
        handle ?? targetUid
    }

    init?(document: QueryDocumentSnapshot) {
        let data = document.data()
        guard let targetUid = data["targetUid"] as? String, !targetUid.isEmpty else {
            return nil
        }
        self.id = document.documentID
        self.targetUid = targetUid
        let rawHandle = (data["targetHandle"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let rawHandle, !rawHandle.isEmpty {
            self.handle = rawHandle.hasPrefix("@") ? rawHandle : "@\(rawHandle)"
        } else {
            self.handle = nil
        }
        if let rawName = (data["targetDisplayName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !rawName.isEmpty {
            self.displayName = rawName
        } else {
            self.displayName = self.handle ?? String(targetUid.prefix(8))
        }
    }
}

// MARK: - Monetization
