@preconcurrency import AVFoundation
import UIKit
import Vision

enum CameraError: Error { case noImage, notRunning }

/// A cat Vision is tracking in the live feed.
struct LiveSighting: Equatable {
    /// Normalised rect, top-left origin, in the upright (portrait) frame.
    var rect: CGRect
    var confidence: Double
    /// Upright frame aspect (width / height) for aspect-fill mapping.
    var frameAspect: CGFloat
}

/// Back camera → photo output, plus a throttled live cat recogniser that
/// drives the Lens reticle.
@MainActor
@Observable
final class CameraService {
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let analyzer = LiveCatAnalyzer()
    private let analysisQueue = DispatchQueue(label: "maison.lens.analysis", qos: .userInitiated)
    private var activeDelegate: PhotoDelegate?

    private(set) var isRunning = false
    private(set) var isUnavailable = false
    private(set) var sighting: LiveSighting?

    init() {
        analyzer.onSighting = { [weak self] sighting in
            Task { @MainActor in self?.sighting = sighting }
        }
    }

    func start() async {
        guard !isRunning, !isUnavailable else { return }
        #if targetEnvironment(simulator)
        isUnavailable = true
        return
        #else
        guard await Self.requestPermission() else { isUnavailable = true; return }
        let session = session, photo = photoOutput, video = videoOutput
        let analyzer = analyzer, queue = analysisQueue
        let ok = await Task.detached(priority: .userInitiated) {
            Self.configure(session: session, photo: photo, video: video, analyzer: analyzer, queue: queue)
        }.value
        guard ok else { isUnavailable = true; return }
        await Task.detached(priority: .userInitiated) { session.startRunning() }.value
        isRunning = true
        #endif
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        sighting = nil
        let session = session
        Task.detached { session.stopRunning() }
    }

    func capture() async throws -> UIImage {
        guard isRunning else { throw CameraError.notRunning }
        if let connection = photoOutput.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
        return try await withCheckedThrowingContinuation { continuation in
            let delegate = PhotoDelegate { [weak self] result in
                Task { @MainActor in self?.activeDelegate = nil }
                continuation.resume(with: result)
            }
            activeDelegate = delegate
            let settings = AVCapturePhotoSettings()
            settings.photoQualityPrioritization = .balanced
            photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }

    private nonisolated static func configure(
        session: AVCaptureSession, photo: AVCapturePhotoOutput, video: AVCaptureVideoDataOutput,
        analyzer: LiveCatAnalyzer, queue: DispatchQueue
    ) -> Bool {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return false }
        session.addInput(input)
        guard session.canAddOutput(photo) else { return false }
        session.addOutput(photo)
        video.alwaysDiscardsLateVideoFrames = true
        video.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        video.setSampleBufferDelegate(analyzer, queue: queue)
        if session.canAddOutput(video) { session.addOutput(video) }
        return true
    }

    private static func requestPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        default: return false
        }
    }
}

/// Runs Vision's animal recogniser on ~4 frames a second.
private final class LiveCatAnalyzer: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    var onSighting: ((LiveSighting?) -> Void)?
    private var lastRun = Date.distantPast
    private var misses = 0

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = Date()
        guard now.timeIntervalSince(lastRun) > 0.25,
              let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastRun = now

        // Sensor frames are landscape; `.right` presents them upright for portrait.
        let width = CGFloat(CVPixelBufferGetHeight(buffer))
        let height = CGFloat(CVPixelBufferGetWidth(buffer))
        let request = VNRecognizeAnimalsRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .right, options: [:])
        try? handler.perform([request])

        let best = (request.results ?? []).compactMap { obs -> (CGRect, Float)? in
            guard let label = obs.labels.first(where: { $0.identifier == VNAnimalIdentifier.cat.rawValue }) else { return nil }
            return (obs.boundingBox, label.confidence)
        }.max { $0.1 < $1.1 }

        if let (box, confidence) = best, confidence > 0.35 {
            misses = 0
            let rect = CGRect(x: box.minX, y: 1 - box.maxY, width: box.width, height: box.height)
            onSighting?(LiveSighting(rect: rect, confidence: Double(confidence), frameAspect: width / height))
        } else {
            misses += 1
            // Hold the reticle briefly so it doesn't flicker between frames.
            if misses >= 3 { onSighting?(nil) }
        }
    }
}

private final class PhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (Result<UIImage, Error>) -> Void

    init(completion: @escaping (Result<UIImage, Error>) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error { completion(.failure(error)); return }
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
            completion(.failure(CameraError.noImage)); return
        }
        completion(.success(image))
    }
}
