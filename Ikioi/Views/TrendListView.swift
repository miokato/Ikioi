import SwiftUI

struct TrendListView: View {
    @Environment(\.trendListViewState) private var state
    @Environment(\.articleDetailViewStateFactory) private var detailFactory
    @Environment(\.countryStore) private var countryStore

    @State private var switchErrorMessage: String?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("\(state.country.flagEmoji) \(state.country.id)")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        countryMenu
                    }
                }
                .task {
                    if case .idle = state.phase {
                        await state.load()
                    }
                }
                .refreshable {
                    await state.load()
                }
                .onChange(of: countryStore.selected) { _, newCountry in
                    Task {
                        await state.setCountry(newCountry)
                        if case .failed(let message) = state.phase {
                            switchErrorMessage = message
                        }
                    }
                }
                .alert(
                    "読み込みに失敗しました",
                    isPresented: Binding(
                        get: { switchErrorMessage != nil },
                        set: { if !$0 { switchErrorMessage = nil } }
                    ),
                    presenting: switchErrorMessage
                ) { _ in
                    Button("OK", role: .cancel) {}
                } message: { message in
                    Text(message)
                }
                .navigationDestination(for: TrendArticle.self) { article in
                    ArticleDetailViewContainer(
                        factory: detailFactory,
                        article: article,
                        country: state.country
                    )
                }
        }
    }

    private var countryMenu: some View {
        Menu {
            Picker(
                "国を選択",
                selection: Binding(
                    get: { countryStore.selected },
                    set: { countryStore.select($0) }
                )
            ) {
                ForEach(countryStore.all) { country in
                    Text("\(country.flagEmoji) \(country.id)")
                        .tag(country)
                }
            }
        } label: {
            Text(countryStore.selected.flagEmoji)
                .font(.title2)
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
                NavigationLink(value: article) {
                    row(for: article)
                }
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

private struct ArticleDetailViewContainer: View {
    @State private var detailState: any ArticleDetailViewStateProtocol

    init(
        factory: any ArticleDetailViewStateFactoryProtocol,
        article: TrendArticle,
        country: Country
    ) {
        _detailState = State(initialValue: factory.make(article: article, country: country))
    }

    var body: some View {
        ArticleDetailView()
            .environment(\.articleDetailViewState, detailState)
    }
}

#Preview {
    TrendListView()
        .environment(\.trendListViewState, TrendListViewStateMock())
        .environment(\.articleDetailViewStateFactory, ArticleDetailViewStateFactoryMock())
        .environment(\.countryStore, CountryStoreMock(
            all: [.fallbackJapan],
            selected: .fallbackJapan
        ))
}
