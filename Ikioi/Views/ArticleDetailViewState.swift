import Foundation
import SwiftUI
import Observation

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
    func load() async
    func webSearchURL() -> URL?
}

@MainActor
@Observable
final class ArticleDetailViewStateMock: ArticleDetailViewStateProtocol {
    var phase: ArticleDetailPhase
    let article: TrendArticle

    init(
        phase: ArticleDetailPhase = .loaded(PreviewWikipediaAPIClient.defaultSummary),
        article: TrendArticle = PreviewWikipediaAPIClient.defaultTrending[0]
    ) {
        self.phase = phase
        self.article = article
    }

    func load() async {}

    func webSearchURL() -> URL? {
        var components = URLComponents(string: "https://www.google.com/search")
        components?.queryItems = [URLQueryItem(name: "q", value: article.title)]
        return components?.url
    }
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

    private let client: WikipediaAPIClient

    init(article: TrendArticle, country: Country, client: WikipediaAPIClient) {
        self.article = article
        self.country = country
        self.client = client
    }

    func load() async {
        phase = .loading
        do {
            let summary = try await client.fetchSummary(
                languageCode: country.languageCode,
                rawTitle: article.rawTitle
            )
            phase = .loaded(summary)
        } catch {
            phase = .failed(String(describing: error))
        }
    }

    func webSearchURL() -> URL? {
        var components = URLComponents(string: "https://www.google.com/search")
        components?.queryItems = [URLQueryItem(name: "q", value: article.title)]
        return components?.url
    }
}
