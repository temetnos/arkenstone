import SwiftUI

public struct ThermalTab: View {
    @ObservedObject var monitor: HardwareMonitor
    @ObservedObject var l10n = LocalizationManager.shared
    
    public init(monitor: HardwareMonitor) {
        self.monitor = monitor
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            // Main Thermal State Card
            GlassCard(padding: 12) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(ArkenTheme.tempGradient.opacity(0.15))
                            .frame(width: 54, height: 54)
                        Image(systemName: "flame.fill")
                            .font(.system(size: 24))
                            .foregroundColor(ArkenTheme.tempColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(L10n.tr("Thermal State", "Termal Durum")): \(monitor.thermal.thermalStateString)")
                            .font(.system(size: 13, weight: .bold))
                        Text("\(L10n.tr("Hottest Sensor", "En Sıcak Sensör")): \(monitor.formatTemperature(monitor.thermal.maxSensorTemperature, decimals: 1))")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                
                Divider().background(Color.white.opacity(0.08))
                
                // SMC Fan Telemetry or Fanless Banner
                if monitor.thermal.fanData.isFanless {
                    HStack(spacing: 6) {
                        Image(systemName: "wind.slash")
                            .font(.system(size: 11))
                            .foregroundColor(ArkenTheme.cpuColor)
                        Text(L10n.tr("Fanless Architecture (100% Silent Passive Cooling)", "Fansız Mimari (Sessiz Pasif Soğutma)"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(L10n.tr("0 RPM", "0 RPM"))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(ArkenTheme.cpuColor)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(6)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "fan.fill")
                            .font(.system(size: 11))
                            .foregroundColor(ArkenTheme.cpuColor)
                        Text(L10n.tr("Cooling Fans (\(monitor.thermal.fanData.count)):", "Soğutma Fanları (\(monitor.thermal.fanData.count)):"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        HStack(spacing: 6) {
                            ForEach(0..<monitor.thermal.fanData.speeds.count, id: \.self) { idx in
                                Text("Fan \(idx + 1): \(monitor.thermal.fanData.speeds[idx]) RPM")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(ArkenTheme.cpuColor)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(6)
                }
            }
            
            // Major Sensor Cards Grid
            let columns = [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ]
            
            LazyVGrid(columns: columns, spacing: 8) {
                ThermalMetricCard(title: L10n.tr("Processor (CPU)", "İşlemci (CPU)"), formattedTemp: monitor.formatTemperature(monitor.thermal.cpuTemperature, decimals: 1), icon: "cpu", color: ArkenTheme.cpuColor)
                ThermalMetricCard(title: L10n.tr("Graphics (GPU)", "Grafik (GPU)"), formattedTemp: monitor.formatTemperature(monitor.thermal.gpuTemperature, decimals: 1), icon: "square.2.layers.3d", color: ArkenTheme.gpuColor)
                ThermalMetricCard(title: L10n.tr("SoC Die", "Çip (SoC Die)"), formattedTemp: monitor.formatTemperature(monitor.thermal.socTemperature, decimals: 1), icon: "circle.grid.cross.fill", color: ArkenTheme.tempColor)
                ThermalMetricCard(title: L10n.tr("Battery", "Batarya"), formattedTemp: monitor.formatTemperature(monitor.thermal.batteryTemperature, decimals: 1), icon: "battery.100percent", color: ArkenTheme.batteryColor)
            }
            
            // Detailed Hardware Sensors List
            GlassCard(padding: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label(L10n.tr("Apple Silicon Hardware Sensors (\(monitor.thermal.detailedSensors.count))", "Apple Silicon Donanım Sensörleri (\(monitor.thermal.detailedSensors.count))"), systemImage: "waveform.path.ecg")
                            .font(.system(size: 11, weight: .semibold))
                        Spacer()
                    }
                    
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(monitor.thermal.detailedSensors.prefix(12)) { sensor in
                                HStack {
                                    Text(sensor.name)
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(monitor.formatTemperature(sensor.temperature, decimals: 1))
                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                        .foregroundColor(sensor.temperature > 60 ? ArkenTheme.tempColor : .primary)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    .frame(maxHeight: 110)
                }
            }
        }
    }
}

struct ThermalMetricCard: View {
    let title: String
    let formattedTemp: String
    let icon: String
    let color: Color
    
    var body: some View {
        GlassCard(padding: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Text(formattedTemp)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                Spacer()
            }
        }
    }
}
