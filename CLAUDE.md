# CLAUDE.md

## プロジェクト概要
Flutterファイル管理アプリケーションです。現在はデフォルトのカウンターアプリが入っているので、ファイル管理機能に置き換える必要があります。
このプロジェクトはandroidのファイルマネージャーアプリになります。
機能は以下の通り
ファイルエクスプローラー機能
画像ビューワー
音楽ビューワー
お気に入りフォルダ機能

## 開発コマンド

### 基本実行
- `flutter run` - アプリを実行
- `flutter run -d windows` - Windows版で実行
- `flutter hot reload` - ホットリロード（ターミナルで'r'を押す）

### テスト・品質管理
- `flutter test` - テスト実行
- `flutter analyze` - 静的解析
- `dart format .` - コード整形

## 現在の状況
デフォルトテンプレートからファイル管理アプリへの変更が必要です。main.dartのカウンターアプリを置き換えてください。
This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

コードはfreezedとriverPodを使用してほかにもビューワー機能などで必要なライブラリがあれば適宜追加してください。
