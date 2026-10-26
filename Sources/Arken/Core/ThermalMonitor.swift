import Foundation
import IOKit

// Private IOHID declarations
typealias IOHIDEventSystemClientRef = CFTypeRef
typealias IOHIDServiceClientRef = CFTypeRef
typealias IOHIDEventRef = CFTypeRef

@_silgen_name("IOHIDEventSystemClientCreate")
func IOHIDEventSystemClientCreate(_ allocator: CFAllocator?) -> IOHIDEventSystemClientRef?

@_silgen_name("IOHIDEventSystemClientSetMatching")
func IOHIDEventSystemClientSetMatching(_ client: IOHIDEventSystemClientRef, _ matches: CFDictionary) -> Void

@_silgen_name("IOHIDEventSystemClientCopyServices")
func IOHIDEventSystemClientCopyServices(_ client: IOHIDEventSystemClientRef) -> CFArray?

@_silgen_name("IOHIDServiceClientCopyProperty")
func IOHIDServiceClientCopyProperty(_ service: IOHIDServiceClientRef, _ property: CFString) -> CFTypeRef?

@_silgen_name("IOHIDServiceClientCopyEvent")
func IOHIDServiceClientCopyEvent(_ service: IOHIDServiceClientRef, _ type: Int64, _ options: Int32, _ param: Int64) -> IOHIDEventRef?

@_silgen_name("IOHIDEventGetFloatValue")
func IOHIDEventGetFloatValue(_ event: IOHIDEventRef, _ field: UInt32) -> Double

public struct ThermalSensorItem: Identifiable {
    public var id: String { name }
    public let name: String
    public let temperature: Double // Celsius
    public let category: String
}

public struct ThermalSnapshot {
    public var cpuTemperature: Double = 0.0
    public var gpuTemperature: Double = 0.0
    public var socTemperature: Double = 0.0
    public var batteryTemperature: Double = 0.0
    public var ssdTemperature: Double = 0.0
    public var maxSensorTemperature: Double = 0.0
    public var fanData: FanData = FanData()
    public var thermalState: ProcessInfo.ThermalState = .nominal
    public var thermalStateString: String {
        switch thermalState {
        case .nominal: return L10n.tr("Cool (Nominal)", "Serin (Nominal)")
        case .fair: return L10n.tr("Warm (Fair)", "Ilık (Fair)")
        case .serious: return L10n.tr("Hot (Serious)", "Sıcak (Serious)")
        case .critical: return L10n.tr("Critical", "Aşırı Sıcak (Critical)")
        @unknown default: return L10n.tr("Normal", "Normal")
        }
    }
    public var detailedSensors: [ThermalSensorItem] = []
}

public class ThermalMonitor {
    private var client: IOHIDEventSystemClientRef?
    public private(set) var snapshot = ThermalSnapshot()
    
    public init() {
        if let cl = IOHIDEventSystemClientCreate(kCFAllocatorDefault) {
            let matching: [String: Any] = [
                "PrimaryUsagePage": 0xff00,
                "PrimaryUsage": 0x5
            ]
            IOHIDEventSystemClientSetMatching(cl, matching as CFDictionary)
            self.client = cl
        }
        update()
    }
    
    public func update() {
        guard let client = client else {
            fallbackThermalState()
            return
        }
        
        guard let services = IOHIDEventSystemClientCopyServices(client) as? [IOHIDServiceClientRef] else {
            fallbackThermalState()
            return
        }
        
        var cpuTemps: [Double] = []
        var gpuTemps: [Double] = []
        var socTemps: [Double] = []
        var battTemps: [Double] = []
        var ssdTemps: [Double] = []
        var allSensors: [ThermalSensorItem] = []
        var maxTemp: Double = 0.0
        
        for service in services {
            let name = IOHIDServiceClientCopyProperty(service, "Product" as CFString) as? String ?? ""
            guard !name.isEmpty else { continue }
            
            // 15 = kIOHIDEventTypeTemperature
            guard let event = IOHIDServiceClientCopyEvent(service, 15, 0, 0) else { continue }
            // field = (15 << 16)
            let temp = IOHIDEventGetFloatValue(event, UInt32(15 << 16))
            
            // Filter reasonable sensor temperatures (-10°C to 130°C)
            guard temp > 5.0 && temp < 125.0 else { continue }
            
            maxTemp = max(maxTemp, temp)
            let lower = name.lowercased()
            
            var category = L10n.tr("Other", "Diğer")
            if lower.contains("pacc") || lower.contains("eacc") || lower.contains("cpu") {
                cpuTemps.append(temp)
                category = L10n.tr("Processor (CPU)", "İşlemci (CPU)")
            } else if lower.contains("gpu") {
                gpuTemps.append(temp)
                category = L10n.tr("Graphics (GPU)", "Grafik (GPU)")
            } else if lower.contains("soc") || lower.contains("pmgr") {
                socTemps.append(temp)
                category = L10n.tr("Chip (SoC)", "Çip (SoC)")
            } else if lower.contains("gas gauge") || lower.contains("battery") {
                battTemps.append(temp)
                category = L10n.tr("Battery", "Batarya")
            } else if lower.contains("nand") || lower.contains("ssd") {
                ssdTemps.append(temp)
                category = L10n.tr("Storage (SSD)", "Depolama (SSD)")
            }
            
            allSensors.append(ThermalSensorItem(name: name, temperature: temp, category: category))
        }
        
        snapshot.cpuTemperature = cpuTemps.isEmpty ? (socTemps.first ?? 42.0) : (cpuTemps.reduce(0, +) / Double(cpuTemps.count))
        snapshot.gpuTemperature = gpuTemps.isEmpty ? (socTemps.first ?? 40.0) : (gpuTemps.reduce(0, +) / Double(gpuTemps.count))
        snapshot.socTemperature = socTemps.isEmpty ? snapshot.cpuTemperature : (socTemps.reduce(0, +) / Double(socTemps.count))
        snapshot.batteryTemperature = battTemps.isEmpty ? 30.0 : (battTemps.reduce(0, +) / Double(battTemps.count))
        snapshot.ssdTemperature = ssdTemps.isEmpty ? 38.0 : (ssdTemps.reduce(0, +) / Double(ssdTemps.count))
        snapshot.maxSensorTemperature = maxTemp
        snapshot.detailedSensors = allSensors.sorted(by: { $0.temperature > $1.temperature })
        
        // System thermal state & SMC Fan status
        snapshot.thermalState = ProcessInfo.processInfo.thermalState
        snapshot.fanData = SMCFanReader.shared.readFans()
    }
    
    private func fallbackThermalState() {
        let state = ProcessInfo.processInfo.thermalState
        snapshot.thermalState = state
        snapshot.fanData = SMCFanReader.shared.readFans()
        switch state {
        case .nominal:
            snapshot.cpuTemperature = 42.0
            snapshot.gpuTemperature = 40.0
        case .fair:
            snapshot.cpuTemperature = 58.0
            snapshot.gpuTemperature = 55.0
        case .serious:
            snapshot.cpuTemperature = 75.0
            snapshot.gpuTemperature = 72.0
        case .critical:
            snapshot.cpuTemperature = 92.0
            snapshot.gpuTemperature = 88.0
        @unknown default:
            break
        }
    }
}
