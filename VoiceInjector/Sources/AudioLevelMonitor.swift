import SwiftUI
import Combine

/// Monitors audio levels from the microphone
class AudioLevelMonitor: ObservableObject {
    static let shared = AudioLevelMonitor()
    
    @Published var levels: [Float] = Array(repeating: 0, count: 8)  // 8 frequency bands
    @Published var peakLevel: Float = 0
    
    private var decayTimer: Timer?
    private let decayRate: Float = 0.12  // Slightly slower decay for smoother animation
    
    private init() {
        // Start decay timer for smooth animation
        decayTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.decayLevels()
        }
    }
    
    /// Process audio buffer and extract levels
    func processBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        
        // Calculate RMS for overall level
        var sum: Float = 0
        for i in 0..<frameLength {
            let sample = channelData[i]
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(frameLength))
        
        // Convert to decibels and normalize (0-1 range)
        // More sensitive: -60dB to -10dB range (was -50 to 0)
        let db = 20 * log10(max(rms, 0.00001))
        let normalizedLevel = max(0, min(1, (db + 60) / 50))
        
        // Create pseudo-frequency bands by analyzing different parts of buffer
        var newLevels: [Float] = []
        let bandSize = frameLength / 8
        
        for band in 0..<8 {
            let start = band * bandSize
            let end = min(start + bandSize, frameLength)
            
            var bandSum: Float = 0
            for i in start..<end {
                let sample = channelData[i]
                bandSum += abs(sample)
            }
            let bandAvg = bandSum / Float(end - start)
            // Increased sensitivity: multiply by 25 instead of 8
            let bandLevel = max(0, min(1, bandAvg * 25))
            
            // Add some variation based on band position
            let variation = Float(band) * 0.08
            newLevels.append(min(1, bandLevel + normalizedLevel * (0.7 + variation)))
        }
        
        DispatchQueue.main.async {
            // Update levels with some smoothing
            for i in 0..<8 {
                self.levels[i] = max(self.levels[i], newLevels[i])
            }
            self.peakLevel = normalizedLevel
        }
    }
    
    private func decayLevels() {
        for i in 0..<levels.count {
            levels[i] = max(0, levels[i] - decayRate)
        }
        peakLevel = max(0, peakLevel - decayRate)
    }
    
    func reset() {
        levels = Array(repeating: 0, count: 8)
        peakLevel = 0
    }
}

import AVFoundation
