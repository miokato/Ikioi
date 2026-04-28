import SwiftUI
import Observation

@MainActor
protocol CountryStoreProtocol: AnyObject, Observable {
    var all: [Country] { get }
    var selected: Country { get }
    func select(_ country: Country)
}

@MainActor
@Observable
final class CountryStoreMock: CountryStoreProtocol {
    var all: [Country]
    var selected: Country

    init(
        all: [Country] = [.fallbackJapan],
        selected: Country = .fallbackJapan
    ) {
        self.all = all
        self.selected = selected
    }

    func select(_ country: Country) {
        selected = country
    }
}

@MainActor
struct CountryStoreKey: @preconcurrency EnvironmentKey {
    static let defaultValue: any CountryStoreProtocol = CountryStoreMock()
}

extension EnvironmentValues {
    var countryStore: any CountryStoreProtocol {
        get { self[CountryStoreKey.self] }
        set { self[CountryStoreKey.self] = newValue }
    }
}

@MainActor
@Observable
final class CountryStore: CountryStoreProtocol {
    private(set) var all: [Country]
    private(set) var selected: Country

    private let storage: CountryPreferenceStorageProtocol

    init(
        all: [Country],
        fallback: Country,
        storage: CountryPreferenceStorageProtocol
    ) {
        self.all = all
        self.storage = storage
        if let savedID = storage.loadSelectedCountryID(),
           let saved = all.first(where: { $0.id == savedID }) {
            self.selected = saved
        } else {
            self.selected = fallback
        }
    }

    func select(_ country: Country) {
        guard country.id != selected.id else { return }
        selected = country
        storage.saveSelectedCountryID(country.id)
    }
}
