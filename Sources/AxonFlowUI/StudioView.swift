import AxonFlowCore
import SwiftUI

public struct StudioView: View {
    @Bindable var state: AxonAppState

    public init(state: AxonAppState) {
        self.state = state
    }

    public var body: some View {
        VStack(spacing: 10) {
            workflowHeaderCard
            stepGraphSection
        }
    }

    private var workflowHeaderCard: some View {
        let wf = state.activeWorkflow
        return AxonGlassCard(padding: 11, cornerRadius: 14, borderColor: state.isRecording ? AxonTheme.rose.opacity(0.45) : AxonTheme.amber.opacity(0.30)) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(wf.name)
                                .font(.system(size: 12.5, weight: .bold))
                                .foregroundStyle(AxonTheme.textPrimary)
                                .lineLimit(1)
                            Text(wf.hotkeyLabel)
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(AxonTheme.amber)
                                .padding(.horizontal, 5.5)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(AxonTheme.amber.opacity(0.16)))
                        }
                        Text(String(
                            format: "%d raw events → %d semantic AX steps (%.0f%% compressed) · %d {{vars}}",
                            wf.rawEventCount,
                            wf.steps.count,
                            wf.compressionPercent,
                            wf.variables.count
                        ))
                        .font(.system(size: 9.8, design: .monospaced))
                        .foregroundStyle(AxonTheme.textSecondary)
                    }
                    Spacer()
                }

                if !wf.variables.isEmpty {
                    HStack(spacing: 5) {
                        Text("PARAMS:")
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(AxonTheme.textTertiary)
                        ForEach(wf.variables.prefix(4), id: \.self) { v in
                            Text("{{\(v)}}")
                                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(AxonTheme.cyan)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(AxonTheme.cyan.opacity(0.14)))
                        }
                    }
                }

                HStack(spacing: 7) {
                    Button {
                        state.toggleRecording()
                    } label: {
                        Label(
                            state.isRecording ? "Stop & Compile" : "Record Task Once",
                            systemImage: state.isRecording ? "stop.circle.fill" : "record.circle"
                        )
                        .font(.system(size: 10.8, weight: .bold))
                        .foregroundStyle(state.isRecording ? Color.white : Color.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(state.isRecording ? AxonTheme.rose : AxonTheme.amber)
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        state.runActiveWorkflowOnce()
                    } label: {
                        Label("Run", systemImage: "play.fill")
                            .font(.system(size: 10.8, weight: .bold))
                            .foregroundStyle(Color.black)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(AxonTheme.emerald))
                    }
                    .buttonStyle(.plain)

                    Button {
                        state.copyAppleScript()
                    } label: {
                        Label("Script", systemImage: "applescript")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(AxonTheme.textPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.white.opacity(0.09)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var stepGraphSection: some View {
        let steps = state.activeWorkflow.steps
        if state.isPreviewSnapshot {
            VStack(spacing: 6) {
                ForEach(steps.prefix(5)) { step in
                    stepRow(step)
                }
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(steps) { step in
                        stepRow(step)
                    }
                }
            }
            .frame(maxHeight: 335)
        }
    }

    private func stepRow(_ step: MacroStep) -> some View {
        let tint = verbColor(step.action)
        return AxonGlassCard(padding: 9, cornerRadius: 11) {
            HStack(spacing: 9) {
                Text("\(step.order)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(tint)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(tint.opacity(0.16)))

                VStack(alignment: .leading, spacing: 2.5) {
                    HStack(spacing: 6) {
                        Text(step.action.verbLabel)
                            .font(.system(size: 8.8, weight: .bold, design: .monospaced))
                            .foregroundStyle(tint)
                            .padding(.horizontal, 5.5)
                            .padding(.vertical, 1.5)
                            .background(Capsule().fill(tint.opacity(0.14)))

                        Text(step.label)
                            .font(.system(size: 11.2, weight: .semibold))
                            .foregroundStyle(AxonTheme.textPrimary)
                            .lineLimit(1)
                    }

                    Text(step.action.targetSummary)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(AxonTheme.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                if let app = step.action.appName {
                    Text(app)
                        .font(.system(size: 9.2, weight: .semibold))
                        .foregroundStyle(AxonTheme.textTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(Capsule().fill(Color.white.opacity(0.06)))
                }
            }
        }
    }

    private func verbColor(_ kind: MacroActionKind) -> Color {
        switch kind {
        case .focusApp: return AxonTheme.violet
        case .click, .doubleClick, .waitForElement: return AxonTheme.amber
        case .typeText, .setClipboard: return AxonTheme.cyan
        case .keyCombo, .runAppleScript: return AxonTheme.emerald
        case .pause: return AxonTheme.textSecondary
        }
    }
}
