import Foundation
import Darwin

public struct CPUCoreUsage: Identifiable {
    public let id: Int
    public let isPerformance: Bool
    public let usage: Double // 0.0 to 100.0
}

public struct CPUSnapshot {
    public var totalUsage: Double = 0.0
    public var userUsage: Double = 0.0
    public var systemUsage: Double = 0.0
    public var idleUsage: Double = 100.0
    public var coreUsages: [CPUCoreUsage] = []
    public var coreCount: Int = 0
    public var efficiencyCoreCount: Int = 0
    public var performanceCoreCount: Int = 0
    public var history: [Double] = [] // Recent 30 samples
}

public class CPUMonitor {
    private var previousInfo: processor_info_array_t?
    private var previousInfoCount: mach_msg_type_number_t = 0
    private var historyBuffer: [Double] = []
    private let maxHistory = 30
    
    public private(set) var snapshot = CPUSnapshot()
    
    public init() {
        // Determine core counts
        var pCores: Int32 = 0
        var eCores: Int32 = 0
        var size = MemoryLayout<Int32>.size
        
        sysctlbyname("hw.perflevel0.logicalcpu", &pCores, &size, nil, 0)
        sysctlbyname("hw.perflevel1.logicalcpu", &eCores, &size, nil, 0)
        
        snapshot.performanceCoreCount = Int(pCores)
        snapshot.efficiencyCoreCount = Int(eCores)
        snapshot.coreCount = Int(ProcessInfo.processInfo.processorCount)
        
        // Initial sample
        update()
    }
    
    deinit {
        if let prev = previousInfo {
            let size = MemoryLayout<integer_t>.stride * Int(previousInfoCount)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: prev), vm_size_t(size))
        }
    }
    
    public func update() {
        var numCPUs: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCpuInfo: mach_msg_type_number_t = 0
        
        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCPUs,
            &cpuInfo,
            &numCpuInfo
        )
        
        guard result == KERN_SUCCESS, let cpuInfo = cpuInfo else { return }
        
        defer {
            if let prev = previousInfo {
                let size = MemoryLayout<integer_t>.stride * Int(previousInfoCount)
                vm_deallocate(mach_task_self_, vm_address_t(bitPattern: prev), vm_size_t(size))
            }
            previousInfo = cpuInfo
            previousInfoCount = numCpuInfo
        }
        
        guard let prevInfo = previousInfo else { return }
        
        var totalUserTicks: Int64 = 0
        var totalSystemTicks: Int64 = 0
        var totalIdleTicks: Int64 = 0
        var totalAllTicks: Int64 = 0
        
        var cores: [CPUCoreUsage] = []
        let coreCount = Int(numCPUs)
        
        for i in 0..<coreCount {
            let offset = Int(CPU_STATE_MAX) * i
            
            let user = Int64(cpuInfo[offset + Int(CPU_STATE_USER)] - prevInfo[offset + Int(CPU_STATE_USER)])
            let sys = Int64(cpuInfo[offset + Int(CPU_STATE_SYSTEM)] - prevInfo[offset + Int(CPU_STATE_SYSTEM)])
            let idle = Int64(cpuInfo[offset + Int(CPU_STATE_IDLE)] - prevInfo[offset + Int(CPU_STATE_IDLE)])
            let nice = Int64(cpuInfo[offset + Int(CPU_STATE_NICE)] - prevInfo[offset + Int(CPU_STATE_NICE)])
            
            let coreTotal = user + sys + idle + nice
            let coreActive = user + sys + nice
            let corePercent = coreTotal > 0 ? (Double(coreActive) / Double(coreTotal)) * 100.0 : 0.0
            
            // On Apple Silicon, Efficiency cores are typically lower index or higher index depending on perflevel
            // E-cores: first eCores or perflevel1
            let isP = i >= snapshot.efficiencyCoreCount
            cores.append(CPUCoreUsage(id: i, isPerformance: isP, usage: min(max(corePercent, 0.0), 100.0)))
            
            totalUserTicks += user
            totalSystemTicks += sys
            totalIdleTicks += idle
            totalAllTicks += coreTotal
        }
        
        let totalActiveTicks = totalUserTicks + totalSystemTicks
        let totalPercent = totalAllTicks > 0 ? (Double(totalActiveTicks) / Double(totalAllTicks)) * 100.0 : 0.0
        let userPercent = totalAllTicks > 0 ? (Double(totalUserTicks) / Double(totalAllTicks)) * 100.0 : 0.0
        let sysPercent = totalAllTicks > 0 ? (Double(totalSystemTicks) / Double(totalAllTicks)) * 100.0 : 0.0
        let idlePercent = totalAllTicks > 0 ? (Double(totalIdleTicks) / Double(totalAllTicks)) * 100.0 : 100.0
        
        snapshot.totalUsage = min(max(totalPercent, 0.0), 100.0)
        snapshot.userUsage = min(max(userPercent, 0.0), 100.0)
        snapshot.systemUsage = min(max(sysPercent, 0.0), 100.0)
        snapshot.idleUsage = min(max(idlePercent, 0.0), 100.0)
        snapshot.coreUsages = cores
        
        historyBuffer.append(snapshot.totalUsage)
        if historyBuffer.count > maxHistory {
            historyBuffer.removeFirst()
        }
        snapshot.history = historyBuffer
    }
}
