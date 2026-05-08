import Foundation

/// `-ui-testing` 런치 인자가 설정되었는지 검출.
///
/// UI 테스트는 mock 데이터 시드를 기대하므로, 실제 backend 연결 전 단계에서
/// 화면별로 이 플래그를 보고 fallback 시드 데이터를 노출.
let isUITesting: Bool = ProcessInfo.processInfo.arguments.contains("-ui-testing")

#if DEBUG
enum UITestingLaunchOverrides {
    static func applyIfNeeded() {
        guard isUITesting else { return }

        applyBoolArgument("-hasOnboarded", to: "hasOnboarded")
        applyBoolArgument("-isAuthenticated", to: "isAuthenticated")
    }

    private static func applyBoolArgument(_ flag: String, to key: String) {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flagIndex = arguments.firstIndex(of: flag),
              arguments.indices.contains(flagIndex + 1),
              let value = boolValue(arguments[flagIndex + 1])
        else {
            return
        }

        UserDefaults.standard.set(value, forKey: key)
    }

    private static func boolValue(_ rawValue: String) -> Bool? {
        switch rawValue.lowercased() {
        case "yes", "true", "1":
            return true
        case "no", "false", "0":
            return false
        default:
            return nil
        }
    }
}
#endif
