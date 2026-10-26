import SwiftUI

public struct BatteryTab: View {
    @ObservedObject var monitor: HardwareMonitor
    @ObservedObject var powerGuard = PowerGuardEngine.shared
    @ObservedObject var l10n = LocalizationManager.shared
    
    public init(monitor: HardwareMonitor) {
        self.monitor = monitor
    }
    
    public var body: some View {
        if !monitor.battery.hasBattery {
            // Desktop Mac AC Direct Power View
            VStack(spacing: 12) {
                GlassCard(padding: 20) {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(ArkenTheme.batteryColor.opacity(0.15))
                                .frame(width: 56, height: 56)
                            Image(systemName: "powerplug.fill")
                                .font(.system(size: 26))
                                .foregroundColor(ArkenTheme.batteryColor)
                        }
                        
                        Text(L10n.tr("Desktop Direct Power (AC Line)", "Masaüstü Doğrudan Güç (AC)"))
                            .font(.system(size: 14, weight: .bold))
                        
                        Text(L10n.tr("This Mac (\(monitor.macModel)) is powered directly by AC mains. No internal battery detected.", "Bu Mac (\(monitor.macModel)) prize doğrudan bağlı çalışır. Dahili pil donanımı bulunmamaktadır."))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        HStack(spacing: 16) {
                            PowerDetailPill(title: L10n.tr("Device Type", "Cihaz Türü"), value: monitor.macModel, icon: "desktopcomputer")
                            PowerDetailPill(title: L10n.tr("Architecture", "Mimari"), value: monitor.chipName, icon: "cpu")
                            PowerDetailPill(title: L10n.tr("Power Status", "Güç Durumu"), value: L10n.tr("Continuous AC", "Sürekli AC"), icon: "bolt.fill")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        } else {
            VStack(spacing: 12) {
                // Main Gauge & Status
            GlassCard(padding: 12) {
                HStack(spacing: 16) {
                    CircularProgress(
                        value: Double(monitor.battery.percentage),
                        gradient: ArkenTheme.batteryGradient,
                        size: 80,
                        lineWidth: 8,
                        icon: monitor.battery.isCharging ? "bolt.fill" : "battery.100percent",
                        label: monitor.battery.isCharging ? L10n.tr("Charging", "Şarj Ediliyor") : (monitor.battery.isPluggedIn ? L10n.tr("On AC Power", "Adaptörde") : L10n.tr("On Battery", "Pilde"))
                    )
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(monitor.battery.isPluggedIn ? L10n.tr("Power Adapter Connected", "Güç Adaptörü Bağlı") : L10n.tr("Battery Power", "Pil Gücü"))
                                .font(.system(size: 13, weight: .bold))
                            Spacer()
                            Text(monitor.battery.condition)
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(ArkenTheme.batteryColor.opacity(0.2))
                                .foregroundColor(ArkenTheme.batteryColor)
                                .clipShape(Capsule())
                        }
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.tr("Charging Power:", "Şarj Gücü:"))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.2f W", monitor.battery.watts))
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(ArkenTheme.batteryColor)
                            }
                            Spacer()
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.tr("Adapter:", "Adaptör:"))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Text(monitor.battery.adapterWatts > 0 ? "\(monitor.battery.adapterWatts)W" : L10n.tr("None", "Yok"))
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            Spacer()
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.tr("Cycle Count:", "Döngü:"))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Text("\(monitor.battery.cycleCount)")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                        }
                    }
                }
            }
            
            // Power Guard (Hardware Charge Limiter & Bypass)
            GlassCard(padding: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                            .foregroundColor(ArkenTheme.batteryColor)
                            .font(.system(size: 15))
                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 6) {
                                Text(L10n.tr("Arken Power Guard (Charge Limit)", "Arken Power Guard (Şarj Sınırı)"))
                                    .font(.system(size: 11, weight: .bold))
                                
                                if powerGuard.isHelperInstalled {
                                    Text(L10n.tr("HARDWARE SMC", "DONANIM SMC"))
                                        .font(.system(size: 7, weight: .black))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(ArkenTheme.batteryColor.opacity(0.2))
                                        .foregroundColor(ArkenTheme.batteryColor)
                                        .clipShape(Capsule())
                                } else {
                                    Text(L10n.tr("AUTH REQUIRED", "İZİN GEREKLİ"))
                                        .font(.system(size: 7, weight: .black))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(ArkenTheme.tempColor.opacity(0.2))
                                        .foregroundColor(ArkenTheme.tempColor)
                                        .clipShape(Capsule())
                                }
                            }
                            Text(L10n.tr("Apple Silicon PMU hardware battery charge limiter & bypass", "Apple Silicon PMU donanımsal şarj kesici"))
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $powerGuard.isEnabled)
                            .toggleStyle(SwitchToggleStyle(tint: ArkenTheme.batteryColor))
                            .labelsHidden()
                    }
                    
                    if powerGuard.isEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(L10n.tr("Target Charge Limit:", "Hedef Şarj Sınırı:"))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("%\(powerGuard.targetLimit)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(ArkenTheme.batteryColor)
                            }
                            
                            Slider(value: Binding(
                                get: { Double(powerGuard.targetLimit) },
                                set: { powerGuard.targetLimit = Int($0) }
                            ), in: 50...90, step: 5)
                            .accentColor(ArkenTheme.batteryColor)
                            
                            // Hardware Bypass Status Banner
                            if powerGuard.isHelperInstalled {
                                if powerGuard.isBypassActive || monitor.battery.percentage >= powerGuard.targetLimit {
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark.shield.fill")
                                            .foregroundColor(.green)
                                            .font(.system(size: 12))
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(L10n.tr("Hardware Bypass Active! Charging Stopped.", "Donanımsal Bypass Aktif! Şarj Kesildi."))
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundColor(.green)
                                            Text(L10n.tr("Mac is running directly on AC adapter; battery is not being charged.", "Mac doğrudan adaptörden besleniyor, bataryaya akım gitmiyor."))
                                                .font(.system(size: 8))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.green.opacity(0.12))
                                    .cornerRadius(8)
                                } else {
                                    HStack(spacing: 4) {
                                        Image(systemName: "bolt.fill")
                                            .foregroundColor(ArkenTheme.batteryColor)
                                            .font(.system(size: 10))
                                        Text(LocalizationManager.shared.language == .tr
                                             ? "Hedefe %\(powerGuard.targetLimit - monitor.battery.percentage) kaldı. %\(powerGuard.targetLimit) olunca şarj donanımsal olarak durdurulacak."
                                             : "\(powerGuard.targetLimit - monitor.battery.percentage)% remaining to target. Charging will stop at \(powerGuard.targetLimit)%.")
                                            .font(.system(size: 9))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                // Top-Up to 100% Quick Button
                                Button(action: {
                                    powerGuard.toggleTopUp()
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: powerGuard.isTopUpActive ? "bolt.circle.fill" : "bolt.badge.automatic")
                                            .foregroundColor(powerGuard.isTopUpActive ? .yellow : .primary)
                                            .font(.system(size: 10, weight: .bold))
                                        Text(powerGuard.isTopUpActive 
                                             ? L10n.tr("⚡ Top-Up Active (Charging to 100%)", "⚡ Tam Şarj Aktif (%100'e Doluyor)")
                                             : L10n.tr("⚡ Top-Up to 100% (One-Time Full Charge)", "⚡ %100 Tam Şarj (Tek Seferlik)"))
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(powerGuard.isTopUpActive ? .yellow : .primary)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .frame(maxWidth: .infinity)
                                    .background(powerGuard.isTopUpActive ? Color.yellow.opacity(0.18) : Color.white.opacity(0.06))
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(powerGuard.isTopUpActive ? Color.yellow.opacity(0.5) : Color.white.opacity(0.12), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            } else {
                                // Authorization Required Card
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 5) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(ArkenTheme.tempColor)
                                            .font(.system(size: 11))
                                        Text(L10n.tr("Authorization Required for Hardware Limiter", "Donanımsal Kesme İçin Yetkilendirme Gerekli"))
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(ArkenTheme.tempColor)
                                    }
                                    
                                    Text(L10n.tr("To disconnect hardware charge circuit, macOS requires a one-time administrator authorization (Touch ID / Password).", "Anakart şarj devresini kapatabilmek için macOS bir kerelik yönetici izni (Touch ID / Şifre) talep eder."))
                                        .font(.system(size: 8))
                                        .foregroundColor(.secondary)
                                    
                                    Button(action: {
                                        powerGuard.installHelper()
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "lock.open.fill")
                                            Text(powerGuard.isInstallingHelper ? L10n.tr("Authorizing...", "Yetkilendiriliyor...") : L10n.tr("Authorize Hardware Limiter", "Donanımsal Kesmeyi Yetkilendir"))
                                        }
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(ArkenTheme.batteryColor)
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .disabled(powerGuard.isInstallingHelper)
                                }
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(ArkenTheme.tempColor.opacity(0.08))
                                .cornerRadius(8)
                            }
                        }
                        .padding(.top, 2)
                    }
                }
            }
            
            // Power Electrical Details (Volt, Amp, Watt)
            GlassCard(padding: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Label(L10n.tr("Electrical Power Metrics", "Elektriksel Güç Metrikleri"), systemImage: "bolt.badge.clock.fill")
                        .font(.system(size: 11, weight: .semibold))
                    
                    HStack {
                        PowerDetailPill(title: L10n.tr("Voltage", "Gerilim (Volt)"), value: String(format: "%.2f V", monitor.battery.voltage), icon: "gauge.with.needle")
                        Spacer()
                        PowerDetailPill(title: L10n.tr("Current", "Akım (Amper)"), value: String(format: "%.3f A", monitor.battery.amperage), icon: "waveform.path")
                        Spacer()
                        PowerDetailPill(title: L10n.tr("Power", "Güç (Watt)"), value: String(format: "%.2f W", monitor.battery.watts), icon: "bolt.fill")
                    }
                }
            }
            
            // Battery Health & Longevity
            GlassCard(padding: 10) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.tr("Battery Health (Max Capacity)", "Pil Sağlığı (Maksimum Kapasite)"))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text(String(format: "%.1f%%", monitor.battery.healthPercentage))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(monitor.battery.healthPercentage > 80 ? ArkenTheme.batteryColor : ArkenTheme.tempColor)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(L10n.tr("Battery Temperature", "Pil Sıcaklığı"))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text(monitor.formatTemperature(monitor.battery.temperature, decimals: 1))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                }
            }
        }
    }
}
}

struct PowerDetailPill: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(ArkenTheme.batteryColor)
                Text(value)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
            }
        }
        .frame(maxWidth: .infinity)
    }
}
