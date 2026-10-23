import SwiftUI

public enum StatusBarDisplayMode: String, CaseIterable, Identifiable {
    // Single Metrics
    case iconOnly = "iconOnly"
    case cpuOnly = "cpuOnly"
    case ramOnly = "ramOnly"
    case thermals = "thermals"
    case battery = "battery"
    case watts = "watts"
    case network = "network"
    
    // Combos & Multi-metrics
    case cpuAndRam = "cpuAndRam"
    case cpuAndTemp = "cpuAndTemp"
    case ramAndTemp = "ramAndTemp"
    case cpuRamTemp = "cpuRamTemp"
    case netAndCpu = "netAndCpu"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .iconOnly: return L10n.tr("Icon Only", "Sadece Simge")
        case .cpuOnly: return L10n.tr("CPU Only (12%)", "Sadece CPU (%12)")
        case .ramOnly: return L10n.tr("RAM Only (54%)", "Sadece RAM (%54)")
        case .thermals: return L10n.tr("Temperature (45°C)", "Sıcaklık (45°C)")
        case .battery: return L10n.tr("Battery & Power (85% | 14W)", "Pil ve Güç (%85 | 14W)")
        case .watts: return L10n.tr("Power Draw (14W)", "Güç Tüketimi (14W)")
        case .network: return L10n.tr("Network Speed (↓ 1.2M ↑ 80K)", "Ağ Hızı (↓ 1.2M ↑ 80K)")
        case .cpuAndRam: return L10n.tr("CPU & RAM (12% | 54%)", "CPU ve RAM (%12 | %54)")
        case .cpuAndTemp: return L10n.tr("CPU & Temp (12% | 45°C)", "CPU ve Sıcaklık (%12 | 45°C)")
        case .ramAndTemp: return L10n.tr("RAM & Temp (54% | 45°C)", "RAM ve Sıcaklık (%54 | 45°C)")
        case .cpuRamTemp: return L10n.tr("CPU, RAM & Temp (12% | 54% | 45°)", "CPU, RAM ve Sıcaklık (%12 | %54 | 45°)")
        case .netAndCpu: return L10n.tr("Network & CPU (↓ 1.2M | 12%)", "Ağ ve CPU (↓ 1.2M | %12)")
        }
    }
}

public class SettingsStore: ObservableObject {
    public static let shared = SettingsStore()
    
    private var isInitialized = false
    
    @Published public var displayMode: StatusBarDisplayMode = .cpuAndRam {
        didSet {
            UserDefaults.standard.set(displayMode.rawValue, forKey: "ArkenDisplayMode")
            guard isInitialized else { return }
            DispatchQueue.main.async {
                StatusBarController.shared?.updateButtonContent()
            }
        }
    }
    
    @Published public var autoCloseShelf: Bool = true {
        didSet {
            UserDefaults.standard.set(autoCloseShelf, forKey: "ArkenAutoCloseShelf")
        }
    }
    
    @Published public var temperatureUnit: TemperatureUnit = .celsius {
        didSet {
            UserDefaults.standard.set(temperatureUnit.rawValue, forKey: "ArkenTemperatureUnit")
            guard isInitialized else { return }
            HardwareMonitor.shared?.temperatureUnit = temperatureUnit
            DispatchQueue.main.async {
                StatusBarController.shared?.updateButtonContent()
            }
        }
    }
    
    public init() {
        if let saved = UserDefaults.standard.string(forKey: "ArkenDisplayMode") ?? UserDefaults.standard.string(forKey: "PalantirDisplayMode"),
           let mode = StatusBarDisplayMode(rawValue: saved) {
            self.displayMode = mode
        }
        if let autoClose = UserDefaults.standard.object(forKey: "ArkenAutoCloseShelf") as? Bool {
            self.autoCloseShelf = autoClose
        } else if let legacyAutoClose = UserDefaults.standard.object(forKey: "PalantirAutoCloseShelf") as? Bool {
            self.autoCloseShelf = legacyAutoClose
        }
        if let savedUnit = UserDefaults.standard.string(forKey: "ArkenTemperatureUnit") ?? UserDefaults.standard.string(forKey: "PalantirTemperatureUnit"),
           let unit = TemperatureUnit(rawValue: savedUnit) {
            self.temperatureUnit = unit
        }
        self.isInitialized = true
    }
}

