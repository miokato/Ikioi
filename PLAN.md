# 国別「いま話題」ブラウザアプリ — 実装計画書

> 実装計画書 / v1 (MVP) 仕様
> 最終更新: 2026-04-27 (記事詳細遷移を NavigationStack 方式に変更)

---

## 0. プロジェクト概要

### コンセプト

各国でいま読まれている話題を一覧表示し、検索ワードを思いつく前のユーザーに「世界の脈拍」を提供するiOSアプリ。1セッション1〜2分の日課利用を想定。

### ユースケース

1. アプリを起動する
2. 国を切り替えて、その国でいま話題のトピックを眺める
3. 気になったトピックをタップして詳細（Wikipedia 要約）を読む
4. 興味があれば「Web検索」ボタンから Safari に飛んで深掘りする

### 非ゴール

- 検索エンジンになること（v1では検索機能を持たない、外部に投げるだけ）
- リアルタイム性（日次更新で十分）
- ソーシャル機能、ユーザーアカウント、コメント

---

## 1. 技術スタック

| 項目 | 採用 |
|---|---|
| 言語 | Swift 5.9+ |
| UI | SwiftUI (iOS 17+) |
| 状態管理 | `@Observable` macro (iOS 17+) |
| HTTP | `URLSession` + async/await |
| 永続化 | `URLCache` (HTTPレベルキャッシュ) + `UserDefaults` (設定値) |
| 広告 | Google Mobile Ads SDK (AdMob) |
| バックエンド | なし（クライアント直接 Wikipedia API を叩く） |
| 最低サポートOS | iOS 17.0 |

### 依存パッケージ (SwiftPM)

- `Google-Mobile-Ads-SDK` (AdMob)
- それ以外は標準ライブラリのみ

---

## 2. プロジェクト構成

```
Ikioi/
├── App/
│   ├── IkioiApp.swift                # @main エントリポイント
│   └── AppConfiguration.swift        # 環境変数・定数
├── Models/
│   ├── Country.swift                 # 国の定義 (ISO + Wikipedia project)
│   ├── TrendArticle.swift            # トレンド記事
│   └── ArticleSummary.swift          # Wikipedia 要約レスポンス
├── Services/
│   ├── WikipediaAPIClient.swift      # API クライアント
│   ├── TrendRepository.swift         # キャッシュ込みデータ取得
│   └── ArticleFilter.swift           # ブラックリスト等のフィルタ
├── Views/
│   ├── MainView.swift                # ルート: 国セレクタ + トレンドリスト
│   ├── CountrySelectorView.swift     # 横スクロール国セレクタ
│   ├── TrendListView.swift           # 記事カードリスト
│   ├── TrendListViewState.swift      # トレンドリストのプレゼンテーション状態
│   ├── TrendCardView.swift           # 個別カード
│   ├── ArticleDetailView.swift       # 詳細画面 (NavigationStack の destination)
│   ├── ArticleDetailViewState.swift  # 詳細画面のプレゼンテーション状態
│   ├── SafariView.swift              # SFSafariViewController ラッパー
│   ├── SettingsView.swift            # 設定画面
│   └── Components/
│       ├── FlagView.swift
│       ├── AsyncImageView.swift
│       └── BannerAdView.swift
├── Resources/
│   ├── Countries.json                # 国マスタデータ
│   ├── Blocklist.json                # フィルタ対象ページ
│   ├── Localizable.strings           # 多言語対応
│   └── Assets.xcassets               # フラグ画像、アプリアイコン
└── Info.plist
```

---

## 3. データモデル

### Country

```swift
struct Country: Identifiable, Codable, Hashable {
    let id: String              // ISO 3166-1 alpha-2 ("JP", "DE" etc.)
    let nameKey: String         // ローカライズキー ("country.JP")
    let wikipediaProject: String // "ja.wikipedia.org", "de.wikipedia.org" etc.
    let languageCode: String    // "ja", "de" — 要約API呼び出しに使う
    let flagEmoji: String       // "🇯🇵" — フォールバック表示用
    let note: String?           // "英語圏全体" のような注釈 (nil可)
}
```

