import SwiftUI
import UniformTypeIdentifiers

public struct ShelfTab: View {
    @ObservedObject var shelf = DropShelfEngine.shared
    @ObservedObject var l10n = LocalizationManager.shared
    @State private var isTargeted = false
    @State private var isNotchIslandVisible = true
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 12) {
            // Shelf Control & Toggle Card
            GlassCard(padding: 12) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(ArkenTheme.accentColor.opacity(0.18))
                            .frame(width: 44, height: 44)
                        Image(systemName: "hand.draw.fill")
                            .font(.system(size: 18))
                            .foregroundColor(ArkenTheme.accentColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.tr("Dynamic File Shelf & Undo", "Dinamik Dosya Rafı & Geri Al"))
                            .font(.system(size: 12, weight: .bold))
                        Text(shelf.items.isEmpty ? L10n.tr("Shelf is empty", "Raf boş") : (LocalizationManager.shared.language == .tr ? "\(shelf.items.count) dosya bekliyor" : "\(shelf.items.count) files staged"))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Undo Button
                    if shelf.canUndo {
                        Button(action: {
                            withAnimation {
                                shelf.undo()
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.uturn.backward.circle.fill")
                                Text(L10n.tr("Undo", "Geri Al"))
                            }
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(ArkenTheme.accentColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(ArkenTheme.accentColor.opacity(0.15))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help(L10n.tr("Undo last action", "Son silme/temizleme işlemini geri al"))
                    }
                    
                    // Floating Shelf Window Button
                    Button(action: {
                        StatusBarController.shared?.openDetachedShelf()
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "pip.enter")
                            Text(L10n.tr("Float", "Yüzen Raf"))
                        }
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(ArkenTheme.accentColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(ArkenTheme.accentColor.opacity(0.18))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(L10n.tr("Open detached floating shelf (Always on top)", "Bağımsız yüzen dosya rafını aç (Her zaman üstte)"))
                    
                    // Clear All
                    if !shelf.items.isEmpty {
                        Button(action: {
                            withAnimation {
                                shelf.clearAll()
                            }
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help(L10n.tr("Clear All", "Tümünü Temizle"))
                    }
                }
            }
            
            // How it works card
            GlassCard(padding: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundColor(ArkenTheme.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.tr("Quick Tip", "Pratik Kullanım İpucu"))
                            .font(.system(size: 11, weight: .semibold))
                        Text(L10n.tr("You can drag files directly onto the Arken menu bar icon. Shelf auto-closes after drop.", "Dosyayı doğrudan menü çubuğundaki Arken simgesine sürükleyip bırakabilirsiniz. Taşındıktan sonra raf otomatik kapanır."))
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Drag Mode Selector Card
            GlassCard(padding: 10) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: shelf.dragMode == .copy ? "doc.on.doc.fill" : "arrow.right.doc.fill")
                                .foregroundColor(shelf.dragMode == .copy ? ArkenTheme.accentColor : Color.orange)
                                .font(.system(size: 11))
                            Text("\(L10n.tr("Drag Action", "Sürükleme Eylemi")): \(shelf.dragMode.title)")
                                .font(.system(size: 11, weight: .bold))
                        }
                        Text(shelf.dragMode.description)
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Picker("", selection: $shelf.dragMode) {
                        Text(L10n.tr("📋 Copy", "📋 Kopyala")).tag(ShelfDragMode.copy)
                        Text(L10n.tr("✂️ Move", "✂️ Taşı")).tag(ShelfDragMode.move)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 150)
                }
            }
            
            // Drop Area / Staging Area
            GlassCard(padding: 10) {
                VStack(spacing: 8) {
                    if shelf.items.isEmpty {
                        VStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                                    .foregroundColor(isTargeted ? ArkenTheme.accentColor : Color.white.opacity(0.2))
                                    .frame(height: 110)
                                    .background(isTargeted ? ArkenTheme.accentColor.opacity(0.1) : Color.white.opacity(0.02))
                                
                                VStack(spacing: 6) {
                                    Image(systemName: "plus.square.dashed")
                                        .font(.system(size: 28))
                                        .foregroundColor(isTargeted ? ArkenTheme.accentColor : .secondary)
                                    Text(L10n.tr("Drag files or folders here", "Dosyaları veya klasörleri buraya sürükleyin"))
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    } else {
                        VStack(spacing: 4) {
                            ForEach(shelf.items) { item in
                                ShelfListRow(item: item)
                                    .draggableFile(url: item.url, itemId: item.id)
                            }
                        }
                    }
                }
            }
            .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isTargeted) { providers in
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
                return true
            }
        }
    }
}

struct ShelfListRow: View {
    let item: ShelvedItem
    @ObservedObject var shelf = DropShelfEngine.shared
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                .resizable()
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                Text(item.sizeFormatted)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            
            if item.isApplication {
                ShelfCleanButton {
                    DiskCleanerEngine.shared.scanApp(url: item.url)
                    NotificationCenter.default.post(name: NSNotification.Name("ArkenSelectTab"), object: ArkenTab.cleaner)
                }
                .frame(width: 58, height: 18)
            }
            
            Spacer()
            
            if isHovered {
                HStack(spacing: 6) {
                    ShelfIconButton(iconName: "folder", tooltip: L10n.tr("Show in Finder", "Finder'da Göster")) {
                        shelf.revealInFinder(url: item.url)
                    }
                    .frame(width: 16, height: 16)
                    
                    ShelfIconButton(iconName: "doc.on.doc", tooltip: L10n.tr("Copy to Clipboard", "Panoya Kopyala")) {
                        shelf.copyToPasteboard(item: item)
                    }
                    .frame(width: 16, height: 16)
                    
                    ShelfRemoveButton {
                        withAnimation {
                            shelf.removeItem(id: item.id)
                        }
                    }
                    .frame(width: 16, height: 16)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.white.opacity(0.08) : Color.white.opacity(0.02))
        )
        .onHover { h in isHovered = h }
        .onTapGesture(count: 2) {
            shelf.openFile(url: item.url)
        }
        .contextMenu {
            if item.isApplication {
                Button(action: {
                    DiskCleanerEngine.shared.scanApp(url: item.url)
                    NotificationCenter.default.post(name: NSNotification.Name("ArkenSelectTab"), object: ArkenTab.cleaner)
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
            }
        }
    }
}
