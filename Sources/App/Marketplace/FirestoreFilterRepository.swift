import FirebaseFirestore
import Foundation
import Marketplace
import Models

/// Firestore-backed `FilterRepository`. App 모듈에 위치 — Marketplace 모듈은
/// Firebase 의존을 갖지 않도록 DI 역전 패턴을 사용.
///
/// 컬렉션 스키마 (`docs/FIRESTORE_RULES.md` §3 참조):
///   /filters/{filterId}
///     authorUid: String
///     title: String
///     version: String
///     category: String        // FilterCategory.rawValue
///     status: String          // FilterStatus.rawValue
///     useCount: Int
///     downloadCount: Int
///     ratingAvg: Double?
///     priceCoins: Int
///     coverURL: String?
///     signatureSampleURL: String?
///     createdAt: Timestamp
///     engine: { type, minAppVersion, minIOSVersion, lutSize?, lutFile? }
///     author: { uid, displayName }
public final class FirestoreFilterRepository: FilterRepository, @unchecked Sendable {
    private let db: Firestore
    private let collection: String

    public init(db: Firestore = Firestore.firestore(), collection: String = "filters") {
        self.db = db
        self.collection = collection
    }

    public func listFilters() async throws -> [Models.Filter] {
        let snapshot = try await db.collection(collection)
            .whereField("status", isEqualTo: FilterStatus.approved.rawValue)
            .limit(to: 200)
            .getDocuments()
        return await withFreshAuthorProfiles(snapshot.documents.compactMap { Self.decode($0) })
    }

    public func filter(id: Models.Filter.ID) async throws -> Models.Filter {
        let doc = try await db.collection(collection).document(id.uuidString).getDocument()
        guard doc.exists, let filter = Self.decode(doc) else {
            throw FirestoreFilterRepositoryError.notFound(id)
        }
        return await withFreshAuthorProfiles([filter]).first ?? filter
    }

    public func trending(limit: Int = 24) async throws -> [Models.Filter] {
        let snapshot = try await db.collection(collection)
            .whereField("status", isEqualTo: FilterStatus.approved.rawValue)
            .order(by: "useCount", descending: true)
            .limit(to: limit)
            .getDocuments()
        return await withFreshAuthorProfiles(snapshot.documents.compactMap { Self.decode($0) })
    }

    public func newFilters(limit: Int = 24) async throws -> [Models.Filter] {
        let snapshot = try await db.collection(collection)
            .whereField("status", isEqualTo: FilterStatus.approved.rawValue)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        return await withFreshAuthorProfiles(snapshot.documents.compactMap { Self.decode($0) })
    }

    public func search(query: String, category: FilterCategory? = nil, limit: Int = 50) async throws -> [Models.Filter] {
        // Firestore는 full-text search를 지원하지 않으므로 client-side 필터링.
        // 향후 Algolia/Typesense 연동 시 이 메서드를 교체 (ADR-0004 참조).
        var ref: Query = db.collection(collection)
            .whereField("status", isEqualTo: FilterStatus.approved.rawValue)
        if let category {
            ref = ref.whereField("category", isEqualTo: category.rawValue)
        }
        let snapshot = try await ref.limit(to: 200).getDocuments()
        let all = await withFreshAuthorProfiles(snapshot.documents.compactMap { Self.decode($0) })
        let q = query.lowercased()
        if q.isEmpty {
            return Array(all.prefix(limit))
        }
        return Array(
            all
                .filter { f in
                    f.title.lowercased().contains(q)
                        || f.author.displayName.lowercased().contains(q)
                }
                .prefix(limit)
        )
    }

    private func withFreshAuthorProfiles(_ filters: [Models.Filter]) async -> [Models.Filter] {
        let uids = Array(Set(filters.map(\.author.uid).filter { !$0.isEmpty && $0 != "unknown" }))
        guard !uids.isEmpty else { return filters }

        var profiles: [String: [String: Any]] = [:]
        for uid in uids {
            do {
                let doc = try await db.collection("users").document(uid).getDocument()
                if let data = doc.data() {
                    profiles[uid] = data
                }
            } catch {
                continue
            }
        }

        return filters.map { filter in
            Self.filter(filter, applyingAuthorProfileData: profiles[filter.author.uid])
        }
    }

