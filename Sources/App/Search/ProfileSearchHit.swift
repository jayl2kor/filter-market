import Foundation

/// 검색 결과에서 프로필 행을 렌더링하기 위한 표시용 경량 모델.
///
/// `PopularMaker` 와 형상은 비슷하지만 출처가 다르다:
/// - `PopularMaker`: 캐시된 `filters[]` 를 집계해 만든 인기 메이커 상위 5명
/// - `ProfileSearchHit`: Firestore `/users` 에서 prefix 검색으로 직접 가져온 사용자
struct ProfileSearchHit: Identifiable, Hashable, Sendable {
    let uid: String
    let displayName: String
    let handle: String
    let avatarURL: URL?
    let avatarInitials: String
    let filterCount: Int

    var id: String { uid }
}
