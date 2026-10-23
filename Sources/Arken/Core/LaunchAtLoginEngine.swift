import Foundation
import Combine
import ServiceManagement

public class LaunchAtLoginEngine: ObservableObject {
    public static let shared = LaunchAtLoginEngine()
    
    private let agentId = "com.citadel.arkenstone"
    private var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")
            .appendingPathComponent("\(agentId).plist")
    }
    
    private var legacyPlistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")
            .appendingPathComponent("com.citadel.palantir.plist")
    }
    
    @Published public var isEnabled: Bool = false
    
    public init() {
        checkStatus()
        autoUpdatePathIfNeeded()
    }
    
    public func checkStatus() {
        var active = false
        if #available(macOS 13.0, *) {
            let status = SMAppService.mainApp.status
            if status == .enabled {
                active = true
            }
        }
        if !active {
            active = FileManager.default.fileExists(atPath: plistURL.path)
        }
        
        DispatchQueue.main.async {
            self.isEnabled = active
        }
    }
    
    public func toggle() {
        setEnabled(!isEnabled)
    }
    
    public func setEnabled(_ enable: Bool) {
        if enable {
            enableLaunchAtLogin()
        } else {
            disableLaunchAtLogin()
        }
        checkStatus()
    }
    
    private func enableLaunchAtLogin() {
        var registeredViaService = false
        
        // 1. Primary: Modern Apple SMAppService (macOS 13+ Ventura, Sonoma, Sequoia)
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            do {
                try service.register()
                registeredViaService = (service.status == .enabled)
            } catch {
                // If unnotarized or dev build, fallback gracefully
                print("SMAppService notice: \(error.localizedDescription). Using LaunchAgent fallback.")
            }
        }
        
        // 2. Fallback: LaunchAgent Plist (100% reliable across all environments)
        if !registeredViaService {
            writeLaunchAgentPlist()
        } else {
            removeLaunchAgentPlist()
        }
    }
    
    private func disableLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            try? SMAppService.mainApp.unregister()
        }
        removeLaunchAgentPlist()
    }
    
    private func writeLaunchAgentPlist() {
        let launchAgentsDir = plistURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: launchAgentsDir, withIntermediateDirectories: true)
        
        let execPath = Bundle.main.executableURL?.path ?? Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/ArkenStone").path
        
        let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(agentId)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(execPath)</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>ProcessType</key>
            <string>Interactive</string>
        </dict>
        </plist>
        """
        
        do {
            try plistContent.write(to: plistURL, atomically: true, encoding: .utf8)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            process.arguments = ["load", plistURL.path]
            try? process.run()
            process.waitUntilExit()
        } catch {
            print("Failed to write LaunchAgent plist: \(error)")
        }
    }
    
    private func removeLaunchAgentPlist() {
        if FileManager.default.fileExists(atPath: plistURL.path) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            process.arguments = ["unload", plistURL.path]
            try? process.run()
            process.waitUntilExit()
            try? FileManager.default.removeItem(at: plistURL)
        }
    }
    
    private func autoUpdatePathIfNeeded() {
        // Clean up legacy plist if present
        if FileManager.default.fileExists(atPath: legacyPlistURL.path) {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            proc.arguments = ["unload", legacyPlistURL.path]
            try? proc.run()
            proc.waitUntilExit()
            try? FileManager.default.removeItem(at: legacyPlistURL)
        }
        
        guard FileManager.default.fileExists(atPath: plistURL.path) else { return }
        
        let currentExecPath = Bundle.main.executableURL?.path ?? Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/ArkenStone").path
        if let data = try? Data(contentsOf: plistURL),
           let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
           let args = plist["ProgramArguments"] as? [String],
           let existingPath = args.first,
           existingPath != currentExecPath {
            // Path changed (e.g. app moved to /Applications) - re-generate plist with new path
            writeLaunchAgentPlist()
        }
    }
}
