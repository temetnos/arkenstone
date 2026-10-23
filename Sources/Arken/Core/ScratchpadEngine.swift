import Foundation
import AppKit
import Combine

public class ScratchpadEngine: ObservableObject {
    public static let shared = ScratchpadEngine()
    
    private let storageKey = "ArkenScratchpadContent"
    private var lastClearedContent: String = ""
    
    @Published public var content: String = "" {
        didSet {
            UserDefaults.standard.set(content, forKey: storageKey)
        }
    }
    
    @Published public var fontSize: CGFloat = 12
    
    public var characterCount: Int {
        content.count
    }
    
    public var wordCount: Int {
        let words = content.split { $0.isWhitespace || $0.isNewline }
        return words.count
    }
    
    public var lineCount: Int {
        content.components(separatedBy: .newlines).count
    }
    
    public var canUndoClear: Bool {
        !lastClearedContent.isEmpty
    }
    
    public init() {
        if let saved = UserDefaults.standard.string(forKey: storageKey) {
            self.content = saved
        } else if let legacy = UserDefaults.standard.string(forKey: "PalantirScratchpadContent") {
            self.content = legacy
        }
    }
    
    public func copyAll() {
        guard !content.isEmpty else { return }
        let pboard = NSPasteboard.general
        pboard.clearContents()
        pboard.setString(content, forType: .string)
        ClipboardEngine.shared.checkPasteboard()
        SoundManager.shared.play(.action)
    }
    
    public func clear() {
        guard !content.isEmpty else { return }
        lastClearedContent = content
        content = ""
        SoundManager.shared.play(.pop)
    }
    
    public func undoClear() {
        guard !lastClearedContent.isEmpty else { return }
        content = lastClearedContent
        lastClearedContent = ""
        SoundManager.shared.play(.success)
    }
}
