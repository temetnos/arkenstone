import Foundation
import Combine
import AppKit

public enum TemperatureUnit: String, CaseIterable, Identifiable {
    case celsius = "celsius"
    case fahrenheit = "fahrenheit"
    
    public var id: String { rawValue }
    
    public var symbol: String {
        switch self {
        case .celsius: return "°C"
        case .fahrenheit: return "°F"
        }
    }
    
    public var displayName: String {
        switch self {
        case .celsius: return "°C"
        case .fahrenheit: return "°F"
        }
    }
    
    public var fullTitle: String {
        switch self {
        case .celsius: return L10n.tr("Celsius (°C)", "Santigrat (°C)")
        case .fahrenheit: return L10n.tr("Fahrenheit (°F)", "Fahrenhayt (°F)")
        }
    }
    
    public func convert(_ celsius: Double) -> Double {
        switch self {
        case .celsius: return celsius
        case .fahrenheit: return (celsius * 9.0 / 5.0) + 32.0
        }
    }
    
    public func format(_ celsius: Double, decimals: Int = 0) -> String {
        let val = convert(celsius)
        return String(format: "%.\(decimals)f%@", val, symbol)
    }
}

public class HardwareMonitor: ObservableObject {
    public static weak var shared: HardwareMonitor?
    
    @Published public var temperatureUnit: TemperatureUnit = .celsius
    
    @Published public var cpu = CPUSnapshot()
    @Published public var memory = MemorySnapshot()
    @Published public var gpu = GPUSnapshot()
    @Published public var thermal = ThermalSnapshot()
    @Published public var battery = BatterySnapshot()
    @Published public var network = NetworkSnapshot()
    
    // Top Processes
    @Published public var topMemoryProcesses: [ProcessUsageItem] = []
    @Published public var topCpuProcesses: [ProcessUsageItem] = []
    
    // System Info
    @Published public var macModel: String = "MacBook"
    @Published public var chipName: String = "Apple Silicon"
    @Published public var osVersion: String = "macOS"
    @Published public var uptimeString: String = "0s"
    
    // Monitors
    private let cpuMonitor = CPUMonitor()
    private let memoryMonitor = MemoryMonitor()
    private let gpuMonitor = GPUMonitor()
    private let thermalMonitor = ThermalMonitor()
    private let batteryMonitor = BatteryMonitor()
    private let networkMonitor = NetworkMonitor()
    public let processMonitor = ProcessMonitor()
    
    // Background Telemetry Queue & Concurrency Lock
    private let telemetryQueue = DispatchQueue(label: "com.citadel.arken.telemetry", qos: .utility)
    private var isUpdatingTelemetry = false
    
    // Adaptive Timer
    private var timer: Timer?
    public var isPopoverVisible: Bool = false {
        didSet {
            setupTimer()
        }
    }
    
    public init() {
        Self.shared = self
        
        // Restore temperature unit preference with fallback
        let savedUnit = UserDefaults.standard.string(forKey: "ArkenTemperatureUnit")
            ?? UserDefaults.standard.string(forKey: "PalantirTemperatureUnit")
            ?? TemperatureUnit.celsius.rawValue
        if let unit = TemperatureUnit(rawValue: savedUnit) {
            self.temperatureUnit = unit
        }
        
        fetchSystemInfo()
        updateAll()
        setupTimer()
    }
    
    public func formatTemperature(_ celsius: Double, decimals: Int = 0) -> String {
        return temperatureUnit.format(celsius, decimals: decimals)
    }
    
    deinit {
        timer?.invalidate()
    }
    
