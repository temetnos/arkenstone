import Foundation
import AppKit
import IOKit.pwr_mgt
import Combine

public enum KeepAwakeDuration: String, CaseIterable, Identifiable {
    case indefinite = "indefinite"
    case thirtyMinutes = "30m"
    case oneHour = "1h"
    case twoHours = "2h"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .indefinite: return L10n.tr("Indefinite", "Süresiz")
        case .thirtyMinutes: return L10n.tr("30 Mins", "30 Dakika")
        case .oneHour: return L10n.tr("1 Hour", "1 Saat")
        case .twoHours: return L10n.tr("2 Hours", "2 Saat")
        }
    }
    
    public var seconds: TimeInterval? {
        switch self {
        case .indefinite: return nil
        case .thirtyMinutes: return 1800
        case .oneHour: return 3600
        case .twoHours: return 7200
        }
    }
}

public class KeepAwakeEngine: ObservableObject {
    public static let shared = KeepAwakeEngine()
    
    // Regular Display/Idle Sleep Prevention
    @Published public var isActive: Bool = false
    @Published public var selectedDuration: KeepAwakeDuration = .indefinite
    @Published public var remainingSeconds: Int = 0
    
    // Clamshell (Lid-Closed) Sleep Prevention
    @Published public var isClamshellEnabled: Bool = false
    @Published public var isClamshellActive: Bool = false
    @Published public var isClamshellAuthRequired: Bool = false
    @Published public var isPluggedIn: Bool = false
    
    private var assertionID: IOPMAssertionID = 0
    private var clamshellAssertionID: IOPMAssertionID = 0
    private var countdownTimer: Timer?
    private var powerCheckTimer: Timer?
    
    private var helperPath: String {
        if FileManager.default.fileExists(atPath: "/usr/local/bin/arken-power-helper") {
            return "/usr/local/bin/arken-power-helper"
        }
        return "/usr/local/bin/palantir-power-helper"
    }
    private var isDisablesleepApplied = false
    private var isExecutingPrivileged = false
    
