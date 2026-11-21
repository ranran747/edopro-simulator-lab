# Codex: カード表面をPC内へ収集する共通プロンプト

この文書と `profiles/<slug>/CODEX_COLLECT_IMAGES.md` をCodexに渡す。公開リポジトリ・公開Releaseにはカード表面を置かず、背景画像とカード裏面/スリーブだけを完全パス＋SHA-256の許可リストに従って同梱する。収集対象のカード表面と不足する小さなUI画像は利用者のPC上だけで揃える。同梱済みの背景・スリーブは保持し、収集作業で勝手に上書きしない。画像の収集元が利用者から指定されていなくても、同梱DBと対応表→作品公式の公開カード検索・資料→確認できた直接画像URLの順で調査して進める。曖昧な行だけをunknownに残し、他の行を続ける。

## そのまま渡す総合プロンプト

```text
対象PROFILEのWindowsシミュレーターに、既存カードの表面画像をPCローカルで追加してください。同梱済みの背景・カード裏面/スリーブは保持し、ハッシュを記録して勝手に上書きしません。PROFILEはprofiles/<slug>/CODEX_COLLECT_IMAGES.mdとruntime/ProjectIgnis/config/tcg-profile.confを照合して決めます。両者が異なる場合は別ゲームの画像を入れず、正しい実行フォルダーを探してください。

これは画像収集・照合・ローカル設定の依頼です。カード絵を全オリジナルに置き換えたり、似た絵を生成して既存カードの代わりにしたりしません。公開元の通常アクセスで参照できる画像と、利用者が既に持つ画像を使います。画像の取得元が未指定という理由だけで止まらず、下記の公式公開情報を調べて収集を進めてください。認証、cookies、DRM、アクセス制限の回避、海賊版配布元は使いません。403/429や認証要求が出た取得元は止めてunknown理由を残し、別の公開資料・手元素材や他のカードの作業を進めます。TLS検証は無効化しません。

1. RUNTIME=実際のruntime/ProjectIgnis、LOCAL_ART_ROOT=Git作業ツリーの外のPC専用フォルダーを確定します。例えばWindowsのLocalAppData配下 EDOProSimulatorLab/card-art/PROFILE を使います。公開repoのartwork、docs、pack、distやRelease用一時フォルダーを画像保存先にしません。
2. 指定されたexpansions/<DB名>をSQLite読取専用で開き、datas.idを画像ファイル名の正本にします。texts.name/descと、存在するpack/cards.json、pack/*-ids.json、dataのカードメタデータを照合します。数値ID、カード番号、印刷版、セット/商品、言語、面、画像元ページの対応表を作ります。カード名だけで別印刷を同一視しません。対応表が同梱されていない場合もDBのdescや公式番号を調べ、照合できないIDだけunknownにします。DBやID対応表を再生成・再採番しません。
3. tools/profile_assets.pyのinventoryで欠損一覧を作ります。作業用TSVの列は id,name,printing,language,image_url,source_page です。既存画像があるIDと同じstemの別拡張子が複数ある場合は報告し、利用者の既存画像を勝手に上書き・削除しません。
4. 各profileの公式検索ページと既存メタデータを起点に、カード番号・印刷差分・セット・言語・面が一致する画像を探します。画像URLの推測を成功扱いせず、公開の詳細ページ・メタデータからURLを裏付けます。日本語UI/翻訳DBであっても画像が日本語版とは限りません。picsは通常1数値IDに1画像なので、別言語画像を同じIDへ無言で上書きしません。
5. 同じ番号の通常版をパラレルの代わりに使った場合は、base_art_substituteと実際の元版・元言語を記録し、完全一致の印刷画像として数えません。番号・面が曖昧ならunknownです。裏面、覚醒面、ツインパクト、AP、ドン!!、トークン、エネルギーはprofile差分に従って別扱いにします。
6. 確認済みの数値IDだけ、LOCAL_ART_ROOT/images.tsvへヘッダーなし ID<TAB>直接のHTTPS画像URL を書きます。IDがDBに存在することと重複IDがないことを確認し、実際の配信ホストを個別に--allow-hostへ指定してtools/import_images.pyを実行します。通常の公開CDNへのredirectも実際のホストを確認します。手元素材は番号を確認してLOCAL_ART_ROOT内へ<数値ID>.jpg/.png/.webpとして用意し、--localで取り込みます。公開ページURLを直接画像URLの代わりにTSVへ入れません。
7. カード表面の最終保存先はRUNTIME/pics/<datas.id>.jpgまたは.pngです。共通importerは静止WebPをJPEGへ変換できます。変換・回転・余白追加をした場合は元ファイルをPC内に残し、元URL/ファイル、SHA-256、変換内容、保存先を記録します。元画像を描き替えたり、別カード名を合成しません。
8. 通常裏面・スリーブと背景は同梱済みを優先して保持します。各profile差分の「裏面を適用する」という説明は、欠損している場合に限ります。欠損時は公式の公開ルール資料・紹介ページや利用者の手元素材から確認します。カード表面のpicsとは別です。tools/profile_assets.py theme --official-back <PC内の画像>はtextures/tcg/cover.png、textures/cover.png、textures/cover2.pngを上書きするので、既存スリーブがある場合は実行しません。ONE PIECEのドン!!裏面は別引数--resource-backです。追加取得の背景/ロゴもPC内のみで、カード絵の代替にはしません。
9. カード表面を同梱しない配布版で起動に必要な小さなUI画像が不足する場合は、対応版の公式EDOPro upstreamを確認して、必要なファイルだけPC内のRUNTIME/textures/等へ取得します。参照元は https://github.com/edo9300/edopro のtextures/および対応する公式配布物です。使用版/commit、元パス、取得先、SHA-256を記録します。client/gframe/image_manager.cppのASSERT_TEXTURE_LOADED等とskin XMLが要求する名前を調べます。act/attack/chain/equip/field系/settings等は版によって必要性が異なるため実装で確認し、checkbox等のoptional画像を全て必須とは言いません。upstreamのカード画像を別ゲームのカード表面に流用したり、texturesディレクトリー全体を公開パッケージに同梱したりしません。
10. DB、Lua、見本デッキ、コア、exe、認証・ネットワーク設定は変更しません。カード画像を入れるためにinstall_pack.pyを丸ごと実行するとDB/Luaまで書き換える実装があるため、原則として共通importerを使います。同梱済みの背景・スリーブは既存のまま保持し、カード表面の収集作業で再生成・差替えしません。生成物を元のカード絵の代わりにしません。
11. 収集したカード表面・小さなUI画像・途中ファイル・ローカル収集manifest・スクリーンショット・カード表面入りZIPはPC内のみです。収集エージェントはgit add/commit/push、GitHub API upload、public Release作成・差替えをしません。公開担当が同梱する例外は、背景/スリーブとしてレビュー済みの完全パス＋SHA-256が一致するものだけです。同梱済みの背景・スリーブを削除・上書きせず保持します。画像をGitにignoreしてもZIPへの混入防止にはならないため、収集作業で公開ZIPを作りません。履歴や既存公開物の削除もしません。
12. ローカル報告に matched / kept / base_art_substitute / unknown / access_denied / failed を分けて数えます。unknownを取得済みや全カード対応に数えません。通常裏面、リソース裏面、各カードの面・版・言語、小さなUI画像の確認結果を別々に示します。画像不足でも確認済みの収集分を完了させ、残ったIDと具体的理由を報告してください。
```

