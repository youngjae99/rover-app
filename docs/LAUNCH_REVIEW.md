# Rover.app — README 개선 / 기능 추가 / 런칭 준비 검토

> 레퍼런스: [`rullerzhou-afk/clawd-on-desk`](https://github.com/rullerzhou-afk/clawd-on-desk) (Electron, ⭐ 1,993 · 2026-05 기준)

## 0. 두 프로젝트의 본질적 포지셔닝 차이

| | clawd-on-desk | rover-app |
|---|---|---|
| 본질 | **수동적 옵저버** — 코딩 에이전트가 무엇을 하는지 *지켜보는* 펫 | **능동적 컴패니언** — 사용자가 *말을 걸고*, 더 나아가 펫이 *직접 컴퓨터를 조작* |
| 입력 | 없음 (훅으로 이벤트만 수신) | 말풍선 입력창 + 트리거 + 스케줄 |
| 백엔드 | 9종 에이전트 hook 통합 (Claude Code, Codex, Cursor, Copilot, Gemini, opencode 등) | 3종 (Claude Code CLI, Codex CLI, Anthropic Computer Use) — 단 Computer Use 는 *마우스/키보드 조작* 가능 |
| 플랫폼 | Win/macOS/Linux (Electron) | macOS only (Swift native) |
| 차별 무기 | 멀티 에이전트, 권한 버블, 커스텀 테마, 다국어 README 4종 | 정통 XP Rover IP, 네이티브 앱(가벼움), Computer Use 능동 조작, KR/EN 로컬라이제이션 |

핵심 인사이트: clawd 는 "다 지켜본다", rover 는 "직접 한다 + 너랑 대화한다". 같은 카테고리지만 가치 제안이 다르므로 **그대로 따라하는 건 패배 전략**. Rover 의 강점(Computer Use, XP 노스탤지어, 능동 대화)을 정면에 두고 clawd 의 *플랫폼 기능* 만 흡수하는 방향이 맞다.

---

## 1. README 개선안

### 1.1 현재 README 의 문제

1. **One-liner 부재.** "A homage to Rover…" 로 시작하는 문단이 길고, GitHub repo description 으로 그대로 못 쓴다. 첫 줄이 SEO / 소셜 카드 / Awesome 리스트 등재 시 노출되는데 약하다.
2. **배지 없음.** clawd 는 version / platform / stars / "Mentioned in Awesome" 4종을 상단에 박아 신뢰도 시그널을 준다. Rover 는 0개.
3. **Demo 가 placeholder.** "Demo video coming soon" 은 출시 전 README 의 가장 큰 약점. 첫 방문자 90% 가 여기서 이탈한다.
4. **차별점이 묻혀있다.** Computer Use 백엔드(이게 진짜 무기)가 Features 섹션 중간에 한 줄 들어가 있어 묻힘. 첫 화면에서 보이지 않음.
5. **Repository layout 섹션이 너무 큼.** 25줄짜리 트리는 컨트리뷰터용 — 일반 사용자에겐 노이즈. CONTRIBUTING.md 로 분리.
6. **TODO 섹션 일부가 outdated.** `Rover.icns` 가 이미 `RoverApp/` 에 있고, 최근 커밋 `c0a36b6` 가 아이콘 생성을 끝냈는데 README 는 "App icon. The bundle ships without one." 라고 적혀 있음.
7. **로컬라이제이션 README 부재.** 앱이 KR 로컬라이즈되어 있는데 README 는 EN-only. 한국 커뮤니티(긱뉴스, 클리앙) 유입 채널을 못 살림.
8. **"What is this" 섹션이 길다.** 한 문단에 200+ 단어. 스캔 안 됨.

### 1.2 추천 One-liner (3안)

> **A안 (감성 + 기능 명시, 추천):**
> *Rover is back. The Windows XP search dog, reborn as a macOS desktop pet that actually drives your coding agent — Claude Code, Codex, or Computer Use.*

> **B안 (제품-first):**
> *A floating macOS desktop pet that talks to your AI coding agent — and, when you ask, takes the mouse and keyboard for you.*

> **C안 (clawd 와 정면 대비):**
> *The XP search dog, back as a macOS pet — but this one talks back, and can run your computer.*

GitHub repo `description` 필드(현재 비어있음)에는 A안 축약: *"Windows XP's Rover, reborn as a macOS pet that drives Claude Code, Codex, or Computer Use."*

### 1.3 README 골격

```
<Hero>
  - 로고 / 타이틀 (rover.app)
  - 다국어 README 링크 (EN · 한국어)
  - 배지 4종 (release · platform=macOS · license=MIT · stars)
  - One-liner (A안)
  - 데모 GIF / mp4 (placeholder 가 아닌 실제 영상)

## What makes Rover different
  - 3 bullet 비교: 펫이 말한다 / 펫이 조작한다 / 정통 XP 자산

## Animations
  - 12-cell 표 (clawd 처럼 grid)

## Quick Start
  - DMG 다운로드 (5줄)
  - From source (5줄, 한 코드블록)

## Backends
  - Claude Code CLI / Codex CLI / Computer Use 3개 카드

## Triggers
  - 4 trigger × 한줄 설명

## Permissions
  - 표 1개

## Settings · Localization · Safety
  - 각 한 단락

## Roadmap
  - 명시적 섹션

## Contributing / License / Credits
```

핵심: **Demo → What makes different → Animations → Quick Start** 가 화면 첫 두 스크롤에 다 들어가야 한다. clawd 가 그렇게 되어있고 그게 별 1.9k 의 이유 중 하나.

### 1.4 즉시 손볼 디테일

- `RoverApp/Rover.icns` 가 존재하므로 TODO 의 "App icon" 항목 제거.
- `RoverApp/package.sh` 가 최근 커밋 `031f0c7` 에서 `create-dmg` 의존성을 빼고 `hdiutil` 로 갈아탔는데 README 는 여전히 `brew install create-dmg` 안내. 수정.
- 최근 추가된 *session resume* (`a4d0dce`) / *transcript with reasoning* (`6e2d6c6`) 기능이 README Features 에 빠져있음.
- Limitations 의 "Conversation memory across prompts" 도 session resume 으로 일부 해결됐으니 문구 갱신.
- `docs/rover-states.png` 활용도가 낮음 — 12-cell animation grid 로 대체하면 시각적 임팩트 ↑.

---

## 2. 추가할 만한 기능 (우선순위)

### P0 — 출시 직전 반드시

1. **데모 영상 / 애니메이션 그리드 GIF** (60–90초 영상 + 12-cell sprite grid).
2. **App icon 노출 확인** (이미 빌드됨).
3. **README 한국어판** (`README.ko-KR.md`) — KR 커뮤니티 유입 채널 확보.
4. **GitHub release 자동화** (tag push → DMG artifact GH Action).
5. **`claude` CLI 경로 설정 UI** — auto-probe 실패 시 GUI 에서 path 지정. 첫 사용자 경험 직결.

### P1 — 출시 후 한 달 내

6. **Permission Bubble.** Claude Code 의 `PreToolUse` hook → Rover 말풍선의 Allow/Deny 버튼. 현재 `--dangerously-skip-permissions` 의 정반대 축. 안전 + UX 동시. 구현: hook 자동 등록 + 로컬 HTTP 응답.
7. **멀티 에이전트 단계적 지원.** 1) Cursor Agent hooks (`~/.cursor/hooks.json`) 2) Gemini CLI 3) Copilot/opencode. *passive observer* 백엔드 하나 추가하는 형태. Computer Use 는 Rover 만의 무기로 유지.
8. **세션 HUD / 대시보드** — Rover 옆 칩 ("Claude Code · 14 files · 2m"), 우클릭 → Open Dashboard.
9. **마크다운 렌더링** — 응답 텍스트.
10. **Auto-update (Sparkle)** — appcast.xml + EdDSA key.
11. **DND 모드** — 회의/발표 중 자동 침묵.

