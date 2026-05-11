import Foundation
import Testing

@testable import moodit

@Suite("LoadState")
struct LoadStateTests {
    @Test("idle 상태는 isLoading=false, value=nil, error=nil")
    func idleAccessors() {
        let state: LoadState<String> = .idle
        #expect(state.isLoading == false)
        #expect(state.isLoaded == false)
        #expect(state.isFailed == false)
        #expect(state.value == nil)
        #expect(state.error == nil)
    }

    @Test("loading 상태는 isLoading=true 만 true")
    func loadingAccessors() {
        let state: LoadState<String> = .loading
        #expect(state.isLoading == true)
        #expect(state.isLoaded == false)
        #expect(state.isFailed == false)
        #expect(state.value == nil)
        #expect(state.error == nil)
    }

    @Test("loaded 상태는 value 를 노출하고 isLoaded=true")
    func loadedAccessors() {
        let state: LoadState<String> = .loaded("hello")
        #expect(state.isLoading == false)
        #expect(state.isLoaded == true)
        #expect(state.isFailed == false)
        #expect(state.value == "hello")
        #expect(state.error == nil)
    }

    @Test("failed 상태는 FriendlyError 를 노출하고 isFailed=true")
    func failedAccessors() {
        let err = FriendlyError(message: "not allowed", code: "permission-denied")
        let state: LoadState<String> = .failed(err)
        #expect(state.isLoading == false)
        #expect(state.isLoaded == false)
        #expect(state.isFailed == true)
        #expect(state.value == nil)
        #expect(state.error == err)
    }

    @Test("Equatable 은 동일 case + 동일 payload 에서만 true")
    func equatableSemantics() {
        let a: LoadState<String> = .loaded("x")
        let b: LoadState<String> = .loaded("x")
        let c: LoadState<String> = .loaded("y")
        #expect(a == b)
        #expect(a != c)

        let e1: LoadState<String> = .failed(FriendlyError(message: "same", code: "1"))
        let e2: LoadState<String> = .failed(FriendlyError(message: "same", code: "1"))
        let e3: LoadState<String> = .failed(FriendlyError(message: "different", code: "1"))
        #expect(e1 == e2)
        #expect(e1 != e3)

        let l: LoadState<String> = .loading
        let l2: LoadState<String> = .loading
        let i: LoadState<String> = .idle
        #expect(l == l2)
        #expect(l != i)
    }

    @Test("FriendlyError 는 message + code 가 모두 같아야 동치")
    func friendlyErrorEquality() {
        let a = FriendlyError(message: "x", code: "c")
        let b = FriendlyError(message: "x", code: "c")
        let c = FriendlyError(message: "x", code: "d")
        let d = FriendlyError(message: "x", code: nil)
        #expect(a == b)
        #expect(a != c)
        #expect(a != d)
    }
}
