//
//  IkioiApp.swift
//  Ikioi
//
//  Created by Mio Kato on 2026/04/27.
//

import SwiftUI

@main
struct IkioiApp: App {
    @State private var rootState: TrendListViewState = IkioiApp.makeRootState()

    var body: some Scene {
        WindowGroup {
            TrendListView(state: rootState)
        }
    }

    private static func makeRootState() -> TrendListViewState {
        let countries = (try? Country.loadFromBundle()) ?? []
        let japan = countries.first { $0.id == "JP" } ?? .fallbackJapan
        let filter = (try? ArticleFilter.loadFromBundle()) ?? ArticleFilter(blocklist: [:])
        return TrendListViewState(
            country: japan,
            client: LiveWikipediaAPIClient(),
            filter: filter
        )
    }
}
