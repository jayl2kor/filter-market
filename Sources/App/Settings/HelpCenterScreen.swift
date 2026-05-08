import DesignSystem
import SwiftUI

/// 도움말 — Settings → 도움말 진입점.
///
/// FAQ 항목과 문의 채널을 보여줍니다. 환불 폼은 별도 라우트(`.refundRequest`)로
/// 분리되어 있으므로 도움말은 정보성 문서와 문의 링크에 집중합니다.
struct HelpCenterScreen: View {
    @State private var externalURL: ExternalURL?
    @State private var expandedFAQ: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.lg) {
                header

                section(title: "자주 묻는 질문") {
                    ForEach(faqItems, id: \.id) { item in
                        faqRow(item: item)
                        if item.id != faqItems.last?.id {
                            divider
                        }
                    }
                }

                section(title: "문의 채널") {
                    contactRow(
                        icon: "envelope",
                        title: "이메일 문의",
                        subtitle: "support@moodit.app"
                    ) {
                        if let url = URL(string: "mailto:support@moodit.app") {
                            externalURL = ExternalURL(value: url)
                        }
                    }
                    divider
                    NavigationLink(value: AppRoute.refundRequest) {
                        contactRowLabel(
                            icon: "arrow.uturn.backward.circle",
                            title: "환불 요청",
                            subtitle: "결제 환불은 별도 폼에서 처리합니다"
                        )
                    }
                    .buttonStyle(.plain)
                    divider
                    contactRow(
                        icon: "doc.text",
                        title: "이용약관",
                        subtitle: "moodit 서비스 이용 약관"
                    ) {
                        externalURL = ExternalURL(value: MooditPolicyURL.terms)
                    }
                    divider
                    contactRow(
                        icon: "hand.raised",
                        title: "개인정보처리방침",
                        subtitle: "개인정보 수집 및 이용"
                    ) {
                        externalURL = ExternalURL(value: MooditPolicyURL.privacy)
                    }
                }

                Text("도움이 필요하신가요? 이메일로 문의해 주세요.")
                    .font(Font.fmCaption)
                    .foregroundStyle(FMColors.Text.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, Sp.md)
            }
            .padding(Sp.md)
        }
        .background(FMColors.Background.bg1.ignoresSafeArea())
        .navigationTitle("도움말")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $externalURL) { item in
            SafariView(url: item.value)
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: Sp.xxs) {
            Text("어떻게 도와드릴까요?")
                .font(Font.fmTitleLarge)
                .foregroundStyle(FMColors.Text.primary)
            Text("자주 묻는 질문과 문의 채널을 안내합니다.")
                .font(Font.fmBody)
                .foregroundStyle(FMColors.Text.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, Sp.xs)
    }

    @ViewBuilder
    private func section<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Sp.xs) {
            Text(title)
                .font(Font.fmCaption)
                .foregroundStyle(FMColors.Text.secondary)
                .padding(.leading, Sp.xs)
            VStack(spacing: 0) { content() }
                .background(FMColors.Background.bg2)
                .clipShape(RoundedRectangle(cornerRadius: R.lg))
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(FMColors.Border.subtle)
            .frame(height: 0.5)
            .padding(.leading, Sp.lg)
    }

    // MARK: - Rows

    @ViewBuilder
    private func faqRow(item: FAQItem) -> some View {
        let isExpanded = expandedFAQ == item.id
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                expandedFAQ = isExpanded ? nil : item.id
            }
        } label: {
            VStack(alignment: .leading, spacing: Sp.xxs) {
                HStack(spacing: Sp.sm) {
                    Text(item.question)
                        .font(Font.fmBody)
                        .foregroundStyle(FMColors.Text.primary)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(FMColors.Text.tertiary)
                }
                if isExpanded {
                    Text(item.answer)
                        .font(Font.fmBody)
                        .foregroundStyle(FMColors.Text.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, Sp.xxs)
                }
            }
            .padding(Sp.md)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func contactRow(
        icon: String,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            contactRowLabel(icon: icon, title: title, subtitle: subtitle)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func contactRowLabel(
        icon: String,
        title: String,
        subtitle: String
    ) -> some View {
        HStack(spacing: Sp.md) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(FMColors.Accent.primary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Font.fmBody)
                    .foregroundStyle(FMColors.Text.primary)
                Text(subtitle)
                    .font(Font.fmCaption)
                    .foregroundStyle(FMColors.Text.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(FMColors.Text.tertiary)
        }
        .padding(Sp.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - FAQ data

    private var faqItems: [FAQItem] {
        [
            FAQItem(
                id: "coin",
                question: "코인은 어떻게 사용하나요?",
                answer: "유료 필터를 다운로드할 때 코인을 차감합니다. 충전은 설정 → 결제 및 구독 → 충전하기에서 가능합니다."
            ),
            FAQItem(
                id: "pro",
                question: "Pro 멤버십 혜택은 무엇인가요?",
                answer: "Pro는 모든 무료 + 일부 유료 필터 무제한 사용, 광고 제거, 메이커 분석 도구를 제공합니다."
            ),
            FAQItem(
                id: "refund",
                question: "결제 환불은 어떻게 신청하나요?",
                answer: "App Store 결제는 Apple 정책에 따라 reportaproblem.apple.com에서 직접 신청하세요. 코인 차감 환불은 도움말 → 환불 요청 폼을 이용하세요."
            ),
            FAQItem(
                id: "delete",
                question: "계정을 삭제하고 싶어요.",
                answer: "설정 → 계정 → 계정 삭제에서 신청할 수 있습니다. 보유 코인과 업로드한 필터는 삭제 후 복구되지 않습니다."
            ),
            FAQItem(
                id: "report",
                question: "부적절한 필터/사용자를 신고하려면?",
                answer: "필터 상세 화면 우상단 메뉴에서 '신고하기'를 선택하세요. 24시간 내 검수합니다."
            ),
            FAQItem(
                id: "block",
                question: "특정 사용자를 차단하려면?",
                answer: "프로필 화면의 메뉴에서 차단할 수 있고, 설정 → 알림 및 콘텐츠 → 차단 사용자에서 관리할 수 있습니다."
            )
        ]
    }
}

private struct FAQItem {
    let id: String
    let question: String
    let answer: String
}

#Preview {
    NavigationStack {
        HelpCenterScreen()
    }
}
