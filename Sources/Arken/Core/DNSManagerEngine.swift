import Foundation
import AppKit
import Combine

public enum DNSPreset: String, CaseIterable, Identifiable {
    case dhcp = "dhcp"
    case cloudflare = "cloudflare"
    case google = "google"
    case quad9 = "quad9"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .dhcp: return L10n.tr("Default (Automatic DHCP)", "Varsayılan (Otomatik DHCP)")
        case .cloudflare: return "Cloudflare (1.1.1.1)"
        case .google: return "Google (8.8.8.8)"
        case .quad9: return "Quad9 (9.9.9.9)"
        }
    }
    
    public var shortTitle: String {
        switch self {
        case .dhcp: return L10n.tr("DHCP", "DHCP")
        case .cloudflare: return "Cloudflare"
        case .google: return "Google"
        case .quad9: return "Quad9"
        }
    }
    
    public var servers: [String] {
        switch self {
        case .dhcp: return []
        case .cloudflare: return ["1.1.1.1", "1.0.0.1"]
        case .google: return ["8.8.8.8", "8.8.4.4"]
        case .quad9: return ["9.9.9.9", "149.112.112.112"]
        }
    }
}

public class DNSManagerEngine: ObservableObject {
    public static let shared = DNSManagerEngine()
    
    @Published public var activeDNS: DNSPreset = .dhcp
    @Published public var currentDNSDisplay: String = L10n.tr("Detecting...", "Algılanıyor...")
    @Published public var isFlushing: Bool = false
    @Published public var isSwitching: Bool = false
    @Published public var statusMessage: String?
    
    private var cachedService: String = "Wi-Fi"
    
