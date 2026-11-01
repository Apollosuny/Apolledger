//
//  LedgerComponents.swift
//  Apolledge
//

import SwiftUI

/// Maps the backend's Material Symbols names (the design's vocabulary) to SF Symbols.
enum LedgerIcon {
    private static let symbols = [
        "restaurant": "fork.knife",
        "directions_car": "car",
        "home": "house",
        "shopping_bag": "bag",
        "medication": "pills",
        "sports_esports": "gamecontroller",
        "more_horiz": "ellipsis",
        "payments": "banknote",
        "sell": "tag",
    ]

    static func symbol(for icon: String?) -> String {
        icon.flatMap { symbols[$0] } ?? "circle"
    }
}

/// `6.240.000 ₫`: the one big serif number of a screen, with a smaller muted currency mark.
struct HeroAmount: View {
    let amount: Int64
    var font = AppTypography.hero
    var color = AppColors.ink

    var body: some View {
        Text("\(Text(Money.grouped(amount)).foregroundStyle(color))\(Text(" ₫").font(AppTypography.heroCurrency).foregroundStyle(AppColors.inkTertiary))")
            .font(font)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .accessibilityLabel(Money.vnd(amount))
    }
}

struct SectionLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .appLabelStyle()
    }
}

/// 34pt bordered square from the design, with a 44pt hit target.
struct HeaderIconButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15))
                .foregroundStyle(AppColors.inkSecondary)
                .frame(width: 34, height: 34)
                .overlay {
                    RoundedRectangle(cornerRadius: 10).strokeBorder(AppColors.hairlineStrong, lineWidth: 1)
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// One row of the ledger: lines instead of cards, amounts in a tabular mono column.
struct TransactionRow: View {
    let icon: String
    let title: String
    let meta: String
    let amount: String
    let amountColor: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(AppColors.inkSecondary)
                .frame(width: 26)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTypography.row)
                    .foregroundStyle(AppColors.ink)
                    .lineLimit(1)
                Text(meta)
                    .font(AppTypography.meta)
                    .foregroundStyle(AppColors.inkTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: AppSpacing.xs)

            Text(amount)
                .font(AppTypography.amount)
                .monospacedDigit()
                .foregroundStyle(amountColor)
                .lineLimit(1)
        }
        .padding(.vertical, 11)
        .frame(minHeight: 60)
        .contentShape(Rectangle())
        .overlay(alignment: .top) { Hairline() }
        .accessibilityElement(children: .combine)
    }
}

struct Hairline: View {
    var strong = false

    var body: some View {
        Rectangle()
            .fill(strong ? AppColors.hairlineStrong : AppColors.hairline)
            .frame(height: 1)
    }
}

/// 3pt progress line used by budgets and report breakdowns.
struct ProgressLine: View {
    let fraction: Double
    var color = AppColors.ink

    var body: some View {
        GeometryReader { proxy in
            Rectangle()
                .fill(color)
                .frame(width: proxy.size.width * min(max(fraction, 0), 1))
        }
        .frame(height: 3)
        .background(AppColors.hairline)
    }
}

struct DashedAddButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: "plus")
                .font(AppTypography.row)
                .foregroundStyle(AppColors.inkSecondary)
                .frame(maxWidth: .infinity, minHeight: 46)
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadius.control)
                        .strokeBorder(AppColors.hairlineStrong, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Two-option switch from the entry sheet and the report header.
struct SegmentedSwitch<Value: Hashable>: View {
    let options: [(value: Value, title: String)]
    @Binding var selection: Value
    var font = AppTypography.link

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.value) { option in
                let isSelected = option.value == selection
                Button {
                    selection = option.value
                } label: {
                    Text(option.title)
                        .font(font)
                        .foregroundStyle(isSelected ? AppColors.ink : AppColors.inkSecondary)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .padding(.horizontal, AppSpacing.xs)
                        .background(isSelected ? AppColors.paper : .clear, in: RoundedRectangle(cornerRadius: 9))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(AppColors.paperSecondary, in: RoundedRectangle(cornerRadius: AppRadius.control))
        .animation(AppMotion.standard, value: selection)
    }
}

struct CategoryChip: View {
    let account: Account
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(account.name, systemImage: LedgerIcon.symbol(for: account.icon))
                .font(AppTypography.chip)
                .foregroundStyle(isSelected ? AppColors.paper : AppColors.inkSecondary)
                .padding(.horizontal, 13)
                .frame(minHeight: 38)
                .background(isSelected ? AppColors.ink : .clear, in: Capsule())
                .overlay {
                    Capsule().strokeBorder(isSelected ? AppColors.ink : AppColors.hairlineStrong, lineWidth: 1)
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Wrapping row for chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 7

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let height = rows(in: width, subviews: subviews).last.map { $0.y + $0.height } ?? 0
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in rows(in: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var y: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(in width: CGFloat, subviews: Subviews) -> [Row] {
        var rows = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if !rows[rows.count - 1].indices.isEmpty, rows[rows.count - 1].width + spacing + size.width > width {
                let previous = rows[rows.count - 1]
                rows.append(Row(y: previous.y + previous.height + spacing))
            }
            let last = rows.count - 1
            rows[last].width += (rows[last].indices.isEmpty ? 0 : spacing) + size.width
            rows[last].height = max(rows[last].height, size.height)
            rows[last].indices.append(index)
        }
        return rows
    }
}

/// Label/value row of forms and the transaction detail.
struct DetailRow<Value: View>: View {
    let label: String
    @ViewBuilder let value: () -> Value

    var body: some View {
        HStack {
            Text(label)
                .font(AppTypography.subtitle)
                .foregroundStyle(AppColors.inkSecondary)
            Spacer(minLength: AppSpacing.md)
            value()
                .font(AppTypography.row)
                .foregroundStyle(AppColors.ink)
        }
        .frame(minHeight: 46)
        .overlay(alignment: .top) { Hairline() }
    }
}

/// Design system: errors state the fact in ink; the expense color only ever means money going out.
struct InlineError: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.circle")
            .font(AppTypography.caption)
            .foregroundStyle(AppColors.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .transition(.opacity)
    }
}

/// Design system: no illustration, no emoji. One serif sentence and one action.
struct EmptyState: View {
    let title: String
    var detail: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            Text(title)
                .font(AppTypography.screenTitle)
                .foregroundStyle(AppColors.ink)
            if let detail {
                Text(detail)
                    .font(AppTypography.subtitle)
                    .foregroundStyle(AppColors.inkSecondary)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(AppTypography.link)
                    .foregroundStyle(AppColors.ink)
                    .frame(minHeight: 44)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xxl)
    }
}

extension View {
    /// Design system loading: the lines are already there, content fades in over 200ms. No spinner.
    func fadesIn(when isLoaded: Bool) -> some View {
        opacity(isLoaded ? 1 : 0)
            .animation(.easeOut(duration: 0.2), value: isLoaded)
    }
}

extension Error {
    /// User-facing text. Unknown errors never leak internals into the UI.
    var userMessage: String {
        (self as? LocalizedError)?.errorDescription ?? "Đã có lỗi xảy ra. Vui lòng thử lại."
    }
}