### TrendArticle

```swift
struct TrendArticle: Identifiable, Codable {
    let id: String              // article title (URLエンコード済み)
    let rank: Int               // 1..25
    let title: String           // 表示用タイトル (アンダースコアをスペースに)
    let rawTitle: String        // API呼び出し用 (アンダースコア保持)
    let viewCount: Int          // 閲覧数
    var summary: ArticleSummary? // 要約は遅延ロード
}
```

### ArticleSummary

```swift
struct ArticleSummary: Codable {
    let extract: String         // 平文要約 (1〜3段落)
    let thumbnailURL: URL?      // サムネイル画像 (nilあり)
    let pageURL: URL            // Wikipedia ページへの正規URL
    let description: String?    // 短い説明文
}
```

---

## 4. API 仕様

### 4.1 国別トレンド一覧

**エンドポイント:**
```
GET https://wikimedia.org/api/rest_v1/metrics/pageviews/top/{project}/all-access/{year}/{month}/{day}
```

**例:**
```
https://wikimedia.org/api/rest_v1/metrics/pageviews/top/ja.wikipedia.org/all-access/2026/04/26
```

**重要な注意:**
- UTC基準なので、日本時間で「今日のトレンド」を取るには **2日前** を指定するのが安全
- レスポンスには 1000 件返ってくるので、フィルタ後に上位25件に絞る
- `project` は `ja.wikipedia.org` のような `.org` 付き形式で統一する
- 必ず `User-Agent` ヘッダを付ける（Wikimedia API ポリシー要件）
  - 例: `Ikioi/1.0 (contact@example.com)`

**レスポンス例:**
```json
{
  "items": [{
    "project": "ja.wikipedia.org",
    "access": "all-access",
    "year": "2026", "month": "04", "day": "26",
    "articles": [
      {"article": "メインページ", "views": 1234567, "rank": 1},
      {"article": "記事タイトル", "views": 234567, "rank": 2}
    ]
  }]
}
```

### 4.2 記事要約

**エンドポイント:**
```
GET https://{lang}.wikipedia.org/api/rest_v1/page/summary/{title}
```

**例:**
```
https://ja.wikipedia.org/api/rest_v1/page/summary/%E5%A4%A7%E8%B0%B7%E7%BF%94%E5%B9%B3
```

**重要な注意:**
- `{title}` はURLパス要素として安全にエンコードする。単純な文字列連結やクエリ用エンコードを流用しない
- リダイレクトや曖昧さ回避ページが返る場合があるため、`content_urls.desktop.page` を正規URLとして優先する

**レスポンス抜粋:**
```json
{
  "title": "大谷翔平",
  "extract": "...平文要約...",
  "thumbnail": { "source": "https://upload.wikimedia.org/...", "width": 320, "height": 240 },
  "content_urls": { "desktop": { "page": "https://ja.wikipedia.org/wiki/..." } },
  "description": "日本のプロ野球選手"
}
```

### 4.3 レート制限

Wikimedia Analytics API は固定のリクエスト上限を前提にしない。公式ポリシーに従い、識別可能な `User-Agent` を必ず付け、過剰な並列実行を避ける。

実装方針:
- トレンド一覧取得は国切替ごとに1リクエスト。Pull-to-refresh でも連打を抑制する
- 要約ロードは画面表示時の遅延ロードとし、一度に25件まとめて発行しない
- 要約取得の同時実行数は最大3件程度に制限する
- HTTP 429 / 503 はリトライ可能エラーとして扱い、短い指数バックオフを入れる
- APIレスポンスが返る前に同一URLへ重複リクエストしない

---

## 5. 国マスタ (Countries.json)

v1 サポート対象。`Resources/Countries.json` に静的に持つ。

