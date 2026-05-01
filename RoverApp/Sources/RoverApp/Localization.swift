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
    var bubbleStopButton: String { t("stop", "중단") }
    var bubbleNewConvButton: String { t("new", "새 대화") }

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
    var menuNewConversation: String { t("New conversation", "새 대화 시작") }

    // MARK: settings tabs
    var settingsTitle: String { t("Rover Settings", "Rover 설정") }
    var tabGeneral: String { t("General", "일반") }
    var tabBackend: String { t("Backend", "백엔드") }
    var tabTriggers: String { t("Triggers", "트리거") }
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
    var aboutCodexCLI: String { t("Codex CLI", "Codex CLI") }

    // MARK: settings - permission bubble
    var sectionPermissionBubble: String { t("Permission bubble", "권한 버블") }
    var permBubbleToggle: String { t("Show permission requests in Rover", "권한 요청을 Rover 말풍선에 표시") }
    var permBubbleHint: String {
        t("Installs a Claude Code PreToolUse hook in ~/.claude/settings.json. Tool permission asks pop up as Allow / Deny in the bubble. If Rover isn't running the hook silently falls back to Claude's terminal prompt.",
          "Claude Code의 PreToolUse 훅을 ~/.claude/settings.json 에 설치해. 도구 권한 요청이 말풍선의 Allow/Deny 로 뜸. Rover 가 꺼져 있으면 훅이 조용히 빠져서 Claude 의 터미널 프롬프트로 폴백.")
    }
    var permBubbleAllow: String { t("Allow", "허용") }
    var permBubbleDeny: String { t("Deny", "거부") }
    var permBubbleAsk: String { t("Decide later", "나중에") }
    var permBubbleHeader: String { t("permission requested", "권한 요청") }
    var permBubbleShowDetail: String { t("Show full input", "전체 입력 보기") }
    var permBubbleHideDetail: String { t("Hide", "숨기기") }

    // MARK: settings - CLI binaries
    var sectionCLIBinaries: String { t("CLI binaries", "CLI 바이너리") }
    var cliBinaryChoose: String { t("Choose…", "선택…") }
    var cliBinaryReset: String { t("Reset", "초기화") }
    var cliBinaryAuto: String { t("auto-detected", "자동 탐지") }
    var cliBinaryCustom: String { t("custom", "사용자 지정") }
    var cliBinaryNotFound: String { t("not found at this path", "해당 경로에 파일 없음") }
    var cliBinariesHint: String {
        t("Override the auto-detected path if your CLI lives somewhere else (e.g. asdf, mise, or a custom install).",
          "CLI가 자동 탐지되지 않는 위치(asdf, mise, 사용자 설치 등)에 있다면 직접 지정.")
    }

    // MARK: settings - backend
    var sectionBackend: String { t("Active backend", "활성 백엔드") }
    var sectionAnthropicKey: String { t("Anthropic API key", "Anthropic API 키") }
    var anthropicKeyPlaceholder: String { t("sk-ant-…", "sk-ant-…") }
    var anthropicKeySave: String { t("Save", "저장") }
    var anthropicKeyClear: String { t("Clear", "삭제") }
    var anthropicKeyStored: String { t("Stored in Keychain.", "Keychain에 저장됨.") }
    var anthropicKeyMissing: String { t("Not set — Computer Use will refuse to run.", "미설정 — Computer Use는 실행할 수 없어.") }

    // MARK: settings - safety
    var sectionSafety: String { t("Safety", "안전") }
    var safetyDryRun: String { t("Dry-run mode (don't post events)", "Dry-run 모드 (실제 이벤트 안 보냄)") }
    var safetyDryRunHint: String {
        t("When on, mouse / keyboard tools log what they would do but don't actually click or type. Esc cancels the agent loop at any time.",
          "켜면 마우스 / 키보드 도구는 실행 의도만 기록하고 실제로는 클릭/타이핑하지 않아. 도중에 Esc를 누르면 에이전트 루프가 즉시 중단돼.")
    }
    var safetyActionDelay: String { t("Action delay", "액션 간격") }

    // MARK: settings - triggers
    var sectionHotkey: String { t("Global hotkey", "전역 핫키") }
    var hotkeyEnabled: String { t("Enable ⌘⇧Space hotkey", "⌘⇧Space 핫키 활성화") }
    var hotkeyHint: String {
        t("Press ⌘⇧Space anywhere to summon Roger. The bubble opens with the input field focused.",
          "어디서든 ⌘⇧Space를 눌러 Roger를 호출. 입력 포커스된 말풍선이 열림.")
    }
    var sectionActiveApp: String { t("Active app changes", "활성 앱 변화") }
    var activeAppEnabled: String { t("Animate when I switch apps", "앱 전환 시 애니메이션") }
    var activeAppDebounce: String { t("Debounce", "쿨타임") }
    var activeAppHint: String {
        t("Roger animates and shows a brief speech bubble when you switch to a new app. No agent calls — zero cost.",
          "다른 앱으로 전환하면 Roger가 잠깐 애니메이션 + 말풍선. 에이전트 호출 없음 — 비용 0.")
    }
    var sectionPeriodic: String { t("Periodic screen observation", "주기적 화면 관찰") }
    var periodicEnabled: String { t("Glance at my screen periodically", "주기적으로 화면 보기") }
    var periodicInterval: String { t("Interval", "주기") }
    var periodicHint: String {
        t("Sends a screenshot to Computer Use on every interval to ask if you need help. Each glance costs API credits — keep the interval long.",
          "매 주기마다 스크린샷을 Computer Use에 보내서 도움 필요한지 판단. 호출당 API 비용 발생 — 주기를 길게 유지해.")
    }
    var sectionSchedules: String { t("Scheduled tasks", "예약 작업") }
    var scheduleEnabled: String { t("Run scheduled prompts", "예약 프롬프트 실행") }
    var scheduleAdd: String { t("Add", "추가") }
    var scheduleRemove: String { t("Remove", "삭제") }
    var scheduleTime: String { t("Time (HH:MM)", "시간 (HH:MM)") }
    var schedulePrompt: String { t("Prompt", "프롬프트") }
    var scheduleHint: String {
        t("Each entry fires once per day at the given time. Computer Use runs the prompt — make sure your API key is set.",
          "각 항목이 매일 정해진 시각에 한 번 실행. Computer Use로 프롬프트 실행 — API 키 설정 필수.")
    }

    // MARK: settings - TCC
    var sectionTccPermissions: String { t("Computer Use permissions", "Computer Use 권한") }
    var tccAccessibility: String { t("Accessibility (mouse + keyboard)", "Accessibility (마우스 + 키보드)") }
    var tccScreenRecording: String { t("Screen Recording (screenshots)", "Screen Recording (스크린샷)") }
    var tccOpenPane: String { t("Open…", "열기…") }
    var tccPermissionsHint: String {
        t("Both must be granted for Computer Use to function. macOS may need the app to be re-launched after granting.",
          "둘 다 허용해야 Computer Use가 동작해. 권한 부여 후 앱 재시작이 필요할 수 있어.")
    }

    var backendHint: String {
        t("Choose the engine that drives Roger. Coding agents (Claude Code, Codex) work in the working directory; Computer Use lets Roger see your screen and click for you.",
          "Roger를 움직이는 엔진을 선택해. 코딩 에이전트(Claude Code, Codex)는 작업 디렉토리에서 동작하고, Computer Use는 Roger가 화면을 보고 직접 클릭/타이핑할 수 있게 해.")
    }
    func backendBlurb(_ id: BackendID) -> String {
        switch id {
        case .claudeCodeCLI:
            return t("Spawns the local `claude` CLI in stream-json mode.",
                     "로컬 `claude` CLI를 stream-json 모드로 실행.")
        case .codexCLI:
            return t("Spawns the local `codex exec --json` CLI. Auth comes from your existing Codex login.",
                     "로컬 `codex exec --json`을 실행. 인증은 기존 Codex 로그인을 사용.")
        case .anthropicComputerUse:
            return t("Direct Anthropic API + Computer Use tool. Roger drives your desktop. Requires API key + permissions.",
                     "Anthropic API 직통 + Computer Use 도구. Roger가 데스크톱을 직접 움직임. API key + 권한 필요.")
        }
    }

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
