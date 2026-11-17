# Card artwork import / カード画像の追加

Pass the following to Codex with your own pack, local images, or a manifest from a source that permits your planned use.

> Inspect this pack's numeric card IDs in its `expansions/*.cdb` files (the `datas.id` column), or use the pack maintainer's ID mapping. Place JPG or PNG artwork I supply into `runtime/ProjectIgnis/pics` as `<numeric-card-ID>.jpg` or `<numeric-card-ID>.png`. Preserve existing files. For an authorized direct HTTPS source, prepare an `images.tsv` with one `ID<TAB>URL` row per image and use `tools/import_images.py`, passing each source hostname through `--allow-host`. Ask me for an image source if I have supplied none. Report missing IDs and ambiguous printings. Keep card text, Lua, deck files and the installed runtime configuration intact.

Codex には同じフォルダで次のように依頼できます。

> このカードパックの `expansions/*.cdb` の `datas.id` と、パック提供者の対応表を参照してください。私が用意した画像を `runtime/ProjectIgnis/pics/<数値ID>.jpg` または `.png` に配置してください。既存画像は保持してください。利用条件を確認済みの HTTPS URL を使う場合は `ID<TAB>URL` の `images.tsv` を作り、ホストを明示して `tools/import_images.py` を実行してください。取得元が未指定なら確認してください。欠けたIDや版違いを報告し、DB・Lua・デッキ・設定は変更しないでください。
