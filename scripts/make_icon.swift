// Draws Tiempo Pomo's app icon: a tomato whose outline is a progress ring,
// turned slightly to one side, with a clock at 10:10 inside, on a violet
// tile. Flat, geometric and round throughout.
//
// Small sizes are drawn separately rather than shrunk: at 64 px the eight
// ticks become four, at 32 px they go and the hands thicken, and at 16 px
// only the tomato and its leaves remain.
//
// Usage: swift scripts/make_icon.swift <output-dir>
//   writes <output-dir>/AppIcon.iconset/*.png, AppIcon-1024.png and preview.png
import AppKit

let outDir = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? ".")
let iconset = outDir.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func color(_ hex: String, _ alpha: CGFloat = 1) -> CGColor {
    var v: UInt64 = 0
    Scanner(string: String(hex.dropFirst())).scanHexInt64(&v)
    return CGColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
                   blue: CGFloat(v & 0xFF) / 255, alpha: alpha)
}

enum Palette {
    static let tileTop = color("#54469A")
    static let tileBottom = color("#483B80")
    static let tile = color("#4E4088")
    static let track = color("#7567B5")
    static let trackSide = color("#3A2E6E")
    static let ring = color("#E8543F")
    static let ringSide = color("#A63526")
    static let cream = color("#FFF4E8")
    static let leaf = color("#84BF39")
    static let leafSide = color("#5E8F2A")
}

/// How much to draw at a given pixel size.
struct Detail {
    var ticks: Int          // 8, 4 or 0
    var hands: Bool
    var hub: Bool
    var leaves: Int         // 5, 3 or 2
    var weight: CGFloat     // stroke multiplier, heavier when small
    var side: Bool          // the ring's visible depth

    static func forPixels(_ px: Int) -> Detail {
        switch px {
        case ..<24: return Detail(ticks: 0, hands: false, hub: false, leaves: 2, weight: 1.75, side: false)
        case ..<48: return Detail(ticks: 0, hands: true, hub: false, leaves: 2, weight: 1.35, side: true)
        case ..<96: return Detail(ticks: 4, hands: true, hub: false, leaves: 3, weight: 1.15, side: true)
        default:    return Detail(ticks: 8, hands: true, hub: true, leaves: 5, weight: 1, side: true)
        }
    }
}

// The tomato in its own units: a squat circle with a notch at the top.
// The full outline is the track; the open path (missing the upper-left
// curve back to the notch) is the progress.
func tomato(closed: Bool) -> CGPath {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: 0, y: -30))
    p.addCurve(to: CGPoint(x: 50, y: -6), control1: CGPoint(x: 18, y: -42), control2: CGPoint(x: 48, y: -34))
    p.addCurve(to: CGPoint(x: 0, y: 44), control1: CGPoint(x: 52, y: 24), control2: CGPoint(x: 28, y: 44))
    p.addCurve(to: CGPoint(x: -50, y: -6), control1: CGPoint(x: -28, y: 44), control2: CGPoint(x: -52, y: 24))
    if closed {
        p.addCurve(to: CGPoint(x: 0, y: -30), control1: CGPoint(x: -48, y: -34), control2: CGPoint(x: -18, y: -42))
        p.closeSubpath()
    }
    return p
}

func stroke(_ ctx: CGContext, _ path: CGPath, _ c: CGColor, _ width: CGFloat) {
    ctx.addPath(path)
    ctx.setStrokeColor(c)
    ctx.setLineWidth(width)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.strokePath()
}

func line(_ ctx: CGContext, _ a: CGPoint, _ b: CGPoint, _ c: CGColor, _ width: CGFloat) {
    let p = CGMutablePath()
    p.move(to: a)
    p.addLine(to: b)
    stroke(ctx, p, c, width)
}

