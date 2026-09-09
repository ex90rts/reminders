import Foundation
import SwiftUI

enum AppLanguage: String, Codable, CaseIterable, Hashable, Identifiable {
    case system
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case englishUS = "en-US"

    var id: Self { self }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = Self(rawValue: rawValue) ?? .system
    }

    var resolved: AppLanguage {
        self == .system ? Self.resolve(preferredLanguages: Locale.preferredLanguages) : self
    }

    var locale: Locale {
        Locale(identifier: resolved.localizationIdentifier)
    }

    var selectionTitle: String {
        switch self {
        case .system: localized("跟随系统")
        case .simplifiedChinese: localized("简体中文")
        case .traditionalChinese: localized("繁體中文")
        case .englishUS: localized("English (US)")
        }
    }

    static func resolve(preferredLanguages: [String]) -> AppLanguage {
        guard let preferredLanguage = preferredLanguages.first else { return .englishUS }
        let normalized = preferredLanguage.replacingOccurrences(of: "_", with: "-").lowercased()
        guard normalized == "zh" || normalized.hasPrefix("zh-") else { return .englishUS }

        let usesTraditionalChinese = normalized.contains("-hant")
            || normalized.contains("-tw")
            || normalized.contains("-hk")
            || normalized.contains("-mo")
        return usesTraditionalChinese ? .traditionalChinese : .simplifiedChinese
    }

    func localized(_ key: String, _ arguments: CVarArg...) -> String {
        AppLocalization.localized(key, language: self, arguments: arguments)
    }

    fileprivate var localizationIdentifier: String {
        switch self {
        case .system:
            resolved.localizationIdentifier
        case .simplifiedChinese:
            "zh-Hans"
        case .traditionalChinese:
            "zh-Hant"
        case .englishUS:
            "en"
        }
    }
}

enum AppLocalization {
    static func localized(
        _ key: String,
        language: AppLanguage,
        arguments: [CVarArg] = []
    ) -> String {
        let resolvedLanguage = language.resolved
        let format = localizationBundle(for: resolvedLanguage)?
            .localizedString(forKey: key, value: key, table: nil) ?? key
        guard !arguments.isEmpty else { return format }
        return String(format: format, locale: resolvedLanguage.locale, arguments: arguments)
    }

    private static func localizationBundle(for language: AppLanguage) -> Bundle? {
        guard let path = Bundle.main.path(
            forResource: language.localizationIdentifier,
            ofType: "lproj"
        ) else { return nil }
        return Bundle(path: path)
    }
}

private struct AppLanguageEnvironmentKey: EnvironmentKey {
    static let defaultValue = AppLanguage.system
}

extension EnvironmentValues {
    var appLanguage: AppLanguage {
        get { self[AppLanguageEnvironmentKey.self] }
        set { self[AppLanguageEnvironmentKey.self] = newValue }
    }
}

extension View {
    func appLanguage(_ language: AppLanguage) -> some View {
        environment(\.appLanguage, language)
            .environment(\.locale, language.locale)
    }
}
