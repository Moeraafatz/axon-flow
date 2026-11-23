import AppKit
import AxonFlowCore
import SwiftUI

public struct RootAxonView: View {
    @Bindable var state: AxonAppState
    public let width: CGFloat

    public init(state: AxonAppState, width: CGFloat = 510) {
        self.state = state
        self.width = width
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            backgroundLayer

            VStack(spacing: 11) {
                headerBar
                tabBar

                Group {
                    switch state.selectedTab {
                    case .studio:
                        StudioView(state: state)
                    case .batch:
                        BatchView(state: state)
                    case .library:
                        LibraryView(state: state)
                    case .safety:
                        SafetyView(state: state)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)

                footerBar
            }
            .padding(14)

            if let toast = state.statusToast {
                Text(toast)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(AxonTheme.amber))
                    .padding(.bottom, 16)
            }
        }
        .frame(width: width)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(AxonTheme.cardBorderStrong, lineWidth: 1)
        )
        .preferredColorScheme(.dark)
    }

    private var backgroundLayer: some View {
        ZStack {
            LinearGradient(
                colors: [AxonTheme.canvasTop, AxonTheme.canvasBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [AxonTheme.amber.opacity(0.16), Color.clear],
                center: .topLeading,
                startRadius: 10,
                endRadius: 340
            )
            RadialGradient(
                colors: [AxonTheme.cyan.opacity(0.13), Color.clear],
                center: .bottomTrailing,
                startRadius: 10,
                endRadius: 310
            )
        }
    }

    private var headerBar: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [AxonTheme.amber.opacity(0.32), AxonTheme.cyan.opacity(0.24)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(AxonTheme.amber.opacity(0.55), lineWidth: 1)
                    )
                    .frame(width: 30, height: 30)
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AxonTheme.amber)
            }

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text("Axon Flow")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AxonTheme.textPrimary)
                    Text("v1.0.0")
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AxonTheme.textTertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Capsule().fill(Color.white.opacity(0.07)))
                }
                Text("Semantic Cross-App Macro Compiler · AX Tree Engine")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AxonTheme.textSecondary)
            }

            Spacer()

            HStack(spacing: 5) {
                Circle()
                    .fill(state.isRecording ? AxonTheme.rose : AxonTheme.emerald)
                    .frame(width: 7, height: 7)
                Text(state.isRecording ? "RECORDING" : "AX READY")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(state.isRecording ? AxonTheme.rose : AxonTheme.emerald)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill((state.isRecording ? AxonTheme.rose : AxonTheme.emerald).opacity(0.14))
                    .overlay(Capsule().strokeBorder((state.isRecording ? AxonTheme.rose : AxonTheme.emerald).opacity(0.32), lineWidth: 0.75))
            )
        }
    }

    private var tabBar: some View {
        let tabs = AxonTab.allCases
        return HStack(spacing: 5) {
            ForEach(Array(tabs.enumerated()), id: \.element.id) { index, tab in
                let active = state.selectedTab == tab
                Button {
                    state.selectedTab = tab
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 10.5, weight: .semibold))
                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: active ? .bold : .medium))
                        Text(tab.shortcut)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(active ? Color.black.opacity(0.65) : AxonTheme.textTertiary)
                    }
                    .foregroundStyle(active ? Color.black : AxonTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6.5)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(active ? AxonTheme.textPrimary : Color.white.opacity(0.055))
                    )
                }
                .buttonStyle(.plain)
                .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.black.opacity(0.32))
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private var footerBar: some View {
        HStack(spacing: 9) {
            Text("⌥⇧K Toggle HUD")
                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                .foregroundStyle(AxonTheme.textTertiary)
            Text("·")
                .foregroundStyle(AxonTheme.textTertiary)
            Text("Window-Move Immune")
                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                .foregroundStyle(AxonTheme.amber)
            Spacer()
            Text("100% Local")
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(AxonTheme.emerald)
            if !state.isPreviewSnapshot {
                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(AxonTheme.textTertiary)
            }
        }
        .padding(.top, 2)
    }
}
