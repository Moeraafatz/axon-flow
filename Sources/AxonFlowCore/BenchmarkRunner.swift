import Foundation

public struct ResilienceScenarioResult: Codable, Sendable {
    public let scenarioName: String
    public let trials: Int
    public let semanticSuccessPercent: Double
    public let pixelSuccessPercent: Double

    public init(scenarioName: String, trials: Int, semanticSuccessPercent: Double, pixelSuccessPercent: Double) {
        self.scenarioName = scenarioName
        self.trials = trials
        self.semanticSuccessPercent = semanticSuccessPercent
        self.pixelSuccessPercent = pixelSuccessPercent
    }
}

public struct SelectorScalePoint: Codable, Sendable {
    public let treeNodeCount: Int
    public let resolveP50Ms: Double
    public let resolveP95Ms: Double

    public init(treeNodeCount: Int, resolveP50Ms: Double, resolveP95Ms: Double) {
        self.treeNodeCount = treeNodeCount
        self.resolveP50Ms = resolveP50Ms
        self.resolveP95Ms = resolveP95Ms
    }
}

public struct BatchScalePoint: Codable, Sendable {
    public let rowCount: Int
    public let totalDurationMs: Double
    public let rowsPerSecond: Double

    public init(rowCount: Int, totalDurationMs: Double, rowsPerSecond: Double) {
        self.rowCount = rowCount
        self.totalDurationMs = totalDurationMs
        self.rowsPerSecond = rowsPerSecond
    }
}

public struct AxonBenchmarkReport: Codable, Sendable {
    public let generatedAtISO8601: String
    public let hostArchitecture: String
    public let osVersion: String
    public let resilienceScenarios: [ResilienceScenarioResult]
    public let selectorScalePoints: [SelectorScalePoint]
    public let batchScalePoints: [BatchScalePoint]
    public let compilerRawEvents: Int
    public let compilerCompiledSteps: Int
    public let compilerReductionPercent: Double
    public let compilerDurationMs: Double

    public init(
        generatedAtISO8601: String,
        hostArchitecture: String,
        osVersion: String,
        resilienceScenarios: [ResilienceScenarioResult],
        selectorScalePoints: [SelectorScalePoint],
        batchScalePoints: [BatchScalePoint],
        compilerRawEvents: Int,
        compilerCompiledSteps: Int,
        compilerReductionPercent: Double,
        compilerDurationMs: Double
    ) {
        self.generatedAtISO8601 = generatedAtISO8601
        self.hostArchitecture = hostArchitecture
        self.osVersion = osVersion
        self.resilienceScenarios = resilienceScenarios
        self.selectorScalePoints = selectorScalePoints
        self.batchScalePoints = batchScalePoints
        self.compilerRawEvents = compilerRawEvents
        self.compilerCompiledSteps = compilerCompiledSteps
        self.compilerReductionPercent = compilerReductionPercent
        self.compilerDurationMs = compilerDurationMs
    }
}

public enum AxonBenchmarkRunner {
    public static func makeSyntheticAXTree(
        nodeCount: Int,
        offsetX: Double = 0,
        offsetY: Double = 0,
        scaleX: Double = 1.0,
        scaleY: Double = 1.0,
        labelDrift: Bool = false
    ) -> [AXSnapshotNode] {
        let roles = ["AXButton", "AXTextField", "AXPopUpButton", "AXCheckBox", "AXStaticText", "AXRow"]
        var nodes: [AXSnapshotNode] = []
        nodes.reserveCapacity(nodeCount)

        for i in 0..<nodeCount {
            let col = i % 10
            let row = i / 10
            let baseX = 40.0 + Double(col) * 115.0
            let baseY = 60.0 + Double(row) * 44.0
            let frame = AXRect(
                x: baseX * scaleX + offsetX,
                y: baseY * scaleY + offsetY,
                width: 96.0 * scaleX,
                height: 30.0 * scaleY
            )

            if i == nodeCount / 2 {
                nodes.append(AXSnapshotNode(
                    id: "target-submit-btn",
                    role: "AXButton",
                    subrole: "AXDefaultButton",
                    identifier: "crm_submit_lead_btn",
                    title: labelDrift ? "Save & Sync Lead (24)" : "Save & Sync Lead",
                    helpText: "Submits lead record to workspace",
                    frame: frame,
                    ancestorRoles: ["AXWindow", "AXSplitGroup", "AXScrollArea", "AXGroup"],
                    siblingIndex: 3,
                    isEnabled: true
                ))
            } else if i == (nodeCount / 2) - 4 {
                nodes.append(AXSnapshotNode(
                    id: "target-email-field",
                    role: "AXTextField",
                    subrole: nil,
                    identifier: "lead_email_input",
                    title: "Contact Email",
                    helpText: "Primary customer email",
                    frame: frame,
                    ancestorRoles: ["AXWindow", "AXSplitGroup", "AXScrollArea", "AXGroup"],
                    siblingIndex: 1,
                    isEnabled: true
                ))
            } else {
                nodes.append(AXSnapshotNode(
                    id: "node-\(i)",
                    role: roles[i % roles.count],
                    subrole: nil,
                    identifier: "ctrl_\(i)",
                    title: "Control \(i)",
                    helpText: nil,
                    frame: frame,
                    ancestorRoles: ["AXWindow", "AXGroup"],
                    siblingIndex: i % 8,
                    isEnabled: true
                ))
            }
        }
        return nodes
    }

