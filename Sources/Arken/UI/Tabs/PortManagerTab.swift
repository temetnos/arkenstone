import SwiftUI

public struct PortManagerTab: View {
    @ObservedObject var portManager = PortManagerEngine.shared
    @ObservedObject var l10n = LocalizationManager.shared
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 12) {
            // Header Action Card
            GlassCard(padding: 12) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(ArkenTheme.cpuColor.opacity(0.18))
                            .frame(width: 44, height: 44)
                        Image(systemName: "point.3.connected.trianglepath.dotted")
                            .font(.system(size: 18))
                            .foregroundColor(ArkenTheme.cpuColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.tr("Listening Ports & Process Manager", "Açık Port & Süreç Yöneticisi"))
                            .font(.system(size: 12, weight: .bold))
                        Text(portManager.statusMessage)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Refresh Button
                    Button(action: {
                        portManager.scanPorts()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .rotationEffect(Angle(degrees: portManager.isScanning ? 360 : 0))
                                .animation(portManager.isScanning ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: portManager.isScanning)
                            Text(L10n.tr("Refresh", "Yenile"))
                        }
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(portManager.isScanning)
                }
            }
            
            // Helpful Developer Tip
            GlassCard(padding: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(ArkenTheme.accentColor)
                        .font(.system(size: 12))
                    Text(L10n.tr("Fix EADDRINUSE Conflicts:", "EADDRINUSE Hatası Çözümü:"))
                        .font(.system(size: 9, weight: .bold))
                    Text(L10n.tr("Terminate hung 3000, 8080, etc. development ports with one click.", "Kilitlenen 3000, 8080 vb. portları tek tıkla sonlandırabilirsiniz."))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            
            // Search / Filter Bar
            if !portManager.ports.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    TextField(L10n.tr("Search port, process (node, python) or PID...", "Port, süreç (node, python) veya PID ara..."), text: $portManager.searchQuery)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 11))
                    
                    if !portManager.searchQuery.isEmpty {
                        Button(action: { portManager.searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help(L10n.tr("Clear search", "Aramayı temizle"))
                    }
                }
                .padding(6)
                .background(Color.white.opacity(0.06))
                .cornerRadius(6)
            }
            
            // Port List
            if portManager.ports.isEmpty {
                GlassCard(padding: 24) {
                    VStack(spacing: 8) {
                        Image(systemName: "antenna.radiowaves.left.and.right.slash")
                            .font(.system(size: 26))
                            .foregroundColor(.secondary)
                        Text(portManager.isScanning ? L10n.tr("Scanning ports...", "Portlar taranıyor...") : L10n.tr("No listening ports found", "Aktif dinlenen port bulunamadı"))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            } else if portManager.filteredPorts.isEmpty {
                GlassCard(padding: 16) {
                    VStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                        Text(L10n.tr("No matching ports found", "Eşleşen port bulunamadı"))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                VStack(spacing: 5) {
                    ForEach(portManager.filteredPorts) { item in
                        PortItemRow(item: item) {
                            portManager.killPortProcess(item: item)
                        }
                    }
                }
            }
        }
    }
}

struct PortItemRow: View {
    let item: ListeningPortItem
    var onKill: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Port Number Badge
            Text(":\(item.port)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(item.isCommonDevPort ? ArkenTheme.tempColor : ArkenTheme.cpuColor)
                .frame(width: 58, alignment: .leading)
            
            // Process Info
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(item.processName)
                        .font(.system(size: 10, weight: .semibold))
                    if item.isCommonDevPort {
                        Text("DEV")
                            .font(.system(size: 7, weight: .black))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(ArkenTheme.tempColor.opacity(0.2))
                            .foregroundColor(ArkenTheme.tempColor)
                            .clipShape(Capsule())
                    }
                }
                
                Text("PID: \(item.pid) • \(item.protocolType)")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Kill / Free Button
            if item.isKilled {
                Text(L10n.tr("Killed", "Sonlandırıldı"))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.green)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.15))
                    .clipShape(Capsule())
            } else {
                Button(action: onKill) {
                    HStack(spacing: 3) {
                        Image(systemName: "stop.circle.fill")
                        Text(L10n.tr("Kill", "Sonlandır"))
                    }
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.red)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.red.opacity(isHovered ? 0.22 : 0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
                .help(L10n.tr("Kill process listening on this port (SIGTERM)", "Bu portu dinleyen süreci sonlandır (SIGTERM)"))
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(item.isCommonDevPort ? ArkenTheme.tempColor.opacity(0.04) : Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(item.isCommonDevPort ? ArkenTheme.tempColor.opacity(0.25) : Color.white.opacity(0.06), lineWidth: 0.8)
        )
        .onHover { h in isHovered = h }
    }
}
