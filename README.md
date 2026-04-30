# Rover · 부활 (Revival 2026)

> Microsoft Windows XP의 검색 동반자 **Rover**를 기리며 — 21세기 macOS 데스크톱 펫으로 부활시킨 작은 프로젝트.
> 노란 리트리버는 이번엔 검색이 아니라 **Claude Code** 와 함께 일합니다.

```
   ___                       _____
  / _ \  ___  __   __  ___  | || |__
 | (_) ||_ /  \ \ / / / -_) |__   _|
  \___//___|   \_/   \___|     |_|
        XP 2001                  2026
```

## 이 프로젝트는

2001년, Microsoft는 Windows XP의 검색 화면에 친근한 가이드를 넣었습니다 — 노란 리트리버 강아지 **Rover**. 검색 결과를 찾아주는 데스크톱 동반자였죠. 25년이 지나, 같은 발상을 21세기 답게 다시 살려봅니다.

원본 Rover의 스프라이트와 사운드는 그대로 살리되, 이번엔 그가 검색이 아니라 **Claude Code** 를 통해 코딩, 설명, 검색, 모든 작업을 도와줍니다. 화면 어디든 떠다니고, 클릭하면 XP 스타일의 말풍선이 위로 펼쳐지며, 24가지 애니메이션 상태(눈 깜빡임, 잠자기, 짖기, 핥기, 부끄러워하기 등)로 사용자 입력에 반응합니다.

순수한 노스탤지어 프로젝트 — 상업적 의도 없음.

## 특징

- 🐶 **떠있는 데스크톱 펫** — 투명 borderless 윈도우, 어디든 자유롭게 드래그
- 💬 **XP Luna 스타일 말풍선** — 클릭 한 번으로 입력창 열림, claude CLI 응답 실시간 스트리밍
- 🎬 **24개 애니메이션 상태** — 원본 PNG 스프라이트 (~470 프레임): idle, sleep, speak, eat, reading, ashamed, lick, haf, exit 등
- 🔊 **원본 사운드** — Haf, Lick, Whine, Snoring 등 그대로
- 🎯 **stream-json 파서** — claude CLI 출력을 NDJSON으로 실시간 파싱, tool 사용에 따라 자동 애니메이션 전환
  - `Read` / `Glob` / `Grep` → Reading 모드
  - `Bash` / `Edit` / `Write` → Eat 모드
  - `WebFetch` / `WebSearch` → Lick 모드
  - 에러 → Ashamed 모드
- ⚙️ **설정 창** — 모델 선택 (Opus 4.7 / Sonnet 4.6 / Haiku 4.5), 시스템 프롬프트 편집, 작업 디렉토리, 메뉴바 토글, dangerous-skip-permissions
- 🌐 **i18n** — 한국어 / English (시스템 자동 감지 + 수동 오버라이드)
- 🖱️ **메뉴바 아이콘** — paw 아이콘으로 어디서든 즉시 호출
- 💤 **자동 sleep** — 60초 무활동 시 잠자기 애니메이션, 클릭하면 깨어남

## 설치

### 방법 1: DMG (권장)

