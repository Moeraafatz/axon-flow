import Foundation

public struct BatchPreflightResult: Sendable, Equatable {
    public let requiredVariables: [String]
    public let missingColumns: [String]
    public let rowCount: Int

    public var isReady: Bool { missingColumns.isEmpty && rowCount > 0 }

    public init(requiredVariables: [String], missingColumns: [String], rowCount: Int) {
        self.requiredVariables = requiredVariables
        self.missingColumns = missingColumns
        self.rowCount = rowCount
    }
}

public struct BatchRunSummary: Sendable {
    public let totalRows: Int
    public let succeededRows: Int
    public let failedRows: Int
    public let totalDurationMs: Double
    public let traces: [RowExecutionTrace]

    public var successRatePercent: Double {
        guard totalRows > 0 else { return 0 }
        return (Double(succeededRows) / Double(totalRows)) * 100.0
    }

    public init(
        totalRows: Int,
        succeededRows: Int,
        failedRows: Int,
        totalDurationMs: Double,
        traces: [RowExecutionTrace]
    ) {
        self.totalRows = totalRows
        self.succeededRows = succeededRows
        self.failedRows = failedRows
        self.totalDurationMs = totalDurationMs
        self.traces = traces
    }
}

public enum CSVBatchEngine {
    /// RFC-4180 compliant CSV parser handling quoted fields, embedded commas, escaped quotes (""), and CRLF/LF.
    public static func parse(_ rawCSV: String, fileName: String = "batch.csv") -> CSVDataset {
        let stripped = rawCSV.hasPrefix("\u{FEFF}") ? String(rawCSV.dropFirst()) : rawCSV
        let matrix = parseRows(stripped)
        guard let headerRow = matrix.first else {
            return CSVDataset(fileName: fileName, headers: [], rows: [])
        }
        let headers = headerRow.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        var rows: [[String: String]] = []
        rows.reserveCapacity(max(0, matrix.count - 1))

        for rowValues in matrix.dropFirst() {
            if rowValues.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                continue
            }
            var dict: [String: String] = [:]
            for (idx, header) in headers.enumerated() where !header.isEmpty {
                dict[header] = idx < rowValues.count ? rowValues[idx] : ""
            }
            rows.append(dict)
        }
        return CSVDataset(fileName: fileName, headers: headers, rows: rows)
    }

    public static func preflight(workflow: MacroWorkflow, dataset: CSVDataset) -> BatchPreflightResult {
        let required = workflow.variables.isEmpty ? MacroCompiler.extractVariables(from: workflow.steps) : workflow.variables
        let headerSet = Set(dataset.headers)
        let missing = required.filter { !headerSet.contains($0) }
        return BatchPreflightResult(
            requiredVariables: required,
            missingColumns: missing,
            rowCount: dataset.rows.count
        )
    }

    public static func interpolate(_ template: String, with row: [String: String]) -> String {
        guard template.contains("{{") else { return template }
        var output = template
        for (key, value) in row {
            output = output.replacingOccurrences(of: "{{\(key)}}", with: value)
            output = output.replacingOccurrences(of: "{{ \(key) }}", with: value)
        }
        return output
    }

    public static func instantiateSteps(for workflow: MacroWorkflow, row: [String: String]) -> [MacroStep] {
        workflow.steps.filter(\.isEnabled).map { step in
            var copy = step
            switch step.action {
            case .typeText(let s):
                copy.action = .typeText(interpolate(s, with: row))
            case .setClipboard(let s):
                copy.action = .setClipboard(interpolate(s, with: row))
            case .runAppleScript(let s):
                copy.action = .runAppleScript(interpolate(s, with: row))
            case .click(let sel):
                copy.action = .click(interpolateSelector(sel, with: row))
            case .doubleClick(let sel):
                copy.action = .doubleClick(interpolateSelector(sel, with: row))
            case .waitForElement(let sel, let timeout):
                copy.action = .waitForElement(interpolateSelector(sel, with: row), timeoutSec: timeout)
            default:
                break
            }
            return copy
        }
    }

    /// Simulates or validates an entire CSV batch run against a target Accessibility snapshot tree.
    public static func runSimulatedBatch(
        workflow: MacroWorkflow,
        dataset: CSVDataset,
        axTree: [AXSnapshotNode],
        maxTracesStored: Int = 50
    ) -> BatchRunSummary {
        let start = CFAbsoluteTimeGetCurrent()
        var succeeded = 0
        var failed = 0
        var traces: [RowExecutionTrace] = []
        traces.reserveCapacity(min(dataset.rows.count, maxTracesStored))

        let primaryCol = dataset.headers.first ?? ""
        for (idx, row) in dataset.rows.enumerated() {
            let rowStart = CFAbsoluteTimeGetCurrent()
            let steps = instantiateSteps(for: workflow, row: row)
            var rowOK = true
            var rowError: String?
            var dominantStrategy: SelectorStrategy = .identifier

            for step in steps {
                switch step.action {
                case .click(let sel), .doubleClick(let sel), .waitForElement(let sel, _):
                    if let match = SemanticMatcher.resolve(selector: sel, in: axTree) {
                        dominantStrategy = match.strategy
                    } else {
                        rowOK = false
                        rowError = "Unresolved selector: \(sel.displayBadge)"
                    }
                default:
                    break
                }
                if !rowOK { break }
            }

            let rowMs = (CFAbsoluteTimeGetCurrent() - rowStart) * 1000.0
            if rowOK { succeeded += 1 } else { failed += 1 }

            if traces.count < maxTracesStored {
                let label = row[primaryCol].flatMap { $0.isEmpty ? nil : $0 } ?? "Row #\(idx + 1)"
                traces.append(RowExecutionTrace(
                    rowIndex: idx + 1,
                    primaryLabel: label,
                    stepsExecuted: steps.count,
                    strategyUsed: dominantStrategy,
                    durationMs: rowMs,
                    succeeded: rowOK,
                    errorMessage: rowError
                ))
            }
        }

        let totalMs = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
        return BatchRunSummary(
            totalRows: dataset.rows.count,
            succeededRows: succeeded,
            failedRows: failed,
            totalDurationMs: totalMs,
            traces: traces
        )
    }

    private static func interpolateSelector(_ sel: AXSelector, with row: [String: String]) -> AXSelector {
        AXSelector(
            bundleID: sel.bundleID,
            appName: sel.appName,
            role: sel.role,
            subrole: sel.subrole,
            identifier: sel.identifier.map { interpolate($0, with: row) },
            title: sel.title.map { interpolate($0, with: row) },
            helpText: sel.helpText.map { interpolate($0, with: row) },
            ancestorRoles: sel.ancestorRoles,
            siblingIndex: sel.siblingIndex,
            recordedScreenPoint: sel.recordedScreenPoint
        )
    }

    private static func parseRows(_ input: String) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var field = ""
        var inQuotes = false
        let chars = Array(input)
        var i = 0

        while i < chars.count {
            let ch = chars[i]
            if inQuotes {
                if ch == "\"" {
                    if i + 1 < chars.count && chars[i + 1] == "\"" {
                        field.append("\"")
                        i += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(ch)
                }
            } else {
                if ch == "\"" {
                    inQuotes = true
                } else if ch == "," {
                    currentRow.append(field)
                    field = ""
                } else if ch == "\r" {
                    if i + 1 < chars.count && chars[i + 1] == "\n" { i += 1 }
                    currentRow.append(field)
                    rows.append(currentRow)
                    currentRow = []
                    field = ""
                } else if ch == "\n" {
                    currentRow.append(field)
                    rows.append(currentRow)
                    currentRow = []
                    field = ""
                } else {
                    field.append(ch)
                }
            }
            i += 1
        }

        if !field.isEmpty || !currentRow.isEmpty {
            currentRow.append(field)
            rows.append(currentRow)
        }
        return rows
    }
}
