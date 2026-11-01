//
//  ReportsView.swift
//  Apolledge
//

import SwiftUI

/// The "Báo cáo" tab.
struct ReportsView: View {
    let revision: Int

    @Environment(\.ledgerService) private var service
    @State private var viewModel = ReportsViewModel()
    @State private var range = ReportRange.sixMonths

    private struct LoadKey: Hashable {
        let range: ReportRange
        let revision: Int
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                if let errorMessage = viewModel.errorMessage {
                    InlineError(message: errorMessage)
                }
                if let report = viewModel.report {
                    Group {
                        if report.peakVnd == 0 {
                            EmptyState(title: "Trang trắng", detail: "Chưa có khoản chi nào để báo cáo")
                        } else {
                            summary(report)
                            breakdown(report)
                        }
                    }
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.lg)
        }
        .background(AppColors.paper)
        .task(id: LoadKey(range: range, revision: revision)) {
            await viewModel.load(range: range, service: service)
        }
        .refreshable {
            await viewModel.load(range: range, service: service)
        }
    }

    private var header: some View {
        HStack {
            Text("Báo cáo")
                .font(AppTypography.screenTitle)
                .foregroundStyle(AppColors.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            SegmentedSwitch(
                options: [(ReportRange.sixMonths, "6T"), (ReportRange.oneYear, "1N")],
                selection: $range,
                font: AppTypography.figureSmall
            )
            .frame(width: 104)
        }
        .frame(height: AppSpacing.headerHeight)
    }

    private func summary(_ report: SpendingReport) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionLabel("Chi trung bình / tháng")
            HeroAmount(amount: report.averageVnd, font: AppTypography.heroSecondary)
            chart(report)
        }
        .padding(.bottom, AppSpacing.md)
        .overlay(alignment: .bottom) { Hairline(strong: true) }
    }

    private func chart(_ report: SpendingReport) -> some View {
        HStack(alignment: .bottom, spacing: report.months.count > 6 ? 4 : 9) {
            ForEach(report.months) { entry in
                let isCurrent = entry.id == report.currentMonth?.id
                VStack(spacing: 7) {
                    Spacer(minLength: 0)
                    if entry.spentVnd > 0 {
                        Text(Money.millions(entry.spentVnd))
                            .font(.custom("GeistMono-Regular", size: 9.5))
                            .monospacedDigit()
                            .lineLimit(1)
                            .fixedSize()
                            .foregroundStyle(isCurrent ? AppColors.ink : AppColors.inkTertiary)
                    }
                    UnevenRoundedRectangle(topLeadingRadius: 3, topTrailingRadius: 3)
                        .fill(isCurrent ? AppColors.ink : AppColors.hairline)
                        .frame(height: barHeight(entry.spentVnd, peak: report.peakVnd))
                    Text("T\(entry.month.month)")
                        .font(.custom("GeistMono-Regular", size: 9.5))
                        .foregroundStyle(AppColors.inkTertiary)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Tháng \(entry.month.month): \(Money.vnd(entry.spentVnd))")
            }
        }
        .frame(height: 130)
        .padding(.top, 6)
    }

    private func barHeight(_ amount: Int64, peak: Int64) -> CGFloat {
        guard peak > 0, amount > 0 else { return 1 }
        return max(4, 80 * CGFloat(amount) / CGFloat(peak))
    }

    @ViewBuilder
    private func breakdown(_ report: SpendingReport) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel("Tháng \(report.currentMonth?.month.month ?? 0) theo danh mục")
                Spacer()
                Text(Money.grouped(report.currentMonth?.spentVnd ?? 0))
                    .font(AppTypography.figureSmall)
                    .monospacedDigit()
                    .foregroundStyle(AppColors.inkTertiary)
            }
            if report.categories.isEmpty {
                Text("Chưa có khoản chi nào trong tháng này")
                    .font(AppTypography.subtitle)
                    .foregroundStyle(AppColors.inkSecondary)
            }
            ForEach(report.categories) { category in
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: LedgerIcon.symbol(for: category.icon))
                        .font(.system(size: 16))
                        .foregroundStyle(AppColors.inkSecondary)
                        .frame(width: 26)
                        .accessibilityHidden(true)
                    VStack(spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(category.name)
                                .font(AppTypography.row)
                                .foregroundStyle(AppColors.ink)
                            Spacer()
                            Text(Money.grouped(category.spentVnd))
                                .font(AppTypography.figureMedium)
                                .monospacedDigit()
                                .foregroundStyle(AppColors.inkSecondary)
                        }
                        ProgressLine(fraction: category.share)
                    }
                    Text("\(Int((category.share * 100).rounded()))%")
                        .font(AppTypography.figureSmall)
                        .monospacedDigit()
                        .foregroundStyle(AppColors.inkTertiary)
                        .frame(width: 34, alignment: .trailing)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

#Preview {
    ReportsView(revision: 0)
}
