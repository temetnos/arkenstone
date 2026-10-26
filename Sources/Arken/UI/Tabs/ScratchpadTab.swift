import SwiftUI

public struct ScratchpadTab: View {
    @ObservedObject var scratchpad = ScratchpadEngine.shared
    @ObservedObject var l10n = LocalizationManager.shared
    
    private var wordCount: Int {
        scratchpad.content.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
    }
    private var charCount: Int {
        scratchpad.content.count
    }
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 10) {
            // Action Strip
            GlassCard(padding: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "note.text")
                        .foregroundColor(ArkenTheme.tempColor)
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(L10n.tr("Quick Scratchpad", "Hızlı Karalama Defteri"))
                            .font(.system(size: 11, weight: .bold))
                        
                        if !scratchpad.content.isEmpty {
                            Text("\(wordCount) \(L10n.tr("words", "kelime")) • \(charCount) \(L10n.tr("chars", "krkt"))")
                                .font(.system(size: 8.5))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Detach to Floating Window Button
                    Button(action: {
                        StatusBarController.shared?.openDetachedNotes()
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.up.right.square")
                            Text(L10n.tr("Detach", "Pencereye Ayır"))
                        }
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(ArkenTheme.tempColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(ArkenTheme.tempColor.opacity(0.15))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(L10n.tr("Open Detached Floating Notes Window (Pinned on All Desktops)", "Ayrılabilir Yüzen Notlar Penceresini Aç (Tüm Masaüstlerinde Sabit)"))
                    
                    // Export Button
                    if !scratchpad.content.isEmpty {
                        Button(action: {
                            exportNotes()
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "square.and.arrow.up")
                                Text(L10n.tr("Export", "Dışa Aktar"))
                            }
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(ArkenTheme.cpuColor)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(ArkenTheme.cpuColor.opacity(0.15))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help(L10n.tr("Export notes to Arken_Notes.txt on Desktop", "Notları Masaüstüne Arken_Notes.txt olarak kaydet"))
                    }
                    
                    // Copy All Button
                    Button(action: {
                        scratchpad.copyAll()
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "doc.on.doc.fill")
                            Text(L10n.tr("Copy", "Kopyala"))
                        }
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(ArkenTheme.accentColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(ArkenTheme.accentColor.opacity(0.15))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(L10n.tr("Copy all to clipboard", "Tüm içeriği panoya kopyala"))
                    
                    // Undo Clear Button
                    if scratchpad.canUndoClear {
                        Button(action: {
                            scratchpad.undoClear()
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.uturn.backward")
                                Text(L10n.tr("Undo", "Geri Al"))
                            }
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(ArkenTheme.batteryColor)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(ArkenTheme.batteryColor.opacity(0.15))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help(L10n.tr("Undo clear", "Silinen metni geri al"))
                    }
                    
                    // Clear Button
                    if !scratchpad.content.isEmpty {
                        Button(action: {
                            scratchpad.clear()
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help(L10n.tr("Clear Text", "Metni Temizle"))
                    }
                }
            }
            
            // Text Editor Area
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.3))
                
                if scratchpad.content.isEmpty {
                    Text(L10n.tr("Quickly jot down notes, commands, API keys, or temporary snippets here. Auto-saved...", "Buraya hızlıca not, komut satırı, API anahtarı veya geçici metin yapıştırabilirsiniz. Otomatik kaydedilir..."))
                        .font(.system(size: 11))
                        .foregroundColor(Color.secondary.opacity(0.6))
                        .padding(12)
                }
                
                MacScratchpadEditor(text: $scratchpad.content, fontSize: scratchpad.fontSize)
                    .padding(6)
            }
            .frame(height: 220)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.8)
            )
            
            // Bottom Metric Bar
            GlassCard(padding: 6) {
                HStack(spacing: 8) {
                    Text(LocalizationManager.shared.language == .tr ? "\(scratchpad.wordCount) kelime" : "\(scratchpad.wordCount) words")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Text("•")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Text(LocalizationManager.shared.language == .tr ? "\(scratchpad.characterCount) karakter" : "\(scratchpad.characterCount) chars")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Text("•")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Text(LocalizationManager.shared.language == .tr ? "\(scratchpad.lineCount) satır" : "\(scratchpad.lineCount) lines")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Circle().fill(Color.green).frame(width: 5, height: 5)
                        Text(L10n.tr("Saved", "Kayıtlı"))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    private func exportNotes() {
        guard !scratchpad.content.isEmpty else { return }
        let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory() + "/Desktop")
        let fileURL = desktopURL.appendingPathComponent("Arken_Notes.txt")
        do {
            try scratchpad.content.write(to: fileURL, atomically: true, encoding: .utf8)
            NSWorkspace.shared.activateFileViewerSelecting([fileURL])
            SoundManager.shared.play(.success)
        } catch {
            print("Failed to export notes: \(error)")
        }
    }
}

public struct MacScratchpadEditor: NSViewRepresentable {
    @Binding var text: String
    var fontSize: CGFloat
    
    public init(text: Binding<String>, fontSize: CGFloat = 11.5) {
        self._text = text
        self.fontSize = fontSize
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        
        let contentSize = scrollView.contentSize
        let textView = ScratchpadTextView(frame: NSRect(origin: .zero, size: contentSize))
        textView.minSize = NSSize(width: 0.0, height: contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textColor = .labelColor
        textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.isRichText = false
        textView.allowsUndo = true
        textView.delegate = context.coordinator
        textView.insertionPointColor = NSColor.white
        
        textView.isSelectable = true
        textView.isEditable = true
        textView.string = text
        
        scrollView.documentView = textView
        return scrollView
    }
    
    public func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? ScratchpadTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
    }
    
    public class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MacScratchpadEditor
        
        init(_ parent: MacScratchpadEditor) {
            self.parent = parent
        }
        
        public func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            self.parent.text = textView.string
        }
    }
}

class ScratchpadTextView: NSTextView {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command) else {
            return super.performKeyEquivalent(with: event)
        }
        switch event.charactersIgnoringModifiers {
        case "c", "C":
            copy(nil)
            return true
        case "v", "V":
            paste(nil)
            return true
        case "x", "X":
            cut(nil)
            return true
        case "a", "A":
            selectAll(nil)
            return true
        case "z", "Z":
            if event.modifierFlags.contains(.shift) {
                undoManager?.redo()
            } else {
                undoManager?.undo()
            }
            return true
        default:
            return super.performKeyEquivalent(with: event)
        }
    }
}
