import DesignSystem
import FirebaseAuth
import SwiftUI

enum HandleValidationStatus: Equatable {
    case idle
    case checking
    case available
    case unavailable
    case invalid
    case failed

    var message: String {
        switch self {
        case .idle: "유저네임을 입력해 주세요."
        case .checking: "확인 중..."
        case .available: "이 이름 사용 가능해요."
        case .unavailable: "이미 사용 중이에요."
        case .invalid: "3~20자, 영문/숫자/_ 만 사용할 수 있어요."
        case .failed: "확인하지 못했어요. 다시 시도해 주세요."
        }
    }

    var tint: Color {
        switch self {
        case .available: FMColors.Accent.primary
        case .unavailable: FMColors.Semantic.error
        case .invalid: FMColors.Semantic.warning
        case .checking: FMColors.Text.secondary
        case .idle, .failed: FMColors.Text.tertiary
        }
    }

    var iconName: String? {
        switch self {
        case .idle, .checking: nil
        case .available: "checkmark.circle.fill"
        case .unavailable: "xmark.circle.fill"
        case .invalid, .failed: "exclamationmark.circle.fill"
        }
    }
}

enum HandleValidator {
    static let reservedHandles: Set<String> = [
        "admin",
        "moodit",
        "support",
        "moodit_team",
        "official",
        "help",
        "terms",
        "privacy"
    ]

    static func normalized(_ value: String) -> String {
        value
            .replacingOccurrences(of: "@", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    static func isValid(_ value: String) -> Bool {
        guard (3 ... 20).contains(value.count) else { return false }
        return value.range(of: #"^[a-z0-9_]+$"#, options: .regularExpression) != nil
    }
}

enum HandleAvailabilityChecker {
    static func status(
        for handle: String,
        initialHandle: String? = nil
    ) async -> HandleValidationStatus {
        if HandleValidator.reservedHandles.contains(handle) {
            return .unavailable
        }
        if handle == initialHandle {
            return .available
        }
        guard !isUITesting, FirebaseSideEffects.isConfigured else {
            return .available
        }

        do {
            guard let ownerUID = try await FirebaseSideEffects.handleOwnerUID(for: handle) else {
                return .available
            }
            if FirebaseSideEffects.currentUserOwns(uid: ownerUID) {
                return .available
            }
            return .unavailable
        } catch {
            return .failed
        }
    }
}
