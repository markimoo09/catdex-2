import CoreImage
import UIKit
import Vision

struct CutoutResult {
    /// The subject cropped to its bounds (transparent background), or the cameo crop.
    let cutout: UIImage
    /// Full-frame masked subject, pixel-aligned with the original (nil for cameo).
    let alignedMask: UIImage?
    /// True when the subject could not be lifted.
    let isCameo: Bool
}

/// Lifts the subject out of a photo with Vision's foreground-instance mask — the
/// capability behind long-press "lift subject" in Photos.
enum CutoutService {

    static func lift(_ image: UIImage) async -> CutoutResult {
        let upright = normalized(image)

        // A photo that already carries transparency (a saved sticker, a lifted
        // subject) is honoured as-is.
        if hasMeaningfulAlpha(upright) {
            return CutoutResult(cutout: cropToOpaque(upright), alignedMask: upright, isCameo: false)
        }

        guard let cg = upright.cgImage else { return cameo(upright) }
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        do {
            try await Task.detached(priority: .userInitiated) { try handler.perform([request]) }.value
            guard let observation = request.results?.first, !observation.allInstances.isEmpty else {
                return cameo(upright)
            }
            let full = try observation.generateMaskedImage(
                ofInstances: observation.allInstances, from: handler, croppedToInstancesExtent: false
            )
            guard let aligned = uiImage(from: full) else { return cameo(upright) }
            return CutoutResult(cutout: cropToOpaque(aligned), alignedMask: aligned, isCameo: false)
        } catch {
            return cameo(upright)
        }
    }

    /// When lifting fails the photo is presented as an arched cameo portrait —
    /// a deliberate frame rather than a broken cutout.
    static func cameo(_ image: UIImage) -> CutoutResult {
        CutoutResult(cutout: cameoCrop(image), alignedMask: nil, isCameo: true)
    }

    static func cameoCrop(_ image: UIImage) -> UIImage {
        guard let cg = image.cgImage else { return image }
        let w = CGFloat(cg.width), h = CGFloat(cg.height)
        let targetAspect: CGFloat = 3.0 / 4.0
        var rect: CGRect
        if w / h > targetAspect {
            let cw = h * targetAspect
            rect = CGRect(x: (w - cw) / 2, y: 0, width: cw, height: h)
        } else {
            let ch = w / targetAspect
            rect = CGRect(x: 0, y: (h - ch) / 2, width: w, height: ch)
        }
        rect = rect.integral
        guard let cropped = cg.cropping(to: rect) else { return image }
        return UIImage(cgImage: cropped)
    }

    // MARK: Helpers

    static func normalized(_ image: UIImage, maxDimension: CGFloat = 2048) -> UIImage {
        let scale = min(1, maxDimension / max(image.size.width, image.size.height))
        if image.imageOrientation == .up, scale >= 1, image.cgImage != nil { return image }
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = !hasAlphaChannel(image)
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private static func hasAlphaChannel(_ image: UIImage) -> Bool {
        guard let info = image.cgImage?.alphaInfo else { return false }
        return ![.none, .noneSkipFirst, .noneSkipLast].contains(info)
    }

    /// Any noticeably transparent region along the border.
    static func hasMeaningfulAlpha(_ image: UIImage) -> Bool {
        guard hasAlphaChannel(image), let cg = image.cgImage else { return false }
        let side = 32
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        guard let ctx = CGContext(
            data: &pixels, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return false }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))
        var transparent = 0
        for i in stride(from: 3, to: pixels.count, by: 4) where pixels[i] < 16 { transparent += 1 }
        return transparent > side * side / 20
    }

    /// Crops to the bounding box of opaque pixels, with a small margin.
    static func cropToOpaque(_ image: UIImage) -> UIImage {
        guard let cg = image.cgImage else { return image }
        let w = cg.width, h = cg.height
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(
            data: &pixels, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        var minX = w, minY = h, maxX = 0, maxY = 0
        for y in stride(from: 0, to: h, by: 2) {
            let row = y * w * 4
            for x in stride(from: 0, to: w, by: 2) where pixels[row + x * 4 + 3] > 24 {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX > minX, maxY > minY else { return image }
        let margin = Int(Double(max(maxX - minX, maxY - minY)) * 0.02)
        let rect = CGRect(
            x: max(0, minX - margin), y: max(0, minY - margin),
            width: min(w, maxX + margin) - max(0, minX - margin),
            height: min(h, maxY + margin) - max(0, minY - margin)
        )
        guard let cropped = cg.cropping(to: rect) else { return image }
        return UIImage(cgImage: cropped)
    }

    private static func uiImage(from buffer: CVPixelBuffer) -> UIImage? {
        let ci = CIImage(cvPixelBuffer: buffer)
        guard let cg = CIContext().createCGImage(ci, from: ci.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
