import FirebaseFirestore
import Foundation
import Testing

@testable import moodit

@Suite("FirestoreErrorMapper")
struct FirestoreErrorMapperTests {
    @Test("permissionDenied 코드는 접근 불가 메시지를 반환한다")
    func permissionDeniedMessage() {
        let message = FirestoreErrorMapper.message(forFirestoreCode: FirestoreErrorCode.permissionDenied.rawValue)
        #expect(message == "이 항목에 접근할 수 없어요.")
    }

    @Test("notFound 코드는 삭제됨/없음 메시지를 반환한다")
    func notFoundMessage() {
        let message = FirestoreErrorMapper.message(forFirestoreCode: FirestoreErrorCode.notFound.rawValue)
        #expect(message == "삭제되었거나 존재하지 않는 항목이에요.")
    }

    @Test("unavailable/deadlineExceeded 는 네트워크 안내 메시지로 매핑된다", arguments: [
        FirestoreErrorCode.unavailable.rawValue,
        FirestoreErrorCode.deadlineExceeded.rawValue,
    ])
    func networkErrorMessages(code: Int) {
        let message = FirestoreErrorMapper.message(forFirestoreCode: code)
        #expect(message == "네트워크가 불안정해요. 잠시 후 다시 시도해 주세요.")
    }

    @Test("unauthenticated 는 로그인 요구 메시지를 반환한다")
    func unauthenticatedMessage() {
        let message = FirestoreErrorMapper.message(forFirestoreCode: FirestoreErrorCode.unauthenticated.rawValue)
        #expect(message == "로그인이 필요해요.")
    }

    @Test("resourceExhausted 는 트래픽 안내 메시지를 반환한다")
    func resourceExhaustedMessage() {
        let message = FirestoreErrorMapper.message(forFirestoreCode: FirestoreErrorCode.resourceExhausted.rawValue)
        #expect(message == "요청이 너무 많아요. 잠시 후 다시 시도해 주세요.")
    }

    @Test("매핑되지 않은 코드는 기본 fallback 메시지를 반환한다")
    func unknownCodeFallsBack() {
        // 사용하지 않는 매우 큰 코드값.
        let message = FirestoreErrorMapper.message(forFirestoreCode: 9999)
        #expect(message == FirestoreErrorMapper.defaultMessage)
    }

    @Test("Firestore 도메인이 아닌 NSError 는 기본 fallback 메시지를 반환한다")
    func nonFirestoreDomainFallsBack() {
        let foreign = NSError(domain: "com.example.foreign", code: 7, userInfo: nil)
        let message = FirestoreErrorMapper.friendlyMessage(for: foreign)
        #expect(message == FirestoreErrorMapper.defaultMessage)
    }

    @Test("Firestore 도메인의 permissionDenied NSError 는 한국어 메시지로 매핑된다")
    func firestorePermissionDeniedNSError() {
        let nsError = NSError(
            domain: FirestoreErrorDomain,
            code: FirestoreErrorCode.permissionDenied.rawValue,
            userInfo: [NSLocalizedDescriptionKey: "Missing or insufficient permissions."]
        )
        let message = FirestoreErrorMapper.friendlyMessage(for: nsError)
        #expect(message == "이 항목에 접근할 수 없어요.")
    }
}
