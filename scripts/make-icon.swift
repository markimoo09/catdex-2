// Renders the CatDex Maison app icon (1024×1024, Pearl theme) on the host Mac.
// Usage: swift scripts/make-icon.swift CatDex/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png
import AppKit
import CoreGraphics

let outPath = CommandLine.arguments.dropFirst().first ?? "AppIcon.png"
let size = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

// Flip to a top-left origin so the coordinates below read like a design file.
ctx.translateBy(x: 0, y: CGFloat(size))
ctx.scaleBy(x: 1, y: -1)

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

let center = CGPoint(x: 512, y: 512)

// Pearl field washing into blush.
let field = CGGradient(colorsSpace: space, colors: [rgb(0xFFFBF7), rgb(0xF8E7DF), rgb(0xEFE3EF)] as CFArray,
                       locations: [0, 0.6, 1])!
ctx.drawRadialGradient(field, startCenter: center, startRadius: 0, endCenter: center, endRadius: 760, options: [])

// Guilloche rosette — the engraving pattern on banknotes and watch dials.
ctx.setLineWidth(1.2)
for ring in 0..<3 {
    let base = 300.0 + Double(ring) * 70
    for i in 0..<14 {
        let phase = Double(i) / 14 * .pi * 2 / 12
        let path = CGMutablePath()
        for step in 0...720 {
            let t = Double(step) / 720 * .pi * 2
            let r = base + 14 * sin(12 * t + phase) + 4 * sin(36 * t - phase * 2)
            let p = CGPoint(x: 512 + r * cos(t), y: 512 + r * sin(t))
            step == 0 ? path.move(to: p) : path.addLine(to: p)
        }
        path.closeSubpath()
        ctx.addPath(path)
        ctx.setStrokeColor(rgb(0xD4927E, 0.16))
        ctx.strokePath()
    }
}

// Double hairline ring.
ctx.setStrokeColor(rgb(0xD4927E, 0.85))
ctx.setLineWidth(4)
ctx.strokeEllipse(in: CGRect(x: 512 - 430, y: 512 - 430, width: 860, height: 860))
ctx.setLineWidth(1.5)
ctx.strokeEllipse(in: CGRect(x: 512 - 410, y: 512 - 410, width: 820, height: 820))

// Cat head silhouette: a soft head plus two ears, filled as one shape.
let head = CGMutablePath()
head.addEllipse(in: CGRect(x: 512 - 230, y: 420, width: 460, height: 360))
func ear(_ pts: [CGPoint]) {
    head.move(to: pts[0])
    head.addQuadCurve(to: pts[2], control: pts[1])
    head.addLine(to: pts[3])
    head.closeSubpath()
}
ear([CGPoint(x: 300, y: 560), CGPoint(x: 300, y: 300), CGPoint(x: 352, y: 268), CGPoint(x: 470, y: 440)])
// The right ear mirrors the left, so it is wound in reverse to keep the union solid.
head.move(to: CGPoint(x: 554, y: 440))
head.addLine(to: CGPoint(x: 672, y: 268))
head.addQuadCurve(to: CGPoint(x: 724, y: 560), control: CGPoint(x: 724, y: 300))
head.closeSubpath()

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: 18), blur: 40, color: rgb(0x8A5A50, 0.35))
ctx.addPath(head)
ctx.setFillColor(rgb(0xD4927E))
ctx.fillPath(using: .winding)
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(head)
ctx.clip(using: .winding)
let gold = CGGradient(colorsSpace: space,
                      colors: [rgb(0xF8DCCD), rgb(0xE5A893), rgb(0xC27F6A), rgb(0xDA9984), rgb(0xF4D0C0)] as CFArray,
                      locations: [0, 0.3, 0.55, 0.78, 1])!
ctx.drawLinearGradient(gold, start: CGPoint(x: 280, y: 260), end: CGPoint(x: 760, y: 800), options: [])
ctx.restoreGState()

// Serene closed eyes and a small nose, engraved into the gold.
ctx.setStrokeColor(rgb(0x4A2E36, 0.9))
ctx.setLineWidth(14)
ctx.setLineCap(.round)
for x in [418.0, 606.0] {
    let eye = CGMutablePath()
    eye.move(to: CGPoint(x: x - 46, y: 588))
    eye.addQuadCurve(to: CGPoint(x: x + 46, y: 588), control: CGPoint(x: x, y: 626))
    ctx.addPath(eye)
    ctx.strokePath()
}
let nose = CGMutablePath()
nose.move(to: CGPoint(x: 494, y: 648))
nose.addLine(to: CGPoint(x: 530, y: 648))
nose.addLine(to: CGPoint(x: 512, y: 670))
nose.closeSubpath()
ctx.addPath(nose)
ctx.setFillColor(rgb(0x4A2E36, 0.9))
ctx.fillPath()

let image = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
