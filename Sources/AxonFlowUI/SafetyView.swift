import AxonFlowCore
import SwiftUI

public struct SafetyView: View {
    @Bindable var state: AxonAppState

    public init(state: AxonAppState) {
        self.state = state
    }

    public var body: some View {
        VStack(spacing: 10) {
            permissionsCard
            executionGuardsCard
            killSwitchCard
        }
    }

    private var permissionsCard: some View {
        AxonGlassCard(padding: 11, cornerRadius: 13) {
            VStack(alignment: .leading, spacing: 8) {
                Label("macOS Automation Permissions (Zero Root · Zero Cloud)", systemImage: "shield.checkered")
                    .font(.system(size: 11.2, weight: .bold))
                    .foregroundStyle(AxonTheme.textPrimary)

                permRow(
                    title: "Accessibility (AXUIElement Tree)",
                    detail: "Reads semantic identifiers/roles & performs native AXPress actions",
                    active: state.hasAccessibilityPermission,
                    action: { AXPermissionHelper.openAccessibilitySettings() }
                )
                Divider().overlay(Color.white.opacity(0.08))
                permRow(
                    title: "Input Monitoring (CGEventTap)",
                    detail: "Listens locally only while Record Task Once is explicitly active",
                    active: state.hasInputMonitoringPermission,
                    action: { AXPermissionHelper.openInputMonitoringSettings() }
                )
            }
        }
    }

    private func permRow(title: String, detail: String, active: Bool, action: @escaping () -> Void) -> some View {
        HStack(spacing: 9) {
            Circle()
                .fill(active ? AxonTheme.emerald : AxonTheme.amber)
                .frame(width: 7.5, height: 7.5)
            VStack(alignment: .leading, spacing: 1.5) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AxonTheme.textPrimary)
                Text(detail)
                    .font(.system(size: 9.5))
                    .foregroundStyle(AxonTheme.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            if active {
                Text("Granted")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(AxonTheme.emerald)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(AxonTheme.emerald.opacity(0.15)))
            } else {
                Button("Grant", action: action)
                    .buttonStyle(.plain)
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(Capsule().fill(AxonTheme.amber))
            }
        }
    }

    private var executionGuardsCard: some View {
        AxonGlassCard(padding: 11, cornerRadius: 13) {
            VStack(spacing: 9) {
                guardToggleRow(
                    title: "Dry-Run Verification Guard",
                    detail: "Resolves every AX selector & prints match trace without clicking",
                    isOn: state.safetyConfig.dryRunGuard,
                    accent: AxonTheme.cyan
                ) {
                    state.safetyConfig.dryRunGuard.toggle()
                }

                Divider().overlay(Color.white.opacity(0.08))

                guardToggleRow(
                    title: "Abort Batch on First Selector Miss",
                    detail: "Halts CSV replay immediately instead of skipping unresolved rows",
                    isOn: state.safetyConfig.abortOnFirstRowError,
                    accent: AxonTheme.amber
                ) {
                    state.safetyConfig.abortOnFirstRowError.toggle()
                }
            }
        }
    }

    private func guardToggleRow(title: String, detail: String, isOn: Bool, accent: Color, action: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AxonTheme.textPrimary)
                Text(detail)
                    .font(.system(size: 9.5))
                    .foregroundStyle(AxonTheme.textSecondary)
            }
            Spacer()
            AxonTogglePill(isOn: isOn, accent: accent, action: action)
        }
    }

    private var killSwitchCard: some View {
        AxonGlassCard(padding: 10, cornerRadius: 13, borderColor: AxonTheme.rose.opacity(0.32)) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Emergency Kill Switch: Esc or ⌘.")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AxonTheme.rose)
                    Text("Cancels active macro playback immediately · Zero cloud sync")
                        .font(.system(size: 9.5))
                        .foregroundStyle(AxonTheme.textSecondary)
                }
                Spacer()
                Button {
                    state.wipeLibrary()
                } label: {
                    Label("Reset DB", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(AxonTheme.rose.opacity(0.75)))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
