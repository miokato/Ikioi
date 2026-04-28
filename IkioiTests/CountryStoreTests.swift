import Foundation
import Testing
@testable import Ikioi

@MainActor
struct CountryStoreTests {
    private static let countries: [Country] = [
        Country(id: "JP", nameKey: "country.JP", wikipediaProject: "ja.wikipedia.org", languageCode: "ja", flagEmoji: "🇯🇵", note: nil),
        Country(id: "EN", nameKey: "country.EN", wikipediaProject: "en.wikipedia.org", languageCode: "en", flagEmoji: "🌐", note: nil),
        Country(id: "FR", nameKey: "country.FR", wikipediaProject: "fr.wikipedia.org", languageCode: "fr", flagEmoji: "🇫🇷", note: nil),
    ]

    @Test func initialSelectionUsesSavedIDWhenInList() {
        let storage = InMemoryCountryPreferenceStorage(savedID: "FR")
        let store = CountryStore(all: Self.countries, fallback: Self.countries[0], storage: storage)
        #expect(store.selected.id == "FR")
    }

    @Test func initialSelectionFallsBackWhenNoSavedID() {
        let storage = InMemoryCountryPreferenceStorage()
        let store = CountryStore(all: Self.countries, fallback: Self.countries[0], storage: storage)
        #expect(store.selected.id == "JP")
    }

    @Test func initialSelectionFallsBackWhenSavedIDNotInList() {
        let storage = InMemoryCountryPreferenceStorage(savedID: "XX")
        let store = CountryStore(all: Self.countries, fallback: Self.countries[0], storage: storage)
        #expect(store.selected.id == "JP")
    }

    @Test func selectUpdatesSelectedAndPersists() {
        let storage = InMemoryCountryPreferenceStorage()
        let store = CountryStore(all: Self.countries, fallback: Self.countries[0], storage: storage)
        store.select(Self.countries[1])
        #expect(store.selected.id == "EN")
        #expect(storage.savedID == "EN")
        #expect(storage.saveCount == 1)
    }

    @Test func selectingSameCountryDoesNotPersistAgain() {
        let storage = InMemoryCountryPreferenceStorage(savedID: "JP")
        let store = CountryStore(all: Self.countries, fallback: Self.countries[0], storage: storage)
        storage.saveCount = 0
        store.select(Self.countries[0])
        #expect(storage.saveCount == 0)
    }
}

@MainActor
final class InMemoryCountryPreferenceStorage: CountryPreferenceStorageProtocol {
    var savedID: String?
    var saveCount: Int = 0

    init(savedID: String? = nil) {
        self.savedID = savedID
    }

    func loadSelectedCountryID() -> String? { savedID }

    func saveSelectedCountryID(_ id: String) {
        savedID = id
        saveCount += 1
    }
}
