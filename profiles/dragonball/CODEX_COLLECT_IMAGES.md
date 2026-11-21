# Codex収集プロンプト: ドラゴンボール フュージョンワールド

PROFILE=`dragonball` / DB=`RUNTIME/expansions/dragonball.cdb`

[共通プロンプト](../../docs/CODEX_IMAGE_COLLECTION.md)を読んで、このprofile差分と合わせて画像収集を進めてください。`runtime/ProjectIgnis/config/tcg-profile.conf` が `dragonball` であることを確認し、手元DB→対応表→公式公開情報を調査します。取得元未指定だけで停止せず、確認できるものを進め、曖昧な行だけunknownで報告します。

収集するカード表面・小さなUI画像・途中データ・取得manifestはPC内のみ。同梱済みの背景・カード裏面/スリーブは保持し、収集作業で勝手に上書きしません。カード絵を全オリジナルへ置換・生成しません。認証/cookies/DRM/アクセス制限の回避や海賊版配布元を使いません。収集エージェントはgit add/commit/push・GitHub/public Releaseへの追加をしません。公開担当の例外は完全パス＋SHA-256で許可した背景/スリーブだけで、カード表面は例外にしません。既存画像を保持し、DB/Lua/デッキ/コア/exeは変更しません。

## DBとカード番号

pack/cards.json の code が数値ID。printIdはパラレル等を含む印刷番号、idは基本カード番号。pack/dragonball-ids.jsonとDBを照合する。source/rarityを確認し、公式サイトの言語/地域を記録する。

## 公開元と画像保存先

起点: [ドラゴンボール フュージョンワールドの公開情報](https://www.dbs-cardgame.com/fw/jp/cardlist/)

既存downloaderは https://www.dbs-cardgame.com/fw/images/cards/card/jp/<id>.webp、リーダー表面だけは<id>_f.webpを読む。WebP→JPEGの保存先はpics/<code>.jpg。実際に詳細ページで確認できた版・面のURLを優先する。既存downloaderは基本番号の絵を同じidの各printIdへ複写するため、その方法を使う場合はbase_art_substituteと記録し、印刷完全一致とは数えない。

最終IDは必ず手元DBの`datas.id`に存在することを確認します。参照先のURL形式は既存実装の手掛かりであり、未確認のURLを取得成功や正しい版として記録しません。通常公開で確認できたHTTPSホストだけを共通importerの`--allow-host`へ列挙します。

## 裏面・複数面・特別カード

同梱済みの背景・通常裏面・スリーブ・リソース裏面は保持します。以下で裏面の適用に触れる箇所は、欠損時のローカル補完だけを意味し、既存スリーブを上書きする指示ではありません。

リーダーのfrontとawakened/backを必ず分ける。powerBack/textBackNは効果データであり、別の画像数値IDの証拠ではない。覚醒面の対応経路がクライアント/DBで確認できるまでcode+1等を作らず、表面を裏面画像で上書きしない。kind=markerは実物カード画像と別のルール用カウンター。通常カード裏面も覚醒面とは別。

共通の小さな必須UI画像が不足する場合は、対応版の[公式EDOPro upstream](https://github.com/edo9300/edopro)のtextures/とクライアントの要求ファイルを照合し、必要分だけPC内へ取得します。カード表面・通常裏面・UI素材の取得結果を分けます。公式upstreamへの参照は画像をGitHubへ再配布する指示ではありません。

## コマンドの型

```powershell
python tools/profile_assets.py --profile dragonball --runtime "<RUNTIME>" inventory --output "<LOCAL_ART_ROOT>/missing-art.tsv"
python tools/import_images.py --runtime "<RUNTIME>" --manifest "<LOCAL_ART_ROOT>/images.tsv" --allow-host <確認できた配信ホスト>
python tools/import_images.py --runtime "<RUNTIME>" --local "<LOCAL_ART_ROOT>/numbered"
```

`images.tsv`はヘッダーなしの`数値ID<TAB>直接HTTPS画像URL`。詳細な照合記録は別にPC内へ残します。matched/kept/base_art_substitute/unknown/access_denied/failed、実際の版・言語・面・元ページ・SHA-256・保存先を報告してください。

## 実装確認の根拠

この差分は開発時の`edopro-dragonball/`内にある以下のテキスト実装を読んで作成しました。配布版に補助catalogがない場合はDBのdescと公式番号で調べ、分からない対応を捏造しません。

- `tools/download_images.py`
- `tools/import_cards.py`
- `tools/install_pack.py`
- `pack/cards.json`
- `pack/dragonball-ids.json`
