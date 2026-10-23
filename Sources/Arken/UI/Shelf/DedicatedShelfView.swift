import SwiftUI
import UniformTypeIdentifiers

public struct DedicatedShelfView: View {
    @ObservedObject var shelf = DropShelfEngine.shared
    @State private var isTargeted: Bool = false
    public var isDetached: Bool = false
    var onClose: (() -> Void)? = nil
    
    public init(isDetached: Bool = false, onClose: (() -> Void)? = nil) {
        self.isDetached = isDetached
        self.onClose = onClose
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            // Header Bar
            HStack(spacing: 8) {
                Image(systemName: "hand.draw.fill")
                    .foregroundColor(ArkenTheme.accentColor)
                    .font(.system(size: 13))
                
                Text(L10n.tr("File Shelf", "Dosya Rafı"))
                    .font(.system(size: 12, weight: .bold))
                
                if !shelf.items.isEmpty {
                    Text("\(shelf.items.count)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(ArkenTheme.accentColor.opacity(0.3))
                        .clipShape(Capsule())
                }
                
                Spacer()
                
                // Drag Mode Switcher (Copy vs Move)
                HStack(spacing: 2) {
                    Button(action: {
                        withAnimation(.spring(response: 0.25)) {
                            shelf.dragMode = .copy
                        }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "doc.on.doc.fill")
                                .font(.system(size: 8))
                            Text(L10n.tr("Copy", "Kopyala"))
                                .font(.system(size: 9, weight: shelf.dragMode == .copy ? .bold : .medium))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(shelf.dragMode == .copy ? ArkenTheme.accentColor.opacity(0.35) : Color.clear)
                        .foregroundColor(shelf.dragMode == .copy ? .white : .secondary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(L10n.tr("Copy (Safe): Copies file to Finder (+), original is preserved (⌥ Option)", "Kopyala (Güvenli): Dosyayı Finder'a kopyalar (+), orijinal yerinde kalır (Geçici: ⌥ Option)"))
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.25)) {
                            shelf.dragMode = .move
                        }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.right.doc.fill")
                                .font(.system(size: 8))
                            Text(L10n.tr("Move", "Taşı"))
                                .font(.system(size: 9, weight: shelf.dragMode == .move ? .bold : .medium))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(shelf.dragMode == .move ? Color.orange.opacity(0.35) : Color.clear)
                        .foregroundColor(shelf.dragMode == .move ? .white : .secondary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(L10n.tr("Move (Cut): Moves file to destination, original is removed (⌘ Command)", "Taşı (Kes): Dosyayı hedefe taşır, orijinal konumdan silinir (Geçici: ⌘ Command)"))
                }
                .padding(2)
                .background(Color.white.opacity(0.06))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
                
                // Undo Button
                if shelf.canUndo {
                    Button(action: {
                        withAnimation {
                            shelf.undo()
                        }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.uturn.backward")
                            Text(L10n.tr("Undo", "Geri Al"))
                        }
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(ArkenTheme.accentColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(ArkenTheme.accentColor.opacity(0.18))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(L10n.tr("Undo last action (Cmd+Z)", "Son işlemi geri al (Cmd+Z)"))
                }
                
                // Clear All Button
                if !shelf.items.isEmpty {
                    Button(action: {
                        withAnimation {
                            shelf.clearAll()
                            checkEmptyAndClose()
                        }
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(L10n.tr("Clear All", "Tümünü Temizle"))
                }
                
                // Detach / Dock Button
                Button(action: {
                    if isDetached {
                        StatusBarController.shared?.closeDetachedShelf()
                        StatusBarController.shared?.showShelfPopover()
                    } else {
                        StatusBarController.shared?.openDetachedShelf()
                    }
                }) {
                    Image(systemName: isDetached ? "pip.exit" : "pip.enter")
                        .font(.system(size: 11))
                        .foregroundColor(isDetached ? ArkenTheme.accentColor : .secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .help(isDetached 
                    ? L10n.tr("Dock Shelf to Menu Bar", "Rafı Menü Çubuğuna Sabitle") 
                    : L10n.tr("Detach to Floating Window (Always on Top)", "Pencereyi Ayır (Her Zaman Üstte)"))
                
                // Close Button
                Button(action: {
                    onClose?()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .help(L10n.tr("Close", "Kapat"))
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            
            Divider().background(Color.white.opacity(0.1))
            
            // File Cards or Drop Zone
            if shelf.items.isEmpty {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                        .foregroundColor(isTargeted ? ArkenTheme.accentColor : Color.white.opacity(0.2))
                        .frame(height: 120)
                        .background(isTargeted ? ArkenTheme.accentColor.opacity(0.1) : Color.white.opacity(0.02))
                    
                    VStack(spacing: 6) {
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.system(size: 26))
                            .foregroundColor(isTargeted ? ArkenTheme.accentColor : ArkenTheme.accentColor.opacity(0.6))
                        Text(isTargeted ? L10n.tr("Drop files now!", "Dosyayı Bırakın!") : L10n.tr("Drop files here", "Dosyaları buraya bırakın"))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(isTargeted ? ArkenTheme.accentColor : .primary)
                        Text(L10n.tr("Drag out to any app or folder whenever you need", "İstediğiniz uygulamaya taşımak için raftan sürükleyebilirsiniz"))
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 10)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(shelf.items) { item in
                            DedicatedShelfItemCard(item: item) {
                                checkEmptyAndClose()
                            }
                            .draggableFile(url: item.url, itemId: item.id)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                }
                .frame(height: 125)
            }
            
            // Bottom Hint
            HStack {
                Text(shelf.items.isEmpty ? L10n.tr("Tip: Drag & drop files onto the menu bar icon", "İpucu: Dosyayı tutup başka bir uygulamaya taşıyabilirsiniz") : shelf.lastActionMessage)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
        }
        .frame(width: 380, height: 200)
        .background(VisualEffectBackground())
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
            return true
        }
    }
    
    private func checkEmptyAndClose() {
        guard SettingsStore.shared.autoCloseShelf else { return }
        if shelf.items.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                if self.shelf.items.isEmpty {
                    self.onClose?()
                }
            }
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) {
        var urls: [URL] = []
        let group = DispatchGroup()
        
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    defer { group.leave() }
                    if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        urls.append(url)
                    } else if let url = item as? URL {
                        urls.append(url)
                    }
                }
            }
        }
        
        group.notify(queue: .main) {
            shelf.addURLs(urls)
        }
    }
}

// Dedicated Shelf Item Card
struct DedicatedShelfItemCard: View {
    let item: ShelvedItem
    var onRemoved: (() -> Void)? = nil
    @ObservedObject var shelf = DropShelfEngine.shared
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 4) {
            // Icon
            ZStack(alignment: .topTrailing) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
                
                // Remove Button
                if isHovered {
                    ShelfRemoveButton {
                        withAnimation {
                            shelf.removeItem(id: item.id)
                            onRemoved?()
                        }
                    }
                    .frame(width: 16, height: 16)
                    .offset(x: 4, y: -4)
                }
            }
            
            // Name
            Text(item.name)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
                .frame(width: 78)
            
            // Size & Drag Mode Hint
            HStack(spacing: 3) {
                Image(systemName: shelf.dragMode == .copy ? "plus.circle.fill" : "arrow.right.circle.fill")
                    .font(.system(size: 7))
                    .foregroundColor(shelf.dragMode == .copy ? Color.green : Color.orange)
                Text(item.sizeFormatted)
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
            }
            
            // Clean Leftovers Quick Bridge
            if item.isApplication {
                ShelfCleanButton {
                    DiskCleanerEngine.shared.scanApp(url: item.url)
                    StatusBarController.shared?.closeShelfPopover()
                    StatusBarController.shared?.selectTab(.cleaner)
                    NotificationCenter.default.post(name: NSNotification.Name("ArkenSelectTab"), object: ArkenTab.cleaner)
                }
                .frame(width: 60, height: 18)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHovered ? Color.white.opacity(0.12) : Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHovered ? ArkenTheme.accentColor.opacity(0.6) : Color.white.opacity(0.1), lineWidth: 0.8)
        )
        .onHover { h in isHovered = h }
        .onTapGesture(count: 2) {
            shelf.openFile(url: item.url)
        }
        .contextMenu {
            if item.isApplication {
                Button(action: {
                    DiskCleanerEngine.shared.scanApp(url: item.url)
                    StatusBarController.shared?.closeShelfPopover()
                    StatusBarController.shared?.selectTab(.cleaner)
                }) {
                    Text(L10n.tr("🧹 Clean App Leftovers...", "🧹 Uygulama Kalıntılarını Temizle..."))
                }
                Divider()
            }
            Button(L10n.tr("Open", "Aç")) { shelf.openFile(url: item.url) }
            Button(L10n.tr("Show in Finder", "Finder'da Göster")) { shelf.revealInFinder(url: item.url) }
            Button(L10n.tr("Copy to Clipboard", "Panoya Kopyala")) { shelf.copyToPasteboard(item: item) }
            Divider()
            Button(L10n.tr("Remove from Shelf", "Raftan Kaldır")) {
                shelf.removeItem(id: item.id)
                onRemoved?()
            }
        }
    }
}
