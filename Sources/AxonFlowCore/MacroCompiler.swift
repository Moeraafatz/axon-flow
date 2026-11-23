import Foundation

/// Compiles noisy raw desktop event streams into clean, deduplicated, parameterized semantic workflows
/// and exports portable JSON or AppleScript automation scripts.
public enum MacroCompiler {
    public static func compile(
        name: String,
        summary: String = "Compiled from live macOS semantic recording",
        rawEvents: [RawRecordedEvent],
        autoParameterize: Bool = true
    ) -> MacroWorkflow {
        var steps: [MacroStep] = []
        var typedBuffer = ""
        var lastFocusedBundle: String?
        var lastClickSelector: AXSelector?
        var lastClickTime: Double = -10.0

        func flushTypedText() {
            guard !typedBuffer.isEmpty else { return }
            let finalText = autoParameterize ? suggestTemplateIfLiteral(typedBuffer) : typedBuffer
            steps.append(MacroStep(
                order: steps.count + 1,
                label: "Type \(finalText.prefix(28))",
                action: .typeText(finalText),
                retryCount: 1,
                delayAfterMs: 80
            ))
            typedBuffer = ""
        }

        for event in rawEvents {
            switch event.kind {
            case .keyChar(let ch):
                typedBuffer += ch

            case .backspace:
                if !typedBuffer.isEmpty {
                    typedBuffer.removeLast()
                }

            case .appFocus(let bundleID, let appName):
                flushTypedText()
                if bundleID != lastFocusedBundle {
                    lastFocusedBundle = bundleID
                    steps.append(MacroStep(
                        order: steps.count + 1,
                        label: "Focus \(appName)",
                        action: .focusApp(bundleID: bundleID, appName: appName),
                        retryCount: 2,
                        delayAfterMs: 140
                    ))
                }

            case .mouseClick(let selector):
                flushTypedText()
                // Collapse rapid double-click on identical semantic selector into a single .doubleClick step
                if let prev = lastClickSelector,
                   prev == selector,
                   (event.timestampSec - lastClickTime) <= 0.38,
                   let lastIdx = steps.indices.last,
                   case .click = steps[lastIdx].action {
                    steps[lastIdx].action = .doubleClick(selector)
                    steps[lastIdx].label = "Double-click \(selector.title ?? selector.displayBadge)"
                    lastClickSelector = nil
                } else {
                    if selector.bundleID != lastFocusedBundle && !selector.bundleID.isEmpty {
                        lastFocusedBundle = selector.bundleID
                        steps.append(MacroStep(
                            order: steps.count + 1,
                            label: "Focus \(selector.appName)",
                            action: .focusApp(bundleID: selector.bundleID, appName: selector.appName),
                            retryCount: 2,
                            delayAfterMs: 120
                        ))
                    }
                    let titleLabel = selector.title ?? selector.identifier ?? selector.role
                    steps.append(MacroStep(
                        order: steps.count + 1,
                        label: "Click \(titleLabel)",
                        action: .click(selector),
                        retryCount: 2,
                        delayAfterMs: 120
                    ))
                    lastClickSelector = selector
                    lastClickTime = event.timestampSec
                }

            case .keyCombo(let key, let modifiers):
                flushTypedText()
                steps.append(MacroStep(
                    order: steps.count + 1,
                    label: "Press \((modifiers + [key]).joined(separator: "+"))",
                    action: .keyCombo(key: key, modifiers: modifiers),
                    retryCount: 1,
                    delayAfterMs: 100
                ))

            case .clipboardCopy(let value):
                flushTypedText()
                let templatized = autoParameterize ? suggestTemplateIfLiteral(value) : value
                steps.append(MacroStep(
                    order: steps.count + 1,
                    label: "Set Clipboard",
                    action: .setClipboard(templatized),
                    retryCount: 1,
                    delayAfterMs: 60
                ))
            }
        }

        flushTypedText()

        // Re-index cleanly
        for i in steps.indices {
            steps[i].order = i + 1
        }

        let vars = extractVariables(from: steps)
        return MacroWorkflow(
            name: name,
            summary: summary,
            steps: steps,
            variables: vars,
            rawEventCount: rawEvents.count
        )
    }

