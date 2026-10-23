import Foundation
import AppKit
import Combine

public class ColorPickerEngine: ObservableObject {
    public static let shared = ColorPickerEngine()
    
    @Published public var isSampling: Bool = false
    @Published public var lastSampledHex: String?
    @Published public var lastSampledRGB: String?
    @Published public var lastSampledColor: NSColor?
    @Published public var statusMessage: String?
    
    private init() {}
    
    public func pickColor(completion: ((String?) -> Void)? = nil) {
        guard #available(macOS 10.15, *) else {
            completion?(nil)
            return
        }
        
        isSampling = true
        statusMessage = L10n.tr("Select color with magnifying glass...", "Büyüteçle ekrandan renk seçin...")
        
        // Native macOS NSColorSampler displays interactive circular loupe with pixel grid!
        NSColorSampler().show { [weak self] selectedColor in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isSampling = false
                
                guard let color = selectedColor else {
                    self.statusMessage = L10n.tr("Color selection cancelled", "Renk seçimi iptal edildi")
                    completion?(nil)
                    return
                }
                
                // Convert to standard sRGB color space
                guard let srgb = color.usingColorSpace(.sRGB) else {
                    completion?(nil)
                    return
                }
                
                let r = Int(round(srgb.redComponent * 255.0))
                let g = Int(round(srgb.greenComponent * 255.0))
                let b = Int(round(srgb.blueComponent * 255.0))
                
                let hexString = String(format: "#%02X%02X%02X", r, g, b)
                let rgbString = "rgb(\(r), \(g), \(b))"
                
                self.lastSampledHex = hexString
                self.lastSampledRGB = rgbString
                self.lastSampledColor = srgb
                self.statusMessage = L10n.tr("Color copied: \(hexString)", "Renk panoya kopyalandı: \(hexString)")
                
                // Copy HEX to System Pasteboard
                let pboard = NSPasteboard.general
                pboard.clearContents()
                pboard.setString(hexString, forType: .string)
                
                // Automatically record to ClipboardEngine history
                ClipboardEngine.shared.checkPasteboard()
                
                SoundManager.shared.play(.success)
                completion?(hexString)
            }
        }
    }
}