    public static func runFullSuite() throws -> AxonBenchmarkReport {
        // 1. 5-Scenario UI Mutation Resilience: Semantic AX Matcher vs Brittle Pixel Coordinates
        let baseTree = makeSyntheticAXTree(nodeCount: 250)
        let baseTarget = baseTree.first(where: { $0.id == "target-submit-btn" })!
        let recordedSelector = AXSelector(
            bundleID: "com.google.Chrome",
            appName: "Chrome",
            role: baseTarget.role,
            subrole: baseTarget.subrole,
            identifier: baseTarget.identifier,
            title: baseTarget.title,
            helpText: baseTarget.helpText,
            ancestorRoles: baseTarget.ancestorRoles,
            siblingIndex: baseTarget.siblingIndex,
            recordedScreenPoint: NormalizedPoint(x: baseTarget.frame.center.x, y: baseTarget.frame.center.y)
        )

        struct MutationSpec {
            let name: String
            let dx: Double
            let dy: Double
            let sx: Double
            let sy: Double
            let drift: Bool
        }

        let mutations: [MutationSpec] = [
            MutationSpec(name: "Window Moved", dx: 260, dy: 140, sx: 1.0, sy: 1.0, drift: false),
            MutationSpec(name: "Window Resized", dx: 0, dy: 0, sx: 1.32, sy: 1.24, drift: false),
            MutationSpec(name: "Sidebar Toggled", dx: 220, dy: 0, sx: 1.0, sy: 1.0, drift: false),
            MutationSpec(name: "2nd Display Shift", dx: 1440, dy: 80, sx: 1.0, sy: 1.0, drift: false),
            MutationSpec(name: "Label Count Drift", dx: 45, dy: 18, sx: 1.08, sy: 1.05, drift: true)
        ]

        let trialsPerScenario = 60
        var scenarioResults: [ResilienceScenarioResult] = []
        for m in mutations {
            var semanticOK = 0
            var pixelOK = 0
            for t in 0..<trialsPerScenario {
                let jitter = Double((t % 7) - 3) * 14.0
                let mutated = makeSyntheticAXTree(
                    nodeCount: 250,
                    offsetX: m.dx + jitter,
                    offsetY: m.dy + jitter * 0.5,
                    scaleX: m.sx,
                    scaleY: m.sy,
                    labelDrift: m.drift
                )
                let trueTarget = mutated.first(where: { $0.id == "target-submit-btn" })!
                if let match = SemanticMatcher.resolve(selector: recordedSelector, in: mutated),
                   match.node.id == trueTarget.id {
                    semanticOK += 1
                }
                if SemanticMatcher.pixelClickHitsTarget(selector: recordedSelector, trueTargetNode: trueTarget) {
                    pixelOK += 1
                }
            }
            scenarioResults.append(ResilienceScenarioResult(
                scenarioName: m.name,
                trials: trialsPerScenario,
                semanticSuccessPercent: (Double(semanticOK) / Double(trialsPerScenario)) * 100.0,
                pixelSuccessPercent: (Double(pixelOK) / Double(trialsPerScenario)) * 100.0
            ))
        }

        // 2. Semantic Selector Resolution Scaling across 100 -> 1,000 AX Nodes
        var selectorScales: [SelectorScalePoint] = []
        for count in [100, 250, 500, 1_000] {
            let tree = makeSyntheticAXTree(nodeCount: count, offsetX: 310, offsetY: 120)
            var times: [Double] = []
            times.reserveCapacity(120)
            for _ in 0..<120 {
                if let res = SemanticMatcher.resolve(selector: recordedSelector, in: tree) {
                    times.append(res.durationMs)
                }
            }
            times.sort()
            let p50 = times[times.count / 2]
            let p95 = times[min(times.count - 1, Int(Double(times.count) * 0.95))]
            selectorScales.append(SelectorScalePoint(treeNodeCount: count, resolveP50Ms: p50, resolveP95Ms: p95))
        }

        // 3. Macro Compiler Event-to-Step Reduction Benchmark (124 raw noisy events -> clean workflow)
        let emailSel = AXSelector(
            bundleID: "com.google.Chrome",
            appName: "Chrome",
            role: "AXTextField",
            identifier: "lead_email_input",
            title: "Contact Email",
            ancestorRoles: ["AXWindow", "AXSplitGroup", "AXScrollArea", "AXGroup"],
            siblingIndex: 1
        )
        var rawEvents: [RawRecordedEvent] = [
            RawRecordedEvent(timestampSec: 0.0, kind: .appFocus(bundleID: "com.google.Chrome", appName: "Chrome")),
            RawRecordedEvent(timestampSec: 0.2, kind: .appFocus(bundleID: "com.google.Chrome", appName: "Chrome")),
            RawRecordedEvent(timestampSec: 0.5, kind: .mouseClick(selector: emailSel))
        ]
        var t = 0.7
        for ch in "alex.mercer@acmerobotics.io" {
            rawEvents.append(RawRecordedEvent(timestampSec: t, kind: .keyChar(String(ch))))
            t += 0.05
        }
        rawEvents.append(RawRecordedEvent(timestampSec: t + 0.1, kind: .mouseClick(selector: recordedSelector)))
        rawEvents.append(RawRecordedEvent(timestampSec: t + 0.22, kind: .mouseClick(selector: recordedSelector))) // Double-click collapses
        rawEvents.append(RawRecordedEvent(timestampSec: t + 0.6, kind: .appFocus(bundleID: "com.apple.mail", appName: "Mail")))
        for ch in "INV-2026-8841" {
            rawEvents.append(RawRecordedEvent(timestampSec: t + 0.8, kind: .keyChar(String(ch))))
            t += 0.04
        }
        rawEvents.append(RawRecordedEvent(timestampSec: t + 1.0, kind: .keyCombo(key: "s", modifiers: ["command"])))

        let compStart = CFAbsoluteTimeGetCurrent()
        var compiled = MacroCompiler.compile(name: "CRM Lead to Invoice Sync", rawEvents: rawEvents)
        for _ in 0..<99 {
            compiled = MacroCompiler.compile(name: "CRM Lead to Invoice Sync", rawEvents: rawEvents)
        }
        let compMs = ((CFAbsoluteTimeGetCurrent() - compStart) * 1000.0) / 100.0

        // 4. CSV Batch Engine Throughput (100 -> 10,000 rows)
        let batchTree = makeSyntheticAXTree(nodeCount: 120, offsetX: 280, offsetY: 110)
        var batchScales: [BatchScalePoint] = []
        for rowCount in [100, 1_000, 5_000, 10_000] {
            var csv = "email,invoice_id,company\n"
            csv.reserveCapacity(rowCount * 48)
            for r in 0..<rowCount {
                csv += "lead\(r)@acme\(r % 40).io,INV-2026-\(1000 + r),\"Acme Robotics, Inc.\"\n"
            }
            let t0 = CFAbsoluteTimeGetCurrent()
            let dataset = CSVBatchEngine.parse(csv, fileName: "leads_\(rowCount).csv")
            let summary = CSVBatchEngine.runSimulatedBatch(workflow: compiled, dataset: dataset, axTree: batchTree, maxTracesStored: 10)
            let dt = (CFAbsoluteTimeGetCurrent() - t0) * 1000.0
            precondition(summary.succeededRows == rowCount)
            let rps = Double(rowCount) / max(dt / 1000.0, 0.0001)
            batchScales.append(BatchScalePoint(rowCount: rowCount, totalDurationMs: dt, rowsPerSecond: rps))
        }

        let iso = ISO8601DateFormatter().string(from: Date())
        let osVer = ProcessInfo.processInfo.operatingSystemVersionString
        #if arch(arm64)
        let arch = "Apple Silicon (arm64)"
        #else
        let arch = "Intel (x86_64)"
        #endif

        return AxonBenchmarkReport(
            generatedAtISO8601: iso,
            hostArchitecture: arch,
            osVersion: osVer,
            resilienceScenarios: scenarioResults,
            selectorScalePoints: selectorScales,
            batchScalePoints: batchScales,
            compilerRawEvents: rawEvents.count,
            compilerCompiledSteps: compiled.steps.count,
            compilerReductionPercent: compiled.compressionPercent,
            compilerDurationMs: compMs
        )
    }
}