    /// Firestore document → `Models.Filter`. 누락 필드는 기본값으로 흡수, 핵심 필드(id/title) 누락 시 nil.
    static func decode(_ doc: DocumentSnapshot) -> Models.Filter? {
        guard let data = doc.data() else { return nil }
        guard let title = data["title"] as? String else { return nil }
        guard let id = UUID(uuidString: doc.documentID) else { return nil }

        let version = (data["version"] as? String) ?? "1.0.0"
        let categoryRaw = (data["category"] as? String) ?? FilterCategory.cinematic.rawValue
        let category = FilterCategory(rawValue: categoryRaw) ?? .cinematic
        let statusRaw = (data["status"] as? String) ?? FilterStatus.approved.rawValue
        let status = FilterStatus(rawValue: statusRaw) ?? .approved
        let useCount = (data["useCount"] as? Int) ?? 0
        let downloadCount = (data["downloadCount"] as? Int) ?? 0
        let reviewCount = (data["reviewCount"] as? Int) ?? 0
        let likeCount = (data["likeCount"] as? Int) ?? 0
        let priceCoins = (data["priceCoins"] as? Int) ?? 0
        let ratingAvg = data["ratingAvg"] as? Double
        let coverURLString = data["coverURL"] as? String
        let coverURL = coverURLString.flatMap { URL(string: $0) }
        let signatureSampleURLString = data["signatureSampleURL"] as? String
        let signatureSampleURL = signatureSampleURLString.flatMap { URL(string: $0) }
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()

        let authorMap = data["author"] as? [String: Any]
        let authorUid = (authorMap?["uid"] as? String) ?? (data["authorUid"] as? String) ?? "unknown"
        let authorDisplayName = (authorMap?["displayName"] as? String) ?? "Unknown"
        let authorAvatarURL = Self.url(
            authorMap?["avatarURL"],
            authorMap?["photoURL"],
            data["authorAvatarURL"],
            data["authorPhotoURL"]
        )
        let author = FilterAuthor(uid: authorUid, displayName: authorDisplayName, avatarURL: authorAvatarURL)

        let engineMap = data["engine"] as? [String: Any]
        let engineTypeRaw = (engineMap?["type"] as? String) ?? FilterEngineType.lutParams.rawValue
        let engineType = FilterEngineType(rawValue: engineTypeRaw) ?? .lutParams
        let minAppVersion = (engineMap?["minAppVersion"] as? String) ?? "1.0.0"
        let minIOSVersion = (engineMap?["minIOSVersion"] as? String) ?? "17.0"
        let lutSize = engineMap?["lutSize"] as? Int
        let lutFile = engineMap?["lutFile"] as? String
        let engine = FilterEngineDescriptor(
            type: engineType,
            minAppVersion: minAppVersion,
            minIOSVersion: minIOSVersion,
            lutSize: lutSize,
            lutFile: lutFile
        )

        return Models.Filter(
            id: id,
            title: title,
            version: version,
            author: author,
            category: category,
            engine: engine,
            useCount: useCount,
            createdAt: createdAt,
            status: status,
            priceCoins: priceCoins,
            coverURL: coverURL,
            signatureSampleURL: signatureSampleURL,
            ratingAvg: ratingAvg,
            downloadCount: downloadCount,
            reviewCount: reviewCount,
            likeCount: likeCount
        )
    }

    static func filter(_ filter: Models.Filter, applyingAuthorProfileData data: [String: Any]?) -> Models.Filter {
        guard let data else { return filter }
        let displayName = Self.stringValue(data["displayName"], data["handle"])
            ?? filter.author.displayName
        let avatarURL = Self.url(data["avatarURL"], data["photoURL"])
            ?? filter.author.avatarURL
        let author = FilterAuthor(uid: filter.author.uid, displayName: displayName, avatarURL: avatarURL)
        return Models.Filter(
            id: filter.id,
            title: filter.title,
            version: filter.version,
            author: author,
            category: filter.category,
            engine: filter.engine,
            useCount: filter.useCount,
            createdAt: filter.createdAt,
            status: filter.status,
            priceCoins: filter.priceCoins,
            coverURL: filter.coverURL,
            signatureSampleURL: filter.signatureSampleURL,
            ratingAvg: filter.ratingAvg,
            downloadCount: filter.downloadCount,
            reviewCount: filter.reviewCount,
            likeCount: filter.likeCount,
            tags: filter.tags
        )
    }

    private static func stringValue(_ values: Any?...) -> String? {
        for value in values {
            if let string = value as? String {
                let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
        }
        return nil
    }

    private static func url(_ values: Any?...) -> URL? {
        for value in values {
            if let string = value as? String,
               let url = URL(string: string) {
                return url
            }
        }
        return nil
    }
}

public enum FirestoreFilterRepositoryError: Error, Sendable {
    case notFound(Models.Filter.ID)
    case decodeFailed(documentId: String)
}
