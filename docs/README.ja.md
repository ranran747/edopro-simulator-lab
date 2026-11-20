# Windows カードゲームシミュレーター 日本語ガイド

[配布一覧・FAQ](DOWNLOADS.md) · [English](../README.md) · [noteチップ](https://note.com/muutan_ai_lab/n/n615b21d388af) · [GitHub Sponsors](https://github.com/sponsors/ranran747)

各ゲーム向けの非公式Windowsシミュレーターです。**まず[ゲーム別の配布一覧](DOWNLOADS.md)で、使いたい作品のWindows本体と導入ガイドを選んでください。** 対戦/デッキ編集/観戦の対応範囲は各版の説明に記載しています。

## 導入手順

1. 配布一覧から対象ゲームの本体Releaseを開きます。
2. `*-Windows-*.zip`を新しいフォルダーへ展開します。
3. `Start.cmd`を実行し、`Play`／「対戦する」から当該版の説明に沿って対戦します。

本体Releaseは専用exe・コア・カードDB・Luaを収録します。「セットアップキット」は、専用クライアントとデータを持っている人向けの起動/画像追加用ツールです。必要ファイルが不足したまま遊べるとは案内しません。

## 対応範囲と不具合

収録カード、カード画像、デッキ、対戦方法と検証した組合せは版ごとに異なります。公開スモークテストは、その範囲で起動・対戦が完走したという結果です。各カード効果の完全性を一括で保証するものではありません。

問題が出たときは[Issues](https://github.com/ranran747/edopro-simulator-lab/issues)へ、作品名、ダウンロードしたファイル名、Windows版、カード番号、再現手順を記載してください。

## 開発を支援する

公開版は無料です。[note記事末尾のチップ](https://note.com/muutan_ai_lab/n/n615b21d388af)と[GitHub Sponsors](https://github.com/sponsors/ranran747)で開発・検証・保守を任意に支援できます。

## 開発者向け

[パックの構成](PACKS.md)と[ソース/ライセンス](SOURCE.md)を参照してください。各本体Releaseには対応ソースZIPとビルド手順を用意します。自作カードの20戦を実行する[別のコマンドライン検証版](https://github.com/ranran747/edopro-simulator-lab/releases/tag/v0.1.1)もあります。
