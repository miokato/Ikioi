import Foundation

struct Country: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let nameKey: String
    let wikipediaProject: String
    let languageCode: String
    let flagEmoji: String
    let note: String?
}

extension Country {
    static let fallbackJapan = Country(
        id: "JP",
        nameKey: "country.JP",
        wikipediaProject: "ja.wikipedia.org",
        languageCode: "ja",
        flagEmoji: "🇯🇵",
        note: nil
    )

    static func loadFromBundle(name: String = "Countries", bundle: Bundle = .main) throws -> [Country] {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw CountryLoadError.resourceNotFound(name: name)
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([Country].self, from: data)
    }
}

enum CountryLoadError: Error, Equatable {
    case resourceNotFound(name: String)
}
