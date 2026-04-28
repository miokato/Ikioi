import Foundation
import SwiftUI
import Observation
import Translation

enum ArticleDetailPhase {
    case idle
    case loading
    case loaded(ArticleSummary)
    case failed(String)
}

@MainActor
protocol ArticleDetailViewStateProtocol: AnyObject, Observable {
    var phase: ArticleDetailPhase { get }
    var article: TrendArticle { get }
    var translation: DetailTranslationPhase { get }
    var isTranslationEnabled: Bool { get }
    var translationConfig: TranslationSession.Configuration? { get }
    var needsTranslation: Bool { get }
    func load() async
    func webSearchURL() -> URL?
    func toggleTranslation()
    func performTranslation(using session: TranslationSession) async
}

@MainActor
@Observable
final class ArticleDetailViewStateMock: ArticleDetailViewStateProtocol {
    var phase: ArticleDetailPhase
    let article: TrendArticle
    var translation: DetailTranslationPhase
    var isTranslationEnabled: Bool
    var translationConfig: TranslationSession.Configuration?
    var needsTranslation: Bool

    init(
        phase: ArticleDetailPhase = .loaded(PreviewWikipediaAPIClient.defaultSummary),
        article: TrendArticle = PreviewWikipediaAPIClient.defaultTrending[0],
        translation: DetailTranslationPhase = .idle,
        isTranslationEnabled: Bool = false,
        needsTranslation: Bool = false
    ) {
        self.phase = phase
        self.article = article
        self.translation = translation
        self.isTranslationEnabled = isTranslationEnabled
        self.needsTranslation = needsTranslation
    }

    func load() async {}

    func webSearchURL() -> URL? {
        var components = URLComponents(string: "https://www.google.com/search")
        components?.queryItems = [URLQueryItem(name: "q", value: article.title)]
        return components?.url
    }

    func toggleTranslation() {
        isTranslationEnabled.toggle()
    }

    func performTranslation(using session: TranslationSession) async {}
}

@MainActor
struct ArticleDetailViewStateKey: @preconcurrency EnvironmentKey {
    static let defaultValue: any ArticleDetailViewStateProtocol = ArticleDetailViewStateMock()
}

extension EnvironmentValues {
    var articleDetailViewState: any ArticleDetailViewStateProtocol {
        get { self[ArticleDetailViewStateKey.self] }
        set { self[ArticleDetailViewStateKey.self] = newValue }
    }
}

@MainActor
@Observable
final class ArticleDetailViewState: ArticleDetailViewStateProtocol {
    private(set) var phase: ArticleDetailPhase = .idle
    let article: TrendArticle
    let country: Country
    var translation: DetailTranslationPhase = .idle
    private(set) var isTranslationEnabled: Bool = true
    private(set) var translationConfig: TranslationSession.Configuration?

    private let client: WikipediaAPIClient
    private let translator: any ArticleTranslatorProtocol
    private let userLanguage: Locale.Language

    init(
        article: TrendArticle,
        country: Country,
        client: WikipediaAPIClient,
        translator: any ArticleTranslatorProtocol,
        userLanguage: Locale.Language = Locale.userPreferredLanguage
    ) {
        self.article = article
        self.country = country
        self.client = client
        self.translator = translator
        self.userLanguage = userLanguage
    }

    var needsTranslation: Bool {
        let countryLangCode = Locale.Language(identifier: country.languageCode).languageCode
        return countryLangCode != userLanguage.languageCode
    }

    func load() async {
        phase = .loading
        translation = .idle
        translationConfig = nil
        do {
            let summary = try await client.fetchSummary(
                languageCode: country.languageCode,
                rawTitle: article.rawTitle
            )
            phase = .loaded(summary)
            updateTranslationConfig()
        } catch {
            phase = .failed(String(describing: error))
        }
    }

    func performTranslation(using session: TranslationSession) async {
        guard case .loaded(let summary) = phase else { return }
        translation = .loading
        do {
            let translated = try await translator.translateArticle(
                title: article.title,
                extract: summary.extract,
                description: summary.description,
                using: session
            )
            translation = .translated(translated)
        } catch {
            translation = .failed(String(describing: error))
        }
    }

    func toggleTranslation() {
        isTranslationEnabled.toggle()
        if isTranslationEnabled {
            updateTranslationConfig()
        } else {
            translation = .idle
            translationConfig = nil
        }
    }

    func webSearchURL() -> URL? {
        var components = URLComponents(string: "https://www.google.com/search")
        components?.queryItems = [URLQueryItem(name: "q", value: article.title)]
        return components?.url
    }

    private func updateTranslationConfig() {
        guard isTranslationEnabled, needsTranslation, case .loaded = phase else {
            translationConfig = nil
            return
        }
        translation = .loading
        translationConfig = TranslationSession.Configuration(
            source: Locale.Language(identifier: country.languageCode),
            target: userLanguage
        )
    }
}
