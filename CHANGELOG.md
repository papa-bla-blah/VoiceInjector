# Changelog

All notable changes to VoiceInjector will be documented in this file.

## [1.0.0] - 2025-01-13

### Added
- Initial release
- Menu bar icon with toggle functionality
- Continuous speech-to-text using Apple's on-device recognition
- Text injection at cursor position via CGEvent
- Global keyboard shortcut: **Option+V** to toggle
- Live audio visualizer (8-bar equalizer)
- Permission handling for Microphone, Speech Recognition, and Accessibility
- Auto-restart after each utterance for continuous listening

### Technical
- Built with SwiftUI and AppKit
- Uses AVAudioEngine for audio capture
- Uses SFSpeechRecognizer with on-device processing
- Uses CGEvent for cross-application keystroke injection
- XcodeGen for project generation
