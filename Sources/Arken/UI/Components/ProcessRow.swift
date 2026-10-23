import SwiftUI

public struct ProcessRow: View {
    let item: ProcessUsageItem
    let isMemory: Bool
    var onTerminate: (() -> Void)? = nil
    @State private var isHovered = false
    
    public init(item: ProcessUsageItem, isMemory: Bool, onTerminate: (() -> Void)? = nil) {
        self.item = item
        self.isMemory = isMemory
        self.onTerminate = onTerminate
    }
    
    public var body: some View {
        HStack(spacing: 6) {
            // Process Name
            Text(item.name)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Metric Value
            Text(isMemory ? item.memoryFormatted : String(format: "%.1fs", item.cpuUserSeconds))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(isMemory ? ArkenTheme.ramColor : ArkenTheme.cpuColor)
            
            // Terminate Button
            if isHovered {
                Button(action: {
                    onTerminate?()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
                .help(L10n.tr("Terminate Process (SIGTERM)", "Süreci Sonlandır (SIGTERM)"))
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovered ? Color.white.opacity(0.06) : Color.clear)
        )
        .onHover { h in isHovered = h }
    }
}
