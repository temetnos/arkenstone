import Foundation
import Carbon
import AppKit

/// Native macOS Global HotKey Engine using Carbon HIToolbox
/// Enables system-wide keyboard shortcuts without requiring Accessibility (TCC) permissions.
public class GlobalHotKeyEngine {
    public static let shared = GlobalHotKeyEngine()
    
    private var handlers: [UInt32: () -> Void] = [:]
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var nextID: UInt32 = 1
    private var isHandlerInstalled = false
    
    public init() {
        setupCarbonEventHandler()
    }
    
    private func setupCarbonEventHandler() {
        guard !isHandlerInstalled else { return }
        
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        
        InstallEventHandler(
            GetApplicationEventTarget(),
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
        let err = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        if err == noErr, let ref = hotKeyRef {
            hotKeyRefs.append(ref)
        }
    }
    
    public func registerDefaults() {
        let opt = UInt32(optionKey)
        
        // ⌥O -> Screen OCR Text Grabber
        register(keyCode: UInt32(kVK_ANSI_O), modifiers: opt) {
            StatusBarController.shared?.triggerOCRFromMenu()
        }
        
        // ⌥C -> Screen Eyedropper / Color Picker
        register(keyCode: UInt32(kVK_ANSI_C), modifiers: opt) {
            StatusBarController.shared?.triggerColorPickerFromMenu()
        }
        
        // ⌥M -> Global Microphone Killswitch
        register(keyCode: UInt32(kVK_ANSI_M), modifiers: opt) {
            AudioMuteEngine.shared.toggleMute()
        }
        
        // ⌥D -> Detachable Drop Shelf Toggle
        register(keyCode: UInt32(kVK_ANSI_D), modifiers: opt) {
            StatusBarController.shared?.toggleDetachedShelf()
        }
        
        // ⌥A -> Toggle Main Menu Bar Control Center
        register(keyCode: UInt32(kVK_ANSI_A), modifiers: opt) {
            StatusBarController.shared?.toggleMainPopover()
        }
        
        // ⌥K -> Keyboard & Screen Cleaning Lock
        register(keyCode: UInt32(kVK_ANSI_K), modifiers: opt) {
            KeyboardCleanEngine.shared.toggleLock()
        }
    }
}
