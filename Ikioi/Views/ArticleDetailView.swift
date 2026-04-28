import SwiftUI

struct ArticleDetailView: View {
    @Environment(\.articleDetailViewState) private var state
    @State private var safariURL: SafariURL?
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if case .loaded(let summary) = state.phase, let url = summary.thumbnailURL {
                    thumbnail(url)
                }
                Text(state.article.title)
                    .font(.largeTitle.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)

                phaseContent

                webSearchButton

                if case .loaded(let summary) = state.phase {
                    wikipediaButton(pageURL: summary.pageURL)
                    ShareLink(item: summary.pageURL) {
                        Label("シェア", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    credits
                }
            }
            .padding()
        }
        .navigationTitle(state.article.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if case .idle = state.phase {
                await state.load()
            }
        }
        .sheet(item: $safariURL) { item in
            SafariView(url: item.url)
                .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private func thumbnail(_ url: URL) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: .fit)
            default:
                Color.secondary.opacity(0.1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 200)
        .clipped()
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch state.phase {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
        case .loaded(let summary):
            VStack(alignment: .leading, spacing: 8) {
                if let description = summary.description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(summary.extract)
                    .font(.body)
            }
        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                Text("要約を取得できませんでした")
                    .font(.headline)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("再試行") {
                    Task { await state.load() }
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var webSearchButton: some View {
        Button {
            if let url = state.webSearchURL() {
                openURL(url)
            }
        } label: {
            Label("Webで検索", systemImage: "magnifyingglass")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    private func wikipediaButton(pageURL: URL) -> some View {
        Button {
            safariURL = SafariURL(url: pageURL)
        } label: {
            Label("Wikipediaで読む", systemImage: "book")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    private var credits: some View {
        Text("Source: Wikipedia contributors / CC BY-SA")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.top, 16)
    }
}

private struct SafariURL: Identifiable {
    let url: URL
    var id: URL { url }
}

#Preview {
    NavigationStack {
        ArticleDetailView()
            .environment(\.articleDetailViewState, ArticleDetailViewStateMock())
    }
}
