import Foundation
import Testing
@testable import Ikioi

@Suite(.serialized)
struct WikipediaAPIClientTests {
    private static let sampleJSON = """
    {
      "items": [{
        "project": "ja.wikipedia.org",
        "access": "all-access",
        "year": "2026", "month": "04", "day": "25",
        "articles": [
          {"article": "メインページ", "views": 1234567, "rank": 1},
          {"article": "大谷翔平", "views": 234567, "rank": 2}
        ]
      }]
    }
    """.data(using: .utf8)!

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: components)!
    }

    @Test func fetchTrendingDecodesArticles() async throws {
        let session = MockURLProtocol.makeSession(statusCode: 200, body: Self.sampleJSON)
        let client = LiveWikipediaAPIClient(session: session)
        let articles = try await client.fetchTrending(
            project: "ja.wikipedia.org",
            date: makeDate(year: 2026, month: 4, day: 25)
        )
        #expect(articles.count == 2)
        #expect(articles[0].rank == 1)
        #expect(articles[0].rawTitle == "メインページ")
        #expect(articles[0].title == "メインページ")
        #expect(articles[1].rawTitle == "大谷翔平")
        #expect(articles[1].viewCount == 234567)
    }

    @Test func underscoresInRawTitleBecomeSpacesInDisplayTitle() async throws {
        let json = """
        {"items":[{"project":"en.wikipedia.org","access":"all-access","year":"2026","month":"04","day":"25",
         "articles":[{"article":"Albert_Einstein","views":100,"rank":1}]}]}
        """.data(using: .utf8)!
        let session = MockURLProtocol.makeSession(statusCode: 200, body: json)
        let client = LiveWikipediaAPIClient(session: session)
        let articles = try await client.fetchTrending(
            project: "en.wikipedia.org",
            date: makeDate(year: 2026, month: 4, day: 25)
        )
        #expect(articles.first?.rawTitle == "Albert_Einstein")
        #expect(articles.first?.title == "Albert Einstein")
    }

    @Test func httpErrorIsThrown() async {
        let session = MockURLProtocol.makeSession(statusCode: 503, body: Data())
        let client = LiveWikipediaAPIClient(session: session)
        do {
            _ = try await client.fetchTrending(
                project: "ja.wikipedia.org",
                date: makeDate(year: 2026, month: 4, day: 25)
            )
            Issue.record("expected error")
        } catch let error as WikipediaAPIError {
            #expect(error == .httpError(503))
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test func urlIsConstructedFromProjectAndDate() async throws {
        let session = MockURLProtocol.makeSession(statusCode: 200, body: Self.sampleJSON)
        let client = LiveWikipediaAPIClient(session: session)
        _ = try await client.fetchTrending(
            project: "ja.wikipedia.org",
            date: makeDate(year: 2026, month: 4, day: 25)
        )
        let urlString = MockURLProtocol.lastRequest?.url?.absoluteString ?? ""
        #expect(urlString.contains("ja.wikipedia.org"))
        #expect(urlString.contains("2026/04/25"))
        #expect(urlString.hasPrefix("https://wikimedia.org/api/rest_v1/metrics/pageviews/top/"))
    }

    @Test func userAgentHeaderIsSent() async throws {
        let session = MockURLProtocol.makeSession(statusCode: 200, body: Self.sampleJSON)
        let client = LiveWikipediaAPIClient(session: session, userAgent: "TestAgent/9.9")
        _ = try await client.fetchTrending(
            project: "ja.wikipedia.org",
            date: makeDate(year: 2026, month: 4, day: 25)
        )
        #expect(MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "User-Agent") == "TestAgent/9.9")
    }
}
