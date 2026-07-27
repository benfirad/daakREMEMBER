import Combine
import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case tr
    case en
    case es

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tr: "Türkçe"
        case .en: "English"
        case .es: "Español"
        }
    }

    static var systemDefault: AppLanguage {
        let preferred = Locale.preferredLanguages.first?.lowercased() ?? "en"
        if preferred.hasPrefix("tr") { return .tr }
        if preferred.hasPrefix("es") { return .es }
        return .en
    }
}

enum AppLocalization {
    private static let languageKey = "selectedAppLanguage"

    static func selectedLanguage() -> AppLanguage {
        let sharedValue = UserDefaults(suiteName: SharedStorage.appGroup)?
            .string(forKey: languageKey)
        let localValue = UserDefaults.standard.string(forKey: languageKey)
        return AppLanguage(rawValue: sharedValue ?? localValue ?? "")
            ?? AppLanguage.systemDefault
    }

    static func save(_ language: AppLanguage) {
        UserDefaults.standard.set(language.rawValue, forKey: languageKey)
        UserDefaults(suiteName: SharedStorage.appGroup)?
            .set(language.rawValue, forKey: languageKey)
    }

    static func text(
        _ key: String,
        language: AppLanguage,
        arguments: [String] = []
    ) -> String {
        let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj")
        let localizedBundle = path.flatMap(Bundle.init(path:)) ?? .main
        let format = localizedBundle.localizedString(
            forKey: key,
            value: key,
            table: nil
        )
        guard !arguments.isEmpty else { return format }
        return String(
            format: format,
            locale: Locale(identifier: language.rawValue),
            arguments: arguments.map { $0 as CVarArg }
        )
    }
}

final class LocalizationController: ObservableObject {
    @Published var language: AppLanguage {
        didSet { AppLocalization.save(language) }
    }

    init() {
        language = AppLocalization.selectedLanguage()
        AppLocalization.save(language)
    }

    func text(_ key: String, arguments: [String] = []) -> String {
        AppLocalization.text(key, language: language, arguments: arguments)
    }
}
