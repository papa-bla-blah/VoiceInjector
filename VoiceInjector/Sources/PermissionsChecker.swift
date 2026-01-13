import Foundation
import AVFoundation
import Speech
import AppKit
import ApplicationServices

/// Handles checking and requesting system permissions
struct PermissionsChecker {
    
    // MARK: - Accessibility Permission
    
    /// Check if the app has Accessibility permission (required for CGEvent injection)
    static func checkAccessibilityPermission() -> Bool {
        let trusted = AXIsProcessTrusted()
        return trusted
    }
    
    /// Prompt user to enable Accessibility permission
    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    /// Open System Settings to Accessibility pane
    static func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
    
    // MARK: - Microphone Permission
    
    /// Check if the app has Microphone permission
    static func checkMicrophonePermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await requestMicrophonePermission()
        default:
            return false
        }
    }
    
    /// Request Microphone permission
    static func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    /// Open System Settings to Microphone pane
    static func openMicrophoneSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
        NSWorkspace.shared.open(url)
    }
    
    // MARK: - Speech Recognition Permission
    
    /// Check if the app has Speech Recognition permission
    static func checkSpeechRecognitionPermission() async -> Bool {
        let status = SFSpeechRecognizer.authorizationStatus()
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await requestSpeechRecognitionPermission()
        default:
            return false
        }
    }
    
    /// Request Speech Recognition permission
    static func requestSpeechRecognitionPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
    
    /// Open System Settings to Speech Recognition pane
    static func openSpeechRecognitionSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition")!
        NSWorkspace.shared.open(url)
    }
    
    // MARK: - All Permissions Check
    
    /// Check all required permissions at once
    static func checkAllPermissions() async -> (accessibility: Bool, microphone: Bool, speechRecognition: Bool) {
        let accessibility = checkAccessibilityPermission()
        let microphone = await checkMicrophonePermission()
        let speechRecognition = await checkSpeechRecognitionPermission()
        return (accessibility, microphone, speechRecognition)
    }
    
    /// Returns true only if all permissions are granted
    static func allPermissionsGranted() async -> Bool {
        let perms = await checkAllPermissions()
        return perms.accessibility && perms.microphone && perms.speechRecognition
    }
}