### P2 — 중기

12. **Custom themes / sprite packs** (`~/Library/Application Support/Rover/Themes/`). 원본 XP Rover 자산은 IP 핵심이므로 *추가* 테마 형태로만.
13. **Mini mode / 화면 가장자리 peek**.
14. **눈동자 시선 추적** — idle 때 커서 따라.
15. **음성 인식 입력** — Whisper.cpp 또는 Speech.framework.
16. **Computer Use 안전 강화** — action preview window, forbidden zone (drag-rectangle).
17. **Conversation memory** 검증/완성.
18. **다국어 확장** — JP, ZH.
19. **Telemetry (opt-in)** — Plausible / PostHog 셀프호스트.

### Rover 가 *하지 말아야* 할 것

- **Linux / Windows 포팅.** Swift native 가 차별점. Electron 전쟁은 clawd 가 이미 점유.
- **9종 에이전트 hook 모두 지원.** P1-7 의 상위 3종에서 멈출 것. 통합 유지비용 ↑↑.

---

## 3. 런칭 준비 체크리스트

### 3.1 기술

- [ ] **Apple Developer Program 가입 ($99/년)** — Code signing + notarization 의 전제.
- [ ] **Developer ID 인증서로 코드사인** (`codesign --options=runtime --timestamp`).
- [ ] **Notarization** (`xcrun notarytool submit`) + **stapling** (`xcrun stapler staple`).
- [ ] **하드닝 entitlements** 검토 (Computer Use → Accessibility / Screen Recording / Apple Events / Sandbox-off).
- [ ] **Sparkle 자동 업데이트** + appcast.xml + EdDSA key.
- [ ] **GitHub Actions CI**: tag push → build → sign → notarize → DMG 업로드.
- [ ] **크래시 리포팅** (선택, opt-in).
- [ ] **TCC 권한 가이드** — 첫 실행 시 onboarding 5장.
- [ ] **Computer Use kill switch** — 마지막 5초 actions 로그 + 차단 UI.
- [ ] **Privacy policy** — Anthropic API 호출 데이터 (스크린샷 포함) 명시.

