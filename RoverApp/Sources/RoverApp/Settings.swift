import Foundation
import SwiftUI

struct ModelOption: Identifiable, Hashable {
    let id: String
    let label: String
    private let blurbEn: String
    private let blurbKo: String

    init(id: String, label: String, blurbEn: String, blurbKo: String) {
        self.id = id
        self.label = label
        self.blurbEn = blurbEn
        self.blurbKo = blurbKo
    }

    func blurb(for lang: AppLanguage) -> String {
        lang.resolved == .korean ? blurbKo : blurbEn
    }
}

@MainActor
final class RoverSettings: ObservableObject {
    // MARK: - Persisted

    @Published var model: String { didSet { save("rover.model", model) } }
    @Published var systemPrompt: String { didSet { save("rover.systemPrompt", systemPrompt) } }
    @Published var workingDirectory: String { didSet { save("rover.cwd", workingDirectory) } }
    @Published var showMenuBarIcon: Bool { didSet { save("rover.menuBar", showMenuBarIcon) } }
    @Published var soundEnabled: Bool {
        didSet {
            save("rover.sound", soundEnabled)
            SoundPlayer.shared.enabled = soundEnabled
        }
    }
    @Published var allowDangerously: Bool { didSet { save("rover.dangerous", allowDangerously) } }
    @Published var language: AppLanguage {
        didSet { save("rover.language", language.rawValue) }
    }
    @Published var activeBackendId: BackendID {
        didSet { save("rover.backend", activeBackendId.rawValue) }
    }

    // Triggers
    @Published var hotkeyEnabled: Bool { didSet { save("rover.trig.hotkey", hotkeyEnabled) } }
    @Published var activeAppEnabled: Bool { didSet { save("rover.trig.activeApp", activeAppEnabled) } }
    @Published var activeAppDebounceSec: Int {
        didSet { save("rover.trig.activeAppDebounceSec", activeAppDebounceSec) }
    }
    @Published var periodicEnabled: Bool { didSet { save("rover.trig.periodic", periodicEnabled) } }
    @Published var periodicIntervalSec: Int {
        didSet { save("rover.trig.periodicIntervalSec", periodicIntervalSec) }
    }
    @Published var scheduleEnabled: Bool { didSet { save("rover.trig.schedule", scheduleEnabled) } }
    @Published var schedules: [ScheduleEntry] {
        didSet {
            if let data = try? JSONEncoder().encode(schedules) {
                UserDefaults.standard.set(data, forKey: "rover.schedules")
            }
        }
    }

    // MARK: - Static

    static let availableModels: [ModelOption] = [
        ModelOption(id: "claude-opus-4-7",
                    label: "Claude Opus 4.7",
                    blurbEn: "Most capable, most expensive",
                    blurbKo: "가장 똑똑함, 가장 비쌈"),
        ModelOption(id: "claude-sonnet-4-6",
                    label: "Claude Sonnet 4.6",
                    blurbEn: "Balanced default",
                    blurbKo: "균형 잡힌 기본값"),
        ModelOption(id: "claude-haiku-4-5",
                    label: "Claude Haiku 4.5",
                    blurbEn: "Fastest",
                    blurbKo: "가장 빠름")
    ]

    static let defaultSystemPromptEn = """
    You are Rover — Microsoft's classic desktop companion, brought back in the 21st century.
    Be friendly and concise. Carry out commands precisely while keeping a warm, doglike tone.
    """

    static let defaultSystemPromptKo = """
    너는 Rover야 — Microsoft의 데스크톱 동반자가 21세기에 부활한 모습이지.
    친근하고 짧게 답해. 명령은 정확히 수행하되, 답변 톤은 강아지 같은 따뜻함을 유지해.
    """

    static func defaultSystemPrompt(for lang: AppLanguage) -> String {
        lang.resolved == .korean ? defaultSystemPromptKo : defaultSystemPromptEn
    }

    init() {
        let d = UserDefaults.standard
        let storedLang = d.string(forKey: "rover.language").flatMap(AppLanguage.init(rawValue:))
        self.language = storedLang ?? .system
        self.model = d.string(forKey: "rover.model") ?? Self.availableModels.first!.id
        self.systemPrompt = d.string(forKey: "rover.systemPrompt")
            ?? Self.defaultSystemPrompt(for: storedLang ?? .system)
        self.workingDirectory = d.string(forKey: "rover.cwd")
            ?? FileManager.default.homeDirectoryForCurrentUser.path
        self.showMenuBarIcon = (d.object(forKey: "rover.menuBar") as? Bool) ?? true
        self.soundEnabled = (d.object(forKey: "rover.sound") as? Bool) ?? true
        self.allowDangerously = (d.object(forKey: "rover.dangerous") as? Bool) ?? false
        let storedBackend = d.string(forKey: "rover.backend").flatMap(BackendID.init(rawValue:))
        self.activeBackendId = storedBackend ?? .claudeCodeCLI

        self.hotkeyEnabled = (d.object(forKey: "rover.trig.hotkey") as? Bool) ?? false
        self.activeAppEnabled = (d.object(forKey: "rover.trig.activeApp") as? Bool) ?? false
        self.activeAppDebounceSec = (d.object(forKey: "rover.trig.activeAppDebounceSec") as? Int) ?? 30
        self.periodicEnabled = (d.object(forKey: "rover.trig.periodic") as? Bool) ?? false
        self.periodicIntervalSec = (d.object(forKey: "rover.trig.periodicIntervalSec") as? Int) ?? 600
        self.scheduleEnabled = (d.object(forKey: "rover.trig.schedule") as? Bool) ?? false
        if let data = d.data(forKey: "rover.schedules"),
           let decoded = try? JSONDecoder().decode([ScheduleEntry].self, from: data) {
            self.schedules = decoded
        } else {
            self.schedules = []
        }

        SoundPlayer.shared.enabled = self.soundEnabled
    }

    private func save<T>(_ key: String, _ value: T) {
        UserDefaults.standard.set(value, forKey: key)
    }

    // MARK: - Derived

    var s: AppStrings { AppStrings(language) }

    var primaryStarters: [LocalizedStarter] { s.starterPrimary }
    var secondaryStarters: [LocalizedStarter] { s.starterSecondary }

    func resetSystemPrompt() {
        systemPrompt = Self.defaultSystemPrompt(for: language)
    }

    var currentModelLabel: String {
        Self.availableModels.first(where: { $0.id == model })?.label ?? model
    }
}
