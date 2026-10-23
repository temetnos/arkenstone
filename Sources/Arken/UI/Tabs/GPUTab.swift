import SwiftUI

public struct GPUTab: View {
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
                        value: monitor.gpu.deviceUtilization,
                        gradient: ArkenTheme.gpuGradient,
                        size: 80,
                        lineWidth: 8,
                        icon: "square.2.layers.3d",
                        label: L10n.tr("GPU Load", "GPU Yükü")
                    )
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Apple GPU")
                                .font(.system(size: 13, weight: .bold))
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: "thermometer.medium")
                                    .foregroundColor(ArkenTheme.tempColor)
                                Text(monitor.formatTemperature(monitor.thermal.gpuTemperature, decimals: 1))
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                            }
                        }
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Renderer:")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.0f%%", monitor.gpu.rendererUtilization))
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            Spacer()
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Tiler:")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.0f%%", monitor.gpu.tilerUtilization))
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            Spacer()
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.tr("State:", "Durum:"))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Text(monitor.gpu.deviceUtilization > 10 ? L10n.tr("Active", "Aktif") : L10n.tr("Idle", "Boşta"))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(monitor.gpu.deviceUtilization > 10 ? ArkenTheme.gpuColor : .secondary)
                            }
                        }
                    }
                }
            }
            
            // Memory Usage
            GlassCard(padding: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Label(L10n.tr("GPU Memory Usage (Unified Memory)", "GPU Bellek Kullanımı (Birleşik Bellek)"), systemImage: "memorychip")
                        .font(.system(size: 11, weight: .semibold))
                    
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(L10n.tr("In-Use VRAM", "Kullanılan VRAM"))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text(formatBytes(monitor.gpu.inUseMemoryBytes))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(L10n.tr("Allocated Memory", "Ayrılan Bellek"))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text(formatBytes(monitor.gpu.allocatedMemoryBytes))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                        }
                    }
                }
            }
            
            // GPU History Chart
            GlassCard(padding: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(L10n.tr("GPU Activity History", "GPU Aktivite Geçmişi"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%.0f%%", monitor.gpu.deviceUtilization))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(ArkenTheme.gpuColor)
                    }
                    MiniSparkline(data: monitor.gpu.history, gradient: ArkenTheme.gpuGradient, height: 32)
                }
            }
        }
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let mb = Double(bytes) / (1024 * 1024)
        if mb > 1024 {
            return String(format: "%.2f GB", mb / 1024.0)
        } else {
            return String(format: "%.0f MB", mb)
        }
    }
}
