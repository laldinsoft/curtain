// Draws Curtain's app icon at 1024 × 1024: two closed velvet drapes under a scalloped valance, on the
// macOS icon grid, with a warm line of light under the hem (the Mac is still on behind them).
// Usage: swift icon/make-icon.swift out.png
import AppKit

let size: CGFloat = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let cg = NSGraphicsContext.current!.cgContext

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255, blue: CGFloat(hex & 0xff) / 255, alpha: a)
}
func linear(_ colors: [NSColor], _ locations: [CGFloat], from: CGPoint, to: CGPoint) {
    let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors.map(\.cgColor) as CFArray, locations: locations)!
    cg.drawLinearGradient(g, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

// macOS grid: an 824-point body inset 100, corner radius about 22.5 %, with a soft drop shadow.
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let shape = NSBezierPath(roundedRect: body, xRadius: 186, yRadius: 186)
cg.saveGState()
cg.setShadow(offset: CGSize(width: 0, height: -10), blur: 28, color: NSColor.black.withAlphaComponent(0.35).cgColor)
rgb(0x0b0c14).setFill(); shape.fill()
cg.restoreGState()
cg.saveGState()
shape.addClip()

// Night behind everything.
linear([rgb(0x262a45), rgb(0x0b0c14)], [0, 1], from: CGPoint(x: 0, y: body.maxY), to: CGPoint(x: 0, y: body.minY))

// The stage floor and the light leaking under the drapes.
let hem: CGFloat = 250                     // y of the drapes' lower edge
let floor = CGRect(x: body.minX, y: body.minY, width: body.width, height: hem - body.minY)
cg.saveGState(); cg.clip(to: floor)
linear([rgb(0x15121a), rgb(0x07070b)], [0, 1], from: CGPoint(x: 0, y: hem), to: CGPoint(x: 0, y: body.minY))
let glow = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                      colors: [rgb(0xffc56b, 0.95).cgColor, rgb(0xff9a3c, 0.35).cgColor, rgb(0xff9a3c, 0).cgColor] as CFArray,
                      locations: [0, 0.35, 1])!
cg.saveGState()
cg.translateBy(x: 512, y: hem); cg.scaleBy(x: 1, y: 0.22)
cg.drawRadialGradient(glow, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: 380, options: [])
cg.restoreGState()
cg.restoreGState()

// The drapes: velvet folds, each a dark–light–dark band, with a rounded hem per fold.
let top: CGFloat = 790
let folds = 5
func drape(from x0: CGFloat, to x1: CGFloat, mirrored: Bool) {
    let w = (x1 - x0) / CGFloat(folds)
    for i in 0..<folds {
        let x = x0 + CGFloat(i) * w
        let path = NSBezierPath()
        path.move(to: CGPoint(x: x, y: top))
        path.line(to: CGPoint(x: x + w, y: top))
        path.line(to: CGPoint(x: x + w, y: hem + 14))
        path.curve(to: CGPoint(x: x, y: hem + 14), controlPoint1: CGPoint(x: x + w * 0.75, y: hem - 16), controlPoint2: CGPoint(x: x + w * 0.25, y: hem - 16))
        path.close()
        cg.saveGState(); path.addClip()
        // Folds nearer the seam catch a little more light.
        let nearSeam = mirrored ? CGFloat(i) / CGFloat(folds - 1) : 1 - CGFloat(i) / CGFloat(folds - 1)
        let lit = rgb(0xd8344a).blended(withFraction: 0.18 * nearSeam, of: rgb(0xff6a5c))!
        linear([rgb(0x4a0912), lit, rgb(0x9c1a2c), rgb(0x3a0610)], [0, 0.42, 0.7, 1],
               from: CGPoint(x: x, y: 0), to: CGPoint(x: x + w, y: 0))
        // Velvet darkens toward the top under the valance and toward the floor.
        linear([NSColor.black.withAlphaComponent(0.35), NSColor.black.withAlphaComponent(0), NSColor.black.withAlphaComponent(0.25)],
               [0, 0.35, 1], from: CGPoint(x: 0, y: top), to: CGPoint(x: 0, y: hem - 20))
        cg.restoreGState()
    }
}
drape(from: body.minX - 4, to: 512, mirrored: false)
drape(from: 512, to: body.maxX + 4, mirrored: true)
// The seam where the two drapes meet.
cg.saveGState()
let seam = NSBezierPath(rect: CGRect(x: 509, y: hem, width: 6, height: top - hem))
NSColor.black.withAlphaComponent(0.55).setFill(); seam.fill()
cg.restoreGState()

// The valance: a band across the top with three swags and a gold cord along its edge.
let swags = 3
let valanceBottom: CGFloat = 742
let valance = NSBezierPath()
valance.move(to: CGPoint(x: body.minX - 10, y: body.maxY + 10))
valance.line(to: CGPoint(x: body.maxX + 10, y: body.maxY + 10))
valance.line(to: CGPoint(x: body.maxX + 10, y: valanceBottom + 20))
let sw = (body.width + 20) / CGFloat(swags)
for i in (0..<swags).reversed() {
    let xr = body.minX - 10 + CGFloat(i + 1) * sw, xl = xr - sw
    valance.curve(to: CGPoint(x: xl, y: valanceBottom + 20), controlPoint1: CGPoint(x: xr - sw * 0.2, y: valanceBottom - 40), controlPoint2: CGPoint(x: xl + sw * 0.2, y: valanceBottom - 40))
}
valance.close()
cg.saveGState()
cg.setShadow(offset: CGSize(width: 0, height: -8), blur: 18, color: NSColor.black.withAlphaComponent(0.55).cgColor)
rgb(0x5a0b16).setFill(); valance.fill()
cg.restoreGState()
cg.saveGState(); valance.addClip()
linear([rgb(0x8e1626), rgb(0x5a0b16), rgb(0x3d0710)], [0, 0.6, 1], from: CGPoint(x: 0, y: body.maxY), to: CGPoint(x: 0, y: valanceBottom - 20))
cg.restoreGState()
// Gold cord along the swags.
let cord = NSBezierPath()
cord.move(to: CGPoint(x: body.minX - 10, y: valanceBottom + 20))
for i in 0..<swags {
    let xl = body.minX - 10 + CGFloat(i) * sw, xr = xl + sw
    cord.curve(to: CGPoint(x: xr, y: valanceBottom + 20), controlPoint1: CGPoint(x: xl + sw * 0.2, y: valanceBottom - 40), controlPoint2: CGPoint(x: xr - sw * 0.2, y: valanceBottom - 40))
}
cord.lineWidth = 12
cord.lineCapStyle = .round
cg.saveGState()
cg.setShadow(offset: CGSize(width: 0, height: -3), blur: 6, color: NSColor.black.withAlphaComponent(0.5).cgColor)
rgb(0xd9a441).setStroke(); cord.stroke()
cg.restoreGState()
cord.lineWidth = 4
rgb(0xffe1a0, 0.8).setStroke(); cord.stroke()

// A faint sheen across the top of the body, as on Apple's icons.
linear([NSColor.white.withAlphaComponent(0.10), NSColor.white.withAlphaComponent(0)], [0, 1],
       from: CGPoint(x: 0, y: body.maxY), to: CGPoint(x: 0, y: body.maxY - 260))
cg.restoreGState()

// A hairline edge to keep the shape crisp on dark menus and docks.
shape.lineWidth = 2
NSColor.white.withAlphaComponent(0.08).setStroke(); shape.stroke()

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
