import DesignSystem
import SwiftUI
import UIKit

// MARK: - CapturePreviewScreen

/// 촬영 직후 결과 풀스크린.
///
/// Phase D3 — `mockups/screens/05-capture-preview.html` 와 정합. 다크 모드 강제.
/// 상단 frosted 헤더 (닫기 / 더보기) + 사진 풀스크린 + 메타 핀 (필터 이름·강도)
/// + 하단 frosted 컨트롤 (재촬영 / 필터 변경 / 편집 / 삭제) + 저장·공유 CTA.
///
/// 본 화면은 시각만 제공한다. 기존 `CameraScreen` 의 `CaptureResultScreen` (sheet)
/// 은 그대로 유지하며, 후속 통합에서 본 화면으로 점진 전환할 수 있다.
public struct CapturePreviewScreen: View {
    public let image: UIImage?
    public let filterName: String?
    public let aspectRatio: String?
    public let intensityPercent: Int?

    public var onSave: (() -> Void)?
    public var onShare: (() -> Void)?
    public var onDiscard: (() -> Void)?
    public var onRetake: (() -> Void)?
    public var onChangeFilter: (() -> Void)?
    public var onEdit: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var showDiscardConfirm = false

    public init(
        image: UIImage? = nil,
        filterName: String? = nil,
        aspectRatio: String? = nil,
        intensityPercent: Int? = nil,
        onSave: (() -> Void)? = nil,
        onShare: (() -> Void)? = nil,
        onDiscard: (() -> Void)? = nil,
        onRetake: (() -> Void)? = nil,
        onChangeFilter: (() -> Void)? = nil,
        onEdit: (() -> Void)? = nil
    ) {
        self.image = image
        self.filterName = filterName
        self.aspectRatio = aspectRatio
        self.intensityPercent = intensityPercent
        self.onSave = onSave
        self.onShare = onShare
        self.onDiscard = onDiscard
        self.onRetake = onRetake
        self.onChangeFilter = onChangeFilter
        self.onEdit = onEdit
    }