    public static func extractVariables(from steps: [MacroStep]) -> [String] {
        var found: [String] = []
        var seen = Set<String>()
        let pattern = #"\{\{\s*([A-Za-z0-9_]+)\s*\}\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        for step in steps {
            let candidates: [String]
            switch step.action {
            case .typeText(let s), .setClipboard(let s), .runAppleScript(let s):
                candidates = [s]
            case .click(let sel), .doubleClick(let sel), .waitForElement(let sel, _):
                candidates = [sel.title ?? "", sel.identifier ?? ""]
            default:
                candidates = []
            }
            for str in candidates {
                let nsRange = NSRange(str.startIndex..<str.endIndex, in: str)
                for match in regex.matches(in: str, range: nsRange) {
                    if let r = Range(match.range(at: 1), in: str) {
                        let name = String(str[r])
                        if seen.insert(name).inserted {
                            found.append(name)
                        }
                    }
                }
            }
        }
        return found
    }

    private static func suggestTemplateIfLiteral(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("{{") && trimmed.contains("}}") { return trimmed }
        if trimmed.range(of: #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#, options: .regularExpression) != nil {
            return "{{email}}"
        }
        if trimmed.range(of: #"^https?://\S+$"#, options: .regularExpression) != nil {
            return "{{url}}"
        }
        if trimmed.range(of: #"^INV-\d{4}-\d{3,}$"#, options: .regularExpression) != nil {
            return "{{invoice_id}}"
        }
        return text
    }

    public static func exportAppleScript(for workflow: MacroWorkflow, sampleRow: [String: String] = [:]) -> String {
        var lines: [String] = [
            "-- Generated by Axon Flow (Semantic Cross-App Macro Compiler)",
            "-- Workflow: \(workflow.name)",
            ""
        ]
        for step in workflow.steps where step.isEnabled {
            switch step.action {
            case .focusApp(_, let appName):
                lines.append("tell application \"\(escapeAS(appName))\" to activate")
            case .click(let sel):
                let target = escapeAS(sel.title ?? sel.identifier ?? sel.role)
                lines.append("tell application \"System Events\" to tell process \"\(escapeAS(sel.appName))\" to click (first UI element whose title is \"\(target)\")")
            case .doubleClick(let sel):
                let target = escapeAS(sel.title ?? sel.identifier ?? sel.role)
                lines.append("tell application \"System Events\" to tell process \"\(escapeAS(sel.appName))\" to perform action \"AXPress\" of (first UI element whose title is \"\(target)\")")
            case .typeText(let raw):
                let rendered = CSVBatchEngine.interpolate(raw, with: sampleRow)
                lines.append("tell application \"System Events\" to keystroke \"\(escapeAS(rendered))\"")
            case .keyCombo(let key, let mods):
                let usingClause = mods.isEmpty ? "" : " using {\(mods.map { "\($0.lowercased()) down" }.joined(separator: ", "))}"
                lines.append("tell application \"System Events\" to keystroke \"\(escapeAS(key))\"\(usingClause)")
            case .setClipboard(let raw):
                let rendered = CSVBatchEngine.interpolate(raw, with: sampleRow)
                lines.append("set the clipboard to \"\(escapeAS(rendered))\"")
            case .waitForElement(let sel, let timeout):
                lines.append("-- Wait up to \(Int(timeout))s for semantic target \(sel.displayBadge)")
                lines.append("delay 0.25")
            case .runAppleScript(let script):
                lines.append(CSVBatchEngine.interpolate(script, with: sampleRow))
            case .pause(let ms):
                lines.append(String(format: "delay %.2f", Double(ms) / 1000.0))
            }
        }
        return lines.joined(separator: "\n")
    }

    private static func escapeAS(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
