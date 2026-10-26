import Foundation
import AppKit
import SwiftUI
import Carbon

final class CleanLockWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.keyCode == 53 { // ESC key
            return false // Allow Esc to reach event monitor
        }
        return true // Swallow all function keys (F1-F12), media keys, and system shortcuts
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            super.keyDown(with: event)
        }
    }
    
    override func keyUp(with event: NSEvent) {
        if event.keyCode == 53 {
            super.keyUp(with: event)
        }
    }
}

public class KeyboardCleanEngine: ObservableObject {
    public static let shared = KeyboardCleanEngine()
    
    @Published public var isLocked: Bool = false
    @Published public var holdProgress: Double = 0.0
    
    private var window: CleanLockWindow?
    private var eventMonitor: Any?
    private var holdTimer: Timer?
    private var holdStartTime: Date?
    
    public init() {}
    
    public func toggleLock() {
        if isLocked {
            unlock()
        } else {
            lock()
        }
    }
    
    public func lock() {
        guard !isLocked else { return }
        
        // Reset any lingering timer state from previous runs
        cancelEscHold()
        isLocked = true
        holdProgress = 0.0
        
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            isLocked = false
            return
        }
        
        let win = CleanLockWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.setFrame(screen.frame, display: true)
        win.level = .screenSaver
        win.isOpaque = false
        win.backgroundColor = NSColor.black.withAlphaComponent(0.88)
        win.ignoresMouseEvents = false
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        win.hidesOnDeactivate = false
        
        let hostingView = NSHostingView(rootView: KeyboardCleanOverlayView(engine: self))
        hostingView.frame = screen.frame
        hostingView.autoresizingMask = [.width, .height]
        win.contentView = hostingView
        
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = win
        
        // Monitor key events to block input and detect Esc hold
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged, .systemDefined]) { [weak self] event in
            guard let self = self, self.isLocked else { return event }
            
            if event.type == .keyDown {
                if event.keyCode == 53 { // ESC key
                    if self.holdStartTime == nil {
                        self.startEscHold()
                    }
                } else {
                    self.cancelEscHold()
                }
                return nil
            } else if event.type == .keyUp {
                if event.keyCode == 53 {
                    self.cancelEscHold()
                }
                return nil
            } else if event.type == .systemDefined {
                // Swallow media keys / volume / brightness keys
                return nil
            }
            return nil
        }
        
        SoundManager.shared.play(.pop)
    }
    
    public func unlock() {
        guard isLocked else { return }
        isLocked = false
        cancelEscHold()
        
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        
        if let win = window {
            win.orderOut(nil)
            self.window = nil
        }
        
        SoundManager.shared.play(.success)
    }
    
    private func startEscHold() {
        cancelEscHold()
        holdStartTime = Date()
        
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] t in
            guard let self = self, self.isLocked, let start = self.holdStartTime else {
                t.invalidate()
                return
            }
            let elapsed = Date().timeIntervalSince(start)
            let progress = min(1.0, elapsed / 2.2) // 2.2s hold
            self.holdProgress = progress
            if progress >= 1.0 {
                t.invalidate()
                self.unlock()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.holdTimer = timer
    }
    
    private func cancelEscHold() {
        holdStartTime = nil
        holdTimer?.invalidate()
        holdTimer = nil
        holdProgress = 0.0
    }
    
    public func onButtonHoldProgress(progress: Double) {
        self.holdProgress = progress
        if progress >= 1.0 {
            unlock()
        }
    }
}

public struct KeyboardCleanOverlayView: View {
    @ObservedObject var engine: KeyboardCleanEngine
    @State private var isHoldingButton = false
    @State private var buttonHoldStart: Date?
    @State private var buttonTimer: Timer?
    
    public var body: some View {
        ZStack {
            Color.black.opacity(0.88)
                .ignoresSafeArea()
            
            VStack(spacing: 28) {
                // Icon
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.cyan.opacity(0.25), Color.blue.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 96, height: 96)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.cyan.opacity(0.4), lineWidth: 1.5)
                        )
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 44, weight: .medium))
                        .foregroundColor(.cyan)
                }
                
                VStack(spacing: 8) {
                    Text(L10n.tr("Keyboard & Screen Cleaning Lock", "Klavye ve Ekran Temizlik Kilidi"))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(L10n.tr("Wipe your screen, keyboard, and trackpad safely. Typing keys and shortcuts are blocked.",
                                 "Ekranınızı, klavyenizi ve dokunmatik yüzeyi güvenle silin. Yazı tuşları ve kısayollar kilitlendi."))
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 480)
                    
                    HStack(spacing: 5) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color.orange.opacity(0.9))
                        Text(L10n.tr("Note: Hardware F-keys (brightness, volume, Mission Control) remain active under macOS firmware control.",
                                     "Not: Donanımsal F tuşları (parlaklık, ses, Mission Control) macOS sistem kontrolünde aktiftir."))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.orange.opacity(0.9))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(Capsule())
                }
                
                // Unlock Progress & Instructions
                VStack(spacing: 16) {
                    // Circular Progress Bar
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.12), lineWidth: 6)
                            .frame(width: 72, height: 72)
                        
                        Circle()
                            .trim(from: 0, to: engine.holdProgress)
                            .stroke(
                                LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom),
                                style: StrokeStyle(lineWidth: 6, lineCap: .round)
                            )
                            .frame(width: 72, height: 72)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 0.05), value: engine.holdProgress)
                        
                        Text(String(format: "%d%%", Int(engine.holdProgress * 100)))
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    
                    Text(L10n.tr("Hold ESC or click & hold the button below to unlock (or press ⌥K)",
                                 "Kilidi açmak için ESC tuşunu veya butonu basılı tutun (veya ⌥K basın)"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    
                    // Interactive Click & Hold Button
                    Button(action: {}) {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.open.fill")
                            Text(L10n.tr("Hold to Unlock", "Basılı Tutup Aç"))
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.15))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                if !isHoldingButton {
                                    startHoldingButton()
                                }
                            }
                            .onEnded { _ in
                                stopHoldingButton()
                            }
                    )
                }
                .padding(.top, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func startHoldingButton() {
        isHoldingButton = true
        buttonHoldStart = Date()
        buttonTimer?.invalidate()
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak engine] t in
            guard let start = self.buttonHoldStart, let eng = engine, eng.isLocked else {
                t.invalidate()
                return
            }
            let elapsed = Date().timeIntervalSince(start)
            let progress = min(1.0, elapsed / 2.0)
            eng.onButtonHoldProgress(progress: progress)
        }
        RunLoop.main.add(timer, forMode: .common)
        self.buttonTimer = timer
    }
    
    private func stopHoldingButton() {
        isHoldingButton = false
        buttonHoldStart = nil
        buttonTimer?.invalidate()
        buttonTimer = nil
        if engine.isLocked {
            engine.holdProgress = 0.0
        }
    }
}
