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
            filter: ArticleFilter(blocklist: [:])
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
            filter: ArticleFilter(blocklist: [:])
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
            filter: ArticleFilter(blocklist: [:])
        )
        await state.setCountry(Self.france)
        if case .failed = state.phase {
            // expected
        } else {
            Issue.record("expected .failed, got \(state.phase)")
        }
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