    public func setupTimer() {
        timer?.invalidate()
        let interval: TimeInterval = isPopoverVisible ? 1.0 : 3.0
        
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.updateAll()
        }
        if let t = timer {
            RunLoop.main.add(t, forMode: .common)
        }
    }
    
    public func updateAll() {
        guard !isUpdatingTelemetry else { return }
        isUpdatingTelemetry = true
        
        telemetryQueue.async { [weak self] in
            guard let self = self else { return }
            defer { self.isUpdatingTelemetry = false }
            
            self.cpuMonitor.update()
            self.memoryMonitor.update()
            self.gpuMonitor.update()
            self.thermalMonitor.update()
            self.batteryMonitor.update()
            self.networkMonitor.update()
            
            // Check battery limit alerts & sync keep awake AC status
            PowerGuardEngine.shared.checkBattery(battery: self.batteryMonitor.snapshot)
            KeepAwakeEngine.shared.syncWithBatteryState(isPluggedIn: self.batteryMonitor.snapshot.isPluggedIn)
            
            // Top processes updated when popover is open
            var memProcs: [ProcessUsageItem] = []
            var cpuProcs: [ProcessUsageItem] = []
            if self.isPopoverVisible {
                let res = self.processMonitor.getTopProcesses(limit: 5)
                memProcs = res.topMemory
                cpuProcs = res.topCpu
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.cpu = self.cpuMonitor.snapshot
                self.memory = self.memoryMonitor.snapshot
                self.gpu = self.gpuMonitor.snapshot
                self.thermal = self.thermalMonitor.snapshot
                self.battery = self.batteryMonitor.snapshot
                self.network = self.networkMonitor.snapshot
                if self.isPopoverVisible {
                    self.topMemoryProcesses = memProcs
                    self.topCpuProcesses = cpuProcs
                }
                self.updateUptime()
                
                // Directly trigger status bar icon update (single source of truth)
                StatusBarController.shared?.updateButtonContent()
            }
        }
    }
    
    private func fetchSystemInfo() {
        var modelSize = 0
        sysctlbyname("hw.model", nil, &modelSize, nil, 0)
        var modelChars = [CChar](repeating: 0, count: max(modelSize, 1))
        if modelSize > 0 {
            sysctlbyname("hw.model", &modelChars, &modelSize, nil, 0)
        }
        let rawModel = String(cString: modelChars)
        
        var brandSize = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &brandSize, nil, 0)
        var brandChars = [CChar](repeating: 0, count: max(brandSize, 1))
        if brandSize > 0 {
            sysctlbyname("machdep.cpu.brand_string", &brandChars, &brandSize, nil, 0)
        }
        let rawBrand = String(cString: brandChars)
        
        // Chip identification with Apple Silicon fallbacks
        if !rawBrand.isEmpty {
            self.chipName = rawBrand
        } else {
            var targetSize = 0
            sysctlbyname("hw.targettype", nil, &targetSize, nil, 0)
            var targetChars = [CChar](repeating: 0, count: max(targetSize, 1))
            if targetSize > 0 {
                sysctlbyname("hw.targettype", &targetChars, &targetSize, nil, 0)
            }
            let targetType = String(cString: targetChars)
            self.chipName = targetType.isEmpty ? "Apple Silicon" : "Apple Silicon (\(targetType))"
        }
        
        // Comprehensive Model Mapping (covering M1..M4 modern naming Mac14..Mac16, Intel & Legacy)
        let m = rawModel.lowercased()
        if m.contains("bookair") || m == "mac14,2" || m == "mac14,15" || m == "mac15,12" || m == "mac15,13" {
            self.macModel = "MacBook Air"
        } else if m.contains("bookpro") || m.hasPrefix("mac14,5") || m.hasPrefix("mac14,6") || m.hasPrefix("mac14,7") || m.hasPrefix("mac14,9") || m.hasPrefix("mac14,10") || m.hasPrefix("mac15,3") || m.hasPrefix("mac15,6") || m.hasPrefix("mac15,7") || m.hasPrefix("mac15,8") || m.hasPrefix("mac15,9") || m.hasPrefix("mac15,10") || m.hasPrefix("mac15,11") || m.hasPrefix("mac16,5") || m.hasPrefix("mac16,6") || m.hasPrefix("mac16,7") || m.hasPrefix("mac16,8") {
            self.macModel = "MacBook Pro"
        } else if m.contains("book") {
            self.macModel = "MacBook"
        } else if m.contains("mini") || m == "mac14,3" || m == "mac14,12" || m.hasPrefix("mac16,1") || m.hasPrefix("mac16,2") || m.hasPrefix("mac16,10") {
            self.macModel = "Mac mini"
        } else if m.contains("studio") || m == "mac14,13" || m == "mac14,14" {
            self.macModel = "Mac Studio"
        } else if m.contains("imac") || m == "mac15,4" || m == "mac15,5" {
            self.macModel = "iMac"
        } else if m.contains("macpro") || m == "mac14,8" {
            self.macModel = "Mac Pro"
        } else {
            // Intelligent hardware fallback based on battery existence
            self.macModel = batteryMonitor.snapshot.hasBattery ? "MacBook" : "Mac Desktop"
        }
        
        let os = ProcessInfo.processInfo.operatingSystemVersion
        self.osVersion = "macOS \(os.majorVersion).\(os.minorVersion)"
    }
    
    private func updateUptime() {
        var bootTime = timeval()
        var size = MemoryLayout<timeval>.size
        if sysctlbyname("kern.boottime", &bootTime, &size, nil, 0) == 0 {
            let now = Date().timeIntervalSince1970
            let seconds = Int(now - Double(bootTime.tv_sec))
            let days = seconds / 86400
            let hours = (seconds % 86400) / 3600
            let minutes = (seconds % 3600) / 60
            
            let dayUnit = L10n.tr("d", "g")
            let hourUnit = L10n.tr("h", "sa")
            let minUnit = L10n.tr("m", "dk")
            
            if days > 0 {
                self.uptimeString = "\(days)\(dayUnit) \(hours)\(hourUnit) \(minutes)\(minUnit)"
            } else if hours > 0 {
                self.uptimeString = "\(hours)\(hourUnit) \(minutes)\(minUnit)"
            } else {
                self.uptimeString = "\(minutes)\(minUnit)"
            }
        }
    }
}
