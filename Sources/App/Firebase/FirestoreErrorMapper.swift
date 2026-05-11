import FirebaseFirestore
import Foundation

/// `FirebaseFirestore` 가 던지는 NSError 를 사용자에게 보여줄 한국어 메시지로 매핑한다.
///
/// 호출 규칙: Firestore catch 블록에서 `error.localizedDescription` 을 직접
/// UI 에 넘기지 말고 반드시 이 매퍼를 통과시킨다.
///
/// 추가 사유: SDK 의 `localizedDescription` 은 영문 ("Missing or insufficient
/// permissions." 등) 이며 한국어 UI 와 어울리지 않고, 사용자에게 노출되어선 안
/// 되는 내부 정보 (코드, 도메인) 를 포함할 수 있다.
enum FirestoreErrorMapper {
    /// 임의의 `Error` 를 한국어 friendly 메시지로 매핑.
    /// Firestore 도메인이 아니거나 매핑되지 않은 코드는 기본 fallback 을 반환한다.
    static func friendlyMessage(for error: Error) -> String {
        let nsError = error as NSError
        guard nsError.domain == FirestoreErrorDomain else {
            return defaultMessage
        }
        return message(forFirestoreCode: nsError.code)
    }

    /// 내부 헬퍼 — 테스트가 NSError 합성 없이도 코드만으로 매핑을 검증할 수 있게 노출.
    static func message(forFirestoreCode code: Int) -> String {
        switch code {
        case FirestoreErrorCode.permissionDenied.rawValue:
            return "이 항목에 접근할 수 없어요."
        case FirestoreErrorCode.notFound.rawValue:
            return "삭제되었거나 존재하지 않는 항목이에요."
        case FirestoreErrorCode.unavailable.rawValue,
             FirestoreErrorCode.deadlineExceeded.rawValue:
            return "네트워크가 불안정해요. 잠시 후 다시 시도해 주세요."
        case FirestoreErrorCode.unauthenticated.rawValue:
            return "로그인이 필요해요."
        case FirestoreErrorCode.cancelled.rawValue:
            return "요청이 취소되었어요."
        case FirestoreErrorCode.resourceExhausted.rawValue:
            return "요청이 너무 많아요. 잠시 후 다시 시도해 주세요."
        case FirestoreErrorCode.failedPrecondition.rawValue,
             FirestoreErrorCode.aborted.rawValue:
            return "지금은 처리할 수 없어요. 잠시 후 다시 시도해 주세요."
        case FirestoreErrorCode.invalidArgument.rawValue:
            return "요청 내용이 올바르지 않아요."
        default:
            return defaultMessage
        }
    }

    static let defaultMessage = "일시적인 문제가 발생했어요. 잠시 후 다시 시도해 주세요."
}
