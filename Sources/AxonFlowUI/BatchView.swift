import AxonFlowCore
import SwiftUI

public struct BatchView: View {
    @Bindable var state: AxonAppState

    public init(state: AxonAppState) {
        self.state = state
    }

    public var body: some View {
        VStack(spacing: 10) {
            datasetHeaderCard
            progressCard
            tracesSection
        }
    }

    private var datasetHeaderCard: some View {
        let preflight = CSVBatchEngine.preflight(workflow: state.activeWorkflow, dataset: state.dataset)
        return AxonGlassCard(padding: 11, cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(state.dataset.fileName, systemImage: "doc.text.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AxonTheme.textPrimary)
                    Spacer()
                    Text(preflight.isReady ? "SCHEMA MATCHED" : "MISSING COLS")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(preflight.isReady ? AxonTheme.emerald : AxonTheme.rose)
                        .padding(.horizontal, 6.5)
                        .padding(.vertical, 2.5)
                        .background(Capsule().fill((preflight.isReady ? AxonTheme.emerald : AxonTheme.rose).opacity(0.16)))
                }

                HStack(spacing: 5) {
                    ForEach(state.dataset.headers.prefix(4), id: \.self) { col in
                        let mapped = preflight.requiredVariables.contains(col)
                        Text(mapped ? "{{\(col)}} ✓" : col)
                            .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                            .foregroundStyle(mapped ? AxonTheme.cyan : AxonTheme.textTertiary)
                            .padding(.horizontal, 6.5)
                            .padding(.vertical, 2.5)
                            .background(Capsule().fill(mapped ? AxonTheme.cyan.opacity(0.14) : Color.white.opacity(0.06)))
                    }
                }

                HStack(spacing: 8) {
                    Button {
                        state.runCSVBatchDryRun()
                    } label: {
                        Label("Verify Batch Against Moved Window", systemImage: "play.rectangle.fill")
                            .font(.system(size: 10.8, weight: .bold))
                            .foregroundStyle(Color.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(AxonTheme.emerald))
                    }
                    .buttonStyle(.plain)

                    Button {
                        state.copyAppleScript()
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(AxonTheme.amber)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(AxonTheme.amber.opacity(0.15)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var progressCard: some View {
        let total = max(state.batchTotalRows, 1)
        let frac = min(1.0, Double(state.batchCompletedRows) / Double(total))
        return AxonGlassCard(padding: 10, cornerRadius: 13) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Batch Execution Telemetry")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AxonTheme.textPrimary)
                    Spacer()
                    Text("\(state.batchCompletedRows)/\(state.batchTotalRows) rows · \(String(format: "%.1f%%", state.batchSuccessRate)) match")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(AxonTheme.emerald)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [AxonTheme.amber, AxonTheme.emerald],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(8, geo.size.width * CGFloat(frac)))
                    }
                }
                .frame(height: 6.5)
            }
        }
    }

    @ViewBuilder
    private var tracesSection: some View {
        if state.batchTraces.isEmpty {
            AxonGlassCard(padding: 18) {
                Text("Run a CSV batch to inspect per-row semantic AX selector resolution traces.")
                    .font(.system(size: 11))
                    .foregroundStyle(AxonTheme.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        } else {
            VStack(spacing: 6) {
                ForEach(state.batchTraces.prefix(4)) { trace in
                    AxonGlassCard(padding: 9, cornerRadius: 11) {
                        HStack(spacing: 8) {
                            Image(systemName: trace.succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(trace.succeeded ? AxonTheme.emerald : AxonTheme.rose)

                            VStack(alignment: .leading, spacing: 1.5) {
                                Text("Row #\(trace.rowIndex) · \(trace.primaryLabel)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(AxonTheme.textPrimary)
                                    .lineLimit(1)
                                Text("\(trace.stepsExecuted) semantic steps resolved via \(trace.strategyUsed.rawValue)")
                                    .font(.system(size: 9.5, design: .monospaced))
                                    .foregroundStyle(AxonTheme.textSecondary)
                            }

                            Spacer()

                            Text(String(format: "%.2f ms", trace.durationMs))
                                .font(.system(size: 9.8, weight: .bold, design: .monospaced))
                                .foregroundStyle(AxonTheme.cyan)
                                .padding(.horizontal, 6.5)
                                .padding(.vertical, 2.5)
                                .background(Capsule().fill(AxonTheme.cyan.opacity(0.14)))
                        }
                    }
                }
            }
        }
    }
}
