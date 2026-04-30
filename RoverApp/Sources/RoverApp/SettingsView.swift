import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var settings: RoverSettings

    private var s: AppStrings { settings.s }

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label(s.tabGeneral, systemImage: "gearshape") }
            modelTab
                .tabItem { Label(s.tabModel, systemImage: "cpu") }
            promptTab
                .tabItem { Label(s.tabPrompt, systemImage: "text.bubble") }
            advancedTab
                .tabItem { Label(s.tabAdvanced, systemImage: "wrench.and.screwdriver") }
        }
        .frame(width: 540, height: 440)
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

            Section(s.sectionAbout) {
                LabeledContent(s.aboutVersion, value: "0.2.0")
                LabeledContent(s.aboutBundle, value: Bundle.main.bundleIdentifier ?? "—")
                LabeledContent(s.aboutClaudeCLI) {
                    Text(ClaudeRunner.detectClaudePath())
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