```json
[
  {"id":"JP","nameKey":"country.JP","wikipediaProject":"ja.wikipedia.org","languageCode":"ja","flagEmoji":"🇯🇵","note":null},
  {"id":"KR","nameKey":"country.KR","wikipediaProject":"ko.wikipedia.org","languageCode":"ko","flagEmoji":"🇰🇷","note":null},
  {"id":"DE","nameKey":"country.DE","wikipediaProject":"de.wikipedia.org","languageCode":"de","flagEmoji":"🇩🇪","note":null},
  {"id":"FR","nameKey":"country.FR","wikipediaProject":"fr.wikipedia.org","languageCode":"fr","flagEmoji":"🇫🇷","note":null},
  {"id":"IT","nameKey":"country.IT","wikipediaProject":"it.wikipedia.org","languageCode":"it","flagEmoji":"🇮🇹","note":null},
  {"id":"RU","nameKey":"country.RU","wikipediaProject":"ru.wikipedia.org","languageCode":"ru","flagEmoji":"🇷🇺","note":null},
  {"id":"TR","nameKey":"country.TR","wikipediaProject":"tr.wikipedia.org","languageCode":"tr","flagEmoji":"🇹🇷","note":null},
  {"id":"PL","nameKey":"country.PL","wikipediaProject":"pl.wikipedia.org","languageCode":"pl","flagEmoji":"🇵🇱","note":null},
  {"id":"NL","nameKey":"country.NL","wikipediaProject":"nl.wikipedia.org","languageCode":"nl","flagEmoji":"🇳🇱","note":null},
  {"id":"SE","nameKey":"country.SE","wikipediaProject":"sv.wikipedia.org","languageCode":"sv","flagEmoji":"🇸🇪","note":null},
  {"id":"FI","nameKey":"country.FI","wikipediaProject":"fi.wikipedia.org","languageCode":"fi","flagEmoji":"🇫🇮","note":null},
  {"id":"TH","nameKey":"country.TH","wikipediaProject":"th.wikipedia.org","languageCode":"th","flagEmoji":"🇹🇭","note":null},
  {"id":"VN","nameKey":"country.VN","wikipediaProject":"vi.wikipedia.org","languageCode":"vi","flagEmoji":"🇻🇳","note":null},
  {"id":"ID","nameKey":"country.ID","wikipediaProject":"id.wikipedia.org","languageCode":"id","flagEmoji":"🇮🇩","note":null},
  {"id":"EN","nameKey":"country.EN","wikipediaProject":"en.wikipedia.org","languageCode":"en","flagEmoji":"🌐","note":"country.EN.note"},
  {"id":"ES","nameKey":"country.ES","wikipediaProject":"es.wikipedia.org","languageCode":"es","flagEmoji":"🌐","note":"country.ES.note"},
  {"id":"BR","nameKey":"country.BR","wikipediaProject":"pt.wikipedia.org","languageCode":"pt","flagEmoji":"🇧🇷","note":"country.BR.note"},
  {"id":"SA","nameKey":"country.SA","wikipediaProject":"ar.wikipedia.org","languageCode":"ar","flagEmoji":"🌐","note":"country.SA.note"}
]
```

注: EN/ES/SA は実態が「言語圏」なので国旗は地球マーク。`note` のローカライズキーで「英語圏全体」「スペイン語圏」「アラビア語圏」を表示。

---

## 6. ブラックリスト (Blocklist.json)

各言語版の Wikipedia には、メインページや特殊ページが常にトップに来る。これらをハードコードでフィルタ。

```json
{
  "ja.wikipedia.org": ["メインページ", "特別:検索", "Wikipedia:メインページ"],
  "en.wikipedia.org": ["Main_Page", "Special:Search", "Wikipedia:Main_Page"],
  "de.wikipedia.org": ["Wikipedia:Hauptseite", "Spezial:Suche"],
  "fr.wikipedia.org": ["Wikipédia:Accueil_principal", "Spécial:Recherche"],
  "ko.wikipedia.org": ["위키백과:대문", "특수:검색"],
  "ru.wikipedia.org": ["Заглавная_страница", "Служебная:Поиск"],
  "es.wikipedia.org": ["Wikipedia:Portada", "Especial:Buscar"]
}
```

**プレフィックスベースのフィルタも併用:**
- `Special:`, `特別:`, `Spécial:`, `Spezial:`, `Especial:`, `Служебная:` などで始まるタイトル
- `Wikipedia:`, `Wikipédia:`, `Википедия:` などの名前空間
- ファイルページ (`File:`, `ファイル:`)

