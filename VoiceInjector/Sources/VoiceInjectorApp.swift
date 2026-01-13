import SwiftUI
import AppKit
import Carbon.HIToolbox

@main
struct VoiceInjectorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // No visible window - menu bar only app
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var speechManager: SpeechManager?
    private var globalKeyMonitor: Any?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize managers
        speechManager = SpeechManager()
        statusBarController = StatusBarController(speechManager: speechManager!)
        
        // Setup global keyboard shortcut (Option+V)
        setupGlobalShortcut()
        
        // Check permissions on launch
        Task {
            await checkInitialPermissions()
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Remove key monitor
        if let monitor = globalKeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    private func setupGlobalShortcut() {
        // Option+V to toggle voice input
        // Note: Requires Accessibility permission to work globally
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Check for Option+V (keyCode 9 = V)
            if event.modifierFlags.contains(.option) && event.keyCode == 9 {
                DispatchQueue.main.async {
                    self?.speechManager?.toggleListening()
                    print("[Shortcut] Option+V pressed - toggled listening")
                }
            }
        }
        
        // Also monitor local events (when app is focused)
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains(.option) && event.keyCode == 9 {
                DispatchQueue.main.async {
                    self?.speechManager?.toggleListening()
                    print("[Shortcut] Option+V pressed - toggled listening")
                }
                return nil  // Consume the event
            }
            return event
        }
        
        print("[Setup] Global shortcut registered: Option+V to toggle")
    }
    
    private func checkInitialPermissions() async {
        let hasAccessibility = PermissionsChecker.checkAccessibilityPermission()
        let hasMicrophone = await PermissionsChecker.checkMicrophonePermission()
        let hasSpeechRecognition = await PermissionsChecker.checkSpeechRecognitionPermission()
        
        if !hasAccessibility || !hasMicrophone || !hasSpeechRecognition {
            await MainActor.run {
                statusBarController?.showPermissionsAlert(
                    accessibility: hasAccessibility,
                    microphone: hasMicrophone,
                    speechRecognition: hasSpeechRecognition
                )
            }
        }
    }
}
