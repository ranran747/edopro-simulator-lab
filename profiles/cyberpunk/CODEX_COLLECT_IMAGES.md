# Codex収集プロンプト: Cyberpunk TCG

PROFILE=`cyberpunk` / DB=`RUNTIME/expansions/cyberpunk.cdb`

[共通プロンプト](../../docs/CODEX_IMAGE_COLLECTION.md)を読んで、このprofile差分と合わせて画像収集を進めてください。`runtime/ProjectIgnis/config/tcg-profile.conf` が `cyberpunk` であることを確認し、手元DB→対応表→公式公開情報を調査します。取得元未指定だけで停止せず、確認できるものを進め、曖昧な行だけunknownで報告します。

収集するカード表面・小さなUI画像・途中データ・取得manifestはPC内のみ。同梱済みの背景・カード裏面/スリーブは保持し、収集作業で勝手に上書きしません。カード絵を全オリジナルへ置換・生成しません。認証/cookies/DRM/アクセス制限の回避や海賊版配布元を使いません。収集エージェントはgit add/commit/push・GitHub/public Releaseへの追加をしません。公開担当の例外は完全パス＋SHA-256で許可した背景/スリーブだけで、カード表面は例外にしません。既存画像を保持し、DB/Lua/デッキ/コア/exeは変更しません。

## DBとカード番号

data/cards.json の id を pack/cyberpunk-ids.json で数値IDへ変換し、number と set/sets、版・言語を併記する。英語/フランス語等のテキスト差分があっても同じ印刷画像とは決めない。

## 公開元と画像保存先

起点: [Cyberpunk TCGの公開情報](https://cyberpunktcg.com/cards)

data/cards.json の image は公式公開カードDBの画像URL。期限付きsigned URLが古い場合は公式カードページの現在の通常公開情報から取得元を確認し直す。認証/cookies等を使わず確認できない行だけunknown。URLを数値IDから推測しない。既存downloaderはJPEGへ変換してpics/<ids[id]>.jpgへ保存する。

最終IDは必ず手元DBの`datas.id`に存在することを確認します。参照先のURL形式は既存実装の手掛かりであり、未確認のURLを取得成功や正しい版として記録しません。通常公開で確認できたHTTPSホストだけを共通importerの`--allow-host`へ列挙します。

## 裏面・複数面・特別カード

同梱済みの背景・通常裏面・スリーブ・リソース裏面は保持します。以下で裏面の適用に触れる箇所は、欠損時のローカル補完だけを意味し、既存スリーブを上書きする指示ではありません。

横長レンダーをパルワールド建築物と同じ理由で一律に90度回転しない。元の向きとアスペクト比を記録する。通常裏面・ロゴは公式公開資料または利用者素材からローカルで適用。カード画像と任意のマーケティング素材を別リストにする。

共通の小さな必須UI画像が不足する場合は、対応版の[公式EDOPro upstream](https://github.com/edo9300/edopro)のtextures/とクライアントの要求ファイルを照合し、必要分だけPC内へ取得します。カード表面・通常裏面・UI素材の取得結果を分けます。公式upstreamへの参照は画像をGitHubへ再配布する指示ではありません。

## コマンドの型

```powershell
python tools/profile_assets.py --profile cyberpunk --runtime "<RUNTIME>" inventory --output "<LOCAL_ART_ROOT>/missing-art.tsv"
python tools/import_images.py --runtime "<RUNTIME>" --manifest "<LOCAL_ART_ROOT>/images.tsv" --allow-host <確認できた配信ホスト>
python tools/import_images.py --runtime "<RUNTIME>" --local "<LOCAL_ART_ROOT>/numbered"
```

`images.tsv`はヘッダーなしの`数値ID<TAB>直接HTTPS画像URL`。詳細な照合記録は別にPC内へ残します。matched/kept/base_art_substitute/unknown/access_denied/failed、実際の版・言語・面・元ページ・SHA-256・保存先を報告してください。

## 実装確認の根拠

この差分は開発時の`edopro-cyberpunk/`内にある以下のテキスト実装を読んで作成しました。配布版に補助catalogがない場合はDBのdescと公式番号で調べ、分からない対応を捏造しません。

- `tools/download_images.py`
- `tools/fetch_official.py`
- `data/cards.json`
- `pack/cyberpunk-ids.json`
