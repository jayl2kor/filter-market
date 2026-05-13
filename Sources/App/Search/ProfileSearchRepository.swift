import FirebaseFirestore
import Foundation

protocol ProfileSearchRepository: Sendable {
    func searchProfiles(query: String, limit: Int) async throws -> [ProfileSearchHit]
}

/// Firestore `/users` 기반 prefix 검색 구현.
///
/// 전략:
/// 1) `/handles` 컬렉션 documentID prefix 쿼리 — 핸들은 `setHandle` 에서 lowercased 강제.
///    매칭된 uid 들을 `/users` 에서 `where(in:)` 으로 일괄 fetch (30개 청크).
/// 2) `/users.displayName` 범위 쿼리 — 첫 토큰 prefix 매칭. 한글은 case 무관,
///    영문은 cap-sensitive (Phase 2 에서 displayNameLowercased 필드 도입 시 정상화).
/// 3) uid 기준 dedupe — handle 일치 결과 우선.
struct FirestoreProfileSearchRepository: ProfileSearchRepository {
    init() {}

    func searchProfiles(query: String, limit: Int) async throws -> [ProfileSearchHit] {
        let normalized = Self.normalize(query)
        guard normalized.count >= 2 else { return [] }

        async let handleHits = Self.searchHandles(prefix: normalized, limit: limit)
        async let nameHits = Self.searchDisplayName(prefix: query.trimmingCharacters(in: .whitespacesAndNewlines), limit: limit)

        let (handles, names) = try await (handleHits, nameHits)
        var seen: Set<String> = []
        var merged: [ProfileSearchHit] = []
        for hit in handles + names where !seen.contains(hit.uid) {
            seen.insert(hit.uid)
            merged.append(hit)
            if merged.count >= limit { break }
        }
        return merged
    }

    // MARK: - Internals

    private static func searchHandles(prefix: String, limit: Int) async throws -> [ProfileSearchHit] {
        let endMarker = prefix + "\u{f8ff}"
        let snapshot = try await FirebaseSideEffects.firestore()
            .collection("handles")
            .order(by: FieldPath.documentID())
            .start(at: [prefix])
            .end(at: [endMarker])
            .limit(to: limit)
            .getDocuments()

        let uids = snapshot.documents.compactMap { $0.data()["uid"] as? String }
        guard !uids.isEmpty else { return [] }
        return try await fetchUsers(uids: uids)
    }

    private static func searchDisplayName(prefix: String, limit: Int) async throws -> [ProfileSearchHit] {
        guard !prefix.isEmpty else { return [] }
        let endMarker = prefix + "\u{f8ff}"
        let snapshot = try await FirebaseSideEffects.firestore()
            .collection("users")
            .order(by: "displayName")
            .start(at: [prefix])
            .end(at: [endMarker])
            .limit(to: limit)
            .getDocuments()
        return snapshot.documents.compactMap { decode(uid: $0.documentID, data: $0.data()) }
    }

    private static func fetchUsers(uids: [String]) async throws -> [ProfileSearchHit] {
        let chunks = uids.chunked(into: 30)
        var results: [ProfileSearchHit] = []
        try await withThrowingTaskGroup(of: [ProfileSearchHit].self) { group in
            for chunk in chunks {
                group.addTask {
                    let snap = try await FirebaseSideEffects.firestore()
                        .collection("users")
                        .whereField(FieldPath.documentID(), in: chunk)
                        .getDocuments()
                    return snap.documents.compactMap { decode(uid: $0.documentID, data: $0.data()) }
                }
            }
            for try await partial in group {
                results.append(contentsOf: partial)
            }
        }
        // /handles 쿼리 순서를 최대한 보존하기 위해 uid 입력 순서로 정렬.
        let order = Dictionary(uniqueKeysWithValues: uids.enumerated().map { ($0.element, $0.offset) })
        return results.sorted { (order[$0.uid] ?? Int.max) < (order[$1.uid] ?? Int.max) }
    }

    // MARK: - Decode

    /// 테스트에서 사용 가능하도록 internal 접근.
    static func decode(uid: String, data: [String: Any]) -> ProfileSearchHit? {
        if let visible = data["makerPageVisible"] as? Bool, !visible { return nil }
        if data["deletedAt"] != nil { return nil }

        let displayName = (data["displayName"] as? String) ?? ""
        let rawHandle = (data["handle"] as? String) ?? ""
        guard !displayName.isEmpty || !rawHandle.isEmpty else { return nil }

        let handle: String
        if rawHandle.isEmpty {
            handle = "@\(String(uid.prefix(8)))"
        } else {
            handle = rawHandle.hasPrefix("@") ? rawHandle : "@\(rawHandle)"
        }

        let avatarURL = parseURL(data["avatarURL"]) ?? parseURL(data["photoURL"])
        let initialsSource = displayName.isEmpty ? rawHandle : displayName
        let initials = String(initialsSource.prefix(2)).uppercased()
        let filterCount = (data["filterCount"] as? Int) ?? 0

        return ProfileSearchHit(
            uid: uid,
            displayName: displayName.isEmpty ? handle : displayName,
            handle: handle,
            avatarURL: avatarURL,
            avatarInitials: initials.isEmpty ? "M" : initials,
            filterCount: filterCount
        )
    }

    static func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "@#"))
            .lowercased()
    }

    private static func parseURL(_ value: Any?) -> URL? {
        guard let raw = value as? String, !raw.isEmpty else { return nil }
        return URL(string: raw)
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map { offset in
            Array(self[offset..<Swift.min(offset + size, count)])
        }
    }
}
