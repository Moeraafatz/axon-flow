import AppKit
@preconcurrency import ApplicationServices
import CoreGraphics
import Foundation

public enum AXPermissionHelper {
    public static func hasAccessibilityPermission() -> Bool {
        AXIsProcessTrusted()
    }

    public static func hasInputMonitoringPermission() -> Bool {
        CGPreflightListenEventAccess()
    }

    public static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    public static func openInputMonitoringSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }
}

private enum EventTapTrampoline {
    nonisolated(unsafe) static var handler: (@Sendable (CGEventType, CGEvent) -> Void)?
}

private func globalRecordEventCallback(
    _ proxy: CGEventTapProxy,
    _ type: CGEventType,
    _ event: CGEvent,
    _ refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    EventTapTrampoline.handler?(type, event)
    return Unmanaged.passUnretained(event)
}

/// Live macOS Accessibility & CGEventTap recorder + semantic executor.
/// Uses standard user-space Accessibility API — zero root, zero kernel extensions.
@MainActor
public final class LiveAXBridge {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var recordingStart: CFAbsoluteTime = 0
    private var onRecordedEvent: ((RawRecordedEvent) -> Void)?

    public init() {}

    public func startRecording(onEvent: @escaping (RawRecordedEvent) -> Void) -> Bool {
        guard AXPermissionHelper.hasAccessibilityPermission() else { return false }
        stopRecording()
        self.onRecordedEvent = onEvent
        self.recordingStart = CFAbsoluteTimeGetCurrent()

        let mask: CGEventMask =
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.keyDown.rawValue)

        EventTapTrampoline.handler = { [weak self] type, event in
            let loc = event.location
            let flags = event.flags
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            var unicodeLength = 0
            var chars = [UniChar](repeating: 0, count: 4)
            event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &unicodeLength, unicodeString: &chars)
            let typedString = unicodeLength > 0 ? String(utf16CodeUnits: Array(chars.prefix(unicodeLength)), count: unicodeLength) : ""

            Task { @MainActor [weak self] in
                self?.processEvent(type: type, location: loc, keyCode: keyCode, flags: flags, typed: typedString)
            }
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: globalRecordEventCallback,
            userInfo: nil
        ) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.eventTap = tap
        self.runLoopSource = source
        return true
    }

    public func stopRecording() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), src, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        EventTapTrampoline.handler = nil
    }

    private func processEvent(type: CGEventType, location: CGPoint, keyCode: Int64, flags: CGEventFlags, typed: String) {
        let elapsed = CFAbsoluteTimeGetCurrent() - recordingStart
        if type == .leftMouseDown {
            if let selector = Self.captureSemanticSelector(at: location) {
                onRecordedEvent?(RawRecordedEvent(timestampSec: elapsed, kind: .mouseClick(selector: selector)))
            }
        } else if type == .keyDown {
            if keyCode == 51 { // Backspace
                onRecordedEvent?(RawRecordedEvent(timestampSec: elapsed, kind: .backspace))
                return
            }
            var mods: [String] = []
            if flags.contains(.maskCommand) { mods.append("command") }
            if flags.contains(.maskControl) { mods.append("control") }
            if flags.contains(.maskAlternate) { mods.append("option") }
            if !mods.isEmpty && !typed.isEmpty {
                onRecordedEvent?(RawRecordedEvent(timestampSec: elapsed, kind: .keyCombo(key: typed.lowercased(), modifiers: mods)))
            } else if !typed.isEmpty && keyCode != 36 && keyCode != 53 {
                onRecordedEvent?(RawRecordedEvent(timestampSec: elapsed, kind: .keyChar(typed)))
            }
        }
    }

    public static func captureSemanticSelector(at point: CGPoint) -> AXSelector? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appName = app.localizedName ?? "App"
        let bundleID = app.bundleIdentifier ?? ""

        let sysWide = AXUIElementCreateSystemWide()
        var elementRef: AXUIElement?
        let status = AXUIElementCopyElementAtPosition(sysWide, Float(point.x), Float(point.y), &elementRef)
        guard status == .success, let element = elementRef else {
            return AXSelector(
                bundleID: bundleID,
                appName: appName,
                role: "AXUnknown",
                recordedScreenPoint: NormalizedPoint(x: Double(point.x), y: Double(point.y))
            )
        }

        let role = copyStringAttr(element, kAXRoleAttribute) ?? "AXUIElement"
        let subrole = copyStringAttr(element, kAXSubroleAttribute)
        let identifier = copyStringAttr(element, kAXIdentifierAttribute)
        let title = copyStringAttr(element, kAXTitleAttribute) ?? copyStringAttr(element, kAXDescriptionAttribute)
        let help = copyStringAttr(element, kAXHelpAttribute)

        var ancestors: [String] = []
        var cursor: AXUIElement? = element
        for _ in 0..<5 {
            guard let cur = cursor else { break }
            var parentRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(cur, kAXParentAttribute as CFString, &parentRef) == .success,
               let rawParent = parentRef {
                let parentEl = rawParent as! AXUIElement
                if let pRole = copyStringAttr(parentEl, kAXRoleAttribute) {
                    ancestors.insert(pRole, at: 0)
                }
                cursor = parentEl
            } else {
                break
            }
        }

        return AXSelector(
            bundleID: bundleID,
            appName: appName,
            role: role,
            subrole: subrole,
            identifier: identifier,
            title: title,
            helpText: help,
            ancestorRoles: ancestors,
            siblingIndex: 0,
            recordedScreenPoint: NormalizedPoint(x: Double(point.x), y: Double(point.y))
        )
    }

    public static func executeLiveStep(_ step: MacroStep, dryRun: Bool) -> Bool {
        if dryRun { return true }
        switch step.action {
        case .focusApp(let bundleID, _):
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
                return app.activate(options: [])
            }
            return false
        case .setClipboard(let text):
            NSPasteboard.general.clearContents()
            return NSPasteboard.general.setString(text, forType: .string)
        case .runAppleScript(let source):
            var errorDict: NSDictionary?
            let script = NSAppleScript(source: source)
            script?.executeAndReturnError(&errorDict)
            return errorDict == nil
        case .pause(let ms):
            usleep(useconds_t(max(0, ms) * 1000))
            return true
        case .click(let sel), .doubleClick(let sel):
            let pt = CGPoint(x: sel.recordedScreenPoint.x, y: sel.recordedScreenPoint.y)
            guard let src = CGEventSource(stateID: .hidSystemState),
                  let down = CGEvent(mouseEventSource: src, mouseType: .leftMouseDown, mouseCursorPosition: pt, mouseButton: .left),
                  let up = CGEvent(mouseEventSource: src, mouseType: .leftMouseUp, mouseCursorPosition: pt, mouseButton: .left) else {
                return false
            }
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
            return true
        case .typeText(let text):
            guard let src = CGEventSource(stateID: .hidSystemState) else { return false }
            let utf16 = Array(text.utf16)
            for unit in utf16 {
                var ch = unit
                if let down = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: true),
                   let up = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: false) {
                    down.keyboardSetUnicodeString(stringLength: 1, unicodeString: &ch)
                    up.keyboardSetUnicodeString(stringLength: 1, unicodeString: &ch)
                    down.post(tap: .cghidEventTap)
                    up.post(tap: .cghidEventTap)
                }
            }
            return true
        case .keyCombo, .waitForElement:
            return true
        }
    }

    private static func copyStringAttr(_ element: AXUIElement, _ attr: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attr as CFString, &value) == .success,
              let str = value as? String, !str.isEmpty else {
            return nil
        }
        return str
    }
}
