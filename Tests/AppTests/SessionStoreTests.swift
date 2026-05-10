import Foundation
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

    @Test("profile save success commits remote avatar URL and clears local image data")
    func saveProfileSuccessClearsLocalAvatarData() async throws {
        let store = SessionStore()
        let avatarData = Data([0x1, 0x2, 0x3])
        let remoteURL = URL(string: "https://cdn.example.com/users/u1/avatar.jpg")!
        store.profileSaveClient = SessionProfileSaveClient(
            uploadAvatarImageData: { data in
                #expect(data == avatarData)
                return ProfileAvatarUpload(publicURL: remoteURL, objectKey: "users/u1/avatar/avatar.jpg")
            },
            updateProfile: { payload in
                #expect(payload["avatarURL"] as? String == remoteURL.absoluteString)
                #expect(payload["photoURL"] as? String == remoteURL.absoluteString)
                #expect(payload["avatarObjectKey"] as? String == "users/u1/avatar/avatar.jpg")
            },
            setHandle: { handle in
                #expect(handle == "maker")
            }
        )

        let saved = try await store.saveProfile(
            EditableProfile(
                displayName: "Maker",
                handle: "maker",
                bio: "bio",
                website: "",
                makerPageVisible: true,
                photoSharingAllowed: true,
                avatarVariant: 0,
                avatarImageData: avatarData,
                avatarURL: nil
            )
        )

        #expect(saved.avatarURL == remoteURL)
        #expect(saved.avatarImageData == nil)
        #expect(store.editableProfile.avatarURL == remoteURL)
        #expect(store.editableProfile.avatarImageData == nil)
        #expect(store.lastSubmitErrorMessage == nil)
    }

    @Test("profile avatar upload failure surfaces error without committing local preview")
    func saveProfileUploadFailureSurfacesError() async {
        let store = SessionStore()
        let avatarData = Data([0x1, 0x2, 0x3])
        store.profileSaveClient = SessionProfileSaveClient(
            uploadAvatarImageData: { _ in
                throw ProfileSaveTestError.upload
            },
            updateProfile: { _ in
                Issue.record("updateProfile should not run after upload failure")
            },
            setHandle: { _ in }
        )

        await #expect(throws: ProfileSaveTestError.upload) {
            try await store.saveProfile(
                EditableProfile(
                    displayName: "Maker",
                    handle: "maker",
                    bio: "",
                    website: "",
                    makerPageVisible: true,
                    photoSharingAllowed: false,
                    avatarVariant: 0,
                    avatarImageData: avatarData,
                    avatarURL: nil
                )
            )
        }

        #expect(store.lastSubmitErrorMessage?.contains("프로필 저장 실패") == true)
        #expect(store.editableProfile.avatarImageData == nil)
        #expect(store.editableProfile.avatarURL == nil)
    }

    @Test("profile update failure surfaces error and does not commit uploaded avatar URL")
    func saveProfileUpdateFailureSurfacesError() async {
        let store = SessionStore()
        let remoteURL = URL(string: "https://cdn.example.com/users/u1/avatar.jpg")!
        store.profileSaveClient = SessionProfileSaveClient(
            uploadAvatarImageData: { _ in
                ProfileAvatarUpload(publicURL: remoteURL, objectKey: "users/u1/avatar/avatar.jpg")
            },
            updateProfile: { _ in
                throw ProfileSaveTestError.update
            },
            setHandle: { _ in }
        )

        await #expect(throws: ProfileSaveTestError.update) {
            try await store.saveProfile(
                EditableProfile(
                    displayName: "Maker",
                    handle: "maker",
                    bio: "",
                    website: "",
                    makerPageVisible: true,
                    photoSharingAllowed: false,
                    avatarVariant: 0,
                    avatarImageData: Data([0x4]),
                    avatarURL: nil
                )
            )
        }

        #expect(store.lastSubmitErrorMessage?.contains("프로필 저장 실패") == true)
        #expect(store.editableProfile.avatarURL == nil)
        #expect(store.editableProfile.avatarImageData == nil)
    }
}

private enum ProfileSaveTestError: Error, Equatable {
    case upload
    case update
}
