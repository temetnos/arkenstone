import SwiftUI
import AppKit

public struct DraggableFileView<Content: View>: NSViewRepresentable {
    public let fileURL: URL
    public let itemId: UUID
    public let content: Content

    public init(fileURL: URL, itemId: UUID, @ViewBuilder content: () -> Content) {
        self.fileURL = fileURL
        self.itemId = itemId
        self.content = content()
    }

    public func makeNSView(context: Context) -> DraggableContainerView<Content> {
        let view = DraggableContainerView(fileURL: fileURL, itemId: itemId, content: content)
        return view
    }

    public func updateNSView(_ nsView: DraggableContainerView<Content>, context: Context) {
        nsView.update(fileURL: fileURL, itemId: itemId, content: content)
    }
}

public class DraggableContainerView<Content: View>: NSView, NSDraggingSource {
    public var fileURL: URL
    public var itemId: UUID
    private var hostingView: NSHostingView<Content>?
    private var dragStartEvent: NSEvent?
    private var isDraggingSessionActive = false

    public init(fileURL: URL, itemId: UUID, content: Content) {
        self.fileURL = fileURL
        self.itemId = itemId
        super.init(frame: .zero)
        self.wantsLayer = true

        let hosting = NSHostingView(rootView: content)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(hosting)
        self.hostingView = hosting

        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: self.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])
    }

    public func update(fileURL: URL, itemId: UUID, content: Content) {
        self.fileURL = fileURL
        self.itemId = itemId
        self.hostingView?.rootView = content
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override var intrinsicContentSize: NSSize {
        return hostingView?.intrinsicContentSize ?? super.intrinsicContentSize
    }

    public override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)
        
        // 1. Allow clicks on NSButton, NSControl, or interactive buttons
        var v = hit
        while let current = v {
            if current is NSButton || current is NSControl || current.className.contains("Button") {
                return current
            }
            if current === self {
                break
            }
            v = current.superview
        }
        
        // 2. If a specific subview other than hostingView was hit, let it receive the event
        if let hit = hit, hit !== self && hit !== hostingView {
            return hit
        }
        
        return self
    }

    public override func mouseDown(with event: NSEvent) {
        self.dragStartEvent = event
        self.isDraggingSessionActive = false
        if event.clickCount == 2 {
            DropShelfEngine.shared.openFile(url: fileURL)
        }
    }

    public override func mouseDragged(with event: NSEvent) {
        guard !isDraggingSessionActive else { return }

        let startPoint = dragStartEvent?.locationInWindow ?? event.locationInWindow
        let currentPoint = event.locationInWindow
        let distance = hypot(currentPoint.x - startPoint.x, currentPoint.y - startPoint.y)

        // System threshold for deliberate drag
        if distance > 3 {
            isDraggingSessionActive = true
            startDragSession(with: event)
        }
    }

    public override func mouseUp(with event: NSEvent) {
        defer {
            self.dragStartEvent = nil
            self.isDraggingSessionActive = false
        }
        
        guard !isDraggingSessionActive else { return }
        
        // Direct click fallback safety net for the remove button:
        let loc = self.convert(event.locationInWindow, from: nil)
        
        // DedicatedShelfItemCard (bounds.width < 150): remove button is at top right
        let inCardRemoveCorner = loc.x >= (bounds.width - 34) && (loc.y >= (bounds.height - 35) || loc.y <= 35)
        if inCardRemoveCorner && bounds.width < 150 {
            withAnimation {
                DropShelfEngine.shared.removeItem(id: itemId)
            }
            return
        }
        
        // ShelfListRow (bounds.width >= 150): remove button is at far right
        if bounds.width >= 150 && loc.x >= (bounds.width - 32) {
            withAnimation {
                DropShelfEngine.shared.removeItem(id: itemId)
            }
            return
        }
    }

    public override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        let openItem = NSMenuItem(title: L10n.tr("Open", "Aç"), action: #selector(openFileAction), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        let revealItem = NSMenuItem(title: L10n.tr("Show in Finder", "Finder'da Göster"), action: #selector(revealFileAction), keyEquivalent: "")
        revealItem.target = self
        menu.addItem(revealItem)

        let copyItem = NSMenuItem(title: L10n.tr("Copy to Clipboard", "Panoya Kopyala"), action: #selector(copyFileAction), keyEquivalent: "")
        copyItem.target = self
        menu.addItem(copyItem)

        menu.addItem(NSMenuItem.separator())

        let removeItem = NSMenuItem(title: L10n.tr("Remove from Shelf", "Raftan Kaldır"), action: #selector(removeFileAction), keyEquivalent: "")
        removeItem.target = self
        menu.addItem(removeItem)

        return menu
    }

    @objc private func openFileAction() {
        DropShelfEngine.shared.openFile(url: fileURL)
    }

    @objc private func revealFileAction() {
        DropShelfEngine.shared.revealInFinder(url: fileURL)
    }

    @objc private func copyFileAction() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([fileURL as NSURL])
        DropShelfEngine.shared.lastActionMessage = LocalizationManager.shared.language == .tr
            ? "\"\(fileURL.lastPathComponent)\" panoya kopyalandı"
            : "\"\(fileURL.lastPathComponent)\" copied to clipboard"
    }

    @objc private func removeFileAction() {
        withAnimation {
            DropShelfEngine.shared.removeItem(id: itemId)
        }
    }

    private func startDragSession(with event: NSEvent) {
        let draggingItem = NSDraggingItem(pasteboardWriter: fileURL as NSURL)
        let icon = NSWorkspace.shared.icon(forFile: fileURL.path)
        icon.size = NSSize(width: 48, height: 48)

        let targetWidth = min(48, max(24, self.bounds.width))
        let targetHeight = min(48, max(24, self.bounds.height))
        let centerRect = NSRect(
            x: (self.bounds.width - targetWidth) / 2,
            y: (self.bounds.height - targetHeight) / 2,
            width: targetWidth,
            height: targetHeight
        )
        draggingItem.setDraggingFrame(centerRect, contents: icon)

        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }

    // MARK: - NSDraggingSource Protocol
    public func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        switch context {
        case .outsideApplication:
            // Dynamic modifier keys:
            // Holding Option (⌥) dynamically forces COPY
            if NSEvent.modifierFlags.contains(.option) {
                return .copy
            }
            // Holding Command (⌘) dynamically forces MOVE
            if NSEvent.modifierFlags.contains(.command) {
                return .move
            }
            // User configured mode:
            return DropShelfEngine.shared.dragMode == .copy ? .copy : .move
        case .withinApplication:
            return .copy
        @unknown default:
            return .copy
        }
    }

    public func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        self.isDraggingSessionActive = false
        self.dragStartEvent = nil

        DispatchQueue.main.async {
            if operation.contains(.move) {
                DropShelfEngine.shared.lastActionMessage = L10n.tr(
                    "\"\(self.fileURL.lastPathComponent)\" moved to destination",
                    "\"\(self.fileURL.lastPathComponent)\" yeni yerine taşındı"
                )
                if DropShelfEngine.shared.removeOnMove {
                    withAnimation {
                        DropShelfEngine.shared.removeItem(id: self.itemId)
                    }
                }
            } else if operation.contains(.copy) {
                DropShelfEngine.shared.lastActionMessage = L10n.tr(
                    "\"\(self.fileURL.lastPathComponent)\" copied (Original preserved)",
                    "\"\(self.fileURL.lastPathComponent)\" kopyalandı (Orijinal korundu)"
                )
            }
        }
    }
}

