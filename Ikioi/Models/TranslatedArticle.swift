import Foundation

struct TranslatedArticle: Sendable, Equatable {
    let title: String
    let extract: String
    let description: String?
}

enum DetailTranslationPhase: Sendable {
    case idle
    case loading
    case translated(TranslatedArticle)
    case unsupported
    case failed(String)
}
