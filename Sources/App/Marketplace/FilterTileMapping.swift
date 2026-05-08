import DesignSystem
import Models
import SwiftUI

/// `Models.Filter` → `FMFilterTileData` 변환.
///
/// 디자인 시스템 모듈은 Models를 의존하지 않으므로, 이 매핑은 App 레이어에 둔다.
extension Filter {
    func toTileData() -> FMFilterTileData {
        FMFilterTileData(
            title: title,
            makerName: "@\(author.displayName)",
            downloadCount: downloadCount > 0 ? downloadCount : useCount,
            priceLabel: priceCoins > 0 ? "\(priceCoins) 코인" : nil,
            categoryHint: category.hintColor,
            categoryKey: category.rawValue,
            coverMotif: nil,
            previewImageURL: coverURL,
            beforeImageURL: nil
        )
    }
}

extension FilterCategory {
    var hintColor: Color {
        switch self {
        case .cinematic: FMColors.Category.cinematic
        case .vintage: FMColors.Category.vintage
        case .pastel: FMColors.Category.pastel
        case .bw: FMColors.Category.monochrome
        case .portrait: FMColors.Category.portrait
        case .food: FMColors.Category.food
        case .travel: FMColors.Category.travel
        case .anime: FMColors.Category.cinematic
        case .mood, .moody: FMColors.Category.mood
        case .bright: FMColors.Category.pastel
        case .skin: FMColors.Category.portrait
        }
    }
}
