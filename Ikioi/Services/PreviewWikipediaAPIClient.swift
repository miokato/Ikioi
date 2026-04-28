import Foundation

struct PreviewWikipediaAPIClient: WikipediaAPIClient {
    let trending: [TrendArticle]
    let summary: ArticleSummary

    init(
        trending: [TrendArticle] = PreviewWikipediaAPIClient.defaultTrending,
        summary: ArticleSummary = PreviewWikipediaAPIClient.defaultSummary
    ) {
        self.trending = trending
        self.summary = summary
    }

    nonisolated func fetchTrending(project: String, date: Date) async throws -> [TrendArticle] {
        trending
    }

    nonisolated func fetchSummary(languageCode: String, rawTitle: String) async throws -> ArticleSummary {
        summary
    }
}

extension PreviewWikipediaAPIClient {
    static let defaultTrending: [TrendArticle] = [
        TrendArticle(id: "大谷翔平", rank: 1, title: "大谷翔平", rawTitle: "大谷翔平", viewCount: 234567),
        TrendArticle(id: "桜", rank: 2, title: "桜", rawTitle: "桜", viewCount: 123456),
        TrendArticle(id: "東京_(架空のドラマ)", rank: 3, title: "東京 (架空のドラマ)", rawTitle: "東京_(架空のドラマ)", viewCount: 98765),
    ]

    static let defaultSummary = ArticleSummary(
        extract: "プレビュー用の本文。これはWikipedia要約のサンプルテキストです。",
        thumbnailURL: nil,
        pageURL: URL(string: "https://ja.wikipedia.org/wiki/Test")!,
        description: "プレビュー説明"
    )
}
