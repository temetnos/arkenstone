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
        RunLoop.main.add(timer!, forMode: .common)
    }
    
    public func updateAll() {
        cpuMonitor.update()
        memoryMonitor.update()
        gpuMonitor.update()
        thermalMonitor.update()
        batteryMonitor.update()
        networkMonitor.update()
        
        // Check battery limit alerts & sync keep awake AC status
        PowerGuardEngine.shared.checkBattery(battery: batteryMonitor.snapshot)
        KeepAwakeEngine.shared.syncWithBatteryState(isPluggedIn: batteryMonitor.snapshot.isPluggedIn)
        
        // Top processes updated when popover is open
        var memProcs: [ProcessUsageItem] = []
        var cpuProcs: [ProcessUsageItem] = []
        if isPopoverVisible {
            let res = processMonitor.getTopProcesses(limit: 5)
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
        }
    }
    
    private func fetchSystemInfo() {
        var modelSize = 0
        sysctlbyname("hw.model", nil, &modelSize, nil, 0)
        var modelChars = [CChar](repeating: 0, count: modelSize)
        sysctlbyname("hw.model", &modelChars, &modelSize, nil, 0)
        let rawModel = String(cString: modelChars)
        
        var brandSize = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &brandSize, nil, 0)
        var brandChars = [CChar](repeating: 0, count: brandSize)
        sysctlbyname("machdep.cpu.brand_string", &brandChars, &brandSize, nil, 0)
        let rawBrand = String(cString: brandChars)
        
        self.chipName = rawBrand.isEmpty ? "Apple Silicon" : rawBrand
        
        if rawModel.contains("MacBookAir") {
            self.macModel = "MacBook Air"
        } else if rawModel.contains("MacBookPro") {
            self.macModel = "MacBook Pro"
        } else if rawModel.contains("Macmini") {
            self.macModel = "Mac mini"
        } else if rawModel.contains("MacStudio") {
            self.macModel = "Mac Studio"
        } else if rawModel.contains("MacPro") {
            self.macModel = "Mac Pro"
        } else {
            self.macModel = "Apple Mac"
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
