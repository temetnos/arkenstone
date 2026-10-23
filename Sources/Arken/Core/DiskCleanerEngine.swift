import Foundation
import AppKit
import Combine
import UniformTypeIdentifiers

public struct AppLeftoverItem: Identifiable {
    public let id = UUID()
    public let path: String
    public let name: String
    public let category: String
    public let sizeBytes: UInt64
    public var isSelected: Bool = true
    
    public var sizeFormatted: String {
        if sizeBytes == 0 { return "< 1 KB" }
        let bcf = ByteCountFormatter()
        bcf.countStyle = .file
        return bcf.string(fromByteCount: Int64(sizeBytes))
    }
}

public struct ScannedAppInfo {
    public let appName: String
    public let bundleId: String
    public let appURL: URL
    public var leftovers: [AppLeftoverItem] = []
    
    public var totalSizeBytes: UInt64 {
        leftovers.filter { $0.isSelected }.reduce(0) { $0 + $1.sizeBytes }
    }
    
    public var totalSizeFormatted: String {
        if totalSizeBytes == 0 { return "< 1 KB" }
        let bcf = ByteCountFormatter()
        bcf.countStyle = .file
        return bcf.string(fromByteCount: Int64(totalSizeBytes))
    }
}

public struct CleanTargetCategory: Identifiable {
    public let id: String
    public let nameEn: String
    public let nameTr: String
    public let detailEn: String
    public let detailTr: String
    public let icon: String
    public let paths: [String]
    public var sizeBytes: UInt64 = 0
    public var isSelected: Bool = true
    public var isCleaned: Bool = false
    
    public var name: String {
        return L10n.tr(nameEn, nameTr)
    }
    
    public var detail: String {
        return L10n.tr(detailEn, detailTr)
    }
    
    public init(id: String, nameEn: String, nameTr: String, detailEn: String, detailTr: String, icon: String, paths: [String], sizeBytes: UInt64 = 0, isSelected: Bool = true, isCleaned: Bool = false) {
        self.id = id
        self.nameEn = nameEn
        self.nameTr = nameTr
        self.detailEn = detailEn
        self.detailTr = detailTr
        self.icon = icon
        self.paths = paths
        self.sizeBytes = sizeBytes
        self.isSelected = isSelected
        self.isCleaned = isCleaned
    }
    
    public var sizeFormatted: String {
        let mb = Double(sizeBytes) / (1024 * 1024)
        if mb > 1024 {
            return String(format: "%.2f GB", mb / 1024.0)
        } else if mb > 0.1 {
            return String(format: "%.0f MB", mb)
        } else {
            return "0 MB"
        }
    }
}

public class DiskCleanerEngine: ObservableObject {
    public static let shared = DiskCleanerEngine()
    
    @Published public var categories: [CleanTargetCategory] = []
    @Published public var isScanning: Bool = false
    @Published public var isCleaning: Bool = false
    @Published public var lastCleanedBytes: UInt64 = 0
    @Published public var lastStatusMessage: String = L10n.tr("Ready to scan", "Taramaya hazır")
    
    // App Leftover Cleaner
    @Published public var activeAppScan: ScannedAppInfo?
    @Published public var isScanningApp: Bool = false
    @Published public var appCleanSuccessMessage: String?
    
    public var totalSelectedBytes: UInt64 {
        categories.filter { $0.isSelected && !$0.isCleaned }.reduce(0) { $0 + $1.sizeBytes }
    }
    
    public var totalSelectedFormatted: String {
        let mb = Double(totalSelectedBytes) / (1024 * 1024)
        if mb > 1024 {
            return String(format: "%.2f GB", mb / 1024.0)
        } else {
            return String(format: "%.0f MB", mb)
        }
    }
    
    // Strict Whitelist of Safe Directories
    private let home = NSHomeDirectory()
    
    public init() {
        setupDefaultCategories()
    }
    
