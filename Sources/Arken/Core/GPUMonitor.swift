import Foundation
import IOKit

public struct GPUSnapshot {
    public var deviceUtilization: Double = 0.0 // 0 to 100%
    public var rendererUtilization: Double = 0.0
    public var tilerUtilization: Double = 0.0
    public var allocatedMemoryBytes: UInt64 = 0
    public var inUseMemoryBytes: UInt64 = 0
    public var history: [Double] = []
}

public class GPUMonitor {
    private var historyBuffer: [Double] = []
    private let maxHistory = 30
    
    public private(set) var snapshot = GPUSnapshot()
    
    public init() {
        update()
    }
    
    public func update() {
        var iterator: io_iterator_t = 0
        let matchDict = IOServiceMatching("IOAccelerator")
        
        let status = IOServiceGetMatchingServices(kIOMainPortDefault, matchDict, &iterator)
        guard status == KERN_SUCCESS else { return }
        
        var entry = IOIteratorNext(iterator)
        var found = false
        
        while entry != 0 {
            defer {
                IOObjectRelease(entry)
                entry = IOIteratorNext(iterator)
            }
            
            if !found, let prop = IORegistryEntryCreateCFProperty(
                entry,
                "PerformanceStatistics" as CFString,
                kCFAllocatorDefault,
                0
            )?.takeRetainedValue() as? [String: Any] {
                found = true
                
                let devUtil = Double(prop["Device Utilization %"] as? Int ?? 0)
                let rendUtil = Double(prop["Renderer Utilization %"] as? Int ?? 0)
                let tilerUtil = Double(prop["Tiler Utilization %"] as? Int ?? 0)
                
                let allocMem = UInt64(prop["Alloc system memory"] as? Int64 ?? 0)
                let inUseMem = UInt64(prop["In use system memory"] as? Int64 ?? 0)
                
                snapshot.deviceUtilization = min(max(devUtil, 0.0), 100.0)
                snapshot.rendererUtilization = min(max(rendUtil, 0.0), 100.0)
                snapshot.tilerUtilization = min(max(tilerUtil, 0.0), 100.0)
                snapshot.allocatedMemoryBytes = allocMem
                snapshot.inUseMemoryBytes = inUseMem
            }
        }
        
        IOObjectRelease(iterator)
        
        historyBuffer.append(snapshot.deviceUtilization)
        if historyBuffer.count > maxHistory {
            historyBuffer.removeFirst()
        }
        snapshot.history = historyBuffer
    }
}
