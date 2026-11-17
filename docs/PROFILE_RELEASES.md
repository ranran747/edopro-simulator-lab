# Windows タイトル別セットアップキット

各キットには作品別のタイトル・対戦背景、起動ファイル、画像インポーターと収集用プロンプトが入っています。実行には対応する専用クライアント、コア、カードパックを用意してください。[背景の生成プロンプト](../artwork/PROMPTS.md)

| タイトル | GitHub Release |
| --- | --- |
| 名探偵コナン TCG | [conan](https://github.com/ranran747/edopro-simulator-lab/releases/tag/conan-setup-v0.2.0) |
| Cyberpunk TCG | [cyberpunk](https://github.com/ranran747/edopro-simulator-lab/releases/tag/cyberpunk-setup-v0.2.0) |
| ドラゴンボール フュージョンワールド | [dragonball](https://github.com/ranran747/edopro-simulator-lab/releases/tag/dragonball-setup-v0.2.0) |
| デュエル・マスターズ | [duelmasters](https://github.com/ranran747/edopro-simulator-lab/releases/tag/duelmasters-setup-v0.2.0) |
| ガンダムカードゲーム | [gundam](https://github.com/ranran747/edopro-simulator-lab/releases/tag/gundam-setup-v0.2.0) |
| ONE PIECEカードゲーム | [onepiece](https://github.com/ranran747/edopro-simulator-lab/releases/tag/onepiece-setup-v0.2.0) |
| パルワールド OCG | [palworld](https://github.com/ranran747/edopro-simulator-lab/releases/tag/palworld-setup-v0.2.0) |
| ポケモンカードゲーム | [pokemon](https://github.com/ranran747/edopro-simulator-lab/releases/tag/pokemon-setup-v0.2.0) |
| Pokémon TCG Pocket | [pokepoke](https://github.com/ranran747/edopro-simulator-lab/releases/tag/pokepoke-setup-v0.2.0) |
| ユニオンアリーナ | [unionarena](https://github.com/ranran747/edopro-simulator-lab/releases/tag/unionarena-setup-v0.2.0) |

## 手元のプロジェクトから Windows ZIP を作る

照合済みのデータ・スクリプトをインストール済みのプロジェクトを用意します。Python 3.10 以降と Pillow を使います。

```powershell
python -m pip install Pillow
python tools/build_profile_release.py unionarena --output dist/windows-local --local-project 'C:\edopro-unionarena'
```

ZIP を新規フォルダに展開し、`Start.cmd` を開いてください。既存の専用クライアント、ルール、翻訳DBとデッキ選択用のシナリオを使います。タイトルと対戦画面に作品別の背景が入ります。裏面・ロゴ・アイコンはプロジェクトに設定された素材を使います。差し替える場合は `--official-art` に `cover.png`、`title-logo.png`、`AppIcon.ico` などを置いたフォルダを指定します。ONE PIECE のドン!! 用裏面は `don-back.png` で指定できます。

`--local-project` を省くと GitHub 配布用のセットアップキットができます。

## 素材の参照先

- サイバーパンクのタイトルロゴは、公式マーケティング素材のロゴ欄から取得できます。[Cyberpunk TCG Marketing Materials](https://cyberpunktcg.com/marketing-materials)
- ポケポケのロゴとアプリアイコンは、公式サイトの素材です。[Pokémon TCG Pocket 公式サイト](https://www.pokemontcgpocket.com/ja/)

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
