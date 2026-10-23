import SwiftUI

public struct MiniSparkline: View {
    public let data: [Double]
    public let gradient: LinearGradient
    public var height: CGFloat = 36
    
    public init(data: [Double], gradient: LinearGradient, height: CGFloat = 36) {
        self.data = data
        self.gradient = gradient
        self.height = height
    }
    
    public var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let h = proxy.size.height
            let count = max(data.count, 2)
            let stepX = width / CGFloat(count - 1)
            
            ZStack {
                // Subtle area fill under curve
                if data.count >= 2 {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: h))
                        for (index, val) in data.enumerated() {
                            let normalizedY = 1.0 - (min(max(val, 0.0), 100.0) / 100.0)
                            let x = CGFloat(index) * stepX
                            let y = CGFloat(normalizedY) * (h - 4) + 2
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                        path.addLine(to: CGPoint(x: CGFloat(data.count - 1) * stepX, y: h))
                        path.closeSubpath()
                    }
                    .fill(gradient.opacity(0.12))
                }
                
                // Curve stroke
                Path { path in
                    for (index, val) in data.enumerated() {
                        let normalizedY = 1.0 - (min(max(val, 0.0), 100.0) / 100.0)
                        let x = CGFloat(index) * stepX
                        let y = CGFloat(normalizedY) * (h - 4) + 2
                        
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(gradient, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
            }
        }
        .frame(height: height)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.03))
        )
    }
}
