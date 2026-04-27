import Foundation
import Observation

@MainActor
@Observable
final class ArticleDetailViewState {
    enum Phase {
        case idle
        case loading
        case loaded(ArticleSummary)
        case failed(String)
    }

    private(set) var phase: Phase = .idle
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
