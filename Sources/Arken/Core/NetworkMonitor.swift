import Foundation
import Darwin
import AppKit

public struct NetworkSnapshot {
    public var downloadSpeedBytesPerSec: Double = 0.0
    public var uploadSpeedBytesPerSec: Double = 0.0
    public var totalDownloadedBytes: UInt64 = 0
    public var totalUploadedBytes: UInt64 = 0
    public var downloadSpeedFormatted: String = "0 KB/s"
    public var uploadSpeedFormatted: String = "0 KB/s"
    public var activeInterface: String = "en0"
    public var ipAddress: String = "127.0.0.1"
    public var downloadHistory: [Double] = []
    public var uploadHistory: [Double] = []
}

public class NetworkMonitor {
    private var lastInBytes: UInt64 = 0
    private var lastOutBytes: UInt64 = 0
    private var lastTimestamp: TimeInterval = 0
    private var lastIPCheckTimestamp: TimeInterval = 0
    
    private var downloadHistoryBuffer: [Double] = []
    private var uploadHistoryBuffer: [Double] = []
    private let maxHistory = 30
    private var wakeObserver: NSObjectProtocol?
    
    public private(set) var snapshot = NetworkSnapshot()
    
    public init() {
        let now = Date().timeIntervalSince1970
        let initial = getNetworkBytes()
        self.lastInBytes = initial.ibytes
        self.lastOutBytes = initial.obytes
        self.lastTimestamp = now
        self.lastIPCheckTimestamp = now
        self.snapshot.totalDownloadedBytes = initial.ibytes
        self.snapshot.totalUploadedBytes = initial.obytes
        
        let netInfo = getPrimaryInterfaceAndIP()
        self.snapshot.ipAddress = netInfo.ip
        self.snapshot.activeInterface = netInfo.interface
        
        // Listen for system wake-up to prevent huge delta speed spikes
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.resetAfterWake()
        }
        