1. [Releases](https://github.com/youngjae99/21st-rover/releases) 페이지에서 최신 `Rover.dmg` 다운로드
2. DMG 더블클릭 → `Rover.app` 을 `Applications` 폴더로 드래그
3. Launchpad 또는 `~/Applications` 에서 Rover 실행
4. 메뉴바 우상단의 🐾 아이콘 클릭 → "Ask Rover…" 또는 화면에 떠있는 강아지 클릭

> 첫 실행 시 macOS Gatekeeper 경고가 뜨면, 우클릭 → "열기" 로 우회

### 방법 2: 소스에서 빌드

요구사항:
- macOS 14+
- Swift 5.9+ (Command Line Tools 설치만 되어 있으면 됨, Xcode 풀버전 불필요)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI 가 PATH 또는 `/Applications/cmux.app/Contents/Resources/bin/claude` 등에 설치되어 있어야 함

```bash
git clone https://github.com/youngjae99/21st-rover.git
cd 21st-rover/RoverApp
./run.sh
```

`run.sh` 가 자동으로:
1. `rover/Resources/` 의 PNG·WAV 자산을 SPM 리소스 디렉토리로 rsync
2. `swift build` (debug)
3. `Rover.app` 번들 조립
4. 앱 실행

## DMG 직접 만들기

릴리즈 배포용 DMG를 로컬에서 만들고 싶다면:

```bash
brew install create-dmg
cd RoverApp
./package.sh
```

`Rover.dmg` 가 생성됩니다. 그대로 GitHub Release에 업로드하면 끝.

## 동작 방식

```
사용자 클릭
   ↓
SpeechBubbleView (입력창)
   ↓ 사용자 입력 + Enter
ClaudeRunner.send(prompt)
   ↓ stdin
$ claude -p --output-format stream-json --include-partial-messages \
         --model <opus/sonnet/haiku> --append-system-prompt "..."
   ↓ NDJSON (한 줄씩)
ClaudeRunner.handleLine → ClaudeEvent
   ↓
AppViewModel.handleEvent
   ├→ SpeechBubbleView (responseText 누적, 자동 스크롤)
   └→ RoverState (Speak/Eat/Reading/Ashamed/...)
        ↓
   SpriteAnimator (NSImage 시퀀스, 8–14fps)
        ↓
   RoverSpriteView
```

## 디렉토리 구조

```
21st-rover/
├── rover/                      ← 원본 Microsoft Rover 자산 + C# 재구현
│   ├── Resources/              ← PNG 스프라이트, WAV 사운드, EN/RU 텍스트
│   ├── Animation.cs            ← 원본 애니메이션 로직 (Windows Forms)
│   └── ...
└── RoverApp/                   ← macOS Swift 앱
    ├── Package.swift           ← SwiftPM
    ├── Info.plist              ← 번들 메타
    ├── build.sh                ← 자산 동기화 + swift build + .app 묶기
    ├── run.sh                  ← build + open
    ├── package.sh              ← create-dmg 패키징
    └── Sources/RoverApp/
        ├── main.swift                   ← NSApp 진입점, 윈도우 + 메뉴바 셋업
        ├── FloatingWindow.swift         ← borderless 투명 NSWindow + 사이즈 추적 hosting view
        ├── RoverPetView.swift           ← Rover 스프라이트 + 드래그 + 우클릭 메뉴
        ├── RoverSpriteView.swift        ← 프레임 시퀀스 애니메이터
        ├── SpeechBubbleView.swift       ← XP Luna 말풍선 + 입력 + 응답
        ├── AppViewModel.swift           ← 상태 머신 + 이벤트 → 애니메이션 매핑
        ├── ClaudeRunner.swift           ← claude CLI 자식 프로세스 + NDJSON 파서
        ├── AnimationCatalog.swift       ← 24개 상태별 PNG 시퀀스 로딩/캐싱
        ├── SoundPlayer.swift            ← AVAudioPlayer 풀
        ├── Settings.swift               ← UserDefaults 영구 저장
        ├── SettingsView.swift           ← 설정 창 4탭 UI
        ├── SettingsWindowController.swift
        ├── MenuBarController.swift      ← NSStatusItem (paw 아이콘)
        ├── Localization.swift           ← AppStrings (en/ko)
        └── Theme.swift                  ← XP 색상 토큰 + 커서 헬퍼
```

## 키보드 단축키

| 단축키       | 동작                  |
|--------------|-----------------------|
| 클릭 (Rover) | 입력창 열기           |
| 우클릭       | 컨텍스트 메뉴         |
| ⌘+,          | 설정 창               |
| Esc          | 말풍선 닫기           |
| ⌘+Q          | 종료                  |
| 메뉴바 클릭  | 입력창 열기 (어디서든)|

## 한계 / TODO

- [ ] 세션 지속 (`claude --continue` / `--resume`) — 현재는 매 프롬프트가 새 세션
- [ ] 응답 마크다운 렌더링 (현재 plain text)
- [ ] 글로벌 단축키 (⌘+Space 같은 시스템 hotkey)
- [ ] 앱 아이콘 `.icns` (Dock 활성화 시)
- [ ] Code signing + notarization (DMG 배포 시 Gatekeeper 우회 불필요하도록)
- [ ] Auto-update
- [ ] Claude CLI 경로 수동 설정 UI (현재는 자동 탐지)

## 크레딧

- 🐕 **원본 Rover 캐릭터 / 스프라이트 / 사운드**: Microsoft Corporation, "Search Companion" — Windows XP (2001)
- 🤖 **Claude Code**: [Anthropic](https://anthropic.com)
- 🚀 **macOS 부활판**: 이 저장소

원본 Rover 자산은 `rover/` 디렉토리에 보관되어 있습니다 (원본 Windows Forms C# 재구현 + 자산). 추억 보존 + 학습 목적의 비상업 프로젝트.

## 라이선스

- 원본 Microsoft Rover 자산: © Microsoft Corporation. 비상업/노스탤지어/교육 용도로만 사용.
- 이 저장소에 추가된 Swift 코드: MIT.

---

> "Rover는 결국 Windows Vista에서 사라졌지만, 우리는 그를 잊지 않았습니다."
