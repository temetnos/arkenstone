import SwiftUI
import UniformTypeIdentifiers

public struct DiskCleanerTab: View {
    @ObservedObject var cleaner = DiskCleanerEngine.shared
    @ObservedObject var l10n = LocalizationManager.shared
    @State private var showConfirmAlert: Bool = false
    @State private var isTargeted: Bool = false
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 12) {
            // Main Action & Status Card
            GlassCard(padding: 12) {
                VStack(spacing: 10) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(ArkenTheme.tempColor.opacity(0.18))
                                .frame(width: 44, height: 44)
                            Image(systemName: "sparkles")
                                .font(.system(size: 20))
                                .foregroundColor(ArkenTheme.tempColor)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.tr("System & Disk Cleaner", "Sistem & Disk Temizleyici"))
                                .font(.system(size: 13, weight: .bold))
                            Text(cleaner.lastStatusMessage)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    Divider().background(Color.white.opacity(0.1))
                    
                    // Buttons
                    HStack(spacing: 8) {
                        // Scan Button
                        Button(action: {
                            cleaner.scan()
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: cleaner.isScanning ? "arrow.triangle.2.circlepath" : "magnifyingglass")
                                    .rotationEffect(Angle(degrees: cleaner.isScanning ? 360 : 0))
                                    .animation(cleaner.isScanning ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: cleaner.isScanning)
                                Text(cleaner.isScanning ? L10n.tr("Scanning...", "Taranıyor...") : L10n.tr("Scan System", "Sistemi Tara"))
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(cleaner.isScanning || cleaner.isCleaning)
                        
                        Spacer()
                        
                        // Clean Button
                        Button(action: {
                            showConfirmAlert = true
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "trash.fill")
                                Text(cleaner.totalSelectedBytes > 0 ? (LocalizationManager.shared.language == .tr ? "Temizle (\(cleaner.totalSelectedFormatted))" : "Clean (\(cleaner.totalSelectedFormatted))") : L10n.tr("Clean", "Temizle"))
                            }
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(cleaner.totalSelectedBytes > 0 ? ArkenTheme.tempColor : Color.gray.opacity(0.4))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(cleaner.totalSelectedBytes == 0 || cleaner.isCleaning || cleaner.isScanning)
                    }
                }
            }
            
            // App Leftover Cleaner Card
            GlassCard(padding: 12) {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "shippingbox.and.arrow.backward.fill")
                            .foregroundColor(ArkenTheme.accentColor)
                            .font(.system(size: 13))
                        Text(L10n.tr("App Leftover Cleaner", "Uygulama Kalıntılarını Tam Temizleyici"))
                            .font(.system(size: 11, weight: .bold))
                        Spacer()
                        if cleaner.activeAppScan != nil {
                            Button(action: {
                                cleaner.clearAppScan()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    if let successMsg = cleaner.appCleanSuccessMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(successMsg)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.green)
                            Spacer()
                        }
                        .padding(8)
                        .background(Color.green.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    if cleaner.isScanningApp {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text(L10n.tr("Scanning application leftovers...", "Uygulama kalıntıları taranıyor..."))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    } else if let scan = cleaner.activeAppScan {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: scan.appURL.path))
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 28, height: 28)
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(scan.appName)
                                        .font(.system(size: 12, weight: .bold))
                                    Text(scan.bundleId)
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(scan.totalSizeFormatted)
                                    .font(.system(size: 14, weight: .black, design: .rounded))
                                    .foregroundColor(ArkenTheme.tempColor)
                            }
                            
                            if scan.leftovers.isEmpty {
                                Text(L10n.tr("No leftover files found for this application. (Clean)", "Bu uygulama için artık dosya bulunamadı. (Temiz)"))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 4)
                            } else {
                                VStack(spacing: 4) {
                                    ForEach(scan.leftovers) { item in
                                        let isAppBundle = item.path == scan.appURL.path
                                        HStack(spacing: 8) {
                                            Button(action: {
                                                cleaner.toggleAppLeftover(id: item.id)
                                            }) {
                                                Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                                                    .foregroundColor(item.isSelected ? (isAppBundle ? ArkenTheme.accentColor : ArkenTheme.tempColor) : .secondary)
                                                    .font(.system(size: 12))
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            
                                            Image(systemName: isAppBundle ? "app.badge.fill" : "folder.fill")
                                                .font(.system(size: 10))
                                                .foregroundColor(isAppBundle ? ArkenTheme.accentColor : .secondary)
                                            
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text(item.category)
                                                    .font(.system(size: 9, weight: isAppBundle ? .bold : .semibold))
                                                    .foregroundColor(isAppBundle ? ArkenTheme.accentColor : .primary)
                                                Text(item.name)
                                                    .font(.system(size: 8, design: .monospaced))
                                                    .foregroundColor(.secondary)
                                                    .lineLimit(1)
                                            }
                                            
                                            Spacer()
                                            
                                            Text(item.sizeFormatted)
                                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                                .foregroundColor(isAppBundle ? ArkenTheme.accentColor : .secondary)
                                        }
                                        .padding(.vertical, 2)
                                        .padding(.horizontal, 4)
                                        .background(isAppBundle ? ArkenTheme.accentColor.opacity(0.08) : Color.clear)
                                        .cornerRadius(4)
                                    }
                                }
                                
                                HStack {
                                    Button(action: {
                                        cleaner.clearAppScan()
                                    }) {
                                        Text(L10n.tr("Cancel", "Vazgeç"))
                                            .font(.system(size: 10))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    Spacer()
                                    
                                    let isAppSelected = scan.leftovers.contains { $0.path == scan.appURL.path && $0.isSelected }
                                    
                                    Button(action: {
                                        cleaner.cleanAppLeftovers()
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "trash.fill")
                                            if isAppSelected {
                                                Text(LocalizationManager.shared.language == .tr
                                                     ? "Uygulamayı ve Kalıntıları Sil (\(scan.totalSizeFormatted))"
                                                     : "Uninstall App & Leftovers (\(scan.totalSizeFormatted))")
                                            } else {
                                                Text(LocalizationManager.shared.language == .tr
                                                     ? "Kalıntıları Temizle (\(scan.totalSizeFormatted))"
                                                     : "Clean Leftovers (\(scan.totalSizeFormatted))")
                                            }
                                        }
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(isAppSelected ? ArkenTheme.accentColor : ArkenTheme.tempColor)
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .disabled(scan.leftovers.filter { $0.isSelected }.isEmpty)
                                }
                                .padding(.top, 4)
                            }
                        }
                    } else {
                        // Drop zone & select app button & Shelf bridge hint
                        VStack(spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "app.badge.checkmark")
                                    .foregroundColor(ArkenTheme.tempColor)
                                    .font(.system(size: 13))
                                Text(L10n.tr("Choose Any Application (.app)", "İstediğiniz Uygulamayı (.app) Seçin"))
                                    .font(.system(size: 11, weight: .bold))
                            }
                            
                            Button(action: {
                                cleaner.selectAppViaDialog()
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "magnifyingglass.circle.fill")
                                        .font(.system(size: 12))
                                    Text(L10n.tr("Select Application (.app)...", "Uygulama Seç (.app)..."))
                                }
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(ArkenTheme.tempColor)
                                .clipShape(Capsule())
                                .shadow(color: ArkenTheme.tempColor.opacity(0.35), radius: 3)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            HStack(spacing: 4) {
                                Image(systemName: "hand.draw.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(ArkenTheme.accentColor)
                                Text(L10n.tr("Shelf Bridge: Drag any .app into Floating Shelf and click '🧹 Clean'", "Dosya Rafı Köprüsü: Uygulamayı yüzen Rafa bırakıp '🧹 Kalıntı' butonuna basabilirsiniz"))
                                    .font(.system(size: 8.5))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isTargeted ? ArkenTheme.accentColor : Color.white.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [4]))
                        )
                        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                            guard let provider = providers.first else { return false }
                            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                                var targetURL: URL?
                                if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                                    targetURL = url
                                } else if let url = item as? URL {
                                    targetURL = url
                                }
                                if let url = targetURL {
                                    DispatchQueue.main.async {
                                        cleaner.scanApp(url: url)
                                    }
                                }
                            }
                            return true
                        }
                    }
                }
            }
            
            // Safety Guarantee Badge
            GlassCard(padding: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(ArkenTheme.batteryColor)
                        .font(.system(size: 13))
                    Text(L10n.tr("100% Safe Cleaning:", "100% Güvenli Temizlik:"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(ArkenTheme.batteryColor)
                    Text(L10n.tr("Only temporary build artifacts and caches are scanned. Personal files and documents are never touched.", "Yalnızca geçici derleme artıkları ve önbellekler taranır. Belgeleriniz veya ayarlarınız asla silinmez."))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            
            // Full Disk Access Banner for Trash & Protected Caches
            if !cleaner.hasFullDiskAccess {
                GlassCard(padding: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 13))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.tr("Full Disk Access Recommended", "Tam Disk Erişimi Önerilir"))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.orange)
                            Text(L10n.tr("Grant access in macOS Settings to scan User Trash & system files.", "Çöp Sepeti ve korumalı dosyaları tam taramak için Sistem Ayarları'ndan Tam Disk Erişimi verin."))
                                .font(.system(size: 8.5))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(action: {
                            cleaner.openFullDiskAccessSettings()
                        }) {
                            Text(L10n.tr("Grant Access", "İzin Ver"))
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.85))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            
            // Category Checklist
            VStack(spacing: 6) {
                ForEach(cleaner.categories) { cat in
                    CleanCategoryRow(category: cat, hasFullDiskAccess: cleaner.hasFullDiskAccess) {
                        cleaner.toggleCategory(id: cat.id)
                    }
                }
            }
        }
        .alert(isPresented: $showConfirmAlert) {
            Alert(
                title: Text(L10n.tr("Safe Disk Clean", "Güvenli Disk Temizliği")),
                message: Text(LocalizationManager.shared.language == .tr ? "Seçili \(cleaner.totalSelectedFormatted) geçici önbellek ve derleme kalıntısı güvenle temizlenecek. Devam edilsin mi?" : "\(cleaner.totalSelectedFormatted) of selected caches and build artifacts will be safely removed. Proceed?"),
                primaryButton: .default(Text(L10n.tr("Yes, Clean", "Evet, Temizle"))) {
                    cleaner.cleanSelected()
                },
                secondaryButton: .cancel(Text(L10n.tr("Cancel", "Vazgeç")))
            )
        }
        .onAppear {
            if cleaner.categories.allSatisfy({ $0.sizeBytes == 0 }) {
                cleaner.scan()
            }
        }
    }
}

