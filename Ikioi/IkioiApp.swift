//
//  IkioiApp.swift
//  Ikioi
//
//  Created by Mio Kato on 2026/04/27.
//

import SwiftUI

@main
struct IkioiApp: App {
    @State private var countryStore: CountryStore
    @State private var rootState: TrendListViewState
    @State private var detailFactory: ArticleDetailViewStateFactory

    init() {
        let countries = (try? Country.loadFromBundle()) ?? []
        let filter = (try? ArticleFilter.loadFromBundle()) ?? ArticleFilter(blocklist: [:])
        let client = LiveWikipediaAPIClient()
        let translator = LiveArticleTranslator()
        let userLanguage = Locale.userPreferredLanguage
        let storage = UserDefaultsCountryPreferenceStorage()
        let store = CountryStore(
            all: countries,
            fallback: .fallbackJapan,
            storage: storage
        )

        _countryStore = State(initialValue: store)
        _rootState = State(initialValue: TrendListViewState(
            country: store.selected,
            client: client,
            filter: filter,
            translator: translator,
            userLanguage: userLanguage
        ))
        _detailFactory = State(initialValue: ArticleDetailViewStateFactory(
            client: client,
            translator: translator,
            userLanguage: userLanguage
        ))
    }

    var body: some Scene {
        WindowGroup {
            TrendListView()
                .environment(\.countryStore, countryStore)
                .environment(\.trendListViewState, rootState)
                .environment(\.articleDetailViewStateFactory, detailFactory)
        }
    }
}
