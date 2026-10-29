import AppKit
import SwiftUI

class StatusDragView: NSView {
    weak var controller: StatusBarController?
    
    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        controller?.showShelfPopover()
        return .copy
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pboard = sender.draggingPasteboard
        if let urls = pboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty {
            DropShelfEngine.shared.addURLs(urls)
            controller?.showShelfPopover()
            return true
        }
        return false
    }
    
    override func mouseDown(with event: NSEvent) {
        controller?.togglePopover(self)
    }
    
    override func rightMouseDown(with event: NSEvent) {
        controller?.showContextMenu()
    }
}

public class StatusBarController: NSObject, NSPopoverDelegate {
    public static weak var shared: StatusBarController?
    
    private var statusItem: NSStatusItem
    private var mainPopover: NSPopover
    private var shelfPopover: NSPopover
    public var floatingShelfPanel: NSPanel?
    public var floatingNotesPanel: NSPanel?
    private var monitor: HardwareMonitor
    private var dragView: StatusDragView?
    
    public init(monitor: HardwareMonitor) {
        self.monitor = monitor
        
        // Create Status Item in Menu Bar
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.mainPopover = NSPopover()
        self.shelfPopover = NSPopover()
        
        super.init()
        
        Self.shared = self
        
        setupMainPopover()
        setupShelfPopover()
        setupStatusButton()
        observeMonitor()
    }
    
    private func setupMainPopover() {
        mainPopover.contentSize = NSSize(width: 380, height: 460)
        mainPopover.behavior = .transient
        mainPopover.animates = true
        mainPopover.delegate = self
        mainPopover.contentViewController = NSHostingController(
            rootView: PopoverView(monitor: monitor)
        )
    }
    
    private func setupShelfPopover() {
        shelfPopover.contentSize = NSSize(width: 380, height: 200)
        shelfPopover.behavior = .transient
        shelfPopover.animates = true
        shelfPopover.delegate = self
        shelfPopover.contentViewController = NSHostingController(
            rootView: DedicatedShelfView(onClose: { [weak self] in
                self?.closeShelfPopover()
            })
        )
    }
    
    private func setupStatusButton() {
        guard let button = statusItem.button else { return }
        
        // Add Drag and Drop Overlay
        let dv = StatusDragView(frame: button.bounds)
        dv.autoresizingMask = [.width, .height]
        dv.controller = self
        button.addSubview(dv)
        self.dragView = dv
        
        updateButtonContent()
    }
    
    private func observeMonitor() {
        // Redundant 2s timer removed: HardwareMonitor directly triggers updateButtonContent()
        // on its background telemetry cycle, eliminating double-polling wakeups.
        updateButtonContent()
    }
    
