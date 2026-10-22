// Pre-lifts demo cats on the host Mac (Vision's subject-lift model is missing from
// the iOS Simulator). Writes <name>.jpg + a frame-aligned <name>-cutout.png for SEED_DIR.
// Usage: swift scripts/make-demo-cutouts.swift <out-dir> <image> [<image> ...]
import AppKit
import CoreImage
import Vision

let args = Array(CommandLine.arguments.dropFirst())
guard args.count >= 2 else { print("usage: <out-dir> <images…>"); exit(1) }
let outDir = URL(fileURLWithPath: args[0])
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
let ci = CIContext()

for path in args.dropFirst() {
    let url = URL(fileURLWithPath: path)
    let name = url.deletingPathExtension().lastPathComponent
    guard let ns = NSImage(contentsOf: url),
          let cg = ns.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        print("skip \(path)"); continue
    }
    let rep = NSBitmapImageRep(cgImage: cg)
    try rep.representation(using: .jpeg, properties: [.compressionFactor: 0.9])!
        .write(to: outDir.appendingPathComponent("\(name).jpg"))

    let request = VNGenerateForegroundInstanceMaskRequest()
    let handler = VNImageRequestHandler(cgImage: cg)
    try handler.perform([request])
    guard let obs = request.results?.first else { print("no subject in \(name)"); continue }
    let buffer = try obs.generateMaskedImage(ofInstances: obs.allInstances, from: handler,
                                             croppedToInstancesExtent: false)
    let image = CIImage(cvPixelBuffer: buffer)
    guard let out = ci.createCGImage(image, from: image.extent) else { continue }
    try NSBitmapImageRep(cgImage: out).representation(using: .png, properties: [:])!
        .write(to: outDir.appendingPathComponent("\(name)-cutout.png"))

    let animals = VNRecognizeAnimalsRequest()
    try handler.perform([animals])
    let cat = animals.results?.flatMap(\.labels).first { $0.identifier == "Cat" }
    print("\(name): cutout \(out.width)x\(out.height), cat confidence \(cat?.confidence ?? 0)")
}