    private func setupDefaultCategories() {
        self.categories = [
            CleanTargetCategory(
                id: "homebrew",
                nameEn: "Homebrew Download Cache",
                nameTr: "Homebrew İndirme Önbelleği",
                detailEn: "Old downloaded package tarballs and build caches",
                detailTr: "Eski indirilmiş paket ve derleme arşivleri",
                icon: "shippingbox.fill",
                paths: [
                    "\(home)/Library/Caches/Homebrew"
                ]
            ),
            CleanTargetCategory(
                id: "developer",
                nameEn: "Xcode & Developer Build Caches",
                nameTr: "Xcode & Geliştirici Geçici Dosyaları",
                detailEn: "DerivedData and build artifacts (recreated automatically upon build)",
                detailTr: "DerivedData ve derleme artıkları (sonraki derlemede yeniden üretilir)",
                icon: "hammer.fill",
                paths: [
                    "\(home)/Library/Developer/Xcode/DerivedData",
                    "\(home)/Library/Caches/com.apple.dt.Xcode",
                    "\(home)/.cocoapods/cache"
                ]
            ),
            CleanTargetCategory(
                id: "packages",
                nameEn: "Package Manager Caches",
                nameTr: "Paket Yöneticisi Önbellekleri",
                detailEn: "Pip, npm, and yarn package download caches",
                detailTr: "Pip, npm ve yarn bağımlılık indirme kalıntıları",
                icon: "cube.box.fill",
                paths: [
                    "\(home)/Library/Caches/pip",
                    "\(home)/.npm/_cacache",
                    "\(home)/Library/Caches/Yarn"
                ]
            ),
            CleanTargetCategory(
                id: "app_caches",
                nameEn: "App Media & Web Caches",
                nameTr: "Uygulama Medya Önbellekleri",
                detailEn: "Temporary cache data from Spotify, Chrome, Slack, Safari etc.",
                detailTr: "Spotify, Chrome, Slack vb. uygulamaların geçici medya verileri",
                icon: "app.badge.checkmark.fill",
                paths: [
                    "\(home)/Library/Caches/com.spotify.client/Data",
                    "\(home)/Library/Caches/Google/Chrome/Default/Cache",
                    "\(home)/Library/Caches/com.brave.Browser/Default/Cache",
                    "\(home)/Library/Caches/Slack/Cache",
                    "\(home)/Library/Caches/com.apple.Safari/WebKitCache"
                ]
            ),
            CleanTargetCategory(
                id: "logs",
                nameEn: "System Crash & Diagnostic Reports",
                nameTr: "Sistem Çökme & Tanı Günlükleri",
                detailEn: "Old crash reports and diagnostic log files",
                detailTr: "Eski crash logları ve hata kayıtları",
                icon: "doc.text.magnifyingglass",
                paths: [
                    "\(home)/Library/Logs/DiagnosticReports"
                ]
            ),
            CleanTargetCategory(
                id: "trash",
                nameEn: "User Trash",
                nameTr: "Kullanıcı Çöp Sepeti",
                detailEn: "Items currently in your macOS Trash",
                detailTr: "Çöp sepetinde bekleyen silinmiş dosyalar",
                icon: "trash.fill",
                paths: [
                    "\(home)/.Trash"
                ]
            )
        ]
    }
    
