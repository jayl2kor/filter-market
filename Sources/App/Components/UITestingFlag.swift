import Foundation

/// `-ui-testing` 런치 인자가 설정되었는지 검출.
///
/// UI 테스트는 mock 데이터 시드를 기대하므로, 실제 backend 연결 전 단계에서
/// 화면별로 이 플래그를 보고 fallback 시드 데이터를 노출.
let isUITesting: Bool = ProcessInfo.processInfo.arguments.contains("-ui-testing")
