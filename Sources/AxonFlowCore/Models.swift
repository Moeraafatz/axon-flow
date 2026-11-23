import CoreGraphics
import Foundation

public struct NormalizedPoint: Codable, Hashable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct AXRect: Codable, Hashable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var center: (x: Double, y: Double) {
        (x + width * 0.5, y + height * 0.5)
    }

    public func contains(x px: Double, y py: Double) -> Bool {
        px >= x && px <= (x + width) && py >= y && py <= (y + height)
    }
}

/// Semantic macOS Accessibility target invariant to window position, display shifts, and layout changes.
public struct AXSelector: Codable, Hashable, Sendable {
    public let bundleID: String
    public let appName: String
    public let role: String
    public let subrole: String?
    public let identifier: String?
    public let title: String?
    public let helpText: String?
    public let ancestorRoles: [String]
    public let siblingIndex: Int
    public let recordedScreenPoint: NormalizedPoint

    public init(
        bundleID: String,
        appName: String,
        role: String,
        subrole: String? = nil,
        identifier: String? = nil,
        title: String? = nil,
        helpText: String? = nil,
        ancestorRoles: [String] = [],
        siblingIndex: Int = 0,
        recordedScreenPoint: NormalizedPoint = NormalizedPoint(x: 0, y: 0)
    ) {
        self.bundleID = bundleID
        self.appName = appName
        self.role = role
        self.subrole = subrole
        self.identifier = identifier
        self.title = title
        self.helpText = helpText
        self.ancestorRoles = ancestorRoles
        self.siblingIndex = siblingIndex
        self.recordedScreenPoint = recordedScreenPoint
    }

    public var displayBadge: String {
        if let id = identifier, !id.isEmpty { return "#\(id)" }
        if let t = title, !t.isEmpty { return "\(role)[\"\(t)\"]" }
        return "\(role)#\(siblingIndex)"
    }
}

public struct AXSnapshotNode: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let role: String
    public let subrole: String?
    public let identifier: String?
    public let title: String?
    public let helpText: String?
    public let frame: AXRect
    public let ancestorRoles: [String]
    public let siblingIndex: Int
    public let isEnabled: Bool

    public init(
        id: String,
        role: String,
        subrole: String? = nil,
        identifier: String? = nil,
        title: String? = nil,
        helpText: String? = nil,
        frame: AXRect,
        ancestorRoles: [String] = [],
        siblingIndex: Int = 0,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.role = role
        self.subrole = subrole
        self.identifier = identifier
        self.title = title
        self.helpText = helpText
        self.frame = frame
        self.ancestorRoles = ancestorRoles
        self.siblingIndex = siblingIndex
        self.isEnabled = isEnabled
    }
}

public enum SelectorStrategy: String, Codable, Sendable {
    case identifier = "AXIdentifier"
    case titleAndRole = "Title+Role"
    case ancestorFuzzy = "Ancestor+Fuzzy"
    case fallback = "Fallback"
}

public struct SelectorMatchResult: Sendable, Equatable {
    public let node: AXSnapshotNode
    public let score: Double
    public let strategy: SelectorStrategy
    public let durationMs: Double

    public init(node: AXSnapshotNode, score: Double, strategy: SelectorStrategy, durationMs: Double) {
        self.node = node
        self.score = score
        self.strategy = strategy
        self.durationMs = durationMs
    }
}

public enum MacroActionKind: Codable, Hashable, Sendable {
    case focusApp(bundleID: String, appName: String)
    case click(AXSelector)
    case doubleClick(AXSelector)
    case typeText(String)
    case keyCombo(key: String, modifiers: [String])
    case setClipboard(String)
    case waitForElement(AXSelector, timeoutSec: Double)
    case runAppleScript(String)
    case pause(ms: Int)

    public var verbLabel: String {
        switch self {
        case .focusApp: return "FOCUS"
        case .click: return "CLICK"
        case .doubleClick: return "DBL-CLICK"
        case .typeText: return "TYPE"
        case .keyCombo: return "HOTKEY"
        case .setClipboard: return "CLIPBOARD"
        case .waitForElement: return "WAIT AX"
        case .runAppleScript: return "APPLESCRIPT"
        case .pause: return "PAUSE"
        }
    }

    public var targetSummary: String {
        switch self {
        case .focusApp(_, let appName): return appName
        case .click(let sel), .doubleClick(let sel), .waitForElement(let sel, _): return sel.displayBadge
        case .typeText(let text): return "\"\(text)\""
        case .keyCombo(let key, let mods): return (mods + [key]).joined(separator: "+")
        case .setClipboard(let text): return "\"\(text)\""
        case .runAppleScript(let script): return String(script.prefix(48))
        case .pause(let ms): return "\(ms) ms"
        }
    }

