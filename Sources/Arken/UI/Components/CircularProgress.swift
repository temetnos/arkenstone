import SwiftUI

public struct CircularProgress: View {
    public let value: Double // 0.0 to 100.0
    public let gradient: LinearGradient
    public var size: CGFloat = 84
    public var lineWidth: CGFloat = 8
    public var icon: String? = nil
    public var label: String? = nil
    public var unit: String = "%"
    
    public init(
        value: Double,
        gradient: LinearGradient,
        size: CGFloat = 84,
        lineWidth: CGFloat = 8,
        icon: String? = nil,
        label: String? = nil,
        unit: String = "%"
    ) {
        self.value = value
        self.gradient = gradient
        self.size = size
        self.lineWidth = lineWidth
        self.icon = icon
        self.label = label
        self.unit = unit
    }
    
    public var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: lineWidth)
                .frame(width: size, height: size)
            
            // Active progress
            Circle()
                .trim(from: 0.0, to: CGFloat(min(max(value / 100.0, 0.0), 1.0)))
                .stroke(
                    gradient,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(Angle(degrees: -90))
                .frame(width: size, height: size)
                .animation(.easeOut(duration: 0.35), value: value)
            
            // Value inside
            VStack(spacing: 1) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                
                HStack(alignment: .firstTextBaseline, spacing: 0.5) {
                    Text(String(format: "%.0f", value))
                        .font(.system(size: size * 0.22, weight: .bold, design: .rounded))
                    Text(unit)
                        .font(.system(size: size * 0.12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
                
                if let label = label {
                    Text(label)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
