import SwiftUI

public struct ClipboardTab: View {
    @ObservedObject var clipboard = ClipboardEngine.shared
    @ObservedObject var l10n = LocalizationManager.shared
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 10) {
            // Header & Action Bar
            GlassCard(padding: 10) {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "doc.on.clipboard.fill")
                            .foregroundColor(ArkenTheme.accentColor)
                        Text(L10n.tr("Clipboard History", "Pano Geçmişi"))
                            .font(.system(size: 11, weight: .bold))
                        
                        Text("\(clipboard.items.count)")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(ArkenTheme.accentColor.opacity(0.3))
                            .clipShape(Capsule())
                        
                        // Privacy indicator badge
                        HStack(spacing: 3) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 8))
                            Text(L10n.tr("RAM Only", "Sadece RAM"))
                                .font(.system(size: 8, weight: .semibold))
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.15))
                        .foregroundColor(.green)
                        .clipShape(Capsule())
                        .help(L10n.tr("History is kept strictly in volatile memory (RAM) and never saved to disk.", "Pano geçmişi yalnızca geçici bellekte (RAM) tutulur, asla diske yazılmaz."))
                        
                        Spacer()
                        
                        // Eyedropper / Color Picker Button
                        Button(action: {
                            ColorPickerEngine.shared.pickColor()
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "eyedropper.halffull")
                                Text(L10n.tr("Pick Color", "Renk Seç"))
                            }
                            .font(.system(size: 9, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(ArkenTheme.accentColor.opacity(0.18))
                            .foregroundColor(ArkenTheme.accentColor)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help(L10n.tr("Sample pixel color from screen into clipboard (HEX)", "Ekrandan büyüteçle renk seçip panoya kopyala (HEX)"))
                        
                        // Clear Unpinned
                        if !clipboard.items.isEmpty {
                            Button(action: {
                                withAnimation {
                                    clipboard.clearUnpinned()
                                }
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "trash")
                                    Text(L10n.tr("Clear", "Temizle"))
                                }
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.secondary)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .help(L10n.tr("Clear Unpinned", "Sabitlenmemişleri Temizle"))
                        }
                    }
                    
                    // Search Bar
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        TextField(L10n.tr("Search clipboard...", "Panoda ara..."), text: $clipboard.searchQuery)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 11))
                        
                        if !clipboard.searchQuery.isEmpty {
                            Button(action: { clipboard.searchQuery = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .help(L10n.tr("Clear search", "Aramayı temizle"))
                        }
                    }
                    .padding(5)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(6)
                    
                    // Filter Pills
                    HStack(spacing: 4) {
                        ForEach(ClipboardContentType.allCases) { filter in
                            Button(action: {
                                withAnimation {
                                    clipboard.selectedFilter = filter
                                }
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: filter.icon)
                                        .font(.system(size: 8))
                                    Text(filter.title)
                                        .font(.system(size: 9, weight: .medium))
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(clipboard.selectedFilter == filter ? ArkenTheme.accentColor.opacity(0.3) : Color.white.opacity(0.04))
                                .foregroundColor(clipboard.selectedFilter == filter ? ArkenTheme.accentColor : .secondary)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        Spacer()
                    }
                }
            }
            
            // Clipboard Items List
            if clipboard.filteredItems.isEmpty {
                GlassCard(padding: 20) {
                    VStack(spacing: 6) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                        Text(clipboard.searchQuery.isEmpty ? L10n.tr("Clipboard is empty", "Pano geçmişi boş") : L10n.tr("No matching items found", "Eşleşen öğe bulunamadı"))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                VStack(spacing: 5) {
                    ForEach(clipboard.filteredItems) { item in
                        ClipboardRowView(item: item)
                    }
                }
            }
        }
    }
}

