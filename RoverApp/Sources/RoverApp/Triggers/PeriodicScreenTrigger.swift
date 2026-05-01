import Foundation
import AppKit

/// Fires every `intervalSec` and attaches a fresh screenshot to the
/// trigger context. Skips firing when the screen looks unchanged
/// from the previous fire (cheap mean-grayscale dedup) — saves API
/// cost during idle periods.
@MainActor
final class PeriodicScreenTrigger: Trigger {
    let id: TriggerID = .periodicScreen
    var isEnabled: Bool {
        didSet {
            if oldValue == isEnabled { return }
            isEnabled ? start() : stop()
        }
    }
    var onFire: ((TriggerContext) -> Void)?

    /// Seconds between observations. Defaults to 10 minutes.
    var intervalSec: Int = 600

    private var timer: Timer?
    private var lastScreenSignature: UInt64 = 0

    init(isEnabled: Bool = false) {
        self.isEnabled = isEnabled
    }

    func start() {
        guard timer == nil, isEnabled else { return }
        let interval = TimeInterval(max(60, intervalSec))
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.fire() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func fire() {
        guard isEnabled else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                let png = try await ScreenshotTool.capturePNG()
                let sig = Self.dHash(png: png)
                if sig == self.lastScreenSignature { return }
                self.lastScreenSignature = sig
                self.onFire?(TriggerContext(
                    triggerId: self.id,
                    promptHint: "Periodic glance — anything I can help with?",
                    attachments: [.screenshot(png)],
                    requiresUserPrompt: false
                ))
            } catch {
                // Silently skip — Screen Recording permission may be off.
            }
        }
    }

    /// Cheap 64-bit signature of the screenshot. Two screens that produce
    /// the same hash are "the same enough" — skip the fire.
    static func dHash(png: Data) -> UInt64 {
        var hasher = Hasher()
        hasher.combine(png.count)
        // Sample 64 bytes spread evenly through the image.
        let stride = max(1, png.count / 64)
        var i = 0
        var taken = 0
        while i < png.count, taken < 64 {
            hasher.combine(png[i])
            i += stride
            taken += 1
        }
        return UInt64(bitPattern: Int64(hasher.finalize()))
    }
}