    public var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            photoLayer
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, Sp.md)
                    .padding(.top, Sp.sm)

                Spacer()

                if let filterName {
                    metaPill(name: filterName)
                        .padding(.bottom, Sp.lg)
                }

                bottomControls
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(false)
        .accessibilityElement(children: .contain)
        .fmConfirmationDialog(
            "이 사진을 삭제할까요?",
            isPresented: $showDiscardConfirm
        ) {
            Button("삭제", role: .destructive) {
                FMHaptic.warning.play()
                onDiscard?()
                dismiss()
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("저장되지 않은 사진은 복구할 수 없어요.")
        }
    }

    // MARK: - Photo

    @ViewBuilder
    private var photoLayer: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
        } else {
            // Placeholder — 실제 사진이 없을 때 cinematic-tone 그라디언트 mock.
            placeholderPhoto
        }
    }

    private var placeholderPhoto: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 38/255, green: 28/255, blue: 36/255),
                    Color(red: 122/255, green: 76/255, blue: 56/255),
                    Color(red: 196/255, green: 138/255, blue: 78/255)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Vignette 흉내
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.clear,
                    Color.black.opacity(0.55)
                ]),
                center: .center,
                startRadius: 60,
                endRadius: 460
            )

            Image(systemName: "photo")
                .font(.system(size: 96, weight: .ultraLight))
                .foregroundStyle(.white.opacity(0.18))
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            iconButton(systemName: "chevron.down", label: "닫기") {
                FMHaptic.light.play()
                onRetake?()
                dismiss()
            }
            .accessibilityIdentifier("preview.dismiss")

            Spacer()

            if let aspectRatio {
                Text(aspectRatio)
                    .fmTypography(.caption)
                    .foregroundStyle(.white.opacity(0.78))
                    .padding(.horizontal, Sp.sm)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial.opacity(0.6), in: Capsule())
                    .overlay {
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                    }
            }

            Spacer()

            iconButton(systemName: "ellipsis", label: "더보기") {
                FMHaptic.light.play()
                // 더보기 메뉴 — 후속 phase.
            }
            .accessibilityIdentifier("preview.more")
        }
    }

    // MARK: - Meta pill

    private func metaPill(name: String) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(FMColors.Accent.primary)
                .frame(width: 6, height: 6)

            Text(name)
                .fmTypography(.subhead)
                .foregroundStyle(.white)
                .lineLimit(1)

            if let intensity = intensityPercent {
                Rectangle()
                    .fill(Color.white.opacity(0.28))
                    .frame(width: 1, height: 12)
                    .padding(.horizontal, 2)

                Text("\(intensity)%")
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.78))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial.opacity(0.7), in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("적용 필터 \(name)" + (intensityPercent.map { ", 강도 \($0)퍼센트" } ?? ""))
    }

    // MARK: - Bottom controls

    private var bottomControls: some View {
        VStack(spacing: Sp.md) {
            quickActions

            saveRow
        }
        .padding(.horizontal, Sp.md)
        .padding(.top, Sp.md)
        .padding(.bottom, Sp.md)
        .background(
            LinearGradient(
                stops: [
                    .init(color: Color.clear, location: 0.0),
                    .init(color: Color.black.opacity(0.86), location: 0.65)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    private var quickActions: some View {
        HStack {
            Spacer()
            quickButton(symbol: "arrow.uturn.backward", label: "재촬영", identifier: "preview.retake") {
                FMHaptic.light.play()
                onRetake?()
                dismiss()
            }
            Spacer()
            quickButton(symbol: "camera.filters", label: "필터 변경", identifier: "preview.changeFilter") {
                FMHaptic.light.play()
                onChangeFilter?()
            }
            Spacer()
            quickButton(symbol: "slider.horizontal.3", label: "편집", identifier: "preview.edit") {
                FMHaptic.light.play()
                onEdit?()
            }
            Spacer()
            quickButton(symbol: "trash", label: "삭제", identifier: "preview.discard", destructive: true) {
                FMHaptic.light.play()
                showDiscardConfirm = true
            }
            Spacer()
        }
    }

    private var saveRow: some View {
        HStack(spacing: Sp.xs) {
            Button {
                FMHaptic.light.play()
                onSave?()
            } label: {
                HStack(spacing: Sp.xs) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 17, weight: .semibold))
                    Text("저장")
                        .fmTypography(.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: R.md)
                        .fill(Color.white.opacity(0.12))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: R.md)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                }
            }
            .accessibilityIdentifier("preview.save")
            .accessibilityLabel("저장")

            FMButton(
                "공유하기",
                icon: "square.and.arrow.up",
                variant: .primary,
                size: .lg
            ) {
                onShare?()
            }
            .accessibilityIdentifier("preview.share")
        }
    }

    // MARK: - Sub-components

    private func iconButton(
        systemName: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial.opacity(0.7), in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                }
        }
        .accessibilityLabel(label)
    }

    private func quickButton(
        symbol: String,
        label: String,
        identifier: String,
        destructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(destructive ? FMColors.Semantic.error : .white)
                    .frame(width: 48, height: 48)
                    .background(.ultraThinMaterial.opacity(0.7), in: Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                    }

                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .tracking(0.3)
                    .foregroundStyle(destructive ? FMColors.Semantic.error.opacity(0.92) : .white.opacity(0.92))
            }
        }
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(label)
    }
}

// MARK: - Preview

#Preview("CapturePreviewScreen — Placeholder 4:5") {
    CapturePreviewScreen(
        filterName: "Sunset 1973",
        aspectRatio: "4:5",
        intensityPercent: 75
    )
}

#Preview("CapturePreviewScreen — 16:9") {
    CapturePreviewScreen(
        filterName: "Cinematic Teal",
        aspectRatio: "16:9",
        intensityPercent: 60
    )
}

#Preview("CapturePreviewScreen — 1:1") {
    CapturePreviewScreen(
        filterName: "Mono Soft",
        aspectRatio: "1:1",
        intensityPercent: 45
    )
}

#Preview("CapturePreviewScreen — No filter") {
    CapturePreviewScreen()
}

#Preview("CapturePreviewScreen — XXXLarge") {
    CapturePreviewScreen(
        filterName: "Sunset 1973",
        aspectRatio: "4:5",
        intensityPercent: 75
    )
    .dynamicTypeSize(.xxxLarge)
}
