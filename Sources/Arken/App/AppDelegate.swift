import AppKit

public class AppDelegate: NSObject, NSApplicationDelegate {
    private var hardwareMonitor: HardwareMonitor?
    private var statusBarController: StatusBarController?
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Run purely in Menu Bar without Dock icon
        NSApplication.shared.setActivationPolicy(.accessory)
        
        // Setup minimal standard Edit menu so ⌘C, ⌘V, ⌘X, ⌘A, ⌘Z work across all text fields
        setupStandardEditMenu()
        
        // Initialize monitor and status bar controller
        let monitor = HardwareMonitor()
        self.hardwareMonitor = monitor
        self.statusBarController = StatusBarController(monitor: monitor)
        
        // Register Global System Hotkeys (⌥Space/⌥A, ⌃⌥C, ⌃⌥O, ⌃⌥P, ⌃⌥M, ⌃⌥D, ⌃⌥N, ⌃⌥H, ⌃⌥V, ⌃⌥K)
        GlobalHotKeyEngine.shared.registerDefaults()
        
        // If launched manually by user (not via background LaunchAgent), show popover immediately
        if !CommandLine.arguments.contains("--background") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.statusBarController?.showMainPopover()
            }
        }
    }
    
    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusBarController?.showMainPopover()
        return true
    }
    
    private func setupStandardEditMenu() {
        let mainMenu = NSMenu()
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redoItem = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redoItem)
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)
        NSApplication.shared.mainMenu = mainMenu
    }
    
    public func applicationWillTerminate(_ notification: Notification) {
        KeepAwakeEngine.shared.deactivate()
        PowerGuardEngine.shared.restoreChargingOnTermination()
        KeyboardCleanEngine.shared.unlock()
    }
}