// Category Row Component
struct CleanCategoryRow: View {
    let category: CleanTargetCategory
    var hasFullDiskAccess: Bool = true
    var onToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 10) {
            // Checkbox
            Button(action: onToggle) {
                Image(systemName: category.isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(category.isSelected ? ArkenTheme.tempColor : .secondary)
                    .font(.system(size: 14))
            }
            .buttonStyle(PlainButtonStyle())
            
            // Icon
            Image(systemName: category.icon)
                .font(.system(size: 12))
                .foregroundColor(ArkenTheme.tempColor)
                .frame(width: 16)
            
            // Details
            VStack(alignment: .leading, spacing: 1) {
                Text(category.name)
                    .font(.system(size: 11, weight: .semibold))
                Text(category.detail)
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Size or Cleaned Badge
            if category.isCleaned {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark")
                    Text(L10n.tr("Cleaned", "Temizlendi"))
                }
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(ArkenTheme.batteryColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(ArkenTheme.batteryColor.opacity(0.15))
                .clipShape(Capsule())
            } else if category.id == "trash" && !hasFullDiskAccess && category.sizeBytes == 0 {
                Text(L10n.tr("Permission Required", "İzin Gerekli"))
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundColor(.orange)
            } else {
                Text(category.sizeFormatted)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(category.sizeBytes > 0 ? .primary : .secondary)
            }
        }
        .padding(9)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(category.isSelected ? 0.06 : 0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(category.isSelected ? ArkenTheme.tempColor.opacity(0.2) : Color.white.opacity(0.06), lineWidth: 0.8)
        )
    }
}
