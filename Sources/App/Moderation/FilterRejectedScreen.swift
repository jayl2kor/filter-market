import DesignSystem
import SwiftUI
import UIKit

/// 48 Filter Rejected — `mockups/screens/48-filter-rejected.html` 정합.
///
/// 검수 거부 hero (error 좌측 보더) + 필터 미리보기 카드 + 번호 매겨진 사유 리스트
/// + 검수자 메모 (info 강조) + 처리 이력 timeline + 이의 제기 외부 링크.
/// 하단 sticky 푸터에 취소 / 에디터에서 수정 CTA.
struct FilterRejectedScreen: View {
    let filterID: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var showDeleteConfirm = false

    private var data: RejectionData { RejectionData.mock(forID: filterID) }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Sp.md) {
                    heroCard
                    filterCard
                    reasonsSection
                    moderatorNote
                    timelineSection
                    policySection
                    appealLink
                }
                .padding(Sp.md)
            }

            footer
        }
        .background(FMColors.Background.bg1)
        .navigationTitle("검수 결과")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    contactSupport()
                } label: {
                    Image(systemName: "questionmark.circle")
                }
                .accessibilityLabel("고객지원")
                .accessibilityIdentifier("mod.rejected.support")
            }
        }
        .fmConfirmationDialog(
            "필터를 삭제할까요?",
            isPresented: $showDeleteConfirm
        ) {
            Button("필터 삭제", role: .destructive) {
                FMHaptic.warning.play()
                dismiss()
            }
            Button("계속 보기", role: .cancel) {}
        } message: {
            Text("삭제하면 이 거절 항목과 이어 작성하던 초안으로 돌아갈 수 없어요.")
        }
    }

    // MARK: - Hero

    private var heroCard: some View {
        HStack(alignment: .top, spacing: Sp.sm) {
            Image(systemName: "xmark.circle")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(FMColors.Semantic.error)
                .frame(width: 48, height: 48)
                .background(FMColors.Semantic.errorBg, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text("검수 거부")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.4)
                    .textCase(.uppercase)
                    .foregroundStyle(FMColors.Semantic.error)

                Text(data.heroTitle)
                    .fmTypography(.headline)
                    .foregroundStyle(FMColors.Text.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(data.heroDesc)
                    .fmTypography(.subhead)
                    .foregroundStyle(FMColors.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(Sp.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FMColors.Background.bg2)
        .clipShape(RoundedRectangle(cornerRadius: R.lg))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(FMColors.Semantic.error)
                .frame(width: 4)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: R.lg,
                        bottomLeadingRadius: R.lg
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: R.lg)
                .strokeBorder(FMColors.Semantic.error.opacity(0.5), lineWidth: 1)
        }
        .accessibilityIdentifier("mod.rejected.review")
    }

    // MARK: - Filter card

    private var filterCard: some View {
        HStack(spacing: Sp.sm) {
            RoundedRectangle(cornerRadius: R.sm)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0x594878), Color(hex: 0x1F1832)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 60, height: 75)
                .opacity(0.7)
                .overlay {
                    RoundedRectangle(cornerRadius: R.sm)
                        .strokeBorder(FMColors.Border.subtle, lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(data.filterName)
                    .fmTypography(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(FMColors.Text.primary)

                Text(data.submittedAt)
                    .fmTypography(.caption)
                    .foregroundStyle(FMColors.Text.tertiary)

                Text("REJECTED")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.4)
                    .foregroundStyle(FMColors.Semantic.error)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(FMColors.Semantic.errorBg, in: RoundedRectangle(cornerRadius: R.sm))
            }

            Spacer()
        }
        .padding(Sp.sm)
        .background(FMColors.Background.bg2)
        .clipShape(RoundedRectangle(cornerRadius: R.md))
        .overlay {
            RoundedRectangle(cornerRadius: R.md)
                .strokeBorder(FMColors.Border.subtle, lineWidth: 1)
        }
        .accessibilityIdentifier("mod.rejected.detail")
    }

    // MARK: - Reasons

    private var reasonsSection: some View {
        VStack(alignment: .leading, spacing: Sp.xs) {
            Text("거부 사유")
                .fmTypography(.callout)
                .fontWeight(.bold)
                .foregroundStyle(FMColors.Text.primary)

            Text("검수자가 확인한 항목입니다. 모두 해결 후 재제출하시면 우선 검수됩니다.")
                .fmTypography(.caption)
                .foregroundStyle(FMColors.Text.tertiary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: Sp.xs) {
                ForEach(Array(data.reasons.enumerated()), id: \.offset) { index, reason in
                    reasonRow(number: index + 1, reason: reason)
                }
            }
            .padding(.top, Sp.xs)
        }
    }

    private func reasonRow(number: Int, reason: RejectionReason) -> some View {
        HStack(alignment: .top, spacing: Sp.sm) {
            Text("\(number)")
                .fmTypography(.caption)
                .fontWeight(.bold)
                .foregroundStyle(FMColors.Text.secondary)
                .frame(width: 24, height: 24)
                .background(FMColors.Background.bg3, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(reason.title)
                    .fmTypography(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(FMColors.Text.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(reason.body)
                    .fmTypography(.subhead)
                    .foregroundStyle(FMColors.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Sp.md)
        .padding(.vertical, Sp.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FMColors.Background.bg2)
        .clipShape(RoundedRectangle(cornerRadius: R.md))
        .overlay {
            RoundedRectangle(cornerRadius: R.md)
                .strokeBorder(FMColors.Border.subtle, lineWidth: 1)
        }
    }

    // MARK: - Moderator note

    private var moderatorNote: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("검수자 메모")
                .font(.system(size: 10, weight: .bold))
                .tracking(0.4)
                .textCase(.uppercase)
                .foregroundStyle(FMColors.Semantic.info)

            Text(data.moderatorNote)
                .fmTypography(.subhead)
                .foregroundStyle(FMColors.Text.primary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Sp.md)
        .padding(.vertical, Sp.sm)
        .background(FMColors.Semantic.infoBg)
        .clipShape(RoundedRectangle(cornerRadius: R.md))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(FMColors.Semantic.info)
                .frame(width: 3)
        }
        .clipShape(RoundedRectangle(cornerRadius: R.md))
    }

    // MARK: - Policy

    private var policySection: some View {
        VStack(alignment: .leading, spacing: Sp.xs) {
            Text("다음 단계")
                .fmTypography(.callout)
                .fontWeight(.bold)
                .foregroundStyle(FMColors.Text.primary)

            VStack(alignment: .leading, spacing: Sp.xs) {
                policyRow("재제출하면 다시 처음부터 심사가 진행되며 보통 48시간 이내 결과가 도착해요.")
                policyRow("같은 항목을 반복 제출하면 24시간 재제출 제한이 걸릴 수 있어요.")
                policyRow("결과에 이의가 있다면 고객센터로 사유와 필터 ID를 함께 보내주세요.")
            }
            .padding(Sp.md)
            .background(FMColors.Background.bg2, in: RoundedRectangle(cornerRadius: R.md))
            .overlay {
                RoundedRectangle(cornerRadius: R.md)
                    .strokeBorder(FMColors.Border.subtle, lineWidth: 1)
            }
        }
        .accessibilityIdentifier("mod.rejected.policy")
    }

    private func policyRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: Sp.xs) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(FMColors.Semantic.info)
                .padding(.top, 2)
            Text(text)
                .fmTypography(.subhead)
                .foregroundStyle(FMColors.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Timeline

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: Sp.xs) {
            Text("처리 이력")
                .fmTypography(.callout)
                .fontWeight(.bold)
                .foregroundStyle(FMColors.Text.primary)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(data.timeline) { entry in
                    timelineRow(entry)
                }
            }
            .padding(Sp.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FMColors.Background.bg2)
            .clipShape(RoundedRectangle(cornerRadius: R.md))
            .overlay {
                RoundedRectangle(cornerRadius: R.md)
                    .strokeBorder(FMColors.Border.subtle, lineWidth: 1)
            }
        }
    }

    private func timelineRow(_ entry: TimelineEntry) -> some View {
        HStack(alignment: .top, spacing: Sp.xs) {
            Text(entry.time)
                .fmTypography(.caption)
                .foregroundStyle(entry.isRejection ? FMColors.Semantic.error : FMColors.Text.tertiary)
                .frame(width: 80, alignment: .leading)

            Text(entry.event)
                .fmTypography(.caption)
                .fontWeight(entry.isRejection ? .semibold : .regular)
                .foregroundStyle(entry.isRejection ? FMColors.Semantic.error : FMColors.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Appeal

    private var appealLink: some View {
        HStack(spacing: 4) {
            Spacer()
            Text("결과에 동의하지 않으시나요?")
                .fmTypography(.caption)
                .foregroundStyle(FMColors.Text.secondary)

            Button {
                if let url = URL(string: "https://moodit.app/appeal") {
                    openURL(url)
                }
            } label: {
                HStack(spacing: 2) {
                    Text("이의 제기 신청")
                    Image(systemName: "arrow.up.forward")
                        .font(.system(size: 10, weight: .semibold))
                }
                .fmTypography(.caption)
                .fontWeight(.semibold)
                .underline()
                .foregroundStyle(FMColors.Accent.primary)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("mod.rejected.appeal")
            Spacer()
        }
        .padding(.top, Sp.xs)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: Sp.xs) {
            NavigationLink(value: AppRoute.editor) {
                HStack(spacing: Sp.xs) {
                    Image(systemName: "slider.horizontal.3")
                    Text("재편집 후 재제출")
                        .fmTypography(.callout)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(FMColors.Text.inverse)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(FMColors.Accent.primary, in: RoundedRectangle(cornerRadius: R.md))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("mod.rejected.edit")

            HStack(spacing: Sp.xs) {
                FMButton("고객센터 문의", icon: "envelope", variant: .secondary, size: .lg) {
                    contactSupport()
                }
                .accessibilityIdentifier("mod.rejected.support.footer")

                FMButton("필터 삭제", icon: "trash", variant: .destructive, size: .lg) {
                    showDeleteConfirm = true
                }
                .accessibilityIdentifier("mod.rejected.delete")
            }
        }
        .padding(.horizontal, Sp.md)
        .padding(.top, Sp.md)
        .padding(.bottom, Sp.md)
        .background(FMColors.Background.bg1)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(FMColors.Border.subtle)
                .frame(height: 1)
        }
    }

    private func contactSupport() {
        if let url = URL(string: "mailto:support@moodit.app?subject=Filter%20Rejection%20Question") {
            openURL(url)
        }
    }
}

// MARK: - Model

struct RejectionData {
    let filterName: String
    let submittedAt: String
    let heroTitle: String
    let heroDesc: String
    let reasons: [RejectionReason]
    let moderatorNote: String
    let timeline: [TimelineEntry]

    static func mock(forID id: String) -> RejectionData {
        RejectionData(
            filterName: id.isEmpty ? "Strange Vibe" : id,
            submittedAt: "2일 전 제출 · 2026-05-04",
            heroTitle: "아래 사항을 수정하면 재제출할 수 있어요",
            heroDesc: "콘텐츠 가이드라인에 맞지 않는 부분이 발견되었습니다. 수정 사항은 모두 draft에 반영되어 있어요.",
            reasons: [
                RejectionReason(
                    title: "기존 필터와 LUT 92% 유사",
                    body: "기존 공개 필터와 색조·대비 곡선이 거의 동일합니다."
                ),
                RejectionReason(
                    title: "표지 사진 1장 부족",
                    body: "최소 3장의 비포·애프터 표지가 필요합니다 (현재 2장)."
                ),
                RejectionReason(
                    title: "설명에 외부 링크 포함",
                    body: "설명에 다른 사이트로 유도하는 URL이 있습니다. 본인 메이커 페이지 외부 링크는 허용되지 않습니다."
                )
            ],
            moderatorNote: "색감 자체는 좋습니다. 새로운 LUT 곡선으로 재작업하시고, 표지를 한 장 더 추가하시면 통과 가능성이 높습니다.",
            timeline: [
                TimelineEntry(time: "5월 4일 14:22", event: "업로드 제출", isRejection: false),
                TimelineEntry(time: "5월 4일 16:08", event: "자동 검사 완료 (유사도 92% 플래그)", isRejection: false),
                TimelineEntry(time: "5월 6일 09:14", event: "검수자 검토 시작", isRejection: false),
                TimelineEntry(time: "5월 6일 09:41", event: "거부 통보 — 사유 3건", isRejection: true)
            ]
        )
    }
}

struct RejectionReason: Hashable {
    let title: String
    let body: String
}

struct TimelineEntry: Identifiable, Hashable {
    let id = UUID()
    let time: String
    let event: String
    let isRejection: Bool
}

// MARK: - Preview

#Preview("Filter rejected") {
    NavigationStack {
        FilterRejectedScreen(filterID: "Strange Vibe")
    }
}

#Preview("Filter rejected — Dark") {
    NavigationStack {
        FilterRejectedScreen(filterID: "Strange Vibe")
    }
    .preferredColorScheme(.dark)
}
