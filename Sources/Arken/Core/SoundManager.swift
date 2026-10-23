import Foundation
import AppKit
import Combine

public enum SoundEffect {
    case success
    case action
    case pop
    case warning
    case alert
}

public enum SoundScheme: String, CaseIterable, Identifiable {
    case classic = "classic"
    case minimal = "minimal"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .classic: return L10n.tr("Classic Mac (Glass, Pop, Tink)", "Klasik Mac (Glass, Pop, Tink)")
        case .minimal: return L10n.tr("Minimalist (Ping, Hero, Purr)", "Minimalist (Ping, Hero, Purr)")
        }
    }
}

public class SoundManager: ObservableObject {
    public static let shared = SoundManager()
    
    @Published public var isSoundEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(isSoundEnabled, forKey: "ArkenSoundEnabled")
        }
    }
    
    @Published public var selectedScheme: SoundScheme = .classic {
        didSet {
            UserDefaults.standard.set(selectedScheme.rawValue, forKey: "ArkenSoundScheme")
        }
    }
    
    private init() {
        if let saved = UserDefaults.standard.object(forKey: "ArkenSoundEnabled") as? Bool {
            self.isSoundEnabled = saved
        } else if let legacy = UserDefaults.standard.object(forKey: "PalantirSoundEnabled") as? Bool {
            self.isSoundEnabled = legacy
        }
        if let savedScheme = UserDefaults.standard.string(forKey: "ArkenSoundScheme") ?? UserDefaults.standard.string(forKey: "PalantirSoundScheme"),
           let scheme = SoundScheme(rawValue: savedScheme) {
            self.selectedScheme = scheme
        }
    }
    
    public func play(_ effect: SoundEffect) {
        guard isSoundEnabled else { return }
        playSound(effect, scheme: selectedScheme)
    }
    
    public func testPlay(_ effect: SoundEffect) {
        playSound(effect, scheme: selectedScheme)
    }
    
    private func playSound(_ effect: SoundEffect, scheme: SoundScheme) {
        let soundName: String
        
        switch scheme {
        case .classic:
            switch effect {
            case .success: soundName = "Glass"
            case .action: soundName = "Tink"
            case .pop: soundName = "Pop"
            case .warning: soundName = "Basso"
            case .alert: soundName = "Submarine"
            }
        case .minimal:
            switch effect {
            case .success: soundName = "Ping"
            case .action: soundName = "Purr"
            case .pop: soundName = "Hero"
            case .warning: soundName = "Morse"
            case .alert: soundName = "Hero"
            }
        }
        
        NSSound(named: soundName)?.play()
    }
}
