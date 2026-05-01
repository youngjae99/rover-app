<h1 align="center">Rover.app</h1>

<p align="center">
  <a href="README.md">English</a>
  ·
  <a href="README.ko-KR.md">한국어</a>
</p>

<p align="center">
  <a href="https://github.com/youngjae99/rover-app/releases"><img src="https://img.shields.io/github/v/release/youngjae99/rover-app?display_name=tag" alt="Release"></a>
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey" alt="Platform">
  <a href="LICENSE"><img src="https://img.shields.io/badge/code-MIT-blue" alt="License"></a>
  <a href="https://github.com/youngjae99/rover-app/stargazers"><img src="https://img.shields.io/github/stars/youngjae99/rover-app?style=flat&logo=github&color=yellow" alt="Stars"></a>
</p>

<p align="center">
  <img src="docs/rover-hero.gif" width="240" alt="macOS 위에서 동작하는 Windows XP 검색 컴패니언 Rover" />
</p>

<p align="center">
  <strong>로버가 돌아왔습니다.</strong> Windows XP의 그 노란 래브라도가, 이번엔 macOS 데스크탑에 떠다니며 코딩 에이전트를 실제로 운전합니다 — Claude Code, Codex, 그리고 Anthropic Computer Use.
</p>

<p align="center">
  <img src="docs/rover-states-grid.png" width="720" alt="Rover의 12가지 애니메이션 상태: idle, speak, reading, eat, sleep, tired, haf, lick, ashamed, attention, come, exit" />
  <br/>
  <em>총 24개 상태 중 12개</em>
</p>

> **데모 영상.** v1 런칭에 맞춰 60초 워크스루를 녹화 중입니다. 직접 캡처하려면 Cmd+Shift+5 → Record Selected Portion 으로 Rover 와 말풍선을 함께 담은 뒤 `docs/demo.mp4` 로 저장하세요.

---

## Rover 가 다른 점

다른 "AI 코딩 펫" 들은 에이전트를 *지켜봅니다*. Rover 는 *말도 걸 수 있고*, 원할 땐 *직접 키보드와 마우스를 잡습니다*.

- 🐶 **말이 통합니다.** Rover 를 클릭해 프롬프트를 입력하면, 에이전트의 응답이 XP Luna 풍 말풍선에 흘러나옵니다. 화면을 가리지 않게 위로 자라며 스크롤됩니다.
- 🖱️ **컴퓨터를 직접 운전합니다.** 백엔드를 Anthropic Computer Use 로 바꾸면 Rover 가 스크린샷을 찍고, 마우스를 움직이고, 타이핑하고, 스크롤합니다. dry-run / action delay / Esc 킬-스위치 포함.
- 🎞️ **진짜 그 Rover 입니다.** 2001년 출시 당시의 sprite 프레임과 WAV 사운드를 그대로 사용합니다. 25년 묵은 머슬 메모리, 그대로.

비영리 노스탤지어 프로젝트입니다. Microsoft 와 무관합니다.

---

## 빠른 시작

### DMG 설치 (권장)

