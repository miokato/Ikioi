import Foundation
import Translation
@testable import Ikioi

final class ArticleTranslatorStub: ArticleTranslatorProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var _articleResult: TranslatedArticle?
    private var _titlesResult: [String: String]?
    private var _error: Error?

    var articleResult: TranslatedArticle? {
        get { lock.lock(); defer { lock.unlock() }; return _articleResult }
        set { lock.lock(); _articleResult = newValue; lock.unlock() }
    }

    var titlesResult: [String: String]? {
        get { lock.lock(); defer { lock.unlock() }; return _titlesResult }
        set { lock.lock(); _titlesResult = newValue; lock.unlock() }
    }

    var error: Error? {
        get { lock.lock(); defer { lock.unlock() }; return _error }
        set { lock.lock(); _error = newValue; lock.unlock() }
    }

    func translateArticle(
        title: String,
        extract: String,
        description: String?,
        using session: TranslationSession
    ) async throws -> TranslatedArticle {
        if let error { throw error }
        if let articleResult { return articleResult }
        return TranslatedArticle(
            title: "T:" + title,
            extract: "E:" + extract,
            description: description.map { "D:" + $0 }
        )
    }

    func translateTitles(
        _ titlesByID: [(id: String, title: String)],
        using session: TranslationSession
    ) async throws -> [String: String] {
        if let error { throw error }
        if let titlesResult { return titlesResult }
        var fallback: [String: String] = [:]
        for item in titlesByID {
            fallback[item.id] = "T:" + item.title
        }
        return fallback
    }
}
