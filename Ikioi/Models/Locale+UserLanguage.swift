import Foundation

extension Locale {
    // Locale.current.language はアプリのローカライズに依存して解決されるため、
    // アプリが当該言語に未ローカライズだと別言語にフォールバックする。
    // 翻訳先はユーザーの「優先する言語」設定そのものを使いたいため preferredLanguages を見る。
    static var userPreferredLanguage: Locale.Language {
        Locale.Language(identifier: Locale.preferredLanguages.first ?? "en")
    }
}
