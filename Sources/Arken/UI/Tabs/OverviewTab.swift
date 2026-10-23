import SwiftUI

public struct OverviewTab: View {
    @ObservedObject var monitor: HardwareMonitor
    @ObservedObject var keepAwake = KeepAwakeEngine.shared
    @ObservedObject var shelf = DropShelfEngine.shared
    @ObservedObject var powerGuard = PowerGuardEngine.shared
    @ObservedObject var clipboard = ClipboardEngine.shared
    @ObservedObject var l10n = LocalizationManager.shared
    @ObservedObject var desktopFocus = DesktopFocusEngine.shared
    
    public var onSelectTab: ((ArkenTab) -> Void)? = nil
    
    public init(monitor: HardwareMonitor, onSelectTab: ((ArkenTab) -> Void)? = nil) {
        self.monitor = monitor
        self.onSelectTab = onSelectTab
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            // Quick Utility Command Hub (Productivity Tools & System Toggles)
            VStack(spacing: 6) {
                // Tier 1: Productivity Hub (Drop Shelf & Clipboard History)
                HStack(spacing: 8) {
                    // Drop Shelf Card (Navigate to Tab + Popout Floating Shelf)
                    HStack(spacing: 0) {
                        Button(action: {
                            onSelectTab?(.shelf)
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "hand.draw.fill")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(ArkenTheme.accentColor)
                                Text(L10n.tr("Shelf", "Dosya Rafı"))
                                    .font(.system(size: 10.5, weight: .semibold))
                                    .lineLimit(1)
                                
                                if !shelf.items.isEmpty {
                                    Text("\(shelf.items.count)")
                                        .font(.system(size: 8.5, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 4.5)
                                        .padding(.vertical, 1)
                                        .background(ArkenTheme.accentColor)
                                        .clipShape(Capsule())
                                }
                                
                                Spacer(minLength: 2)
                            }
                            .padding(.leading, 9)
                            .padding(.trailing, 6)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help(L10n.tr("Open File Shelf tab", "Dosya Rafı sekmesini aç"))
                        
                        Rectangle()
                            .fill(Color.white.opacity(0.12))
                            .frame(width: 1, height: 14)
                        
                        Button(action: {
                            StatusBarController.shared?.openDetachedShelf()
                        }) {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(ArkenTheme.accentColor)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help(L10n.tr("Open Detached Floating Shelf", "Ayrılabilir Yüzen Dosya Rafını Aç (Always on Top)"))
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(shelf.items.isEmpty ? Color.white.opacity(0.1) : ArkenTheme.accentColor.opacity(0.35), lineWidth: 0.5)
                    )
                    
                    // Clipboard Card (Quick Tab Access)
                    Button(action: {
                        onSelectTab?(.clipboard)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.on.clipboard.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(ArkenTheme.accentColor)
                            Text(L10n.tr("Clipboard", "Pano Geçmişi"))
                                .font(.system(size: 10.5, weight: .semibold))
                                .lineLimit(1)
                            
                            Spacer(minLength: 2)
                            
                            if !clipboard.items.isEmpty {
                                Text("\(clipboard.items.count)")
                                    .font(.system(size: 8.5, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4.5)
                                    .padding(.vertical, 1)
                                    .background(Color.white.opacity(0.2))
                                    .clipShape(Capsule())
                            }
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundColor(.secondary.opacity(0.5))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(L10n.tr("Open Clipboard History tab", "Pano Geçmişi sekmesini aç"))
                }
                
                // Tier 2: Live System Toggles (Keep Awake, Desktop Focus, Power Guard)
                HStack(spacing: 6) {
                    // Keep Awake (Caffeine) Toggle Button
                    Button(action: {
                        keepAwake.toggle()
                    }) {
                        HStack(spacing: 4.5) {
                            Image(systemName: keepAwake.isActive ? "cup.and.saucer.fill" : "cup.and.saucer")
                                .font(.system(size: 10))
                                .foregroundColor(keepAwake.isActive ? ArkenTheme.tempColor : .secondary)
                            Text(keepAwake.isActive ? L10n.tr("Awake", "Uyanık") : L10n.tr("Sleep", "Uykuda"))
                                .font(.system(size: 9.5, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4.5)
                        .background(keepAwake.isActive ? ArkenTheme.tempColor.opacity(0.18) : Color.white.opacity(0.05))
                        .foregroundColor(keepAwake.isActive ? ArkenTheme.tempColor : .primary)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(keepAwake.isActive ? ArkenTheme.tempColor.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(L10n.tr("Prevent system sleep (Caffeine)", "Sistem uykusunu engelle (Caffeine)"))
                    
                    // Desktop Focus Toggle Button
                    Button(action: {
                        desktopFocus.toggleDesktopIcons()
                    }) {
                        HStack(spacing: 4.5) {
                            Image(systemName: desktopFocus.isDesktopHidden ? "eye.slash.fill" : "desktopcomputer")
                                .font(.system(size: 10))
                                .foregroundColor(desktopFocus.isDesktopHidden ? ArkenTheme.tempColor : ArkenTheme.accentColor)
                            Text(desktopFocus.isDesktopHidden ? L10n.tr("Icons Hidden", "Gizli") : L10n.tr("Desktop", "Masaüstü"))
                                .font(.system(size: 9.5, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4.5)
                        .background(desktopFocus.isDesktopHidden ? ArkenTheme.tempColor.opacity(0.18) : Color.white.opacity(0.05))
                        .foregroundColor(desktopFocus.isDesktopHidden ? ArkenTheme.tempColor : .primary)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(desktopFocus.isDesktopHidden ? ArkenTheme.tempColor.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(L10n.tr("Hide or show desktop icons (Focus Mode)", "Masaüstü simgelerini gizle veya göster (Odak Modu)"))
                    
                    // Power Guard Status Pill
                    Button(action: {
                        onSelectTab?(.battery)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: powerGuard.isBypassActive ? "shield.fill" : (powerGuard.isEnabled ? "shield.lefthalf.filled" : "shield"))
                                .font(.system(size: 9.5))
                                .foregroundColor(powerGuard.isBypassActive ? .green : (powerGuard.isEnabled ? ArkenTheme.batteryColor : .secondary))
                            Text(powerGuard.isBypassActive ? "Bypass" : (powerGuard.isEnabled ? (LocalizationManager.shared.language == .tr ? "%\(powerGuard.targetLimit) Sınır" : "\(powerGuard.targetLimit)%") : L10n.tr("Normal", "Normal")))
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundColor(powerGuard.isBypassActive ? .green : (powerGuard.isEnabled ? ArkenTheme.batteryColor : .secondary))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4.5)
                        .background(powerGuard.isBypassActive ? Color.green.opacity(0.15) : (powerGuard.isEnabled ? ArkenTheme.batteryColor.opacity(0.12) : Color.white.opacity(0.05)))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(powerGuard.isBypassActive ? Color.green.opacity(0.35) : (powerGuard.isEnabled ? ArkenTheme.batteryColor.opacity(0.25) : Color.white.opacity(0.08)), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(L10n.tr("Go to Power & Battery Protection settings", "Güç ve Şarj Koruması ayarlarına git"))
                }
            }
            
            // Main 4 Circular Rings
            HStack(spacing: 10) {
                // CPU
                GlassCard(padding: 10) {
                    VStack(spacing: 6) {
                        CircularProgress(
                            value: monitor.cpu.totalUsage,
                            gradient: ArkenTheme.cpuGradient,
                            size: 68,
                            lineWidth: 7,
                            icon: "cpu",
                            label: "CPU"
                        )
                        HStack(spacing: 3) {
                            Image(systemName: "thermometer.medium")
                                .font(.system(size: 9))
                                .foregroundColor(ArkenTheme.tempColor)
                            Text(monitor.formatTemperature(monitor.thermal.cpuTemperature, decimals: 0))
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .contentShape(Rectangle())
                .onTapGesture { onSelectTab?(.cpu) }
                .help(L10n.tr("View CPU and core details", "CPU ve çekirdek detaylarını gör"))
                
                // GPU
                GlassCard(padding: 10) {
                    VStack(spacing: 6) {
                        CircularProgress(
                            value: monitor.gpu.deviceUtilization,
                            gradient: ArkenTheme.gpuGradient,
                            size: 68,
                            lineWidth: 7,
                            icon: "square.2.layers.3d",
                            label: "GPU"
                        )
                        HStack(spacing: 3) {
                            Image(systemName: "thermometer.medium")
                                .font(.system(size: 9))
                                .foregroundColor(ArkenTheme.tempColor)
                            Text(monitor.formatTemperature(monitor.thermal.gpuTemperature, decimals: 0))
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .contentShape(Rectangle())
                .onTapGesture { onSelectTab?(.gpu) }
                .help(L10n.tr("View GPU and graphics details", "GPU ve grafik detaylarını gör"))
                
                // RAM
                GlassCard(padding: 10) {
                    VStack(spacing: 6) {
                        CircularProgress(
                            value: monitor.memory.usedPercentage,
                            gradient: ArkenTheme.ramGradient,
                            size: 68,
                            lineWidth: 7,
                            icon: "memorychip",
                            label: "RAM"
                        )
                        Text(String(format: "%.1f GB", Double(monitor.memory.usedBytes) / 1_073_741_824.0))
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .contentShape(Rectangle())
                .onTapGesture { onSelectTab?(.ram) }
                .help(L10n.tr("View RAM and memory distribution", "RAM ve bellek dağılımını gör"))
                
                // Battery
                GlassCard(padding: 10) {
                    VStack(spacing: 6) {
                        CircularProgress(
                            value: Double(monitor.battery.percentage),
                            gradient: ArkenTheme.batteryGradient,
                            size: 68,
                            lineWidth: 7,
                            icon: powerGuard.isBypassActive ? "shield.fill" : (monitor.battery.isCharging ? "bolt.batteryblock.fill" : (monitor.battery.isPluggedIn ? "powerplug.fill" : "battery.100percent")),
                            label: powerGuard.isBypassActive ? "Bypass" : (monitor.battery.isCharging ? L10n.tr("Charging", "Şarjda") : (monitor.battery.isPluggedIn ? L10n.tr("AC", "Prizde") : L10n.tr("Battery", "Pil")))
                        )
                        Text(powerGuard.isBypassActive ? "0.0W (Bypass)" : (monitor.battery.watts > 0.05 ? String(format: "%.1f W", monitor.battery.watts) : "\(monitor.battery.percentage)%"))
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(powerGuard.isBypassActive ? .green : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .contentShape(Rectangle())
                .onTapGesture { onSelectTab?(.battery) }
                .help(L10n.tr("View battery and charge protection details", "Pil ve şarj koruma detaylarını gör"))
            }
            
            // Real-time Graph (CPU & GPU History)
            GlassCard(padding: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label(L10n.tr("CPU & GPU Activity Stream", "CPU & GPU Aktivite Akışı"), systemImage: "chart.xyaxis.line")
                            .font(.system(size: 11, weight: .semibold))
                        Spacer()
                        HStack(spacing: 8) {
                            HStack(spacing: 4) {
                                Circle().fill(ArkenTheme.cpuColor).frame(width: 6, height: 6)
                                Text("CPU").font(.system(size: 9)).foregroundColor(.secondary)
                            }
                            HStack(spacing: 4) {
                                Circle().fill(ArkenTheme.gpuColor).frame(width: 6, height: 6)
                                Text("GPU").font(.system(size: 9)).foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    MiniSparkline(data: monitor.cpu.history, gradient: ArkenTheme.cpuGradient, height: 38)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { onSelectTab?(.cpu) }
            .help(L10n.tr("View CPU details", "CPU detaylarına git"))
            
            // Network Live Strip
            GlassCard(padding: 8) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "network")
                            .font(.system(size: 12))
                            .foregroundColor(ArkenTheme.cpuColor)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(L10n.tr("Network Speed", "Ağ Hızı"))
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                            Text("↓ \(monitor.network.downloadSpeedFormatted)  ↑ \(monitor.network.uploadSpeedFormatted)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                        }
                    }
                    Spacer()
                    Text(monitor.network.ipAddress)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { onSelectTab?(.network) }
            .help(L10n.tr("View network traffic and connection details", "Ağ trafiği ve bağlantı detaylarını gör"))
            
            // Quick Status Strip
            HStack(spacing: 8) {
                // Thermal Status
                GlassCard(padding: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12))
                            .foregroundColor(ArkenTheme.tempColor)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(L10n.tr("Thermal State", "Termal Durum"))
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            Text(monitor.thermal.thermalStateString)
                                .font(.system(size: 11, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
                .onTapGesture { onSelectTab?(.thermal) }
                .help(L10n.tr("View temperature and sensor details", "Sıcaklık ve sensör detaylarını gör"))
                
                // Memory Pressure
                GlassCard(padding: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "speedometer")
                            .font(.system(size: 12))
                            .foregroundColor(ArkenTheme.ramColor)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(L10n.tr("RAM Pressure", "RAM Baskısı"))
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            Text(monitor.memory.pressureLevel.title)
                                .font(.system(size: 11, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
                .onTapGesture { onSelectTab?(.ram) }
                .help(L10n.tr("View RAM usage details", "RAM kullanım detaylarını gör"))
                
                // Power Wattage
                GlassCard(padding: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 12))
                            .foregroundColor(ArkenTheme.batteryColor)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(L10n.tr("Power Draw", "Güç Tüketimi"))
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            Text(String(format: "%.2f W", monitor.battery.watts))
                                .font(.system(size: 11, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
                .onTapGesture { onSelectTab?(.battery) }
                .help(L10n.tr("View power consumption and battery details", "Güç tüketimi ve batarya detaylarını gör"))
            }
        }
    }
}
