# Windows タイトル別セットアップキット

各キットには起動ファイル、カード画像のインポーター、収集用プロンプト、裏面と背景の取り込みツールが入っています。実行には対応する専用クライアント、コア、カードパックを用意してください。

| タイトル | GitHub Release |
| --- | --- |
| 名探偵コナン TCG | [conan](https://github.com/ranran747/edopro-simulator-lab/releases/tag/conan-setup-v0.1.0) |
| Cyberpunk TCG | [cyberpunk](https://github.com/ranran747/edopro-simulator-lab/releases/tag/cyberpunk-setup-v0.1.0) |
| ドラゴンボール フュージョンワールド | [dragonball](https://github.com/ranran747/edopro-simulator-lab/releases/tag/dragonball-setup-v0.1.0) |
| デュエル・マスターズ | [duelmasters](https://github.com/ranran747/edopro-simulator-lab/releases/tag/duelmasters-setup-v0.1.0) |
| ガンダムカードゲーム | [gundam](https://github.com/ranran747/edopro-simulator-lab/releases/tag/gundam-setup-v0.1.0) |
| ONE PIECEカードゲーム | [onepiece](https://github.com/ranran747/edopro-simulator-lab/releases/tag/onepiece-setup-v0.1.0) |
| パルワールド OCG | [palworld](https://github.com/ranran747/edopro-simulator-lab/releases/tag/palworld-setup-v0.1.0) |
| ポケモンカードゲーム | [pokemon](https://github.com/ranran747/edopro-simulator-lab/releases/tag/pokemon-setup-v0.1.0) |
| Pokémon TCG Pocket | [pokepoke](https://github.com/ranran747/edopro-simulator-lab/releases/tag/pokepoke-setup-v0.1.0) |
| ユニオンアリーナ | [unionarena](https://github.com/ranran747/edopro-simulator-lab/releases/tag/unionarena-setup-v0.1.0) |

## 手元のプロジェクトから Windows ZIP を作る

照合済みのデータ・スクリプトをインストール済みのプロジェクトを用意します。Python 3.10 以降と Pillow を使います。

```powershell
python -m pip install Pillow
python tools/build_profile_release.py unionarena --output dist/windows-local --local-project 'C:\edopro-unionarena'
```

ZIP を新規フォルダに展開し、`Start.cmd` を開いてください。既存の専用クライアント、ルール、翻訳DBとデッキ選択用のシナリオを使います。カード表面は必要に応じてインポートできます。裏面と背景の初期表示は幾何学模様で、利用できる公式裏面は `theme --official-back` で取り込めます。

`--local-project` を省くと GitHub 配布用のセットアップキットができます。
