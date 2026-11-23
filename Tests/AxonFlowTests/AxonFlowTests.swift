import AxonFlowCore
import Foundation
import XCTest

final class AxonFlowTests: XCTestCase {
    func testSemanticMatcherSurvivesWindowMoveResizeAndLabelDrift() throws {
        let baseTree = AxonBenchmarkRunner.makeSyntheticAXTree(nodeCount: 200)
        let target = try XCTUnwrap(baseTree.first(where: { $0.id == "target-submit-btn" }))
        let selector = AXSelector(
            bundleID: "com.google.Chrome",
            appName: "Chrome",
            role: target.role,
            subrole: target.subrole,
            identifier: target.identifier,
            title: target.title,
            helpText: target.helpText,
            ancestorRoles: target.ancestorRoles,
            siblingIndex: target.siblingIndex,
            recordedScreenPoint: NormalizedPoint(x: target.frame.center.x, y: target.frame.center.y)
        )

        // Move window +420px right, +190px down, scale 1.3x, and drift button count label
        let mutatedTree = AxonBenchmarkRunner.makeSyntheticAXTree(
            nodeCount: 200,
            offsetX: 420,
            offsetY: 190,
            scaleX: 1.3,
            scaleY: 1.25,
            labelDrift: true
        )
        let movedTarget = try XCTUnwrap(mutatedTree.first(where: { $0.id == "target-submit-btn" }))

        XCTAssertFalse(SemanticMatcher.pixelClickHitsTarget(selector: selector, trueTargetNode: movedTarget))
        let resolved = try XCTUnwrap(SemanticMatcher.resolve(selector: selector, in: mutatedTree))
        XCTAssertEqual(resolved.node.id, movedTarget.id)
        XCTAssertEqual(resolved.strategy, .identifier)
    }

    func testMacroCompilerCoalescesKeystrokesBackspaceDoubleClickAndAutoVariables() {
        let btn = AXSelector(bundleID: "com.google.Chrome", appName: "Chrome", role: "AXButton", identifier: "submit_btn", title: "Submit")
        let events: [RawRecordedEvent] = [
            RawRecordedEvent(timestampSec: 0.0, kind: .appFocus(bundleID: "com.google.Chrome", appName: "Chrome")),
            RawRecordedEvent(timestampSec: 0.1, kind: .appFocus(bundleID: "com.google.Chrome", appName: "Chrome")),
            RawRecordedEvent(timestampSec: 0.2, kind: .keyChar("a")),
            RawRecordedEvent(timestampSec: 0.25, kind: .keyChar("l")),
            RawRecordedEvent(timestampSec: 0.30, kind: .keyChar("x")),
            RawRecordedEvent(timestampSec: 0.35, kind: .backspace),
            RawRecordedEvent(timestampSec: 0.40, kind: .keyChar("e")),
            RawRecordedEvent(timestampSec: 0.45, kind: .keyChar("x")),
            RawRecordedEvent(timestampSec: 0.50, kind: .keyChar("@")),
            RawRecordedEvent(timestampSec: 0.55, kind: .keyChar("a")),
            RawRecordedEvent(timestampSec: 0.60, kind: .keyChar("c")),
            RawRecordedEvent(timestampSec: 0.65, kind: .keyChar("m")),
            RawRecordedEvent(timestampSec: 0.70, kind: .keyChar("e")),
            RawRecordedEvent(timestampSec: 0.75, kind: .keyChar(".")),
            RawRecordedEvent(timestampSec: 0.80, kind: .keyChar("i")),
            RawRecordedEvent(timestampSec: 0.85, kind: .keyChar("o")),
            RawRecordedEvent(timestampSec: 1.00, kind: .mouseClick(selector: btn)),
            RawRecordedEvent(timestampSec: 1.18, kind: .mouseClick(selector: btn))
        ]

        let wf = MacroCompiler.compile(name: "Test Flow", rawEvents: events, autoParameterize: true)
        XCTAssertEqual(wf.steps.count, 3) // Focus + Type({{email}}) + DoubleClick
        XCTAssertTrue(wf.variables.contains("email"))
        if case .doubleClick(let sel) = wf.steps[2].action {
            XCTAssertEqual(sel.identifier, "submit_btn")
        } else {
            XCTFail("Expected rapid double-click to collapse into .doubleClick")
        }
    }

    func testCSVBatchEngineParsesQuotedRFC4180AndRunsBatch() {
        let csv = """
        email,company
        "alex@acme.io","Acme, Inc."
        "sara@northstar.ai","Northstar ""Labs"""
        """
        let dataset = CSVBatchEngine.parse(csv, fileName: "test.csv")
        XCTAssertEqual(dataset.headers, ["email", "company"])
        XCTAssertEqual(dataset.rows.count, 2)
        XCTAssertEqual(dataset.rows[0]["company"], "Acme, Inc.")
        XCTAssertEqual(dataset.rows[1]["company"], "Northstar \"Labs\"")

        let tree = AxonBenchmarkRunner.makeSyntheticAXTree(nodeCount: 100, offsetX: 300, offsetY: 120)
        let btn = AXSelector(bundleID: "com.google.Chrome", appName: "Chrome", role: "AXButton", identifier: "crm_submit_lead_btn", title: "Save & Sync Lead")
        let wf = MacroWorkflow(
            name: "Batch",
            summary: "",
            steps: [
                MacroStep(order: 1, label: "Type Email", action: .typeText("{{email}}")),
                MacroStep(order: 2, label: "Click Save", action: .click(btn))
            ],
            variables: ["email"]
        )

        let preflight = CSVBatchEngine.preflight(workflow: wf, dataset: dataset)
        XCTAssertTrue(preflight.isReady)

        let summary = CSVBatchEngine.runSimulatedBatch(workflow: wf, dataset: dataset, axTree: tree)
        XCTAssertEqual(summary.succeededRows, 2)
        XCTAssertEqual(summary.failedRows, 0)
    }

    func testAppleScriptExportAndSQLiteStorePersistence() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("axon-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = try WorkflowStore(databaseURL: dir.appendingPathComponent("workflows.sqlite"))
        let wf = MacroWorkflow(
            name: "Sync Lead",
            summary: "Test",
            steps: [
                MacroStep(order: 1, label: "Focus", action: .focusApp(bundleID: "com.apple.Safari", appName: "Safari")),
                MacroStep(order: 2, label: "Type", action: .typeText("{{email}}"))
            ],
            variables: ["email"]
        )

        try await store.upsert(wf)
        let loaded = try await store.fetchAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.name, "Sync Lead")

        let script = MacroCompiler.exportAppleScript(for: wf, sampleRow: ["email": "ceo@acme.io"])
        XCTAssertTrue(script.contains("tell application \"Safari\" to activate"))
        XCTAssertTrue(script.contains("ceo@acme.io"))
    }
}
