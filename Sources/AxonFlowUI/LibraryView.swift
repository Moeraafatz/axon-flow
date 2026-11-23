import AxonFlowCore
import SwiftUI

public struct LibraryView: View {
    @Bindable var state: AxonAppState

    public init(state: AxonAppState) {
        self.state = state
    }

    public var body: some View {
        VStack(spacing: 10) {
            roiStrip
            workflowList
        }
    }

    private var roiStrip: some View {
        let totalRuns = state.workflows.reduce(0) { $0 + $1.runCount }
        let hoursSaved = state.workflows.reduce(0.0) { $0 + $1.totalHoursSaved }
        return HStack(spacing: 8) {
            metricTile(title: "WORKFLOWS", value: "\(state.workflows.count)", accent: AxonTheme.amber)
            metricTile(title: "BATCH RUNS", value: "\(totalRuns)", accent: AxonTheme.cyan)
            metricTile(title: "TIME SAVED", value: String(format: "%.1f hrs", hoursSaved), accent: AxonTheme.emerald)
        }
    }

    private func metricTile(title: String, value: String, accent: Color) -> some View {
        AxonGlassCard(padding: 9, cornerRadius: 11) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(AxonTheme.textTertiary)
                Text(value)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(accent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var workflowList: some View {
        VStack(spacing: 7) {
            ForEach(state.workflows.prefix(4)) { wf in
                Button {
                    state.selectWorkflow(wf)
                } label: {
                    AxonGlassCard(
                        padding: 10,
                        cornerRadius: 12,
                        borderColor: wf.id == state.activeWorkflow.id ? AxonTheme.amber.opacity(0.45) : AxonTheme.cardBorder
                    ) {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(wf.name)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(AxonTheme.textPrimary)
                                    .lineLimit(1)
                                Spacer()
                                Text(wf.hotkeyLabel)
                                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                    .foregroundStyle(AxonTheme.amber)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(AxonTheme.amber.opacity(0.15)))
                            }

                            Text(wf.summary)
                                .font(.system(size: 10.4))
                                .foregroundStyle(AxonTheme.textSecondary)
                                .lineLimit(1)

                            HStack(spacing: 9) {
                                Text("\(wf.steps.count) AX steps")
                                    .foregroundStyle(AxonTheme.cyan)
                                Text("\(wf.variables.count) vars")
                                    .foregroundStyle(AxonTheme.amber)
                                Text("\(wf.runCount) runs")
                                    .foregroundStyle(AxonTheme.emerald)
                                Spacer()
                                Text(String(format: "~%.1fh saved", wf.totalHoursSaved))
                                    .foregroundStyle(AxonTheme.textTertiary)
                            }
                            .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}
