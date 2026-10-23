import SwiftUI

public struct MemoryTab: View {
    @ObservedObject var monitor: HardwareMonitor
    @ObservedObject var l10n = LocalizationManager.shared
    
    public init(monitor: HardwareMonitor) {
        self.monitor = monitor
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            // Main Gauge & Overview
            GlassCard(padding: 12) {
                HStack(spacing: 16) {
                    CircularProgress(
                        value: monitor.memory.usedPercentage,
                        gradient: ArkenTheme.ramGradient,
                        size: 80,
                        lineWidth: 8,
                        icon: "memorychip",
                        label: L10n.tr("Usage", "Kullanım")
                    )
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("\(L10n.tr("Total", "Toplam")) \(formatGB(monitor.memory.totalBytes))")
                                .font(.system(size: 13, weight: .bold))
                            Spacer()
                            // Pressure badge
                            Text(monitor.memory.pressureLevel.title)
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(pressureColor.opacity(0.2))
                                .foregroundColor(pressureColor)
                                .clipShape(Capsule())
                        }
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.tr("Used:", "Kullanılan:"))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Text(formatGB(monitor.memory.usedBytes))
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            Spacer()
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.tr("Free:", "Boşta:"))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Text(formatGB(monitor.memory.freeBytes))
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            Spacer()
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.tr("Swap:", "Swap:"))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Text(formatMB(monitor.memory.swapUsedBytes))
                                    .font(.system(size: 11, weight: .semibold))
                            }
                        }
                    }
                }
            }
            
            // Detailed Breakdown List
            GlassCard(padding: 12) {
                VStack(spacing: 7) {
                    Label(L10n.tr("Memory Allocation Breakdown", "Bellek Tahsis Dağılımı"), systemImage: "chart.bar.xaxis")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    MemoryRow(label: L10n.tr("Apps (Active)", "Uygulamalar (Aktif)"), bytes: monitor.memory.activeBytes, total: monitor.memory.totalBytes, color: ArkenTheme.ramColor)
                    MemoryRow(label: L10n.tr("Wired", "Kilitli (Wired)"), bytes: monitor.memory.wiredBytes, total: monitor.memory.totalBytes, color: ArkenTheme.cpuColor)
                    MemoryRow(label: L10n.tr("Compressed", "Sıkıştırılmış"), bytes: monitor.memory.compressedBytes, total: monitor.memory.totalBytes, color: ArkenTheme.tempColor)
                    MemoryRow(label: L10n.tr("Free / Cache", "Boş / Önbellek"), bytes: monitor.memory.freeBytes, total: monitor.memory.totalBytes, color: Color.gray)
                }
            }
            
            // Top Memory Processes
            if !monitor.topMemoryProcesses.isEmpty {
                GlassCard(padding: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(L10n.tr("Top RAM Processes", "En Çok RAM Tüketenler"), systemImage: "memorychip")
                            .font(.system(size: 11, weight: .semibold))
                        
                        ForEach(monitor.topMemoryProcesses) { proc in
                            ProcessRow(item: proc, isMemory: true) {
                                _ = monitor.processMonitor.terminateProcess(pid: proc.pid)
                                monitor.updateAll()
                            }
                        }
                    }
                }
            }
            
            // Swap Info Card
            if monitor.memory.swapTotalBytes > 0 {
                GlassCard(padding: 10) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(ArkenTheme.accentColor)
                        Text(L10n.tr("Virtual Memory (Swap):", "Sanal Bellek (Swap):"))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text("\(formatMB(monitor.memory.swapUsedBytes)) / \(formatMB(monitor.memory.swapTotalBytes))")
                            .font(.system(size: 10, weight: .semibold))
                        Spacer()
                    }
                }
            }
        }
    }
    
    private var pressureColor: Color {
        switch monitor.memory.pressureLevel {
        case .normal: return ArkenTheme.ramColor
        case .warning: return ArkenTheme.tempColor
        case .critical: return Color.red
        }
    }
    
    private func formatGB(_ bytes: UInt64) -> String {
        return String(format: "%.1f GB", Double(bytes) / 1_073_741_824.0)
    }
    
    private func formatMB(_ bytes: UInt64) -> String {
        let mb = Double(bytes) / 1_048_576.0
        if mb > 1024 {
            return String(format: "%.1f GB", mb / 1024.0)
        }
        return String(format: "%.0f MB", mb)
    }
}

struct MemoryRow: View {
    let label: String
    let bytes: UInt64
    let total: UInt64
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            Spacer()
            Text(String(format: "%.2f GB", Double(bytes) / 1_073_741_824.0))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
        }
    }
}
