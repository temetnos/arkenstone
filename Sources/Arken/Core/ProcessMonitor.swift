import Foundation
import Darwin

public struct ProcessUsageItem: Identifiable {
    public var id: Int32 { pid }
    public let pid: Int32
    public let name: String
    public let memoryBytes: UInt64
    public let memoryFormatted: String
    public let cpuUserSeconds: Double
}

public class ProcessMonitor {
    private struct PreviousCpuTime {
        var userTime: UInt64
        var systemTime: UInt64
        var timestamp: TimeInterval
    }
    
    private var previousTimes: [Int32: PreviousCpuTime] = [:]
    
    public init() {}
    
    public func getTopProcesses(limit: Int = 5) -> (topMemory: [ProcessUsageItem], topCpu: [ProcessUsageItem]) {
        var pids = [Int32](repeating: 0, count: 2048)
        let bytesUsed = proc_listpids(1 /* PROC_ALL_PIDS */, 0, &pids, Int32(MemoryLayout<Int32>.stride * 2048))
        guard bytesUsed > 0 else { return ([], []) }
        
        let count = Int(bytesUsed) / MemoryLayout<Int32>.stride
        var items: [ProcessUsageItem] = []
        var nameBuf = [CChar](repeating: 0, count: 256)
        let taskInfoSize = Int32(MemoryLayout<proc_taskinfo>.stride)
        
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
            
            let memBytes = taskInfo.pti_resident_size
            let memMB = Double(memBytes) / (1024 * 1024)
            let memFormatted = memMB > 1024 ? String(format: "%.1f GB", memMB / 1024.0) : String(format: "%.0f MB", memMB)
            let cpuSeconds = Double(taskInfo.pti_total_user) / 1_000_000_000.0
            
            items.append(ProcessUsageItem(
                pid: pid,
                name: name,
                memoryBytes: memBytes,
                memoryFormatted: memFormatted,
                cpuUserSeconds: cpuSeconds
            ))
        }
        
        let topMem = Array(items.sorted(by: { $0.memoryBytes > $1.memoryBytes }).prefix(limit))
        let topCpu = Array(items.sorted(by: { $0.cpuUserSeconds > $1.cpuUserSeconds }).prefix(limit))
        
        return (topMem, topCpu)
    }
    
    public func terminateProcess(pid: Int32) -> Bool {
        if kill(pid, SIGTERM) == 0 {
            return true
        }
        return kill(pid, SIGKILL) == 0
    }
}
