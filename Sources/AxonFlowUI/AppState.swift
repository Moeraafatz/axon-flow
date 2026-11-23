import AppKit
import AxonFlowCore
import Foundation
import Observation

public enum AxonTab: String, CaseIterable, Identifiable, Sendable {
    case studio = "Studio"
    case batch = "Batch"
    case library = "Library"
    case safety = "Safety"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .studio: return "point.3.connected.trianglepath.dotted"
        case .batch: return "tablecells.fill"
        case .library: return "square.stack.3d.up.fill"
        case .safety: return "shield.checkered"
        }
    }

    public var shortcut: String {
        switch self {
        case .studio: return "⌘1"
        case .batch: return "⌘2"
        case .library: return "⌘3"
        case .safety: return "⌘4"
        }
    }
}

@MainActor
@Observable
public final class AxonAppState {
    public var selectedTab: AxonTab = .studio
    public var workflows: [MacroWorkflow] = []
    public var activeWorkflow: MacroWorkflow
    public var isRecording: Bool = false
    public var recordedEventsBuffer: [RawRecordedEvent] = []
    public var dataset: CSVDataset
    public var batchTraces: [RowExecutionTrace] = []
    public var batchCompletedRows: Int = 0
    public var batchTotalRows: Int = 0
    public var batchSuccessRate: Double = 100.0
    public var safetyConfig: AxonSafetyConfig = .default
    public var hasAccessibilityPermission: Bool = false
    public var hasInputMonitoringPermission: Bool = false
    public var databaseBytes: Int64 = 0
    public var statusToast: String? = nil
    public let isPreviewSnapshot: Bool

    private let store: WorkflowStore?
    private let liveBridge: LiveAXBridge?

    public init(store: WorkflowStore? = nil, isPreviewSnapshot: Bool = false) {
        self.store = store
        self.isPreviewSnapshot = isPreviewSnapshot
        let defaults = AxonSampleData.demoWorkflows()
        self.workflows = defaults
        self.activeWorkflow = defaults[0]
        self.dataset = AxonSampleData.demoDataset()
        if !isPreviewSnapshot {
            self.liveBridge = LiveAXBridge()
            refreshPermissions()
        } else {
            self.liveBridge = nil
        }
    }

    public static func demo(tab: AxonTab = .studio) -> AxonAppState {
        let state = AxonAppState(store: nil, isPreviewSnapshot: true)
        state.selectedTab = tab
        state.batchTraces = AxonSampleData.demoTraces()
        state.batchCompletedRows = 250
        state.batchTotalRows = 250
        state.batchSuccessRate = 100.0
        state.hasAccessibilityPermission = true
        state.hasInputMonitoringPermission = true
        state.databaseBytes = 94_208
        return state
    }

    public func bootstrap() async {
        guard !isPreviewSnapshot else { return }
        refreshPermissions()
        if let store {
            let saved = (try? await store.fetchAll()) ?? []
            if !saved.isEmpty {
                workflows = saved
                activeWorkflow = saved[0]
            } else {
                for wf in workflows {
                    try? await store.upsert(wf)
                }
            }
            databaseBytes = await store.databaseFileSizeBytes()
        }
    }

    public func refreshPermissions() {
        hasAccessibilityPermission = AXPermissionHelper.hasAccessibilityPermission()
        hasInputMonitoringPermission = AXPermissionHelper.hasInputMonitoringPermission()
    }

    public func toggleRecording() {
        if isRecording {
            stopAndCompileRecording()
        } else {
            startRecording()
        }
    }

    public func startRecording() {
        guard !isPreviewSnapshot, let liveBridge else {
            isRecording = true
            return
        }
        refreshPermissions()
        guard hasAccessibilityPermission else {
            AXPermissionHelper.openAccessibilitySettings()
            showToast("Enable Accessibility permission to capture semantic AX selectors")
            return
        }
        recordedEventsBuffer.removeAll()
        let started = liveBridge.startRecording { [weak self] ev in
            self?.recordedEventsBuffer.append(ev)
        }
        if started {
            isRecording = true
            showToast("Recording semantic AX tree events…")
        } else {
            showToast("Could not attach CGEventTap — check Input Monitoring")
        }
    }

    public func stopAndCompileRecording() {
        liveBridge?.stopRecording()
        isRecording = false
        guard !recordedEventsBuffer.isEmpty else {
            showToast("Recording stopped (0 events captured)")
            return
        }
        let compiled = MacroCompiler.compile(
            name: "Recorded Workflow #\(workflows.count + 1)",
            rawEvents: recordedEventsBuffer,
            autoParameterize: true
        )
        activeWorkflow = compiled
        workflows.insert(compiled, at: 0)
        if let store {
            Task {
                try? await store.upsert(compiled)
                databaseBytes = await store.databaseFileSizeBytes()
            }
        }
        showToast("Compiled \(compiled.rawEventCount) raw events → \(compiled.steps.count) semantic steps")
    }

    public func runActiveWorkflowOnce() {
        let dryRun = safetyConfig.dryRunGuard
        var okCount = 0
        let firstRow = dataset.rows.first ?? [:]
        let instantiated = CSVBatchEngine.instantiateSteps(for: activeWorkflow, row: firstRow)
        for step in instantiated {
            if isPreviewSnapshot || LiveAXBridge.executeLiveStep(step, dryRun: dryRun) {
                okCount += 1
            }
        }
        activeWorkflow.runCount += 1
        showToast(dryRun ? "Dry-run verified \(okCount)/\(instantiated.count) semantic steps" : "Executed \(okCount)/\(instantiated.count) steps")
    }

    public func runCSVBatchDryRun() {
        let tree = AxonBenchmarkRunner.makeSyntheticAXTree(nodeCount: 250, offsetX: 280, offsetY: 140)
        let summary = CSVBatchEngine.runSimulatedBatch(workflow: activeWorkflow, dataset: dataset, axTree: tree)
        batchTraces = summary.traces
        batchCompletedRows = summary.totalRows
        batchTotalRows = summary.totalRows
        batchSuccessRate = summary.successRatePercent
        showToast(String(format: "Verified %d/%d rows in %.1f ms (%.0f%% match)", summary.succeededRows, summary.totalRows, summary.totalDurationMs, summary.successRatePercent))
    }

    public func copyAppleScript() {
        let script = MacroCompiler.exportAppleScript(for: activeWorkflow, sampleRow: dataset.rows.first ?? [:])
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(script, forType: .string)
        showToast("Copied AppleScript export to clipboard")
    }

    public func selectWorkflow(_ wf: MacroWorkflow) {
        activeWorkflow = wf
        selectedTab = .studio
    }

    public func wipeLibrary() {
        guard let store else {
            workflows.removeAll()
            return
        }
        Task {
            try? await store.wipeAll()
            workflows = AxonSampleData.demoWorkflows()
            activeWorkflow = workflows[0]
            databaseBytes = await store.databaseFileSizeBytes()
            showToast("Workflow library reset")
        }
    }

    public func showToast(_ msg: String) {
        statusToast = msg
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            if statusToast == msg { statusToast = nil }
        }
    }
}
