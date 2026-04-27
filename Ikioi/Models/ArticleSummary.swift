import Foundation

struct ArticleSummary: Decodable, Hashable, Sendable {
    let extract: String
    let thumbnailURL: URL?
    let pageURL: URL
    let description: String?

    init(extract: String, thumbnailURL: URL?, pageURL: URL, description: String?) {
        self.extract = extract
        self.thumbnailURL = thumbnailURL
        self.pageURL = pageURL
        self.description = description
    }

    private enum CodingKeys: String, CodingKey {
        case extract
        case thumbnail
        case contentUrls = "content_urls"
        case description
    }

    private struct Thumbnail: Decodable {
        let source: URL
    }

    private struct ContentUrls: Decodable {
        let desktop: Desktop

        struct Desktop: Decodable {
            let page: URL
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.extract = try container.decode(String.self, forKey: .extract)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.thumbnailURL = try container.decodeIfPresent(Thumbnail.self, forKey: .thumbnail)?.source
        self.pageURL = try container.decode(ContentUrls.self, forKey: .contentUrls).desktop.page
    }
}
