## 概要
- ビジネスロジックを実装する場合はテストから書いてください。
- 重くない処理は基本MainActorに実装してください
- SwiftConcurrencyを利用して平行処理を書いてください

## ディレクトリ構成
- Models : 構造体でCodableに準拠したモデルを定義
  - (例) Country.swift
- Services : ビジネスロジック
  - (例) CountryValidation.swift
- Stores : Observationを利用した画面を越えて状態を保持
  - (例) CountryStore.swift
- Views : 画面
  - (例) CountryListView.swift
  - (例) CountryListViewState.swift

## アーキテクチャ
- MVVMで責務を分ける
- プレゼンテーションロジックはxxxViewStateに記述する
- 画面はxxxViewに記述する
- 画面を越えて状態を保持する場合はObservationを利用し、xxxStoreに記述する
- ビジネスロジックはxxxServiceに記述し、状態を持たない
- xxxStateやxxxStoreクラスはObservation,Environment,Protocol,KeyPathを利用してDIで差し込む

## テスト
テストは以下のコマンドで実行する
```
xcodebuild test -scheme "Ikioi" -destination "platform=iOS Simulator,name=iPhone 17 Pro,OS=latest"
```
- Testingフレームワークを利用する
- ビジネスロジックはテストしてから実装する

