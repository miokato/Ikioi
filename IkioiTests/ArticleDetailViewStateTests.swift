import Foundation
import Testing
@testable import Ikioi

@MainActor
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

    private static func makeState(
        article: TrendArticle = ArticleDetailViewStateTests.testArticle,
        country: Country = ArticleDetailViewStateTests.testCountry,
        client: WikipediaAPIClient,
        userLanguage: Locale.Language = Locale.Language(identifier: "ja")
    ) -> ArticleDetailViewState {
        ArticleDetailViewState(
            article: article,
            country: country,
            client: client,
            translator: ArticleTranslatorStub(),
            userLanguage: userLanguage
        )
    }

    @Test func loadSuccessUpdatesPhaseToLoaded() async {
        let state = Self.makeState(
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

    @Test func loadFailureUpdatesPhaseToFailed() async {
        let state = Self.makeState(
            client: StubWikipediaAPIClient(summaryResult: .failure(.httpError(503)))
        )
        await state.load()
        if case .failed = state.phase {
            // expected
        } else {
            Issue.record("expected .failed, got \(state.phase)")
        }
    }

    @Test func loadStartsAsLoadingThenSettles() async {
        let state = Self.makeState(
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

    @Test func webSearchURLEncodesTitleSpaces() {
        let state = Self.makeState(
            article: TrendArticle(
                id: "Albert_Einstein",
                rank: 1,
                title: "Albert Einstein",
                rawTitle: "Albert_Einstein",
                viewCount: 100
            ),
            client: StubWikipediaAPIClient()
        )
        let url = state.webSearchURL()
        #expect(url?.absoluteString == "https://www.google.com/search?q=Albert%20Einstein")
    }

    @Test func needsTranslationIsFalseForSameLanguage() {
        let state = Self.makeState(
            client: StubWikipediaAPIClient(),
            userLanguage: Locale.Language(identifier: "ja")
        )
        #expect(state.needsTranslation == false)
    }

    @Test func needsTranslationIsTrueForDifferentLanguage() {
        let state = Self.makeState(
            client: StubWikipediaAPIClient(),
            userLanguage: Locale.Language(identifier: "en")
        )
        #expect(state.needsTranslation == true)
    }

    @Test func loadSetsTranslationConfigOnDifferentLanguage() async {
        let state = Self.makeState(
            client: StubWikipediaAPIClient(summaryResult: .success(Self.testSummary)),
            userLanguage: Locale.Language(identifier: "en")
        )
        await state.load()
        #expect(state.translationConfig != nil)
        if case .loading = state.translation {
            // expected (waiting for translation task)
        } else {
            Issue.record("expected translation phase to be .loading after load, got \(state.translation)")
        }
    }

    @Test func loadKeepsTranslationConfigNilOnSameLanguage() async {
        let state = Self.makeState(
            client: StubWikipediaAPIClient(summaryResult: .success(Self.testSummary)),
            userLanguage: Locale.Language(identifier: "ja")
        )
        await state.load()
        #expect(state.translationConfig == nil)
    }

    @Test func toggleTranslationKeepsCacheWhenDisabled() async {
        let state = Self.makeState(
            client: StubWikipediaAPIClient(summaryResult: .success(Self.testSummary)),
            userLanguage: Locale.Language(identifier: "en")
        )
        await state.load()
        let cached = TranslatedArticle(title: "T", extract: "E", description: nil)
        state.translation = .translated(cached)
        #expect(state.isTranslationEnabled == true)

        state.toggleTranslation()
        #expect(state.isTranslationEnabled == false)
        if case .translated(let value) = state.translation {
            #expect(value == cached)
        } else {
            Issue.record("expected cached translation to be kept, got \(state.translation)")
        }

        state.toggleTranslation()
        #expect(state.isTranslationEnabled == true)
        if case .translated(let value) = state.translation {
            #expect(value == cached)
        } else {
            Issue.record("expected cached translation to be restored, got \(state.translation)")
        }
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