1. [Releases](https://github.com/youngjae99/rover-app/releases) 에서 최신 `Rover.dmg` 를 받습니다.
2. DMG 를 열고 `Rover.app` 을 `Applications` 로 드래그한 뒤 Launchpad 에서 실행합니다.
3. Rover 를 클릭하거나 메뉴 바의 발바닥 아이콘을 클릭합니다.

> 첫 실행 시 macOS Gatekeeper: `Rover.app` 우클릭 → 열기. 코드 사이닝 / 노터라이즈는 [Roadmap](#roadmap) 항목입니다.

### 소스에서 빌드

```bash
git clone https://github.com/youngjae99/rover-app.git
cd rover-app/RoverApp
./run.sh
```

`run.sh` 는 `rover/Resources/` 의 자산을 동기화하고 `swift build` 후 `Rover.app` 을 ad-hoc 코드사인합니다 (이렇게 해야 macOS TCC 권한이 리빌드 사이에도 유지됩니다). macOS 14+, Swift 5.9+ 필요 (Command Line Tools 만으로도 충분, 풀 Xcode 불필요).

### DMG 만들기

```bash
cd RoverApp
./package.sh
```

`Rover.dmg` 가 `.app` 옆에 생성됩니다. `hdiutil` 을 직접 사용하므로 `create-dmg` 같은 외부 의존성이 없습니다.

---

## 백엔드

**Settings → Backend** 에서 선택하세요.

| 백엔드 | 동작 | 셋업 |
|---|---|---|
| **Claude Code CLI** *(기본값)* | `claude -p --output-format stream-json --include-partial-messages` 를 래핑. tool use 에 따라 애니메이션이 실시간 변경. | 표준 경로 자동 탐지 (`/opt/homebrew/bin/claude`, `~/.claude/local/claude` 등). |
| **Codex CLI** | OpenAI Codex CLI 에 동일한 방식. | `codex` 표준 경로 자동 탐지. |
| **Anthropic Computer Use** *(베타)* | Anthropic API 와 직접 통신. `claude-opus-4-7` Computer Use 루프. **Rover 가 스크린샷, 마우스, 키보드, 스크롤을 모두 직접 수행합니다.** | Settings → Backend 에 Anthropic API 키 입력 (macOS Keychain 에 저장). |

> ⚠️ **Computer Use 는 강력합니다 — 사용자가 할 수 있는 모든 것을 할 수 있습니다.** 새 작업에 신뢰가 생기기 전까지는 **dry-run 모드** (Settings → Advanced) 를 기본으로 두세요. Esc 로 언제든, 도구 실행 도중이라도 루프를 즉시 중단할 수 있습니다.

---

## 트리거

Rover 는 클릭만 기다리지 않습니다. **Settings → Triggers** 에서 각각 켜고 끌 수 있습니다.

- **글로벌 단축키** (⌘⇧Space). 다른 앱이 풀스크린이어도 어디서든 말풍선 호출.
- **앱 전환 감지**. 앱을 바꾸면 Rover 가 짧은 애니메이션을 재생하고 (선택적으로) 힌트를 띄움. 에이전트 호출 없음 — 비용 0.
- **주기적 화면 관찰**. 설정한 간격으로 Rover 가 Computer Use 에 스크린샷을 보내 도움이 필요한지 확인. 매번 API 비용이 발생하므로 기본값은 10분.
- **스케줄 작업**. HH:MM 단위 일별 항목, 활성 백엔드를 통해 고정 프롬프트 실행.

---

## 펫 동작

- 떠다니는 borderless / 투명 윈도우. 화면 어디로든 드래그 가능.
- 원본 sprite 시트 기반 24개 애니메이션 상태 (idle, idle fidgets, sleep, speak, eat, reading, ashamed, lick, haf, exit).
- 원본 WAV 사운드 (Haf, Lick, Whine, Snoring, Tap).
- 60초 비활성 시 수면. 클릭으로 깨우기.
- XP Luna 풍 말풍선. 하단 고정 앵커에서 위로 자람, 내용이 넘치면 스크롤, 화면 상단을 절대 침범하지 않음.
- 세션 인식: 최근 프롬프트와 reasoning 이 다음 대화로 이어짐.

---

## 키보드 / 마우스

| 동작 | 효과 |
|---|---|
| Rover 클릭 | 입력 말풍선 열기 |
| Rover 드래그 | 윈도우 이동 |
| Rover 우클릭 | 컨텍스트 메뉴 (Ask, Sound, Model, Settings, Quit) |
| 메뉴 바 발바닥 클릭 | 어디서든 말풍선 열기 |
| ⌘⇧Space | 글로벌 단축키 (Settings → Triggers 에서 활성화) |
| ⌘, | Settings 창 |
| Esc | 말풍선 닫기 + 실행 중인 에이전트 취소 |
| ⌘Q | 종료 |

---

## 첫 실행 권한

Computer Use, 글로벌 단축키, 앱 전환 트리거는 각각 다른 macOS 권한이 필요합니다. Rover 가 처음 필요한 시점에 사용자에게 물어봅니다.

| 권한 | 용도 |
|---|---|
| **Accessibility** | 마우스/키보드 제어, 글로벌 단축키 |
| **Screen Recording** | 주기적 화면 관찰, Computer Use 스크린샷 |
| **Apple Events** | 앱 전환 트리거 (foreground 앱 식별) |

API 키는 macOS Keychain 에 저장되며 평문 설정 파일에 노출되지 않습니다.

---

## 설정 (탭 6개)

- **General** — 언어 (System / English / 한국어), 메뉴 바 토글, 사운드 토글, 작업 디렉터리.
- **Backend** — 활성 백엔드 선택, Anthropic API 키 입력.
- **Triggers** — 위 4개 트리거 각각 on/off 및 튜닝.
- **Model** — Claude Opus 4.7 / Sonnet 4.6 / Haiku 4.5 (CLI 백엔드 한정).
- **System Prompt** — 영구 append-system-prompt, 언어별 기본값으로 리셋.
- **Advanced** — dry-run 토글, action delay, `--dangerously-skip-permissions` (CLI 백엔드), 버전 및 바이너리 경로.

---

## 작동 방식

```
trigger        click             ⌘⇧Space hotkey
hotkey         active-app        scheduled task
periodic       change            etc.
        \      |       /
         v     v      v
       TriggerContext
              |
              v
       AppViewModel
              |
              v
       AgentCoordinator
              |
   +----------+-----------+--------------------+
   v                      v                    v
ClaudeCodeCLI         CodexCLI         AnthropicComputerUse
(stdin -> stream-json) (stdin -> JSON)  (HTTPS, computer-use loop)
        \                |               /
         v               v              v
              AgentEvent stream
                    |
        +-----------+-----------+
        v                       v
   SpeechBubbleView         AnimationMapper
                                 |
                                 v
                          SpriteAnimator
                                 |
                                 v
                          RoverSpriteView
```

리포지토리 구조는 [CONTRIBUTING.md](CONTRIBUTING.md) 참고.

---

## Roadmap

공개적으로 추적합니다. 어떤 항목이든 PR 환영.

- [ ] **코드 사이닝 + 노터라이즈** (배포용). 릴리즈 워크플로우는 이미 준비됨 ([docs/SIGNING.md](docs/SIGNING.md)). GitHub Secrets 6개를 채우면 Developer ID + 노터라이즈 모드로 전환. 그 전까지는 ad-hoc DMG 가 빌드되어 Gatekeeper 가 첫 실행에 우클릭 → Open 을 요구.
- [ ] **Sparkle 자동 업데이트.** 현재는 가벼운 GitHub Releases 기반 버전 체커가 들어있음 (Settings → Advanced → Updates). Sparkle 은 사이닝 트랙과 함께.
- [x] **권한 버블** — Claude Code 의 `PreToolUse` 훅을 자동 설치 (Settings → Backend 에서 opt-in). Rover 가 꺼져 있으면 Claude 의 터미널 프롬프트로 폴백.
- [x] **마크다운 렌더링** — assistant 응답이 inline markdown + fenced code block 렌더링.
- [x] **`claude` CLI 경로 설정 UI** (Settings → Advanced → CLI binaries).
- [x] **Cursor Agent 옵저버 모드** — `~/.cursor/hooks.json` 에 훅 자동 설치. Gemini / Copilot / opencode 는 TODO.
- [x] **세션 HUD** — 말풍선 닫혀 있을 때 Rover 옆에 활성 세션 칩.
- [ ] **커스텀 테마** — `~/Library/Application Support/Rover/Themes/` 에 sprite pack 드롭.
- [x] **방해 금지 모드** — 사운드 / 옵저버 힌트 / 자동 트리거 차단, 권한 요청은 폴백. 메뉴바 발바닥 아이콘이 달 모양으로 바뀜.
- [ ] **멀티 모니터 인식**.

---

## 로컬라이제이션

- 현재 영어 / 한국어 지원.
- 시스템 언어 자동 감지. Settings 에서 수동 변경 가능.
- 언어 추가는 `Sources/RoverApp/Localization.swift` 에 strings 추가 후 PR.

---

## 크레딧

- Rover 캐릭터, sprite, 사운드: Microsoft Corporation 의 자산 (Windows XP Search Companion, 2001).
- Claude Code: [Anthropic](https://anthropic.com).
- macOS 부활: 이 리포지토리.

`rover/` 디렉터리에는 원본 자산과 참고용 C# Windows Forms 구현이 함께 들어 있습니다. 보존 / 교육 목적으로만 포함.

---

## 라이선스

- 원본 Microsoft Rover 자산은 Microsoft Corporation 의 소유. 노스탤지어 / 교육 목적의 fair use 로만 포함. 상업적 재배포 금지.
- 이 리포지토리에 추가된 Swift 코드는 MIT License.

> 로버는 Vista 와 함께 떠났습니다. 우리는 작별 인사를 못 했습니다.
