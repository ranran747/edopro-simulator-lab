# Windows 配布と画像の扱い

現在のWindows本体は[ゲーム別配布一覧](DOWNLOADS.md)から取得してください。旧セットアップキット v0.2 のアーカイブは撤去済みです。本体にはクライアント・コア・DB・ルール・背景・カード裏面（スリーブ）を含み、カード表面・単独ロゴ・アイコン画像は含みません。

## カード表面を追加する

[Codex向け共通収集プロンプト](CODEX_IMAGE_COLLECTION.md)と、`profiles/<slug>/CODEX_COLLECT_IMAGES.md`を使います。画像は利用者のPC内へ追加します。同梱背景とスリーブは保持し、カード表面をGitHubやReleaseへアップロードしません。

## 手元のプロジェクトからZIPを作る

```powershell
python tools/build_profile_release.py unionarena --output dist/windows-local --local-project 'C:\edopro-unionarena'
```

この補助ツールは対応する専用クライアント、コア、カードパックを導入済みのプロジェクトからファイルを集めます。起動に必要な画像が欠けても動作する新版クライアントを使用してください。カード表面・ロゴ・アイコンは除外し、背景とスリーブだけを同梱します。既定skinは組込の`none`です。生成ZIP内の`ALLOWED_BACKGROUND_AND_SLEEVE_IMAGES.json`に許可画像の完全パスとSHA-256を記録します。

`--local-project`を省くと、背景1枚・起動補助・画像インポーター・Codexプロンプトだけのキットになります。キット単体では対戦できません。`--official-art`で公開用カード表面やロゴを追加する機能は無効です。

## 公開前の画像検査

```powershell
python tools/check_no_images.py --repo . --allowlist artwork/ALLOWED_IMAGES.json
python tools/check_no_images.py --zip '<配布ZIP>' --allowlist '<外部allowed-images.json>'
```

許可画像は背景またはスリーブの完全パス・SHA-256一致に限ります。`pics/`内や数値ファイル名の画像は許可できません。この検査は画像拡張子とZIP内容を検査し、exe等に埋め込まれた画像の検査は行いません。

## スリーブの出典

ローカル版の通常カードの裏面は、次の公式資料または実物カード写真から取り出しています。画像は `theme --official-back` で適用できます。

| タイトル | 裏面の参照画像 |
| --- | --- |
| 名探偵コナン TCG | [公式ルールマニュアル PDF 3 ページ目](https://www.takaratomy.co.jp/products/conan-cardgame/pdf/rule/rule_manual.pdf#page=3) |
| Cyberpunk TCG | [WeirdCo 公式製造日誌](https://cyberpunktcg.com/blog/production-update-1) ・ [通常カードの実物写真](https://www.ebay.co.uk/itm/188883305990) |
| ドラゴンボール フュージョンワールド | [FB07-104 の実物写真](https://www.ebay.com/itm/366245091408) |
| デュエル・マスターズ | [ボルシャック・モモキングNEX の実物写真](https://ec.bigban.jp/item/1017003838393) |
| ガンダムカードゲーム | [カードショップの実物写真](https://torecaplaza55.com/?pid=188984453) |
| ONE PIECEカードゲーム | [通常カードの実物写真](https://www.ebay.com/itm/137008868314) ・ [ドン!! カードの実物写真](https://www.ebay.com/itm/176371725196) |
| パルワールド OCG | [通常カードの実物写真](https://www.ebay.co.uk/itm/137568121235) |
| ポケモンカードゲーム | [日本版 XY10-010 の実物写真](https://www.ebay.com/itm/147069522429) |
| Pokémon TCG Pocket | [DeNA 公式紹介のゲットチャレンジ画面](https://dena.com/intl/news/4742/) |
| ユニオンアリーナ | [UE01BT/BLC-1-086 の実物写真](https://www.ebay.com/itm/317920829639) |
