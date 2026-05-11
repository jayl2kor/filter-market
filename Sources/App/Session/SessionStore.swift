import Combine
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import FirebaseFunctions
import Foundation

private enum SessionProfileAvatarUploadError: LocalizedError {
    case imageTooLarge
    case invalidUploadResponse
    case uploadFailed

    var errorDescription: String? {
        switch self {
        case .imageTooLarge:
            "프로필 사진 용량이 너무 커요. 다른 사진을 선택해주세요."
        case .invalidUploadResponse:
            "프로필 사진 업로드 정보를 읽지 못했어요."
        case .uploadFailed:
            "프로필 사진 업로드에 실패했어요."
        }
    }
}

struct ProfileAvatarUpload: Equatable, Sendable {
    let publicURL: URL
    let objectKey: String
}

struct SessionProfileSaveClient: Sendable {
    var uploadAvatarImageData: @Sendable (Data?) async throws -> ProfileAvatarUpload?
    var updateProfile: @Sendable ([String: Any]) async throws -> Void
    var setHandle: @Sendable (String) async throws -> Void
}

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var isAuthenticated = false
    @Published private(set) var isGuestMode = false
    @Published private(set) var hasLoadedProfile = false
    @Published var editableProfile = EditableProfile.empty
    @Published var lastProfileSavedAt: Date?
    @Published var accountDeletionRequestedAt: Date?
    @Published var selectedExportCategories: Set<DataExportCategory> = Set(DataExportCategory.allCases)
    @Published var selectedExportFormat: DataExportFormat = .json
    @Published var exportRequests: [DataExportRequest] = []
    @Published var notificationPreferences = NotificationPreferences() {
        didSet {
            ForegroundNotificationPolicy.shared.update(preferences: notificationPreferences)
        }
    }
    @Published var lastSubmitErrorMessage: String?

    @Published private(set) var currentUserID: String?

    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private var notificationPreferencesSaveTask: Task<Void, Never>?
    private var saveProfileTask: Task<Void, Never>?
    private var saveProfileGeneration = 0
    var profileSaveClient: SessionProfileSaveClient?

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
            isGuestMode = !isAuthenticated
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
                if user != nil {
                    self.isGuestMode = false
                }
                onAuthChanged(user)
            }
        }
    }

    func setLocalAuthenticationFallback(_ authenticated: Bool) {
        #if DEBUG
        guard isUITesting || !authenticated else {
            assertionFailure("Local authenticated fallback is only allowed in UI tests.")
            return
        }
        #else
        guard !authenticated else { return }
        #endif
        isAuthenticated = authenticated
        isGuestMode = false
        if !authenticated {
            currentUserID = nil
            hasLoadedProfile = false
            resetUserScopedState()
        }
    }

    func enterGuestMode() {
        isGuestMode = true
        isAuthenticated = false
        hasLoadedProfile = true
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

    func applyAuthUserBaseline(_ user: User) {
        editableProfile = EditableProfile(
            displayName: user.displayName ?? user.email?.split(separator: "@").first.map(String.init) ?? "",
            handle: user.email?.split(separator: "@").first.map(String.init) ?? String(user.uid.prefix(8)),
            bio: editableProfile.bio,
            website: editableProfile.website,
            makerPageVisible: editableProfile.makerPageVisible,
            photoSharingAllowed: editableProfile.photoSharingAllowed,
            avatarVariant: editableProfile.avatarVariant,
            avatarImageData: editableProfile.avatarImageData,
            avatarURL: editableProfile.avatarURL
        )
    }

    func applyUserDocument(_ data: [String: Any]) {
        editableProfile = EditableProfile(
            displayName: (data["displayName"] as? String) ?? editableProfile.displayName,
            handle: (data["handle"] as? String) ?? editableProfile.handle,
            bio: (data["bio"] as? String) ?? editableProfile.bio,
            website: (data["website"] as? String) ?? editableProfile.website,
            makerPageVisible: (data["makerPageVisible"] as? Bool) ?? editableProfile.makerPageVisible,
            photoSharingAllowed: (data["photoSharingAllowed"] as? Bool) ?? editableProfile.photoSharingAllowed,
            avatarVariant: (data["avatarVariant"] as? Int) ?? editableProfile.avatarVariant,
            avatarImageData: editableProfile.avatarImageData,
            avatarURL: Self.url(from: data["avatarURL"])
                ?? Self.url(from: data["photoURL"])
                ?? editableProfile.avatarURL
        )
    }

    func applyRemoteNotificationPreferences(_ data: [String: Any]) {
        let remotePreferences = NotificationPreferences(
            systemEnabled: (data["systemEnabled"] as? Bool) ?? notificationPreferences.systemEnabled,
            social: (data["social"] as? Bool) ?? notificationPreferences.social,
            reviews: (data["reviews"] as? Bool) ?? notificationPreferences.reviews,
            marketplace: (data["marketplace"] as? Bool) ?? notificationPreferences.marketplace,
            creator: (data["creator"] as? Bool) ?? notificationPreferences.creator,
            wallet: (data["wallet"] as? Bool) ?? notificationPreferences.wallet,
            product: (data["product"] as? Bool) ?? notificationPreferences.product,
            quietHoursEnabled: (data["quietHoursEnabled"] as? Bool) ?? notificationPreferences.quietHoursEnabled,
            quietStart: (data["quietStart"] as? String) ?? notificationPreferences.quietStart,
            quietEnd: (data["quietEnd"] as? String) ?? notificationPreferences.quietEnd
        )
        if remotePreferences != notificationPreferences {
            notificationPreferences = remotePreferences
        }
    }

    func setExportRequests(_ requests: [DataExportRequest]) {
        exportRequests = requests
    }

    func resetUserScopedState() {
        editableProfile = .empty
        lastProfileSavedAt = nil
        accountDeletionRequestedAt = nil
        selectedExportCategories = Set(DataExportCategory.allCases)
        selectedExportFormat = .json
        exportRequests = []
        notificationPreferences = NotificationPreferences()
        lastSubmitErrorMessage = nil
        notificationPreferencesSaveTask?.cancel()
        notificationPreferencesSaveTask = nil
        saveProfileTask?.cancel()
        saveProfileTask = nil
        saveProfileGeneration += 1
    }

    func clearLastSubmitError() {
        lastSubmitErrorMessage = nil
    }

    func setNotificationPreference<Value: Equatable>(
        _ keyPath: WritableKeyPath<NotificationPreferences, Value>,
        to value: Value
    ) {
        var preferences = notificationPreferences
        guard preferences[keyPath: keyPath] != value else { return }
        preferences[keyPath: keyPath] = value
        notificationPreferences = preferences
        scheduleNotificationPreferencesSave(preferences)
    }

    func scheduleNotificationPreferencesSave() {
        scheduleNotificationPreferencesSave(notificationPreferences)
    }

    private func scheduleNotificationPreferencesSave(_ preferences: NotificationPreferences) {
        #if DEBUG
        guard !isUITesting else { return }
        #endif
        guard Self.currentFirebaseUID != nil else { return }
        notificationPreferencesSaveTask?.cancel()
        notificationPreferencesSaveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else { return }
            await self?.persistNotificationPreferences(preferences)
        }
    }

    private func persistNotificationPreferences(_ preferences: NotificationPreferences) async {
        guard let uid = Self.currentFirebaseUID else { return }
        let ref = Firestore.firestore()
            .collection("users").document(uid)
            .collection("notificationPreferences").document("main")
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                ref.setData([
                    "systemEnabled": preferences.systemEnabled,
                    "social": preferences.social,
                    "reviews": preferences.reviews,
                    "marketplace": preferences.marketplace,
                    "creator": preferences.creator,
                    "wallet": preferences.wallet,
                    "product": preferences.product,
                    "quietHoursEnabled": preferences.quietHoursEnabled,
                    "quietStart": preferences.quietStart,
                    "quietEnd": preferences.quietEnd,
                    "updatedAt": FieldValue.serverTimestamp()
                ], merge: true) { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
            notificationPreferencesSaveTask = nil
        } catch {
            lastSubmitErrorMessage = "알림 설정 저장 실패: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func saveProfile(_ profile: EditableProfile) async throws -> EditableProfile {
        lastSubmitErrorMessage = nil
        saveProfileTask?.cancel()
        saveProfileTask = nil
        saveProfileGeneration += 1
        let generation = saveProfileGeneration

        do {
            let client = profileSaveClient ?? defaultProfileSaveClient()
            let avatarUpload: ProfileAvatarUpload?
            do {
                avatarUpload = try await client.uploadAvatarImageData(profile.avatarImageData)
            } catch {
                recordProfileSaveFailure(error, step: "profileAvatarUploadInit")
                throw error
            }
            let avatarURL = avatarUpload?.publicURL ?? profile.avatarURL
            var payload: [String: Any] = [
                "displayName": profile.displayName,
                "bio": profile.bio,
                "website": profile.website,
                "makerPageVisible": profile.makerPageVisible,
                "photoSharingAllowed": profile.photoSharingAllowed,
                "avatarVariant": profile.avatarVariant
            ]
            if let avatarURL {
                payload["avatarURL"] = avatarURL.absoluteString
                payload["photoURL"] = avatarURL.absoluteString
            }
            if let avatarUpload {
                payload["avatarObjectKey"] = avatarUpload.objectKey
            }

            do {
                try await client.updateProfile(payload)
            } catch {
                recordProfileSaveFailure(error, step: "updateProfile")
                throw error
            }

            if !profile.handle.isEmpty {
                do {
                    try await client.setHandle(profile.handle)
                } catch {
                    recordProfileSaveFailure(error, step: "setHandle")
                    throw error
                }
            }

            guard saveProfileGeneration == generation else { return editableProfile }
            var savedProfile = profile
            if let avatarURL {
                savedProfile.avatarURL = avatarURL
            }
            if avatarUpload != nil {
                savedProfile.avatarImageData = nil
            }
            editableProfile = savedProfile
            lastProfileSavedAt = Date()
            lastSubmitErrorMessage = nil
            return savedProfile
        } catch {
            guard saveProfileGeneration == generation else { throw error }
            lastSubmitErrorMessage = profileSaveFailureMessage(for: error)
            throw error
        }
    }

    private func recordProfileSaveFailure(_ error: Error, step: String) {
        Telemetry.record(error: error, context: [
            "where": "SessionStore.saveProfile",
            "step": step
        ])
    }

    private func profileSaveFailureMessage(for error: Error) -> String {
        if FirebaseSideEffects.isFunctionNotFound(error) {
            return "프로필 저장 실패: 네트워크 또는 서버 점검 중이에요. 잠시 후 다시 시도해 주세요."
        }
        return "프로필 저장 실패: \(error.localizedDescription)"
    }

    private func defaultProfileSaveClient() -> SessionProfileSaveClient {
        SessionProfileSaveClient(
            uploadAvatarImageData: { data in
                try await Self.uploadProfileAvatarImageData(data)
            },
            updateProfile: { payload in
                let callable = Functions.functions(region: "asia-northeast3").httpsCallable("updateProfile")
                _ = try await callable.call(payload)
            },
            setHandle: { handle in
                let callable = Functions.functions(region: "asia-northeast3").httpsCallable("setHandle")
                _ = try await callable.call(["handle": handle])
            }
        )
    }

    private nonisolated static func uploadProfileAvatarImageData(_ data: Data?) async throws -> ProfileAvatarUpload? {
        guard let data else { return nil }
        guard data.count <= 1_500_000 else {
            throw SessionProfileAvatarUploadError.imageTooLarge
        }
        let callable = Functions.functions(region: "asia-northeast3").httpsCallable("profileAvatarUploadInit")
        let result = try await callable.call([
            "contentType": "image/jpeg",
            "imageBytes": data.count
        ])
        guard let payload = result.data as? [String: Any],
              let uploadURLString = payload["uploadUrl"] as? String,
              let uploadURL = URL(string: uploadURLString),
              let publicURLString = payload["publicURL"] as? String,
              let publicURL = URL(string: publicURLString),
              let objectKey = payload["objectKey"] as? String else {
            throw SessionProfileAvatarUploadError.invalidUploadResponse
        }

        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        request.httpBody = data
        let headers = payload["uploadHeaders"] as? [String: String] ?? [:]
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw SessionProfileAvatarUploadError.uploadFailed
        }
        return ProfileAvatarUpload(publicURL: publicURL, objectKey: objectKey)
    }

    func markAccountDeletionRequested() async throws {
        let callable = Functions.functions(region: "asia-northeast3").httpsCallable("deleteAccount")
        _ = try await callable.call([:] as [String: Any])
        accountDeletionRequestedAt = Date()
    }

    func toggleExportCategory(_ category: DataExportCategory) {
        if selectedExportCategories.contains(category) {
            selectedExportCategories.remove(category)
        } else {
            selectedExportCategories.insert(category)
        }
    }

    func requestDataExport() {
        guard !selectedExportCategories.isEmpty else { return }
        let uid = Self.currentFirebaseUID
        let ref = uid.map {
            Firestore.firestore()
                .collection("users").document($0)
                .collection("exportRequests").document()
        }
        let request = DataExportRequest(
            id: ref?.documentID ?? UUID().uuidString,
            categories: selectedExportCategories,
            format: selectedExportFormat,
            requestedAt: Date(),
            status: "요청됨",
            downloadURL: nil
        )
        exportRequests.insert(request, at: 0)
        guard let ref else { return }
        ref.setData([
            "categories": selectedExportCategories.map(\.rawValue),
            "format": selectedExportFormat.rawValue,
            "status": "requested",
            "requestedAt": FieldValue.serverTimestamp()
        ]) { [weak self] error in
            guard let error else { return }
            Task { @MainActor in
                self?.lastSubmitErrorMessage = "데이터 내보내기 요청 실패: \(error.localizedDescription)"
            }
        }
    }

    private static func url(from value: Any?) -> URL? {
        guard let string = value as? String else { return nil }
        return URL(string: string)
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
