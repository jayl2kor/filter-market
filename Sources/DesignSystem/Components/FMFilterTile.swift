import SwiftUI

// MARK: - FMFilterTileData

/// `FMFilterTile` 전용 표시 모델.
///
/// `Models.Filter` 와 직접 의존하지 않도록 디자인 시스템 모듈에서 정의한 데이터 컨테이너.
public struct FMFilterTileData: Equatable, Sendable {
    public let title: String
    public let makerName: String
    public let downloadCount: Int
    public let priceLabel: String?       // nil 이면 무료
    public let categoryHint: Color?      // 카테고리 점/언더라인 색
    public let previewImageURL: URL?     // 단일 이미지(애프터)
    public let beforeImageURL: URL?      // 옵션 — 비포/애프터 분할 표시

    public init(
        title: String,
        makerName: String,
        downloadCount: Int,
        priceLabel: String? = nil,
        categoryHint: Color? = nil,
        previewImageURL: URL? = nil,
        beforeImageURL: URL? = nil
    ) {
        self.title = title
        self.makerName = makerName
        self.downloadCount = downloadCount
        self.priceLabel = priceLabel
        self.categoryHint = categoryHint
        self.previewImageURL = previewImageURL
        self.beforeImageURL = beforeImageURL
    }
}

// MARK: - FMFilterTile

/// 마켓 그리드용 필터 카드.
///
/// `DESIGN_SYSTEM.md` §8.4 FilterTile — 4:5 사진 + 하단 그라디언트 + 좌상단 배지.
/// 사이즈는 부모 너비에 따라 자동.
public struct FMFilterTile: View {
    private let data: FMFilterTileData
    private let onTap: () -> Void

    public init(data: FMFilterTileData, onTap: @escaping () -> Void = {}) {
        self.data = data
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                preview
                gradientOverlay
                badge
                infoBlock
            }
            .clipShape(RoundedRectangle(cornerRadius: R.lg))
            .overlay {
                RoundedRectangle(cornerRadius: R.lg)
                    .strokeBorder(FMColors.Border.subtle, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .aspectRatio(4.0 / 5.0, contentMode: .fit)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(data.title), \(data.makerName), 다운로드 \(data.downloadCount)")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var preview: some View {
        if let url = data.previewImageURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    placeholderImage
                }
            }
        } else {
            placeholderImage
        }
    }

    private var placeholderImage: some View {
        LinearGradient(
            colors: [
                FMColors.Background.bg3,
                FMColors.Background.bg1
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            Image(systemName: "photo")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(FMColors.Text.tertiary)
        }
    }

    private var gradientOverlay: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0.45),
                .init(color: Color.black.opacity(0.78), location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    @ViewBuilder
    private var badge: some View {
        let label = data.priceLabel ?? "무료"
        Text(label)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(FMColors.Accent.primary)
            .padding(.horizontal, Sp.xs)
            .padding(.vertical, 4)
            .background(.regularMaterial, in: Capsule())
            .padding(Sp.sm)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var infoBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: Sp.xxs) {
                if let hint = data.categoryHint {
                    Circle()
                        .fill(hint)
                        .frame(width: 6, height: 6)
                }
                Text(data.title)
                    .fmTypography(.subhead)
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            HStack(spacing: Sp.xxs) {
                Text(data.makerName)
                    .fmTypography(.caption)
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(1)
                Text("·")
                    .fmTypography(.caption)
                    .foregroundStyle(.white.opacity(0.62))
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.78))
                Text(formattedCount(data.downloadCount))
                    .fmTypography(.caption)
                    .foregroundStyle(.white.opacity(0.78))
                    .monospacedDigit()
            }
        }
        .padding(Sp.sm)
    }

    private func formattedCount(_ count: Int) -> String {
        switch count {
        case ..<1_000: "\(count)"
        case 1_000..<10_000: String(format: "%.1fK", Double(count) / 1_000)
        default: "\(count / 1_000)K"
        }
    }
}

// MARK: - Preview

private let mockTiles: [FMFilterTileData] = [
    .init(
        title: "Velvet Dusk",
        makerName: "유나",
        downloadCount: 12_400,
        priceLabel: nil,
        categoryHint: FMColors.Category.cinematic
    ),
    .init(
        title: "Soft Polaroid",
        makerName: "MK",
        downloadCount: 842,
        priceLabel: "₩2,900",
        categoryHint: FMColors.Category.vintage
    ),
    .init(
        title: "Mono Walk",
        makerName: "이정민",
        downloadCount: 36,
        priceLabel: nil,
        categoryHint: FMColors.Category.monochrome
    ),
    .init(
        title: "Sunset Bloom",
        makerName: "Aki",
        downloadCount: 5_120,
        priceLabel: "₩1,500",
        categoryHint: FMColors.Category.portrait
    )
]

#Preview("FMFilterTile — grid") {
    ScrollView {
        LazyVGrid(columns: Array(repeating: .init(.flexible(), spacing: Sp.sm), count: 2), spacing: Sp.sm) {
            ForEach(0..<mockTiles.count, id: \.self) { index in
                FMFilterTile(data: mockTiles[index]) {}
            }
        }
        .padding(Sp.md)
    }
    .background(FMColors.Background.bg1)
}

#Preview("FMFilterTile — single") {
    FMFilterTile(data: mockTiles[0]) {}
        .frame(width: 200)
        .padding(Sp.md)
        .background(FMColors.Background.bg1)
}

#Preview("FMFilterTile — Dark") {
    LazyVGrid(columns: Array(repeating: .init(.flexible(), spacing: Sp.sm), count: 2), spacing: Sp.sm) {
        ForEach(0..<2, id: \.self) { index in
            FMFilterTile(data: mockTiles[index]) {}
        }
    }
    .padding(Sp.md)
    .background(FMColors.Background.bg1)
    .preferredColorScheme(.dark)
}
