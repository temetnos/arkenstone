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
    
    public var isCommonDevPort: Bool {
        let devPorts = [3000, 3001, 5173, 8000, 8080, 5000, 5001, 4000, 4200, 8888, 9000, 27017, 5432, 3306, 6379]
        return devPorts.contains(port)
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
            process.arguments = ["-iTCP", "-sTCP:LISTEN", "-n", "-P"]
            
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
        
        // Send SIGTERM, fallback to SIGKILL if refused
        let termRes = kill(pid, SIGTERM)
        if termRes != 0 {
            _ = kill(pid, SIGKILL)
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
        
        let lines = output.components(separatedBy: .newlines)
        guard lines.count > 1 else { return [] }
        
        // Skip header line
        for line in lines.dropFirst() {
            let parts = line.split(whereSeparator: { $0.isWhitespace })
            // Columns: COMMAND, PID, USER, FD, TYPE, DEVICE, SIZE/OFF, NODE, NAME
            guard parts.count >= 9 else { continue }
            
            let cmd = String(parts[0])
            guard let pid = Int32(parts[1]) else { continue }
            let nameCol = String(parts[8]) // e.g. *:3000, 127.0.0.1:8080, [::]:5000
            
            if let colonIdx = nameCol.lastIndex(of: ":") {
                let portStr = String(nameCol[nameCol.index(after: colonIdx)...])
                if let portNum = Int(portStr) {
                    let key = "\(portNum)_\(pid)"
                    if !seenKeys.contains(key) {
                        seenKeys.insert(key)
                        results.append(ListeningPortItem(
                            port: portNum,
                            processName: cmd,
                            pid: pid,
                            protocolType: String(parts[4])
                        ))
                    }
                }
            }
        }
        return results
    }
}
