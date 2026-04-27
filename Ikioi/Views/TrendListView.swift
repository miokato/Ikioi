import SwiftUI

struct TrendListView: View {
    @State var state: TrendListViewState

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("\(state.country.flagEmoji) \(state.country.id)")
                .task {
                    if case .idle = state.phase {
                        await state.load()
                    }
                }
                .refreshable {
                    await state.load()
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state.phase {
        case .idle, .loading:
            ProgressView("読み込み中…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let articles) where articles.isEmpty:
            ContentUnavailableView("記事がありません", systemImage: "tray")
        case .loaded(let articles):
            List(articles) { article in
                row(for: article)
            }
            .listStyle(.plain)
        case .failed(let message):
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("読み込みに失敗しました")
                    .font(.headline)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("再試行") {
                    Task { await state.load() }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func row(for article: TrendArticle) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(article.rank)")
                .font(.title2.weight(.bold))
                .frame(width: 36, alignment: .center)
                .foregroundStyle(article.rank <= 3 ? Color.orange : Color.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(article.title)
                    .font(.body.weight(.semibold))
                    .lineLimit(2)
                Text("\(article.viewCount.formatted()) views")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    TrendListView(
        state: TrendListViewState(
            country: .fallbackJapan,
            client: PreviewWikipediaAPIClient(),
            filter: ArticleFilter(blocklist: [:])
        )
    )
}

private struct PreviewWikipediaAPIClient: WikipediaAPIClient {
    nonisolated func fetchTrending(project: String, date: Date) async throws -> [TrendArticle] {
        [
            TrendArticle(id: "大谷翔平", rank: 1, title: "大谷翔平", rawTitle: "大谷翔平", viewCount: 234567),
            TrendArticle(id: "桜", rank: 2, title: "桜", rawTitle: "桜", viewCount: 123456),
            TrendArticle(id: "東京_(架空のドラマ)", rank: 3, title: "東京 (架空のドラマ)", rawTitle: "東京_(架空のドラマ)", viewCount: 98765),
        ]
    }
}
