import Foundation

protocol WikipediaAPIClient: Sendable {
    func fetchTrending(project: String, date: Date) async throws -> [TrendArticle]
}

enum WikipediaAPIError: Error, Equatable {
    case invalidURL
    case invalidResponse
    case httpError(Int)
}

struct LiveWikipediaAPIClient: WikipediaAPIClient {
    private let session: URLSession
    private let userAgent: String

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

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WikipediaAPIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw WikipediaAPIError.httpError(httpResponse.statusCode)
        }

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
