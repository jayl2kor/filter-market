import Foundation
import Models

/// `FilterRepository` that delegates to a `primary` source and falls back to a
/// `fallback` source when the primary returns no data or throws.
///
/// Production wiring composes `FirestoreFilterRepository` (live `downloadCount`,
/// `useCount`, etc.) with `BundleSeedFilterRepository` (deterministic offline
/// catalog) so the marketplace UI reflects server-side counters while still
/// rendering something useful when the network is unavailable.
public final class CompositeFilterRepository: FilterRepository, @unchecked Sendable {
    private let primary: any FilterRepository
    private let fallback: any FilterRepository

    public init(primary: any FilterRepository, fallback: any FilterRepository) {
        self.primary = primary
        self.fallback = fallback
    }

    public func listFilters() async throws -> [Filter] {
        do {
            let primaryResult = try await primary.listFilters()
            if !primaryResult.isEmpty {
                return primaryResult
            }
        } catch {
            // Primary unavailable — fall through to the bundled catalog.
        }
        return try await fallback.listFilters()
    }

    public func filter(id: Filter.ID) async throws -> Filter {
        do {
            return try await primary.filter(id: id)
        } catch {
            return try await fallback.filter(id: id)
        }
    }
}
