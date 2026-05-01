import Foundation

/// One scheduled prompt. Daily-only "HH:MM" format for v0.2 — full cron
/// expressions are out of scope.
struct ScheduleEntry: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var time: String      // "09:00"
    var prompt: String
    var enabled: Bool

    init(id: UUID = UUID(), time: String, prompt: String, enabled: Bool = true) {
        self.id = id
        self.time = time
        self.prompt = prompt
        self.enabled = enabled
    }

    /// Returns the next `Date` >= `now` matching this entry's HH:MM.
    func nextFireDate(after now: Date = Date()) -> Date? {
        let parts = time.split(separator: ":")
        guard parts.count == 2,
              let hh = Int(parts[0]),
              let mm = Int(parts[1]),
              (0...23).contains(hh),
              (0...59).contains(mm) else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        var candidate = cal.date(bySettingHour: hh, minute: mm, second: 0, of: now)
            ?? now
        if candidate <= now {
            candidate = cal.date(byAdding: .day, value: 1, to: candidate) ?? candidate
        }
        return candidate
    }
}

/// Fires entries from `RoverSettings.schedules` on their HH:MM. Each
/// fire reschedules the next one. No persistence beyond settings.
@MainActor
final class ScheduleTrigger: Trigger {
    let id: TriggerID = .schedule
    var isEnabled: Bool {
        didSet {
            if oldValue == isEnabled { return }
            isEnabled ? start() : stop()
        }
    }
    var onFire: ((TriggerContext) -> Void)?

    private let settings: RoverSettings
    private var timers: [UUID: Timer] = [:]

    init(settings: RoverSettings, isEnabled: Bool = false) {
        self.settings = settings
        self.isEnabled = isEnabled
    }

    func start() {
        guard isEnabled else { return }
        rescheduleAll()
    }

    func stop() {
        for t in timers.values { t.invalidate() }
        timers.removeAll()
    }

    /// Public hook for the Settings UI: schedules changed, re-arm.
    func rescheduleAll() {
        stop()
        guard isEnabled else { return }
        for entry in settings.schedules where entry.enabled {
            schedule(entry)
        }
    }

    private func schedule(_ entry: ScheduleEntry) {
        guard let fireAt = entry.nextFireDate() else { return }
        let interval = max(1, fireAt.timeIntervalSinceNow)
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.fire(entry) }
        }
        timers[entry.id] = timer
    }

    private func fire(_ entry: ScheduleEntry) {
        timers[entry.id] = nil
        guard isEnabled,
              let updated = settings.schedules.first(where: { $0.id == entry.id }),
              updated.enabled else { return }
        onFire?(TriggerContext(
            triggerId: id,
            promptHint: updated.prompt,
            attachments: [],
            requiresUserPrompt: false
        ))
        // Re-arm for tomorrow's same time.
        schedule(updated)
    }
}
