//
//  MainTabView.swift
//  Apolledge
//

import SwiftUI

/// Signed-in shell. A mutation anywhere bumps `revision`, which makes every loaded tab refetch:
/// the server is the source of truth, so tabs never patch each other's state.
struct MainTabView: View {
    let username: String
    let onSignOut: () -> Void

    @State private var selection = AppTab.ledger
    /// Tabs load on first visit and then stay alive, so switching back does not flash or refetch.
    @State private var visitedTabs: Set<AppTab> = [.ledger]
    @State private var revision = 0
    @State private var openedItem: LedgerItem?
    @State private var entryMode: EntryMode?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZStack {
                    ForEach(AppTab.allCases, id: \.self) { tab in
                        if visitedTabs.contains(tab) {
                            content(for: tab)
                                .opacity(tab == selection ? 1 : 0)
                                .allowsHitTesting(tab == selection)
                                .accessibilityHidden(tab != selection)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                AppTabBar(selection: $selection) { entryMode = .create }
            }
            // The design's 76pt bar includes the home indicator area.
            .ignoresSafeArea(.container, edges: .bottom)
            .background(AppColors.paper)
            .navigationTitle("Sổ")
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $openedItem) { item in
                TransactionDetailView(
                    item: item,
                    onEdit: { entryMode = .edit(item) },
                    onChanged: ledgerDidChange
                )
            }
        }
        .tint(AppColors.inkSecondary)
        .onChange(of: selection) { _, tab in visitedTabs.insert(tab) }
        .sheet(item: $entryMode) { mode in
            EntrySheet(mode: mode, onSaved: ledgerDidChange)
        }
    }

    @ViewBuilder
    private func content(for tab: AppTab) -> some View {
        switch tab {
        case .ledger:
            LedgerView(
                username: username,
                revision: revision,
                onOpen: { openedItem = $0 },
                onAdd: { entryMode = .create },
                onChanged: { revision += 1 },
                onSignOut: onSignOut
            )
        case .budget:
            BudgetView(revision: revision, onChanged: { revision += 1 })
        case .reports:
            ReportsView(revision: revision)
        case .recurring:
            RecurringView(revision: revision, onChanged: { revision += 1 })
        }
    }

    private func ledgerDidChange() {
        openedItem = nil
        revision += 1
    }
}

#Preview {
    MainTabView(username: "minh.tran", onSignOut: {})
}
