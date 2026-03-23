import SwiftUI

public struct StatusBar: View {
    @ObservedObject var viewModel: HubViewModel

    public init(viewModel: HubViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        HStack(spacing: 16) {
            if let root = viewModel.folderManager?.root {
                Label(root.lastPathComponent, systemImage: "folder")
            }

            Text("\(viewModel.fileCount()) files")

            if let workspaceWarning = viewModel.workspaceWarning {
                Label(workspaceWarning, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.orange)
                    .lineLimit(1)
            }

            if let noticeMessage = viewModel.noticeMessage {
                Label(noticeMessage, systemImage: "info.circle")
                    .lineLimit(1)
            }

            Spacer()
        }
        .font(.system(size: 11))
        .foregroundStyle(AmplifyColors.inkTertiary)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(AmplifyColors.barBg)
    }
}
