import Foundation
import AppKit

/// Fires when the user activates a different macOS app. Default
/// behaviour is animation-only (no agent call) — the coordinator
/// reads `requiresUserPrompt = false` and just hints/animates.
@MainActor
final class ActiveAppTrigger: Trigger {
    let id: TriggerID = .activeAppChange
    var isEnabled: Bool {
        didSet { isEnabled ? start() : stop() }
    }
    var onFire: ((TriggerContext) -> Void)?
    var debounceSec: Int = 30

    private var observer: NSObjectProtocol?
    private var lastFiredAt: Date = .distantPast
    private var lastAppBundle: String?
    private let ownBundleId: String

    init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
        self.ownBundleId = Bundle.main.bundleIdentifier ?? "com.youngjae.rover"
    }

    func start() {
        guard observer == nil, isEnabled else { return }
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                    as? NSRunningApplication else { return }
            Task { @MainActor in self.handle(app) }
        }
    }

    func stop() {
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        observer = nil
    }

    private func handle(_ app: NSRunningApplication) {
        guard isEnabled else { return }
        if app.bundleIdentifier == ownBundleId { return }
        let bundle = app.bundleIdentifier
        let now = Date()
        if bundle == lastAppBundle,
           now.timeIntervalSince(lastFiredAt) < Double(debounceSec) {
            return
        }
        lastAppBundle = bundle
        lastFiredAt = now

        let name = app.localizedName ?? bundle ?? "an app"
        let ctx = TriggerContext(
            triggerId: id,
            promptHint: "User activated \(name).",
            attachments: [],
            requiresUserPrompt: false
        )
        onFire?(ctx)
    }
}
