import Foundation
import AppKit
import Combine

public struct ShelvedItem: Identifiable, Equatable {
    public let id: UUID
    public let url: URL
    public let name: String
    public let sizeFormatted: String
    public let addedAt: Date
    public let isDirectory: Bool
    
    public init(url: URL) {
        self.id = UUID()
        self.url = url
        self.name = url.lastPathComponent
        self.addedAt = Date()
        
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        self.isDirectory = isDir.boolValue
        
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? UInt64 {
            let mb = Double(size) / (1024 * 1024)
            if mb > 1024 {
                self.sizeFormatted = String(format: "%.1f GB", mb / 1024.0)
            } else if mb > 1 {
                self.sizeFormatted = String(format: "%.1f MB", mb)
            } else {
                let kb = Double(size) / 1024.0
                self.sizeFormatted = String(format: "%.0f KB", kb)
            }
        } else {
            self.sizeFormatted = isDir.boolValue ? L10n.tr("Folder", "Klasör") : "-"
        }
    }
    
    public var isApplication: Bool {
        return url.pathExtension.lowercased() == "app"
    }
    
    public static func == (lhs: ShelvedItem, rhs: ShelvedItem) -> Bool {
        return lhs.id == rhs.id && lhs.url == rhs.url && lhs.sizeFormatted == rhs.sizeFormatted
    }
}

public enum ShelfDragMode: String, CaseIterable, Identifiable {
    case copy = "copy"
    case move = "move"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .copy: return L10n.tr("Copy", "Kopyala")
        case .move: return L10n.tr("Move", "Taşı")
        }
    }
    
    public var icon: String {
        switch self {
        case .copy: return "doc.on.doc.fill"
        case .move: return "arrow.right.doc.fill"
        }
    }
    
    public var description: String {
        switch self {
        case .copy: return L10n.tr("Original file is preserved, copy created at destination (Safe)", "Orijinal dosya korunur, hedef konuma kopyalanır (Önerilen / Güvenli)")
        case .move: return L10n.tr("Original file is moved to destination (Cut & Paste)", "Orijinal dosya hedef konuma taşınır (Kes-Yapıştır)")
        }
    }
}

public class DropShelfEngine: ObservableObject {
    public static let shared = DropShelfEngine()
    
    private let dragModeKey = "arken_shelf_drag_mode"
    private let removeOnMoveKey = "arken_shelf_remove_on_move"
    
    @Published public var items: [ShelvedItem] = []
    @Published public var undoStack: [[ShelvedItem]] = []
    @Published public var isShelfOpen: Bool = false
    @Published public var lastActionMessage: String = ""
    
    @Published public var dragMode: ShelfDragMode {
        didSet {
            UserDefaults.standard.set(dragMode.rawValue, forKey: dragModeKey)
        }
    }
    
    @Published public var removeOnMove: Bool {
        didSet {
            UserDefaults.standard.set(removeOnMove, forKey: removeOnMoveKey)
        }
    }
    
    public var canUndo: Bool {
        return !undoStack.isEmpty
    }
    
    public init() {
        if let saved = UserDefaults.standard.string(forKey: dragModeKey) ?? UserDefaults.standard.string(forKey: "palantir_shelf_drag_mode"),
           let mode = ShelfDragMode(rawValue: saved) {
            self.dragMode = mode
        } else {
            self.dragMode = .copy // Default to copy (safe mode)
        }
        
        if let savedRemove = UserDefaults.standard.object(forKey: removeOnMoveKey) as? Bool {
            self.removeOnMove = savedRemove
        } else if let legacyRemove = UserDefaults.standard.object(forKey: "palantir_shelf_remove_on_move") as? Bool {
            self.removeOnMove = legacyRemove
        } else {
            self.removeOnMove = true
        }
    }
    
    public func toggleDragMode() {
        dragMode = (dragMode == .copy) ? .move : .copy
        lastActionMessage = L10n.tr("Drag mode: \(dragMode.title)", "Sürükleme modu: \(dragMode.title)")
        SoundManager.shared.play(.action)
    }
    
    public func addURLs(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        saveStateForUndo()
        
        for url in urls {
            // Avoid adding exact duplicate paths in the same list
            if !items.contains(where: { $0.url == url }) {
                items.insert(ShelvedItem(url: url), at: 0)
            }
        }
        
        lastActionMessage = L10n.tr("\(urls.count) file(s) added to shelf", "\(urls.count) dosya rafa eklendi")
        SoundManager.shared.play(.pop)
    }
    
    public func removeItem(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        saveStateForUndo()
        let name = items[index].name
        items.remove(at: index)
        lastActionMessage = L10n.tr("\"\(name)\" removed from shelf", "\"\(name)\" raftan kaldırıldı")
    }
    
    public func clearAll() {
        guard !items.isEmpty else { return }
        saveStateForUndo()
        let count = items.count
        items.removeAll()
        lastActionMessage = L10n.tr("\(count) file(s) cleared (Undo available)", "\(count) dosya temizlendi (Geri alabilirsiniz)")
    }
    
    public func undo() {
        guard let previousState = undoStack.popLast() else { return }
        items = previousState
        lastActionMessage = L10n.tr("Action undone", "İşlem geri alındı")
        SoundManager.shared.play(.action)
    }
    
    public func revealInFinder(url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    
    public func openFile(url: URL) {
        NSWorkspace.shared.open(url)
    }
    
    public func copyToPasteboard(item: ShelvedItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([item.url as NSURL])
        lastActionMessage = L10n.tr("\"\(item.name)\" copied to clipboard", "\"\(item.name)\" panoya kopyalandı")
    }
    
    private func saveStateForUndo() {
        undoStack.append(items)
        if undoStack.count > 25 {
            undoStack.removeFirst()
        }
    }
}