## 共通ツールの実コマンド

以下のプレースホルダーを実フォルダーに置換し、作業フォルダーにある同梱toolsを使う。

```powershell
python tools/profile_assets.py --profile <slug> --runtime "<RUNTIME>" inventory --output "<LOCAL_ART_ROOT>/missing-art.tsv"
python tools/import_images.py --runtime "<RUNTIME>" --manifest "<LOCAL_ART_ROOT>/images.tsv" --allow-host <実際の配信ホスト>
python tools/import_images.py --runtime "<RUNTIME>" --local "<LOCAL_ART_ROOT>/numbered"
# 裏面が欠損している場合だけ（同梱の背景/スリーブは保持）
python tools/profile_assets.py --profile <slug> --runtime "<RUNTIME>" theme --official-back "<LOCAL_ART_ROOT>/back.png"
```

`inventory`の出力先は未使用のファイル名を使う。共通importerは既存のJPG/JPEG/PNGを保持し、WebPはPillowでJPEGに変換する。`--manifest`は公開HTTPSホストの個別allowlistが必要。`--local`は数値ファイル名のみを取り込む。これらは**画像をPCへ置く操作**であり、公開ZIPの製造手順ではない。

## ProfileとDB

|slug|DB（RUNTIME/expansions以下）|画像ID照合の補助データ|
|---|---|---|
|conan|conan.cdb|data/cards.json + pack/conan-ids.json: card_num→数値ID|
|cyberpunk|cyberpunk.cdb|data/cards.json + pack/cyberpunk-ids.json: id→数値ID|
|dragonball|dragonball.cdb|pack/cards.json: code / printId / id|
|duelmasters|duelmasters.cdb|data/cards.json + data/catalog.json + pack/duelmasters-ids.json: deckのidまたはname:<faces>→数値ID|
|gundam|gundam.cdb|pack/cards.json: code / printId / id|
|onepiece|onepiece.cdb|pack/cards.json: code / printId / id|
|palworld|palworld.cdb|pack/cards.json: code / id / sourceUrl|
|pokemon|pokemon-demo.cdb|pack/cards.json: code / sourceId / setId / number|
|pokepoke|pokepoke.cdb|data/cards.json + pack/pokepoke-ids.json: TCGdex id→数値ID|
|unionarena|unionarena.cdb|data/cards.json + pack/unionarena-ids.json: number / AP-<作品>→数値ID|

