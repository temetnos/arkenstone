import SwiftUI

public enum ArkenTheme {
    // Primary Accent Colors
    public static let cpuColor = Color(red: 0.0, green: 0.75, blue: 1.0)       // Cyan / Electric Blue
    public static let gpuColor = Color(red: 0.72, green: 0.35, blue: 1.0)      // Neon Violet
    public static let ramColor = Color(red: 0.2, green: 0.85, blue: 0.45)      // Emerald Green
    public static let tempColor = Color(red: 1.0, green: 0.58, blue: 0.0)      // Amber / Orange
    public static let batteryColor = Color(red: 0.25, green: 0.88, blue: 0.35) // Mint / Battery Green
    public static let accentColor = Color(red: 0.4, green: 0.6, blue: 1.0)     // Soft Blue
    
    // Backgrounds & Surface
    public static let cardBackground = Color(NSColor.windowBackgroundColor).opacity(0.4)
    public static let cardBorder = Color.white.opacity(0.12)
    public static let subtext = Color.secondary
    
    // Gradients
    public static let cpuGradient = LinearGradient(
        colors: [Color(red: 0.0, green: 0.85, blue: 1.0), Color(red: 0.0, green: 0.45, blue: 0.95)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let gpuGradient = LinearGradient(
        colors: [Color(red: 0.8, green: 0.4, blue: 1.0), Color(red: 0.5, green: 0.1, blue: 0.9)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let ramGradient = LinearGradient(
        colors: [Color(red: 0.3, green: 0.9, blue: 0.5), Color(red: 0.1, green: 0.7, blue: 0.35)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let tempGradient = LinearGradient(
        colors: [Color(red: 1.0, green: 0.7, blue: 0.2), Color(red: 1.0, green: 0.3, blue: 0.1)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let batteryGradient = LinearGradient(
        colors: [Color(red: 0.2, green: 0.85, blue: 0.4), Color(red: 0.05, green: 0.6, blue: 0.25)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
