import Foundation
import Testing
@testable import Ikioi

struct ArticleSummaryTests {
    @Test func decodesFullSummaryResponse() throws {
        let json = """
        {
          "title": "大谷翔平",
          "extract": "日本のプロ野球選手。",
          "thumbnail": { "source": "https://upload.wikimedia.org/photo.jpg", "width": 320, "height": 240 },
          "content_urls": { "desktop": { "page": "https://ja.wikipedia.org/wiki/%E5%A4%A7%E8%B0%B7%E7%BF%94%E5%B9%B3" } },
          "description": "プロ野球選手"
        }
        """.data(using: .utf8)!
        let summary = try JSONDecoder().decode(ArticleSummary.self, from: json)
        #expect(summary.extract == "日本のプロ野球選手。")
        #expect(summary.thumbnailURL?.absoluteString == "https://upload.wikimedia.org/photo.jpg")
        #expect(summary.pageURL.absoluteString == "https://ja.wikipedia.org/wiki/%E5%A4%A7%E8%B0%B7%E7%BF%94%E5%B9%B3")
        #expect(summary.description == "プロ野球選手")
    }

    @Test func decodesSummaryWithoutThumbnailOrDescription() throws {
        let json = """
        {
          "title": "サンプル",
          "extract": "本文",
          "content_urls": { "desktop": { "page": "https://ja.wikipedia.org/wiki/%E3%82%B5%E3%83%B3%E3%83%97%E3%83%AB" } }
        }
        """.data(using: .utf8)!
        let summary = try JSONDecoder().decode(ArticleSummary.self, from: json)
        #expect(summary.thumbnailURL == nil)
        #expect(summary.description == nil)
        #expect(summary.extract == "本文")
    }

    @Test func missingPageURLThrows() {
        let json = """
        { "title": "x", "extract": "y" }
        """.data(using: .utf8)!
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(ArticleSummary.self, from: json)
        }
    }
}
