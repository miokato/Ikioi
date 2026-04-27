import Testing
@testable import Ikioi

struct ArticleFilterTests {
    private func make(_ rawTitle: String, rank: Int = 1, views: Int = 100) -> TrendArticle {
        TrendArticle(id: rawTitle, rank: rank, title: rawTitle, rawTitle: rawTitle, viewCount: views)
    }

    @Test func blocklistedTitleIsRemoved() {
        let filter = ArticleFilter(blocklist: ["ja.wikipedia.org": ["メインページ", "特別:検索"]])
        let articles = [
            make("メインページ", rank: 1),
            make("特別:検索", rank: 2),
            make("大谷翔平", rank: 3),
        ]
        let result = filter.filter(articles, project: "ja.wikipedia.org")
        #expect(result.map(\.rawTitle) == ["大谷翔平"])
        #expect(result.map(\.rank) == [1])
    }

    @Test func defaultPrefixesAreFilteredEvenWithoutBlocklist() {
        let filter = ArticleFilter(blocklist: [:])
        let articles = [
            make("Special:Search"),
            make("Wikipedia:About"),
            make("File:Photo.jpg"),
            make("Albert_Einstein"),
        ]
        let result = filter.filter(articles, project: "en.wikipedia.org")
        #expect(result.map(\.rawTitle) == ["Albert_Einstein"])
    }

    @Test func unknownProjectFallsBackToPrefixOnly() {
        let filter = ArticleFilter(blocklist: ["ja.wikipedia.org": ["メインページ"]])
        let articles = [
            make("メインページ"),
            make("Albert_Einstein"),
        ]
        let result = filter.filter(articles, project: "en.wikipedia.org")
        #expect(result.count == 2)
    }

    @Test func ranksAreReassignedAfterFiltering() {
        let filter = ArticleFilter(blocklist: ["ja.wikipedia.org": ["メインページ"]])
        let articles = [
            make("メインページ", rank: 1),
            make("記事A", rank: 2),
            make("Special:Search", rank: 3),
            make("記事B", rank: 4),
        ]
        let result = filter.filter(articles, project: "ja.wikipedia.org")
        #expect(result.map(\.rawTitle) == ["記事A", "記事B"])
        #expect(result.map(\.rank) == [1, 2])
    }
}