`ArticleFilter.swift` でこのフィルタリングを実装する。

---

## 7. 画面仕様

### 7.1 MainView (ルート画面)

**レイアウト:**
- 上部: ナビゲーションバー（左に設定アイコン、中央にアプリ名、右に日付表示）
- 上部固定: `CountrySelectorView`（高さ約60pt、横スクロール）
- 中央: `TrendListView`（縦スクロール、横スワイプで国切替）
- 下部: `BannerAdView`（AdMob標準サイズ 320x50）

**主要インタラクション:**
- 国セレクタ: タップで切替 + 選択中の国を中央にスナップアニメーション
- 記事カードタップ → `ArticleDetailView` を `NavigationStack` で push 遷移
- 記事リストを **左右スワイプ** すると隣接する国へ遷移（重要）
- Pull-to-refresh で再取得（同日でも再取得を許可）

### 7.2 CountrySelectorView

横スクロールするピル（フラグ＋国名）の列。選択中の国は色とサイズで強調。`ScrollViewReader` で選択時に中央にスナップ。

### 7.3 TrendCardView

各カードの構成:
- 左: ランキング数字（大きめ、1-3位は色を変える）
- 中央: タイトル（太字）+ 説明文（1行で省略）+ 閲覧数
- 右: サムネイル画像（80x80、なければプレースホルダ）

タイトルと説明文は記事要約APIの遅延ロード結果を反映。要約取得前は `redacted(reason: .placeholder)` でスケルトン表示。

### 7.4 ArticleDetailView

`NavigationStack` の `navigationDestination(for: TrendArticle.self)` から push 遷移で表示する。
`ScrollView` ベースの単一画面で、戻る操作は標準のナビゲーションバー（バックスワイプ含む）に任せる。

レイアウト（上から）:
1. サムネイル（フル幅、aspect-fit、最大高さ200pt）
2. タイトル（large title）
3. 説明文（caption）
4. 要約 extract（本文）
5. **「Webで検索する」ボタン（プライマリ、最大幅、目立つ色）** ← 主要CTA
6. 「Wikipedia で読む」ボタン（セカンダリ）
7. 「シェア」ボタン（テキスト + iOS シェアシート）
8. 下部に「Source: Wikipedia contributors / CC BY-SA」のクレジットと記事URL

「Webで検索する」アクション: 外部 Safari を開く（`UIApplication.shared.open` 経由、SwiftUI では `openURL` 環境値を使う）。
ユーザーがブラウザ上で次の検索や共有に進む可能性が高いため、敢えてアプリ内には閉じ込めない。

```swift
var components = URLComponents(string: "https://www.google.com/search")!
components.queryItems = [URLQueryItem(name: "q", value: article.title)]
// openURL(components.url!)  ← @Environment(\.openURL) を使用
```

「Wikipedia で読む」アクション: アプリ内 `SFSafariViewController` で表示する。
画面内の単一記事を読む用途であり、アプリ内ブラウザの方が UX が良いため。実装は `Views/SafariView.swift` の
`UIViewControllerRepresentable` ラッパーを `.sheet(item:)` で提示する（NavigationStack の同一スタック内で
さらに push しないことで、ユーザーが Safari を閉じればすぐ詳細画面に戻れる）。

```swift
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
```

### 7.5 SettingsView

セクション構成:
- **表示する国** — 国の有効/無効トグルとドラッグ並び替え（`onMove`）
- **データソース** — クレジット表示（リードオンリー）
- **このアプリについて** — バージョン、開発者、プライバシーポリシーURL
- **広告非表示** — v2で実装するためグレーアウト or 非表示

設定の永続化は `UserDefaults` で `[String]`（有効国IDの順序付き配列）として保存。

---

## 8. キャッシュ戦略

### HTTP レベル

`URLCache.shared` のサイズを 50MB に拡張。通常時は `URLSession` の `useProtocolCachePolicy` を基本とし、HTTPヘッダに従ってキャッシュする。

