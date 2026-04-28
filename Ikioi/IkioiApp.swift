//
//  IkioiApp.swift
//  Ikioi
//
//  Created by Mio Kato on 2026/04/27.
//

import SwiftUI

@main
struct IkioiApp: App {
    @State private var rootState: TrendListViewState
    @State private var detailFactory: ArticleDetailViewStateFactory

    init() {
        let countries = (try? Country.loadFromBundle()) ?? []
        let japan = countries.first { $0.id == "JP" } ?? .fallbackJapan
        let filter = (try? ArticleFilter.loadFromBundle()) ?? ArticleFilter(blocklist: [:])
        let client = LiveWikipediaAPIClient()
        _rootState = State(initialValue: TrendListViewState(
            country: japan,
            client: client,
            filter: filter
        ))
        _detailFactory = State(initialValue: ArticleDetailViewStateFactory(client: client))
    }

    var body: some Scene {
        WindowGroup {
            TrendListView()
                .environment(\.trendListViewState, rootState)
                .environment(\.articleDetailViewStateFactory, detailFactory)
        }
    }
}
