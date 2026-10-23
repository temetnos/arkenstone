import Foundation
import IOKit

public struct BatterySnapshot {
    public var percentage: Int = 100
    public var isPluggedIn: Bool = false
    public var isCharging: Bool = false
    public var voltage: Double = 0.0 // Volts
    public var amperage: Double = 0.0 // Amperes
    public var watts: Double = 0.0 // Watts
    public var healthPercentage: Double = 100.0 // Health %
    public var cycleCount: Int = 0
    public var adapterWatts: Int = 0
    public var adapterName: String = ""
    public var temperature: Double = 0.0
    public var timeRemainingMinutes: Int = -1 // -1 means calculating or on AC
    public var designCapacity: Int = 0
    public var currentCapacity: Int = 0
    public var maxCapacity: Int = 0
    public var condition: String = "Normal"
    public var hasBattery: Bool = true
}

public class BatteryMonitor {
    public private(set) var snapshot = BatterySnapshot()
    
    public init() {
        update()
    }
    
    public func update() {
        var iter: io_iterator_t = 0
        let serviceMatch = IOServiceMatching("AppleSmartBattery")
        let status = IOServiceGetMatchingServices(kIOMainPortDefault, serviceMatch, &iter)
        
        guard status == KERN_SUCCESS else {
            snapshot.hasBattery = false
            return
        }
        
        var service = IOIteratorNext(iter)
        if service == 0 {
            snapshot.hasBattery = false
            IOObjectRelease(iter)
            return
        }
        snapshot.hasBattery = true
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iter)
            }
            
            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let dict = props?.takeRetainedValue() as? [String: Any] {
                
                let curCap = dict["CurrentCapacity"] as? Int ?? 100
                let maxCap = dict["MaxCapacity"] as? Int ?? 100
                let designCap = dict["DesignCapacity"] as? Int ?? 1
                let nominalCap = dict["NominalChargeCapacity"] as? Int ?? (dict["AppleRawMaxCapacity"] as? Int ?? designCap)
                
                let rawVolt = dict["Voltage"] as? Double ?? (dict["AppleRawBatteryVoltage"] as? Double ?? 0.0)
                let rawAmp = dict["Amperage"] as? Double ?? (dict["InstantAmperage"] as? Double ?? 0.0)
                
                let volts = rawVolt / 1000.0
                let amps = rawAmp / 1000.0
                let watts = abs(volts * amps)
                
                let isPlugged = dict["ExternalConnected"] as? Bool ?? false
                let isCharging = dict["IsCharging"] as? Bool ?? false
                let cycles = dict["CycleCount"] as? Int ?? 0
                
                var adapterWatts = 0
                if let adapterDetails = dict["AdapterDetails"] as? [String: Any] {
                    adapterWatts = adapterDetails["Watts"] as? Int ?? 0
                } else if let rawAdapters = dict["AppleRawAdapterDetails"] as? [[String: Any]], let first = rawAdapters.first {
                    adapterWatts = first["Watts"] as? Int ?? 0
                }
                
                let tempRaw = dict["Temperature"] as? Double ?? 0.0
                let temp = tempRaw > 1000 ? (tempRaw / 100.0) : tempRaw
                
                var timeRemaining = -1
                if let time = dict["TimeRemaining"] as? Int, time < 65535, time >= 0 {
                    timeRemaining = time
                }
                
                let health = max(0.0, min(100.0, (Double(nominalCap) / Double(max(designCap, 1))) * 100.0))
                
                snapshot.percentage = curCap
                snapshot.isPluggedIn = isPlugged
                snapshot.isCharging = isCharging
                snapshot.voltage = volts
                snapshot.amperage = amps
                snapshot.watts = watts
                snapshot.healthPercentage = health
                snapshot.cycleCount = cycles
                snapshot.adapterWatts = adapterWatts
                snapshot.temperature = temp
                snapshot.timeRemainingMinutes = timeRemaining
                snapshot.designCapacity = designCap
                snapshot.currentCapacity = curCap
                snapshot.maxCapacity = maxCap
                snapshot.condition = (dict["PermanentFailureStatus"] as? Int ?? 0) != 0 ? L10n.tr("Service Recommended", "Servis Önerilir") : L10n.tr("Normal", "Normal")
            }
        }
        
        IOObjectRelease(iter)
    }
}
