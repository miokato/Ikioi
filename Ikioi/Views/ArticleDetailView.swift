import SwiftUI
import Translation

struct ArticleDetailView: View {
    @Environment(\.articleDetailViewState) private var state
    @State private var safariURL: SafariURL?
    @Environment(\.openURL) private var openURL

    private var displayedTitle: String {
        if state.isTranslationEnabled, case .translated(let t) = state.translation {
            return t.title
        }
        return state.article.title
    }

    private func displayedExtract(_ summary: ArticleSummary) -> String {
        if state.isTranslationEnabled, case .translated(let t) = state.translation {
            return t.extract
        }
        return summary.extract
    }

    private func displayedDescription(_ summary: ArticleSummary) -> String? {
        if state.isTranslationEnabled, case .translated(let t) = state.translation {
            return t.description
        }
        return summary.description
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if case .loaded(let summary) = state.phase, let url = summary.thumbnailURL {
                    thumbnail(url)
                }
                Text(displayedTitle)
                    .font(.largeTitle.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)

                phaseContent

                webSearchButton

                if case .loaded(let summary) = state.phase {
                    wikipediaButton(pageURL: summary.pageURL)
                    ShareLink(item: summary.pageURL) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    credits
                }
            }
            .padding()
        }
        .navigationTitle(displayedTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if state.needsTranslation {
                ToolbarItem(placement: .topBarTrailing) {
                    translationToggle
                }
            }
        }
        .task {
            if case .idle = state.phase {
                await state.load()
            }
        }
        .translationTask(state.translationConfig) { session in
            await state.performTranslation(using: session)
        }
        .sheet(item: $safariURL) { item in
            SafariView(url: item.url)
                .ignoresSafeArea()
        }
    }

    private var translationToggle: some View {
        Button {
            state.toggleTranslation()
        } label: {
            Image(systemName: state.isTranslationEnabled ? "character.bubble.fill" : "character.bubble")
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
                if let description = displayedDescription(summary) {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(displayedExtract(summary))
                    .font(.body)
                translationStatusIndicator
            }
        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                Text("Failed to load summary")
                    .font(.headline)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Retry") {
                    Task { await state.load() }
                }
                .buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder
    private var translationStatusIndicator: some View {
        if state.isTranslationEnabled {
            switch state.translation {
            case .loading:
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.8)
                    Text("Translating…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            case .unsupported:
                Text("This language pair isn't supported")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            case .failed(let message):
                Text("Translation failed: \(message)")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.top, 4)
            case .idle, .translated:
                EmptyView()
            }
        }
    }

    private var webSearchButton: some View {
        Button {
            if let url = state.webSearchURL() {
                openURL(url)
            }
        } label: {
            Label("Search on the web", systemImage: "magnifyingglass")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    private func wikipediaButton(pageURL: URL) -> some View {
        Button {
            safariURL = SafariURL(url: pageURL)
        } label: {
            Label("Read on Wikipedia", systemImage: "book")
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
