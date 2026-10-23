import SwiftUI

public struct CPUTab: View {
    @ObservedObject var monitor: HardwareMonitor
    @ObservedObject var l10n = LocalizationManager.shared
    
    public init(monitor: HardwareMonitor) {
        self.monitor = monitor
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            // Main Gauge & Breakdown
            GlassCard(padding: 12) {
                HStack(spacing: 16) {
                    CircularProgress(
                        value: monitor.cpu.totalUsage,
                        gradient: ArkenTheme.cpuGradient,
                        size: 80,
                        lineWidth: 8,
                        icon: "cpu",
                        label: L10n.tr("Total", "Toplam")
                    )
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(monitor.chipName)
                                .font(.system(size: 13, weight: .bold))
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: "thermometer.medium")
                                    .foregroundColor(ArkenTheme.tempColor)
                                Text(monitor.formatTemperature(monitor.thermal.cpuTemperature, decimals: 1))
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                            }
                        }
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        // User vs System
                        HStack {
                            Text(L10n.tr("User:", "Kullanıcı:"))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1f%%", monitor.cpu.userUsage))
                                .font(.system(size: 10, weight: .semibold))
                            Spacer()
                            Text(L10n.tr("System:", "Sistem:"))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1f%%", monitor.cpu.systemUsage))
                                .font(.system(size: 10, weight: .semibold))
                            Spacer()
                            Text(L10n.tr("Idle:", "Boşta:"))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1f%%", monitor.cpu.idleUsage))
                                .font(.system(size: 10, weight: .semibold))
                        }
                    }
                }
            }
            
            // Per-Core Breakdown
            GlassCard(padding: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label(L10n.tr("Core Distribution (\(monitor.cpu.coreCount) Cores)", "Çekirdek Dağılımı (\(monitor.cpu.coreCount) Çekirdek)"), systemImage: "square.grid.2x2")
                            .font(.system(size: 11, weight: .semibold))
                        Spacer()
                        Text(L10n.tr("P: Performance • E: Efficiency", "P: Performans • E: Verimlilik"))
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    
                    let columns = [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8)
                    ]
                    
                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(monitor.cpu.coreUsages) { core in
                            CoreLoadBar(core: core)
                        }
                    }
                }
            }
            
            // Top CPU Processes
            if !monitor.topCpuProcesses.isEmpty {
                GlassCard(padding: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(L10n.tr("Top CPU Processes", "En Çok CPU Tüketenler"), systemImage: "bolt.horizontal.circle")
                            .font(.system(size: 11, weight: .semibold))
                        
                        ForEach(monitor.topCpuProcesses) { proc in
                            ProcessRow(item: proc, isMemory: false) {
                                _ = monitor.processMonitor.terminateProcess(pid: proc.pid)
                                monitor.updateAll()
                            }
                        }
                    }
                }
            }
            
            // CPU History Chart
            GlassCard(padding: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(L10n.tr("Load History", "Yük Geçmişi"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%.1f%%", monitor.cpu.totalUsage))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(ArkenTheme.cpuColor)
                    }
                    MiniSparkline(data: monitor.cpu.history, gradient: ArkenTheme.cpuGradient, height: 32)
                }
            }
        }
    }
}