    public var appName: String? {
        switch self {
        case .focusApp(_, let app): return app
        case .click(let sel), .doubleClick(let sel), .waitForElement(let sel, _): return sel.appName
        default: return nil
        }
    }
}

public struct MacroStep: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var order: Int
    public var label: String
    public var action: MacroActionKind
    public var retryCount: Int
    public var delayAfterMs: Int
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        order: Int,
        label: String,
        action: MacroActionKind,
        retryCount: Int = 2,
        delayAfterMs: Int = 120,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.order = order
        self.label = label
        self.action = action
        self.retryCount = retryCount
        self.delayAfterMs = delayAfterMs
        self.isEnabled = isEnabled
    }
}

public struct MacroWorkflow: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var summary: String
    public var steps: [MacroStep]
    public var variables: [String]
    public var rawEventCount: Int
    public var hotkeyLabel: String
    public var createdAt: Date
    public var runCount: Int
    public var estimatedManualSecondsPerRun: Double
    public var lastRunDurationMs: Double

    public init(
        id: UUID = UUID(),
        name: String,
        summary: String,
        steps: [MacroStep],
        variables: [String] = [],
        rawEventCount: Int = 0,
        hotkeyLabel: String = "⌥⇧1",
        createdAt: Date = Date(),
        runCount: Int = 0,
        estimatedManualSecondsPerRun: Double = 90,
        lastRunDurationMs: Double = 0
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.steps = steps
        self.variables = variables
        self.rawEventCount = max(rawEventCount, steps.count)
        self.hotkeyLabel = hotkeyLabel
        self.createdAt = createdAt
        self.runCount = runCount
        self.estimatedManualSecondsPerRun = estimatedManualSecondsPerRun
        self.lastRunDurationMs = lastRunDurationMs
    }

    public var compressionPercent: Double {
        guard rawEventCount > 0 else { return 0 }
        return max(0, (1.0 - Double(steps.count) / Double(rawEventCount)) * 100.0)
    }

    public var totalHoursSaved: Double {
        (Double(runCount) * estimatedManualSecondsPerRun) / 3600.0
    }
}

public enum RawRecordedEventKind: Codable, Hashable, Sendable {
    case appFocus(bundleID: String, appName: String)
    case mouseClick(selector: AXSelector)
    case keyChar(String)
    case backspace
    case keyCombo(key: String, modifiers: [String])
    case clipboardCopy(String)
}

public struct RawRecordedEvent: Codable, Hashable, Sendable {
    public let timestampSec: Double
    public let kind: RawRecordedEventKind

    public init(timestampSec: Double, kind: RawRecordedEventKind) {
        self.timestampSec = timestampSec
        self.kind = kind
    }
}

public struct CSVDataset: Codable, Hashable, Sendable {
    public let fileName: String
    public let headers: [String]
    public let rows: [[String: String]]

    public init(fileName: String, headers: [String], rows: [[String: String]]) {
        self.fileName = fileName
        self.headers = headers
        self.rows = rows
    }
}

public struct RowExecutionTrace: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let rowIndex: Int
    public let primaryLabel: String
    public let stepsExecuted: Int
    public let strategyUsed: SelectorStrategy
    public let durationMs: Double
    public let succeeded: Bool
    public let errorMessage: String?

    public init(
        id: UUID = UUID(),
        rowIndex: Int,
        primaryLabel: String,
        stepsExecuted: Int,
        strategyUsed: SelectorStrategy,
        durationMs: Double,
        succeeded: Bool,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.rowIndex = rowIndex
        self.primaryLabel = primaryLabel
        self.stepsExecuted = stepsExecuted
        self.strategyUsed = strategyUsed
        self.durationMs = durationMs
        self.succeeded = succeeded
        self.errorMessage = errorMessage
    }
}

public struct AxonSafetyConfig: Codable, Sendable, Equatable {
    public var dryRunGuard: Bool
    public var defaultStepDelayMs: Int
    public var maxRetriesPerStep: Int
    public var abortOnFirstRowError: Bool
    public var highlightBeforeClick: Bool

    public static let `default` = AxonSafetyConfig(
        dryRunGuard: false,
        defaultStepDelayMs: 120,
        maxRetriesPerStep: 2,
        abortOnFirstRowError: false,
        highlightBeforeClick: true
    )

    public init(
        dryRunGuard: Bool = false,
        defaultStepDelayMs: Int = 120,
        maxRetriesPerStep: Int = 2,
        abortOnFirstRowError: Bool = false,
        highlightBeforeClick: Bool = true
    ) {
        self.dryRunGuard = dryRunGuard
        self.defaultStepDelayMs = defaultStepDelayMs
        self.maxRetriesPerStep = maxRetriesPerStep
        self.abortOnFirstRowError = abortOnFirstRowError
        self.highlightBeforeClick = highlightBeforeClick
    }
}
