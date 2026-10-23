import Foundation
import AppKit
import Combine

public class DesktopFocusEngine: ObservableObject {
    public static let shared = DesktopFocusEngine()
    
    @Published public var isDesktopHidden: Bool = false
    @Published public var statusMessage: String?
    
    private init() {
        checkCurrentState()
    }
    
    public func checkCurrentState() {
        // Fast, memory-only CFPreferences check: zero process spawning, zero runloop blocking
        if let val = CFPreferencesCopyAppValue("CreateDesktop" as CFString, "com.apple.finder" as CFString) {
            if CFEqual(val, kCFBooleanFalse) {
                self.isDesktopHidden = true
                return
            }
        }
        self.isDesktopHidden = false
    }
    
    public func toggleDesktopIcons() {
        let targetHidden = !isDesktopHidden
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // 1. Update in-memory and on-disk preferences
            CFPreferencesSetAppValue(
                "CreateDesktop" as CFString,
                targetHidden ? kCFBooleanFalse : kCFBooleanTrue,
                "com.apple.finder" as CFString
            )
            CFPreferencesAppSynchronize("com.apple.finder" as CFString)
            
            // 2. Also write via defaults to ensure compatibility
            let defaultsProcess = Process()
            defaultsProcess.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
            defaultsProcess.arguments = ["write", "com.apple.finder", "CreateDesktop", "-bool", targetHidden ? "false" : "true"]
            try? defaultsProcess.run()
            defaultsProcess.waitUntilExit()
            
            // 3. Restart Finder to apply icon visibility
            let killProcess = Process()
            killProcess.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            killProcess.arguments = ["Finder"]
            try? killProcess.run()
            killProcess.waitUntilExit()
            
            DispatchQueue.main.async {
                self.isDesktopHidden = targetHidden
                self.statusMessage = targetHidden 
                    ? L10n.tr("Desktop icons hidden (Focus Mode)", "Masaüstü simgeleri gizlendi (Odak Modu)")
                    : L10n.tr("Desktop icons visible", "Masaüstü simgeleri görünür yapıldı")
                SoundManager.shared.play(.action)
            }
        }
    }
}
