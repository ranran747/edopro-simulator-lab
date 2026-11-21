# Codex収集プロンプト: ガンダムカードゲーム

PROFILE=`gundam` / DB=`RUNTIME/expansions/gundam.cdb`

[共通プロンプト](../../docs/CODEX_IMAGE_COLLECTION.md)を読んで、このprofile差分と合わせて画像収集を進めてください。`runtime/ProjectIgnis/config/tcg-profile.conf` が `gundam` であることを確認し、手元DB→対応表→公式公開情報を調査します。取得元未指定だけで停止せず、確認できるものを進め、曖昧な行だけunknownで報告します。

収集するカード表面・小さなUI画像・途中データ・取得manifestはPC内のみ。同梱済みの背景・カード裏面/スリーブは保持し、収集作業で勝手に上書きしません。カード絵を全オリジナルへ置換・生成しません。認証/cookies/DRM/アクセス制限の回避や海賊版配布元を使いません。収集エージェントはgit add/commit/push・GitHub/public Releaseへの追加をしません。公開担当の例外は完全パス＋SHA-256で許可した背景/スリーブだけで、カード表面は例外にしません。既存画像を保持し、DB/Lua/デッキ/コア/exeは変更しません。

## DBとカード番号

pack/cards.json の codeを数値IDに使い、printId（_p等の印刷差分を保持）/id/rarity/sourceを照合する。pack/gundam-ids.jsonがあれば一致を確認する。公式言語・地域と画像の実言語を併記し、日本語UIだけを根拠に言語を確定しない。

## 公開元と画像保存先

起点: [ガンダムカードゲームの公開情報](https://www.gundam-gcg.com/jp/cards/)

既存URLの起点は https://www.gundam-gcg.com/jp/images/cards/card/<printId>.webp。公式詳細ページでprintIdとURLを確認し、静止WebP→JPEGでpics/<code>.jpgへ置く。基本idへ正規化して全パラレルを同じ絵にしない。

最終IDは必ず手元DBの`datas.id`に存在することを確認します。参照先のURL形式は既存実装の手掛かりであり、未確認のURLを取得成功や正しい版として記録しません。通常公開で確認できたHTTPSホストだけを共通importerの`--allow-host`へ列挙します。

## 裏面・複数面・特別カード

同梱済みの背景・通常裏面・スリーブ・リソース裏面は保持します。以下で裏面の適用に触れる箇所は、欠損時のローカル補完だけを意味し、既存スリーブを上書きする指示ではありません。

GCG-TOKEN/code349900100とGCG-EXRES/code349900200はルール用エントリー。実装/現DBが違えばDBの値を優先する。実カード画像がないものはunknownまたは既存のUI代替として区別し、架空の公式カード画像を生成しない。通常カードの裏面は共通themeへ別に入れる。

共通の小さな必須UI画像が不足する場合は、対応版の[公式EDOPro upstream](https://github.com/edo9300/edopro)のtextures/とクライアントの要求ファイルを照合し、必要分だけPC内へ取得します。カード表面・通常裏面・UI素材の取得結果を分けます。公式upstreamへの参照は画像をGitHubへ再配布する指示ではありません。

## コマンドの型

```powershell
python tools/profile_assets.py --profile gundam --runtime "<RUNTIME>" inventory --output "<LOCAL_ART_ROOT>/missing-art.tsv"
python tools/import_images.py --runtime "<RUNTIME>" --manifest "<LOCAL_ART_ROOT>/images.tsv" --allow-host <確認できた配信ホスト>
python tools/import_images.py --runtime "<RUNTIME>" --local "<LOCAL_ART_ROOT>/numbered"
```

`images.tsv`はヘッダーなしの`数値ID<TAB>直接HTTPS画像URL`。詳細な照合記録は別にPC内へ残します。matched/kept/base_art_substitute/unknown/access_denied/failed、実際の版・言語・面・元ページ・SHA-256・保存先を報告してください。

## 実装確認の根拠

この差分は開発時の`edopro-gundam/`内にある以下のテキスト実装を読んで作成しました。配布版に補助catalogがない場合はDBのdescと公式番号で調べ、分からない対応を捏造しません。

- `tools/download_images.py`
- `tools/import_cards.py`
- `tools/install_pack.py`
- `pack/cards.json`
