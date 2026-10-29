import Foundation
import AppKit

public struct AppInfo {
    public static let version = "0.8.6"
    public static let buildNumber = 86
    public static let name = "ArkenStone"
    public static let shortName = "Arken"
    public static let formattedVersion = "v0.8.6"
    public static let copyright = "© 2026 temetnos"
    
    /// Cached official app icon for in-app UI presentation
    public static let appIcon: NSImage = {
        // 1. Try bundled UI high-res icon
        if let path = Bundle.main.path(forResource: "AppIconUI", ofType: "png"),
           let img = NSImage(contentsOfFile: path) {
            return img
        }
        // 2. Try standard AppIcon names
        if let img = NSImage(named: "AppIconUI") ?? NSImage(named: "AppIcon") {
            return img
        }
        // 3. Try AppIcon.icns in bundle resources
        if let path = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
           let img = NSImage(contentsOfFile: path) {
            return img
        }
        // 4. Try loading from assets directory directly (development fallback)
        if let img = NSImage(contentsOfFile: "assets/AppIconUI.png") ?? NSImage(contentsOfFile: "assets/AppIcon.icns") {
            return img
        }
        // 5. Fallback to NSApp applicationIconImage
        return NSApplication.shared.applicationIconImage
    }()
}
