import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum AxonIconGenerator {
    static func generateIconSet(iconsetURL: URL, docsIconURL: URL) throws {
        try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: docsIconURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        let sizes: [(String, Int)] = [
            ("icon_16x16.png", 16),
            ("icon_16x16@2x.png", 32),
            ("icon_32x32.png", 32),
            ("icon_32x32@2x.png", 64),
            ("icon_128x128.png", 128),
            ("icon_128x128@2x.png", 256),
            ("icon_256x256.png", 256),
            ("icon_256x256@2x.png", 512),
            ("icon_512x512.png", 512),
            ("icon_512x512@2x.png", 1024)
        ]

        for (name, px) in sizes {
            try writePNG(renderIcon(size: px), to: iconsetURL.appendingPathComponent(name))
        }
        try writePNG(renderIcon(size: 256), to: docsIconURL)
    }

    static func renderIcon(size: Int) -> CGImage {
        let s = CGFloat(size)
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size * 4,
            space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.setAllowsAntialiasing(true)
        ctx.setShouldAntialias(true)

        let inset = s * 0.08
        let rect = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
        let radius = rect.width * 0.225
        let squircle = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

        ctx.saveGState()
        ctx.addPath(squircle)
        ctx.clip()

        let bgGrad = CGGradient(
            colorsSpace: cs,
            colors: [
                CGColor(red: 0.11, green: 0.095, blue: 0.145, alpha: 1.0),
                CGColor(red: 0.05, green: 0.045, blue: 0.075, alpha: 1.0),
                CGColor(red: 0.025, green: 0.022, blue: 0.042, alpha: 1.0)
            ] as CFArray,
            locations: [0.0, 0.5, 1.0]
        )!
        ctx.drawLinearGradient(bgGrad, start: CGPoint(x: rect.minX, y: rect.maxY), end: CGPoint(x: rect.maxX, y: rect.minY), options: [])

        // Amber top-left glow
        let amberGlow = CGGradient(
            colorsSpace: cs,
            colors: [
                CGColor(red: 1.0, green: 0.62, blue: 0.04, alpha: 0.34),
                CGColor(red: 1.0, green: 0.62, blue: 0.04, alpha: 0.0)
            ] as CFArray,
            locations: [0.0, 1.0]
        )!
        ctx.drawRadialGradient(amberGlow, startCenter: CGPoint(x: s * 0.32, y: s * 0.68), startRadius: 0, endCenter: CGPoint(x: s * 0.32, y: s * 0.68), endRadius: s * 0.5, options: [])

        // Cyan bottom-right glow
        let cyanGlow = CGGradient(
            colorsSpace: cs,
            colors: [
                CGColor(red: 0.39, green: 0.82, blue: 1.0, alpha: 0.30),
                CGColor(red: 0.39, green: 0.82, blue: 1.0, alpha: 0.0)
            ] as CFArray,
            locations: [0.0, 1.0]
        )!
        ctx.drawRadialGradient(cyanGlow, startCenter: CGPoint(x: s * 0.72, y: s * 0.30), startRadius: 0, endCenter: CGPoint(x: s * 0.72, y: s * 0.30), endRadius: s * 0.48, options: [])

        // Glass top sheen
        let sheen = CGGradient(
            colorsSpace: cs,
            colors: [CGColor(red: 1, green: 1, blue: 1, alpha: 0.14), CGColor(red: 1, green: 1, blue: 1, alpha: 0)] as CFArray,
            locations: [0.0, 1.0]
        )!
        ctx.drawLinearGradient(sheen, start: CGPoint(x: s * 0.5, y: rect.maxY), end: CGPoint(x: s * 0.5, y: rect.midY), options: [])

        // 3 connected semantic workflow graph nodes
        let n1 = CGPoint(x: s * 0.30, y: s * 0.64)
        let n2 = CGPoint(x: s * 0.70, y: s * 0.62)
        let n3 = CGPoint(x: s * 0.50, y: s * 0.30)

        // Luminous connecting flow curves
        ctx.setLineWidth(max(1.5, s * 0.032))
        ctx.setLineCap(.round)
        ctx.setStrokeColor(CGColor(red: 1.0, green: 0.75, blue: 0.30, alpha: 0.88))
        ctx.move(to: n1)
        ctx.addQuadCurve(to: n2, control: CGPoint(x: s * 0.50, y: s * 0.78))
        ctx.strokePath()

        ctx.setStrokeColor(CGColor(red: 0.39, green: 0.82, blue: 1.0, alpha: 0.90))
        ctx.move(to: n2)
        ctx.addQuadCurve(to: n3, control: CGPoint(x: s * 0.68, y: s * 0.40))
        ctx.strokePath()

        ctx.setStrokeColor(CGColor(red: 0.19, green: 0.82, blue: 0.35, alpha: 0.85))
        ctx.move(to: n1)
        ctx.addQuadCurve(to: n3, control: CGPoint(x: s * 0.32, y: s * 0.40))
        ctx.strokePath()

        // Draw glowing nodes
        let nodes: [(CGPoint, CGColor)] = [
            (n1, CGColor(red: 1.0, green: 0.62, blue: 0.04, alpha: 1.0)),
            (n2, CGColor(red: 0.39, green: 0.82, blue: 1.0, alpha: 1.0)),
            (n3, CGColor(red: 0.19, green: 0.82, blue: 0.35, alpha: 1.0))
        ]
        for (pt, color) in nodes {
            let rOuter = s * 0.088
            let rInner = s * 0.045
            ctx.setFillColor(color)
            ctx.fillEllipse(in: CGRect(x: pt.x - rOuter, y: pt.y - rOuter, width: rOuter * 2, height: rOuter * 2))
            ctx.setFillColor(CGColor(red: 0.97, green: 0.99, blue: 1.0, alpha: 1.0))
            ctx.fillEllipse(in: CGRect(x: pt.x - rInner, y: pt.y - rInner, width: rInner * 2, height: rInner * 2))
        }

        ctx.restoreGState()

        ctx.addPath(squircle)
        ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.24))
        ctx.setLineWidth(max(1.0, s * 0.012))
        ctx.strokePath()

        return ctx.makeImage()!
    }

    static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw NSError(domain: "AxonFlowTools.PNG", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to open PNG destination"])
        }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else {
            throw NSError(domain: "AxonFlowTools.PNG", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to write PNG"])
        }
    }
}
