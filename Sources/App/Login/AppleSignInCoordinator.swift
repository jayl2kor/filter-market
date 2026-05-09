import AuthenticationServices
import CryptoKit
import FirebaseAuth
import Foundation
import Security

enum AppleSignInCoordinatorError: Error {
    case invalidCredential
    case missingPresentationAnchor
}

@MainActor
final class AppleSignInCoordinator: NSObject {
    private var continuation: CheckedContinuation<Void, Error>?
    private var currentNonce: String?
    private weak var presentationAnchor: ASPresentationAnchor?

    func signIn(presentationAnchor: ASPresentationAnchor) async throws {
        self.presentationAnchor = presentationAnchor
        let nonce = Self.randomNonceString()
        currentNonce = nonce

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)

        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.map { String(format: "%02x", $0) }.joined()
    }

    static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            precondition(status == errSecSuccess)

            randoms.forEach { random in
                guard remainingLength > 0, Int(random) < charset.count else { return }
                result.append(charset[Int(random)])
                remainingLength -= 1
            }
        }
        return result
    }

    private func finish(with result: Result<Void, Error>) {
        let continuation = continuation
        self.continuation = nil
        currentNonce = nil
        presentationAnchor = nil

        switch result {
        case .success:
            continuation?.resume(returning: ())
        case .failure(let error):
            continuation?.resume(throwing: error)
        }
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = appleIDCredential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8),
                  let nonce = currentNonce
            else {
                finish(with: .failure(AppleSignInCoordinatorError.invalidCredential))
                return
            }

            let credential = OAuthProvider.appleCredential(
                withIDToken: idToken,
                rawNonce: nonce,
                fullName: appleIDCredential.fullName
            )

            do {
                _ = try await Auth.auth().signIn(with: credential)
                finish(with: .success(()))
            } catch {
                finish(with: .failure(error))
            }
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            finish(with: .failure(error))
        }
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            presentationAnchor ?? ASPresentationAnchor()
        }
    }
}