    // MARK: - Safe Scanning
    public func scan() {
        guard !isScanning else { return }
        isScanning = true
        lastStatusMessage = L10n.tr("Scanning system...", "Sistem taranıyor...")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            var updatedCategories = self.categories
            
            for i in 0..<updatedCategories.count {
                var total: UInt64 = 0
                for path in updatedCategories[i].paths {
                    if self.isPathSafe(path) && FileManager.default.fileExists(atPath: path) {
                        total += self.calculateFolderSize(path: path)
                    }
                }
                updatedCategories[i].sizeBytes = total
                updatedCategories[i].isCleaned = false
            }
            
            DispatchQueue.main.async {
                self.categories = updatedCategories
                self.isScanning = false
                self.lastStatusMessage = L10n.tr("Scan complete: \(self.totalSelectedFormatted) reclaimable", "Tarama tamamlandı: \(self.totalSelectedFormatted) temizlenebilir")
                SoundManager.shared.play(.pop)
            }
        }
    }
    
    // MARK: - Safe Cleaning
    public func cleanSelected() {
        guard !isCleaning else { return }
        isCleaning = true
        lastStatusMessage = L10n.tr("Cleaning safely...", "Güvenli temizlik yapılıyor...")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            var freedBytes: UInt64 = 0
            var updatedCategories = self.categories
            let fm = FileManager.default
            
            for i in 0..<updatedCategories.count {
                guard updatedCategories[i].isSelected && !updatedCategories[i].isCleaned else { continue }
                
                var categoryFreed: UInt64 = 0
                for path in updatedCategories[i].paths {
                    // Safety assertion check
                    guard self.isPathSafe(path) && fm.fileExists(atPath: path) else { continue }
                    
                    let pathSize = self.calculateFolderSize(path: path)
                    
                    // Empty contents of folder safely
                    if let contents = try? fm.contentsOfDirectory(atPath: path) {
                        for item in contents {
                            let itemPath = (path as NSString).appendingPathComponent(item)
                            // Strict check to never delete symlinks to system or forbidden paths
                            if self.isPathSafe(itemPath) {
                                try? fm.removeItem(atPath: itemPath)
                            }
                        }
                    }
                    categoryFreed += pathSize
                }
                
                freedBytes += categoryFreed
                updatedCategories[i].sizeBytes = 0
                updatedCategories[i].isCleaned = true
            }
            
            DispatchQueue.main.async {
                self.categories = updatedCategories
                self.isCleaning = false
                self.lastCleanedBytes = freedBytes
                
                let mb = Double(freedBytes) / (1024 * 1024)
                let freedStr = mb > 1024 ? String(format: "%.2f GB", mb / 1024.0) : String(format: "%.0f MB", mb)
                self.lastStatusMessage = L10n.tr("Cleaning complete: \(freedStr) space recovered!", "Temizlik tamamlandı: \(freedStr) alan kazanıldı!")
                SoundManager.shared.play(.success)
            }
        }
    }
    
    public func toggleCategory(id: String) {
        if let idx = categories.firstIndex(where: { $0.id == id }) {
            categories[idx].isSelected.toggle()
        }
    }
    
    // MARK: - Strict Safety Verification
    private func isPathSafe(_ path: String) -> Bool {
        let standardized = (path as NSString).standardizingPath
        
        // 1. NEVER delete anything in these forbidden directories!
        let forbidden = [
            "\(home)/Documents",
            "\(home)/Desktop",
            "\(home)/Downloads",
            "\(home)/Pictures",
            "\(home)/Music",
            "\(home)/Movies",
            "\(home)/.ssh",
            "\(home)/.gnupg",
            "\(home)/Library/Keychains",
            "\(home)/Library/Preferences",
            "\(home)/Library/Application Support",
            "/System",
            "/Library",
            "/usr",
            "/bin",
            "/Applications"
        ]
        
        for forb in forbidden {
            if standardized == forb || standardized.hasPrefix(forb + "/") {
                return false
            }
        }
        
        // 2. MUST be within authorized cache / temporary zones
        let allowedPrefixes = [
            "\(home)/Library/Caches",
            "\(home)/Library/Developer/Xcode/DerivedData",
            "\(home)/Library/Logs/DiagnosticReports",
            "\(home)/.Trash",
            "\(home)/.cocoapods/cache",
            "\(home)/.npm/_cacache"
        ]
        
        for allowed in allowedPrefixes {
            if standardized == allowed || standardized.hasPrefix(allowed + "/") {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - App Leftover Cleaner Logic
    public func scanApp(url: URL) {
        guard !isScanningApp else { return }
        isScanningApp = true
        appCleanSuccessMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Normalize URL to .app root if subpath was passed
            var appURL = url
            if appURL.pathExtension.lowercased() != "app" {
                var current = appURL
                while current.pathComponents.count > 1 {
                    if current.pathExtension.lowercased() == "app" {
                        appURL = current
                        break
                    }
                    let parent = current.deletingLastPathComponent()
                    if parent == current { break }
                    current = parent
                }
            }
            
            // Protected System Whitelist: Guard against scanning core macOS system bundles
            let appPath = appURL.path
            let protectedNames = ["Finder.app", "Safari.app", "System Settings.app", "System Preferences.app", "App Store.app"]
            if appPath.hasPrefix("/System/") || appPath.hasPrefix("/System/Applications") || protectedNames.contains(appURL.lastPathComponent) {
                DispatchQueue.main.async {
                    self.isScanningApp = false
                    self.activeAppScan = nil
                    self.lastStatusMessage = L10n.tr("System apps cannot be uninstalled (Protected by macOS)", "Sistem uygulamaları silinemez (macOS Koruması)")
                    SoundManager.shared.play(.warning)
                }
                return
            }
            
            let appName = appURL.deletingPathExtension().lastPathComponent
            var bundleId = Bundle(url: appURL)?.bundleIdentifier
            
            if bundleId == nil {
                let infoPlistURL = appURL.appendingPathComponent("Contents/Info.plist")
                if let dict = NSDictionary(contentsOf: infoPlistURL) as? [String: Any],
                   let id = dict["CFBundleIdentifier"] as? String {
                    bundleId = id
                }
            }
            
            let resolvedBundleId = bundleId ?? appName
            var foundLeftovers: [AppLeftoverItem] = []
            let fm = FileManager.default
            
            // Collect search tokens (lowercased)
            var tokens = Set<String>()
            tokens.insert(appName.lowercased())
            tokens.insert(resolvedBundleId.lowercased())
            
            let genericTokens: Set<String> = [
                "com", "org", "net", "app", "mac", "client", "desktop", "helper",
                "system", "apple", "google", "microsoft"
            ]
            
            let bundleParts = resolvedBundleId.components(separatedBy: ".")
            for part in bundleParts {
                let p = part.lowercased()
                if p.count >= 3 && !genericTokens.contains(p) {
                    tokens.insert(p)
                    let stripped = p.trimmingCharacters(in: .decimalDigits)
                    if stripped.count >= 3 && !genericTokens.contains(stripped) {
                        tokens.insert(stripped)
                    }
                }
            }
            
            var seenPaths = Set<String>()
            
            func addIfValid(path: String, category: String) {
                let standardized = (path as NSString).standardizingPath
                guard self.isLeftoverPathSafe(standardized),
                      !seenPaths.contains(standardized),
                      fm.fileExists(atPath: standardized) else { return }
                
                let size = self.calculateFolderSize(path: standardized)
                seenPaths.insert(standardized)
                let name = (standardized as NSString).lastPathComponent
                foundLeftovers.append(AppLeftoverItem(
                    path: standardized,
                    name: name,
                    category: category,
                    sizeBytes: size,
                    isSelected: true
                ))
            }
            
            // 0. The Application bundle itself is ALWAYS item #1 (AppCleaner standard)
            if fm.fileExists(atPath: appURL.path) {
                let appSize = self.calculateFolderSize(path: appURL.path)
                seenPaths.insert((appURL.path as NSString).standardizingPath)
                foundLeftovers.append(AppLeftoverItem(
                    path: appURL.path,
                    name: appURL.lastPathComponent,
                    category: L10n.tr("Application", "Uygulama"),
                    sizeBytes: appSize,
                    isSelected: true
                ))
            }
            
            // 1. Direct candidate paths (both User Library and System Library)
            var directCandidates: [(String, String)] = [
                // User Library
                ("\(self.home)/Library/Application Support/\(appName)", "Application Support"),
                ("\(self.home)/Library/Application Support/\(resolvedBundleId)", "Application Support"),
                ("\(self.home)/Library/Caches/\(appName)", "Caches"),
                ("\(self.home)/Library/Caches/\(appName.lowercased())", "Caches"),
                ("\(self.home)/Library/Caches/\(resolvedBundleId)", "Caches"),
                ("\(self.home)/Library/Caches/\(resolvedBundleId).ShipIt", "Caches"),
                ("\(self.home)/Library/Containers/\(resolvedBundleId)", "Containers"),
                ("\(self.home)/Library/Containers/\(appName)", "Containers"),
                ("\(self.home)/Library/Group Containers/\(resolvedBundleId)", "Group Containers"),
                ("\(self.home)/Library/Group Containers/group.\(resolvedBundleId)", "Group Containers"),
                ("\(self.home)/Library/Preferences/\(resolvedBundleId).plist", "Preferences"),
                ("\(self.home)/Library/Preferences/\(appName).plist", "Preferences"),
                ("\(self.home)/Library/Preferences/\(appName.lowercased()).plist", "Preferences"),
                ("\(self.home)/Library/Saved Application State/\(resolvedBundleId).savedState", "Saved State"),
                ("\(self.home)/Library/Saved Application State/\(appName).savedState", "Saved State"),
                ("\(self.home)/Library/WebKit/\(resolvedBundleId)", "WebKit"),
                ("\(self.home)/Library/WebKit/\(appName)", "WebKit"),
                ("\(self.home)/Library/HTTPStorages/\(resolvedBundleId)", "HTTP Storages"),
                ("\(self.home)/Library/HTTPStorages/\(appName)", "HTTP Storages"),
                ("\(self.home)/Library/Logs/\(appName)", "Logs"),
                ("\(self.home)/Library/Logs/\(resolvedBundleId)", "Logs"),
                ("\(self.home)/Library/Application Scripts/\(resolvedBundleId)", "Application Scripts"),
                ("\(self.home)/Library/Application Scripts/\(appName)", "Application Scripts"),
                
                // System Library
                ("/Library/Application Support/\(appName)", "System Application Support"),
                ("/Library/Application Support/\(resolvedBundleId)", "System Application Support"),
                ("/Library/Caches/\(appName)", "System Caches"),
                ("/Library/Caches/\(resolvedBundleId)", "System Caches"),
                ("/Library/Preferences/\(resolvedBundleId).plist", "System Preferences"),
                ("/Library/Preferences/\(appName).plist", "System Preferences"),
                ("/Library/Logs/\(appName)", "System Logs"),
                ("/Library/Logs/\(resolvedBundleId)", "System Logs")
            ]
            
            // Audio application candidate paths (e.g. GarageBand, Logic)
            if appName.lowercased().contains("garageband") || appName.lowercased().contains("logic") {
                directCandidates.append(("/Library/Application Support/GarageBand", "System Application Support"))
                directCandidates.append(("/Library/Audio/Apple Loops/Apple/Apple Loops for GarageBand", "Audio Loops"))
                directCandidates.append(("\(self.home)/Music/Audio Music Apps", "Audio Music Apps"))
            }
            
            for (path, category) in directCandidates {
                addIfValid(path: path, category: category)
            }
            
            // 2. Directory discovery for caches, containers, and application support matching tokens
            let discoveryFolders: [(String, String)] = [
                ("\(self.home)/Library/Application Support", "Application Support"),
                ("/Library/Application Support", "System Application Support"),
                ("\(self.home)/Library/Caches", "Caches"),
                ("/Library/Caches", "System Caches"),
                ("\(self.home)/Library/Containers", "Containers"),
                ("\(self.home)/Library/Group Containers", "Group Containers"),
                ("\(self.home)/Library/Preferences", "Preferences"),
                ("\(self.home)/Library/Saved Application State", "Saved State"),
                ("\(self.home)/Library/WebKit", "WebKit"),
                ("\(self.home)/Library/HTTPStorages", "HTTP Storages"),
                ("\(self.home)/Library/Logs", "Logs"),
                ("/Library/Logs", "System Logs"),
                ("\(self.home)/Library/Application Scripts", "Application Scripts"),
                ("/Library/Audio/Apple Loops", "Audio Loops"),
                ("/Library/Audio/Apple Loops/Apple", "Audio Loops"),
                ("/Library/Audio/Plug-Ins", "Audio Plug-Ins"),
                ("\(self.home)/Library/Audio/Plug-Ins", "Audio Plug-Ins"),
                ("\(self.home)/Library/LaunchAgents", "Launch Agents"),
                ("/Library/LaunchAgents", "System Launch Agents")
            ]
            
            func matchesApp(_ name: String) -> Bool {
                let low = name.lowercased()
                for token in tokens {
                    if low == token { return true }
                    if low.hasPrefix(token + ".") || low.hasPrefix(token + "-") || low.hasPrefix(token + "_") || low.hasPrefix(token + " ") {
                        return true
                    }
                    if low.hasSuffix("." + token) || low.hasSuffix("-" + token) || low.hasSuffix("_" + token) {
                        return true
                    }
                    if token.count >= 4 && low.contains(token) {
                        return true
                    }
                }
                return false
            }
            
            let vendorFolders = ["google", "mozilla", "microsoft", "adobe", "apple", "ilifemediabrowser"]
            
            for (baseDir, category) in discoveryFolders {
                if let entries = try? fm.contentsOfDirectory(atPath: baseDir) {
                    for entry in entries {
                        let low = entry.lowercased()
                        if matchesApp(entry) {
                            let full = (baseDir as NSString).appendingPathComponent(entry)
                            addIfValid(path: full, category: category)
                        } else if vendorFolders.contains(low) {
                            // Check subdirectories of vendor folders (e.g. Google/Chrome, Mozilla/Firefox)
                            let subDir = (baseDir as NSString).appendingPathComponent(entry)
                            if let subEntries = try? fm.contentsOfDirectory(atPath: subDir) {
                                for sub in subEntries {
                                    if matchesApp(sub) {
                                        let fullSub = (subDir as NSString).appendingPathComponent(sub)
                                        addIfValid(path: fullSub, category: category)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // Keep the Application bundle itself pinned at index 0 (AppCleaner standard)
            let appCategoryName = L10n.tr("Application", "Uygulama")
            let appItems = foundLeftovers.filter { $0.category == appCategoryName || $0.path == appURL.path }
            var leftoverItems = foundLeftovers.filter { $0.category != appCategoryName && $0.path != appURL.path }
            leftoverItems.sort { $0.sizeBytes > $1.sizeBytes }
            foundLeftovers = appItems + leftoverItems
            
            let appInfo = ScannedAppInfo(
                appName: appName,
                bundleId: resolvedBundleId,
                appURL: appURL,
                leftovers: foundLeftovers
            )
            
            DispatchQueue.main.async {
                self.activeAppScan = appInfo
                self.isScanningApp = false
                SoundManager.shared.play(.action)
            }
        }
    }
    
    // MARK: - Robust File & App Removal (Trash / Delete)
    private func deleteOrTrashItem(path: String) -> Bool {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else { return true }
        guard isLeftoverPathSafe(path) else { return false }
        
        let trashDir = "\(self.home)/.Trash"
        let fileName = (path as NSString).lastPathComponent
        
        func generateTrashDestination() -> String {
            var dest = "\(trashDir)/\(fileName)"
            if fm.fileExists(atPath: dest) {
                let ts = Int(Date().timeIntervalSince1970)
                let nameWithoutExt = (fileName as NSString).deletingPathExtension
                let ext = (fileName as NSString).pathExtension
                dest = ext.isEmpty ? "\(trashDir)/\(nameWithoutExt)_\(ts)" : "\(trashDir)/\(nameWithoutExt)_\(ts).\(ext)"
            }
            return dest
        }
        
        // Tier 1: Direct move into user's ~/.Trash folder
        let dest = generateTrashDestination()
        do {
            try fm.moveItem(atPath: path, toPath: dest)
            return true
        } catch {}
        
        // Tier 2: Shell /bin/mv into ~/.Trash
        let mvProc = Process()
        mvProc.executableURL = URL(fileURLWithPath: "/bin/mv")
        mvProc.arguments = ["-f", path, dest]
        try? mvProc.run()
        mvProc.waitUntilExit()
        if !fm.fileExists(atPath: path) { return true }
        
        // Tier 3: AppleScript via Finder (Native macOS Trash)
        let escapedPath = path.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let finderScript = """
        tell application "Finder"
            if exists (POSIX file "\(escapedPath)") then
                delete (POSIX file "\(escapedPath)")
            end if
        end tell
        """
        if let script = NSAppleScript(source: finderScript) {
            var err: NSDictionary?
            script.executeAndReturnError(&err)
            if err == nil && !fm.fileExists(atPath: path) { return true }
        }
        
        // Tier 4: FileManager.default.trashItem
        let url = URL(fileURLWithPath: path)
        var resultingURL: NSURL?
        do {
            try fm.trashItem(at: url, resultingItemURL: &resultingURL)
            return true
        } catch {}
        
        // Tier 5: Direct FileManager.default.removeItem
        do {
            try fm.removeItem(atPath: path)
            return true
        } catch {}
        
        // Tier 6: Shell /bin/rm -rf
        let rmProc = Process()
        rmProc.executableURL = URL(fileURLWithPath: "/bin/rm")
        rmProc.arguments = ["-rf", path]
        try? rmProc.run()
        rmProc.waitUntilExit()
        if !fm.fileExists(atPath: path) { return true }
        
        return false
    }
    
    // Tier 7: Privileged batch deletion for items requiring administrator privileges (e.g. /Applications/*.app)
    private func deletePrivilegedBatch(paths: [String]) -> Bool {
        let fm = FileManager.default
        let existing = paths.filter { fm.fileExists(atPath: $0) && isLeftoverPathSafe($0) }
        guard !existing.isEmpty else { return true }
        
        let trashDir = "\(self.home)/.Trash"
        let commands = existing.map { p -> String in
            let esc = p.replacingOccurrences(of: "'", with: "'\\''")
            let base = (p as NSString).lastPathComponent.replacingOccurrences(of: "'", with: "'\\''")
            return "TARGET=\"\(trashDir)/\(base)\" ; if [ -e \"$TARGET\" ]; then TARGET=\"\(trashDir)/\(base)_$(date +%s)\" ; fi ; mv -f '\(esc)' \"$TARGET\" 2>/dev/null || rm -rf '\(esc)'"
        }.joined(separator: " ; ")
        
        let escapedCommands = commands.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let adminScript = """
        do shell script "\(escapedCommands)" with administrator privileges
        """
        
        if let script = NSAppleScript(source: adminScript) {
            var err: NSDictionary?
            script.executeAndReturnError(&err)
            if err == nil {
                return true
            }
        }
        return false
    }

    public func cleanAppLeftovers() {
        guard let scan = activeAppScan, !scan.leftovers.isEmpty else { return }
        
        let toRemove = scan.leftovers.filter { $0.isSelected }
        guard !toRemove.isEmpty else { return }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let fm = FileManager.default
            var totalFreed: UInt64 = 0
            var unremovedItems: [AppLeftoverItem] = []
            
            // Gracefully terminate the app if it is currently running to release file locks
            if !scan.bundleId.isEmpty {
                let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: scan.bundleId)
                for app in runningApps {
                    app.terminate()
                }
                if !runningApps.isEmpty {
                    Thread.sleep(forTimeInterval: 0.5)
                }
            }
            
            // Phase 1: Try standard non-privileged tiers on all selected items
            for item in toRemove {
                let path = item.path
                guard self.isLeftoverPathSafe(path) else { continue }
                
                let size = item.sizeBytes > 0 ? item.sizeBytes : self.calculateFolderSize(path: path)
                
                if self.deleteOrTrashItem(path: path) {
                    totalFreed += size
                } else if fm.fileExists(atPath: path) {
                    unremovedItems.append(item)
                }
            }
            
            // Phase 2: If privileged items (e.g. /Applications/*.app) remain, prompt once with admin privileges
            if !unremovedItems.isEmpty {
                let paths = unremovedItems.map { $0.path }
                if self.deletePrivilegedBatch(paths: paths) {
                    for item in unremovedItems {
                        if !fm.fileExists(atPath: item.path) {
                            let size = item.sizeBytes > 0 ? item.sizeBytes : self.calculateFolderSize(path: item.path)
                            totalFreed += size
                        }
                    }
                }
            }
            
            DispatchQueue.main.async {
                let bcf = ByteCountFormatter()
                bcf.countStyle = .file
                let freedStr = bcf.string(fromByteCount: Int64(totalFreed))
                
                if totalFreed > 0 {
                    self.appCleanSuccessMessage = L10n.tr("Successfully moved \(freedStr) to Trash!", "\(freedStr) başarıyla Çöp Sepeti'ne taşındı!")
                    self.activeAppScan = nil
                    SoundManager.shared.play(.success)
                } else {
                    self.appCleanSuccessMessage = L10n.tr("Could not delete selected items. Please check permissions.", "Seçilen öğeler silinemedi. Lütfen sistem izinlerini kontrol edin.")
                    SoundManager.shared.play(.pop)
                }
            }
        }
    }
    
    public func toggleAppLeftover(id: UUID) {
        guard var scan = activeAppScan else { return }
        if let idx = scan.leftovers.firstIndex(where: { $0.id == id }) {
            scan.leftovers[idx].isSelected.toggle()
            activeAppScan = scan
        }
    }
    
    public func clearAppScan() {
        activeAppScan = nil
        appCleanSuccessMessage = nil
    }
    
    // Strict Safety Guard for Leftover Paths
    private func isLeftoverPathSafe(_ path: String) -> Bool {
        let standardized = (path as NSString).standardizingPath
        
        // 1. FORBIDDEN root and personal directories
        let forbidden = [
            self.home,
            "\(self.home)/Desktop",
            "\(self.home)/Documents",
            "\(self.home)/Downloads",
            "\(self.home)/Pictures",
            "\(self.home)/Movies",
            "\(self.home)/Music",
            "\(self.home)/.ssh",
            "\(self.home)/.gnupg",
            "\(self.home)/Library",
            "\(self.home)/Library/Keychains",
            "\(self.home)/Library/Application Support",
            "\(self.home)/Library/Caches",
            "\(self.home)/Library/Preferences",
            "\(self.home)/Library/Containers",
            "\(self.home)/Library/Group Containers",
            "/",
            "/System",
            "/Library",
            "/Library/Application Support",
            "/Library/Caches",
            "/Library/Preferences",
            "/Library/Audio",
            "/Library/Audio/Apple Loops",
            "/Applications",
            "/usr",
            "/bin",
            "/var",
            "/etc"
        ]
        
        for forb in forbidden {
            if standardized == forb {
                return false
            }
        }
        
        // 2. Allow target .app bundles in Applications or User directories (AppCleaner standard)
        // Must NEVER allow system apps, Palantir itself, or bare directories
        if standardized.hasSuffix(".app") {
            if standardized.hasPrefix("/System/") { return false }
            if standardized.contains("ArkenStone.app") || standardized.contains("Arken.app") || standardized.contains("Palantir.app") { return false }
            if standardized.hasPrefix("/Applications/") ||
               standardized.hasPrefix("\(self.home)/Applications/") ||
               standardized.hasPrefix("\(self.home)/Desktop/") ||
               standardized.hasPrefix("\(self.home)/Downloads/") {
                return true
            }
        }
        
        // 3. Must be located inside legitimate leftover locations:
        let allowedPrefixes = [
            "\(self.home)/Library/Application Support/",
            "\(self.home)/Library/Caches/",
            "\(self.home)/Library/Containers/",
            "\(self.home)/Library/Group Containers/",
            "\(self.home)/Library/Preferences/",
            "\(self.home)/Library/Saved Application State/",
            "\(self.home)/Library/WebKit/",
            "\(self.home)/Library/HTTPStorages/",
            "\(self.home)/Library/Logs/",
            "\(self.home)/Library/Application Scripts/",
            "\(self.home)/Library/Audio/",
            "\(self.home)/Music/Audio Music Apps/",
            "\(self.home)/Library/LaunchAgents/",
            "/Library/Application Support/",
            "/Library/Caches/",
            "/Library/Audio/Apple Loops/",
            "/Library/Audio/Plug-Ins/",
            "/Library/Preferences/",
            "/Library/Logs/",
            "/Library/LaunchAgents/"
        ]
        
        for allowed in allowedPrefixes {
            if standardized.hasPrefix(allowed) && standardized != allowed {
                return true
            }
        }
        
        return false
    }
    
    private var activePanelDelegate: NSOpenSavePanelDelegate?
    
    public func selectAppViaDialog() {
        NSApp.activate(ignoringOtherApps: true)
        
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true // Allow selecting application packages
        panel.treatsFilePackagesAsDirectories = false // Treat .app as atomic file
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = L10n.tr("Select App", "Uygulama Seç")
        panel.message = L10n.tr("Select any application (.app) to clean leftover files", "Kalıntılarını temizlemek istediğiniz herhangi bir uygulamayı (.app) seçin")
        
        // Allow all items at AppKit level so third-party apps, symlinks, and packages are never grayed out
        panel.allowedContentTypes = [.item]
        
        let delegate = AppOpenPanelDelegate()
        self.activePanelDelegate = delegate
        panel.delegate = delegate
        
        if panel.runModal() == .OK, let rawUrl = panel.url {
            let url = rawUrl.resolvingSymlinksInPath()
            if url.pathExtension.lowercased() == "app" || rawUrl.pathExtension.lowercased() == "app" {
                scanApp(url: url)
            }
        }
        self.activePanelDelegate = nil
    }
    
    private func calculateFolderSize(path: String) -> UInt64 {
        var isDir: ObjCBool = false
        if !FileManager.default.fileExists(atPath: path, isDirectory: &isDir) {
            return 0
        }
        if !isDir.boolValue {
            let attrs = try? FileManager.default.attributesOfItem(atPath: path)
            return attrs?[.size] as? UInt64 ?? 0
        }
        
        let url = URL(fileURLWithPath: path)
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .totalFileAllocatedSizeKey, .isSymbolicLinkKey],
            options: [] // Do NOT skip hidden files or subpackages!
        ) else { return 0 }
        
        var total: UInt64 = 0
        for case let fileURL as URL in enumerator {
            if let attrs = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .totalFileAllocatedSizeKey, .isSymbolicLinkKey]) {
                // NEVER follow symlinks into external user directories
                if attrs.isSymbolicLink == true { continue }
                let size = UInt64(max(attrs.fileSize ?? 0, attrs.totalFileAllocatedSize ?? 0))
                total += size
            }
        }
        return total
    }
}

// MARK: - App Selection Panel Delegate
final class AppOpenPanelDelegate: NSObject, NSOpenSavePanelDelegate {
    func panel(_ sender: Any, shouldEnable url: URL) -> Bool {
        // Direct .app check
        if url.pathExtension.lowercased() == "app" {
            return true
        }
        
        // Resolve aliases / symlinks
        let resolved = url.resolvingSymlinksInPath()
        if resolved.pathExtension.lowercased() == "app" {
            return true
        }
        
        // Allow directory navigation to browse into folders
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: resolved.path, isDirectory: &isDir), isDir.boolValue {
            let ext = resolved.pathExtension.lowercased()
            // Do not dive into non-app bundles or packages
            if ext == "framework" || ext == "bundle" || ext == "plugin" || ext == "kext" || ext == "pkg" {
                return false
            }
            return true
        }
        
        return false
    }
    
    func panel(_ sender: Any, validate url: URL) throws {
        let resolved = url.resolvingSymlinksInPath()
        if resolved.pathExtension.lowercased() != "app" && url.pathExtension.lowercased() != "app" {
            throw NSError(
                domain: "ArkenStone",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: L10n.tr("Please select an application (.app) file.", "Lütfen bir uygulama (.app) dosyası seçin.")]
            )
        }
    }
}
