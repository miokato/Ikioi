import Foundation

struct ArticleFilter: Sendable {
    private let blocklist: [String: Set<String>]
    private let blockedPrefixes: [String]

    static let defaultPrefixes: [String] = [
        "Special:", "特別:", "Spécial:", "Spezial:", "Especial:", "Служебная:",
        "Wikipedia:", "Wikipédia:", "Википедия:",
        "File:", "ファイル:",
    ]

    init(blocklist: [String: [String]], blockedPrefixes: [String] = ArticleFilter.defaultPrefixes) {
        self.blocklist = blocklist.mapValues(Set.init)
        self.blockedPrefixes = blockedPrefixes
    }

    func filter(_ articles: [TrendArticle], project: String) -> [TrendArticle] {
        let blockedTitles = blocklist[project] ?? []
        let kept = articles.filter { article in
            if blockedTitles.contains(article.rawTitle) { return false }
            for prefix in blockedPrefixes where article.rawTitle.hasPrefix(prefix) {
                return false
            }
            return true
        }
        return kept.enumerated().map { index, article in
            TrendArticle(
                id: article.id,
                rank: index + 1,
                title: article.title,
                rawTitle: article.rawTitle,
                viewCount: article.viewCount
            )
        }
    }
}

extension ArticleFilter {
    static func loadFromBundle(name: String = "Blocklist", bundle: Bundle = .main) throws -> ArticleFilter {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw ArticleFilterError.resourceNotFound(name: name)
        }
        let data = try Data(contentsOf: url)
        let blocklist = try JSONDecoder().decode([String: [String]].self, from: data)
        return ArticleFilter(blocklist: blocklist)
    }
}

enum ArticleFilterError: Error, Equatable {
    case resourceNotFound(name: String)
}
