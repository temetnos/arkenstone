import Foundation
import Combine
import SwiftUI

public enum AppLanguage: String, CaseIterable, Identifiable {
    case en = "en"
    case tr = "tr"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .en: return "English"
        case .tr: return "Türkçe"
        }
    }
}

public class LocalizationManager: ObservableObject {
    public static let shared = LocalizationManager()
    
    private let languageKey = "arken_app_language"
    
    @Published public var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: languageKey)
            NotificationCenter.default.post(name: NSNotification.Name("ArkenLanguageChanged"), object: nil)
        }
    }
    
    public init() {
        if let saved = UserDefaults.standard.string(forKey: languageKey) ?? UserDefaults.standard.string(forKey: "palantir_app_language"),
           let lang = AppLanguage(rawValue: saved) {
            self.language = lang
        } else {
            // English is primary default
            self.language = .en
        }
    }
    
    public func setLanguage(_ lang: AppLanguage) {
        self.language = lang
    }
}

public struct L10n {
    public static func tr(_ en: String, _ tr: String) -> String {
        return LocalizationManager.shared.language == .tr ? tr : en
    }
}