extension View {
    public func draggableFile(url: URL, itemId: UUID) -> some View {
        DraggableFileView(fileURL: url, itemId: itemId) {
            self
        }
    }
}

// MARK: - Native NSButton Controls for Shelf (Guaranteed Hit-Testing)

public struct ShelfRemoveButton: NSViewRepresentable {
    public let action: () -> Void
    
    public init(action: @escaping () -> Void) {
        self.action = action
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }
    
    public func makeNSView(context: Context) -> NSButton {
        let button = NSButton(frame: NSRect(x: 0, y: 0, width: 16, height: 16))
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.setButtonType(.momentaryChange)
        
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .bold)
        if let image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Remove")?.withSymbolConfiguration(config) {
            button.image = image
            button.contentTintColor = .systemRed
        }
        button.imagePosition = .imageOnly
        button.target = context.coordinator
        button.action = #selector(Coordinator.clicked)
        button.toolTip = L10n.tr("Remove from Shelf", "Raftan Kaldır")
        return button
    }
    
    public func updateNSView(_ nsView: NSButton, context: Context) {
        nsView.target = context.coordinator
        nsView.action = #selector(Coordinator.clicked)
    }
    
    public class Coordinator: NSObject {
        let action: () -> Void
        init(action: @escaping () -> Void) {
            self.action = action
        }
        @objc func clicked() {
            action()
        }
    }
}

