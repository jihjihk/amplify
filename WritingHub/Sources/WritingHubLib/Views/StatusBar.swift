import SwiftUI

public struct StatusBar: View {
    @ObservedObject var viewModel: HubViewModel

    public init(viewModel: HubViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        HStack(spacing: 16) {
            Label("Pipeline:", systemImage: "arrow.right.square")

            ForEach(Array(PipelineStage.allCases.enumerated()), id: \.element) { index, stage in
                if index > 0 {
                    Text("\u{2192}")
                        .foregroundStyle(.tertiary)
                }
                let count = viewModel.pipelineCounts()[stage] ?? 0
                Text("\(count) \(stage.displayName.lowercased())")
            }

            Spacer()

            Label("Cadence: --", systemImage: "calendar")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }
}
