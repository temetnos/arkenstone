import Foundation
import Darwin

public struct ProcessUsageItem: Identifiable {
    public var id: Int32 { pid }
    public let pid: Int32
    public let name: String
    public let memoryBytes: UInt64
    public let memoryFormatted: String
    public let cpuPercent: Double // 0.0% to 100.0% * coreCount
    public let cpuFormatted: String
    public let cpuUserSeconds: Double
    
    public init(
        pid: Int32,
        name: String,
        memoryBytes: UInt64,
        memoryFormatted: String,
        cpuPercent: Double = 0.0,
        cpuFormatted: String = "0.0%",
        cpuUserSeconds: Double = 0.0
    ) {
        self.pid = pid
        self.name = name
        self.memoryBytes = memoryBytes
        self.memoryFormatted = memoryFormatted
        self.cpuPercent = cpuPercent
        self.cpuFormatted = cpuFormatted
        self.cpuUserSeconds = cpuUserSeconds
    }
}

public class ProcessMonitor {
    private struct PreviousCpuTime {
        var totalNs: UInt64
        var timestamp: TimeInterval
    }
    
    private var previousTimes: [Int32: PreviousCpuTime] = [:]
    private let coreCount = Double(max(ProcessInfo.processInfo.processorCount, 1))
    
    public init() {}
    
    public func getTopProcesses(limit: Int = 5) -> (topMemory: [ProcessUsageItem], topCpu: [ProcessUsageItem]) {
        var pids = [Int32](repeating: 0, count: 2048)
        let bytesUsed = proc_listpids(1 /* PROC_ALL_PIDS */, 0, &pids, Int32(MemoryLayout<Int32>.stride * 2048))
        guard bytesUsed > 0 else { return ([], []) }
        
        let count = Int(bytesUsed) / MemoryLayout<Int32>.stride
        var items: [ProcessUsageItem] = []
        var nameBuf = [CChar](repeating: 0, count: 256)
        let taskInfoSize = Int32(MemoryLayout<proc_taskinfo>.stride)
        let now = Date().timeIntervalSince1970
        var activePids = Set<Int32>()
        
        for i in 0..<count {
            let pid = pids[i]
            guard pid > 0 else { continue }
            
            var taskInfo = proc_taskinfo()
            let res = proc_pidinfo(pid, 4 /* PROC_PIDTASKINFO */, 0, &taskInfo, taskInfoSize)
            guard res == taskInfoSize else { continue }
            
            let nameLen = proc_name(pid, &nameBuf, 256)
            let name = nameLen > 0 ? String(cString: nameBuf) : "PID \(pid)"
            
            // Filter system idle / kernel tasks that are not actionable
            if name == "kernel_task" || name == "launchd" { continue }
            
            activePids.insert(pid)
            
            let memBytes = taskInfo.pti_resident_size
            let memMB = Double(memBytes) / (1024 * 1024)
            let memFormatted = memMB > 1024 ? String(format: "%.1f GB", memMB / 1024.0) : String(format: "%.0f MB", memMB)
            let cpuSeconds = Double(taskInfo.pti_total_user) / 1_000_000_000.0
            
            // Real-time delta CPU calculation: (Δ(user + system ns) / Δt)
            let currentTotalNs = taskInfo.pti_total_user + taskInfo.pti_total_system
            var cpuPercent: Double = 0.0
            
            if let prev = previousTimes[pid] {
                let deltaNs = currentTotalNs >= prev.totalNs ? (currentTotalNs - prev.totalNs) : 0
                let deltaTime = now - prev.timestamp
                if deltaTime > 0.1 {
                    // Convert nanoseconds to percentage over delta seconds
                    let rawPct = (Double(deltaNs) / (deltaTime * 1_000_000_000.0)) * 100.0
                    cpuPercent = min(max(rawPct, 0.0), coreCount * 100.0)
                }
            }
            
            previousTimes[pid] = PreviousCpuTime(totalNs: currentTotalNs, timestamp: now)
            
            let cpuFormatted = String(format: "%.1f%%", cpuPercent)
            
            items.append(ProcessUsageItem(
                pid: pid,
                name: name,
                memoryBytes: memBytes,
                memoryFormatted: memFormatted,
                cpuPercent: cpuPercent,
                cpuFormatted: cpuFormatted,
                cpuUserSeconds: cpuSeconds
            ))
        }
        
        // Prune terminated PIDs from previousTimes dictionary to eliminate memory leaks
        previousTimes = previousTimes.filter { activePids.contains($0.key) }
        
        let topMem = Array(items.sorted(by: { $0.memoryBytes > $1.memoryBytes }).prefix(limit))
        let topCpu = Array(items.sorted(by: { $0.cpuPercent > $1.cpuPercent }).prefix(limit))
        
        return (topMem, topCpu)
    }
    
    public func terminateProcess(pid: Int32) -> Bool {
        if kill(pid, SIGTERM) == 0 {
            return true
        }
        return kill(pid, SIGKILL) == 0
    }
}
