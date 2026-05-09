import DesignSystem
import Foundation
import SwiftUI

struct DataExportScreen: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @Environment(\.openURL) private var openURL
    @State private var showSubmitAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Sp.lg) {
                workflowHeader(
                    title: "내 데이터 사본 받기",
                    subtitle: "계정과 활동 데이터를 요청하면 보안 링크로 전달됩니다.",
                    symbol: "doc.zipper"
                )

                categorySection
                formatSection
                historySection
                noticeCard

                FMButton("데이터 사본 요청", icon: "paperplane.fill", variant: .primary, size: .lg) {
                    showSubmitAlert = true
                }
                .disabled(sessionStore.selectedExportCategories.isEmpty)
                .accessibilityIdentifier("settings.export.submit")
            }
            .padding(Sp.md)
            .padding(.bottom, FMLayout.tabBarHeight + Sp.xxxl)
        }
        .background(FMColors.Background.bg1)
        .navigationTitle("데이터 다운로드")
        .navigationBarTitleDisplayMode(.inline)
        .alert("데이터 사본을 요청할까요?", isPresented: $showSubmitAlert) {
            Button("요청") {
                sessionStore.requestDataExport()
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("요청 후 최대 30일 이내 보안 링크로 안내됩니다.")
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: Sp.sm) {
            sectionLabel("포함할 데이터")
            FMCard {
                VStack(spacing: 0) {
                    ForEach(DataExportCategory.allCases) { category in
                        Button {
                            sessionStore.toggleExportCategory(category)
                        } label: {
                            HStack(alignment: .top, spacing: Sp.sm) {
                                Image(systemName: sessionStore.selectedExportCategories.contains(category) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(sessionStore.selectedExportCategories.contains(category) ? FMColors.Accent.primary : FMColors.Text.tertiary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(category.title)
                                        .fmTypography(.headline)
                                        .foregroundStyle(FMColors.Text.primary)
                                    Text(category.detail)
                                        .fmTypography(.caption)
                                        .foregroundStyle(FMColors.Text.secondary)
                                }
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, Sp.xs)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("settings.export.cat.toggle.\(category.rawValue)")
                        if category.id != DataExportCategory.allCases.last?.id {
                            workflowDivider()
                        }
                    }
                }
            }
            .accessibilityIdentifier("settings.export.cat.toggle")
        }
    }

    private var formatSection: some View {
        VStack(alignment: .leading, spacing: Sp.sm) {
            sectionLabel("파일 형식")
            HStack(spacing: Sp.xs) {
                ForEach(DataExportFormat.allCases) { format in
                    Button {
                        sessionStore.selectedExportFormat = format
                    } label: {
                        VStack(spacing: 2) {
                            Text(format.rawValue)
                                .fmTypography(.headline)
                            Text(format.description)
                                .font(.caption2)
                                .lineLimit(1)
                        }
                        .foregroundStyle(sessionStore.selectedExportFormat == format ? .white : FMColors.Text.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(
                            sessionStore.selectedExportFormat == format ? FMColors.Accent.primary : FMColors.Background.bg2,
                            in: RoundedRectangle(cornerRadius: R.md)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: R.md)
                                .strokeBorder(FMColors.Border.default, lineWidth: sessionStore.selectedExportFormat == format ? 0 : 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .accessibilityIdentifier("settings.export.format")
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: Sp.sm) {
            sectionLabel("이전 요청")
            FMCard {
                VStack(spacing: 0) {
                    ForEach(sessionStore.exportRequests) { request in
                        HStack(spacing: Sp.sm) {
                            Image(systemName: request.status == "만료" ? "clock.badge.exclamationmark" : "doc.text")
                                .foregroundStyle(request.status == "만료" ? FMColors.Text.tertiary : FMColors.Accent.primary)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(request.title) — \(request.format.rawValue)")
                                    .fmTypography(.subhead)
                                    .foregroundStyle(FMColors.Text.primary)
                                Text(workflowDateString(request.requestedAt))
                                    .fmTypography(.caption)
                                    .foregroundStyle(FMColors.Text.secondary)
                            }
                            Spacer()
                            if let downloadURL = request.downloadURL {
                                Button("다운로드") {
                                    openURL(downloadURL)
                                }
                                .fmTypography(.caption)
                                .foregroundStyle(FMColors.Accent.primary)
                                .accessibilityIdentifier("settings.export.download.\(request.id)")
                            } else {
                                Text(request.status)
                                    .fmTypography(.caption)
                                    .foregroundStyle(request.status == "만료" ? FMColors.Text.tertiary : FMColors.Accent.primary)
                            }
                        }
                        .padding(.vertical, Sp.xs)
                        if request.id != sessionStore.exportRequests.last?.id {
                            workflowDivider()
                        }
                    }
                }
            }
        }
    }

    private var noticeCard: some View {
        HStack(alignment: .top, spacing: Sp.sm) {
            Image(systemName: "lock.shield")
                .foregroundStyle(FMColors.Accent.primary)
            Text("보안 링크는 7일간 유효합니다. 다운로드 URL은 이메일과 알림 인박스에 동시에 발송됩니다.")
                .fmTypography(.caption)
                .foregroundStyle(FMColors.Text.secondary)
        }
        .padding(Sp.md)
        .background(FMColors.Accent.bg, in: RoundedRectangle(cornerRadius: R.md))
    }
}
