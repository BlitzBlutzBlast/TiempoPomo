// Draws PomTiempo's 1024px app icon: a Dusk-glass tile with the countdown
// ring, a focus arc and a break arc, and a little tomato stem on top.
// Usage: swift scripts/make_icon.swift Resources/AppIcon-1024.png
import AppKit

let output = CommandLine.arguments.dropFirst().first ?? "AppIcon-1024.png"
let size: CGFloat = 1024

func hex(_ s: String, _ alpha: CGFloat = 1) -> NSColor {
    var v: UInt64 = 0
    Scanner(string: String(s.dropFirst())).scanHexInt64(&v)
    return NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
                   blue: CGFloat(v & 0xFF) / 255, alpha: alpha)
}

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

// Tile: macOS icon grid, 824pt squircle centred in 1024.
let inset: CGFloat = 100
let tile = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
let tilePath = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)

ctx.saveGState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
shadow.shadowBlurRadius = 28
shadow.shadowOffset = NSSize(width: 0, height: -12)
shadow.set()
hex("#2A2050").setFill()
tilePath.fill()
ctx.restoreGState()

ctx.saveGState()
tilePath.addClip()
NSGradient(colors: [hex("#5A4290"), hex("#42316A"), hex("#141A33")])!.draw(in: tile, angle: -70)
// Glow of the focus colour behind the ring.
NSGradient(colors: [hex("#01B6E9", 0.35), hex("#01B6E9", 0)])!
    .draw(fromCenter: NSPoint(x: 512, y: 470), radius: 0, toCenter: NSPoint(x: 512, y: 470), radius: 380, options: [])
// Glass sheen across the top.
let sheen = NSBezierPath()
sheen.move(to: NSPoint(x: tile.minX, y: tile.maxY))
sheen.line(to: NSPoint(x: tile.maxX, y: tile.maxY))
sheen.line(to: NSPoint(x: tile.maxX, y: 700))
sheen.curve(to: NSPoint(x: tile.minX, y: 610), controlPoint1: NSPoint(x: 700, y: 610), controlPoint2: NSPoint(x: 400, y: 560))
sheen.close()
NSGradient(colors: [NSColor.white.withAlphaComponent(0.16), NSColor.white.withAlphaComponent(0.02)])!.draw(in: sheen, angle: -90)
ctx.restoreGState()

// Hairline edge.
hex("#FFFFFF", 0.14).setStroke()
tilePath.lineWidth = 3
tilePath.stroke()

// Ring.
let center = NSPoint(x: 512, y: 470)
let radius: CGFloat = 238
let line: CGFloat = 62

func arc(from start: CGFloat, to end: CGFloat, color: NSColor, width: CGFloat = line) {
    let p = NSBezierPath()
    // Clockwise from 12 o'clock: angles in degrees measured the AppKit way.
    p.appendArc(withCenter: center, radius: radius, startAngle: 90 - start, endAngle: 90 - end, clockwise: true)
    p.lineWidth = width
    p.lineCapStyle = .round
    color.setStroke()
    p.stroke()
}

arc(from: 0, to: 359.9, color: hex("#FFFFFF", 0.10))
ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 40, color: hex("#01B6E9", 0.9).cgColor)
arc(from: 0, to: 245, color: hex("#01B6E9"))
ctx.restoreGState()
ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 30, color: hex("#BA88E7", 0.8).cgColor)
arc(from: 275, to: 330, color: hex("#BA88E7"))
ctx.restoreGState()

// Stem and leaves at 12 o'clock, a nod to the tomato.
let top = NSPoint(x: center.x, y: center.y + radius + line / 2 - 6)
hex("#84BF39").setFill()
for (dx, rot) in [(-1.0, 28.0), (1.0, -28.0)] {
    let leaf = NSBezierPath(ovalIn: NSRect(x: -70, y: -24, width: 140, height: 48))
    var t = AffineTransform(translationByX: top.x + CGFloat(dx) * 62, byY: top.y + 26)
    t.rotate(byDegrees: CGFloat(rot))
    leaf.transform(using: t)
    leaf.fill()
}
let stem = NSBezierPath(roundedRect: NSRect(x: top.x - 13, y: top.y + 10, width: 26, height: 80), xRadius: 13, yRadius: 13)
hex("#6FA52E").setFill()
stem.fill()

// Centre: a soft hand pointing to where the focus arc ends.
let dot = NSBezierPath(ovalIn: NSRect(x: center.x - 30, y: center.y - 30, width: 60, height: 60))
hex("#DFE5F4").setFill()
dot.fill()

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
print("wrote \(output)")