    public func updateButtonContent() {
        guard let button = statusItem.button else { return }
        
        let mode = SettingsStore.shared.displayMode
        let isKeepAwake = KeepAwakeEngine.shared.isActive
        let shelfCount = DropShelfEngine.shared.items.count
        
        // Icon
        let iconName = isKeepAwake ? "cup.and.saucer.fill" : (shelfCount > 0 ? "hand.draw.fill" : "waveform.path.ecg")
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        let image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Arken")?.withSymbolConfiguration(config)
        
        button.image = image
        button.imagePosition = .imageLeading
        button.font = NSFont.monospacedDigitSystemFont(ofSize: 11.5, weight: .medium)
        
        let cpuStr = String(format: "%.0f%%", monitor.cpu.totalUsage)
        let ramStr = String(format: "%.0f%%", monitor.memory.usedPercentage)
        let tempStr = monitor.formatTemperature(monitor.thermal.cpuTemperature, decimals: 0)
        let isBypass = PowerGuardEngine.shared.isBypassActive
        let wattStr = isBypass ? "Bypass" : String(format: "%.1fW", monitor.battery.watts)
        let batPct = "\(monitor.battery.percentage)%"
        let dlSpeed = monitor.network.downloadSpeedFormatted
        let ulSpeed = monitor.network.uploadSpeedFormatted
        
        var statusSuffix = ""
        if AudioMuteEngine.shared.isMuted {
            statusSuffix += " 🔇"
        }
        if shelfCount > 0 {
            statusSuffix += " [📁\(shelfCount)]"
        } else if isBypass {
            statusSuffix += " [🛡️]"
        }
        
        switch mode {
        case .iconOnly:
            button.title = statusSuffix
        case .cpuOnly:
            button.title = " CPU \(cpuStr)\(statusSuffix)"
        case .ramOnly:
            button.title = " RAM \(ramStr)\(statusSuffix)"
        case .thermals:
            button.title = " \(tempStr)\(statusSuffix)"
        case .battery:
            let chargePrefix = monitor.battery.isCharging ? "⚡️" : ""
            button.title = " \(chargePrefix)\(batPct) | \(wattStr)\(statusSuffix)"
        case .watts:
            button.title = " \(wattStr)\(statusSuffix)"
        case .network:
            button.title = " ↓\(dlSpeed) ↑\(ulSpeed)\(statusSuffix)"
        case .cpuAndRam:
            button.title = " \(cpuStr) | \(ramStr)\(statusSuffix)"
        case .cpuAndTemp:
            button.title = " \(cpuStr) | \(tempStr)\(statusSuffix)"
        case .ramAndTemp:
            button.title = " \(ramStr) | \(tempStr)\(statusSuffix)"
        case .cpuRamTemp:
            button.title = " \(cpuStr) | \(ramStr) | \(tempStr)\(statusSuffix)"
        case .netAndCpu:
            button.title = " ↓\(dlSpeed) | \(cpuStr)\(statusSuffix)"
        }
        
        button.toolTip = L10n.tr(
            "Arken: CPU \(cpuStr) • RAM \(ramStr) • Temp \(tempStr) • Power \(wattStr) • Net ↓\(dlSpeed) ↑\(ulSpeed)",
            "Arken: CPU \(cpuStr) • RAM \(ramStr) • Sıcaklık \(tempStr) • Güç \(wattStr) • Ağ ↓\(dlSpeed) ↑\(ulSpeed)"
        )
        
        // Ensure drag overlay covers current button bounds
        dragView?.frame = button.bounds
    }
    
    @objc public func togglePopover(_ sender: AnyObject?) {
        if shelfPopover.isShown {
            closeShelfPopover()
            return
        }
        
        if mainPopover.isShown {
            closeMainPopover()
        } else {
            showMainPopover()
        }
    }
    
