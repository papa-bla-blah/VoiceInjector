# VoiceInjector 🎤

**Speak anywhere, type everywhere.** A macOS menu bar app that converts your voice to text and types it wherever your cursor is.

## System Requirements

- **macOS 14.0 (Sonoma) or later** — will not work on older versions
- **Apple Silicon Mac** (M1/M2/M3/M4)
- Microphone (built-in or external)

## Key Features

- 🎯 **Universal Input** — Text appears wherever your cursor is, in any app
- 🔒 **100% Private** — On-device processing, your voice never leaves your Mac
- ⌨️ **Option+V Shortcut** — Toggle listening from anywhere with one keystroke
- 📊 **Visual Feedback** — Live audio meter shows when it's hearing you
- 🪶 **Lightweight** — Runs quietly in menu bar, no dock icon

## Dependencies

**Runtime:** None — uses only built-in macOS frameworks (Speech, AVFoundation, CoreGraphics)

**Build from source:**
- Xcode 15.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## How It Works

1. VoiceInjector lives in your **menu bar** (top-right of screen) as a microphone icon
2. Click into any text field — a chat, document, search bar, anywhere
3. Press **Option+V** to start listening (or click the menu bar icon)
4. Speak naturally
5. After a brief pause, your words appear at the cursor
6. Press **Option+V** again to stop

> **Key concept:** Where your cursor is, that's where your voice goes.

## Works With

Any app where you can type: Claude, ChatGPT, Slack, Messages, Notes, VS Code, browsers, email, documents, Terminal, search bars — everything.

## Permissions Needed

On first launch, grant these three permissions:
- **Microphone** — to hear you
- **Speech Recognition** — to transcribe
- **Accessibility** — to type into other apps (enable manually in System Settings → Privacy & Security → Accessibility)

## Keyboard Shortcut

**Option+V** toggles listening on/off globally. 

Want a different shortcut? Edit `VoiceInjectorApp.swift` line 45 and rebuild.

## Installation

1. Download from [Releases](../../releases)
2. Drag to Applications
3. Launch and grant permissions

## Building from Source

```bash
brew install xcodegen
git clone https://github.com/YOURUSERNAME/VoiceInjector.git
cd VoiceInjector
xcodegen generate
xcodebuild -scheme VoiceInjector -configuration Release build
```

---

MIT License • Built by Liam O'Connor with Claude
