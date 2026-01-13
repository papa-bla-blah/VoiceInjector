import AppKit
import SwiftUI
import Combine

/// Controls the menu bar icon and dropdown menu
class StatusBarController: NSObject {
    
    // MARK: - Properties
    
    private var statusItem: NSStatusItem?
    private var speechManager: SpeechManager
    private var cancellables = Set<AnyCancellable>()
    
    private let enabledImage: NSImage
    private let disabledImage: NSImage
    
    // MARK: - Initialization
    
    init(speechManager: SpeechManager) {
        self.speechManager = speechManager
        
        // Create status bar images
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        enabledImage = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Listening")!
            .withSymbolConfiguration(config)!
        disabledImage = NSImage(systemSymbolName: "mic.slash", accessibilityDescription: "Not Listening")!
            .withSymbolConfiguration(config)!
        
        super.init()
        
        setupStatusItem()
        setupBindings()
    }
    
    // MARK: - Setup
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.image = disabledImage
            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        statusItem?.menu = createMenu()
    }
    
    private func setupBindings() {
        // Update icon and visualizer when speech manager state changes
        speechManager.$isEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isEnabled in
                self?.updateIcon(isEnabled: isEnabled)
                self?.updateVisualizer(isEnabled: isEnabled)
            }
            .store(in: &cancellables)
    }
    
    private func updateIcon(isEnabled: Bool) {
        statusItem?.button?.image = isEnabled ? enabledImage : disabledImage
    }
    
    private func updateVisualizer(isEnabled: Bool) {
        if isEnabled {
            AudioVisualizerWindow.shared.show(near: statusItem)
        } else {
            AudioVisualizerWindow.shared.hide()
            AudioLevelMonitor.shared.reset()
        }
    }
    
    // MARK: - Menu Creation
    
    private func createMenu() -> NSMenu {
        let menu = NSMenu()
        
        // Toggle item
        let toggleItem = NSMenuItem(
            title: speechManager.isEnabled ? "Stop Listening" : "Start Listening",
            action: #selector(toggleListening),
            keyEquivalent: ""
        )
        toggleItem.target = self
        menu.addItem(toggleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Permissions submenu
        let permissionsItem = NSMenuItem(title: "Permissions", action: nil, keyEquivalent: "")
        let permissionsMenu = NSMenu()
        
        let accessibilityItem = NSMenuItem(
            title: "Accessibility Settings...",
            action: #selector(openAccessibilitySettings),
            keyEquivalent: ""
        )
        accessibilityItem.target = self
        permissionsMenu.addItem(accessibilityItem)
        
        let microphoneItem = NSMenuItem(
            title: "Microphone Settings...",
            action: #selector(openMicrophoneSettings),
            keyEquivalent: ""
        )
        microphoneItem.target = self
        permissionsMenu.addItem(microphoneItem)
        
        let speechItem = NSMenuItem(
            title: "Speech Recognition Settings...",
            action: #selector(openSpeechSettings),
            keyEquivalent: ""
        )
        speechItem.target = self
        permissionsMenu.addItem(speechItem)
        
        permissionsItem.submenu = permissionsMenu
        menu.addItem(permissionsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit item
        let quitItem = NSMenuItem(
            title: "Quit VoiceInjector",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
        
        return menu
    }
    
    private func refreshMenu() {
        statusItem?.menu = createMenu()
    }
    
    // MARK: - Actions
    
    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!
        
        if event.type == .rightMouseUp {
            // Right-click: show menu
            statusItem?.menu = createMenu()
            statusItem?.button?.performClick(nil)
        } else {
            // Left-click: toggle listening
            toggleListening()
        }
    }
    
    @objc private func toggleListening() {
        speechManager.toggleListening()
        refreshMenu()
    }
    
    @objc private func openAccessibilitySettings() {
        PermissionsChecker.openAccessibilitySettings()
    }
    
    @objc private func openMicrophoneSettings() {
        PermissionsChecker.openMicrophoneSettings()
    }
    
    @objc private func openSpeechSettings() {
        PermissionsChecker.openSpeechRecognitionSettings()
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    
    // MARK: - Permissions Alert
    
    func showPermissionsAlert(accessibility: Bool, microphone: Bool, speechRecognition: Bool) {
        var missingPermissions: [String] = []
        
        if !accessibility {
            missingPermissions.append("Accessibility (required for text injection)")
        }
        if !microphone {
            missingPermissions.append("Microphone (required for voice capture)")
        }
        if !speechRecognition {
            missingPermissions.append("Speech Recognition (required for transcription)")
        }
        
        guard !missingPermissions.isEmpty else { return }
        
        let alert = NSAlert()
        alert.messageText = "Permissions Required"
        alert.informativeText = "VoiceInjector needs the following permissions to work:\n\n• " + missingPermissions.joined(separator: "\n• ") + "\n\nPlease grant these permissions in System Settings."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Later")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            // Open the first missing permission's settings
            if !accessibility {
                PermissionsChecker.openAccessibilitySettings()
            } else if !microphone {
                PermissionsChecker.openMicrophoneSettings()
            } else if !speechRecognition {
                PermissionsChecker.openSpeechRecognitionSettings()
            }
        }
    }
    
    func showError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
