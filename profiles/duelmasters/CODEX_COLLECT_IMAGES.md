# Codex収集プロンプト: デュエル・マスターズ

PROFILE=`duelmasters` / DB=`RUNTIME/expansions/duelmasters.cdb`

[共通プロンプト](../../docs/CODEX_IMAGE_COLLECTION.md)を読んで、このprofile差分と合わせて画像収集を進めてください。`runtime/ProjectIgnis/config/tcg-profile.conf` が `duelmasters` であることを確認し、手元DB→対応表→公式公開情報を調査します。取得元未指定だけで停止せず、確認できるものを進め、曖昧な行だけunknownで報告します。

収集するカード表面・小さなUI画像・途中データ・取得manifestはPC内のみ。同梱済みの背景・カード裏面/スリーブは保持し、収集作業で勝手に上書きしません。カード絵を全オリジナルへ置換・生成しません。認証/cookies/DRM/アクセス制限の回避や海賊版配布元を使いません。収集エージェントはgit add/commit/push・GitHub/public Releaseへの追加をしません。公開担当の例外は完全パス＋SHA-256で許可した背景/スリーブだけで、カード表面は例外にしません。既存画像を保持し、DB/Lua/デッキ/コア/exeは変更しません。

## DBとカード番号

data/cards.json（DM26-SD1）だけでなく data/catalog.json と tools/card_source.py のload_cardsを読む。pack/duelmasters-ids.jsonのキーは、deckがあるもの/DM26SD1がid、その他が name: + name_key(faces)。name_keyは各face.nameの空白を除去して/結合する。保守実装が同名再録を1数値IDに統合するため、catalogのid/product/prints/firstPrintから今回表示する実際の印刷を別に記録する。既存DB/idsは再生成しない。

## 公開元と画像保存先

起点: [デュエル・マスターズの公開情報](https://dm.takaratomy.co.jp/card/)

faces[].image のうち確認できた画像パスを公式元ページと照合し、https://dm.takaratomy.co.jp + 相対パスを候補にする。保存先は上記code_keyに対応するpics/<数値ID>.jpg。既存download_images.pyはdata/cards.jsonの319行を読む版で、全catalog/DBをカバーしない。手元DBの欠損数から対象を決め、319枚取得で全件完了と報告しない。

最終IDは必ず手元DBの`datas.id`に存在することを確認します。参照先のURL形式は既存実装の手掛かりであり、未確認のURLを取得成功や正しい版として記録しません。通常公開で確認できたHTTPSホストだけを共通importerの`--allow-host`へ列挙します。

## 裏面・複数面・特別カード

同梱済みの背景・通常裏面・スリーブ・リソース裏面は保持します。以下で裏面の適用に触れる箇所は、欠損時のローカル補完だけを意味し、既存スリーブを上書きする指示ではありません。

ツインパクトは上下のクリーチャー/呪文が両方写る1枚のフルカード画像を使い、片方だけ切り取らない。facesが2つあるサイキック/両面カードはツインパクトと区別し、表裏・変身後の表示経路を確認する。顔名の組み合わせが曖昧ならunknown。通常共通裏面をカード固有の第2面と混同しない。

共通の小さな必須UI画像が不足する場合は、対応版の[公式EDOPro upstream](https://github.com/edo9300/edopro)のtextures/とクライアントの要求ファイルを照合し、必要分だけPC内へ取得します。カード表面・通常裏面・UI素材の取得結果を分けます。公式upstreamへの参照は画像をGitHubへ再配布する指示ではありません。

## コマンドの型

```powershell
python tools/profile_assets.py --profile duelmasters --runtime "<RUNTIME>" inventory --output "<LOCAL_ART_ROOT>/missing-art.tsv"
python tools/import_images.py --runtime "<RUNTIME>" --manifest "<LOCAL_ART_ROOT>/images.tsv" --allow-host <確認できた配信ホスト>
python tools/import_images.py --runtime "<RUNTIME>" --local "<LOCAL_ART_ROOT>/numbered"
```

`images.tsv`はヘッダーなしの`数値ID<TAB>直接HTTPS画像URL`。詳細な照合記録は別にPC内へ残します。matched/kept/base_art_substitute/unknown/access_denied/failed、実際の版・言語・面・元ページ・SHA-256・保存先を報告してください。

## 実装確認の根拠

この差分は開発時の`edopro-duelmasters/`内にある以下のテキスト実装を読んで作成しました。配布版に補助catalogがない場合はDBのdescと公式番号で調べ、分からない対応を捏造しません。

- `tools/card_source.py`
- `tools/install_pack.py`
- `tools/download_images.py`
- `data/cards.json`
- `data/catalog.json`
- `pack/duelmasters-ids.json`