### 3.2 마케팅 / 배포 채널

- [ ] **랜딩 페이지** — 원페이지 + DMG 다운로드 + 영상.
- [ ] **Show HN** — Computer Use 시연 영상 1개 본문에.
- [ ] **Product Hunt** — Tuesday 12:01 AM PST.
- [ ] **Reddit** — r/macapps, r/MacOS, r/ClaudeAI, r/LocalLLaMA, r/Anthropic.
- [ ] **X / Threads 데모 스레드** — 30초 영상 + 5장 스크린샷.
- [ ] **한국 커뮤니티** — 긱뉴스, 클리앙, OKKY (KR README 가 전제).
- [ ] **Awesome Claude Code PR**.
- [ ] **Anthropic 디스커션 / Discord**.
- [ ] **YouTube 5분 walkthrough**.

### 3.3 커뮤니티 / 운영

- [ ] **Issue 템플릿** (`.github/ISSUE_TEMPLATE/`).
- [ ] **CONTRIBUTING.md** — Repository layout 이전.
- [ ] **CHANGELOG.md** — Sparkle 업데이트와 자동 연동.
- [ ] **CODE_OF_CONDUCT.md**.
- [ ] **Discussions 활성화**.
- [ ] **GitHub Sponsors** (선택).

### 3.4 Computer Use 만의 추가 리스크 관리

- [ ] **dry-run 기본값 ON** — 가장 안전한 쪽이 디폴트.
- [ ] **API 비용 가시성** — "이번 세션 추정 $X.XX" UI.
- [ ] **README warning box** — "Rover can click, type, take screenshots…" 빨간 박스로 명시.

---

## 4. 손볼 핵심 파일

- `README.md` — 1.3 골격으로 재작성.
- `README.ko-KR.md` — 신규 (P0).
- `docs/` — 데모 mp4/gif, 12-state grid PNG.
- `CONTRIBUTING.md` — 신규, repo layout 이전.
- `.github/workflows/release.yml` — 신규, sign+notarize+release.
- `RoverApp/Sources/RoverApp/Agents/` — Permission Bubble + Cursor/Gemini hooks 모듈.
- `RoverApp/package.sh` ↔ README 동기화 (이미 hdiutil 로 전환됨).
