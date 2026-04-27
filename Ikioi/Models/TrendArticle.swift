import Foundation

struct TrendArticle: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let rank: Int
    let title: String
    let rawTitle: String
    let viewCount: Int
}
