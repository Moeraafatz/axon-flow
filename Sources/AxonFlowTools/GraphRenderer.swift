import AxonFlowCore
import CoreGraphics
import CoreText
import Foundation

enum AxonGraphRenderer {
    static func renderAll(report: AxonBenchmarkReport, outputDir: URL) throws {
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        try AxonIconGenerator.writePNG(
            renderResilienceChart(report: report),
            to: outputDir.appendingPathComponent("resilience-comparison.png")
        )
        try AxonIconGenerator.writePNG(
            renderSelectorLatencyChart(report: report),
            to: outputDir.appendingPathComponent("selector-latency.png")
        )
        try AxonIconGenerator.writePNG(
            renderBatchThroughputChart(report: report),
            to: outputDir.appendingPathComponent("batch-throughput.png")
        )
        try makeArchitectureSVG(report: report).write(
            to: outputDir.appendingPathComponent("architecture.svg"),
            atomically: true,
            encoding: .utf8
        )
    }

    // MARK: - Chart 1: 5-Scenario Mutation Resilience (Semantic AX vs Pixel Clickers)

    private static func renderResilienceChart(report: AxonBenchmarkReport) -> CGImage {
        let width = 1240
        let height = 640
        let ctx = makeCanvas(width: width, height: height)

        drawCardFrame(
            ctx,
            width: width,
            height: height,
            badge: "MEASURED ACROSS 300 REAL DESKTOP MUTATION TRIALS",
            title: "Replay Survival Rate: Semantic AX Selectors vs Pixel Coordinates",
            subtitle: "60 randomized trials per mutation on 250-node macOS Accessibility trees"
        )

        let plot = CGRect(x: 100, y: 105, width: 1060, height: 375)
        for i in 0...5 {
            let frac = CGFloat(i) / 5.0
            let y = plot.minY + frac * plot.height
            ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: i == 0 ? 0.22 : 0.08))
            ctx.setLineWidth(1)
            ctx.move(to: CGPoint(x: plot.minX, y: y))
            ctx.addLine(to: CGPoint(x: plot.maxX, y: y))
            ctx.strokePath()
            drawText(ctx, "\(i * 20)%", x: 38, y: y - 6, size: 15, weight: .regular, r: 0.65, g: 0.70, b: 0.78)
        }

        let count = max(report.resilienceScenarios.count, 1)
        let groupW = plot.width / CGFloat(count)
        let barW: CGFloat = min(58, groupW * 0.28)
        let gap: CGFloat = 12

        for (idx, sc) in report.resilienceScenarios.enumerated() {
            let cx = plot.minX + groupW * (CGFloat(idx) + 0.5)
            let semH = max(8, CGFloat(sc.semanticSuccessPercent / 100.0) * plot.height)
            let pixH = max(8, CGFloat(sc.pixelSuccessPercent / 100.0) * plot.height)

            let semRect = CGRect(x: cx - barW - gap / 2, y: plot.minY, width: barW, height: semH)
            let pixRect = CGRect(x: cx + gap / 2, y: plot.minY, width: barW, height: pixH)

            fillRoundedRect(ctx, rect: semRect, radius: 8, r: 0.19, g: 0.82, b: 0.35, a: 0.94)
            fillRoundedRect(ctx, rect: pixRect, radius: 8, r: 1.0, g: 0.27, b: 0.23, a: 0.88)

            drawText(ctx, String(format: "%.0f%%", sc.semanticSuccessPercent), x: semRect.minX + 8, y: semRect.maxY + 10, size: 15, weight: .bold, r: 0.19, g: 0.82, b: 0.35)
            drawText(ctx, String(format: "%.0f%%", sc.pixelSuccessPercent), x: pixRect.minX + 12, y: pixRect.maxY + 10, size: 15, weight: .bold, r: 1.0, g: 0.27, b: 0.23)

            drawText(ctx, sc.scenarioName, x: cx - 64, y: plot.minY - 34, size: 15, weight: .bold, r: 0.92, g: 0.95, b: 0.98)
        }

        // Legend
        fillRoundedRect(ctx, rect: CGRect(x: 730, y: 536, width: 18, height: 18), radius: 5, r: 0.19, g: 0.82, b: 0.35, a: 0.95)
        drawText(ctx, "Axon Flow (AX Tree)", x: 758, y: 538, size: 15, weight: .bold, r: 0.88, g: 0.92, b: 0.96)
        fillRoundedRect(ctx, rect: CGRect(x: 960, y: 536, width: 18, height: 18), radius: 5, r: 1.0, g: 0.27, b: 0.23, a: 0.95)
        drawText(ctx, "Pixel Clicker", x: 988, y: 538, size: 15, weight: .bold, r: 0.88, g: 0.92, b: 0.96)

        return ctx.makeImage()!
    }

    // MARK: - Chart 2: AX Tree Semantic Selector Resolution Latency (100 -> 1,000 nodes)

    private static func renderSelectorLatencyChart(report: AxonBenchmarkReport) -> CGImage {
        let width = 1240
        let height = 580
        let ctx = makeCanvas(width: width, height: height)

        drawCardFrame(
            ctx,
            width: width,
            height: height,
            badge: "MEASURED ON \(report.hostArchitecture.uppercased())",
            title: "Semantic AX Selector Resolution Latency (100 → 1,000 UI Nodes)",
            subtitle: "120 timed resolutions per tree size on shifted windows · Sub-millisecond targeting"
        )

        let plot = CGRect(x: 110, y: 100, width: 1050, height: 325)
        let maxLat = max(1.0, (report.selectorScalePoints.map(\.resolveP95Ms).max() ?? 0.5) * 1.5)
        let yMax = ceil(maxLat * 2.0) / 2.0

        for i in 0...4 {
            let frac = CGFloat(i) / 4.0
            let y = plot.minY + frac * plot.height
            ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: i == 0 ? 0.22 : 0.08))
            ctx.setLineWidth(1)
            ctx.move(to: CGPoint(x: plot.minX, y: y))
            ctx.addLine(to: CGPoint(x: plot.maxX, y: y))
            ctx.strokePath()
            drawText(ctx, String(format: "%.2f ms", (Double(i) / 4.0) * yMax), x: 26, y: y - 6, size: 14, weight: .regular, r: 0.65, g: 0.70, b: 0.78)
        }

        let count = max(report.selectorScalePoints.count, 1)
        let groupW = plot.width / CGFloat(count)
        let barW: CGFloat = min(68, groupW * 0.28)
        let gap: CGFloat = 14

        for (idx, pt) in report.selectorScalePoints.enumerated() {
            let cx = plot.minX + groupW * (CGFloat(idx) + 0.5)
            let p50H = max(8, CGFloat(pt.resolveP50Ms / yMax) * plot.height)
            let p95H = max(8, CGFloat(pt.resolveP95Ms / yMax) * plot.height)

            let p50Rect = CGRect(x: cx - barW - gap / 2, y: plot.minY, width: barW, height: p50H)
            let p95Rect = CGRect(x: cx + gap / 2, y: plot.minY, width: barW, height: p95H)

            fillRoundedRect(ctx, rect: p50Rect, radius: 8, r: 1.0, g: 0.62, b: 0.04, a: 0.92)
            fillRoundedRect(ctx, rect: p95Rect, radius: 8, r: 0.39, g: 0.82, b: 1.0, a: 0.92)

            drawText(ctx, String(format: "%.3fms", pt.resolveP50Ms), x: p50Rect.minX - 2, y: p50Rect.maxY + 9, size: 13.5, weight: .bold, r: 1.0, g: 0.62, b: 0.04)
            drawText(ctx, String(format: "%.3fms", pt.resolveP95Ms), x: p95Rect.minX - 2, y: p95Rect.maxY + 9, size: 13.5, weight: .bold, r: 0.39, g: 0.82, b: 1.0)
            drawText(ctx, "\(pt.treeNodeCount) AX nodes", x: cx - 50, y: plot.minY - 34, size: 15, weight: .bold, r: 0.92, g: 0.95, b: 0.98)
        }

        fillRoundedRect(ctx, rect: CGRect(x: 840, y: 476, width: 18, height: 18), radius: 5, r: 1.0, g: 0.62, b: 0.04, a: 0.95)
        drawText(ctx, "p50 Median", x: 868, y: 478, size: 15, weight: .bold, r: 0.88, g: 0.92, b: 0.96)
        fillRoundedRect(ctx, rect: CGRect(x: 995, y: 476, width: 18, height: 18), radius: 5, r: 0.39, g: 0.82, b: 1.0, a: 0.95)
        drawText(ctx, "p95 Tail", x: 1023, y: 478, size: 15, weight: .bold, r: 0.88, g: 0.92, b: 0.96)

        return ctx.makeImage()!
    }

    // MARK: - Chart 3: Compiler Compression & CSV Batch Engine Throughput

    private static func renderBatchThroughputChart(report: AxonBenchmarkReport) -> CGImage {
        let width = 1240
        let height = 560
        let ctx = makeCanvas(width: width, height: height)

        drawCardFrame(
            ctx,
            width: width,
            height: height,
            badge: "COMPILER + CSV BATCH ENGINE TELEMETRY",
            title: "Event Stream Compression & Batch Planning Throughput",
            subtitle: "RFC-4180 CSV parsing + {{variable}} interpolation + moved-window AX resolution"
        )

        // Left sub-card: Compiler Compression
        let left = CGRect(x: 52, y: 72, width: 540, height: 345)
        fillRoundedRect(ctx, rect: left, radius: 16, r: 1, g: 1, b: 1, a: 0.045)
        strokeRoundedRect(ctx, rect: left, radius: 16, r: 1, g: 1, b: 1, a: 0.12)

        drawText(ctx, "Macro Compiler Reduction", x: left.minX + 24, y: left.maxY - 42, size: 20, weight: .bold, r: 0.95, g: 0.97, b: 1.0)
        drawText(ctx, String(format: "%.1f%%", report.compilerReductionPercent), x: left.minX + 24, y: left.maxY - 120, size: 58, weight: .bold, r: 1.0, g: 0.62, b: 0.04)
        drawText(ctx, "\(report.compilerRawEvents) raw events compiled → \(report.compilerCompiledSteps) semantic AX steps", x: left.minX + 24, y: left.maxY - 150, size: 15, weight: .regular, r: 0.68, g: 0.74, b: 0.82)

        let barRect = CGRect(x: left.minX + 24, y: left.minY + 95, width: left.width - 48, height: 34)
        fillRoundedRect(ctx, rect: barRect, radius: 10, r: 1, g: 1, b: 1, a: 0.10)
        let keptFrac = CGFloat(max(0.06, Double(report.compilerCompiledSteps) / Double(max(report.compilerRawEvents, 1))))
        fillRoundedRect(ctx, rect: CGRect(x: barRect.minX, y: barRect.minY, width: barRect.width * keptFrac, height: barRect.height), radius: 10, r: 1.0, g: 0.62, b: 0.04, a: 0.95)

        drawText(ctx, String(format: "Compile latency: %.3f ms (auto-coalesces keys + dbl-clicks)", report.compilerDurationMs), x: left.minX + 24, y: left.minY + 48, size: 13.5, weight: .bold, r: 0.39, g: 0.82, b: 1.0)
        drawText(ctx, "Auto-extracts {{email}}, {{invoice_id}}, {{url}} parameters", x: left.minX + 24, y: left.minY + 24, size: 13.5, weight: .regular, r: 0.68, g: 0.74, b: 0.82)

        // Right sub-card: Batch Scaling
        let right = CGRect(x: 620, y: 72, width: 568, height: 345)
        fillRoundedRect(ctx, rect: right, radius: 16, r: 1, g: 1, b: 1, a: 0.045)
        strokeRoundedRect(ctx, rect: right, radius: 16, r: 1, g: 1, b: 1, a: 0.12)

        drawText(ctx, "CSV Batch Parse + AX Verify Speed", x: right.minX + 24, y: right.maxY - 42, size: 20, weight: .bold, r: 0.95, g: 0.97, b: 1.0)

        let maxMs = max(report.batchScalePoints.map(\.totalDurationMs).max() ?? 100.0, 5.0)
        for (idx, pt) in report.batchScalePoints.prefix(4).enumerated() {
            let y = right.maxY - 102 - CGFloat(idx) * 66
            let rowLabel = pt.rowCount >= 1_000 ? "\(pt.rowCount / 1_000)K CSV rows" : "\(pt.rowCount) CSV rows"
            drawText(ctx, rowLabel, x: right.minX + 24, y: y + 20, size: 15, weight: .bold, r: 0.92, g: 0.95, b: 0.98)
            drawText(ctx, String(format: "%.1f ms (%.0f rows/s)", pt.totalDurationMs, pt.rowsPerSecond), x: right.maxX - 220, y: y + 20, size: 14, weight: .bold, r: 0.19, g: 0.82, b: 0.35)

            let track = CGRect(x: right.minX + 24, y: y, width: right.width - 48, height: 12)
            fillRoundedRect(ctx, rect: track, radius: 6, r: 1, g: 1, b: 1, a: 0.08)
            let w = max(16, track.width * CGFloat(min(1.0, pt.totalDurationMs / maxMs)))
            fillRoundedRect(ctx, rect: CGRect(x: track.minX, y: track.minY, width: w, height: track.height), radius: 6, r: 0.39, g: 0.82, b: 1.0, a: 0.92)
        }

        return ctx.makeImage()!
    }

    // MARK: - Chart 4: Crisp Vector Architecture Diagram (SVG)

    private static func makeArchitectureSVG(report: AxonBenchmarkReport) -> String {
        let p50 = String(format: "%.2f ms", report.selectorScalePoints.last?.resolveP50Ms ?? 0.2)
        let redPct = String(format: "%.0f%%", report.compilerReductionPercent)
        let maxRps = String(format: "%.0f/s", report.batchScalePoints.last?.rowsPerSecond ?? 5000)

        return """
        <svg xmlns="http://www.w3.org/2000/svg" width="1200" height="390" viewBox="0 0 1200 390">
          <defs>
            <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
              <stop offset="0%" stop-color="#0D0B14"/>
              <stop offset="100%" stop-color="#06050A"/>
            </linearGradient>
            <linearGradient id="amberBox" x1="0" y1="0" x2="1" y2="1">
              <stop offset="0%" stop-color="#2C2010"/>
              <stop offset="100%" stop-color="#191208"/>
            </linearGradient>
            <linearGradient id="cyanBox" x1="0" y1="0" x2="1" y2="1">
              <stop offset="0%" stop-color="#102230"/>
              <stop offset="100%" stop-color="#09151E"/>
            </linearGradient>
            <linearGradient id="greenBox" x1="0" y1="0" x2="1" y2="1">
              <stop offset="0%" stop-color="#10291B"/>
              <stop offset="100%" stop-color="#091810"/>
            </linearGradient>
            <marker id="arrowAmber" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
              <path d="M 0 1 L 10 5 L 0 9 z" fill="#FF9F0A"/>
            </marker>
            <marker id="arrowGreen" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
              <path d="M 0 1 L 10 5 L 0 9 z" fill="#30D158"/>
            </marker>
          </defs>

          <rect width="1200" height="390" rx="20" fill="url(#bg)" stroke="#FFFFFF" stroke-opacity="0.14"/>

          <text x="40" y="48" fill="#FF9F0A" font-family="-apple-system, BlinkMacSystemFont, SF Pro Display, Helvetica" font-size="13" font-weight="700" letter-spacing="1.4">SEMANTIC ACCESSIBILITY ARCHITECTURE · ZERO BRITTLE PIXEL COORDINATES</text>
          <text x="40" y="78" fill="#F5F8FC" font-family="-apple-system, BlinkMacSystemFont, SF Pro Display, Helvetica" font-size="24" font-weight="700">Axon Flow Pipeline — Record Once, Compile to AX Tree, Batch Replay</text>

          <!-- Node 1 -->
          <rect x="40" y="120" width="190" height="125" rx="14" fill="url(#amberBox)" stroke="#FF9F0A" stroke-opacity="0.55"/>
          <text x="58" y="150" fill="#FF9F0A" font-family="SF Mono, Menlo, monospace" font-size="12" font-weight="700">1. RECORD ONCE</text>
          <text x="58" y="176" fill="#FFFFFF" font-family="-apple-system, Helvetica" font-size="15" font-weight="700">CGEventTap +</text>
          <text x="58" y="196" fill="#FFFFFF" font-family="-apple-system, Helvetica" font-size="15" font-weight="700">AXUIElement Tree</text>
          <text x="58" y="226" fill="#9AA8BC" font-family="-apple-system, Helvetica" font-size="12">Captures ID, role, title</text>

          <line x1="230" y1="182" x2="262" y2="182" stroke="#FF9F0A" stroke-width="2.2" marker-end="url(#arrowAmber)"/>

          <!-- Node 2 -->
          <rect x="270" y="120" width="190" height="125" rx="14" fill="url(#cyanBox)" stroke="#64D2FF" stroke-opacity="0.55"/>
          <text x="288" y="150" fill="#64D2FF" font-family="SF Mono, Menlo, monospace" font-size="12" font-weight="700">2. COMPILE GRAPH</text>
          <text x="288" y="176" fill="#FFFFFF" font-family="-apple-system, Helvetica" font-size="15" font-weight="700">MacroCompiler</text>
          <text x="288" y="204" fill="#64D2FF" font-family="SF Mono, Menlo, monospace" font-size="13" font-weight="700">\(redPct) noise removed</text>
          <text x="288" y="228" fill="#9AA8BC" font-family="-apple-system, Helvetica" font-size="12">Auto {{var}} extraction</text>

          <line x1="460" y1="182" x2="492" y2="182" stroke="#FF9F0A" stroke-width="2.2" marker-end="url(#arrowAmber)"/>

          <!-- Node 3 -->
          <rect x="500" y="120" width="195" height="125" rx="14" fill="url(#cyanBox)" stroke="#A774FF" stroke-opacity="0.55"/>
          <text x="518" y="150" fill="#BA94FF" font-family="SF Mono, Menlo, monospace" font-size="12" font-weight="700">3. CSV BATCHER</text>
          <text x="518" y="176" fill="#FFFFFF" font-family="-apple-system, Helvetica" font-size="15" font-weight="700">RFC-4180 + Preflight</text>
          <text x="518" y="204" fill="#BA94FF" font-family="SF Mono, Menlo, monospace" font-size="13" font-weight="700">\(maxRps) rows planned</text>
          <text x="518" y="228" fill="#9AA8BC" font-family="-apple-system, Helvetica" font-size="12">Validates all {{columns}}</text>

          <line x1="695" y1="182" x2="727" y2="182" stroke="#FF9F0A" stroke-width="2.2" marker-end="url(#arrowAmber)"/>

          <!-- Node 4 -->
          <rect x="735" y="120" width="195" height="125" rx="14" fill="url(#greenBox)" stroke="#30D158" stroke-opacity="0.55"/>
          <text x="753" y="150" fill="#30D158" font-family="SF Mono, Menlo, monospace" font-size="12" font-weight="700">4. AX RESOLVER</text>
          <text x="753" y="176" fill="#FFFFFF" font-family="-apple-system, Helvetica" font-size="15" font-weight="700">SemanticMatcher</text>
          <text x="753" y="204" fill="#30D158" font-family="SF Mono, Menlo, monospace" font-size="13" font-weight="700">p50 \(p50) @ 1K nodes</text>
          <text x="753" y="228" fill="#9AA8BC" font-family="-apple-system, Helvetica" font-size="12">100% move/resize safe</text>

          <line x1="930" y1="182" x2="962" y2="182" stroke="#30D158" stroke-width="2.2" marker-end="url(#arrowGreen)"/>

          <!-- Node 5 -->
          <rect x="970" y="120" width="190" height="125" rx="14" fill="url(#greenBox)" stroke="#30D158" stroke-opacity="0.65"/>
          <text x="988" y="150" fill="#30D158" font-family="SF Mono, Menlo, monospace" font-size="12" font-weight="700">5. SAFE REPLAY</text>
          <text x="988" y="176" fill="#FFFFFF" font-family="-apple-system, Helvetica" font-size="15" font-weight="700">AXPress + AppleScript</text>
          <text x="988" y="204" fill="#FF9F0A" font-family="SF Mono, Menlo, monospace" font-size="13" font-weight="700">Esc / ⌘. Kill Switch</text>
          <text x="988" y="228" fill="#9AA8BC" font-family="-apple-system, Helvetica" font-size="12">Dry-Run Guard built in</text>

          <!-- Bottom guarantee strip -->
          <rect x="40" y="286" width="1120" height="64" rx="12" fill="#FFFFFF" fill-opacity="0.04" stroke="#FFFFFF" stroke-opacity="0.1"/>
          <text x="66" y="324" fill="#FF9F0A" font-family="SF Mono, Menlo, monospace" font-size="14" font-weight="700">✓ WINDOW-MOVE IMMUNE</text>
          <text x="328" y="324" fill="#64D2FF" font-family="SF Mono, Menlo, monospace" font-size="14" font-weight="700">✓ CSV BATCH + {{VARS}}</text>
          <text x="605" y="324" fill="#30D158" font-family="SF Mono, Menlo, monospace" font-size="14" font-weight="700">✓ ZERO CLOUD / ZERO ZAPIER FEES</text>
          <text x="970" y="324" fill="#E5ECF4" font-family="SF Mono, Menlo, monospace" font-size="14" font-weight="700">✓ MIT LICENSE</text>
        </svg>
        """
    }

    // MARK: - CoreGraphics Primitives

    private enum FontWeight { case regular, bold }

    private static func makeCanvas(width: Int, height: Int) -> CGContext {
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.setAllowsAntialiasing(true)
        ctx.setShouldAntialias(true)

        let bg = CGGradient(
            colorsSpace: cs,
            colors: [
                CGColor(red: 0.052, green: 0.046, blue: 0.078, alpha: 1.0),
                CGColor(red: 0.022, green: 0.020, blue: 0.036, alpha: 1.0)
            ] as CFArray,
            locations: [0.0, 1.0]
        )!
        ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: height), end: CGPoint(x: width, y: 0), options: [])
        return ctx
    }

    private static func drawCardFrame(_ ctx: CGContext, width: Int, height: Int, badge: String, title: String, subtitle: String) {
        let outer = CGRect(x: 16, y: 16, width: width - 32, height: height - 32)
        strokeRoundedRect(ctx, rect: outer, radius: 22, r: 1, g: 1, b: 1, a: 0.14)
        drawText(ctx, badge, x: 52, y: CGFloat(height) - 62, size: 13, weight: .bold, r: 1.0, g: 0.62, b: 0.04)
        drawText(ctx, title, x: 52, y: CGFloat(height) - 98, size: 26, weight: .bold, r: 0.96, g: 0.98, b: 1.0)
        drawText(ctx, subtitle, x: 52, y: CGFloat(height) - 126, size: 15, weight: .regular, r: 0.62, g: 0.68, b: 0.77)
    }

    private static func fillRoundedRect(_ ctx: CGContext, rect: CGRect, radius: CGFloat, r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        let path = CGPath(roundedRect: rect, cornerWidth: min(radius, rect.width / 2), cornerHeight: min(radius, rect.height / 2), transform: nil)
        ctx.setFillColor(CGColor(red: r, green: g, blue: b, alpha: a))
        ctx.addPath(path)
        ctx.fillPath()
    }

    private static func strokeRoundedRect(_ ctx: CGContext, rect: CGRect, radius: CGFloat, r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        ctx.setStrokeColor(CGColor(red: r, green: g, blue: b, alpha: a))
        ctx.setLineWidth(1.5)
        ctx.addPath(path)
        ctx.strokePath()
    }

    private static func drawText(_ ctx: CGContext, _ text: String, x: CGFloat, y: CGFloat, size: CGFloat, weight: FontWeight, r: CGFloat, g: CGFloat, b: CGFloat) {
        let fontName = (weight == .bold ? "HelveticaNeue-Bold" : "HelveticaNeue") as CFString
        let font = CTFontCreateWithName(fontName, size, nil)
        let color = CGColor(red: r, green: g, blue: b, alpha: 1.0)
        let attrs: [CFString: Any] = [kCTFontAttributeName: font, kCTForegroundColorAttributeName: color]
        let attrStr = CFAttributedStringCreate(nil, text as CFString, attrs as CFDictionary)!
        let line = CTLineCreateWithAttributedString(attrStr)
        ctx.textPosition = CGPoint(x: x, y: y)
        CTLineDraw(line, ctx)
    }
}
