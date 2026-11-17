# EDOPro Simulator Lab 日本語ガイド

[English](../README.md) · [開発を支援する](https://github.com/sponsors/ranran747)

EDOPro を使ったカードシミュレーターの開発・検証用リポジトリです。最初の公開版にはエンジンのソース、AI 自動対戦の検証ツール、自作の見本デッキ2組、カードパック分離と画像追加のツールがあります。

## 自作カードの対戦を実行する

[Windows コマンドライン版](https://github.com/ranran747/edopro-simulator-lab/releases/latest)を展開し、PowerShell で `Run-demo.cmd` を実行します。ソースからビルドする場合は Visual Studio 2022 C++ Build Tools、Windows SDK、CMake を用意します。

```powershell
.\tools\run-demo.ps1 -Seeds 20
```

改造済みの32ビット `ocgcore.dll` がある場合は `-CoreDirectory` で DLL のあるフォルダを渡せます。決着と両席それぞれのカード53枚（デッキ50枚＋AP3枚）を検査します。ログは `artifacts/` に出ます。

## カードパックと画像

[タイトル別の GitHub Releases](PROFILE_RELEASES.md) から、Windows の起動ファイルと画像セットアップキットを取得できます。

[各ゲームのパック手順](PACKS.md) に従い、カード名・効果文の入ったDBと Lua・対戦シナリオ・デッキを別々に用意します。ゲームに合う専用クライアントへ両方を展開して使います。

画像は提供者の利用条件を確認したものを、数値IDの JPG・PNG として追加できます。 [Codex に渡すプロンプト](IMPORT_IMAGES_WITH_CODEX.md)

```powershell
python tools/import_images.py --runtime runtime/ProjectIgnis --local C:\path\to\your\art
```

この案内は英語が標準で日本語も用意しています。各ゲームの対戦画面やカード文の言語は、専用クライアントとカードパックの対応状況によります。
