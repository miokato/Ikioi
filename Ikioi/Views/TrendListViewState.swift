import SwiftUI
import Observation

protocol TrendListViewStateProtocol {
    
}

@MainActor
final class TrendListViewStateMock: TrendListViewStateProtocol {
    
}

@MainActor
struct TrendListViewStateKey: @preconcurrency EnvironmentKey {
    static let defaultValue: TrendListViewStateProtocol = TrendListViewStateMock()
}

extension EnvironmentValues {
    var trendListViewState: TrendListViewStateProtocol {
        get { self[TrendListViewStateKey.self] }
        set { self[TrendListViewStateKey.self] = newValue }
    }
}

@MainActor
@Observable
final class TrendListViewState: TrendListViewStateProtocol {
    enum Phase {
        case idle
        case loading
        case loaded([TrendArticle])
        case failed(String)
    }

    private(set) var phase: Phase = .idle
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

    func makeDetailState(for article: TrendArticle) -> ArticleDetailViewState {
        ArticleDetailViewState(article: article, country: country, client: client)
    }
}
