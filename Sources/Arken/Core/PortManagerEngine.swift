import Foundation
import Darwin
import Combine
import AppKit

public struct ListeningPortItem: Identifiable, Equatable {
    public var id: String { "\(port)_\(pid)" }
    public let port: Int
    public let processName: String
    public let pid: Int32
    public let protocolType: String
    public var isKilled: Bool = false
    
    private static let devPorts: Set<Int> = [
        3000, 3001, 3002, 4000, 4200, 5000, 5001, 5173, 5174, 8000, 8080, 8888, 9000, 9090, 27017, 5432, 3306, 6379, 11434
    ]
    
    public var isCommonDevPort: Bool {
        Self.devPorts.contains(port)
    }
}

public class PortManagerEngine: ObservableObject {
    public static let shared = PortManagerEngine()
    
    @Published public var ports: [ListeningPortItem] = []
    @Published public var isScanning: Bool = false
    @Published public var statusMessage: String = L10n.tr("Scanning listening ports...", "Portlar taranıyor...")
    @Published public var searchQuery: String = ""
    
    public var filteredPorts: [ListeningPortItem] {
        let q = searchQuery.trimmingCharacters(in: .whitespaces).lowercased()
        if q.isEmpty {
            return ports
        }
        return ports.filter { item in
            String(item.port).contains(q) ||
            item.processName.lowercased().contains(q) ||
            String(item.pid).contains(q) ||
            item.protocolType.lowercased().contains(q)
        }
    }
    
    public init() {
        scanPorts()
    }
    
    public func scanPorts() {
        guard !isScanning else { return }
        isScanning = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
            process.arguments = ["-F", "pcnPt", "-iTCP", "-sTCP:LISTEN", "-n", "-P"]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            
            var items: [ListeningPortItem] = []
            
            do {
                try process.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                
                if let output = String(data: data, encoding: .utf8) {
                    items = self.parseLsofOutput(output)
                }
            } catch {
                // If lsof fails, continue gracefully
            }
            
            DispatchQueue.main.async {
                self.ports = items.sorted {
                    if $0.isCommonDevPort != $1.isCommonDevPort {
                        return $0.isCommonDevPort && !$1.isCommonDevPort
                    }
                    return $0.port < $1.port
                }
                self.isScanning = false
                self.statusMessage = L10n.tr("\(items.count) active ports listening", "\(items.count) aktif port dinleniyor")
            }
        }
    }
    
    public func killPortProcess(item: ListeningPortItem) {
        let pid = item.pid
        guard pid > 1 else { return }
        
        Darwin.errno = 0
        let termRes = kill(pid, SIGTERM)
        if termRes != 0 {
            if Darwin.errno == EPERM {
                DispatchQueue.main.async {
                    self.statusMessage = L10n.tr(
                        "Permission denied: Process owned by root/system (PID \(pid))",
                        "Yetki reddedildi: Root/Sistem süreci (PID \(pid))"
                    )
                    SoundManager.shared.play(.warning)
                }
                return
            }
            
            Darwin.errno = 0
            let killRes = kill(pid, SIGKILL)
            if killRes != 0 && Darwin.errno == EPERM {
                DispatchQueue.main.async {
                    self.statusMessage = L10n.tr(
                        "Permission denied: Process owned by root/system (PID \(pid))",
                        "Yetki reddedildi: Root/Sistem süreci (PID \(pid))"
                    )
                    SoundManager.shared.play(.warning)
                }
                return
            }
        }
        
        // Ensure stubborn/hung processes (e.g. node, docker, python) actually die
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.4) {
            if kill(pid, 0) == 0 {
                _ = kill(pid, SIGKILL)
            }
        }
        
        DispatchQueue.main.async {
            if let idx = self.ports.firstIndex(where: { $0.id == item.id }) {
                self.ports[idx].isKilled = true
            }
            self.statusMessage = L10n.tr("Port \(item.port) released (PID \(pid) killed)", "Port \(item.port) serbest bırakıldı (PID \(pid) sonlandırıldı)")
            SoundManager.shared.play(.pop)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.scanPorts()
        }
    }
    
    private func parseLsofOutput(_ output: String) -> [ListeningPortItem] {
        var results: [ListeningPortItem] = []
        var seenKeys = Set<String>()
        
        var currentPid: Int32?
        var currentCmd: String = ""
        var currentProto: String = "TCP"
        
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            guard !line.isEmpty else { continue }
            let prefix = line.first!
            let val = String(line.dropFirst())
            
            switch prefix {
            case "p":
                currentPid = Int32(val)
                currentCmd = ""
                currentProto = "TCP"
            case "c":
                currentCmd = val
            case "t":
                currentProto = val
            case "P":
                if !val.isEmpty { currentProto = val }
            case "n":
                if let pid = currentPid, let colonIdx = val.lastIndex(of: ":") {
                    let portStr = String(val[val.index(after: colonIdx)...])
                    if let portNum = Int(portStr) {
                        let key = "\(portNum)_\(pid)"
                        if !seenKeys.contains(key) {
                            seenKeys.insert(key)
                            results.append(ListeningPortItem(
                                port: portNum,
                                processName: currentCmd.isEmpty ? "Unknown" : currentCmd,
                                pid: pid,
                                protocolType: currentProto
                            ))
                        }
                    }
                }
            default:
                break
            }
        }
        return results
    }
}
