import Testing
@testable import moodit

@MainActor
@Suite("Session store")
struct SessionStoreTests {
    @Test("local sign-out fallback clears user context")
    func localSignOutFallback() {
        let store = SessionStore()

        store.setAuthenticated(true)
        store.attach(uid: "user-1")
        store.markProfileLoaded()

        #expect(store.isAuthenticated)
        #expect(store.currentUserID == "user-1")
        #expect(store.hasLoadedProfile)

        store.setLocalAuthenticationFallback(false)

        #expect(!store.isAuthenticated)
        #expect(store.currentUserID == nil)
        #expect(!store.hasLoadedProfile)
    }

    @Test("attaching a new uid resets profile loaded state")
    func attachResetsProfileLoadedState() {
        let store = SessionStore()

        store.attach(uid: "user-1")
        store.markProfileLoaded()
        store.attach(uid: "user-2")

        #expect(store.currentUserID == "user-2")
        #expect(!store.hasLoadedProfile)
    }
}
