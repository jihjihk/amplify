import SwiftUI

// MARK: - TabBar

struct TabBar: View {
    @ObservedObject var viewModel: HubViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(viewModel.openTabs.enumerated()), id: \.offset) { idx, tab in
                    TabPill(
                        tab: tab,
                        isActive: idx == viewModel.activeTabIndex,
                        isDirty: viewModel.dirtyTabPaths.contains(tab.filePath ?? URL(fileURLWithPath: "")),
                        onSelect: {
                            viewModel.activeTabIndex = idx
                            viewModel.objectWillChange.send()
                        },
                        onClose: { viewModel.closeTab(at: idx) }
                    )
                }
            }
        }
        .frame(height: 36)
        .background(AmplifyColors.barBg)
        .overlay(alignment: .bottom) { Divider() }
    }
}

// MARK: - TabPill

struct TabPill: View {
    let tab: WritingPiece
    let isActive: Bool
    let isDirty: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovered = false

    private var label: String {
        tab.filePath?.deletingPathExtension().lastPathComponent
            ?? tab.frontMatter.title
            ?? "Untitled"
    }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "doc.text")
                .font(.system(size: 11))
                .foregroundStyle(isActive ? AmplifyColors.inkSecondary : AmplifyColors.inkTertiary)

            Text(label)
                .font(.system(size: 12, weight: isActive ? .medium : .regular))
                .foregroundStyle(isActive ? AmplifyColors.inkPrimary : AmplifyColors.inkSecondary)
                .lineLimit(1)

            ZStack {
                if isDirty && !isHovered {
                    Circle()
                        .fill(AmplifyColors.accent)
                        .frame(width: 6, height: 6)
                } else {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(AmplifyColors.inkTertiary)
                    }
                    .buttonStyle(.plain)
                    .opacity(isHovered || isActive ? 1 : 0)
                }
            }
            .frame(width: 14, height: 14)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isActive ? AmplifyColors.surface : Color.clear)
        .overlay(alignment: .bottom) {
            if isActive {
                Rectangle()
                    .fill(AmplifyColors.accent)
                    .frame(height: 1.5)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .onHover { isHovered = $0 }
    }
}