    public init() {
        if let saved = UserDefaults.standard.object(forKey: "ArkenClamshellEnabled") as? Bool {
            self.isClamshellEnabled = saved
        } else if let legacy = UserDefaults.standard.object(forKey: "PalantirClamshellEnabled") as? Bool {
            self.isClamshellEnabled = legacy
        }
        
        if isClamshellEnabled {
            updateClamshellState()
        } else {
            self.isPluggedIn = Self.checkExternalPower()
        }
        
        // Ensure sleep settings are cleanly restored on application exit
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.deactivate()
            self?.deactivateClamshell(sync: true)
        }
    }
    
    deinit {
        deactivate()
        stopPowerMonitoring()
        deactivateClamshell(sync: true)
    }
    
    // MARK: - Regular Keep Awake
    public func toggle() {
        if isActive {
            deactivate()
        } else {
            activate(duration: selectedDuration)
        }
    }
    
    public func activate(duration: KeepAwakeDuration = .indefinite) {
        deactivate()
        
        let reason = "Arken Keep Awake" as CFString
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &assertionID
        )
        
        if result == kIOReturnSuccess {
            isActive = true
            selectedDuration = duration
            
            if let secs = duration.seconds {
                remainingSeconds = Int(secs)
                let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                    guard let self = self else { return }
                    if self.remainingSeconds > 0 {
                        self.remainingSeconds -= 1
                    } else {
                        self.deactivate()
                    }
                }
                RunLoop.main.add(timer, forMode: .common)
                self.countdownTimer = timer
            } else {
                remainingSeconds = 0
            }
        }
    }
    
    public func deactivate() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        remainingSeconds = 0
        
        if assertionID != 0 {
            IOPMAssertionRelease(assertionID)
            assertionID = 0
        }
        isActive = false
    }
    
    // MARK: - Clamshell (Lid-Closed) Anti-Sleep Mode
    public func toggleClamshell() {
        if isClamshellAuthRequired {
            retryClamshellAuthorization()
        } else {
            setClamshellEnabled(!isClamshellEnabled)
        }
    }
    
    public func retryClamshellAuthorization() {
        self.isClamshellAuthRequired = false
        setClamshellEnabled(true)
    }
    
    public func setClamshellEnabled(_ enabled: Bool) {
        if !enabled {
            self.isClamshellAuthRequired = false
        }
        self.isClamshellEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "ArkenClamshellEnabled")
        updateClamshellState()
    }
    
    public func syncWithBatteryState(isPluggedIn: Bool) {
        self.isPluggedIn = isPluggedIn
        if isClamshellEnabled {
            if isPluggedIn {
                activateClamshell()
            } else {
                deactivateClamshell()
            }
        }
    }
    
    public func updateClamshellState() {
        guard isClamshellEnabled else {
            if isClamshellActive {
                deactivateClamshell()
            }
            stopPowerMonitoring()
            return
        }
        
        self.isPluggedIn = Self.checkExternalPower()
        
        // Safety Lock: ONLY allow lid-closed wakefulness when connected to AC power adapter!
        if isPluggedIn {
            activateClamshell()
            startPowerMonitoringIfNeeded()
        } else {
            // Unplugged! Deactivate immediately to avoid battery drain or backpack overheating
            deactivateClamshell()
            stopPowerMonitoring()
        }
    }
    
    private func activateClamshell() {
        guard !isClamshellActive else { return }
        
        // 1. Create IOKit PreventSystemSleep assertion
        if clamshellAssertionID == 0 {
            let reason = "Arken Clamshell Keep Awake" as CFString
            _ = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventSystemSleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                reason,
                &clamshellAssertionID
            )
        }
        
        // 2. Apply pmset -a disablesleep 1 (the ONLY way macOS allows closed-lid operation without external monitor)
        applyDisableSleep(enabled: true)
        
        isClamshellActive = true
    }
    
    private func deactivateClamshell(sync: Bool = false) {
        // 1. Release IOKit assertion
        if clamshellAssertionID != 0 {
            IOPMAssertionRelease(clamshellAssertionID)
            clamshellAssertionID = 0
        }
        
        // 2. Restore pmset -a disablesleep 0
        if isDisablesleepApplied || isClamshellActive {
            applyDisableSleep(enabled: false, sync: sync)
        }
        
        isClamshellActive = false
    }
    
    private func applyDisableSleep(enabled: Bool, sync: Bool = false) {
        let work = { [weak self] in
            guard let self = self else { return }
            let cmd = enabled ? "clamshell-enable" : "clamshell-disable"
            let val = enabled ? "1" : "0"
            
            // Tier 1: Try running via SUID palantir-power-helper directly
            if FileManager.default.fileExists(atPath: self.helperPath) {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: self.helperPath)
                proc.arguments = [cmd]
                let pipe = Pipe()
                proc.standardOutput = pipe
                
                if (try? proc.run()) != nil {
                    proc.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let out = String(data: data, encoding: .utf8) ?? ""
                    if proc.terminationStatus == 0 && (out.contains("CLAMSHELL_ENABLED") || out.contains("CLAMSHELL_DISABLED")) {
                        self.isDisablesleepApplied = enabled
                        return
                    }
                }
            }
            
            // Tier 2: Try running via sudoers (ALL ALL = NOPASSWD: /usr/local/bin/palantir-power-helper)
            let sudoProc = Process()
            sudoProc.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
            sudoProc.arguments = ["-n", self.helperPath, cmd]
            let sudoPipe = Pipe()
            sudoProc.standardOutput = sudoPipe
            if (try? sudoProc.run()) != nil {
                sudoProc.waitUntilExit()
                let sData = sudoPipe.fileHandleForReading.readDataToEndOfFile()
                let sOut = String(data: sData, encoding: .utf8) ?? ""
                if sudoProc.terminationStatus == 0 && (sOut.contains("CLAMSHELL_ENABLED") || sOut.contains("CLAMSHELL_DISABLED")) {
                    self.isDisablesleepApplied = enabled
                    return
                }
            }
            
            // Tier 3: Privileged AppleScript execution (and update/install helper if needed)
            guard !self.isExecutingPrivileged else { return }
            self.isExecutingPrivileged = true
            defer { self.isExecutingPrivileged = false }
            
            var bundledHelper = Bundle.main.bundlePath + "/Contents/Resources/arken-power-helper"
            if !FileManager.default.fileExists(atPath: bundledHelper) {
                bundledHelper = Bundle.main.bundlePath + "/Contents/Resources/palantir-power-helper"
            }
            var scriptCmd = "/usr/bin/pmset -a disablesleep \(val)"
            if FileManager.default.fileExists(atPath: bundledHelper) {
                scriptCmd = "mkdir -p /usr/local/bin && cp '\(bundledHelper)' /usr/local/bin/arken-power-helper && chown root:wheel /usr/local/bin/arken-power-helper && chmod 4755 /usr/local/bin/arken-power-helper && ln -sf /usr/local/bin/arken-power-helper /usr/local/bin/palantir-power-helper && mkdir -p /private/etc/sudoers.d && printf 'ALL ALL = NOPASSWD: /usr/local/bin/arken-power-helper\\nALL ALL = NOPASSWD: /usr/local/bin/palantir-power-helper\\n' > /private/etc/sudoers.d/arken-power && chmod 440 /private/etc/sudoers.d/arken-power && /usr/bin/pmset -a disablesleep \(val)"
            }
            
            let appleScript = "do shell script \"\(scriptCmd)\" with administrator privileges"
            if let script = NSAppleScript(source: appleScript) {
                var err: NSDictionary?
                script.executeAndReturnError(&err)
                DispatchQueue.main.async {
                    if err == nil {
                        self.isDisablesleepApplied = enabled
                        self.isClamshellAuthRequired = false
                    } else {
                        // User cancelled or authorization failed:
                        // Immediately disable clamshell and mark auth required to prevent infinite loops!
                        self.isDisablesleepApplied = false
                        self.isClamshellEnabled = false
                        self.isClamshellActive = false
                        self.isClamshellAuthRequired = true
                        UserDefaults.standard.set(false, forKey: "ArkenClamshellEnabled")
                        self.stopPowerMonitoring()
                    }
                }
            }
        }
        
        if sync {
            work()
        } else {
            DispatchQueue.global(qos: .userInitiated).async(execute: work)
        }
    }
    
    private func startPowerMonitoringIfNeeded() {
        guard isClamshellEnabled, powerCheckTimer == nil else { return }
        let timer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
            self?.updateClamshellState()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.powerCheckTimer = timer
    }
    
    private func stopPowerMonitoring() {
        powerCheckTimer?.invalidate()
        powerCheckTimer = nil
    }
    
    public static func checkExternalPower() -> Bool {
        var iter: io_iterator_t = 0
        let serviceMatch = IOServiceMatching("AppleSmartBattery")
        let status = IOServiceGetMatchingServices(kIOMainPortDefault, serviceMatch, &iter)
        guard status == KERN_SUCCESS else { return true }
        defer { IOObjectRelease(iter) }
        
        let service = IOIteratorNext(iter)
        guard service != 0 else { return true } // Desktop Macs (iMac, Mac mini, Mac Studio)
        defer { IOObjectRelease(service) }
        
        var props: Unmanaged<CFMutableDictionary>?
        if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
           let dict = props?.takeRetainedValue() as? [String: Any] {
            if let external = dict["ExternalConnected"] as? Bool {
                return external
            }
            if let rawExternal = dict["AppleRawExternalConnected"] as? Bool {
                return rawExternal
            }
        }
        return false
    }
}
