import Foundation
import Carbon
import AppKit

/// Native macOS Global HotKey Engine using Carbon HIToolbox
/// Enables system-wide keyboard shortcuts without requiring Accessibility (TCC) permissions.
public class GlobalHotKeyEngine: ObservableObject {
    public static let shared = GlobalHotKeyEngine()
    
    @Published public var isEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "ArkenGlobalHotKeysEnabled")
            if isEnabled {
                registerDefaults()
            } else {
                unregisterAll()
            }
        }
    }
    
    private var handlers: [UInt32: () -> Void] = [:]
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var nextID: UInt32 = 1
    private var isHandlerInstalled = false
    
    public init() {
        if let saved = UserDefaults.standard.object(forKey: "ArkenGlobalHotKeysEnabled") as? Bool {
            self.isEnabled = saved
        }
        setupCarbonEventHandler()
    }
    
    private func setupCarbonEventHandler() {
        guard !isHandlerInstalled else { return }
        
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        
        InstallEventHandler(
            GetEventDispatcherTarget(),
            { (_, theEvent, _) -> OSStatus in
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    theEvent,
                    EventParamName(kEventParamDirectObject),
                    EventParamName(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                
                if status == noErr {
                    let id = hotKeyID.id
                    DispatchQueue.main.async {
                        GlobalHotKeyEngine.shared.handlers[id]?()
                    }
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            nil
        )
        
        isHandlerInstalled = true
    }
    
    public func register(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        let id = nextID
        nextID += 1
        handlers[id] = action
        
        let hotKeyID = EventHotKeyID(signature: OSType(0x41524B4E), id: id) // 'ARKN'
        var hotKeyRef: EventHotKeyRef?
        let err = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetEventDispatcherTarget(), 0, &hotKeyRef)
        if err == noErr, let ref = hotKeyRef {
            hotKeyRefs.append(ref)
        }
    }
    
    public func unregisterAll() {
        for ref in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
        handlers.removeAll()
    }
    
    public func registerDefaults() {
        guard isEnabled else { return }
        unregisterAll()
        
        let opt = UInt32(optionKey)
        let ctrlOpt = UInt32(controlKey | optionKey)
        
        // ⌥Space & ⌥A -> Toggle Main Menu Bar Control Center
        register(keyCode: UInt32(kVK_Space), modifiers: opt) {
            StatusBarController.shared?.toggleMainPopover()
        }
        register(keyCode: UInt32(kVK_ANSI_A), modifiers: opt) {
            StatusBarController.shared?.toggleMainPopover()
        }
        
        // ⌃⌥C -> Caffeine / Keep Awake Toggle
        register(keyCode: UInt32(kVK_ANSI_C), modifiers: ctrlOpt) {
            KeepAwakeEngine.shared.toggle()
        }
        
        // ⌃⌥P -> Screen Eyedropper / Color Picker (Pipette)
        register(keyCode: UInt32(kVK_ANSI_P), modifiers: ctrlOpt) {
            StatusBarController.shared?.triggerColorPickerFromMenu()
        }
        
        // ⌃⌥O -> Screen OCR Text Grabber
        register(keyCode: UInt32(kVK_ANSI_O), modifiers: ctrlOpt) {
            StatusBarController.shared?.triggerOCRFromMenu()
        }
        
        // ⌃⌥M -> Global Microphone Killswitch
        register(keyCode: UInt32(kVK_ANSI_M), modifiers: ctrlOpt) {
            AudioMuteEngine.shared.toggleMute()
        }
        
        // ⌃⌥D -> Detachable Drop Shelf Toggle
        register(keyCode: UInt32(kVK_ANSI_D), modifiers: ctrlOpt) {
            StatusBarController.shared?.toggleDetachedShelf()
        }
        
        // ⌃⌥N -> Detachable Quick Notes Window
        register(keyCode: UInt32(kVK_ANSI_N), modifiers: ctrlOpt) {
            StatusBarController.shared?.toggleDetachedNotes()
        }
        
        // ⌃⌥H -> Toggle Desktop Icons (Focus Mode)
        register(keyCode: UInt32(kVK_ANSI_H), modifiers: ctrlOpt) {
            DesktopFocusEngine.shared.toggleDesktopIcons()
        }
        
        // ⌃⌥V -> Quick Clipboard History Menu
        register(keyCode: UInt32(kVK_ANSI_V), modifiers: ctrlOpt) {
            StatusBarController.shared?.openClipboardFromMenu()
        }
        
        // ⌃⌥K -> Keyboard & Screen Cleaning Lock
        register(keyCode: UInt32(kVK_ANSI_K), modifiers: ctrlOpt) {
            KeyboardCleanEngine.shared.toggleLock()
        }
    }
}
