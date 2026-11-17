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

ZIP を新規フォルダに展開し、`Start.cmd` を開いてください。既存の専用クライアント、ルール、翻訳DBとデッキ選択用のシナリオを使います。タイトルと対戦画面に作品別の背景が入ります。手元の素材を同梱するには `--official-art` に `cover.png`、`title-logo.png`、`AppIcon.ico` などを置いたフォルダを指定します。ONE PIECE のドン!! 用裏面は `don-back.png` で指定できます。

`--local-project` を省くと GitHub 配布用のセットアップキットができます。

## 素材を確認できる公式ページ

- コナンの通常カードの裏面は、オフィシャルルールマニュアルの PDF 3 ページ目に掲載されています。[タカラトミー公式マニュアル](https://www.takaratomy.co.jp/products/conan-cardgame/pdf/rule/rule_manual.pdf#page=3)
- サイバーパンクのタイトルロゴは、公式マーケティング素材のロゴ欄から取得できます。[Cyberpunk TCG Marketing Materials](https://cyberpunktcg.com/marketing-materials)
- ポケポケのロゴとアプリアイコンは、公式サイトの素材です。[Pokémon TCG Pocket 公式サイト](https://www.pokemontcgpocket.com/ja/)
- デュエマでは公式スリーブのカード裏面 ver. を使えます。[タカラトミー公式スリーブ](https://dm.takaratomy.co.jp/product/protect97/)
- ユニオンアリーナではカードの裏側に公式スタンダードブラックのスリーブを使えます。[バンダイ公式スリーブ](https://www.unionarena-tcg.com/jp/products/other/sleeve/standard_black.php)
