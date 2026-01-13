import SwiftUI
import AppKit

/// Floating window showing audio level visualization
class AudioVisualizerWindow: NSObject {
    private var window: NSWindow?
    private var hostingView: NSHostingView<AudioVisualizerView>?
    
    static let shared = AudioVisualizerWindow()
    
    private override init() {
        super.init()
    }
    
    func show(near statusItem: NSStatusItem?) {
        if window != nil { return }  // Already showing
        
        // Create the SwiftUI view
        let visualizerView = AudioVisualizerView()
        hostingView = NSHostingView(rootView: visualizerView)
        
        // Create borderless window
        let windowWidth: CGFloat = 160
        let windowHeight: CGFloat = 60
        
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        guard let window = window else { return }
        
        window.contentView = hostingView
        window.backgroundColor = NSColor.black.withAlphaComponent(0.85)
        window.isOpaque = false
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        
        // Position near menu bar
        if let button = statusItem?.button, let buttonWindow = button.window {
            let buttonFrame = button.convert(button.bounds, to: nil)
            let screenFrame = buttonWindow.convertToScreen(buttonFrame)
            
            let x = screenFrame.midX - windowWidth / 2
            let y = screenFrame.minY - windowHeight - 5
            
            window.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            // Fallback: top right of screen
            if let screen = NSScreen.main {
                let x = screen.frame.width - windowWidth - 100
                let y = screen.frame.height - windowHeight - 30
                window.setFrameOrigin(NSPoint(x: x, y: y))
            }
        }
        
        // Round corners
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.cornerRadius = 10
        window.contentView?.layer?.masksToBounds = true
        
        window.orderFront(nil)
    }
    
    func hide() {
        window?.orderOut(nil)
        window = nil
        hostingView = nil
    }
    
    var isVisible: Bool {
        return window != nil
    }
}

/// SwiftUI view for the equalizer visualization
struct AudioVisualizerView: View {
    @ObservedObject var audioMonitor = AudioLevelMonitor.shared
    
    let barColors: [Color] = [
        .green, .green, .yellow, .yellow, .orange, .orange, .red, .red
    ]
    
    var body: some View {
        VStack(spacing: 4) {
            // Title
            HStack {
                Image(systemName: "mic.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 10))
                Text("LISTENING")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)
            
            // Equalizer bars
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<8, id: \.self) { index in
                    EqualizerBar(
                        level: audioMonitor.levels[index],
                        color: barColors[index]
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .frame(width: 160, height: 60)
    }
}

/// Individual equalizer bar
struct EqualizerBar: View {
    let level: Float
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                Spacer()
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [color.opacity(0.6), color]),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(height: max(3, CGFloat(level) * geometry.size.height))
                    .animation(.easeOut(duration: 0.08), value: level)
            }
        }
    }
}

#Preview {
    AudioVisualizerView()
        .frame(width: 160, height: 60)
        .background(Color.black.opacity(0.85))
}
