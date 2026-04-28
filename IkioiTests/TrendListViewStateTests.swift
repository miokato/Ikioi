import Foundation
import Testing
@testable import Ikioi

@MainActor
struct TrendListViewStateTests {
    private static let japan = Country(
        id: "JP", nameKey: "country.JP", wikipediaProject: "ja.wikipedia.org",
        languageCode: "ja", flagEmoji: "🇯🇵", note: nil
    )
    private static let france = Country(
        id: "FR", nameKey: "country.FR", wikipediaProject: "fr.wikipedia.org",
        languageCode: "fr", flagEmoji: "🇫🇷", note: nil
    )

    @Test func setCountrySwitchesAndReloads() async {
        let stub = MultiProjectStubClient(
            trendingByProject: [
                "ja.wikipedia.org": [TrendArticle(id: "JA", rank: 1, title: "JA", rawTitle: "JA", viewCount: 1)],
                "fr.wikipedia.org": [TrendArticle(id: "FR", rank: 1, title: "FR", rawTitle: "FR", viewCount: 2)],
            ]
        )
        let state = TrendListViewState(
            country: Self.japan,
            client: stub,
            filter: ArticleFilter(blocklist: [:]),
            translator: ArticleTranslatorStub(),
            userLanguage: Locale.Language(identifier: "ja")
        )
        await state.load()
        guard case .loaded(let before) = state.phase else {
            Issue.record("expected .loaded after first load, got \(state.phase)")
            return
        }
        #expect(before.first?.id == "JA")

        await state.setCountry(Self.france)

        #expect(state.country.id == "FR")
        guard case .loaded(let after) = state.phase else {
            Issue.record("expected .loaded after setCountry, got \(state.phase)")
            return
        }
        #expect(after.first?.id == "FR")
    }

    @Test func setCountryWithSameCountryIsNoop() async {
        let stub = MultiProjectStubClient(
            trendingByProject: ["ja.wikipedia.org": []]
        )
        let state = TrendListViewState(
            country: Self.japan,
            client: stub,
            filter: ArticleFilter(blocklist: [:]),
            translator: ArticleTranslatorStub(),
            userLanguage: Locale.Language(identifier: "ja")
        )
        await state.load()
        let countBefore = stub.fetchCount
        await state.setCountry(Self.japan)
        #expect(stub.fetchCount == countBefore)
    }

    @Test func setCountryFailureUpdatesPhaseToFailed() async {
        let stub = MultiProjectStubClient(
            trendingByProject: ["ja.wikipedia.org": []],
            errorByProject: ["fr.wikipedia.org": .httpError(503)]
        )
        let state = TrendListViewState(
            country: Self.japan,
            client: stub,
            filter: ArticleFilter(blocklist: [:]),
            translator: ArticleTranslatorStub(),
            userLanguage: Locale.Language(identifier: "ja")
        )
        await state.setCountry(Self.france)
        if case .failed = state.phase {
            // expected
        } else {
            Issue.record("expected .failed, got \(state.phase)")
        }
    }

    @Test func needsTranslationIsFalseForSameLanguage() {
        let state = TrendListViewState(
            country: Self.japan,
            client: MultiProjectStubClient(),
            filter: ArticleFilter(blocklist: [:]),
            translator: ArticleTranslatorStub(),
            userLanguage: Locale.Language(identifier: "ja")
        )
        #expect(state.needsTranslation == false)
    }

    @Test func needsTranslationIsTrueForDifferentLanguage() {
        let state = TrendListViewState(
            country: Self.japan,
            client: MultiProjectStubClient(),
            filter: ArticleFilter(blocklist: [:]),
            translator: ArticleTranslatorStub(),
            userLanguage: Locale.Language(identifier: "en")
        )
        #expect(state.needsTranslation == true)
    }

    @Test func translationConfigIsNilWhenSameLanguage() async {
        let stub = MultiProjectStubClient(
            trendingByProject: ["ja.wikipedia.org": [TrendArticle(id: "X", rank: 1, title: "X", rawTitle: "X", viewCount: 1)]]
        )
        let state = TrendListViewState(
            country: Self.japan,
            client: stub,
            filter: ArticleFilter(blocklist: [:]),
            translator: ArticleTranslatorStub(),
            userLanguage: Locale.Language(identifier: "ja")
        )
        await state.load()
        #expect(state.translationConfig == nil)
    }

    @Test func translationConfigIsNonNilWhenDifferentLanguage() async {
        let stub = MultiProjectStubClient(
            trendingByProject: ["ja.wikipedia.org": [TrendArticle(id: "X", rank: 1, title: "X", rawTitle: "X", viewCount: 1)]]
        )
        let state = TrendListViewState(
            country: Self.japan,
            client: stub,
            filter: ArticleFilter(blocklist: [:]),
            translator: ArticleTranslatorStub(),
            userLanguage: Locale.Language(identifier: "en")
        )
        await state.load()
        #expect(state.translationConfig != nil)
    }

    @Test func toggleTranslationDisablesAndClears() async {
        let stub = MultiProjectStubClient(
            trendingByProject: ["ja.wikipedia.org": [TrendArticle(id: "X", rank: 1, title: "X", rawTitle: "X", viewCount: 1)]]
        )
        let state = TrendListViewState(
            country: Self.japan,
            client: stub,
            filter: ArticleFilter(blocklist: [:]),
            translator: ArticleTranslatorStub(),
            userLanguage: Locale.Language(identifier: "en")
        )
        await state.load()
        state.translatedTitles = ["X": "T:X"]
        #expect(state.isTranslationEnabled == true)
        #expect(state.translationConfig != nil)

        state.toggleTranslation()

        #expect(state.isTranslationEnabled == false)
        #expect(state.translationConfig == nil)
        #expect(state.translatedTitles.isEmpty)
    }

    @Test func displayTitleReturnsTranslatedWhenEnabled() async {
        let article = TrendArticle(id: "X", rank: 1, title: "X", rawTitle: "X", viewCount: 1)
        let stub = MultiProjectStubClient(
            trendingByProject: ["ja.wikipedia.org": [article]]
        )
        let state = TrendListViewState(
            country: Self.japan,
            client: stub,
            filter: ArticleFilter(blocklist: [:]),
            translator: ArticleTranslatorStub(),
            userLanguage: Locale.Language(identifier: "en")
        )
        await state.load()
        state.translatedTitles = ["X": "translated"]
        #expect(state.displayTitle(for: article) == "translated")

        state.toggleTranslation()
        #expect(state.displayTitle(for: article) == "X")
    }
}

private final class MultiProjectStubClient: WikipediaAPIClient, @unchecked Sendable {
    private let lock = NSLock()
    private var _fetchCount = 0
    let trendingByProject: [String: [TrendArticle]]
    let errorByProject: [String: WikipediaAPIError]

    init(
        trendingByProject: [String: [TrendArticle]] = [:],
        errorByProject: [String: WikipediaAPIError] = [:]
    ) {
        self.trendingByProject = trendingByProject
        self.errorByProject = errorByProject
    }

    var fetchCount: Int {
        lock.lock(); defer { lock.unlock() }
        return _fetchCount
    }

    nonisolated func fetchTrending(project: String, date: Date) async throws -> [TrendArticle] {
        lock.lock()
        _fetchCount += 1
        lock.unlock()
        if let error = errorByProject[project] {
            throw error
        }
        return trendingByProject[project] ?? []
    }

    nonisolated func fetchSummary(languageCode: String, rawTitle: String) async throws -> ArticleSummary {
        throw WikipediaAPIError.invalidResponse
    }
}