    public func showMainPopover() {
        guard let button = statusItem.button else { return }
        closeShelfPopover()
        monitor.isPopoverVisible = true
        monitor.updateAll()
        mainPopover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        
        // Activate app so popover gains immediate keyboard focus for shortcuts (⌘1..⌘9, ESC)
        NSApp.activate(ignoringOtherApps: true)
        if let window = mainPopover.contentViewController?.view.window {
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    public func toggleMainPopover() {
        if mainPopover.isShown {
            closeMainPopover()
        } else {
            showMainPopover()
        }
    }
    
    public func closeMainPopover() {
        mainPopover.performClose(nil)
        monitor.isPopoverVisible = false
    }
    
    public func showShelfPopover() {
        guard let button = statusItem.button else { return }
        closeMainPopover()
        if !shelfPopover.isShown {
            shelfPopover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            shelfPopover.contentViewController?.view.window?.makeKey()
            DropShelfEngine.shared.isShelfOpen = true
        }
    }
    
    public func closeShelfPopover() {
        shelfPopover.performClose(nil)
        DropShelfEngine.shared.isShelfOpen = false
    }
    
    public func openDetachedShelf() {
        closeShelfPopover()
        closeMainPopover()
        
        if let existing = floatingShelfPanel {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let panel = NSPanel(
            contentRect: NSRect(x: 100, y: 100, width: 390, height: 230),
            styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.title = "Arken File Shelf"
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.titlebarAppearsTransparent = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        if let screen = NSScreen.main {
            let x = screen.visibleFrame.maxX - 410
            let y = screen.visibleFrame.maxY - 270
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        panel.contentViewController = NSHostingController(
            rootView: DedicatedShelfView(isDetached: true, onClose: { [weak self] in
                self?.closeDetachedShelf()
            })
        )
        
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            self?.floatingShelfPanel = nil
        }
        
        self.floatingShelfPanel = panel
        panel.makeKeyAndOrderFront(nil)
        SoundManager.shared.play(.action)
    }
    
    public func closeDetachedShelf() {
        floatingShelfPanel?.orderOut(nil)
        floatingShelfPanel?.close()
        floatingShelfPanel = nil
    }
    
    public var isShelfDetached: Bool {
        return floatingShelfPanel?.isVisible == true
    }
    
    public func toggleDetachedShelf() {
        if isShelfDetached {
            closeDetachedShelf()
        } else {
            openDetachedShelf()
        }
    }
    
    public func openDetachedNotes() {
        closeMainPopover()
        
        if let existing = floatingNotesPanel {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let panel = NSPanel(
            contentRect: NSRect(x: 150, y: 150, width: 440, height: 340),
            styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.title = L10n.tr("Arken Notes", "Hızlı Notlar")
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.titlebarAppearsTransparent = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        if let screen = NSScreen.main {
            let x = screen.visibleFrame.maxX - 460
            let y = screen.visibleFrame.maxY - 380
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        panel.contentViewController = NSHostingController(
            rootView: DedicatedNotesView(onClose: { [weak self] in
                self?.closeDetachedNotes()
            })
        )
        
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            self?.floatingNotesPanel = nil
        }
        
        self.floatingNotesPanel = panel
        panel.makeKeyAndOrderFront(nil)
        SoundManager.shared.play(.action)
    }
    
    public func closeDetachedNotes() {
        floatingNotesPanel?.orderOut(nil)
        floatingNotesPanel?.close()
        floatingNotesPanel = nil
    }
    
    public var isNotesDetached: Bool {
        return floatingNotesPanel?.isVisible == true
    }
    
    public func toggleDetachedNotes() {
        if isNotesDetached {
            closeDetachedNotes()
        } else {
            openDetachedNotes()
        }
    }
    
    // MARK: - NSPopoverDelegate
    public func popoverDidClose(_ notification: Notification) {
        guard let popover = notification.object as? NSPopover else { return }
        if popover == mainPopover {
            monitor.isPopoverVisible = false
        } else if popover == shelfPopover {
            DropShelfEngine.shared.isShelfOpen = false
        }
    }
    
    public func showContextMenu() {
        let menu = NSMenu()
        let titleItem = NSMenuItem(title: "\(AppInfo.name) \(AppInfo.formattedVersion)", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())
        
        let shelfCount = DropShelfEngine.shared.items.count
        let shelfTitle = shelfCount > 0 ? L10n.tr("🏝️ Open File Shelf (\(shelfCount) Files)", "🏝️ Dosya Rafını Aç (\(shelfCount) Dosya)") : L10n.tr("🏝️ Open File Shelf", "🏝️ Dosya Rafını Aç")
        let shelfItem = NSMenuItem(title: shelfTitle, action: #selector(toggleShelfFromMenu), keyEquivalent: "d")
        shelfItem.keyEquivalentModifierMask = [.option]
        shelfItem.target = self
        menu.addItem(shelfItem)
        
        let notesTitle = isNotesDetached ? L10n.tr("📝 Close Floating Notes", "📝 Yüzen Notları Kapat") : L10n.tr("📝 Open Floating Notes Window", "📝 Yüzen Notlar Penceresini Aç")
        let notesItem = NSMenuItem(title: notesTitle, action: #selector(toggleNotesFromMenu), keyEquivalent: "n")
        notesItem.keyEquivalentModifierMask = [.option]
        notesItem.target = self
        menu.addItem(notesItem)
        
        let dragModeTitle = DropShelfEngine.shared.dragMode == .copy ? L10n.tr("📦 Shelf Action: 📋 Copy", "📦 Raf Eylemi: 📋 Kopyala") : L10n.tr("📦 Shelf Action: ✂️ Move", "📦 Raf Eylemi: ✂️ Taşı")
        let dragModeItem = NSMenuItem(title: dragModeTitle, action: #selector(toggleShelfDragMode), keyEquivalent: "")
        dragModeItem.target = self
        menu.addItem(dragModeItem)
        
        // Clipboard History Menu & Submenu
        let clipItems = ClipboardEngine.shared.items
        let clipCount = clipItems.count
        let clipTitle = clipCount > 0 ? L10n.tr("📋 Clipboard History (\(clipCount) Items)", "📋 Pano Geçmişi (\(clipCount) Öğe)") : L10n.tr("📋 Clipboard History", "📋 Pano Geçmişi")
        let clipMenuItem = NSMenuItem(title: clipTitle, action: #selector(openClipboardFromMenu), keyEquivalent: "v")
        clipMenuItem.keyEquivalentModifierMask = [.option]
        clipMenuItem.target = self
        
        let clipSubmenu = NSMenu()
        let openTabItem = NSMenuItem(title: L10n.tr("📋 Open Clipboard Tab", "📋 Pano Sekmesini Aç"), action: #selector(openClipboardFromMenu), keyEquivalent: "")
        openTabItem.target = self
        clipSubmenu.addItem(openTabItem)
        clipSubmenu.addItem(NSMenuItem.separator())
        
        if clipItems.isEmpty {
            let emptyItem = NSMenuItem(title: L10n.tr("Clipboard history is empty", "Pano geçmişi boş"), action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            clipSubmenu.addItem(emptyItem)
        } else {
            for (idx, item) in clipItems.prefix(8).enumerated() {
                let typeIcon: String
                switch item.type {
                case .text: typeIcon = "📄"
                case .image: typeIcon = "🖼️"
                case .code: typeIcon = "💻"
                case .url: typeIcon = "🔗"
                case .color: typeIcon = "🎨"
                case .all: typeIcon = "📝"
                }
                
                let pinPrefix = item.isPinned ? "📌 " : ""
                let truncated = item.preview.count > 30 ? String(item.preview.prefix(30)) + "..." : item.preview
                let itemTitle = "\(pinPrefix)\(typeIcon) \(truncated)"
                
                let subItem = NSMenuItem(title: itemTitle, action: #selector(pasteboardItemClicked(_:)), keyEquivalent: idx < 9 ? "\(idx + 1)" : "")
                subItem.target = self
                subItem.representedObject = item.id
                
                if item.type == .image, let data = item.imageData, let img = NSImage(data: data) {
                    let thumb = NSImage(size: NSSize(width: 16, height: 16))
                    thumb.lockFocus()
                    img.draw(in: NSRect(x: 0, y: 0, width: 16, height: 16), from: .zero, operation: .copy, fraction: 1.0)
                    thumb.unlockFocus()
                    subItem.image = thumb
                }
                
                clipSubmenu.addItem(subItem)
            }
            
            clipSubmenu.addItem(NSMenuItem.separator())
            let clearItem = NSMenuItem(title: L10n.tr("🗑️ Clear Unpinned", "🗑️ Sabitlenmemişleri Temizle"), action: #selector(clearClipboardFromMenu), keyEquivalent: "")
            clearItem.target = self
            clipSubmenu.addItem(clearItem)
        }
        
        clipMenuItem.submenu = clipSubmenu
        menu.addItem(clipMenuItem)
        
        let ocrItem = NSMenuItem(title: L10n.tr("🔍 Screen Text Capture (OCR)", "🔍 Ekrandan Metin Kopyala (OCR)"), action: #selector(triggerOCRFromMenu), keyEquivalent: "o")
        ocrItem.keyEquivalentModifierMask = [.option]
        ocrItem.target = self
        menu.addItem(ocrItem)
        
        let colorItem = NSMenuItem(title: L10n.tr("🎨 Color Eyedropper (Pipette)", "🎨 Ekrandan Renk Seç (Damlalık)"), action: #selector(triggerColorPickerFromMenu), keyEquivalent: "p")
        colorItem.keyEquivalentModifierMask = [.option]
        colorItem.target = self
        menu.addItem(colorItem)
        
        let cleanItem = NSMenuItem(title: L10n.tr("✨ Keyboard & Screen Clean Lock", "✨ Klavye ve Ekran Temizlik Kilidi"), action: #selector(toggleCleanLock), keyEquivalent: "k")
        cleanItem.keyEquivalentModifierMask = [.option]
        cleanItem.target = self
        menu.addItem(cleanItem)
        
        let isMuted = AudioMuteEngine.shared.isMuted
        let micTitle = isMuted ? L10n.tr("🎙️ Unmute Microphone", "🎙️ Mikrofonun Sesini Aç") : L10n.tr("🔇 Mute Microphone (Global Mute)", "🔇 Mikrofonu Sustur (Global Mute)")
        let micItem = NSMenuItem(title: micTitle, action: #selector(toggleMicFromMenu), keyEquivalent: "m")
        micItem.keyEquivalentModifierMask = [.option]
        micItem.target = self
        menu.addItem(micItem)
        
        let awakeStatus = KeepAwakeEngine.shared.isActive ? L10n.tr("Active (Disable)", "Açık (Kapat)") : L10n.tr("Inactive (Enable)", "Kapalı (Aç)")
        let awakeItem = NSMenuItem(title: L10n.tr("☕ Keep Awake: \(awakeStatus)", "☕ Caffeine (Uyanık Tut): \(awakeStatus)"), action: #selector(toggleKeepAwake), keyEquivalent: "c")
        awakeItem.keyEquivalentModifierMask = [.option]
        awakeItem.target = self
        menu.addItem(awakeItem)
        
        let clamshellEngine = KeepAwakeEngine.shared
        let clamshellStatus: String
        if clamshellEngine.isClamshellAuthRequired {
            clamshellStatus = L10n.tr("⚠️ Authorization Required (Click to Grant)", "⚠️ Yetki Gerekli (İzin Vermek İçin Tıkla)")
        } else if clamshellEngine.isClamshellEnabled {
            clamshellStatus = clamshellEngine.isClamshellActive
                ? L10n.tr("Active (AC Connected)", "Açık (Şarjda)")
                : L10n.tr("Standby (Connect AC)", "Beklemede (Şarj Tak)")
        } else {
            clamshellStatus = L10n.tr("Disabled (Enable)", "Kapalı (Aç)")
        }
        let clamshellItem = NSMenuItem(title: L10n.tr("💻 Clamshell (Lid-Closed): \(clamshellStatus)", "💻 Kapak Kapalı (Clamshell): \(clamshellStatus)"), action: #selector(toggleClamshellFromMenu), keyEquivalent: "")
        clamshellItem.target = self
        menu.addItem(clamshellItem)
        
        let isDesktopHidden = DesktopFocusEngine.shared.isDesktopHidden
        let desktopTitle = isDesktopHidden ? L10n.tr("🖥️ Show Desktop Icons", "🖥️ Masaüstü Simgelerini Göster") : L10n.tr("🖥️ Hide Desktop Icons (Focus)", "🖥️ Masaüstü Simgelerini Gizle (Odak)")
        let desktopItem = NSMenuItem(title: desktopTitle, action: #selector(toggleDesktopIconsFromMenu), keyEquivalent: "h")
        desktopItem.keyEquivalentModifierMask = [.option]
        desktopItem.target = self
        menu.addItem(desktopItem)
        
        let loginStatus = LaunchAtLoginEngine.shared.isEnabled ? L10n.tr("Enabled (Disable)", "Açık (Kapat)") : L10n.tr("Disabled (Enable)", "Kapalı (Aç)")
        let loginItem = NSMenuItem(title: L10n.tr("🚀 Launch at Login: \(loginStatus)", "🚀 Girişte Otomatik Başlat: \(loginStatus)"), action: #selector(toggleLaunchAtLogin), keyEquivalent: "l")
        loginItem.target = self
        menu.addItem(loginItem)
        
        // Mounted External Drives & DMGs
        let ejectable = VolumeManager.shared.ejectableVolumes
        if !ejectable.isEmpty {
            menu.addItem(NSMenuItem.separator())
            for vol in ejectable {
                let icon = (vol.url.pathExtension.lowercased() == "dmg" || vol.name.contains(".dmg")) ? "💿" : "⏏️"
                let ejectTitle = "\(icon) \(L10n.tr("Eject", "Çıkar")): \(vol.name)"
                let volItem = NSMenuItem(title: ejectTitle, action: #selector(ejectVolumeFromMenu(_:)), keyEquivalent: "")
                volItem.target = self
                volItem.representedObject = vol
                menu.addItem(volItem)
            }
            if ejectable.count > 1 {
                let allTitle = "⏏️ \(L10n.tr("Eject All Mounted Drives", "Tüm Sürücüleri Çıkar")) (\(ejectable.count))"
                let allItem = NSMenuItem(title: allTitle, action: #selector(ejectAllVolumesFromMenu), keyEquivalent: "")
                allItem.target = self
                menu.addItem(allItem)
            }
        }
        
        menu.addItem(NSMenuItem.separator())
        
        let refreshItem = NSMenuItem(title: L10n.tr("Refresh Now", "Hemen Yenile"), action: #selector(refreshNow), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: L10n.tr("Quit ArkenStone", "ArkenStone'dan Çık"), action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil // Restore toggle behavior after click
    }
    
    @objc private func toggleShelfFromMenu() {
        if shelfPopover.isShown {
            closeShelfPopover()
        } else {
            showShelfPopover()
        }
    }
    
    @objc private func toggleNotesFromMenu() {
        toggleDetachedNotes()
    }
    
    @objc private func toggleShelfDragMode() {
        DropShelfEngine.shared.toggleDragMode()
    }
    
    public func selectTab(_ tab: ArkenTab) {
        showMainPopover()
        NotificationCenter.default.post(name: NSNotification.Name("ArkenSelectTab"), object: tab)
    }
    
    @objc public func openClipboardFromMenu() {
        selectTab(.clipboard)
    }
    
    @objc private func pasteboardItemClicked(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID,
              let item = ClipboardEngine.shared.items.first(where: { $0.id == id }) else { return }
        ClipboardEngine.shared.copyToSystem(item: item)
    }
    
    @objc private func clearClipboardFromMenu() {
        ClipboardEngine.shared.clearUnpinned()
        SoundManager.shared.play(.pop)
    }
    
    @objc public func triggerOCRFromMenu() {
        closeMainPopover()
        closeShelfPopover()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            ScreenOCREngine.shared.startCaptureAndRecognize()
        }
    }
    
    @objc public func triggerColorPickerFromMenu() {
        closeMainPopover()
        closeShelfPopover()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            ColorPickerEngine.shared.pickColor()
        }
    }
    
    @objc public func toggleCleanLock() {
        closeMainPopover()
        closeShelfPopover()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            KeyboardCleanEngine.shared.toggleLock()
        }
    }
    
    @objc private func toggleMicFromMenu() {
        AudioMuteEngine.shared.toggleMute()
    }
    
    @objc private func toggleKeepAwake() {
        KeepAwakeEngine.shared.toggle()
        updateButtonContent()
    }
    
    @objc private func toggleClamshellFromMenu() {
        KeepAwakeEngine.shared.toggleClamshell()
        SoundManager.shared.play(.pop)
    }
    
    @objc private func toggleLaunchAtLogin() {
        LaunchAtLoginEngine.shared.toggle()
    }
    
    @objc private func toggleDesktopIconsFromMenu() {
        DesktopFocusEngine.shared.toggleDesktopIcons()
    }
    
    @objc private func refreshNow() {
        monitor.updateAll()
        updateButtonContent()
    }
    
    @objc private func ejectVolumeFromMenu(_ sender: NSMenuItem) {
        guard let vol = sender.representedObject as? MountedVolumeItem else { return }
        VolumeManager.shared.eject(volume: vol)
    }
    
    @objc private func ejectAllVolumesFromMenu() {
        VolumeManager.shared.ejectAll()
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
