import SwiftUI

struct TerminalTab: Identifiable {
    let id = UUID()
    let label: String
}

struct TerminalTabsView: View {
    let folderPath: URL
    @State private var tabs: [TerminalTab] = [TerminalTab(label: "Terminal 1")]
    @State private var activeTabID: UUID? = nil

    var body: some View {
        VStack(spacing: 0) {
            terminalTabBar

            ZStack {
                ForEach(tabs) { tab in
                    TerminalPanelView(folderPath: folderPath)
                        .id(tab.id)
                        .opacity(tab.id == resolvedActiveID ? 1 : 0)
                        .allowsHitTesting(tab.id == resolvedActiveID)
                }
            }
        }
        .onAppear {
            if activeTabID == nil { activeTabID = tabs.first?.id }
        }
    }

    private var resolvedActiveID: UUID {
        activeTabID ?? tabs.first?.id ?? UUID()
    }

    // MARK: - Tab Bar

    private var terminalTabBar: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(tabs) { tab in
                        terminalTabPill(tab)
                    }
                }
            }

            Spacer()

            Button {
                let newTab = TerminalTab(label: "Terminal \(tabs.count + 1)")
                tabs.append(newTab)
                activeTabID = newTab.id
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AmplifyColors.inkTertiary)
            }
            .buttonStyle(.plain)
            .help("New Terminal")
            .padding(.trailing, 8)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(AmplifyColors.barBg)
    }

    private func terminalTabPill(_ tab: TerminalTab) -> some View {
        let isActive = tab.id == resolvedActiveID

        return HStack(spacing: 4) {
            Image(systemName: "terminal")
                .font(.system(size: 10))
                .foregroundStyle(isActive ? AmplifyColors.inkSecondary : AmplifyColors.inkTertiary)

            Text(tab.label)
                .font(.system(size: 11, weight: isActive ? .medium : .regular))
                .foregroundStyle(isActive ? AmplifyColors.inkPrimary : AmplifyColors.inkSecondary)
                .lineLimit(1)

            if tabs.count > 1 {
                Button {
                    closeTab(tab)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(AmplifyColors.inkTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(isActive ? AmplifyColors.surface : Color.clear)
        .cornerRadius(4)
        .contentShape(Rectangle())
        .onTapGesture { activeTabID = tab.id }
    }

    private func closeTab(_ tab: TerminalTab) {
        guard tabs.count > 1 else { return }
        if let idx = tabs.firstIndex(where: { $0.id == tab.id }) {
            let wasActive = tab.id == activeTabID
            tabs.remove(at: idx)
            if wasActive {
                let newIdx = min(idx, tabs.count - 1)
                activeTabID = tabs[newIdx].id
            }
        }
    }
}
