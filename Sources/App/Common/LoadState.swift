import Foundation

/// 백엔드 read flow 의 4-상태 표현. Store/View 에서 `isLoading` + `error` + `data`
/// 의 트리플 published 변수를 단일 enum 으로 통합한다.
///
/// - 의도적으로 mutation 흐름과 분리: mutation 에러는 toast (StoreErrorToast) 로
///   표시하고 String? 패턴을 유지한다. `LoadState` 는 "화면 전체가 로드 결과에
///   의존하는 흐름" 전용.
public enum LoadState<T: Sendable>: Sendable {
    case idle
    case loading
    case loaded(T)
    case failed(FriendlyError)

    public var value: T? {
        if case .loaded(let v) = self { return v }
        return nil
    }

    public var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    public var error: FriendlyError? {
        if case .failed(let e) = self { return e }
        return nil
    }

    public var isLoaded: Bool {
        if case .loaded = self { return true }
        return false
    }

    public var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }
}

extension LoadState: Equatable where T: Equatable {
    public static func == (lhs: LoadState<T>, rhs: LoadState<T>) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading):
            return true
        case (.loaded(let a), .loaded(let b)):
            return a == b
        case (.failed(let a), .failed(let b)):
            return a == b
        default:
            return false
        }
    }
}

/// 사용자에게 보여줄 한국어 메시지와 진단용 코드를 함께 들고 다니는 에러 표현.
/// `FirestoreErrorMapper.friendlyMessage` 결과로 생성하는 것이 권장 흐름.
public struct FriendlyError: Sendable, Equatable {
    public let message: String
    /// SDK / Firestore 에러 코드의 문자열 표현 (디버깅/로깅용). 없으면 nil.
    public let code: String?

    public init(message: String, code: String? = nil) {
        self.message = message
        self.code = code
    }
}
