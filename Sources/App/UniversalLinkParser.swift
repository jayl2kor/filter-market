import Foundation

/// Resolves a `URL` (custom scheme `moodit://` or universal link
/// `https://moodit.app/*`) to an `AppRoute` for in-app navigation.
///
/// Supported shapes:
///   - `moodit://filter/<slug>` → `.filterDetail(id: slug)`
///   - `moodit://reviews/<slug>` → `.reviews(filterId: slug)`
///   - `moodit://maker/<handle>` → `.otherProfileHandle(handle: handle)`
///   - `moodit://search?q=<query>&category=<cat>` → `.search(initialQuery:category:)`
///   - `moodit://notifications` → `.notifications`
///   - `https://moodit.app/f/<slug>` → `.filterDetail(id: slug)`
///   - `https://moodit.app/u/<handle>` → `.otherProfileHandle(handle: handle)`
///   - `https://moodit.app/r/<slug>` → `.reviews(filterId: slug)`
///   - `https://moodit.app/notifications` → `.notifications`
///
/// Server-sent push payloads provide a `data` map with `kind` and
/// `filterId`/`actorUid`. `route(forPushUserInfo:)` translates that map to a
/// route via the same logic — share with universal link routing so a future
/// payload contract change touches one place.
enum UniversalLinkParser {

    /// Hosts treated as moodit's domain. Add staging/preview hosts here as needed.
    private static let mooditHosts: Set<String> = ["moodit.app", "www.moodit.app"]

    /// Custom URL schemes registered for moodit.
    private static let mooditSchemes: Set<String> = ["moodit"]

    static func route(for url: URL) -> AppRoute? {
        let scheme = url.scheme?.lowercased() ?? ""
        let host = url.host?.lowercased() ?? ""

        // Path components excluding the leading "/".
        let pathParts = url.pathComponents.filter { $0 != "/" }

        if mooditSchemes.contains(scheme) {
            return routeForCustomScheme(host: host, pathParts: pathParts, url: url)
        }
        if scheme == "https" || scheme == "http" {
            guard mooditHosts.contains(host) else { return nil }
            return routeForUniversalLink(pathParts: pathParts, url: url)
        }
        return nil
    }

    /// `moodit://<host>/<extra…>`
    private static func routeForCustomScheme(host: String, pathParts: [String], url: URL) -> AppRoute? {
        switch host {
        case "filter":
            guard let slug = pathParts.first, !slug.isEmpty else { return nil }
            return .filterDetail(id: slug)
        case "reviews":
            guard let slug = pathParts.first, !slug.isEmpty else { return nil }
            return .reviews(filterId: slug)
        case "maker":
            guard let handle = pathParts.first, !handle.isEmpty else { return nil }
            return .otherProfileHandle(handle: handle)
        case "search":
            return searchRoute(from: url)
        case "notifications":
            return .notifications
        default:
            return nil
        }
    }

    /// `https://moodit.app/<first>/<slug?>`
    private static func routeForUniversalLink(pathParts: [String], url: URL) -> AppRoute? {
        guard let first = pathParts.first?.lowercased() else { return nil }
        switch first {
        case "f":
            guard let slug = pathParts.dropFirst().first, !slug.isEmpty else { return nil }
            return .filterDetail(id: slug)
        case "r":
            guard let slug = pathParts.dropFirst().first, !slug.isEmpty else { return nil }
            return .reviews(filterId: slug)
        case "u":
            guard let handle = pathParts.dropFirst().first, !handle.isEmpty else { return nil }
            return .otherProfileHandle(handle: handle)
        case "search":
            return searchRoute(from: url)
        case "notifications":
            return .notifications
        default:
            return nil
        }
    }

    private static func searchRoute(from url: URL) -> AppRoute {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let query = components?.queryItems?.first(where: { $0.name == "q" })?.value
        let category = components?.queryItems?.first(where: { $0.name == "category" })?.value
        return .search(initialQuery: query, category: category)
    }

    // MARK: - Push payload

    /// Resolves a route from a push notification's `userInfo["data"]` map.
    /// The server contract:
    ///   - `kind`: "review" | "like" | "download" | "followRequest" | "system"
    ///   - `filterId`: optional, present for review/like/download
    ///   - `actorUid`: optional, present for like/download/followRequest
    static func route(forPushUserInfo userInfo: [AnyHashable: Any]) -> AppRoute? {
        let data = (userInfo["data"] as? [String: Any]) ?? userInfo as? [String: Any] ?? [:]
        let kind = (data["kind"] as? String) ?? ""

        switch kind {
        case "review":
            guard let filterId = data["filterId"] as? String, !filterId.isEmpty else { return nil }
            return .reviews(filterId: filterId)
        case "like", "download":
            guard let filterId = data["filterId"] as? String, !filterId.isEmpty else { return nil }
            return .filterDetail(id: filterId)
        case "followRequest":
            guard let uid = data["actorUid"] as? String, !uid.isEmpty else { return nil }
            return .otherProfile(uid: uid)
        case "system":
            return .notifications
        case "topup":
            return .walletTopup
        case "purchase":
            // Coin purchase notification — open wallet ledger.
            return .walletTransactions
        case "refund":
            return .refundRequest(orderId: nil)
        case "proSubscription":
            return .proStatus
        default:
            return nil
        }
    }
}
