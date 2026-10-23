import SwiftUI

public struct CoreLoadBar: View {
    public let core: CPUCoreUsage
    
    public init(core: CPUCoreUsage) {
        self.core = core
    }
    
    public var body: some View {
        HStack(spacing: 6) {
            // Core Type Badge
            Text(core.isPerformance ? "P\(core.id + 1)" : "E\(core.id + 1)")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(core.isPerformance ? ArkenTheme.cpuColor : ArkenTheme.ramColor)
                .frame(width: 24, alignment: .leading)
            
            // Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            core.isPerformance ? ArkenTheme.cpuGradient : ArkenTheme.ramGradient
                        )
                        .frame(width: geo.size.width * CGFloat(min(max(core.usage / 100.0, 0.0), 1.0)), height: 6)
                        .animation(.easeOut(duration: 0.25), value: core.usage)
                }
            }
            .frame(height: 6)
            
            // Percentage
            Text(String(format: "%.0f%%", core.usage))
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 32, alignment: .trailing)
        }
    }
}