    private init() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.detectCurrentDNS()
        }
    }
    
    public func flushCache() {
        guard !isFlushing else { return }
        isFlushing = true
        statusMessage = L10n.tr("Flushing DNS cache...", "DNS önbelleği sıfırlanıyor...")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let flushProcess = Process()
            flushProcess.executableURL = URL(fileURLWithPath: "/usr/bin/dscacheutil")
            flushProcess.arguments = ["-flushcache"]
            try? flushProcess.run()
            flushProcess.waitUntilExit()
            
            let killProcess = Process()
            killProcess.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            killProcess.arguments = ["-HUP", "mDNSResponder"]
            try? killProcess.run()
            killProcess.waitUntilExit()
            
            DispatchQueue.main.async {
                self.isFlushing = false
                self.statusMessage = L10n.tr("DNS cache flushed successfully!", "DNS önbelleği başarıyla temizlendi!")
                SoundManager.shared.play(.action)
            }
        }
    }
    
    public func switchDNS(to preset: DNSPreset) {
        guard !isSwitching else { return }
        isSwitching = true
        statusMessage = L10n.tr("Applying DNS settings...", "DNS ayarları uygulanıyor...")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let service = self.getActiveNetworkService()
            
            let args: [String]
            if preset == .dhcp {
                args = ["-setdnsservers", service, "Empty"]
            } else {
                args = ["-setdnsservers", service] + preset.servers
            }
            
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
            proc.arguments = args
            try? proc.run()
            proc.waitUntilExit()
            
            var success = (proc.terminationStatus == 0)
            
            if !success {
                let shellCmd = "/usr/sbin/networksetup " + args.map { "\"\($0)\"" }.joined(separator: " ")
                let script = "do shell script \"\(shellCmd)\" with administrator privileges"
                var error: NSDictionary?
                if let scriptObj = NSAppleScript(source: script) {
                    scriptObj.executeAndReturnError(&error)
                    success = (error == nil)
                }
            }
            
            if success {
                let flushProc = Process()
                flushProc.executableURL = URL(fileURLWithPath: "/usr/bin/dscacheutil")
                flushProc.arguments = ["-flushcache"]
                try? flushProc.run()
                flushProc.waitUntilExit()
            }
            
            DispatchQueue.main.async {
                self.isSwitching = false
                if success {
                    self.activeDNS = preset
                    self.detectCurrentDNS()
                    self.statusMessage = L10n.tr("DNS switched to \(preset.shortTitle)", "DNS \(preset.shortTitle) olarak güncellendi")
                    SoundManager.shared.play(.success)
                } else {
                    self.statusMessage = L10n.tr("Failed to change DNS (Authorization required)", "DNS değiştirilemedi (Yönetici yetkisi gerekli)")
                    SoundManager.shared.play(.warning)
                }
            }
        }
    }
    
    public func detectCurrentDNS() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let service = self.getActiveNetworkService()
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
            proc.arguments = ["-getdnsservers", service]
            let pipe = Pipe()
            proc.standardOutput = pipe
            try? proc.run()
            proc.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            DispatchQueue.main.async {
                if output.contains("aren't any DNS") || output.isEmpty {
                    self.activeDNS = .dhcp
                    self.currentDNSDisplay = L10n.tr("Automatic (DHCP)", "Otomatik (DHCP)")
                } else if output.contains("1.1.1.1") {
                    self.activeDNS = .cloudflare
                    self.currentDNSDisplay = "Cloudflare (1.1.1.1)"
                } else if output.contains("8.8.8.8") {
                    self.activeDNS = .google
                    self.currentDNSDisplay = "Google (8.8.8.8)"
                } else if output.contains("9.9.9.9") {
                    self.activeDNS = .quad9
                    self.currentDNSDisplay = "Quad9 (9.9.9.9)"
                } else {
                    let firstLine = output.components(separatedBy: .newlines).first ?? output
                    self.currentDNSDisplay = "\(L10n.tr("Custom", "Özel")): \(firstLine)"
                }
            }
        }
    }
    
    public func getActiveNetworkService() -> String {
        // 1. Get default route device (e.g. en0, en5)
        var defaultDev: String?
        let routeProc = Process()
        routeProc.executableURL = URL(fileURLWithPath: "/sbin/route")
        routeProc.arguments = ["-n", "get", "default"]
        let rPipe = Pipe()
        routeProc.standardOutput = rPipe
        try? routeProc.run()
        routeProc.waitUntilExit()
        let rData = rPipe.fileHandleForReading.readDataToEndOfFile()
        let rOut = String(data: rData, encoding: .utf8) ?? ""
        for line in rOut.components(separatedBy: .newlines) {
            let parts = line.split(separator: ":").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2 && parts[0] == "interface" {
                defaultDev = parts[1]
                break
            }
        }
        
        // 2. Parse network service order to map device to service name
        let nsProc = Process()
        nsProc.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        nsProc.arguments = ["-listnetworkserviceorder"]
        let nsPipe = Pipe()
        nsProc.standardOutput = nsPipe
        try? nsProc.run()
        nsProc.waitUntilExit()
        let nsData = nsPipe.fileHandleForReading.readDataToEndOfFile()
        let nsOut = String(data: nsData, encoding: .utf8) ?? ""
        
        var currentService: String?
        var matchedService: String?
        var firstActiveService: String?
        
        for line in nsOut.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.starts(with: "(") && trimmed.contains(")") && !trimmed.contains("Hardware Port") {
                if let closingParen = trimmed.firstIndex(of: ")") {
                    let name = String(trimmed[trimmed.index(after: closingParen)...]).trimmingCharacters(in: .whitespaces)
                    if !name.starts(with: "*") {
                        currentService = name
                        if firstActiveService == nil { firstActiveService = name }
                    } else {
                        currentService = nil
                    }
                }
            } else if let svc = currentService, trimmed.contains("Device:"), let dev = defaultDev {
                if trimmed.contains("Device: \(dev)") || trimmed.contains("Device: \(dev),") || trimmed.hasSuffix("Device: \(dev))") {
                    matchedService = svc
                    break
                }
            }
        }
        
        let found = matchedService ?? firstActiveService ?? "Wi-Fi"
        self.cachedService = found
        return found
    }
}