        update()
    }
    
    deinit {
        if let observer = wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }
    
    public func resetAfterWake() {
        let now = Date().timeIntervalSince1970
        let current = getNetworkBytes()
        lastInBytes = current.ibytes
        lastOutBytes = current.obytes
        lastTimestamp = now
        lastIPCheckTimestamp = now
        snapshot.downloadSpeedBytesPerSec = 0.0
        snapshot.uploadSpeedBytesPerSec = 0.0
        snapshot.downloadSpeedFormatted = "0 KB/s"
        snapshot.uploadSpeedFormatted = "0 KB/s"
        
        // Update IP and active interface at a relaxed 10-second interval
        if now - lastIPCheckTimestamp >= 10.0 {
            lastIPCheckTimestamp = now
            let netInfo = getPrimaryInterfaceAndIP()
            snapshot.ipAddress = netInfo.ip
            snapshot.activeInterface = netInfo.interface
        }
    }
    
    public func update() {
        let current = getNetworkBytes()
        let now = Date().timeIntervalSince1970
        let timeDelta = now - lastTimestamp
        
        // Prevent speed spikes after sleep, freeze, or large time gaps
        if timeDelta > 5.0 {
            lastInBytes = current.ibytes
            lastOutBytes = current.obytes
            lastTimestamp = now
            return
        }
        
        guard timeDelta > 0.2 else { return }
        
        var inDelta: Double = 0.0
        var outDelta: Double = 0.0
        
        if current.ibytes >= lastInBytes {
            inDelta = Double(current.ibytes - lastInBytes) / timeDelta
        }
        if current.obytes >= lastOutBytes {
            outDelta = Double(current.obytes - lastOutBytes) / timeDelta
        }
        
        lastInBytes = current.ibytes
        lastOutBytes = current.obytes
        lastTimestamp = now
        
        snapshot.downloadSpeedBytesPerSec = inDelta
        snapshot.uploadSpeedBytesPerSec = outDelta
        snapshot.totalDownloadedBytes = current.ibytes
        snapshot.totalUploadedBytes = current.obytes
        snapshot.downloadSpeedFormatted = formatSpeed(inDelta)
        snapshot.uploadSpeedFormatted = formatSpeed(outDelta)
        
        // Update IP and active interface at a relaxed 10-second interval
        if now - lastIPCheckTimestamp >= 10.0 {
            lastIPCheckTimestamp = now
            let netInfo = getPrimaryInterfaceAndIP()
            snapshot.ipAddress = netInfo.ip
            snapshot.activeInterface = netInfo.interface
        }
        
        downloadHistoryBuffer.append(inDelta)
        if downloadHistoryBuffer.count > maxHistory {
            downloadHistoryBuffer.removeFirst()
        }
        
        uploadHistoryBuffer.append(outDelta)
        if uploadHistoryBuffer.count > maxHistory {
            uploadHistoryBuffer.removeFirst()
        }
        
        snapshot.downloadHistory = downloadHistoryBuffer
        snapshot.uploadHistory = uploadHistoryBuffer
    }
    
    private func getNetworkBytes() -> (ibytes: UInt64, obytes: UInt64) {
        var ifap: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifap) == 0, let first = ifap else { return (0, 0) }
        defer { freeifaddrs(ifap) }
        
        var inBytes: UInt64 = 0
        var outBytes: UInt64 = 0
        
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let cur = ptr {
            let name = String(cString: cur.pointee.ifa_name)
            let family = cur.pointee.ifa_addr.pointee.sa_family
            
            if family == UInt8(AF_LINK), let data = cur.pointee.ifa_data {
                let ifData = data.assumingMemoryBound(to: if_data.self)
                // Filter loopback and point-to-point non-physical interfaces
                if !name.hasPrefix("lo") && !name.hasPrefix("utun") {
                    inBytes += UInt64(ifData.pointee.ifi_ibytes)
                    outBytes += UInt64(ifData.pointee.ifi_obytes)
                }
            }
            ptr = cur.pointee.ifa_next
        }
        return (inBytes, outBytes)
    }
    
    private func getPrimaryInterfaceAndIP() -> (ip: String, interface: String) {
        var ifap: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifap) == 0, let first = ifap else {
            return (L10n.tr("Not Connected", "Bağlı Değil"), "en0")
        }
        defer { freeifaddrs(ifap) }
        
        var candidateIP: String?
        var candidateInterface: String?
        
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let cur = ptr {
            let flags = Int32(cur.pointee.ifa_flags)
            let isUpAndRunning = (flags & (IFF_UP | IFF_RUNNING)) == (IFF_UP | IFF_RUNNING)
            let isLoopback = (flags & IFF_LOOPBACK) != 0
            
            if isUpAndRunning && !isLoopback, let addrPtr = cur.pointee.ifa_addr {
                let name = String(cString: cur.pointee.ifa_name)
                let family = addrPtr.pointee.sa_family
                
                // Exclude virtual / vpn / airdrop / bridge / docker interfaces
                let isVirtual = name.hasPrefix("lo") || name.hasPrefix("utun") ||
                                name.hasPrefix("awdl") || name.hasPrefix("llw") ||
                                name.hasPrefix("bridge") || name.hasPrefix("gif") ||
                                name.hasPrefix("stf") || name.hasPrefix("tailscale") ||
                                name.hasPrefix("wg") || name.hasPrefix("tun") ||
                                name.hasPrefix("tap") || name.hasPrefix("docker") ||
                                name.hasPrefix("veth") || name.hasPrefix("p2p")
                
                if !isVirtual && family == UInt8(AF_INET) {
                    var addr = addrPtr.pointee
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(&addr, socklen_t(addr.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                        let ip = String(cString: hostname)
                        // Ignore self-assigned 169.254.x.x link-local and 127.x.x.x
                        if !ip.hasPrefix("169.254.") && !ip.hasPrefix("127.") {
                            // Prioritize real LAN IP addresses (192.168.x, 10.x, 172.16-31.x)
                            if ip.hasPrefix("192.168.") || ip.hasPrefix("10.") || ip.hasPrefix("172.") {
                                return (ip, name)
                            } else if candidateIP == nil {
                                candidateIP = ip
                                candidateInterface = name
                            }
                        }
                    }
                }
            }
            ptr = cur.pointee.ifa_next
        }
        
        if let ip = candidateIP, let iface = candidateInterface {
            return (ip, iface)
        }
        return (L10n.tr("Not Connected", "Bağlı Değil"), "-")
    }
    
    private func formatSpeed(_ bytesPerSec: Double) -> String {
        let kb = bytesPerSec / 1024.0
        if kb > 1024.0 {
            return String(format: "%.1f MB/s", kb / 1024.0)
        } else if kb > 1.0 {
            return String(format: "%.0f KB/s", kb)
        } else {
            return "0 KB/s"
        }
    }
}
