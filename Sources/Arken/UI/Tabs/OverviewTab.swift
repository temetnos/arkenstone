import SwiftUI

public struct OverviewTab: View {
    @ObservedObject var monitor: HardwareMonitor
    @ObservedObject var keepAwake = KeepAwakeEngine.shared
    @ObservedObject var shelf = DropShelfEngine.shared
    @ObservedObject var powerGuard = PowerGuardEngine.shared
    @ObservedObject var clipboard = ClipboardEngine.shared
    @ObservedObject var l10n = LocalizationManager.shared
    @ObservedObject var desktopFocus = DesktopFocusEngine.shared
    @ObservedObject var volumeManager = VolumeManager.shared
    @ObservedObject var audioMute = AudioMuteEngine.shared
    
    @State private var copiedIP: Bool = false
    
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
                
                // Tier 2: Live System Toggles (Keep Awake, Clamshell/Mute, Desktop Focus, Power Guard)
                HStack(spacing: 5) {
                    // Keep Awake (Caffeine) Toggle Button
                    let awakeText: String = {
                        if keepAwake.isActive {
                            if keepAwake.remainingSeconds > 0 {
                                let mins = max(1, (keepAwake.remainingSeconds + 59) / 60)
                                return "\(L10n.tr("Awake", "Uyanık")) (\(mins)m)"
                            }
                            return L10n.tr("Awake", "Uyanık")
                        }
                        return L10n.tr("Sleep", "Uyku")
                    }()
                    
                    Button(action: {
                        keepAwake.toggle()
                        SoundManager.shared.play(.pop)
                    }) {
                        HStack(spacing: 3.5) {
                            Image(systemName: keepAwake.isActive ? "cup.and.saucer.fill" : "cup.and.saucer")
                                .font(.system(size: 9))
                                .foregroundColor(keepAwake.isActive ? ArkenTheme.tempColor : .secondary)
                            Text(awakeText)
                                .font(.system(size: 9, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
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
                    
                    if monitor.battery.hasBattery {
                        // Clamshell Mode (Lid-Closed Awake) Toggle Button
                        ClamshellButton(keepAwake: keepAwake)
                    } else {
                        // Desktop Mac (No lid): Quick Mute Microphone Button
                        Button(action: {
                            audioMute.toggleMute()
                        }) {
                            HStack(spacing: 3.5) {
                                Image(systemName: audioMute.isMuted ? "mic.slash.fill" : "mic.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(audioMute.isMuted ? .red : ArkenTheme.accentColor)
                                Text(audioMute.isMuted ? L10n.tr("Muted", "Sessiz") : L10n.tr("Mic ON", "Mikrofon"))
                                    .font(.system(size: 9, weight: .semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4.5)
                            .background(audioMute.isMuted ? Color.red.opacity(0.16) : Color.white.opacity(0.05))
                            .foregroundColor(audioMute.isMuted ? .red : .primary)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(audioMute.isMuted ? Color.red.opacity(0.35) : Color.white.opacity(0.08), lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help(audioMute.isMuted ? L10n.tr("Unmute Microphone (⌥M)", "Mikrofonun Sesini Aç (⌥M)") : L10n.tr("Mute Microphone (⌥M)", "Mikrofonu Sustur (⌥M)"))
                    }
                    
                    // Desktop Focus Toggle Button
                    Button(action: {
                        desktopFocus.toggleDesktopIcons()
                        SoundManager.shared.play(.pop)
                    }) {
                        HStack(spacing: 3.5) {
                            Image(systemName: desktopFocus.isDesktopHidden ? "eye.slash.fill" : "desktopcomputer")
                                .font(.system(size: 9))
                                .foregroundColor(desktopFocus.isDesktopHidden ? ArkenTheme.tempColor : ArkenTheme.accentColor)
                            Text(desktopFocus.isDesktopHidden ? L10n.tr("Focus", "Odak") : L10n.tr("Desktop", "Masaüstü"))
                                .font(.system(size: 9, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
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
                        HStack(spacing: 3.5) {
                            Image(systemName: powerGuard.isBypassActive ? "shield.fill" : (powerGuard.isEnabled ? "shield.lefthalf.filled" : "shield"))
                                .font(.system(size: 9))
                                .foregroundColor(powerGuard.isBypassActive ? .green : (powerGuard.isEnabled ? ArkenTheme.batteryColor : .secondary))
                            Text(powerGuard.isBypassActive ? "Bypass" : (powerGuard.isEnabled ? (LocalizationManager.shared.language == .tr ? "%\(powerGuard.targetLimit)" : "\(powerGuard.targetLimit)%") : L10n.tr("Normal", "Normal")))
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(powerGuard.isBypassActive ? .green : (powerGuard.isEnabled ? ArkenTheme.batteryColor : .secondary))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
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
                
                // Battery or Desktop AC Power
                GlassCard(padding: 10) {
                    VStack(spacing: 6) {
                        if monitor.battery.hasBattery {
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
                        } else {
                            CircularProgress(
                                value: 100.0,
                                gradient: LinearGradient(colors: [Color.green, Color.teal], startPoint: .topLeading, endPoint: .bottomTrailing),
                                size: 68,
                                lineWidth: 7,
                                icon: "powerplug.fill",
                                label: L10n.tr("AC Power", "Prizde")
                            )
                            Text(L10n.tr("Desktop Mac", "Masaüstü"))
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .contentShape(Rectangle())
                .onTapGesture { onSelectTab?(.battery) }
                .help(monitor.battery.hasBattery ? L10n.tr("View battery and charge protection details", "Pil ve şarj koruma detaylarını gör") : L10n.tr("Connected to AC Power (Desktop Mac)", "Doğrudan Prizden Besleniyor (Masaüstü Mac)"))
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
                    
                    MiniSparkline(
                        data: monitor.cpu.history,
                        gradient: ArkenTheme.cpuGradient,
                        secondaryData: monitor.gpu.history,
                        secondaryGradient: ArkenTheme.gpuGradient,
                        height: 38
                    )
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
                    HStack(spacing: 4) {
                        Text(copiedIP ? L10n.tr("Copied!", "Kopyalandı!") : monitor.network.ipAddress)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(copiedIP ? .green : .secondary)
                        Image(systemName: copiedIP ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 8))
                            .foregroundColor(copiedIP ? .green : .secondary.opacity(0.5))
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(4)
                    .onTapGesture {
                        let pboard = NSPasteboard.general
                        pboard.clearContents()
                        pboard.setString(monitor.network.ipAddress, forType: .string)
                        SoundManager.shared.play(.pop)
                        withAnimation { copiedIP = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation { copiedIP = false }
                        }
                    }
                    .help(L10n.tr("Click to copy IP address", "IP adresini kopyalamak için tıklayın"))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { onSelectTab?(.network) }
            .help(L10n.tr("View network traffic and connection details", "Ağ trafiği ve bağlantı detaylarını gör"))
            
            // Mounted External Volumes & DMGs (Quick Ejector)
            if !volumeManager.ejectableVolumes.isEmpty {
                GlassCard(padding: 8) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "externaldrive.fill.badge.checkmark")
                                .font(.system(size: 11))
                                .foregroundColor(ArkenTheme.accentColor)
                            Text(L10n.tr("Mounted Drives & DMGs (\(volumeManager.ejectableVolumes.count))", "Bağlı Sürücüler ve DMG'ler (\(volumeManager.ejectableVolumes.count))"))
                                .font(.system(size: 10, weight: .bold))
                            
                            Spacer()
                            
                            if volumeManager.ejectableVolumes.count > 1 {
                                Button(action: {
                                    volumeManager.ejectAll()
                                }) {
                                    HStack(spacing: 3) {
                                        Image(systemName: "eject.fill")
                                        Text(L10n.tr("Eject All", "Tümünü Çıkar"))
                                    }
                                    .font(.system(size: 8.5, weight: .semibold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.white.opacity(0.1))
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        
                        ForEach(volumeManager.ejectableVolumes) { vol in
                            HStack(spacing: 6) {
                                Image(systemName: vol.url.pathExtension.lowercased() == "dmg" || vol.name.contains(".dmg") ? "opticaldiscdrive.fill" : "externaldrive.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Text(vol.name)
                                    .font(.system(size: 9.5, weight: .medium))
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                Button(action: {
                                    volumeManager.eject(volume: vol)
                                }) {
                                    Image(systemName: "eject.circle.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(ArkenTheme.accentColor)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .help(L10n.tr("Safely Eject", "Güvenle Çıkar"))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(5)
                        }
                        
                        if let errorMsg = volumeManager.lastErrorMessage {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 8.5))
                                    .foregroundColor(.orange)
                                Text(errorMsg)
                                    .font(.system(size: 8))
                                    .foregroundColor(.orange)
                                    .lineLimit(2)
                            }
                            .padding(.horizontal, 4)
                            .padding(.top, 2)
                        }
                    }
                }
            }
            
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
                
                // Power Wattage / Power Source
                GlassCard(padding: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: monitor.battery.hasBattery ? "bolt.fill" : "powerplug.fill")
                            .font(.system(size: 12))
                            .foregroundColor(ArkenTheme.batteryColor)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(monitor.battery.hasBattery ? L10n.tr("Power Draw", "Güç Tüketimi") : L10n.tr("Power Source", "Güç Kaynağı"))
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            Text(monitor.battery.hasBattery ? String(format: "%.2f W", monitor.battery.watts) : L10n.tr("AC Connected", "Priz Bağlı"))
                                .font(.system(size: 11, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
                .onTapGesture { onSelectTab?(.battery) }
                .help(monitor.battery.hasBattery ? L10n.tr("View power consumption and battery details", "Güç tüketimi ve batarya detaylarını gör") : L10n.tr("Desktop Mac connected to AC power adapter", "Prizden beslenen masaüstü Mac"))
            }
        }
    }
}

// MARK: - Dedicated Clamshell Toggle Button
private struct ClamshellButton: View {
    @ObservedObject var keepAwake: KeepAwakeEngine
    
    private var iconName: String {
        if keepAwake.isClamshellAuthRequired {
            return "exclamationmark.shield.fill"
        } else if keepAwake.isClamshellActive {
            return "macbook.and.ipad"
        } else if keepAwake.isClamshellEnabled {
            return "exclamationmark.triangle.fill"
        } else {
            return "macbook"
        }
    }
    
    private var titleText: String {
        if keepAwake.isClamshellAuthRequired {
            return L10n.tr("⚠️ Auth", "⚠️ İzin Ver")
        } else if keepAwake.isClamshellActive {
            return L10n.tr("Lid ON", "Kapak Açık")
        } else if keepAwake.isClamshellEnabled {
            return L10n.tr("⚡️ Plug In", "⚡️ Şarj Tak")
        } else {
            return L10n.tr("Clamshell", "Kapak")
        }
    }
    
    private var tintColor: Color {
        if keepAwake.isClamshellAuthRequired {
            return .orange
        } else if keepAwake.isClamshellActive {
            return .green
        } else if keepAwake.isClamshellEnabled {
            return .orange
        } else {
            return .secondary
        }
    }
    
    private var backgroundColor: Color {
        if keepAwake.isClamshellAuthRequired {
            return Color.orange.opacity(0.18)
        } else if keepAwake.isClamshellActive {
            return Color.green.opacity(0.16)
        } else if keepAwake.isClamshellEnabled {
            return Color.orange.opacity(0.15)
        } else {
            return Color.white.opacity(0.05)
        }
    }
    
    private var strokeColor: Color {
        if keepAwake.isClamshellAuthRequired {
            return Color.orange.opacity(0.45)
        } else if keepAwake.isClamshellActive {
            return Color.green.opacity(0.35)
        } else if keepAwake.isClamshellEnabled {
            return Color.orange.opacity(0.35)
        } else {
            return Color.white.opacity(0.08)
        }
    }
    
    var body: some View {
        Button(action: {
            if keepAwake.isClamshellAuthRequired {
                keepAwake.retryClamshellAuthorization()
            } else {
                keepAwake.toggleClamshell()
            }
            SoundManager.shared.play(.pop)
        }) {
            HStack(spacing: 3.5) {
                Image(systemName: iconName)
                    .font(.system(size: 9))
                    .foregroundColor(tintColor)
                Text(titleText)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(keepAwake.isClamshellActive || keepAwake.isClamshellAuthRequired || keepAwake.isClamshellEnabled ? tintColor : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4.5)
            .background(backgroundColor)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(strokeColor, lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .help(keepAwake.isClamshellAuthRequired
            ? L10n.tr("Administrator authorization required for Clamshell. Click to grant Touch ID / Password permission.", "Kapak modu için yönetici yetkisi gerekiyor. İzin vermek için tıklayın.")
            : L10n.tr("Clamshell Mode: Keep Mac awake when lid is closed (Requires AC power)", "Kapak Kapalı Modu: Kapak kapatıldığında Mac'i uyanık tut (Şarjda çalışır)"))
    }
}
