import Foundation
import AppKit
import Vision
import Combine
import CoreGraphics

public class ScreenOCREngine: ObservableObject {
    public static let shared = ScreenOCREngine()
    
    @Published public var isCapturing: Bool = false
    @Published public var lastRecognizedText: String = ""
    @Published public var statusMessage: String = ""
    
    public init() {}
    
    public func hasPermission() -> Bool {
        return CGPreflightScreenCaptureAccess()
    }
    
    public func openScreenCapturePrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
    
    public func startCaptureAndRecognize(completion: ((String?) -> Void)? = nil) {
        guard !isCapturing else { return }
        
        // Preflight Screen Capture Permission
        if !CGPreflightScreenCaptureAccess() {
            _ = CGRequestScreenCaptureAccess()
            DispatchQueue.main.async {
                self.statusMessage = L10n.tr(
                    "Screen recording permission required. Please allow ArkenStone in System Settings.",
                    "Ekran kaydı izni gerekiyor. Lütfen Sistem Ayarları'ndan ArkenStone'a izin verin."
                )
                self.openScreenCapturePrivacySettings()
            }
            completion?(nil)
            return
        }
        
        isCapturing = true
        statusMessage = L10n.tr("Select text area on screen...", "Ekranda metin alanını seçin...")
        
        let tempImagePath = NSTemporaryDirectory() + "arken_ocr_\(UUID().uuidString).png"
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            defer {
                try? FileManager.default.removeItem(atPath: tempImagePath)
            }
            
            // Invoke native interactive screencapture with crosshair selection
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = ["-i", "-s", tempImagePath]
            
            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                DispatchQueue.main.async {
                    self.isCapturing = false
                    self.statusMessage = L10n.tr("Could not start screenshot capture.", "Ekran alıntısı başlatılamadı.")
                    completion?(nil)
                }
                return
            }
            
            // Check if file was created (user didn't press Esc)
            guard FileManager.default.fileExists(atPath: tempImagePath),
                  let image = NSImage(contentsOfFile: tempImagePath),
                  let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                DispatchQueue.main.async {
                    self.isCapturing = false
                    self.statusMessage = L10n.tr("Selection cancelled.", "Seçim iptal edildi.")
                    completion?(nil)
                }
                return
            }
            
            // Recognize text & QR/barcodes via Apple Vision framework
            self.performVisionOCR(cgImage: cgImage) { recognized, isQR in
                
                DispatchQueue.main.async {
                    self.isCapturing = false
                    if let text = recognized, !text.isEmpty {
                        self.lastRecognizedText = text
                        if isQR {
                            self.statusMessage = L10n.tr("QR / Barcode detected & copied!", "QR / Barkod tespit edildi ve kopyalandı!")
                        } else {
                            self.statusMessage = L10n.tr("\(text.count) characters copied!", "\(text.count) karakter kopyalandı!")
                        }
                        
                        // Copy to Pasteboard
                        let pboard = NSPasteboard.general
                        pboard.clearContents()
                        pboard.setString(text, forType: .string)
                        
                        // Also notify ClipboardEngine
                        ClipboardEngine.shared.checkPasteboard()
                        
                        SoundManager.shared.play(.success)
                        completion?(text)
                    } else {
                        self.statusMessage = L10n.tr("No text or QR code detected.", "Görselde metin veya QR kod tespit edilemedi.")
                        SoundManager.shared.play(.warning)
                        completion?(nil)
                    }
                }
            }
        }
    }
    
    private func performVisionOCR(cgImage: CGImage, completion: @escaping (String?, Bool) -> Void) {
        var barcodePayload: String?
        var textLines: [String] = []
        
        let barcodeRequest = VNDetectBarcodesRequest { request, error in
            guard error == nil, let observations = request.results as? [VNBarcodeObservation] else { return }
            for obs in observations {
                if let payload = obs.payloadStringValue, !payload.isEmpty {
                    barcodePayload = payload
                    break
                }
            }
        }
        
        let textRequest = VNRecognizeTextRequest { request, error in
            guard error == nil, let observations = request.results as? [VNRecognizedTextObservation] else { return }
            for observation in observations {
                if let candidate = observation.topCandidates(1).first {
                    textLines.append(candidate.string)
                }
            }
        }
        
        textRequest.recognitionLevel = .accurate
        textRequest.usesLanguageCorrection = true
        // Support English, Turkish, code, numbers
        textRequest.recognitionLanguages = ["tr-TR", "en-US"]
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([barcodeRequest, textRequest])
            if let qr = barcodePayload {
                completion(qr, true)
            } else {
                let fullText = textLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                completion(fullText.isEmpty ? nil : fullText, false)
            }
        } catch {
            completion(nil, false)
        }
    }
}
