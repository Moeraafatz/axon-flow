import AppKit
import AxonFlowCore
import AxonFlowUI
import SwiftUI

@main
struct AxonFlowApp: App {
    @State private var appState: AxonAppState
    @State private var hudController: FloatingAxonHUD?

    init() {
        let store = try? WorkflowStore()
        let state = AxonAppState(store: store, isPreviewSnapshot: false)
        _appState = State(initialValue: state)
        _hudController = State(initialValue: FloatingAxonHUD(state: state))
    }

    var body: some Scene {
        MenuBarExtra {
            RootAxonView(state: appState, width: 510)
                .task {
                    await appState.bootstrap()
                }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: appState.isRecording ? "record.circle.fill" : "point.3.connected.trianglepath.dotted")
                if appState.isRecording {
                    Text("\(appState.recordedEventsBuffer.count)")
                        .font(.system(size: 11, design: .monospaced))
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}
