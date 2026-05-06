import DesignSystem
import Models
import SwiftUI

extension FilterCategory {
    var displayTitle: String {
        switch self {
        case .cinematic: "Cinematic"
        case .vintage: "Vintage"
        case .pastel: "Pastel"
        case .bw: "B&W"
        case .portrait: "Portrait"
        case .food: "Food"
        case .travel: "Travel"
        case .anime: "Anime"
        case .mood: "Mood"
        case .bright: "Bright"
        case .moody: "Moody"
        case .skin: "Skin"
        }
    }

    var swatch: [Color] {
        switch self {
        case .cinematic: [.teal, .indigo]
        case .vintage: [.yellow, .red]
        case .pastel: [.mint, .pink]
        case .bw: [.white, .gray]
        case .portrait: [.orange, .pink]
        case .food: [.green, .orange]
        case .travel: [.blue, .cyan]
        case .anime: [.purple, .pink]
        case .mood: [.indigo, .black]
        case .bright: [.yellow, .mint]
        case .moody: [.gray, .blue]
        case .skin: [.orange, .brown]
        }
    }
}

struct FilterThumbnail: View {
    let filter: Filter

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(
                LinearGradient(
                    colors: filter.category.swatch,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(alignment: .bottomLeading) {
                Image(systemName: "camera.filters")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(Sp.sm)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.white.opacity(0.14), lineWidth: 1)
            }
            .aspectRatio(1, contentMode: .fit)
    }
}

struct FilterRow: View {
    let filter: Filter
    let isSelected: Bool
    let isDownloaded: Bool

    var body: some View {
        HStack(spacing: Sp.sm) {
            FilterThumbnail(filter: filter)
                .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: Sp.xxs) {
                Text(filter.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(filter.author.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)

                HStack(spacing: Sp.xs) {
                    PillText(filter.category.displayTitle)
                    if isDownloaded {
                        PillText("Downloaded")
                    }
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(FMColors.Accent.primary)
                    .font(.title3)
            }
        }
        .padding(Sp.sm)
        .background(FMColors.Background.bg2, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct PillText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white.opacity(0.78))
            .padding(.horizontal, Sp.xs)
            .padding(.vertical, Sp.xxs)
            .background(.white.opacity(0.08), in: Capsule())
    }
}

struct ScreenHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: Sp.xxs) {
            Text(title)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.64))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// `FilterDetailScreen` 은 Phase D3 에서 `Sources/App/Marketplace/FilterDetailScreen.swift` 로 이전됨.
