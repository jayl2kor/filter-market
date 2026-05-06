import Foundation

public enum AuthState: Equatable, Sendable {
    case guest
    case authenticated(uid: String)
}
