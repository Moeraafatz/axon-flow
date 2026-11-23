import AppKit
import AxonFlowUI
@preconcurrency import Carbon
import SwiftUI

private enum AxonHotKeyTrampoline {
    nonisolated(unsafe) static var handler: (@Sendable () -> Void)?
}

private func axonHotKeyCallback(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    AxonHotKeyTrampoline.handler?()
    return noErr
}

@MainActor
final class FloatingAxonHUD {
    private var panel: NSPanel?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let state: AxonAppState

    init(state: AxonAppState) {
        self.state = state
        registerGlobalHotKey()
    }

    func toggle() {
        if let panel, panel.isVisible {
            panel.orderOut(nil)
            return
        }
        show()
    }

    func show() {
        if panel == nil {
            let hosting = NSHostingView(rootView: RootAxonView(state: state, width: 520))
            let newPanel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 620),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            newPanel.isFloatingPanel = true
            newPanel.level = .floating
            newPanel.backgroundColor = .clear
            newPanel.isOpaque = false
            newPanel.hasShadow = true
            newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            newPanel.isMovableByWindowBackground = true
            newPanel.contentView = hosting
            panel = newPanel
        }

        guard let panel else { return }
        if let screen = NSScreen.main ?? NSScreen.screens.first {
            let visible = screen.visibleFrame
            let size = panel.frame.size
            let x = visible.midX - size.width / 2
            let y = visible.maxY - size.height - 90
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private func registerGlobalHotKey() {
        AxonHotKeyTrampoline.handler = { [weak self] in
            Task { @MainActor [weak self] in
                self?.toggle()
            }
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            axonHotKeyCallback,
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )

        // Option + Shift + K (non-overlapping with Glass Recall ⌥Space and Quiet Brief ⌥⇧M)
        let hotKeyID = EventHotKeyID(signature: OSType(0x41584F4E), id: 1) // "AXON"
        RegisterEventHotKey(
            UInt32(kVK_ANSI_K),
            UInt32(optionKey | shiftKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }
}
