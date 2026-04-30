import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case english = "en"
    case korean = "ko"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .english: return "English"
        case .korean: return "한국어"
        }
    }

    /// Resolved language — `.system` is mapped to en/ko based on the user's
    /// preferred languages from `Locale`.
    var resolved: AppLanguage {
        if self != .system { return self }
        let preferred = Locale.preferredLanguages.first?.lowercased() ?? "en"
        return preferred.hasPrefix("ko") ? .korean : .english
    }
}

/// Bundle of all user-facing strings, parameterized by resolved language.
struct AppStrings {
    let lang: AppLanguage // always .english or .korean

    init(_ lang: AppLanguage) {
        self.lang = lang.resolved
    }

    private func t(_ en: String, _ ko: String) -> String {
        lang == .korean ? ko : en
    }

    // MARK: speech bubble
    var bubbleInputHeader: String { t("How can I help?", "뭘 도와줄까?") }
    var bubbleOtherSection: String { t("You may also want to…", "그 외에…") }
    var bubblePromptPlaceholder: String { t("Ask Rover", "Rover에게 물어보기") }
    var bubblePromptBusyPlaceholder: String { t("Working…", "잠깐만…") }
    var bubbleStreamingThinking: String { t("thinking", "생각 중") }
    var bubbleResponseHeader: String { t("rover", "rover") }
    var bubbleErrorTitle: String { t("oops", "oops") }

    // MARK: status
    var statusThinking: String { t("thinking…", "생각 중…") }
    var statusCancelled: String { t("cancelled", "중단됨") }

    // MARK: context / right-click menu
    var menuAsk: String { t("Ask Rover…", "Rover에게 묻기…") }
    var menuSound: String { t("Sound", "소리") }
    var menuShowMenuBar: String { t("Show menu bar icon", "메뉴바 아이콘 표시") }
    var menuModelLabel: String { t("Model", "모델") }
    var menuSettings: String { t("Settings…", "설정…") }
    var menuQuit: String { t("Quit Rover", "Rover 종료") }
    var menuShowRover: String { t("Show Rover", "Rover 보이기") }

    // MARK: settings tabs
    var settingsTitle: String { t("Rover Settings", "Rover 설정") }
    var tabGeneral: String { t("General", "일반") }
    var tabModel: String { t("Model", "모델") }
    var tabPrompt: String { t("System Prompt", "시스템 프롬프트") }
    var tabAdvanced: String { t("Advanced", "고급") }

    // MARK: settings - general
    var sectionBehavior: String { t("Behavior", "동작") }
    var sectionLanguage: String { t("Language", "언어") }
    var sectionWorkingDirectory: String { t("Working directory", "작업 디렉토리") }
    var workingDirChoose: String { t("Choose…", "선택…") }
    var workingDirHint: String {
        t("The directory where Rover runs the claude CLI. Tools operate relative to this folder.",
          "Rover가 claude CLI를 실행할 디렉토리. tool 사용 시 이 위치 기준으로 동작해.")
    }
    var settingsLanguageHint: String {
        t("Restart of the bubble may be needed to refresh some labels.",
          "일부 라벨은 말풍선을 다시 열면 갱신돼.")
    }

    // MARK: settings - model
    var modelHint: String {
        t("Passed to claude as `--model <id>`. If the CLI doesn't recognize the id, it falls back to its default.",
          "선택한 모델은 `claude --model <id>` 로 전달돼. claude CLI가 인식하지 못하는 ID라면 기본값으로 폴백.")
    }

    // MARK: settings - prompt
    var systemPromptHeader: String { t("Append system prompt", "시스템 프롬프트 추가") }
    var systemPromptHint: String {
        t("Sent via `claude --append-system-prompt`. Appended after Claude's default system prompt.",
          "`claude --append-system-prompt` 으로 전달됨. claude의 기본 시스템 프롬프트 뒤에 추가돼.")
    }
    var systemPromptReset: String { t("Reset to default", "기본값으로 되돌리기") }

    // MARK: settings - advanced
    var sectionPermissions: String { t("Permissions", "권한") }
    var permDangerLabel: String {
        t("Skip permission checks (--dangerously-skip-permissions)",
          "권한 검사 건너뛰기 (--dangerously-skip-permissions)")
    }
    var permDangerWarning: String {
        t("⚠️ Allows every tool call to run instantly. Only enable in trusted directories.",
          "⚠️ 켜면 모든 도구 실행이 즉시 허용돼. 신뢰하는 디렉토리에서만 사용.")
    }
    var sectionAbout: String { t("About", "정보") }
    var aboutVersion: String { t("Version", "버전") }
    var aboutBundle: String { t("Bundle", "번들") }
    var aboutClaudeCLI: String { t("Claude CLI", "Claude CLI") }

    // MARK: starters
    var starterPrimary: [LocalizedStarter] {
        [
            LocalizedStarter(
                label: t("Explain this codebase", "이 폴더 코드 설명해줘"),
                prompt: t(
                    "Briefly summarize the structure and role of the code in the current working directory.",
                    "현재 작업 디렉토리의 코드 구조와 역할을 짧게 요약해줘."
                ),
                symbol: "doc.text",
                tint: .green
            ),
            LocalizedStarter(
                label: t("Find a bug", "버그 찾아줘"),
                prompt: t(
                    "Look for potential bugs or risky patterns in this project.",
                    "이 프로젝트에서 잠재적인 버그나 위험한 패턴을 찾아줘."
                ),
                symbol: "ant",
                tint: .green
            ),
            LocalizedStarter(
                label: t("Write tests", "테스트 작성해줘"),
                prompt: t(
                    "Find places with low test coverage and add unit tests there.",
                    "테스트 커버리지가 낮은 곳을 골라서 단위 테스트를 작성해줘."
                ),
                symbol: "checkmark.seal",
                tint: .green
            ),
            LocalizedStarter(
                label: t("Suggest a refactor", "리팩토링 제안"),
                prompt: t(
                    "Find opportunities to improve readability and structure, and propose a refactor plan.",
                    "가독성/구조 개선 여지를 찾아 리팩토링 계획을 알려줘."
                ),
                symbol: "arrow.triangle.2.circlepath",
                tint: .green
            )
        ]
    }

    var starterSecondary: [LocalizedStarter] {
        [
            LocalizedStarter(
                label: t("Search the web", "웹에서 검색"),
                prompt: t(
                    "Find recent news about Anthropic Claude on the web and summarize.",
                    "최근 Anthropic Claude 관련 뉴스를 웹에서 찾아 요약해줘."
                ),
                symbol: "magnifyingglass",
                tint: .blue
            ),
            LocalizedStarter(
                label: t("Inspect environment", "환경 점검"),
                prompt: t(
                    "Check my macOS dev environment (node, swift, git versions, etc).",
                    "내 macOS 개발 환경 (node, swift, git 버전 등) 을 확인해줘."
                ),
                symbol: "gearshape",
                tint: .blue
            )
        ]
    }
}

struct LocalizedStarter: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let prompt: String
    let symbol: String
    let tint: Color

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: LocalizedStarter, rhs: LocalizedStarter) -> Bool { lhs.id == rhs.id }
}
