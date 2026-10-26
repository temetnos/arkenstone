import SwiftUI
import AppKit

public struct DedicatedNotesView: View {
    @ObservedObject var scratchpad = ScratchpadEngine.shared
    @ObservedObject var l10n = LocalizationManager.shared
    public var isDetached: Bool = true
    var onClose: (() -> Void)? = nil
    
    public init(isDetached: Bool = true, onClose: (() -> Void)? = nil) {
        self.isDetached = isDetached
        self.onClose = onClose
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            // Header Bar
            HStack(spacing: 8) {
                Image(systemName: "note.text")
                    .foregroundColor(ArkenTheme.tempColor)
                    .font(.system(size: 13))
                
                Text(L10n.tr("Arken Notes", "Hızlı Notlar"))
                    .font(.system(size: 12, weight: .bold))
                
                if !scratchpad.content.isEmpty {
                    Text("\(scratchpad.wordCount) w • \(scratchpad.characterCount) c")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1.5)
                        .background(ArkenTheme.tempColor.opacity(0.2))
                        .foregroundColor(ArkenTheme.tempColor)
                        .clipShape(Capsule())
                }
                
                Spacer()
                
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
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(ArkenTheme.cpuColor.opacity(0.15))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(L10n.tr("Export notes to Desktop", "Notları Masaüstüne aktar"))
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
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(ArkenTheme.accentColor.opacity(0.15))
                    .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
                .help(L10n.tr("Copy all to clipboard", "Tüm metni panoya kopyala"))
                
                // Undo Clear Button
                if scratchpad.canUndoClear {
                    Button(action: {
                        scratchpad.undoClear()
                    }) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(ArkenTheme.batteryColor)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 3)
                            .background(ArkenTheme.batteryColor.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(L10n.tr("Undo clear", "Silmeyi geri al"))
                }
                
                // Clear Button
                if !scratchpad.content.isEmpty {
                    Button(action: {
                        scratchpad.clear()
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(L10n.tr("Clear notes", "Notları temizle"))
                }
                
                if isDetached {
                    Button(action: {
                        onClose?()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(L10n.tr("Close Window", "Pencereyi Kapat"))
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            
            // Native Editor Container
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.28))
                
                if scratchpad.content.isEmpty {
                    Text(L10n.tr("Type notes, code, commands, or thoughts here. Fully synced and auto-saved...",
                                 "Buraya hızlıca not, kod parçası veya komut yazabilirsiniz. Tüm masaüstlerinde senkronize ve kayıtlı..."))
                        .font(.system(size: 11))
                        .foregroundColor(Color.secondary.opacity(0.55))
                        .padding(12)
                }
                
                MacScratchpadEditor(text: $scratchpad.content, fontSize: scratchpad.fontSize)
                    .padding(6)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.8)
            )
            .padding(.horizontal, 10)
            
            // Bottom Status Strip
            HStack(spacing: 8) {
                Text("\(scratchpad.wordCount) words • \(scratchpad.characterCount) chars • \(scratchpad.lineCount) lines")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Circle().fill(Color.green).frame(width: 5, height: 5)
                    Text(L10n.tr("Auto-Saved", "Otomatik Kayıtlı"))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .frame(minWidth: 380, minHeight: 240)
        .background(VisualEffectBackground())
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
