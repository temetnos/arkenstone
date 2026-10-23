import Foundation
import AppKit
import UserNotifications
import Combine

public class PowerGuardEngine: ObservableObject {
    public static let shared = PowerGuardEngine()
    
    @Published public var isEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "ArkenPowerGuardEnabled")
            if !isEnabled && isBypassActive {
                startHardwareCharging()
            }
        }
    }
    
    @Published public var targetLimit: Int = 80 {
        didSet {
            UserDefaults.standard.set(targetLimit, forKey: "ArkenPowerGuardTarget")
        }
    }
    
    @Published public var isLimitReached: Bool = false
    @Published public var isBypassActive: Bool = false
    @Published public var isHelperInstalled: Bool = false
    @Published public var isInstallingHelper: Bool = false
    @Published public var helperStatusMessage: String = ""
    @Published public var playSoundOnLimit: Bool = true
    @Published public var sendNotificationOnLimit: Bool = true
    
    private var helperPath: String {
        if FileManager.default.fileExists(atPath: "/usr/local/bin/arken-power-helper") {
            return "/usr/local/bin/arken-power-helper"
        }
        return "/usr/local/bin/palantir-power-helper"
    }
    private var lastNotifiedPercentage: Int = 0
    
    public init() {
        if let savedEnabled = UserDefaults.standard.object(forKey: "ArkenPowerGuardEnabled") as? Bool {
            self.isEnabled = savedEnabled
        } else if let legacyEnabled = UserDefaults.standard.object(forKey: "PalantirPowerGuardEnabled") as? Bool {
            self.isEnabled = legacyEnabled
        }
        let savedTarget = UserDefaults.standard.integer(forKey: "ArkenPowerGuardTarget")
        let legacyTarget = UserDefaults.standard.integer(forKey: "PalantirPowerGuardTarget")
        let target = savedTarget > 0 ? savedTarget : legacyTarget
        if target >= 50 && target <= 95 {
            self.targetLimit = target
        }
        
        requestNotificationPermission()
        checkHelperStatus()
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
    
    public func checkHelperStatus() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            
            let fileExists = FileManager.default.fileExists(atPath: self.helperPath)
            if !fileExists {
                DispatchQueue.main.async {
                    self.isHelperInstalled = false
                    self.helperStatusMessage = L10n.tr("SMC Helper Not Installed", "SMC Helper Kurulu Değil")
                }
                return
            }
            
            // Test check-root
            let process = Process()
            process.executableURL = URL(fileURLWithPath: self.helperPath)
            process.arguments = ["check-root"]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            
            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                
                let isRootOk = (process.terminationStatus == 0) && (output == "ROOT_OK")
                
                // Also check status if root is ok
                var bypass = false
                if isRootOk {
                    let statusProcess = Process()
                    statusProcess.executableURL = URL(fileURLWithPath: self.helperPath)
                    statusProcess.arguments = ["status"]
                    let statusPipe = Pipe()
                    statusProcess.standardOutput = statusPipe
                    try? statusProcess.run()
                    statusProcess.waitUntilExit()
                    let sData = statusPipe.fileHandleForReading.readDataToEndOfFile()
                    let sOut = String(data: sData, encoding: .utf8) ?? ""
                    bypass = (statusProcess.terminationStatus == 0 && sOut.contains("BYPASS_ACTIVE"))
                }
                
                DispatchQueue.main.async {
                    self.isHelperInstalled = isRootOk
                    self.isBypassActive = bypass
                    let activeMsg = bypass 
                        ? L10n.tr("Bypass Active (Charging Disconnected)", "Bypass Devrede (Şarj Kesik)")
                        : L10n.tr("Hardware Protection Ready", "Donanımsal Koruma Hazır")
                    self.helperStatusMessage = isRootOk ? activeMsg : L10n.tr("Authorization Required", "Yetkilendirme Gerekli")
                }
            } catch {
                DispatchQueue.main.async {
                    self.isHelperInstalled = false
                    self.helperStatusMessage = L10n.tr("Helper Failed to Execute", "Helper Çalıştırılamadı")
                }
            }
        }
    }
    
    public func installHelper(completion: ((Bool, String) -> Void)? = nil) {
        guard !isInstallingHelper else { return }
        isInstallingHelper = true
        helperStatusMessage = L10n.tr("Waiting for administrator approval...", "Yönetici onayı bekleniyor...")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Stage helper in /tmp first (world-accessible, avoiding Documents TCC restrictions)
            var bundledHelper = Bundle.main.bundlePath + "/Contents/Resources/arken-power-helper"
            if !FileManager.default.fileExists(atPath: bundledHelper) {
                bundledHelper = Bundle.main.bundlePath + "/Contents/Resources/palantir-power-helper"
            }
            let tempHelper = "/tmp/arken-power-helper"
            
            if FileManager.default.fileExists(atPath: bundledHelper) {
                try? FileManager.default.removeItem(atPath: tempHelper)
                try? FileManager.default.copyItem(atPath: bundledHelper, toPath: tempHelper)
                try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempHelper)
            }
            
            let installCmd = "mkdir -p /usr/local/bin && cp /tmp/arken-power-helper /usr/local/bin/arken-power-helper && chown root:wheel /usr/local/bin/arken-power-helper && chmod 4755 /usr/local/bin/arken-power-helper && ln -sf /usr/local/bin/arken-power-helper /usr/local/bin/palantir-power-helper && mkdir -p /private/etc/sudoers.d && printf 'ALL ALL = NOPASSWD: /usr/local/bin/arken-power-helper\\nALL ALL = NOPASSWD: /usr/local/bin/palantir-power-helper\\n' > /private/etc/sudoers.d/arken-power && chmod 440 /private/etc/sudoers.d/arken-power"
            
            let appleScript = "do shell script \"\(installCmd)\" with administrator privileges"
            var error: NSDictionary?
            
            if let scriptObject = NSAppleScript(source: appleScript) {
                let output = scriptObject.executeAndReturnError(&error)
                DispatchQueue.main.async {
                    self.isInstallingHelper = false
                    if error == nil {
                        self.checkHelperStatus()
                        SoundManager.shared.play(.success)
                        completion?(true, output.stringValue ?? L10n.tr("Installed successfully!", "Başarıyla kuruldu!"))
                    } else {
                        let errMsg = error?[NSAppleScript.errorMessage] as? String ?? L10n.tr("Cancelled", "İptal edildi")
                        self.helperStatusMessage = L10n.tr("Authorization Failed: \(errMsg)", "Yetkilendirme Başarısız: \(errMsg)")
                        self.checkHelperStatus()
                        completion?(false, errMsg)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.isInstallingHelper = false
                    self.helperStatusMessage = L10n.tr("Installation could not start.", "Kurulum başlatılamadı.")
                    completion?(false, L10n.tr("Could not create AppleScript", "AppleScript oluşturulamadı"))
                }
            }
        }
    }
    
    public func stopHardwareCharging() {
        guard isHelperInstalled else { return }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: self.helperPath)
            process.arguments = ["stop"]
            
            do {
                try process.run()
                process.waitUntilExit()
                
                DispatchQueue.main.async {
                    if process.terminationStatus == 0 {
                        self.isBypassActive = true
                        self.helperStatusMessage = L10n.tr("Hardware Bypass Active (Charging Stopped)", "Donanımsal Bypass Aktif (Şarj Kesildi)")
                    }
                }
            } catch {
                // If direct execution fails, try sudo
                self.runWithSudo(args: ["stop"])
            }
        }
    }
    
    public func startHardwareCharging() {
        guard isHelperInstalled else { return }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: self.helperPath)
            process.arguments = ["start"]
            
            do {
                try process.run()
                process.waitUntilExit()
                
                DispatchQueue.main.async {
                    if process.terminationStatus == 0 {
                        self.isBypassActive = false
                        self.helperStatusMessage = L10n.tr("Normal Charging Active", "Normal Şarj Devrede")
                    }
                }
            } catch {
                self.runWithSudo(args: ["start"])
            }
        }
    }
    
    private func runWithSudo(args: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = [helperPath] + args
        try? process.run()
        process.waitUntilExit()
        
        DispatchQueue.main.async {
            if args.contains("stop") {
                self.isBypassActive = true
            } else {
                self.isBypassActive = false
            }
        }
    }
    
    public func checkBattery(battery: BatterySnapshot) {
        guard isEnabled else {
            if isBypassActive {
                startHardwareCharging()
            }
            isLimitReached = false
            return
        }
        
        let current = battery.percentage
        if current >= targetLimit {
            isLimitReached = true
            
            // Trigger hardware stop if not already in bypass
            if !isBypassActive && isHelperInstalled {
                stopHardwareCharging()
            }
            
            // Send alert if we haven't alerted for this charging session yet
            if lastNotifiedPercentage != current {
                lastNotifiedPercentage = current
                notifyUser(currentPercentage: current)
            }
        } else if current < targetLimit - 2 {
            // Re-enable charging when battery drops 2% below limit (hysteresis)
            if isBypassActive {
                startHardwareCharging()
            }
            isLimitReached = false
            lastNotifiedPercentage = 0
        }
    }
    
    private func notifyUser(currentPercentage: Int) {
        if playSoundOnLimit {
            SoundManager.shared.play(.alert)
        }
        
        if sendNotificationOnLimit {
            let content = UNMutableNotificationContent()
            content.title = "🛡️ Arken Power Guard"
            content.subtitle = L10n.tr("Battery reached \(currentPercentage)% target!", "Batarya %\(currentPercentage) hedefine ulaştı!")
            content.body = isHelperInstalled 
                ? L10n.tr("Hardware protection active: Charging halted, Mac running on AC power.", "Donanımsal koruma devrede: Şarj akımı kesildi, Mac adaptör gücüyle çalışıyor.")
                : L10n.tr("Target battery level reached. You can authorize Arken Helper to disconnect charging.", "Hedef şarj seviyesine ulaşıldı. Donanımsal kesme için Arken Helper'ı yetkilendirebilirsiniz.")
            content.sound = .default
            
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        }
    }
}
