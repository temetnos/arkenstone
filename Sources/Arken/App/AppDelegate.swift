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
        
        // Register Global System Hotkeys (⌥O, ⌥C, ⌥M, ⌥D, ⌥A, ⌥K)
        GlobalHotKeyEngine.shared.registerDefaults()
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
    }
}
