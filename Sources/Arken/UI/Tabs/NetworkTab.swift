import SwiftUI

public struct NetworkTab: View {
    @ObservedObject var monitor: HardwareMonitor
    @ObservedObject var l10n = LocalizationManager.shared
    @ObservedObject var dns = DNSManagerEngine.shared
    
    public init(monitor: HardwareMonitor) {
        self.monitor = monitor
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            // Speed Gauges (Download & Upload side-by-side)
            HStack(spacing: 10) {
                // Download
                GlassCard(padding: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundColor(ArkenTheme.cpuColor)
                                .font(.system(size: 16))
                            Text(L10n.tr("Download", "İndirme (Download)"))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        
                        Text(monitor.network.downloadSpeedFormatted)
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundColor(.primary)
                        
                        MiniSparkline(data: monitor.network.downloadHistory, gradient: ArkenTheme.cpuGradient, height: 30)
                    }
                }
                
                // Upload
                GlassCard(padding: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundColor(ArkenTheme.gpuColor)
                                .font(.system(size: 16))
                            Text(L10n.tr("Upload", "Yükleme (Upload)"))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        
                        Text(monitor.network.uploadSpeedFormatted)
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundColor(.primary)
                        
                        MiniSparkline(data: monitor.network.uploadHistory, gradient: ArkenTheme.gpuGradient, height: 30)
                    }
                }
            }
            
            // Connection & Data Transfer Stats
            GlassCard(padding: 12) {
                VStack(spacing: 8) {
                    HStack {
                        Label(L10n.tr("Network Connection Info", "Ağ Bağlantı Bilgisi"), systemImage: "network")
                            .font(.system(size: 11, weight: .semibold))
                        Spacer()
                        HStack(spacing: 4) {
                            Circle().fill(Color.green).frame(width: 6, height: 6)
                            Text(L10n.tr("Online", "Çevrimiçi"))
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.green)
                        }
                    }
                    
                    Divider().background(Color.white.opacity(0.1))
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.tr("Interface:", "Arayüz:"))
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            Text("Wi-Fi (\(monitor.network.activeInterface))")
                                .font(.system(size: 11, weight: .bold))
                        }
                        Spacer()
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.tr("Local IP Address:", "Yerel IP Adresi:"))
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            Text(monitor.network.ipAddress)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                        }
                    }
                }
            }
            
            // Quick DNS Switcher & Cache Flush Card
            GlassCard(padding: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label(L10n.tr("DNS & Network Cache", "DNS & Ağ Önbelleği"), systemImage: "bolt.horizontal.fill")
                            .font(.system(size: 11, weight: .semibold))
                        
                        Spacer()
                        
                        Text(DNSManagerEngine.shared.currentDNSDisplay)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(ArkenTheme.cpuColor)
                    }
                    
                    Divider().background(Color.white.opacity(0.1))
                    
                    HStack(spacing: 6) {
                        ForEach(DNSPreset.allCases) { preset in
                            Button(action: {
                                DNSManagerEngine.shared.switchDNS(to: preset)
                            }) {
                                Text(preset.shortTitle)
                                    .font(.system(size: 9, weight: .semibold))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 4)
                                    .background(DNSManagerEngine.shared.activeDNS == preset ? ArkenTheme.cpuColor.opacity(0.25) : Color.white.opacity(0.06))
                                    .foregroundColor(DNSManagerEngine.shared.activeDNS == preset ? ArkenTheme.cpuColor : .secondary)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(DNSManagerEngine.shared.activeDNS == preset ? ArkenTheme.cpuColor : Color.clear, lineWidth: 0.8))
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(DNSManagerEngine.shared.isSwitching)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            DNSManagerEngine.shared.flushCache()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: DNSManagerEngine.shared.isFlushing ? "arrow.triangle.2.circlepath" : "trash.circle.fill")
                                    .rotationEffect(Angle(degrees: DNSManagerEngine.shared.isFlushing ? 360 : 0))
                                    .animation(DNSManagerEngine.shared.isFlushing ? Animation.linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: DNSManagerEngine.shared.isFlushing)
                                Text(DNSManagerEngine.shared.isFlushing ? L10n.tr("Flushing...", "Sıfırlanıyor...") : L10n.tr("Flush DNS", "DNS Sıfırla"))
                            }
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(DNSManagerEngine.shared.isFlushing)
                        .help(L10n.tr("Purge macOS DNS cache (dscacheutil)", "macOS DNS önbelleğini anında sıfırla"))
                    }
                    
                    if let status = DNSManagerEngine.shared.statusMessage {
                        Text(status)
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            
            // Total Data Transferred since Boot
            GlassCard(padding: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Label(L10n.tr("Total Data Transferred Since Boot", "Açılıştan Beri Toplam Veri Akışı"), systemImage: "chart.bar.fill")
                        .font(.system(size: 11, weight: .semibold))
                    
                    HStack {
                        HStack(spacing: 6) {
                            Circle().fill(ArkenTheme.cpuColor).frame(width: 8, height: 8)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(L10n.tr("Received:", "Gelen:"))
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                Text(formatDataBytes(monitor.network.totalDownloadedBytes))
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                            }
                        }
                        Spacer()
                        HStack(spacing: 6) {
                            Circle().fill(ArkenTheme.gpuColor).frame(width: 8, height: 8)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(L10n.tr("Sent:", "Giden:"))
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                Text(formatDataBytes(monitor.network.totalUploadedBytes))
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func formatDataBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / (1024 * 1024 * 1024)
        if gb > 1.0 {
            return String(format: "%.2f GB", gb)
        } else {
            let mb = Double(bytes) / (1024 * 1024)
            return String(format: "%.0f MB", mb)
        }
    }
}
