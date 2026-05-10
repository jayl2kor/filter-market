import Foundation
import Models
import Testing
@testable import moodit

@Suite("Firestore filter repository")
struct FirestoreFilterRepositoryTests {
    @Test("fresh user profile data overrides cached filter author avatar")
    func freshUserProfileOverridesCachedAuthorAvatar() {
        let filter = makeFilter(
            author: FilterAuthor(
                uid: "maker-1",
                displayName: "Cached Maker",
                avatarURL: URL(string: "https://cdn.example.com/cached.jpg")
            )
        )

        let enriched = FirestoreFilterRepository.filter(
            filter,
            applyingAuthorProfileData: [
                "displayName": "Fresh Maker",
                "avatarURL": "https://cdn.example.com/fresh.jpg",
            ]
        )

        #expect(enriched.author.uid == "maker-1")
        #expect(enriched.author.displayName == "Fresh Maker")
        #expect(enriched.author.avatarURL == URL(string: "https://cdn.example.com/fresh.jpg"))
    }

    @Test("missing profile fields keep cached author values")
    func missingProfileFieldsKeepCachedAuthorValues() {
        let cachedAvatar = URL(string: "https://cdn.example.com/cached.jpg")
        let filter = makeFilter(
            author: FilterAuthor(
                uid: "maker-1",
                displayName: "Cached Maker",
                avatarURL: cachedAvatar
            )
        )

        let enriched = FirestoreFilterRepository.filter(
            filter,
            applyingAuthorProfileData: [
                "displayName": " ",
            ]
        )

        #expect(enriched.author.displayName == "Cached Maker")
        #expect(enriched.author.avatarURL == cachedAvatar)
    }

    private func makeFilter(author: FilterAuthor) -> Filter {
        Filter(
            id: UUID(uuidString: "01900B14-7B1C-7C1E-A4F4-9B2C1D2E5A01")!,
            title: "Profile Synced",
            version: "1.0.0",
            author: author,
            category: .cinematic,
            engine: FilterEngineDescriptor(
                type: .lutParams,
                minAppVersion: "1.0.0",
                minIOSVersion: "17.0",
                lutSize: 33,
                lutFile: nil
            ),
            useCount: 12,
            downloadCount: 8,
            tags: ["profile"]
        )
    }
}
