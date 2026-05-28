# Anini ✦

A floating, always-available AI assistant for macOS — built in native SwiftUI.

- **⌥Space** anywhere to summon. Type a question, get an answer.
- Lives in your menu bar as a sparkle (✦), with a notch widget for to-dos, now playing, and language practice.
- Backed by **Claude Code** (default) or **OpenAI Codex** — pick in Settings.
- Full Mac control: shell, AppleScript, Apple Music, iMessage, FaceTime, Calendar, Contacts, screenshots, and more.
- API keys live in your macOS Keychain. No cloud, no relay.

---

## Screenshots

| Light | Dark |
|---|---|
| ![Anini chat — light mode](docs/screenshots/chat-light.png) | ![Anini chat — dark mode](docs/screenshots/chat-dark.png) |

**Notch widget** — now playing, chat, and to-dos:

![Anini notch widget](docs/screenshots/notch_widget.png)

**To-do actions** — let Anini do it later, or complete it now:

![Anini notch to-dos menu](docs/screenshots/notch_todos_menu.png)

**Calendar demo** — Anini adding a Google Calendar event from chat:

![Anini chat — calendar demo](docs/screenshots/chat-calendar-demo.png)

---

## Requirements

Before you build, you'll need:

| Tool | Why | How to get it |
|---|---|---|
| macOS 26 (Tahoe) or later | Deployment target | System Settings → Software Update |
| Xcode 16+ | Build the app | Mac App Store |
| Node.js | The Claude/Codex CLIs run on Node | [nodejs.org](https://nodejs.org) |
| Homebrew | Install xcodegen | [brew.sh](https://brew.sh) |
| xcodegen | Generates `Anini.xcodeproj` from `project.yml` | `brew install xcodegen` |
| Claude Code CLI *or* Codex CLI | The AI brain Anini talks to | See [Pick a backend](#pick-a-backend) below |
| A way to sign in to that CLI | Either a subscription or an API key | See [Pick a backend](#pick-a-backend) below — both options work |

---

## Install (one-time setup)

### 1. Clone

```bash
git clone <this-repo-url> ~/Projects/Anini
cd ~/Projects/Anini
```

### 2. Set up code signing

This creates a stable self-signed certificate in your Keychain so macOS permissions
(Screen Recording, iMessage, etc.) don't break every time you rebuild Anini.

```bash
./scripts/setup-signing.sh
```

macOS will ask for your Mac login password once. The cert lives only on your Mac.

### 3. Generate the Xcode project

```bash
xcodegen generate
```

### 4. Build in Xcode

```bash
open Anini.xcodeproj
```

In Xcode: press **`Cmd+B`** to build. **Do NOT press `Cmd+R`** — Xcode's debug-dylib
feature will fight with the signing setup and crash the app.

### 5. Launch

You'll find the built app at:
```
~/Library/Developer/Xcode/DerivedData/Anini-*/Build/Products/Debug/Anini.app
```

Optional but recommended — drop a symlink in `/Applications` so you can launch from Spotlight:

```bash
ln -s ~/Library/Developer/Xcode/DerivedData/Anini-*/Build/Products/Debug/Anini.app /Applications/Anini.app
```

Then `Cmd+Space → "Anini" → Enter` opens it anytime.

---

## Pick a backend

Anini supports two AI backends — choose whichever you prefer (or install both and switch in Settings).

![Anini settings — AI backend](docs/screenshots/settings-backend.png)

### Claude Code (recommended)

```bash
npm install -g @anthropic-ai/claude-code
```

Then sign the CLI in with **either** of:

- **Your Claude subscription** (Pro / Max / Team) — run `claude` once in any
  terminal and follow the in-terminal login prompt. Free if you already pay
  for Claude. ✨
- **An Anthropic API key** (pay-per-use) — get one at
  [console.anthropic.com](https://console.anthropic.com) → API Keys, then paste
  it into Anini's Settings → AI Backend.

### OpenAI Codex

```bash
npm install -g @openai/codex
```

Then sign the CLI in with **either** of:

- **Your ChatGPT subscription** (Plus / Pro / Team) — run `codex login` and
  sign in with your ChatGPT account. ✨
- **An OpenAI API key** (pay-per-use) — get one at
  [platform.openai.com](https://platform.openai.com) → API Keys, then paste it
  into Anini's Settings → AI Backend.

> **You only need to paste an API key into Anini if you're going the pay-per-use route.**
> If you signed in with your subscription, the CLI already has its credentials
> and Anini will use them automatically.

---

## First run

1. Press **⌥Space** (Option+Space) — Anini's floating window appears.
2. The onboarding wizard walks you through 4 steps:
   - **Choose a backend** — Claude Code or Codex (only the ones you installed will be selectable)
   - **Workspace** — pick the working directory the AI uses (default: your home folder)
   - **Sensitive paths** — toggle which folders the AI should never touch (`~/.ssh`, `~/.aws`, browser passwords, etc.)
   - **Permission mode** — "Safe" (the AI asks before risky actions) or full-auto
3. **Only if you're using the pay-per-use API key route**, paste your key into Settings → AI Backend afterward. Subscription users can skip this — the CLI already has its credentials.
4. Press ⌥Space anytime to open the chat.

---

## Permissions

macOS will pop a permission dialog the first time Anini tries to do something privacy-sensitive.
Click **OK** each time. These grants stick across rebuilds (thanks to the stable signing cert).

| Permission | When you'll see it | Why |
|---|---|---|
| **Screen Recording** | First time you click the camera button | Screenshots to share with the AI |
| **Automation → Messages** | First iMessage send | Sending texts via AppleScript |
| **Automation → Contacts** | First iMessage send | Looking up phone numbers |
| **Automation → Music** | Click "Open Apple Music" in notch | Launching Music |
| **Automation → FaceTime** | First "end FaceTime call" request | Quitting FaceTime to hang up (placing a call needs no permission) |
| **Calendar** | First calendar request | Reading/writing events |

If a permission ever gets stuck (rare), reset it and re-trigger:

```bash
tccutil reset ScreenCapture com.localapp.Anini   # screenshot
tccutil reset AppleEvents com.localapp.Anini     # Messages/Contacts/Music/etc.
```

---

## Customizing

- **Capabilities**: Settings → Capabilities — toggle individual features on/off.
- **Appearance**: Settings → Appearance — accent color, icon emoji, background opacity.
- **Notch widget**: Settings → Notch — pick a language to practice, toggle now-playing.
- **Workspace**: Settings → Workspace — set the directory the AI uses as its working dir.

![Anini settings — Appearance](docs/screenshots/settings-appearance.png)

![Anini settings — Notch](docs/screenshots/settings-notch.png)

![Anini settings — Capabilities](docs/screenshots/settings-capabilities.png)

---

## Updating

```bash
cd ~/Projects/Anini
git pull
xcodegen generate     # regenerate project if project.yml changed
```

Then `Cmd+B` in Xcode and relaunch.

---

## Troubleshooting

**App crashes immediately at launch**
Xcode probably re-enabled the debug dylib. In Xcode → Build Settings → search "Enable Debug Dylib" → set to **No** for the Anini target. Then `Cmd+B` again.

**A permission dialog never appears, but a feature is silently failing**
Run the relevant `tccutil reset` (see [Permissions](#permissions)) and try again.

**`xcodegen: command not found`**
`brew install xcodegen`

**`claude: command not found` (or `codex`)**
The Node-installed CLI isn't in PATH. Try `which node` to confirm Node is installed, then re-run `npm install -g @anthropic-ai/claude-code`.

---

## Project layout

```
Anini/
├── Sources/Anini/         # All Swift source
│   ├── App lifecycle      AniniApp.swift, AppDelegate.swift, HotkeyManager.swift
│   ├── Windows            FloatingPanel.swift, NotchWindow.swift
│   ├── UI views           ContentView.swift, SettingsView.swift, OnboardingView.swift,
│   │                      MessageBubble.swift, NotchWidgetView.swift
│   ├── Chat brain         ChatViewModel.swift, BackendManager.swift, BackendProtocol.swift
│   ├── Backends           ClaudeCodeBackend.swift, CodexBackend.swift
│   ├── Services           NowPlayingService.swift, GoogleCalendarManager.swift,
│   │                      French/Italian language services
│   ├── Config/security    WorkspaceConfig.swift, KeychainHelper.swift, SecurityLayer.swift
│   └── Resources/         Info.plist, entitlements, fonts
├── scripts/
│   └── setup-signing.sh   One-time code-signing cert creator
├── project.yml            xcodegen spec — edit this, then re-run `xcodegen generate`
└── README.md              This file
```

---

## License

Private project — for personal use.
