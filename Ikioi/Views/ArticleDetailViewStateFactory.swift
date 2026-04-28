import Foundation
import SwiftUI

@MainActor
protocol ArticleDetailViewStateFactoryProtocol {
    func make(article: TrendArticle, country: Country) -> any ArticleDetailViewStateProtocol
}

@MainActor
struct ArticleDetailViewStateFactoryMock: ArticleDetailViewStateFactoryProtocol {
    func make(article: TrendArticle, country: Country) -> any ArticleDetailViewStateProtocol {
        ArticleDetailViewStateMock(article: article)
    }
}

@MainActor
struct ArticleDetailViewStateFactoryKey: @preconcurrency EnvironmentKey {
    static let defaultValue: any ArticleDetailViewStateFactoryProtocol = ArticleDetailViewStateFactoryMock()
}

extension EnvironmentValues {
    var articleDetailViewStateFactory: any ArticleDetailViewStateFactoryProtocol {
        get { self[ArticleDetailViewStateFactoryKey.self] }
        set { self[ArticleDetailViewStateFactoryKey.self] = newValue }
    }
}

@MainActor
struct ArticleDetailViewStateFactory: ArticleDetailViewStateFactoryProtocol {
    let client: WikipediaAPIClient

    func make(article: TrendArticle, country: Country) -> any ArticleDetailViewStateProtocol {
        ArticleDetailViewState(article: article, country: country, client: client)
    }
}