// Single Clipboard Item Row
struct ClipboardRowView: View {
    let item: ClipboardItem
    @ObservedObject var clipboard = ClipboardEngine.shared
    @State private var isHovered = false
    @State private var showCopiedBadge = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            iconColumn
            contentPreview
            Spacer()
            actionButtons
        }
        .padding(8)
        .background(rowBackground)
        .overlay(rowOverlay)
        .contentShape(Rectangle())
        .onHover { h in isHovered = h }
        .onTapGesture {
            triggerCopy()
        }
    }
    
    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(item.isPinned ? Color.white.opacity(0.08) : (isHovered ? Color.white.opacity(0.06) : Color.white.opacity(0.02)))
    }
    
    private var rowOverlay: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(item.isPinned ? ArkenTheme.tempColor.opacity(0.3) : Color.white.opacity(0.06), lineWidth: 0.8)
    }
    
    private func triggerCopy() {
        clipboard.copyToSystem(item: item)
        withAnimation(.easeInOut(duration: 0.15)) {
            showCopiedBadge = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 0.15)) {
                showCopiedBadge = false
            }
        }
    }
    
    @ViewBuilder
    private var iconColumn: some View {
        VStack(spacing: 4) {
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 9))
                    .foregroundColor(ArkenTheme.tempColor)
            } else {
                Image(systemName: item.type.icon)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            
            // Color swatch if color
            if item.type == .color {
                Circle()
                    .fill(Color(hex: item.content) ?? Color.clear)
                    .frame(width: 10, height: 10)
                    .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 0.5))
            }
        }
        .frame(width: 14)
        .padding(.top, 2)
    }
    
    @ViewBuilder
    private var contentPreview: some View {
        VStack(alignment: .leading, spacing: 4) {
            if item.type == .image, let data = item.imageData, let nsImg = NSImage(data: data) {
                Image(nsImage: nsImg)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: 95, alignment: .leading)
                    .cornerRadius(6)
                    .background(Color.black.opacity(0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                    )
                
                HStack(spacing: 6) {
                    Text(item.preview)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Spacer()
                    Text(timeAgo(item.copiedAt))
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
            } else {
                Text(item.preview)
                    .font(item.type == .code ? .system(size: 10, design: .monospaced) : .system(size: 10))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                HStack(spacing: 6) {
                    Text(LocalizationManager.shared.language == .tr ? "\(item.characterCount) krk" : "\(item.characterCount) chars")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                    Text("•")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                    Text(timeAgo(item.copiedAt))
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 4) {
            // Pin button
            Button(action: {
                withAnimation {
                    clipboard.togglePin(id: item.id)
                }
            }) {
                Image(systemName: item.isPinned ? "pin.slash.fill" : "pin")
                    .font(.system(size: 10))
                    .foregroundColor(item.isPinned ? ArkenTheme.tempColor : .secondary)
            }
            .buttonStyle(PlainButtonStyle())
            .help(item.isPinned ? L10n.tr("Unpin", "Sabitlemeyi Kaldır") : L10n.tr("Pin to Top", "Başa Sabitle"))
            
            // If image: Send to File Shelf button
            if item.type == .image {
                Button(action: {
                    clipboard.sendImageToShelf(item: item)
                }) {
                    Image(systemName: "hand.draw.fill")
                        .font(.system(size: 10))
                        .foregroundColor(ArkenTheme.accentColor)
                }
                .buttonStyle(PlainButtonStyle())
                .help(L10n.tr("Send Image to File Shelf", "Görseli Dosya Rafına Gönder"))
            }
            
            // Copied confirmation badge
            if showCopiedBadge {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                    Text(L10n.tr("Copied!", "Kopyalandı!"))
                        .font(.system(size: 8.5, weight: .bold))
                }
                .foregroundColor(.green)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.18))
                .clipShape(Capsule())
            }
            
            // Copy button
            Button(action: {
                triggerCopy()
            }) {
                Image(systemName: "doc.on.doc.fill")
                    .font(.system(size: 10))
                    .foregroundColor(ArkenTheme.accentColor)
            }
            .buttonStyle(PlainButtonStyle())
            .help(L10n.tr("Copy to Clipboard", "Panoya Kopyala"))
            
            // Text Transforms (JSON, Base64, URL, Trim)
            if item.type != .image {
                Menu {
                    ForEach(TextTransform.allCases) { transform in
                        Button(transform.title) {
                            clipboard.transformAndCopy(item: item, transform: transform)
                        }
                    }
                } label: {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 10))
                        .foregroundColor(ArkenTheme.accentColor.opacity(0.85))
                }
                .menuStyle(BorderlessButtonMenuStyle())
                .frame(width: 14)
                .help(L10n.tr("Transform & Copy (JSON, Base64, URL, Plain Text)", "Dönüştür ve Kopyala (JSON, Base64, URL, Düz Metin)"))
            }
            
            // Delete button
            if isHovered {
                Button(action: {
                    withAnimation {
                        clipboard.deleteItem(id: item.id)
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
                .help(L10n.tr("Delete", "Sil"))
            }
        }
    }
    
    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 {
            return L10n.tr("Just now", "Az önce")
        } else if seconds < 3600 {
            return LocalizationManager.shared.language == .tr ? "\(seconds / 60) dk" : "\(seconds / 60)m ago"
        } else {
            return LocalizationManager.shared.language == .tr ? "\(seconds / 3600) sa" : "\(seconds / 3600)h ago"
        }
    }
}

// Helper Color hex parser
extension Color {
    init?(hex: String) {
        var clean = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("#") {
            clean.remove(at: clean.startIndex)
        }
        guard clean.count == 6, let rgbValue = UInt64(clean, radix: 16) else { return nil }
        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
