import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import FirebaseFunctions
import Foundation

enum FirebaseSideEffects {
    static var isConfigured: Bool {
        FirebaseApp.app() != nil
    }

    static var currentUID: String? {
        guard isConfigured else { return nil }
        return Auth.auth().currentUser?.uid
    }

    static var currentUser: User? {
        guard isConfigured else { return nil }
        return Auth.auth().currentUser
    }

    static var currentUserEmail: String? {
        guard isConfigured else { return nil }
        return Auth.auth().currentUser?.email?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static var currentUserDisplayName: String? {
        guard isConfigured else { return nil }
        return Auth.auth().currentUser?.displayName
    }

    static var hasCurrentUser: Bool {
        currentUID != nil
    }

    static func currentUserOwns(uid: String?) -> Bool {
        guard let uid else { return false }
        return currentUID == uid
    }

    static func signOut() throws {
        guard isConfigured else { return }
        try Auth.auth().signOut()
    }

    static func refreshedRoleClaim() async throws -> String? {
        guard isConfigured, let user = Auth.auth().currentUser else {
            return nil
        }
        let result = try await user.getIDTokenResult(forcingRefresh: true)
        return result.claims["role"] as? String
    }

    static func firestore() -> Firestore {
        Firestore.firestore()
    }

    static func callable(_ name: String, region: String = "asia-northeast3") -> HTTPSCallable {
        Functions.functions(region: region).httpsCallable(name)
    }

    static func callFunction(
        _ name: String,
        region: String = "asia-northeast3",
        data: [String: Any]
    ) async throws -> HTTPSCallableResult {
        try await callable(name, region: region).call(data)
    }

    static func callAuthenticatedFunction(
        _ name: String,
        region: String = "asia-northeast3",
        data: [String: Any]
    ) async throws -> HTTPSCallableResult {
        guard let user = currentUser else {
            throw FirebaseAuthRequestError.unauthenticated
        }
        _ = try await user.getIDTokenResult(forcingRefresh: false)

        do {
            return try await callFunction(name, region: region, data: data)
        } catch {
            guard isFunctionUnauthenticated(error), let refreshedUser = currentUser else {
                throw error
            }
            _ = try await refreshedUser.getIDTokenResult(forcingRefresh: true)
            return try await callFunction(name, region: region, data: data)
        }
    }

    static func isFunctionNotFound(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == FunctionsErrorDomain
            && nsError.code == FunctionsErrorCode.notFound.rawValue
    }

    static func isFunctionUnauthenticated(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == FunctionsErrorDomain
            && nsError.code == FunctionsErrorCode.unauthenticated.rawValue
    }

    static func handleOwnerUID(for handle: String) async throws -> String? {
        let snapshot = try await firestore()
            .collection("handles")
            .document(handle)
            .getDocument()
        guard snapshot.exists else { return nil }
        return snapshot.data()?["uid"] as? String
    }

    static func reserveHandle(_ handle: String, for uid: String) async throws {
        _ = uid
        _ = try await callFunction(
            "setHandle",
            data: ["handle": handle]
        )
    }
}

enum FirebaseAuthRequestError: LocalizedError {
    case unauthenticated

    var errorDescription: String? {
        switch self {
        case .unauthenticated:
            return "로그인이 필요합니다."
        }
    }
}
