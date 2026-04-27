import Foundation

protocol WikipediaAPIClient: Sendable {
    func fetchTrending(project: String, date: Date) async throws -> [TrendArticle]
    func fetchSummary(languageCode: String, rawTitle: String) async throws -> ArticleSummary
}

enum WikipediaAPIError: Error, Equatable {
    case invalidURL
    case invalidResponse
    case httpError(Int)
}

struct LiveWikipediaAPIClient: WikipediaAPIClient {
    private let session: URLSession
    private let userAgent: String

    private static let titleAllowedCharacters: CharacterSet = {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/")
        return allowed
    }()

    init(session: URLSession = .shared, userAgent: String = "Ikioi/1.0 (contact@example.com)") {
        self.session = session
        self.userAgent = userAgent
    }

    nonisolated func fetchTrending(project: String, date: Date) async throws -> [TrendArticle] {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy/MM/dd"
        let datePath = formatter.string(from: date)

        let urlString = "https://wikimedia.org/api/rest_v1/metrics/pageviews/top/\(project)/all-access/\(datePath)"
        guard let url = URL(string: urlString) else {
            throw WikipediaAPIError.invalidURL
        }

        let data = try await get(url: url)
        let decoded = try JSONDecoder().decode(TrendingResponse.self, from: data)
        guard let firstItem = decoded.items.first else {
            return []
        }
        return firstItem.articles.map { article in
            TrendArticle(
                id: article.article,
                rank: article.rank,
                title: article.article.replacingOccurrences(of: "_", with: " "),
                rawTitle: article.article,
                viewCount: article.views
            )
        }
    }

    nonisolated func fetchSummary(languageCode: String, rawTitle: String) async throws -> ArticleSummary {
        guard let encodedTitle = rawTitle.addingPercentEncoding(
            withAllowedCharacters: Self.titleAllowedCharacters
        ) else {
            throw WikipediaAPIError.invalidURL
        }
        let urlString = "https://\(languageCode).wikipedia.org/api/rest_v1/page/summary/\(encodedTitle)"
        guard let url = URL(string: urlString) else {
            throw WikipediaAPIError.invalidURL
        }

        let data = try await get(url: url)
        return try JSONDecoder().decode(ArticleSummary.self, from: data)
    }

    private nonisolated func get(url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WikipediaAPIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw WikipediaAPIError.httpError(httpResponse.statusCode)
        }
        return data
    }
}

private struct TrendingResponse: Decodable {
    let items: [Item]

    struct Item: Decodable {
        let articles: [Article]
    }

    struct Article: Decodable {
        let article: String
        let views: Int
        let rank: Int
    }
}