/// The calyx: two leaves sweeping out over the shoulders and, when there's
/// room, a short curved stem between them. All arcs, all round ends.
func leaves(_ count: Int) -> CGPath {
    let p = CGMutablePath()
    let base = CGPoint(x: 0, y: -32)
    p.move(to: base)
    p.addQuadCurve(to: CGPoint(x: -17, y: -38), control: CGPoint(x: -7, y: -45))
    p.move(to: base)
    p.addQuadCurve(to: CGPoint(x: 17, y: -38), control: CGPoint(x: 7, y: -45))
    if count >= 3 {
        p.move(to: base)
        p.addQuadCurve(to: CGPoint(x: 5, y: -49), control: CGPoint(x: 0, y: -43))
    }
    return p
}

func render(pixels: Int) -> NSBitmapImageRep {
    let d = Detail.forPixels(pixels)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    let k = CGFloat(pixels) / 1024

    // Work top-down in a 1024 canvas, like the mockups.
    ctx.translateBy(x: 0, y: CGFloat(pixels))
    ctx.scaleBy(x: k, y: -k)
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high

    // Tile: macOS icon grid, 824 pt continuous-corner square.
    let tileRect = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tile = CGPath(roundedRect: tileRect, cornerWidth: 185, cornerHeight: 185, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10 * k), blur: 26 * k, color: CGColor(gray: 0, alpha: 0.32))
    ctx.addPath(tile)
    ctx.setFillColor(Palette.tile)
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(tile)
    ctx.clip()
    let shade = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [Palette.tileTop, Palette.tileBottom] as CFArray,
                           locations: [0, 1])!
    ctx.drawLinearGradient(shade, start: CGPoint(x: 512, y: 100), end: CGPoint(x: 512, y: 924), options: [])
    // A whisper of light from the upper left.
    let light = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                           colors: [CGColor(gray: 1, alpha: 0.07), CGColor(gray: 1, alpha: 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(light, startCenter: CGPoint(x: 360, y: 240), startRadius: 0,
                           endCenter: CGPoint(x: 360, y: 240), endRadius: 620, options: [])
    ctx.restoreGState()

    // Hairline edge, as on Apple's icons.
    if pixels >= 64 {
        let inner = CGPath(roundedRect: tileRect.insetBy(dx: 1.5, dy: 1.5), cornerWidth: 183.5, cornerHeight: 183.5, transform: nil)
        stroke(ctx, inner, CGColor(gray: 1, alpha: 0.10), 3)
    }

    // The tomato: centred on the tile (its full extent, leaves and depth
    // included), turned slightly to the right.
    // Size of the tomato on the tile. ICON_SCALE overrides it for trying sizes.
    let unit = CGFloat(Double(ProcessInfo.processInfo.environment["ICON_SCALE"] ?? "") ?? 6.21)
    ctx.saveGState()
    // Offsets that centre the artwork's full extent; they grow with it.
    ctx.translateBy(x: 512 - 11 * unit / 4.85, y: 512 - 2 * unit / 4.85)
    ctx.concatenate(CGAffineTransform(a: 0.86, b: -0.1, c: 0.03, d: 1, tx: 0, ty: 0))
    ctx.scaleBy(x: unit, y: unit)

    let w = 12 * d.weight
    let full = tomato(closed: true)
    let open = tomato(closed: false)

    // Depth: the ring's side, seen past its front edge, with a soft shadow
    // falling on the tile.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 4 * k, height: -16 * k), blur: 40 * k, color: CGColor(gray: 0, alpha: 0.28))
    ctx.translateBy(x: 5, y: 3.5)
    if d.side {
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        stroke(ctx, full, Palette.trackSide, w)
        stroke(ctx, open, Palette.ringSide, w)
        ctx.endTransparencyLayer()
    } else {
        stroke(ctx, full, CGColor(gray: 0, alpha: 0.001), w)
    }
    ctx.restoreGState()

    // Front of the ring: the track, then the progress over it.
    stroke(ctx, full, Palette.track, w)
    stroke(ctx, open, Palette.ring, w)

    // The clock sits midway between the notch's inner edge and the bottom.
    ctx.translateBy(x: 0, y: 7)
    if d.ticks > 0 {
        let tickColor = Palette.cream.copy(alpha: 0.88)!
        for i in 0..<d.ticks {
            let a = Double(i) / Double(d.ticks) * 2 * .pi
            let outer = CGPoint(x: 25 * sin(a), y: -25 * cos(a))
            let inner = CGPoint(x: 19 * sin(a), y: -19 * cos(a))
            line(ctx, inner, outer, tickColor, 3 * d.weight)
        }
    }
    if d.hands {
        // 10:10. Hour hand short and heavy, minute hand long and lighter.
        let hour = Double(305) * .pi / 180, minute = Double(60) * .pi / 180
        line(ctx, .zero, CGPoint(x: 10 * sin(hour), y: -10 * cos(hour)), Palette.cream, 3.8 * d.weight)
        line(ctx, .zero, CGPoint(x: 14 * sin(minute), y: -14 * cos(minute)), Palette.cream, 3.2 * d.weight)
    }
    if d.hub {
        ctx.setFillColor(Palette.cream)
        ctx.fillEllipse(in: CGRect(x: -3.2, y: -3.2, width: 6.4, height: 6.4))
        ctx.setFillColor(Palette.ring)
        ctx.fillEllipse(in: CGRect(x: -1.3, y: -1.3, width: 2.6, height: 2.6))
    }
    ctx.translateBy(x: 0, y: -7)

    // Leaves: flat, in front, with the same depth as the ring underneath.
    let calyx = leaves(d.leaves)
    if d.side {
        ctx.saveGState()
        ctx.translateBy(x: 1.2, y: 1)
        stroke(ctx, calyx, Palette.leafSide, 4.6 * d.weight)
        ctx.restoreGState()
    }
    stroke(ctx, calyx, Palette.leaf, 4.6 * d.weight)

    ctx.restoreGState()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func save(_ rep: NSBitmapImageRep, _ url: URL) throws {
    try rep.representation(using: .png, properties: [:])!.write(to: url)
}

let sizes: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256), ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
var cache: [Int: NSBitmapImageRep] = [:]
for (name, px) in sizes {
    let rep = cache[px] ?? render(pixels: px)
    cache[px] = rep
    try save(rep, iconset.appendingPathComponent("\(name).png"))
}
try save(cache[1024]!, outDir.appendingPathComponent("AppIcon-1024.png"))

// Preview sheet: the icon large, then the Dock and Finder sizes on light and
// dark backgrounds, each size drawn from its own tuned render.
let sheet = NSImage(size: NSSize(width: 1400, height: 760), flipped: true) { _ in
    NSColor(srgbRed: 0.96, green: 0.95, blue: 0.97, alpha: 1).setFill()
    NSRect(x: 0, y: 0, width: 1400, height: 760).fill()
    NSColor(srgbRed: 0.11, green: 0.11, blue: 0.12, alpha: 1).setFill()
    NSRect(x: 760, y: 0, width: 640, height: 760).fill()
    func draw(_ px: Int, _ x: CGFloat, _ y: CGFloat, _ points: CGFloat) {
        let img = NSImage(size: NSSize(width: px, height: px))
        img.addRepresentation(cache[px] ?? render(pixels: px))
        img.draw(in: NSRect(x: x, y: y, width: points, height: points), from: .zero, operation: .sourceOver,
                 fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
    }
    draw(1024, 20, 20, 720)
    for (i, bg) in [CGFloat(800), 1100].enumerated() {
        _ = i
        draw(256, bg, 60, 256)
        draw(128, bg, 360, 128)
        draw(64, bg + 150, 392, 64)
        draw(32, bg, 540, 32)
        draw(32, bg + 60, 540, 32)
        draw(16, bg + 120, 548, 16)
        draw(64, bg, 620, 64)
    }
    return true
}
let sheetRep = NSBitmapImageRep(data: sheet.tiffRepresentation!)!
try save(sheetRep, outDir.appendingPathComponent("preview.png"))
print("wrote \(iconset.path), AppIcon-1024.png, preview.png")
