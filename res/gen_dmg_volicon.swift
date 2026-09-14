// Generates res/dmg-volume.icns (+ res/dmg-volume.png preview): a removable-drive shaped icon carrying the
// Horus eye, used as the installer dmg's volume icon by sign_mac.sh.
//   swift res/gen_dmg_volicon.swift
import AppKit

let eye = NSImage(contentsOfFile: "res/mac-icon.png")!
let outDir = "res"
let iconset = "\(NSTemporaryDirectory())dmg-volume.iconset"

func render(_ px: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    let s = CGFloat(px) / 1024 // design in a 1024 space
    ctx.scaleBy(x: s, y: s)

    // drive body: wide rounded slab, lit from the top
    let body = CGRect(x: 96, y: 236, width: 832, height: 552)
    let bodyPath = CGPath(roundedRect: body, cornerWidth: 72, cornerHeight: 72, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 40, color: NSColor.black.withAlphaComponent(0.35).cgColor)
    ctx.setFillColor(NSColor.white.cgColor); ctx.addPath(bodyPath); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState(); ctx.addPath(bodyPath); ctx.clip()
    let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: [NSColor(white: 0.98, alpha: 1).cgColor, NSColor(white: 0.84, alpha: 1).cgColor] as CFArray,
                          locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: body.maxY), end: CGPoint(x: 0, y: body.minY), options: [])
    // darker front face along the bottom edge
    ctx.setFillColor(NSColor(white: 0.62, alpha: 1).cgColor)
    ctx.fill(CGRect(x: body.minX, y: body.minY, width: body.width, height: 60))
    ctx.setFillColor(NSColor(white: 0.30, alpha: 1).cgColor) // slot
    ctx.fill(CGRect(x: body.minX + 130, y: body.minY + 22, width: body.width - 260, height: 10))
    ctx.restoreGState()
    ctx.setStrokeColor(NSColor(white: 0.45, alpha: 1).cgColor); ctx.setLineWidth(6)
    ctx.addPath(bodyPath); ctx.strokePath()
    // activity LED
    ctx.setFillColor(NSColor(calibratedRed: 0.20, green: 0.55, blue: 0.85, alpha: 1).cgColor)
    ctx.fillEllipse(in: CGRect(x: body.maxX - 96, y: body.minY + 86, width: 22, height: 22))

    // the Horus eye, centred on the upper face
    let eyeSize: CGFloat = 400
    let eyeRect = CGRect(x: 512 - eyeSize / 2, y: body.minY + 60 + (body.height - 60 - eyeSize) / 2, width: eyeSize, height: eyeSize)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 18, color: NSColor.black.withAlphaComponent(0.30).cgColor)
    eye.draw(in: eyeRect, from: .zero, operation: .sourceOver, fraction: 1)
    ctx.restoreGState()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

try? FileManager.default.removeItem(atPath: iconset)
try! FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)
for (name, px) in [("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64),
                   ("icon_128x128", 128), ("icon_128x128@2x", 256), ("icon_256x256", 256), ("icon_256x256@2x", 512),
                   ("icon_512x512", 512), ("icon_512x512@2x", 1024)] {
    let png = render(px).representation(using: .png, properties: [:])!
    try! png.write(to: URL(fileURLWithPath: "\(iconset)/\(name).png"))
}
try! render(1024).representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(outDir)/dmg-volume.png"))
let p = Process(); p.launchPath = "/usr/bin/iconutil"; p.arguments = ["-c", "icns", iconset, "-o", "\(outDir)/dmg-volume.icns"]
p.launch(); p.waitUntilExit()
print(p.terminationStatus == 0 ? "wrote \(outDir)/dmg-volume.icns and dmg-volume.png" : "iconutil failed")
