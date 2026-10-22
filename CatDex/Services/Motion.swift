import CoreMotion
import SwiftUI

/// Device tilt for parallax and foil, smoothed. Where Core Motion is unavailable
/// (the Simulator) a slow figure-eight drift keeps the light moving.
@MainActor
@Observable
final class Motion {
    /// Roughly -1...1 on each axis.
    private(set) var tilt: CGSize = .zero
    private(set) var isLive = false

    private let manager = CMMotionManager()
    private var driftTask: Task<Void, Never>?
    private var subscribers = 0

    func start() {
        subscribers += 1
        guard subscribers == 1 else { return }
        if manager.isDeviceMotionAvailable {
            isLive = true
            manager.deviceMotionUpdateInterval = 1.0 / 30
            manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
                guard let self, let motion else { return }
                let roll = max(-1, min(1, motion.attitude.roll / 0.6))
                let pitch = max(-1, min(1, (motion.attitude.pitch - 0.7) / 0.6))
                self.tilt = CGSize(
                    width: self.tilt.width * 0.82 + roll * 0.18,
                    height: self.tilt.height * 0.82 + pitch * 0.18
                )
            }
        } else {
            driftTask = Task { [weak self] in
                let start = Date()
                while !Task.isCancelled {
                    let t = Date().timeIntervalSince(start)
                    self?.tilt = CGSize(width: sin(t * 0.55) * 0.55, height: sin(t * 1.1) * 0.25)
                    try? await Task.sleep(for: .milliseconds(33))
                }
            }
        }
    }

    func stop() {
        subscribers = max(0, subscribers - 1)
        guard subscribers == 0 else { return }
        manager.stopDeviceMotionUpdates()
        driftTask?.cancel()
        driftTask = nil
    }
}
