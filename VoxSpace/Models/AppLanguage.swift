import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case spanish = "es"
    case english = "en"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .spanish:
            return "Español"
        case .english:
            return "English"
        }
    }
}
