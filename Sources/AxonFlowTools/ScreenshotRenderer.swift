import AppKit
import AxonFlowUI
import CoreGraphics
import Foundation
import SwiftUI

@MainActor
enum AxonScreenshotRenderer {
    static func renderAll(outputDir: URL) throws {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)

        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        let studioImg = try renderCard(tab: .studio)
        let batchImg = try renderCard(tab: .batch)
        let libraryImg = try renderCard(tab: .library)
        let safetyImg = try renderCard(tab: .safety)

        try AxonIconGenerator.writePNG(studioImg, to: outputDir.appendingPathComponent("studio.png"))
        try AxonIconGenerator.writePNG(batchImg, to: outputDir.appendingPathComponent("batch.png"))
        try AxonIconGenerator.writePNG(libraryImg, to: outputDir.appendingPathComponent("library.png"))
        try AxonIconGenerator.writePNG(safetyImg, to: outputDir.appendingPathComponent("safety.png"))

        let hero = try renderHeroBanner(studio: studioImg, batch: batchImg, library: libraryImg)
        try AxonIconGenerator.writePNG(hero, to: outputDir.appendingPathComponent("hero.png"))
    }

    private static func renderCard(tab: AxonTab) throws -> CGImage {
        let state = AxonAppState.demo(tab: tab)
        let framed = RootAxonView(state: state, width: 510)
            .padding(24)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.032, green: 0.030, blue: 0.048),
                        Color(red: 0.015, green: 0.015, blue: 0.025)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

        let renderer = ImageRenderer(content: framed)
        renderer.scale = 2.0
        guard let cg = renderer.cgImage else {
            throw NSError(domain: "AxonFlowTools.Screenshot", code: 1, userInfo: [NSLocalizedDescriptionKey: "ImageRenderer returned nil for \(tab.rawValue)"])
        }
        return cg
    }

    private static func renderHeroBanner(studio: CGImage, batch: CGImage, library: CGImage) throws -> CGImage {
        let heroView = ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.030, green: 0.028, blue: 0.046),
                    Color(red: 0.014, green: 0.014, blue: 0.024)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [AxonTheme.amber.opacity(0.20), Color.clear],
                center: UnitPoint(x: 0.22, y: 0.20),
                startRadius: 20,
                endRadius: 560
            )
            RadialGradient(
                colors: [AxonTheme.cyan.opacity(0.16), Color.clear],
                center: UnitPoint(x: 0.80, y: 0.80),
                startRadius: 20,
                endRadius: 560
            )

            VStack(spacing: 26) {
                HStack(spacing: 12) {
                    Text("AXON FLOW")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(AxonTheme.amber)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(AxonTheme.amber.opacity(0.14))
                                .overlay(Capsule().strokeBorder(AxonTheme.amber.opacity(0.45), lineWidth: 1))
                        )
                    Text("Record Once · Semantic AX Selectors (Window-Move Immune) · CSV Batch Replay")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AxonTheme.textSecondary)
                }

                HStack(alignment: .center, spacing: 24) {
                    panelPreview(image: studio, caption: "Semantic Macro Studio (⌘1)")
                    panelPreview(image: batch, caption: "CSV Batch Replay Engine (⌘2)")
                    panelPreview(image: library, caption: "Workflow Library & ROI (⌘3)")
                }
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 34)
        }
        .frame(width: 1640, height: 880)
        .preferredColorScheme(.dark)

        let renderer = ImageRenderer(content: heroView)
        renderer.scale = 2.0
        guard let cg = renderer.cgImage else {
            throw NSError(domain: "AxonFlowTools.Screenshot", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to render hero banner"])
        }
        return cg
    }

    private static func panelPreview(image: CGImage, caption: String) -> some View {
        VStack(spacing: 10) {
            Image(decorative: image, scale: 2.0)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 495)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.65), radius: 24, x: 0, y: 14)

            Text(caption)
                .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(AxonTheme.textSecondary)
        }
    }
}