`returnCacheDataElseLoad` は常用しない。古いランキングを気づかず表示し続けるリスクがあるため、オフライン復旧用の永続キャッシュはアプリレベルで明示的に扱う。

### アプリレベル

`TrendRepository` 内に `[Country.id: (date: Date, articles: [TrendArticle])]` の辞書を持つ。同日の同国リクエストはメモリキャッシュから返す。日付が変わったら無効化。

加えて、オフライン時とアプリ再起動後の表示に備え、取得済みランキングを国・対象日ごとのJSONとして `Application Support/TrendCache/` に保存する。保存対象は `TrendArticle` の一覧、取得対象日、取得時刻。要約本文は肥大化しやすいため、v1ではランキングキャッシュとは分離し、必要に応じて `URLCache` に任せる。

Pull-to-refresh はメモリキャッシュをバイパスして再取得するが、成功後はメモリキャッシュとディスクキャッシュの両方を更新する。

---

## 9. エラーハンドリング

| ケース | 動作 |
|---|---|
| ネットワークオフライン | キャッシュがあれば表示 + 「オフライン」バナー / なければエラー画面 + 再試行ボタン |
| API 5xx | エラー画面 + 再試行ボタン |
| API 429 / 503 | 短い指数バックオフ後に再試行。失敗が続く場合はキャッシュ表示 or エラー画面 |
| 国別データが空 | 「データ取得中、少し前の日付で再試行します」と1日前にフォールバック（最大3日まで遡る） |
| 個別記事の要約失敗 | カードはタイトルと閲覧数のみ表示、詳細シートはタイトルと「Wikipediaで読む」のみ |
| サムネイル取得失敗 | プレースホルダー画像 |

すべてのエラー時に `Logger` でログ出力（OSLog）、ただしユーザーに詳細スタックトレースは出さない。

---

## 10. ローカライズ

`Localizable.strings` を以下の言語で用意:
- 英語 (Base)
- 日本語

国名キーは `country.JP` 形式で、両言語版に全国分を定義。注釈キー `country.EN.note` には「English-speaking regions」「英語圏全体」など。

UI文言の例:
```
"app.title" = "Trend Browser";
"main.refreshing" = "Refreshing...";
"main.lastUpdated" = "Last updated: %@";
"detail.searchOnWeb" = "Web で検索";
"detail.readOnWikipedia" = "Wikipedia で読む";
"settings.dataSource" = "Data: Wikimedia Analytics API (CC0), Wikipedia contributors (CC BY-SA)";
"error.offline.title" = "オフライン";
"error.retry" = "再試行";
```

---

## 11. AdMob 統合

- `Info.plist` に `GADApplicationIdentifier` を設定
- `App Tracking Transparency` プロンプトの実装（`ATTrackingManager.requestTrackingAuthorization`）
- アプリ起動時に SDK 初期化
- `BannerAdView` を `MainView` 下部に固定配置
- v1 はバナーのみ。インタースティシャルやリワード広告は実装しない（UX阻害のため）

開発中はテスト広告ユニットID (`ca-app-pub-3940256099942544/2934735716`) を使う。本番IDは環境変数 or `AppConfiguration.swift` で切替。

---

## 12. Info.plist 必須項目

- `GADApplicationIdentifier` (AdMob)
- `NSUserTrackingUsageDescription` (ATT用文言)
- `NSAppTransportSecurity` は不要（Wikipedia はすべて HTTPS）
- 通常の `UIApplication.shared.open(_:)` で `https` URL を開く用途では `LSApplicationQueriesSchemes` は不要

---

## 13. 開発フェーズ

### Phase 1: コア機能（Week 1-2）

- [ ] 既存の `Ikioi` プロジェクト構成を整理（SwiftUI、iOS 17+）
- [ ] 初期テンプレートのビルドエラーを解消（例: `ContentView.swift` 先頭の不要文字）
- [ ] `Countries.json` 読み込み、モデル定義
- [ ] `WikipediaAPIClient` でトレンド取得 + 要約取得
- [ ] `ArticleFilter` でブロックリスト適用
- [ ] 単一国（日本）でのリスト表示が動く