public struct ShelfCleanButton: NSViewRepresentable {
    public let action: () -> Void
    
    public init(action: @escaping () -> Void) {
        self.action = action
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }
    
    public func makeNSView(context: Context) -> NSButton {
        let button = NSButton(frame: .zero)
        button.isBordered = false
        button.bezelStyle = .inline
        button.wantsLayer = true
        button.layer?.cornerRadius = 8
        button.layer?.backgroundColor = NSColor(red: 0.98, green: 0.45, blue: 0.22, alpha: 0.95).cgColor
        
        let title = "  ✨ " + L10n.tr("Clean", "Kalıntı") + "  "
        let attr = NSAttributedString(
            string: title,
            attributes: [
                .foregroundColor: NSColor.white,
                .font: NSFont.systemFont(ofSize: 9, weight: .bold)
            ]
        )
        button.attributedTitle = attr
        button.target = context.coordinator
        button.action = #selector(Coordinator.clicked)
        button.toolTip = L10n.tr("Scan and clean leftover files for this application (~/Library)", "Bu uygulamanın kütüphanedeki öksüz dosyalarını temizle")
        return button
    }
    
    public func updateNSView(_ nsView: NSButton, context: Context) {
        nsView.target = context.coordinator
        nsView.action = #selector(Coordinator.clicked)
    }
    
    public class Coordinator: NSObject {
        let action: () -> Void
        init(action: @escaping () -> Void) {
            self.action = action
        }
        @objc func clicked() {
            action()
        }
    }
}

public struct ShelfIconButton: NSViewRepresentable {
    public let iconName: String
    public let tooltip: String
    public let tintColor: NSColor
    public let action: () -> Void
    
    public init(iconName: String, tooltip: String, tintColor: NSColor = .secondaryLabelColor, action: @escaping () -> Void) {
        self.iconName = iconName
        self.tooltip = tooltip
        self.tintColor = tintColor
        self.action = action
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }
    
    public func makeNSView(context: Context) -> NSButton {
        let button = NSButton(frame: NSRect(x: 0, y: 0, width: 16, height: 16))
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.setButtonType(.momentaryChange)
        let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .regular)
        if let image = NSImage(systemSymbolName: iconName, accessibilityDescription: tooltip)?.withSymbolConfiguration(config) {
            button.image = image
            button.contentTintColor = tintColor
        }
        button.imagePosition = .imageOnly
        button.target = context.coordinator
        button.action = #selector(Coordinator.clicked)
        button.toolTip = tooltip
        return button
    }
    
    public func updateNSView(_ nsView: NSButton, context: Context) {
        nsView.target = context.coordinator
        nsView.action = #selector(Coordinator.clicked)
    }
    
    public class Coordinator: NSObject {
        let action: () -> Void
        init(action: @escaping () -> Void) {
            self.action = action
        }
        @objc func clicked() {
            action()
        }
    }
}

