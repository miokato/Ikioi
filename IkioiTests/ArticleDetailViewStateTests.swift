import Foundation
import Testing
@testable import Ikioi

struct ArticleDetailViewStateTests {
    private static let testCountry = Country(
        id: "JP",
        nameKey: "country.JP",
        wikipediaProject: "ja.wikipedia.org",
        languageCode: "ja",
        flagEmoji: "🇯🇵",
        note: nil
    )

    private static let testArticle = TrendArticle(
        id: "大谷翔平",
        rank: 1,
        title: "大谷翔平",
        rawTitle: "大谷翔平",
        viewCount: 100
    )

    private static let testSummary = ArticleSummary(
        extract: "本文",
        thumbnailURL: URL(string: "https://example.com/photo.jpg"),
        pageURL: URL(string: "https://ja.wikipedia.org/wiki/Test")!,
        description: "説明"
    )

    @Test @MainActor func loadSuccessUpdatesPhaseToLoaded() async {
        let state = ArticleDetailViewState(
            article: Self.testArticle,
            country: Self.testCountry,
            client: StubWikipediaAPIClient(summaryResult: .success(Self.testSummary))
        )
        await state.load()
        guard case .loaded(let summary) = state.phase else {
            Issue.record("expected .loaded, got \(state.phase)")
            return
        }
        #expect(summary.extract == "本文")
        #expect(summary.description == "説明")
    }

    @Test @MainActor func loadFailureUpdatesPhaseToFailed() async {
        let state = ArticleDetailViewState(
            article: Self.testArticle,
            country: Self.testCountry,
            client: StubWikipediaAPIClient(summaryResult: .failure(.httpError(503)))
        )
        await state.load()
        if case .failed = state.phase {
            // expected
        } else {
            Issue.record("expected .failed, got \(state.phase)")
        }
    }

    @Test @MainActor func loadStartsAsLoadingThenSettles() async {
        let state = ArticleDetailViewState(
            article: Self.testArticle,
            country: Self.testCountry,
            client: StubWikipediaAPIClient(summaryResult: .success(Self.testSummary))
        )
        if case .idle = state.phase {
            // expected initial
        } else {
            Issue.record("expected initial .idle")
        }
        await state.load()
        if case .loaded = state.phase {
            // expected
        } else {
            Issue.record("expected .loaded after load")
        }
    }

    @Test @MainActor func webSearchURLEncodesTitleSpaces() {
        let state = ArticleDetailViewState(
            article: TrendArticle(
                id: "Albert_Einstein",
                rank: 1,
                title: "Albert Einstein",
                rawTitle: "Albert_Einstein",
                viewCount: 100
            ),
            country: Self.testCountry,
            client: StubWikipediaAPIClient()
        )
        let url = state.webSearchURL()
        #expect(url?.absoluteString == "https://www.google.com/search?q=Albert%20Einstein")
    }
}

private struct StubWikipediaAPIClient: WikipediaAPIClient {
    enum SummaryResult: Sendable {
        case success(ArticleSummary)
        case failure(WikipediaAPIError)
    }

    let trending: [TrendArticle]
    let summaryResult: SummaryResult

    init(
        trending: [TrendArticle] = [],
        summaryResult: SummaryResult = .failure(.invalidResponse)
    ) {
        self.trending = trending
        self.summaryResult = summaryResult
    }

    nonisolated func fetchTrending(project: String, date: Date) async throws -> [TrendArticle] {
        trending
    }

    nonisolated func fetchSummary(languageCode: String, rawTitle: String) async throws -> ArticleSummary {
        switch summaryResult {
        case .success(let summary): return summary
        case .failure(let error): throw error
        }
    }
}