public struct SettingsTab: View {
    @ObservedObject var settings = SettingsStore.shared
    @ObservedObject var keepAwake = KeepAwakeEngine.shared
    @ObservedObject var launchAtLogin = LaunchAtLoginEngine.shared
    @ObservedObject var l10n = LocalizationManager.shared
    @ObservedObject var sound = SoundManager.shared
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 10) {
            // Language Selection Card
            GlassCard(padding: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "globe")
                        .foregroundColor(ArkenTheme.accentColor)
                        .font(.system(size: 15))
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(L10n.tr("Language", "Dil"))
                            .font(.system(size: 11, weight: .bold))
                        Text(L10n.tr("Choose interface language", "Arayüz dilini seçin"))
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Picker("", selection: Binding(
                        get: { l10n.language },
                        set: { l10n.setLanguage($0) }
                    )) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: 130)
                }
            }
            
            // Keep Awake Control
            GlassCard(padding: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "cup.and.saucer.fill")
                            .foregroundColor(keepAwake.isActive ? ArkenTheme.tempColor : .secondary)
                            .font(.system(size: 15))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(L10n.tr("Keep Awake", "Uyanık Tut (Caffeine)"))
                                .font(.system(size: 11, weight: .bold))
                            Text(keepAwake.isActive 
                                 ? L10n.tr("Screen & system sleep prevented", "Ekran ve sistem uykusu engellendi") 
                                 : L10n.tr("System in normal sleep mode", "Sistem normal uyku modunda"))
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { keepAwake.isActive },
                            set: { _ in keepAwake.toggle() }
                        ))
                        .toggleStyle(SwitchToggleStyle(tint: ArkenTheme.tempColor))
                        .labelsHidden()
                    }
                    
                    if keepAwake.isActive {
                        HStack(spacing: 6) {
                            ForEach(KeepAwakeDuration.allCases) { dur in
                                Button(action: {
                                    keepAwake.activate(duration: dur)
                                }) {
                                    Text(dur.title)
                                        .font(.system(size: 9, weight: .medium))
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .background(keepAwake.selectedDuration == dur ? ArkenTheme.tempColor.opacity(0.25) : Color.white.opacity(0.06))
                                        .foregroundColor(keepAwake.selectedDuration == dur ? ArkenTheme.tempColor : .secondary)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    
                    Divider().background(Color.white.opacity(0.1))
                    
                    // Clamshell Mode (Lid Closed)
                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: "macbook.and.ipad")
                            .foregroundColor(keepAwake.isClamshellActive ? ArkenTheme.tempColor : (keepAwake.isClamshellEnabled ? Color.orange : .secondary))
                            .font(.system(size: 14))
                        
                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 4) {
                                Text(L10n.tr("Clamshell Mode (Lid-Closed Awake)", "Kapak Kapalıyken Uyanık Tut"))
                                    .font(.system(size: 10, weight: .bold))
                                
                                Text(L10n.tr("⚡️ AC Required", "⚡️ Şarjda"))
                                    .font(.system(size: 8, weight: .semibold))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.orange.opacity(0.2))
                                    .foregroundColor(.orange)
                                    .clipShape(Capsule())
                            }
                            
                            if keepAwake.isClamshellEnabled {
                                if keepAwake.isClamshellActive {
                                    Text(L10n.tr("Active: Mac stays awake with lid closed (AC connected)", "Devrede: Kapak kapatıldığında Mac uyanık kalır (Adaptör bağlı)"))
                                        .font(.system(size: 8))
                                        .foregroundColor(.green)
                                } else {
                                    Text(L10n.tr("Safety Engaged: Connect power adapter to prevent lid sleep", "Güvenlik Kilidi: Çantada ısınmayı önlemek için yalnızca şarjda çalışır"))
                                        .font(.system(size: 8))
                                        .foregroundColor(Color.orange)
                                }
                            } else {
                                Text(L10n.tr("Prevents sleep when lid is closed (e.g. downloads, server)", "Kapak kapalıyken uykuya geçmeyi engeller (indirmeler, sunucu)"))
                                    .font(.system(size: 8))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { keepAwake.isClamshellEnabled },
                            set: { keepAwake.setClamshellEnabled($0) }
                        ))
                        .toggleStyle(SwitchToggleStyle(tint: ArkenTheme.tempColor))
                        .labelsHidden()
                    }
                }
            }
            
            // Menu Bar Appearance
            GlassCard(padding: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "menubar.rectangle")
                        .foregroundColor(ArkenTheme.cpuColor)
                        .font(.system(size: 14))
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(L10n.tr("Menu Bar Appearance", "Menü Çubuğu Görünümü"))
                            .font(.system(size: 11, weight: .bold))
                        Text(L10n.tr("Metric displayed on status bar", "Durum çubuğunda gösterilen metrik"))
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Picker("", selection: $settings.displayMode) {
                        ForEach(StatusBarDisplayMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: 185)
                }
            }
            
            // Temperature Unit Selection (Celsius vs Fahrenheit)
            GlassCard(padding: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "thermometer.medium")
                        .foregroundColor(ArkenTheme.tempColor)
                        .font(.system(size: 15))
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(L10n.tr("Temperature Unit", "Sıcaklık Birimi"))
                            .font(.system(size: 11, weight: .bold))
                        Text(L10n.tr("Celsius (°C) or Fahrenheit (°F)", "Santigrat (°C) veya Fahrenhayt (°F)"))
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Picker("", selection: $settings.temperatureUnit) {
                        ForEach(TemperatureUnit.allCases) { unit in
                            Text(unit.fullTitle).tag(unit)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(maxWidth: 175)
                }
            }
            
            // Sound Effects Setting
            GlassCard(padding: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: sound.isSoundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            .foregroundColor(sound.isSoundEnabled ? ArkenTheme.tempColor : .secondary)
                            .font(.system(size: 15))
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text(L10n.tr("Sound Effects", "Ses Efektleri"))
                                .font(.system(size: 11, weight: .bold))
                            Text(sound.isSoundEnabled 
                                 ? L10n.tr("Audio feedback enabled", "Eylem ve işlem sesleri açık") 
                                 : L10n.tr("All sounds muted", "Tüm uygulama sesleri kapalı"))
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $sound.isSoundEnabled)
                            .toggleStyle(SwitchToggleStyle(tint: ArkenTheme.tempColor))
                            .labelsHidden()
                    }
                    
                    if sound.isSoundEnabled {
                        Divider().background(Color.white.opacity(0.1))
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(L10n.tr("Sound Scheme", "Ses Teması"))
                                    .font(.system(size: 10, weight: .semibold))
                                Text(sound.selectedScheme.title)
                                    .font(.system(size: 8.5))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Picker("", selection: $sound.selectedScheme) {
                                ForEach(SoundScheme.allCases) { scheme in
                                    Text(scheme.title).tag(scheme)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .frame(maxWidth: 160)
                            
                            Button(action: {
                                sound.testPlay(.success)
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "play.fill")
                                    Text(L10n.tr("Test", "Dene"))
                                }
                                .font(.system(size: 9, weight: .semibold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
            
            // Launch at Login Setting
            GlassCard(padding: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "power.circle.fill")
                        .foregroundColor(launchAtLogin.isEnabled ? ArkenTheme.cpuColor : .secondary)
                        .font(.system(size: 15))
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(L10n.tr("Launch at Login", "Girişte Otomatik Başlat"))
                            .font(.system(size: 11, weight: .bold))
                        Text(launchAtLogin.isEnabled 
                             ? L10n.tr("Starts automatically on boot (LaunchAgent)", "Mac açıldığında otomatik başlar (LaunchAgent)") 
                             : L10n.tr("Disabled — Launched manually", "Kapalı — Manuel olarak başlatılır"))
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: Binding(
                        get: { launchAtLogin.isEnabled },
                        set: { launchAtLogin.setEnabled($0) }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: ArkenTheme.cpuColor))
                    .labelsHidden()
                }
            }
            
            // Drop Shelf Behavior Setting
            GlassCard(padding: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "hand.draw.fill")
                            .foregroundColor(ArkenTheme.accentColor)
                            .font(.system(size: 14))
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text(L10n.tr("Shelf Drag Action", "Dosya Rafı Sürükleme Eylemi"))
                                .font(.system(size: 11, weight: .bold))
                            Text(DropShelfEngine.shared.dragMode == .copy 
                                 ? L10n.tr("Copy (Safe): Original file is preserved", "Kopyala (Güvenli): Orijinal dosya korunur") 
                                 : L10n.tr("Move (Cut): File is moved to destination", "Taşı (Kes): Dosya yeni yerine taşınır"))
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Picker("", selection: Binding(
                            get: { DropShelfEngine.shared.dragMode },
                            set: { DropShelfEngine.shared.dragMode = $0 }
                        )) {
                            Text(L10n.tr("📋 Copy", "📋 Kopyala")).tag(ShelfDragMode.copy)
                            Text(L10n.tr("✂️ Move", "✂️ Taşı")).tag(ShelfDragMode.move)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(width: 145)
                    }
                    
                    Divider().background(Color.white.opacity(0.08))
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(L10n.tr("Remove from Shelf on Move", "Taşındığında Raftan Kaldır"))
                                .font(.system(size: 10, weight: .medium))
                            Text(L10n.tr("Files dropped in move mode are cleared from shelf", "Taşıma modunda hedef yere bırakılan dosya raftan silinir"))
                                .font(.system(size: 8.5))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { DropShelfEngine.shared.removeOnMove },
                            set: { DropShelfEngine.shared.removeOnMove = $0 }
                        ))
                        .toggleStyle(SwitchToggleStyle(tint: ArkenTheme.accentColor))
                        .labelsHidden()
                    }
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(L10n.tr("Auto-close Shelf when Empty", "Rafı Otomatik Kapat"))
                                .font(.system(size: 10, weight: .medium))
                            Text(L10n.tr("Shelf window closes when all files are cleared", "Tüm dosyalar raftan temizlenince pencere kapanır"))
                                .font(.system(size: 8.5))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $settings.autoCloseShelf)
                            .toggleStyle(SwitchToggleStyle(tint: ArkenTheme.accentColor))
                            .labelsHidden()
                    }
                }
            }
            
            // About & System Info
            GlassCard(padding: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("ArkenStone for macOS")
                            .font(.system(size: 10, weight: .bold))
                        Text(AppInfo.formattedVersion)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(ArkenTheme.cpuColor)
                        Spacer()
                        Text("Apple Silicon Native")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    Text(L10n.tr("Native macOS menu bar command center combining hardware charging bypass, screen OCR, port manager, scratchpad, hardware monitor, and clipboard history in one lightweight app.", "Donanımsal şarj kesici, ekran OCR, port yöneticisi, karalama defteri, donanım monitörü ve pano geçmişini tek hafif potada birleştiren yerel macOS aracı."))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
