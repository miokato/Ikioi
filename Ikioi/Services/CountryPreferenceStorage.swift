import Foundation

protocol CountryPreferenceStorageProtocol {
    func loadSelectedCountryID() -> String?
    func saveSelectedCountryID(_ id: String)
}

struct UserDefaultsCountryPreferenceStorage: CountryPreferenceStorageProtocol {
    let defaults: UserDefaults

    private let key = "selectedCountryID"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadSelectedCountryID() -> String? {
        defaults.string(forKey: key)
    }

    func saveSelectedCountryID(_ id: String) {
        defaults.set(id, forKey: key)
    }
}
