import Foundation
import SwiftUI
import Observation
import Translation

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
    var translatedTitles: [String: String] { get }
    var isTranslationEnabled: Bool { get }
    var isTranslating: Bool { get }
    var translationConfig: TranslationSession.Configuration? { get }
    var needsTranslation: Bool { get }
    func load() async
    func setCountry(_ country: Country) async
    func toggleTranslation()
    func applyTranslation(using session: TranslationSession) async
    func displayTitle(for article: TrendArticle) -> String
}

@MainActor
@Observable
final class TrendListViewStateMock: TrendListViewStateProtocol {
    var phase: TrendListPhase
    var country: Country
    var translatedTitles: [String: String]
    var isTranslationEnabled: Bool
    var isTranslating: Bool
    var translationConfig: TranslationSession.Configuration?
    var needsTranslation: Bool

    init(
        phase: TrendListPhase = .loaded(PreviewWikipediaAPIClient.defaultTrending),
        country: Country = .fallbackJapan,
        translatedTitles: [String: String] = [:],
        isTranslationEnabled: Bool = false,
        isTranslating: Bool = false,
        needsTranslation: Bool = false
    ) {
        self.phase = phase
        self.country = country
        self.translatedTitles = translatedTitles
        self.isTranslationEnabled = isTranslationEnabled
        self.isTranslating = isTranslating
        self.needsTranslation = needsTranslation
    }

    func load() async {}

    func setCountry(_ country: Country) async {
        guard country.id != self.country.id else { return }
        self.country = country
        await load()
    }

    func toggleTranslation() {
        isTranslationEnabled.toggle()
    }

    func applyTranslation(using session: TranslationSession) async {}

    func displayTitle(for article: TrendArticle) -> String {
        if isTranslationEnabled, let translated = translatedTitles[article.id] {
            return translated
        }
        return article.title
    }
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
    private(set) var country: Country
    var translatedTitles: [String: String] = [:]
    private(set) var isTranslationEnabled: Bool = true
    private(set) var isTranslating: Bool = false
    private(set) var translationConfig: TranslationSession.Configuration?

    private let client: WikipediaAPIClient
    private let filter: ArticleFilter
    private let translator: any ArticleTranslatorProtocol
    private let userLanguage: Locale.Language
    private let calendar: Calendar
    private let topN: Int
    private let utcOffsetDays: Int

    init(
        country: Country,
        client: WikipediaAPIClient,
        filter: ArticleFilter,
        translator: any ArticleTranslatorProtocol,
        userLanguage: Locale.Language = Locale.userPreferredLanguage,
        calendar: Calendar = Calendar(identifier: .gregorian),
        topN: Int = 25,
        utcOffsetDays: Int = -2
    ) {
        self.country = country
        self.client = client
        self.filter = filter
        self.translator = translator
        self.userLanguage = userLanguage
        self.calendar = calendar
        self.topN = topN
        self.utcOffsetDays = utcOffsetDays
    }

    var needsTranslation: Bool {
        let countryLangCode = Locale.Language(identifier: country.languageCode).languageCode
        return countryLangCode != userLanguage.languageCode
    }

    func load(now: Date = .now) async {
        phase = .loading
        translatedTitles = [:]
        translationConfig = nil
        let targetDate = calendar.date(byAdding: .day, value: utcOffsetDays, to: now) ?? now
        do {
            let articles = try await client.fetchTrending(
                project: country.wikipediaProject,
                date: targetDate
            )
            let filtered = filter.filter(articles, project: country.wikipediaProject)
            phase = .loaded(Array(filtered.prefix(topN)))
            updateTranslationConfig()
        } catch {
            phase = .failed(String(describing: error))
        }
    }

    func load() async {
        await load(now: .now)
    }

    func setCountry(_ country: Country) async {
        guard country.id != self.country.id else { return }
        self.country = country
        await load()
    }

    func toggleTranslation() {
        isTranslationEnabled.toggle()
    }

    func applyTranslation(using session: TranslationSession) async {
        guard case .loaded(let articles) = phase else { return }
        let titlesByID = articles.map { (id: $0.id, title: $0.title) }
        isTranslating = true
        defer { isTranslating = false }
        do {
            let result = try await translator.translateTitles(titlesByID, using: session)
            translatedTitles = result
        } catch {
            translatedTitles = [:]
        }
    }

    func displayTitle(for article: TrendArticle) -> String {
        if isTranslationEnabled, let translated = translatedTitles[article.id] {
            return translated
        }
        return article.title
    }

    private func updateTranslationConfig() {
        guard isTranslationEnabled, needsTranslation, case .loaded = phase else {
            translationConfig = nil
            return
        }
        translationConfig = TranslationSession.Configuration(
            source: Locale.Language(identifier: country.languageCode),
            target: userLanguage
        )
    }
}
