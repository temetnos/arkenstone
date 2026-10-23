import Foundation
import AppKit

let currentDir = FileManager.default.currentDirectoryPath
let inputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "\(currentDir)/assets/AppIcon_1024.png"
guard let sourceImage = NSImage(contentsOfFile: inputPath) else {
    print("Failed to load source image")
    exit(1)
}

let canvasSize = NSSize(width: 1024, height: 1024)
let outputImage = NSImage(size: canvasSize)

outputImage.lockFocus()

guard let context = NSGraphicsContext.current?.cgContext else {
    print("Failed to get graphics context")
    exit(1)
}

// Clear to fully transparent
context.clear(CGRect(origin: .zero, size: canvasSize))

// In macOS coordinate system, y starts at bottom.
// In source image, top border is y=106 from top, so in AppKit coords: y = 1024 - 918 = 106 from bottom!
let squircleRect = CGRect(x: 106, y: 106, width: 812, height: 812)
let cornerRadius: CGFloat = 184.0

let squirclePath = CGPath(roundedRect: squircleRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

// 1. Draw Apple-standard soft drop shadow beneath squircle
context.saveGState()
context.setShadow(
    offset: CGSize(width: 0, height: -12),
    blur: 24,
    color: NSColor.black.withAlphaComponent(0.42).cgColor
)
context.addPath(squirclePath)
context.setFillColor(NSColor.black.cgColor)
context.fillPath()
context.restoreGState()

// 2. Clip to squircle and draw image
context.saveGState()
context.addPath(squirclePath)
context.clip()

// Draw source image into full 1024x1024 rect
sourceImage.draw(in: NSRect(origin: .zero, size: canvasSize))

context.restoreGState()

outputImage.unlockFocus()

// Save master 1024x1024 PNG
guard let tiffData = outputImage.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData),
      let pngData = bitmap.representation(using: .png, properties: [:]) else {
    print("Failed to encode PNG")
    exit(1)
}

let outputDir = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "\(currentDir)/assets"
try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
let masterPngPath = "\(outputDir)/AppIcon_1024.png"
try pngData.write(to: URL(fileURLWithPath: masterPngPath))
print("Master 1024x1024 icon saved to \(masterPngPath)")

// Now generate iconset sizes and compile AppIcon.icns
let iconsetDir = "\(outputDir)/AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

let sizes: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (filename, px) in sizes {
    let destPath = "\(iconsetDir)/\(filename)"
    let resizedImage = NSImage(size: NSSize(width: px, height: px))
    resizedImage.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    outputImage.draw(in: NSRect(x: 0, y: 0, width: px, height: px), from: .zero, operation: .copy, fraction: 1.0)
    resizedImage.unlockFocus()
    
    if let rTiff = resizedImage.tiffRepresentation,
       let rBitmap = NSBitmapImageRep(data: rTiff),
       let rPng = rBitmap.representation(using: .png, properties: [:]) {
        try? rPng.write(to: URL(fileURLWithPath: destPath))
    }
}

print("Iconset created at \(iconsetDir)")

// Run iconutil -c icns
let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
proc.arguments = ["-c", "icns", iconsetDir, "-o", "\(outputDir)/AppIcon.icns"]
try proc.run()
proc.waitUntilExit()

if proc.terminationStatus == 0 {
    print("AppIcon.icns successfully generated at \(outputDir)/AppIcon.icns")
} else {
    print("iconutil failed with code \(proc.terminationStatus)")
    exit(1)
}
