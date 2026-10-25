import AppKit

public class AppDelegate: NSObject, NSApplicationDelegate {
    private var hardwareMonitor: HardwareMonitor?
    private var statusBarController: StatusBarController?
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Run purely in Menu Bar without Dock icon
        NSApplication.shared.setActivationPolicy(.accessory)
        
        // Initialize monitor and status bar controller
        let monitor = HardwareMonitor()
        self.hardwareMonitor = monitor
        self.statusBarController = StatusBarController(monitor: monitor)
        
        // Register Global System Hotkeys (⌥O, ⌥C, ⌥M, ⌥D, ⌥A)
        GlobalHotKeyEngine.shared.registerDefaults()
    }
    
    public func applicationWillTerminate(_ notification: Notification) {
        KeepAwakeEngine.shared.deactivate()
    }
}
