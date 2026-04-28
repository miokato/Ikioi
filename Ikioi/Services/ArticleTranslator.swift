import Foundation
import Translation

protocol ArticleTranslatorProtocol: Sendable {
    func translateArticle(
        title: String,
        extract: String,
        description: String?,
        using session: TranslationSession
    ) async throws -> TranslatedArticle

    func translateTitles(
        _ titlesByID: [(id: String, title: String)],
        using session: TranslationSession
    ) async throws -> [String: String]
}

struct LiveArticleTranslator: ArticleTranslatorProtocol {
    func translateArticle(
        title: String,
        extract: String,
        description: String?,
        using session: TranslationSession
    ) async throws -> TranslatedArticle {
        var requests: [TranslationSession.Request] = [
            TranslationSession.Request(sourceText: title, clientIdentifier: "title"),
            TranslationSession.Request(sourceText: extract, clientIdentifier: "extract"),
        ]
        if let description {
            requests.append(
                TranslationSession.Request(sourceText: description, clientIdentifier: "description")
            )
        }
        let responses = try await session.translations(from: requests)
        var translatedTitle = title
        var translatedExtract = extract
        var translatedDescription: String? = description
        for response in responses {
            switch response.clientIdentifier {
            case "title": translatedTitle = response.targetText
            case "extract": translatedExtract = response.targetText
            case "description": translatedDescription = response.targetText
            default: break
            }
        }
        return TranslatedArticle(
            title: translatedTitle,
            extract: translatedExtract,
            description: translatedDescription
        )
    }

    func translateTitles(
        _ titlesByID: [(id: String, title: String)],
        using session: TranslationSession
    ) async throws -> [String: String] {
        let requests = titlesByID.map {
            TranslationSession.Request(sourceText: $0.title, clientIdentifier: $0.id)
        }
        let responses = try await session.translations(from: requests)
        var result: [String: String] = [:]
        for response in responses {
            if let id = response.clientIdentifier {
                result[id] = response.targetText
            }
        }
        return result
    }
}

struct ArticleTranslatorMock: ArticleTranslatorProtocol {
    let prefix: String

    init(prefix: String = "[mock]") {
        self.prefix = prefix
    }

    func translateArticle(
        title: String,
        extract: String,
        description: String?,
        using session: TranslationSession
    ) async throws -> TranslatedArticle {
        TranslatedArticle(
            title: "\(prefix) \(title)",
            extract: "\(prefix) \(extract)",
            description: description.map { "\(prefix) \($0)" }
        )
    }

    func translateTitles(
        _ titlesByID: [(id: String, title: String)],
        using session: TranslationSession
    ) async throws -> [String: String] {
        var result: [String: String] = [:]
        for item in titlesByID {
            result[item.id] = "\(prefix) \(item.title)"
        }
        return result
    }
}
