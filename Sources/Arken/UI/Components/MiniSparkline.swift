import SwiftUI

public struct MiniSparkline: View {
    public let data: [Double]
    public let gradient: LinearGradient
    public var secondaryData: [Double]? = nil
    public var secondaryGradient: LinearGradient? = nil
    public var height: CGFloat = 36
    
    public init(
        data: [Double],
        gradient: LinearGradient,
        secondaryData: [Double]? = nil,
        secondaryGradient: LinearGradient? = nil,
        height: CGFloat = 36
    ) {
        self.data = data
        self.gradient = gradient
        self.secondaryData = secondaryData
        self.secondaryGradient = secondaryGradient
        self.height = height
    }
    
    public var body: some View {
        GeometryReader { proxy in
            ZStack {
                // Primary fill (CPU)
                drawFill(data: data, in: proxy, fillColor: gradient, opacity: 0.10)
                
                // Secondary fill (GPU) if provided
                if let sec = secondaryData, let secGrad = secondaryGradient {
                    drawFill(data: sec, in: proxy, fillColor: secGrad, opacity: 0.08)
                }
                
                // Secondary curve (GPU) drawn first so CPU sits slightly in front
                if let sec = secondaryData, let secGrad = secondaryGradient {
                    drawCurve(data: sec, in: proxy, strokeColor: secGrad)
                }
                
                // Primary curve (CPU)
                drawCurve(data: data, in: proxy, strokeColor: gradient)
            }
        }
        .frame(height: height)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.03))
        )
    }
    
    private func drawCurve(data: [Double], in proxy: GeometryProxy, strokeColor: LinearGradient) -> some View {
        let width = proxy.size.width
        let h = proxy.size.height
        let effectiveData = data.isEmpty ? [0.0, 0.0] : (data.count == 1 ? [data[0], data[0]] : data)
        let stepX = width / CGFloat(max(effectiveData.count - 1, 1))
        
        return Path { path in
            for (index, val) in effectiveData.enumerated() {
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
        .stroke(strokeColor, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
    }
    
    private func drawFill(data: [Double], in proxy: GeometryProxy, fillColor: LinearGradient, opacity: Double) -> some View {
        let width = proxy.size.width
        let h = proxy.size.height
        let effectiveData = data.isEmpty ? [0.0, 0.0] : (data.count == 1 ? [data[0], data[0]] : data)
        let stepX = width / CGFloat(max(effectiveData.count - 1, 1))
        
        return Path { path in
            path.move(to: CGPoint(x: 0, y: h))
            for (index, val) in effectiveData.enumerated() {
                let normalizedY = 1.0 - (min(max(val, 0.0), 100.0) / 100.0)
                let x = CGFloat(index) * stepX
                let y = CGFloat(normalizedY) * (h - 4) + 2
                path.addLine(to: CGPoint(x: x, y: y))
            }
            path.addLine(to: CGPoint(x: width, y: h))
            path.closeSubpath()
        }
        .fill(fillColor.opacity(opacity))
    }
}
