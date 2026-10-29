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
        var totalTicks: UInt64
        var timestamp: TimeInterval
    }
    
    private var previousTimes: [Int32: PreviousCpuTime] = [:]
    private let coreCount = Double(max(ProcessInfo.processInfo.processorCount, 1))
    
    // Mach absolute timebase conversion factor (Apple Silicon: 125/3 = 41.666 ns/tick, Intel: 1.0 ns/tick)
    private static let timebaseFactor: Double = {
        var tb = mach_timebase_info()
        mach_timebase_info(&tb)
        return Double(tb.numer) / Double(tb.denom)
    }()
    
    public init() {}
    
    public func getTopProcesses(limit: Int = 5) -> (topMemory: [ProcessUsageItem], topCpu: [ProcessUsageItem]) {
        let estimatedBytes = proc_listpids(1 /* PROC_ALL_PIDS */, 0, nil, 0)
        let neededCount = max(Int(estimatedBytes) / MemoryLayout<Int32>.stride, 1024)
        var pids = [Int32](repeating: 0, count: neededCount)
        let bytesUsed = proc_listpids(1 /* PROC_ALL_PIDS */, 0, &pids, Int32(MemoryLayout<Int32>.stride * neededCount))
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
            let cpuSeconds = (Double(taskInfo.pti_total_user) * Self.timebaseFactor) / 1_000_000_000.0
            
            // Real-time delta CPU calculation using Mach absolute time conversion:
            // pti_total_user and pti_total_system are in Mach absolute time ticks (24 MHz on Apple Silicon)
            let currentTotalTicks = taskInfo.pti_total_user + taskInfo.pti_total_system
            var cpuPercent: Double = 0.0
            
            if let prev = previousTimes[pid] {
                let deltaTicks = currentTotalTicks >= prev.totalTicks ? (currentTotalTicks - prev.totalTicks) : 0
                let deltaTime = now - prev.timestamp
                if deltaTime > 0.1 {
                    // Convert Mach ticks to elapsed CPU seconds using system timebase
                    let deltaSeconds = (Double(deltaTicks) * Self.timebaseFactor) / 1_000_000_000.0
                    // Standard macOS Activity Monitor per-core percentage (1.0 core fully utilized = 100.0%)
                    let rawPct = (deltaSeconds / deltaTime) * 100.0
                    cpuPercent = min(max(rawPct, 0.0), coreCount * 100.0)
                }
            }
            
            previousTimes[pid] = PreviousCpuTime(totalTicks: currentTotalTicks, timestamp: now)
            
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
