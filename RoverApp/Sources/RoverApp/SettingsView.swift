import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var settings: RoverSettings
    @ObservedObject var keychain: KeychainStore
    @ObservedObject var safety: SafetyController
    @State private var apiKeyDraft: String = ""

    private var s: AppStrings { settings.s }

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label(s.tabGeneral, systemImage: "gearshape") }
            backendTab
                .tabItem { Label(s.tabBackend, systemImage: "circle.grid.cross") }
            triggersTab
                .tabItem { Label(s.tabTriggers, systemImage: "bolt.horizontal") }
            modelTab
                .tabItem { Label(s.tabModel, systemImage: "cpu") }
            promptTab
                .tabItem { Label(s.tabPrompt, systemImage: "text.bubble") }
            advancedTab
                .tabItem { Label(s.tabAdvanced, systemImage: "wrench.and.screwdriver") }
        }
        .frame(width: 580, height: 520)
    }

    // MARK: - Triggers

    private var triggersTab: some View {
        Form {
            Section(s.sectionHotkey) {
                Toggle(s.hotkeyEnabled, isOn: $settings.hotkeyEnabled)
                Text(s.hotkeyHint).font(.caption).foregroundStyle(.secondary)
            }
            Section(s.sectionActiveApp) {
                Toggle(s.activeAppEnabled, isOn: $settings.activeAppEnabled)
                HStack {
                    Text(s.activeAppDebounce)
                    Spacer()
                    Text("\(settings.activeAppDebounceSec) s")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Slider(value: Binding(
                    get: { Double(settings.activeAppDebounceSec) },
                    set: { settings.activeAppDebounceSec = Int($0) }
                ), in: 5...300, step: 5)
                Text(s.activeAppHint).font(.caption).foregroundStyle(.secondary)
            }
            Section(s.sectionPeriodic) {
                Toggle(s.periodicEnabled, isOn: $settings.periodicEnabled)
                HStack {
                    Text(s.periodicInterval)
                    Spacer()
                    Text("\(settings.periodicIntervalSec / 60) min")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Slider(value: Binding(
                    get: { Double(settings.periodicIntervalSec) },
                    set: { settings.periodicIntervalSec = Int($0) }
                ), in: 60...3600, step: 60)
                Text(s.periodicHint).font(.caption).foregroundStyle(.orange)
            }
            Section(s.sectionSchedules) {
                Toggle(s.scheduleEnabled, isOn: $settings.scheduleEnabled)
                ForEach($settings.schedules) { $entry in
                    HStack {
                        Toggle("", isOn: $entry.enabled).labelsHidden()
                        TextField(s.scheduleTime, text: $entry.time)
                            .frame(width: 80)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                        TextField(s.schedulePrompt, text: $entry.prompt)
                            .textFieldStyle(.roundedBorder)
                        Button(action: { removeSchedule(entry.id) }) {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                Button(s.scheduleAdd) { addSchedule() }
                Text(s.scheduleHint).font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func addSchedule() {
        settings.schedules.append(ScheduleEntry(time: "09:00", prompt: "good morning"))
    }

    private func removeSchedule(_ id: UUID) {
        settings.schedules.removeAll { $0.id == id }
    }

    // MARK: - Backend

    private var backendTab: some View {
        Form {
            Section(s.sectionBackend) {
                Picker(s.sectionBackend, selection: $settings.activeBackendId) {
                    ForEach(BackendID.allCases, id: \.self) { id in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(id.displayName)
                            Text(s.backendBlurb(id))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(id)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }
            Section(s.sectionAnthropicKey) {
                HStack {
                    SecureField(s.anthropicKeyPlaceholder, text: $apiKeyDraft)
                        .textFieldStyle(.roundedBorder)
                    Button(s.anthropicKeySave) {
                        keychain.anthropicAPIKey = apiKeyDraft
                        apiKeyDraft = ""
                    }
                    .disabled(apiKeyDraft.isEmpty)
                }
                HStack(spacing: 8) {
                    Image(systemName: keychain.hasAnthropicKey ? "checkmark.seal.fill" : "exclamationmark.circle")
                        .foregroundStyle(keychain.hasAnthropicKey ? .green : .orange)
                    Text(keychain.hasAnthropicKey ? s.anthropicKeyStored : s.anthropicKeyMissing)
                        .font(.caption)
                    Spacer()
                    if keychain.hasAnthropicKey {
                        Button(s.anthropicKeyClear) { keychain.anthropicAPIKey = nil }
                            .buttonStyle(.borderless)
                            .controlSize(.small)
                    }
                }
            }
            Section(s.sectionPermissionBubble) {
                Toggle(s.permBubbleToggle, isOn: $settings.permissionBubbleEnabled)
                Text(s.permBubbleHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                Text(s.backendHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            Section(s.sectionLanguage) {
                Picker(s.sectionLanguage, selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.label).tag(lang)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Text(s.settingsLanguageHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section(s.sectionBehavior) {
                Toggle(s.menuShowMenuBar, isOn: $settings.showMenuBarIcon)
                Toggle(s.menuSound, isOn: $settings.soundEnabled)
            }
            Section(s.sectionWorkingDirectory) {
                HStack {
                    Text(settings.workingDirectory)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button(s.workingDirChoose) { chooseDirectory() }
                }
                Text(s.workingDirHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: settings.workingDirectory)
        panel.prompt = "Use this folder"
        if panel.runModal() == .OK, let url = panel.url {
            settings.workingDirectory = url.path
        }
    }

    // MARK: - Model

    private var modelTab: some View {
        Form {
            Section(s.tabModel) {
                Picker(s.tabModel, selection: $settings.model) {
                    ForEach(RoverSettings.availableModels) { option in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(option.label)
                            Text(option.blurb(for: settings.language))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(option.id)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }

            Section {
                Text(s.modelHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - System Prompt

    private var promptTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(s.systemPromptHeader)
                    .font(.headline)
                Spacer()
                Button(s.systemPromptReset) { settings.resetSystemPrompt() }
                    .buttonStyle(.borderless)
            }
            Text(s.systemPromptHint)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: $settings.systemPrompt)
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
        }
        .padding()
    }

    // MARK: - Advanced

    private var advancedTab: some View {
        Form {
            Section(s.sectionPermissions) {
                Toggle(s.permDangerLabel, isOn: $settings.allowDangerously)
                Text(s.permDangerWarning)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Section(s.sectionSafety) {
                Toggle(s.safetyDryRun, isOn: $safety.dryRun)
                Text(s.safetyDryRunHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Text(s.safetyActionDelay)
                    Spacer()
                    Text("\(safety.actionDelayMs) ms")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Slider(value: Binding(
                    get: { Double(safety.actionDelayMs) },
                    set: { safety.actionDelayMs = Int($0) }
                ), in: 50...1000, step: 50)
            }

            Section(s.sectionTccPermissions) {
                permissionRow(
                    title: s.tccAccessibility,
                    granted: PermissionPrompter.shared.accessibilityStatus == .granted,
                    onOpen: { PermissionPrompter.shared.openAccessibilityPane() }
                )
                permissionRow(
                    title: s.tccScreenRecording,
                    granted: PermissionPrompter.shared.screenRecordingStatus == .granted,
                    onOpen: { PermissionPrompter.shared.openScreenRecordingPane() }
                )
                Text(s.tccPermissionsHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(s.sectionCLIBinaries) {
                cliBinaryRow(
                    title: s.aboutClaudeCLI,
                    customPath: $settings.customClaudePath,
                    resolvedPath: ClaudeRunner.detectClaudePath()
                )
                cliBinaryRow(
                    title: s.aboutCodexCLI,
                    customPath: $settings.customCodexPath,
                    resolvedPath: CodexCLIBackend.detectCodexPath()
                )
                Text(s.cliBinariesHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(s.sectionAbout) {
                LabeledContent(s.aboutVersion, value: "0.2.0")
                LabeledContent(s.aboutBundle, value: Bundle.main.bundleIdentifier ?? "—")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func permissionRow(title: String, granted: Bool, onOpen: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: granted ? "checkmark.seal.fill" : "exclamationmark.circle")
                .foregroundStyle(granted ? .green : .orange)
            Text(title)
            Spacer()
            Button(s.tccOpenPane) { onOpen() }
                .buttonStyle(.borderless)
                .controlSize(.small)
        }
    }

    /// Row for the "CLI binaries" advanced section. Shows the resolved
    /// (auto-detected or overridden) path with an exists/missing indicator,
    /// a Choose… button to pick a binary, and a Reset button when a custom
    /// override is set.
    @ViewBuilder
    private func cliBinaryRow(
        title: String,
        customPath: Binding<String>,
        resolvedPath: String
    ) -> some View {
        let custom = customPath.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let isCustom = !custom.isEmpty
        // For PATH-only fallbacks (e.g. "claude" with no slashes) we can't
        // statically check existence — assume valid and let the runner
        // surface launch errors at send time.
        let mustExist = isCustom || resolvedPath.contains("/")
        let exists = mustExist ? FileManager.default.fileExists(atPath: resolvedPath) : true

        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(isCustom ? s.cliBinaryCustom : s.cliBinaryAuto)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Image(systemName: exists ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(exists ? .green : .orange)
            }
            HStack(spacing: 8) {
                Text(resolvedPath)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(s.cliBinaryChoose) {
                    pickCLIBinary(into: customPath)
                }
                .controlSize(.small)
                if isCustom {
                    Button(s.cliBinaryReset) {
                        customPath.wrappedValue = ""
                    }
                    .controlSize(.small)
                }
            }
            if !exists {
                Text(s.cliBinaryNotFound)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 2)
    }

    private func pickCLIBinary(into binding: Binding<String>) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        // CLI binaries are usually shell scripts or Mach-O executables
        // living under /opt/homebrew/bin, /usr/local/bin, ~/.asdf/shims,
        // etc. Show hidden files so users can navigate into ~/.claude.
        panel.showsHiddenFiles = true
        panel.treatsFilePackagesAsDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            binding.wrappedValue = url.path
        }
    }
}
