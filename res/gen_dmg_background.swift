// Generates res/dmg-background.png: the Finder window background for the macOS installer dmg.
// Layout matches sign_mac.sh: window 800x400 pt, app icon centred at (200,190), Applications link at (600,185).
// Rendered at 2x (1600x800 px) and tagged 144 dpi so Finder shows it crisp on Retina at 800x400 pt.
//   swift res/gen_dmg_background.swift
import AppKit

let scale: CGFloat = 2
let w = 800 * scale, h = 400 * scale
let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "res/dmg-background.png")

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(w), pixelsHigh: Int(h), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext
ctx.scaleBy(x: scale, y: scale)
// Finder coordinates are top-left based; flip so y grows downwards like create-dmg's --icon x y.
ctx.translateBy(x: 0, y: 400); ctx.scaleBy(x: 1, y: -1)

// background
ctx.setFillColor(NSColor(calibratedWhite: 0.97, alpha: 1).cgColor)
ctx.fill(CGRect(x: 0, y: 0, width: 800, height: 400))

// arrow between the two icons (icons are 100 pt wide, centred at x=200 and x=600)
let y: CGFloat = 190, x0: CGFloat = 300, x1: CGFloat = 500, head: CGFloat = 26, thick: CGFloat = 8
let arrow = CGMutablePath()
arrow.move(to: CGPoint(x: x0, y: y - thick / 2))
arrow.addLine(to: CGPoint(x: x1 - head, y: y - thick / 2))
arrow.addLine(to: CGPoint(x: x1 - head, y: y - head * 0.75))
arrow.addLine(to: CGPoint(x: x1, y: y))
arrow.addLine(to: CGPoint(x: x1 - head, y: y + head * 0.75))
arrow.addLine(to: CGPoint(x: x1 - head, y: y + thick / 2))
arrow.addLine(to: CGPoint(x: x0, y: y + thick / 2))
arrow.closeSubpath()
ctx.setFillColor(NSColor(calibratedRed: 0.20, green: 0.55, blue: 0.85, alpha: 1).cgColor)
ctx.addPath(arrow); ctx.fillPath()

// caption (drawn un-flipped so the text is upright)
ctx.saveGState()
ctx.translateBy(x: 0, y: 400); ctx.scaleBy(x: 1, y: -1)
let para = NSMutableParagraphStyle(); para.alignment = .center
let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 15, weight: .medium),
    .foregroundColor: NSColor(calibratedWhite: 0.45, alpha: 1),
    .paragraphStyle: para,
]
NSAttributedString(string: "Drag HorusRD to the Applications folder to install", attributes: attrs)
    .draw(in: CGRect(x: 100, y: 400 - 330 - 20, width: 600, height: 24))
ctx.restoreGState()

NSGraphicsContext.restoreGraphicsState()
rep.size = NSSize(width: 800, height: 400) // point size of the 1600x800 bitmap -> 144 dpi metadata
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: out)
print("wrote \(out.path) \(Int(w))x\(Int(h)) px @ 144 dpi")
