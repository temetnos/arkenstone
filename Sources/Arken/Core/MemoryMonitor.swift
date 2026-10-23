import Foundation
import Darwin

public enum MemoryPressureLevel: String {
    case normal = "normal"
    case warning = "warning"
    case critical = "critical"
    
    public var title: String {
        switch self {
        case .normal: return L10n.tr("Normal", "Normal")
        case .warning: return L10n.tr("Warning", "Uyarı")
        case .critical: return L10n.tr("Critical", "Kritik")
        }
    }
}

public struct MemorySnapshot {
    public var totalBytes: UInt64 = 0
    public var usedBytes: UInt64 = 0
    public var freeBytes: UInt64 = 0
    public var activeBytes: UInt64 = 0
    public var inactiveBytes: UInt64 = 0
    public var wiredBytes: UInt64 = 0
    public var compressedBytes: UInt64 = 0
    public var swapUsedBytes: UInt64 = 0
    public var swapTotalBytes: UInt64 = 0
    
    public var usedPercentage: Double {
        guard totalBytes > 0 else { return 0.0 }
        return (Double(usedBytes) / Double(totalBytes)) * 100.0
    }
    
    public var pressureLevel: MemoryPressureLevel = .normal
    public var history: [Double] = []
}

public class MemoryMonitor {
    private let pageSize = UInt64(vm_kernel_page_size)
    private var historyBuffer: [Double] = []
    private let maxHistory = 30
    
    public private(set) var snapshot = MemorySnapshot()
    
    public init() {
        snapshot.totalBytes = ProcessInfo.processInfo.physicalMemory
        update()
    }
    
    public func update() {
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return }
        
        let active = UInt64(vmStats.active_count) * pageSize
        let inactive = UInt64(vmStats.inactive_count) * pageSize
        let wired = UInt64(vmStats.wire_count) * pageSize
        let compressed = UInt64(vmStats.compressor_page_count) * pageSize
        let freePages = UInt64(vmStats.free_count) * pageSize
        
        let total = ProcessInfo.processInfo.physicalMemory
        let used = active + wired + compressed
        let free = total > used ? (total - used) : freePages
        
        snapshot.totalBytes = total
        snapshot.usedBytes = used
        snapshot.freeBytes = free
        snapshot.activeBytes = active
        snapshot.inactiveBytes = inactive
        snapshot.wiredBytes = wired
        snapshot.compressedBytes = compressed
        
        // Swap usage
        var swapUsage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        if sysctlbyname("vm.swapusage", &swapUsage, &size, nil, 0) == 0 {
            snapshot.swapUsedBytes = UInt64(swapUsage.xsu_used)
            snapshot.swapTotalBytes = UInt64(swapUsage.xsu_total)
        }
        
        let usedPct = snapshot.usedPercentage
        
        // Pressure evaluation using Darwin kernel memorystatus
        var pressureLevelInt: Int32 = 0
        var pressureSize = MemoryLayout<Int32>.size
        let kernResult = sysctlbyname("kern.memorystatus_vm_pressure_level", &pressureLevelInt, &pressureSize, nil, 0)
        
        if kernResult == 0 && pressureLevelInt > 0 {
            // Darwin vm pressure levels:
            // 1: Normal (NOTE_MEMORYSTATUS_PRESSURE_NORMAL)
            // 2: Warning (NOTE_MEMORYSTATUS_PRESSURE_WARN)
            // 4: Critical (NOTE_MEMORYSTATUS_PRESSURE_CRITICAL)
            switch pressureLevelInt {
            case 2:
                snapshot.pressureLevel = .warning
            case 4...:
                snapshot.pressureLevel = .critical
            default:
                snapshot.pressureLevel = .normal
            }
        } else {
            // Fallback: only evaluate based on actual active RAM saturation
            if usedPct > 88.0 {
                snapshot.pressureLevel = .critical
            } else if usedPct > 78.0 {
                snapshot.pressureLevel = .warning
            } else {
                snapshot.pressureLevel = .normal
            }
        }
        
        historyBuffer.append(usedPct)
        if historyBuffer.count > maxHistory {
            historyBuffer.removeFirst()
        }
        snapshot.history = historyBuffer
    }
}