補助データがない配布版でもDBの既存IDを再採番しない。参考リストの件数は版で変わるため、取得対象数は手元のDBから読み取る。`datas`登録数・印刷差分数・取得画像数・カード効果の対応数は別々の値である。

## カード表面の再混入チェック・背景/スリーブの例外

ローカル画像フォルダーをGit作業ツリー外に置き、`.gitignore.local-art.fragment`相当の除外を適用する。公開担当は、許可した背景/スリーブだけを完全なパス・SHA-256で照合し、下記の検査を使う。カード表面が入ったsource ZIP・旧Releaseの追加画像ZIPも公開候補に混ぜない。背景とカード裏面/スリーブを含むだけのパッケージは許可リストで検証する。公開先tagは公開担当の`windows-2026.11.21-preview3-local-card-art`への再構築対象。

```powershell
python tools/check_no_images.py --repo . --index --allowlist "<Git用許可リストJSON>"
python tools/check_no_images.py --zip "<公開候補Windows ZIP>" --allowlist "<ZIP用許可リストJSON>"
python tools/check_no_images.py --repo . --ref HEAD --zip "<公開候補source ZIP>" --allowlist "<GitとZIPを列挙した許可リストJSON>"
```

allowlist省略時は既定で全画像を拒否する。指定時はscope・完全パス・実バイトのSHA-256が一致する背景/スリーブだけを許可する。exit 0のみ検査を通過。不許可画像ありは1、壊れたZIP・暗号化/未対応/上限超過の内部archiveなど未検査があれば2。ネストZIPも検査する。全Release資産・全ZIPを明示して検査し、検査したZIPのSHA-256と実際に公開する資産のSHA-256を一致させる。Git検査はHEADまたはindexのパスが対象で、ignoreされたローカル画像は公開対象ではない。

許可リストは `{"version":1,"allowed":[{"scope":"git または zip","path":"完全な相対パス","sha256":"実ファイルの64桁SHA-256","role":"background または sleeve"}]}` の形。`bytes`は任意。Git用はrepo相対パス、ZIP用は先頭フォルダーも含む完全なentryパスで、glob・部分一致・pics/配下・数値ファイル名・card_face roleは禁止。package root相対のpathを使う場合だけ `--archive-root "<ZIP先頭フォルダー名>"` でその1階層を明示する。自動で先頭階層を剥がさない。Git画像のSHAはworktreeではなく選んだHEAD/indexのblobを読む。

これは拡張子と許可画像のハッシュによる検査であり、exe/PDF/DB内部、HTML/base64、拡張子を変えた画像、過去commitや検査に渡していない旧Releaseの無画像化までは証明しない。収集エージェントはそれらの削除・公開操作をしない。

## 実装根拠と参照先

共通CLIの根拠: 公開repoの `tools/import_images.py`、`tools/profile_assets.py`、`tools/export_local_pack.py`、`tools/release_profiles.json`。ゲーム差分の根拠は各 `edopro-<slug>/tools/download_images.py`・ID表・カードcatalog。Pocketは`tools/install_pack.py`の画像jobsのみを読み、DB変更を伴うインストールは指示していない。

小さなUI素材のupstream参照: [edo9300/edopro](https://github.com/edo9300/edopro)。ゲーム別の公式カード検索は各profile差分に列挙。これらのURLは探索の起点であり、画像取得済みや全ての版・言語の網羅を意味しない。
