import Foundation
import AppKit

/// Cross-cutting safety machinery for the autonomous Computer Use loop.
/// - Global Esc monitor: pressing Escape sets `cancelled = true` and the
///   currently-running agent loop bails on next checkpoint.
/// - Action rate limit: enforces a minimum delay between dispatcher calls
///   so a runaway loop can't melt the user's UI.
/// - Dry-run: when true, mouse/keyboard tools are reported but not posted.
@MainActor
final class SafetyController: ObservableObject {
    @Published var dryRun: Bool = false
    @Published var actionDelayMs: Int = 250

    /// Set to true on Esc press. Read by the Anthropic backend's loop and
    /// reset back to false at the start of each new turn.
    @Published private(set) var cancelled: Bool = false

    private var lastActionAt: Date = .distantPast
    private var escMonitor: Any?

    init() {
        startEscMonitor()
    }

    func resetCancellation() {
        cancelled = false
    }

    func raiseCancellation() {
        cancelled = true
    }

    /// Awaits long enough that consecutive dispatcher calls land at least
    /// `actionDelayMs` apart. Cheap when calls are already spread out.
    func enforceRateLimit() async {
        let elapsed = Date().timeIntervalSince(lastActionAt) * 1000
        let needed = Double(actionDelayMs) - elapsed
        if needed > 0 {
            try? await Task.sleep(nanoseconds: UInt64(needed * 1_000_000))
        }
        lastActionAt = Date()
    }

    private func startEscMonitor() {
        // Global monitor — fires while another app is foreground.
        // Local monitor — fires when Roger is foreground. We need both.
        let handler: (NSEvent) -> Void = { [weak self] event in
            // keyCode 53 = Escape
            if event.keyCode == 53 {
                Task { @MainActor in self?.raiseCancellation() }
            }
        }
        escMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: handler)
        _ = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handler(event)
            return event
        }
    }
}
