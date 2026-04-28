import Foundation
import SwiftUI
import Observation

enum TrendListPhase {
    case idle
    case loading
    case loaded([TrendArticle])
    case failed(String)
}

@MainActor
protocol TrendListViewStateProtocol: AnyObject, Observable {
    var phase: TrendListPhase { get }
    var country: Country { get }
    func load() async
}

@MainActor
@Observable
final class TrendListViewStateMock: TrendListViewStateProtocol {
    var phase: TrendListPhase
    let country: Country

    init(
        phase: TrendListPhase = .loaded(PreviewWikipediaAPIClient.defaultTrending),
        country: Country = .fallbackJapan
    ) {
        self.phase = phase
        self.country = country
    }

    func load() async {}
}

@MainActor
struct TrendListViewStateKey: @preconcurrency EnvironmentKey {
    static let defaultValue: any TrendListViewStateProtocol = TrendListViewStateMock()
}

extension EnvironmentValues {
    var trendListViewState: any TrendListViewStateProtocol {
        get { self[TrendListViewStateKey.self] }
        set { self[TrendListViewStateKey.self] = newValue }
    }
}

@MainActor
@Observable
final class TrendListViewState: TrendListViewStateProtocol {
    private(set) var phase: TrendListPhase = .idle
    let country: Country

    private let client: WikipediaAPIClient
    private let filter: ArticleFilter
    private let calendar: Calendar
    private let topN: Int
    private let utcOffsetDays: Int

    init(
        country: Country,
        client: WikipediaAPIClient,
        filter: ArticleFilter,
        calendar: Calendar = Calendar(identifier: .gregorian),
        topN: Int = 25,
        utcOffsetDays: Int = -2
    ) {
        self.country = country
        self.client = client
        self.filter = filter
        self.calendar = calendar
        self.topN = topN
        self.utcOffsetDays = utcOffsetDays
    }

    func load(now: Date = .now) async {
        phase = .loading
        let targetDate = calendar.date(byAdding: .day, value: utcOffsetDays, to: now) ?? now
        do {
            let articles = try await client.fetchTrending(
                project: country.wikipediaProject,
                date: targetDate
            )
            let filtered = filter.filter(articles, project: country.wikipediaProject)
            phase = .loaded(Array(filtered.prefix(topN)))
        } catch {
            phase = .failed(String(describing: error))
        }
    }

    func load() async {
        await load(now: .now)
    }
}
