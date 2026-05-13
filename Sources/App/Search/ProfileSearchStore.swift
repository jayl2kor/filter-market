import Foundation

/// SearchScreen 이 보유하는 프로필 검색 상태 머신.
///
/// - 입력: 이미 디바운스된 쿼리 (`update(query:)`)
/// - 동작: 동일 쿼리 가드 → 캐시 히트 → fresh fetch (이전 Task 취소)
/// - 출력: `results: [ProfileSearchHit]` + `state: LoadState<Void>`
@MainActor
final class ProfileSearchStore: ObservableObject {
    @Published private(set) var results: [ProfileSearchHit] = []
    @Published private(set) var state: LoadState<Void> = .idle

    private let repository: any ProfileSearchRepository
    private var currentTask: Task<Void, Never>?
    private var cache: [String: [ProfileSearchHit]] = [:]
    private var cacheOrder: [String] = []
    private let cacheCapacity: Int
    private var lastQuery: String = ""

    init(
        repository: any ProfileSearchRepository = FirestoreProfileSearchRepository(),
        cacheCapacity: Int = 8
    ) {
        self.repository = repository
        self.cacheCapacity = cacheCapacity
    }

    /// SearchScreen 의 `debouncedQuery` 변화에 대응해 호출. 최소 2자 미만이면 결과 비움.
    func update(query: String, limit: Int = 20) {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized != lastQuery else { return }
        lastQuery = normalized
        currentTask?.cancel()

        guard normalized.count >= 2 else {
            results = []
            state = .idle
            return
        }

        if let cached = cache[normalized] {
            results = cached
            state = .loaded(())
            return
        }

        state = .loading
        currentTask = Task { @MainActor [weak self, repository] in
            do {
                let fetched = try await repository.searchProfiles(query: normalized, limit: limit)
                guard !Task.isCancelled, let self else { return }
                self.results = fetched
                self.state = .loaded(())
                self.storeCache(query: normalized, hits: fetched)
            } catch {
                guard !Task.isCancelled, let self else { return }
                self.results = []
                self.state = .failed(FriendlyError(message: FirestoreErrorMapper.friendlyMessage(for: error)))
            }
        }
    }

    /// Pull-to-refresh 등에서 같은 쿼리로 강제 재실행할 때 사용.
    func refresh(limit: Int = 20) {
        let q = lastQuery
        lastQuery = ""
        cache[q] = nil
        update(query: q, limit: limit)
    }

    func reset() {
        currentTask?.cancel()
        currentTask = nil
        results = []
        state = .idle
        lastQuery = ""
    }

    private func storeCache(query: String, hits: [ProfileSearchHit]) {
        cache[query] = hits
        cacheOrder.removeAll { $0 == query }
        cacheOrder.append(query)
        if cacheOrder.count > cacheCapacity {
            let evict = cacheOrder.removeFirst()
            cache.removeValue(forKey: evict)
        }
    }
}
