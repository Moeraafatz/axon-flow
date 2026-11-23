import AxonFlowCore
import Foundation

@main
struct AxonFlowToolsMain {
    static func main() async {
        do {
            let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            let docsDir = root.appendingPathComponent("docs", isDirectory: true)
            let screenshotsDir = docsDir.appendingPathComponent("screenshots", isDirectory: true)
            let graphsDir = docsDir.appendingPathComponent("graphs", isDirectory: true)
            let assetsDir = docsDir.appendingPathComponent("assets", isDirectory: true)
            let iconsetDir = root.appendingPathComponent(".build/AppIcon.iconset", isDirectory: true)

            print("[AxonFlowTools] Generating macOS AppIcon set...")
            try AxonIconGenerator.generateIconSet(
                iconsetURL: iconsetDir,
                docsIconURL: assetsDir.appendingPathComponent("icon.png")
            )

            print("[AxonFlowTools] Rendering SwiftUI Retina screenshots...")
            try await MainActor.run {
                try AxonScreenshotRenderer.renderAll(outputDir: screenshotsDir)
            }

            print("[AxonFlowTools] Running Apple Silicon AX Resilience & CSV Batch benchmarks...")
            let report = try AxonBenchmarkRunner.runFullSuite()

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let jsonData = try encoder.encode(report)
            try jsonData.write(to: docsDir.appendingPathComponent("benchmarks.json"))

            print("[AxonFlowTools] Rendering benchmark graphs & architecture SVG...")
            try AxonGraphRenderer.renderAll(report: report, outputDir: graphsDir)

            let summary = makeBenchmarkMarkdown(report: report)
            try summary.write(to: docsDir.appendingPathComponent("benchmark-summary.md"), atomically: true, encoding: .utf8)

            print("[AxonFlowTools] Complete!")
            print(summary)
        } catch {
            fputs("[AxonFlowTools] ERROR: \(error)\n", stderr)
            exit(1)
        }
    }

    private static func makeBenchmarkMarkdown(report: AxonBenchmarkReport) -> String {
        var resilienceRows = ""
        for sc in report.resilienceScenarios {
            resilienceRows += String(
                format: "| %@ | %d | **%.1f%%** | %.1f%% |\n",
                sc.scenarioName, sc.trials, sc.semanticSuccessPercent, sc.pixelSuccessPercent
            )
        }

        var selectorRows = ""
        for pt in report.selectorScalePoints {
            selectorRows += String(
                format: "| %d AX nodes | **%.3f ms** | **%.3f ms** |\n",
                pt.treeNodeCount, pt.resolveP50Ms, pt.resolveP95Ms
            )
        }

        let maxBatch = report.batchScalePoints.last
        let batchSummary = maxBatch.map {
            String(format: "`%d` CSV rows parsed, interpolated & AX-verified in **`%.1f ms`** (`%.0f rows/s`)", $0.rowCount, $0.totalDurationMs, $0.rowsPerSecond)
        } ?? ""

        return """
        ### Measured Benchmarks (\(report.hostArchitecture) · \(report.osVersion))

        - **Macro Compiler Compression:** `\(report.compilerRawEvents)` noisy raw events → **`\(report.compilerCompiledSteps)` semantic steps** (`\(String(format: "%.1f%%", report.compilerReductionPercent))` reduction in `\(String(format: "%.3f ms", report.compilerDurationMs))`)
        - **CSV Batch Throughput:** \(batchSummary)

        #### 1. Replay Survival Across UI Mutations (60 trials each)

        | Desktop Mutation Scenario | Trials | Axon Flow (Semantic AX) | Pixel Clicker |
        | :--- | ---: | ---: | ---: |
        \(resilienceRows)
        #### 2. Semantic AX Tree Resolution Speed

        | Accessibility Tree Size | Resolution p50 | Resolution p95 |
        | ---: | ---: | ---: |
        \(selectorRows)
        """
    }
}
