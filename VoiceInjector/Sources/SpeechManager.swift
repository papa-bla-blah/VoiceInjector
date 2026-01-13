import Foundation
import AVFoundation
import Speech
import Combine

// Simple debug print helper
func debugLog(_ message: String) {
    let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
    print("[\(timestamp)] SpeechManager: \(message)")
    fflush(stdout)
}

/// Manages continuous speech recognition using AVAudioEngine and SFSpeechRecognizer
class SpeechManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var isListening: Bool = false
    @Published private(set) var currentTranscription: String = ""
    @Published var isEnabled: Bool = false {
        didSet {
            if isEnabled {
                startListening()
            } else {
                stopListening()
            }
        }
    }
    
    // MARK: - Properties
    
    private let audioEngine = AVAudioEngine()
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    private let silenceThreshold: TimeInterval = 1.8
    private var silenceTimer: Timer?
    private var isRestarting: Bool = false
    private var consecutiveErrors: Int = 0
    private let maxConsecutiveErrors = 3
    
    // MARK: - Initialization
    
    init(locale: Locale = .current) {
        speechRecognizer = SFSpeechRecognizer(locale: locale)
        speechRecognizer?.defaultTaskHint = .dictation
        debugLog("SpeechManager initialized with locale: \(locale.identifier)")
    }
    
    // MARK: - Public Methods
    
    func startListening() {
        guard !isListening else { 
            debugLog("Already listening, ignoring startListening()")
            return 
        }
        
        debugLog("startListening() called")
        consecutiveErrors = 0
        
        Task {
            do {
                try await doStartRecognition()
            } catch {
                debugLog("Failed to start: \(error.localizedDescription)")
                await MainActor.run {
                    self.isListening = false
                }
            }
        }
    }
    
    func stopListening() {
        debugLog("stopListening() called")
        
        silenceTimer?.invalidate()
        silenceTimer = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        isListening = false
        isRestarting = false
        consecutiveErrors = 0
    }
    
    func toggleListening() {
        isEnabled.toggle()
    }
    
    // MARK: - Private Methods
    
    @MainActor
    private func doStartRecognition() async throws {
        // Check permissions
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        if speechStatus != .authorized {
            throw SpeechError.notAuthorized
        }
        
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        if micStatus != .authorized {
            throw SpeechError.microphoneNotAuthorized
        }
        
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            debugLog("Speech recognizer not available")
            throw SpeechError.recognizerUnavailable
        }
        
        // Clean up any existing
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechError.requestCreationFailed
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = true
        // Add task hint for better continuous recognition
        recognitionRequest.taskHint = .dictation
        
        debugLog("Recognition request created")
        
        // Setup audio
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        debugLog("Audio format: \(recordingFormat.sampleRate)Hz, \(recordingFormat.channelCount) ch")
        
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [weak self] buffer, time in
            self?.recognitionRequest?.append(buffer)
            // Feed audio to visualizer
            AudioLevelMonitor.shared.processBuffer(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        debugLog("Audio engine started")
        
        isListening = true
        isRestarting = false
        currentTranscription = ""
        
        // Start recognition
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            self?.handleRecognitionResult(result: result, error: error)
        }
        debugLog("Recognition task started - listening for speech...")
    }
    
    private func handleRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?) {
        
        if let result = result {
            consecutiveErrors = 0  // Reset error count on successful result
            let text = result.bestTranscription.formattedString
            let isFinal = result.isFinal
            
            if !text.isEmpty {
                debugLog("Transcription: '\(text)' (final: \(isFinal))")
            }
            
            Task { @MainActor in
                self.processTranscription(text, isFinal: isFinal)
            }
            
            // Only restart on final non-empty results
            if isFinal && !text.isEmpty {
                scheduleRestart(delay: 500_000_000)  // 500ms after final result
            }
            return
        }
        
        if let error = error {
            let nsError = error as NSError
            
            // Error 1110 = No speech detected - this is NORMAL during silence
            // Don't restart, just keep listening
            if nsError.code == 1110 {
                debugLog("No speech detected - waiting for speech...")
                consecutiveErrors += 1
                
                // Only restart after several consecutive "no speech" errors
                // This gives the recognizer time to actually hear speech
                if consecutiveErrors >= maxConsecutiveErrors && isEnabled && !isRestarting {
                    debugLog("Too many no-speech errors, restarting with delay...")
                    scheduleRestart(delay: 1_000_000_000)  // 1 second delay
                }
                return
            }
            
            // Error 301 = cancelled - this happens during restart, ignore
            if nsError.code == 301 {
                debugLog("Recognition cancelled (expected during restart)")
                return
            }
            
            // Other errors - log and restart
            debugLog("Recognition error: \(nsError.code) - \(error.localizedDescription)")
            if isEnabled && !isRestarting {
                scheduleRestart(delay: 500_000_000)
            }
        }
    }
    
    private func scheduleRestart(delay: UInt64) {
        guard !isRestarting else { return }
        isRestarting = true
        debugLog("Scheduling restart in \(delay/1_000_000)ms...")
        
        Task {
            try? await Task.sleep(nanoseconds: delay)
            
            await MainActor.run {
                guard self.isEnabled else { 
                    self.isRestarting = false
                    return 
                }
                
                debugLog("Performing restart")
                self.silenceTimer?.invalidate()
                self.recognitionTask?.cancel()
                self.recognitionTask = nil
                self.recognitionRequest?.endAudio()
                self.recognitionRequest = nil
                
                if self.audioEngine.isRunning {
                    self.audioEngine.stop()
                    self.audioEngine.inputNode.removeTap(onBus: 0)
                }
                
                self.consecutiveErrors = 0
                
                // Restart
                Task {
                    do {
                        try await self.doStartRecognition()
                    } catch {
                        debugLog("Restart failed: \(error.localizedDescription)")
                        self.isRestarting = false
                    }
                }
            }
        }
    }
    
    private func processTranscription(_ text: String, isFinal: Bool) {
        silenceTimer?.invalidate()
        currentTranscription = text
        
        if isFinal && !text.isEmpty {
            injectText(text)
        } else if !text.isEmpty {
            // Start silence timer for partial results
            silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceThreshold, repeats: false) { [weak self] _ in
                guard let self = self, !self.currentTranscription.isEmpty else { return }
                Task { @MainActor in
                    debugLog("Silence timeout - injecting partial result")
                    self.injectText(self.currentTranscription)
                    if self.isEnabled && !self.isRestarting {
                        self.scheduleRestart(delay: 300_000_000)
                    }
                }
            }
        }
    }
    
    private func injectText(_ text: String) {
        guard !text.isEmpty else { return }
        let textWithSpace = text + " "
        debugLog(">>> INJECTING: '\(text)'")
        InputBridge.shared.injectText(textWithSpace)
        currentTranscription = ""
    }
}

// MARK: - Speech Errors

enum SpeechError: LocalizedError {
    case notAuthorized
    case microphoneNotAuthorized
    case recognizerUnavailable
    case requestCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized: return "Speech recognition not authorized"
        case .microphoneNotAuthorized: return "Microphone not authorized"
        case .recognizerUnavailable: return "Speech recognizer unavailable"
        case .requestCreationFailed: return "Failed to create request"
        }
    }
}
