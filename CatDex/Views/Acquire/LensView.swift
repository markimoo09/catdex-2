import AVFoundation
import PhotosUI
import SwiftUI

/// The custom camera. On device, a gold reticle locks onto any cat Vision sees.
struct LensView: View {
    let lotNumber: Int
    var onPhoto: (UIImage) -> Void
    var onClose: () -> Void

    @State private var camera = CameraService()
    @State private var pickerItem: PhotosPickerItem?
    @State private var showPicker = false
    @State private var flash = false
    @State private var shutterCount = 0

    var body: some View {
        ZStack {
            Theme.ink.ignoresSafeArea()

            if camera.isUnavailable {
                DarkLens().ignoresSafeArea()
            } else {
                CameraPreview(session: camera.session).ignoresSafeArea()
            }

            // Vignette.
            RadialGradient(colors: [.clear, .black.opacity(0.65)], center: .center, startRadius: 160, endRadius: 520)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            GeometryReader { proxy in
                Reticle(sighting: camera.sighting, in: proxy.size)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack {
                topBar
                Spacer()
                controls
            }

            if flash {
                Color.white.opacity(0.85).ignoresSafeArea().allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .statusBarHidden()
        .photosPicker(isPresented: $showPicker, selection: $pickerItem, matching: .images, preferredItemEncoding: .current)
        .onChange(of: pickerItem) { _, item in load(item) }
        .task { await camera.start() }
        .onDisappear { camera.stop() }
        .sensoryFeedback(.impact(weight: .heavy), trigger: shutterCount)
        .sensoryFeedback(.selection, trigger: camera.sighting != nil)
    }

    private var topBar: some View {
        HStack {
            GlassIconButton(systemName: "xmark", label: "Close", dark: true) { onClose() }
            Spacer()
            VStack(spacing: 3) {
                Text("The Lens").font(Theme.title(15)).foregroundStyle(.white)
                Text("№ \(lotNumber)")
                    .font(Theme.number(12, weight: .semibold))
                    .foregroundStyle(Theme.roseLight)
            }
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
    }

    private var controls: some View {
        HStack {
            Button { showPicker = true } label: {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(Color.white)
                    .frame(width: 54, height: 54)
                    .maisonGlass(in: Circle())
                .contentShape(Circle())
            }
            .accessibilityLabel("Choose from library")

            Spacer()

            Shutter(locked: camera.sighting != nil) { shoot() }

            Spacer()

            Color.clear.frame(width: 54, height: 54)
        }
        .padding(.horizontal, 36)
        .padding(.bottom, 26)
    }

    private func shoot() {
        guard camera.isRunning else {
            showPicker = true
            return
        }
        shutterCount += 1
        withAnimation(.easeOut(duration: 0.08)) { flash = true }
        Task {
            try? await Task.sleep(for: .milliseconds(90))
            withAnimation(.easeIn(duration: 0.35)) { flash = false }
            if let image = try? await camera.capture() {
                camera.stop()
                onPhoto(image)
            }
        }
    }

    private func load(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                camera.stop()
                onPhoto(image)
            }
            pickerItem = nil
        }
    }
}

// MARK: - Shutter

struct Shutter: View {
    var locked: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(locked ? AnyShapeStyle(Theme.roseGold) : AnyShapeStyle(Color.white.opacity(0.9)), lineWidth: 3)
                    .frame(width: 82, height: 82)
                Circle()
                    .fill(locked ? AnyShapeStyle(Theme.roseGold) : AnyShapeStyle(Color.white))
                    .frame(width: 66, height: 66)
                Aperture()
                    .stroke(Theme.ink.opacity(locked ? 0.6 : 0.25), lineWidth: 1)
                    .frame(width: 30, height: 30)
                    .rotationEffect(.degrees(locked ? 30 : 0))
            }
            .shadow(color: locked ? Theme.rose.opacity(0.6) : .black.opacity(0.4), radius: locked ? 18 : 8)
            .animation(.spring(duration: 0.4, bounce: 0.3), value: locked)
        }
        .buttonStyle(PressScale())
        .accessibilityLabel("Acquire")
    }
}

// MARK: - Reticle

struct Reticle: View {
    let sighting: LiveSighting?
    let size: CGSize
    @State private var breathe = false

    init(sighting: LiveSighting?, in size: CGSize) {
        self.sighting = sighting
        self.size = size
    }

    private var frame: CGRect {
        guard let s = sighting else {
            let w = size.width * 0.66, h = w * 1.2
            return CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2 - 20, width: w, height: h)
        }
        // Aspect-fill mapping of the upright camera frame onto the view.
        let scale = max(size.width / s.frameAspect, size.height)
        let dw = s.frameAspect * scale, dh = scale
        let ox = (size.width - dw) / 2, oy = (size.height - dh) / 2
        return CGRect(x: ox + s.rect.minX * dw, y: oy + s.rect.minY * dh, width: s.rect.width * dw, height: s.rect.height * dh)
            .insetBy(dx: -14, dy: -14)
    }

    var body: some View {
        let rect = frame
        let locked = sighting != nil
        ZStack(alignment: .topLeading) {
            CornerBrackets(length: locked ? 26 : 20)
                .stroke(locked ? AnyShapeStyle(Theme.roseGold) : AnyShapeStyle(Color.white.opacity(breathe ? 0.55 : 0.3)),
                        style: StrokeStyle(lineWidth: locked ? 2 : 1.2, lineCap: .round))
                .frame(width: rect.width, height: rect.height)
                .shadow(color: locked ? Theme.rose.opacity(0.7) : .clear, radius: 8)
                .offset(x: rect.minX, y: rect.minY)

            if let sighting {
                HStack(spacing: 6) {
                    Circle().fill(Theme.roseLight).frame(width: 5, height: 5)
                    Text("FELIS CATUS · \(Int(sighting.confidence * 100))%")
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .tracking(1.5)
                        .foregroundStyle(Theme.ink)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Theme.roseGold))
                .offset(x: rect.minX, y: max(4, rect.minY - 26))
                .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottomLeading)))
            }
        }
        .animation(.spring(duration: 0.45, bounce: 0.2), value: sighting)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { breathe = true }
        }
        .accessibilityHidden(true)
    }
}

struct CornerBrackets: Shape {
    var length: CGFloat

    var animatableData: CGFloat {
        get { length }
        set { length = newValue }
    }

    func path(in r: CGRect) -> Path {
        var p = Path()
        let l = min(length, r.width / 3, r.height / 3)
        p.move(to: CGPoint(x: r.minX, y: r.minY + l)); p.addLine(to: CGPoint(x: r.minX, y: r.minY)); p.addLine(to: CGPoint(x: r.minX + l, y: r.minY))
        p.move(to: CGPoint(x: r.maxX - l, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.minY + l))
        p.move(to: CGPoint(x: r.maxX, y: r.maxY - l)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY)); p.addLine(to: CGPoint(x: r.maxX - l, y: r.maxY))
        p.move(to: CGPoint(x: r.minX + l, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY - l))
        return p
    }
}

// MARK: - Preview

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}
}

/// Shown where there's no camera (the Simulator): a slowly turning iris.
struct DarkLens: View {
    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack {
                Theme.ink
                Guilloche(color: Theme.roseLight.opacity(0.06), lineWidth: 0.4, petals: 10, bands: 3, strands: 14)
                    .rotationEffect(.radians(t * 0.03))
                    .centered(size: 600)
                Aperture()
                    .stroke(Theme.roseLight.opacity(0.18), lineWidth: 1)
                    .frame(width: 180, height: 180)
                    .rotationEffect(.radians(t * 0.12))
            }
        }
    }
}
