import Foundation
import CoreGraphics
import Carbon.HIToolbox

/// Handles injecting text at the cursor position using CGEvent keystroke simulation
class InputBridge {
    
    // MARK: - Singleton
    static let shared = InputBridge()
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Inject text at the current cursor position by simulating keystrokes
    /// - Parameter text: The text to inject
    /// - Returns: True if injection was successful
    @discardableResult
    func injectText(_ text: String) -> Bool {
        guard PermissionsChecker.checkAccessibilityPermission() else {
            print("InputBridge: Accessibility permission not granted")
            return false
        }
        
        // Process each character
        for char in text {
            if !typeCharacter(char) {
                print("InputBridge: Failed to type character: \(char)")
                return false
            }
            // Small delay between characters for reliability
            usleep(1000) // 1ms delay
        }
        
        return true
    }
    
    /// Inject text using the pasteboard (faster for longer text)
    /// - Parameter text: The text to inject
    /// - Returns: True if injection was successful
    @discardableResult
    func injectTextViaPaste(_ text: String) -> Bool {
        guard PermissionsChecker.checkAccessibilityPermission() else {
            print("InputBridge: Accessibility permission not granted")
            return false
        }
        
        // Save current pasteboard content
        let pasteboard = NSPasteboard.general
        let previousContent = pasteboard.string(forType: .string)
        
        // Set new content
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // Simulate Cmd+V
        let success = simulateKeyCombo(keyCode: UInt16(kVK_ANSI_V), flags: .maskCommand)
        
        // Restore previous pasteboard content after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let previous = previousContent {
                pasteboard.clearContents()
                pasteboard.setString(previous, forType: .string)
            }
        }
        
        return success
    }
    
    // MARK: - Private Methods
    
    private func typeCharacter(_ char: Character) -> Bool {
        // Get key code and modifiers for this character
        guard let (keyCode, modifiers) = keyCodeForCharacter(char) else {
            // For special characters, use Unicode input
            return typeUnicodeCharacter(char)
        }
        
        return simulateKeyPress(keyCode: keyCode, modifiers: modifiers)
    }
    
    private func typeUnicodeCharacter(_ char: Character) -> Bool {
        // Use Option+key method or direct Unicode input
        // This handles special characters that don't have direct key codes
        let string = String(char)
        
        // Create CGEventSource
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            return false
        }
        
        // Create a key down event and set the unicode string
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) else {
            return false
        }
        
        var chars = Array(string.utf16)
        keyDown.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars)
        keyDown.post(tap: .cghidEventTap)
        
        // Key up
        guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
            return false
        }
        keyUp.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars)
        keyUp.post(tap: .cghidEventTap)
        
        return true
    }
    
    private func simulateKeyPress(keyCode: UInt16, modifiers: CGEventFlags = []) -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            return false
        }
        
        // Key down
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true) else {
            return false
        }
        keyDown.flags = modifiers
        keyDown.post(tap: .cghidEventTap)
        
        // Key up
        guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            return false
        }
        keyUp.flags = modifiers
        keyUp.post(tap: .cghidEventTap)
        
        return true
    }
    
    private func simulateKeyCombo(keyCode: UInt16, flags: CGEventFlags) -> Bool {
        return simulateKeyPress(keyCode: keyCode, modifiers: flags)
    }

    
    // MARK: - Key Code Mapping
    
    /// Returns the virtual key code and required modifiers for a character
    private func keyCodeForCharacter(_ char: Character) -> (UInt16, CGEventFlags)? {
        // Common character to keycode mapping
        let keyMap: [Character: (UInt16, CGEventFlags)] = [
            // Letters (lowercase - no shift needed)
            "a": (UInt16(kVK_ANSI_A), []),
            "b": (UInt16(kVK_ANSI_B), []),
            "c": (UInt16(kVK_ANSI_C), []),
            "d": (UInt16(kVK_ANSI_D), []),
            "e": (UInt16(kVK_ANSI_E), []),
            "f": (UInt16(kVK_ANSI_F), []),
            "g": (UInt16(kVK_ANSI_G), []),
            "h": (UInt16(kVK_ANSI_H), []),
            "i": (UInt16(kVK_ANSI_I), []),
            "j": (UInt16(kVK_ANSI_J), []),
            "k": (UInt16(kVK_ANSI_K), []),
            "l": (UInt16(kVK_ANSI_L), []),
            "m": (UInt16(kVK_ANSI_M), []),
            "n": (UInt16(kVK_ANSI_N), []),
            "o": (UInt16(kVK_ANSI_O), []),
            "p": (UInt16(kVK_ANSI_P), []),
            "q": (UInt16(kVK_ANSI_Q), []),
            "r": (UInt16(kVK_ANSI_R), []),
            "s": (UInt16(kVK_ANSI_S), []),
            "t": (UInt16(kVK_ANSI_T), []),
            "u": (UInt16(kVK_ANSI_U), []),
            "v": (UInt16(kVK_ANSI_V), []),
            "w": (UInt16(kVK_ANSI_W), []),
            "x": (UInt16(kVK_ANSI_X), []),
            "y": (UInt16(kVK_ANSI_Y), []),
            "z": (UInt16(kVK_ANSI_Z), []),
            
            // Numbers
            "0": (UInt16(kVK_ANSI_0), []),
            "1": (UInt16(kVK_ANSI_1), []),
            "2": (UInt16(kVK_ANSI_2), []),
            "3": (UInt16(kVK_ANSI_3), []),
            "4": (UInt16(kVK_ANSI_4), []),
            "5": (UInt16(kVK_ANSI_5), []),
            "6": (UInt16(kVK_ANSI_6), []),
            "7": (UInt16(kVK_ANSI_7), []),
            "8": (UInt16(kVK_ANSI_8), []),
            "9": (UInt16(kVK_ANSI_9), []),
            
            // Common punctuation
            " ": (UInt16(kVK_Space), []),
            ".": (UInt16(kVK_ANSI_Period), []),
            ",": (UInt16(kVK_ANSI_Comma), []),
            "-": (UInt16(kVK_ANSI_Minus), []),
            "=": (UInt16(kVK_ANSI_Equal), []),
            "'": (UInt16(kVK_ANSI_Quote), []),
            ";": (UInt16(kVK_ANSI_Semicolon), []),
            "/": (UInt16(kVK_ANSI_Slash), []),
            "\\": (UInt16(kVK_ANSI_Backslash), []),
            "[": (UInt16(kVK_ANSI_LeftBracket), []),
            "]": (UInt16(kVK_ANSI_RightBracket), []),
            "`": (UInt16(kVK_ANSI_Grave), []),
            
            // Shift characters (uppercase letters)
            "A": (UInt16(kVK_ANSI_A), .maskShift),
            "B": (UInt16(kVK_ANSI_B), .maskShift),
            "C": (UInt16(kVK_ANSI_C), .maskShift),
            "D": (UInt16(kVK_ANSI_D), .maskShift),
            "E": (UInt16(kVK_ANSI_E), .maskShift),
            "F": (UInt16(kVK_ANSI_F), .maskShift),
            "G": (UInt16(kVK_ANSI_G), .maskShift),
            "H": (UInt16(kVK_ANSI_H), .maskShift),
            "I": (UInt16(kVK_ANSI_I), .maskShift),
            "J": (UInt16(kVK_ANSI_J), .maskShift),
            "K": (UInt16(kVK_ANSI_K), .maskShift),
            "L": (UInt16(kVK_ANSI_L), .maskShift),
            "M": (UInt16(kVK_ANSI_M), .maskShift),
            "N": (UInt16(kVK_ANSI_N), .maskShift),
            "O": (UInt16(kVK_ANSI_O), .maskShift),
            "P": (UInt16(kVK_ANSI_P), .maskShift),
            "Q": (UInt16(kVK_ANSI_Q), .maskShift),
            "R": (UInt16(kVK_ANSI_R), .maskShift),
            "S": (UInt16(kVK_ANSI_S), .maskShift),
            "T": (UInt16(kVK_ANSI_T), .maskShift),
            "U": (UInt16(kVK_ANSI_U), .maskShift),
            "V": (UInt16(kVK_ANSI_V), .maskShift),
            "W": (UInt16(kVK_ANSI_W), .maskShift),
            "X": (UInt16(kVK_ANSI_X), .maskShift),
            "Y": (UInt16(kVK_ANSI_Y), .maskShift),
            "Z": (UInt16(kVK_ANSI_Z), .maskShift),
            
            // Shift punctuation
            "!": (UInt16(kVK_ANSI_1), .maskShift),
            "@": (UInt16(kVK_ANSI_2), .maskShift),
            "#": (UInt16(kVK_ANSI_3), .maskShift),
            "$": (UInt16(kVK_ANSI_4), .maskShift),
            "%": (UInt16(kVK_ANSI_5), .maskShift),
            "^": (UInt16(kVK_ANSI_6), .maskShift),
            "&": (UInt16(kVK_ANSI_7), .maskShift),
            "*": (UInt16(kVK_ANSI_8), .maskShift),
            "(": (UInt16(kVK_ANSI_9), .maskShift),
            ")": (UInt16(kVK_ANSI_0), .maskShift),
            "_": (UInt16(kVK_ANSI_Minus), .maskShift),
            "+": (UInt16(kVK_ANSI_Equal), .maskShift),
            "\"": (UInt16(kVK_ANSI_Quote), .maskShift),
            ":": (UInt16(kVK_ANSI_Semicolon), .maskShift),
            "?": (UInt16(kVK_ANSI_Slash), .maskShift),
            "|": (UInt16(kVK_ANSI_Backslash), .maskShift),
            "{": (UInt16(kVK_ANSI_LeftBracket), .maskShift),
            "}": (UInt16(kVK_ANSI_RightBracket), .maskShift),
            "~": (UInt16(kVK_ANSI_Grave), .maskShift),
            "<": (UInt16(kVK_ANSI_Comma), .maskShift),
            ">": (UInt16(kVK_ANSI_Period), .maskShift),
            
            // Special keys
            "\n": (UInt16(kVK_Return), []),
            "\t": (UInt16(kVK_Tab), []),
        ]
        
        return keyMap[char]
    }
}

// MARK: - AppKit Extension for Pasteboard
import AppKit