### Phase 2: 国切替UI（Week 2-3）

- [ ] `CountrySelectorView` 実装、横スクロール + スナップ
- [ ] 全15-19カ国の切替が動く
- [ ] リスト全体を横スワイプで隣接国遷移（`TabView(selection:)` + `.tabViewStyle(.page)` で実装）
- [ ] フラグ画像表示

### Phase 3: 詳細とアクション（Week 3-4）

- [ ] `ArticleDetailView` 実装（NavigationStack push 遷移）
- [ ] サムネイル非同期表示（`AsyncImage`）
- [ ] Web検索ボタン（外部 Safari 起動）
- [ ] Wikipedia ボタン（`SFSafariViewController` でアプリ内表示）
- [ ] シェア機能
- [ ] Wikipedia contributors / CC BY-SA クレジット表示

### Phase 4: 仕上げ（Week 4-5）

- [ ] キャッシュ実装
- [ ] ランキングのディスクキャッシュ実装（オフライン/再起動後対応）
- [ ] エラーハンドリングと再試行UI
- [ ] `SettingsView` で国の有効/無効
- [ ] ローカライズ（英語・日本語）
- [ ] AdMob統合
- [ ] App Storeアセット（アイコン、スクリーンショット、説明文）
- [ ] TestFlight提出

---

## 14. 受け入れ基準（v1リリース条件）

- [ ] アプリ起動からトレンド一覧表示まで2秒以内（キャッシュあり）
- [ ] 全サポート国でトレンド一覧が正常に取得できる
- [ ] 国切替アニメーションが60fpsを維持
- [ ] オフライン時もキャッシュデータが見える
- [ ] 記事タップから Web 検索遷移までクラッシュなし
- [ ] Wikimedia Analytics API と Wikipedia contributors のクレジットが規定通り表示される
- [ ] AdMob のバナーが表示される
- [ ] App Store 審査ガイドライン違反なし（特に4.2のミニマム機能性とプライバシー）

---

## 15. 既知の制約とv2以降の課題

| 項目 | v1の対応 | v2以降 |
|---|---|---|
| データ更新頻度 | UTC日次（実質1.5日遅れ） | Google Trends追加でリアルタイム化 |
| 国の代表性 | 言語版で代用 | GDELT等で国別正規化 |
| ボット流入による異常値 | 簡易フィルタなし | Z-scoreでの異常検知 |
| 中国本土 | 非対応 | 別データソース検討 |
| 画像著作権 | Wikipedia提供サムネのみ | 変更なし（安全） |
| ランキング変動 | 非表示 | 「前日比」「急上昇」表示 |
| 通知 | なし | 朝7時に「今日の○○国トップ5」プッシュ |

---

## 16. ライセンスとクレジット

- ランキングデータ: Wikimedia Analytics API / CC0 1.0
- 記事要約・記事本文由来コンテンツ: Wikipedia contributors / CC BY-SA
- アプリ自体のライセンス: 未定（クローズドソース予定）
- サードパーティ:
  - Google Mobile Ads SDK (Apache 2.0)

クレジット表示の要件:
- 設定画面に明示
- 各記事詳細シートに「Source: Wikipedia contributors」を表示し、Wikipediaページへのリンクを併記
- ランキングデータについては設定画面またはアプリ情報に「Powered by Wikimedia Analytics API」を表示
- App Store 説明文にデータソースを記載

---

## 17. Claude Code への引き継ぎメモ

このドキュメントを基に実装を進める際、以下を優先順位として参考にしてください:

1. **まず Phase 1 の `WikipediaAPIClient` から手を付ける**。これが動けば全体の見通しが立つ。
2. UI 実装は最小限のSwiftUIから入り、デザインの作り込みは後回し。
3. `URLSession` 設定は最初から `URLCache` を組み込む。ただしオフライン表示はディスクJSONキャッシュを主経路にする。
4. AdMob はビルドが通る最小構成で入れて、デザインが固まってから配置調整。
5. テストコードは API クライアント層に絞って書く（UI テストは v1 では不要）。

不明点があれば、このドキュメントに追記しながら進めてください。
