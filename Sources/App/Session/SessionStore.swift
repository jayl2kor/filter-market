import Combine
import FirebaseAuth
import FirebaseCore
import Foundation

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var isAuthenticated = false
    @Published private(set) var hasLoadedProfile = false
    private(set) var currentUserID: String?

    private var authStateHandle: AuthStateDidChangeListenerHandle?

    nonisolated static var currentFirebaseUser: User? {
        guard !isUnitTesting, FirebaseApp.app() != nil else { return nil }
        return Auth.auth().currentUser
    }

    nonisolated static var currentFirebaseUID: String? {
        currentFirebaseUser?.uid
    }

    nonisolated static var isUnitTesting: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    func subscribeToAuthState(onAuthChanged: @escaping @MainActor (User?) -> Void) {
        #if DEBUG
        guard !isUITesting else {
            hasLoadedProfile = true
            isAuthenticated = Self.uiTestingAuthenticationFlag()
            return
        }
        #endif
        guard !Self.isUnitTesting, FirebaseApp.app() != nil else {
            hasLoadedProfile = true
            isAuthenticated = false
            return
        }
        guard authStateHandle == nil else { return }
        authStateHandle = Auth.auth().addStateDidChangeListener { _, user in
            Task { @MainActor in
                self.isAuthenticated = (user != nil)
                onAuthChanged(user)
            }
        }
    }

    func setLocalAuthenticationFallback(_ authenticated: Bool) {
        isAuthenticated = authenticated
        if !authenticated {
            currentUserID = nil
            hasLoadedProfile = false
        }
    }

    func attach(uid: String?) {
        currentUserID = uid
        hasLoadedProfile = false
    }

    func markProfileLoaded() {
        hasLoadedProfile = true
    }

    func markProfileUnloaded() {
        hasLoadedProfile = false
    }

    func setAuthenticated(_ authenticated: Bool) {
        isAuthenticated = authenticated
    }

    #if DEBUG
    private static func uiTestingAuthenticationFlag() -> Bool {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-isAuthenticated"),
              args.indices.contains(index + 1) else {
            return false
        }
        return ["1", "true", "yes"].contains(args[index + 1].lowercased())
    }
    #endif
}
