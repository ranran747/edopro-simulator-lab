"""Build profile setup kits and, optionally, a Windows ZIP for local use."""

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import sqlite3
from tempfile import TemporaryDirectory

from export_local_pack import PROFILES, pack_files, write_zip
from profile_assets import TOOLS, card_rows, profile_for
from check_no_images import IMAGE_EXTENSIONS

RUNTIME = "runtime/ProjectIgnis"
BASE_SCRIPTS = {"archetype_setcode_constants.lua", "card_counter_constants.lua",
                "cards_specific_functions.lua", "constant.lua", "debug_utility.lua",
                "deprecated_functions.lua", "utility.lua", "COPYING.txt"}
REPLACED_TEXTURES = {"cover", "cover2", "unknown"}
DEFAULT_SKIN = "none"

def allowed_image_role(path):
    p = Path(path).as_posix().lower()
    if p.startswith('artwork/') and Path(p).stem in PROFILES and Path(p).suffix == '.jpg':
        return 'background'
    if p in {'textures/tcg/title.jpg','textures/tcg/battle.jpg','textures/bg.png','textures/bg_deck.png','textures/bg_menu.png'}:
        return 'background'
    if p in {'textures/field.png','textures/field2.png','textures/field3.png','textures/field4.png',
             'textures/fieldsp.png','textures/fieldsp2.png','textures/fieldsp3.png','textures/fieldsp4.png',
             'textures/field-transparent.png','textures/field-transparent2.png',
             'textures/field-transparent3.png','textures/field-transparent4.png',
             'textures/field-transparentsp.png','textures/field-transparentsp2.png',
             'textures/field-transparentsp3.png','textures/field-transparentsp4.png'}:
        return 'background'
    if p in {'textures/cover.png','textures/cover2.png','textures/cover.jpg','textures/cover2.jpg',
             'textures/tcg/cover.png','textures/tcg/cover2.png','textures/tcg/don-back.png'}:
        return 'sleeve'
    return None

START = r"""@echo off
setlocal
cd /d "%~dp0runtime\ProjectIgnis" || goto :missing
if not exist "{client}" goto :missing
if not exist "ocgcore.dll" goto :missing
if not exist "config\tcg-profile.conf" goto :missing
findstr /x /l /c:"{profile}" "config\tcg-profile.conf" >nul || goto :missing
if not exist "expansions\{database}" goto :missing
if not exist "puzzles\{puzzle}.lua" goto :missing
start "" "{client}" -m -r
exit /b
:missing
echo The installed runtime for {profile} is missing or incomplete. See README.md.
pause
exit /b 1
"""


def update_readme(profile, client, database, local):
    title = profile["title"]
    start_steps = (
        "ZIP を展開して `Start.cmd` を開き、タイトル画面の「対戦する」を選びます。"
        if local else
        "1. ZIP を展開します。\n"
        f"2. 手元の `{title}` 専用クライアント・コア・カードパックを"
        f" `runtime/ProjectIgnis/` に揃えます。このキットには画像ツールと起動用ファイルが入っています。\n"
        f"   専用クライアントは `{client}`、カードDBは `expansions/{database}`、"
        f" `config/tcg-profile.conf` の内容は `{profile['id']}` です。\n"
        "3. `Start.cmd` を開き、タイトル画面の「対戦する」を選びます。"
    )
    return f"""# {title} / EDOPro

既存の Windows 向けシミュレーターのための非公式パッケージです。

## 起動

{start_steps}

対戦モードやカード効果の対応範囲は、お使いのカードパックの版に従います。

## カード画像

カード表面は、手元で利用できる画像を `runtime/ProjectIgnis/pics/` に追加します。
Python 3.10 以降を使います。WebP とテーマの取り込みには `python -m pip install Pillow` を実行してください。

```powershell
python tools/profile_assets.py inventory
python tools/import_images.py --runtime runtime/ProjectIgnis --local 'C:\\card-art'
python tools/import_images.py --runtime runtime/ProjectIgnis --manifest images.tsv --allow-host images.example.org
```

採番済みファイルは `<id>.jpg`、`<id>.png` または `<id>.webp` とします。取得用 TSV はヘッダーなしの `ID<TAB>直接のHTTPS画像URL` です。
`missing-art.tsv` は画像候補を調べる作業用リストです。[タイトル別の収集プロンプト](COLLECT.md)を参照してください。

## 裏面と背景

背景とカード裏面（スリーブ）は同梱し、カード表面画像は含みません。`CODEX_COLLECT_IMAGES.md`で表面画像をPC内だけに取得します。表面画像をGitHubへコミット/アップロードしないでください。

ゲームを終了し、利用可能な公式裏面を用意してから適用します。同じ裏面を通常表示・サイズ変更後の表示の両方に使います。

```powershell
python tools/profile_assets.py theme --title 'C:\\card-art\\title.jpg' --battle 'C:\\card-art\\battle.jpg'
python tools/profile_assets.py theme --official-back 'C:\\card-art\\back.png'
python tools/profile_assets.py theme --title-logo 'C:\\card-art\\logo.png' --icon 'C:\\card-art\\icon.ico'
```

同梱背景/裏面は保持し、差し替えたい場合だけ手元の画像を指定します。
`--title` と `--battle` で手元の横長素材を指定できます。ONE PIECE のリソース用裏面は `--resource-back` で個別に指定できます。

[Simulator Lab のソースとライセンス](https://github.com/ranran747/edopro-simulator-lab/blob/main/docs/SOURCE.md)
"""


def write_kit(root, profile, local=False):
    name = profile["id"]
    client = f"EDOPro-{profile['client']}.exe"
    puzzle = f"{profile['client']}_Player_Match"
    database = PROFILES[name]
    (root / "tools").mkdir()
    (root / 'artwork').mkdir()
    scene = TOOLS.parent / 'artwork' / f'{name}.jpg'
    approved = json.loads((TOOLS.parent / 'artwork/ALLOWED_IMAGES.json').read_text(encoding='utf-8'))['allowed']
    expected = next(row['sha256'] for row in approved if row['scope']=='git' and row['path']==f'artwork/{name}.jpg')
    if hashlib.sha256(scene.read_bytes()).hexdigest() != expected:
        raise ValueError('background does not match approved image manifest')
    shutil.copy2(scene, root/'artwork'/scene.name)
    for filename in ("import_images.py", "profile_assets.py", "export_local_pack.py"):
        shutil.copy2(TOOLS / filename, root / "tools" / filename)
    shutil.copy2(TOOLS.parent / "COPYING", root / "COPYING")
    (root / "profile.json").write_text(json.dumps(profile, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    launcher = START.format(profile=name, client=client, database=database, puzzle=puzzle)
    (root / "Start.cmd").write_text(launcher, encoding="ascii", newline="\r\n")
    (root / "README.md").write_text(update_readme(profile, client, database, local), encoding="utf-8")
    reference = f"\n照合用データ: {profile['reference']}\n" if "reference" in profile else ""
    prompt = f"""# {profile['title']} のカード画像を集める

以下を `missing-art.tsv` と、手元のカードパックの印刷番号対応表と一緒にエージェントへ渡してください。

> `missing-art.tsv` の数値IDをカードパックの対応表と照合してください。画像の探索先は {profile['source']} です。
> {profile['matching']}
> 利用可能な画像だけを選び、印刷番号・言語と元ページを作業用リストに記録してください。
> カード番号を照合できた行について、別の `images.tsv` にヘッダーなしで `ID<TAB>直接のHTTPS画像URL` を書いてください。
> 使用するホストを `--allow-host` で明示して `tools/import_images.py` を実行してください。ローカル提供の画像は数値IDに改名して `--local` で取り込んでください。
> 見つからないID、版や面が特定できないID、リクエストが拒否されたIDは報告してください。利用可能な公式裏面がある場合は別ファイルとして用意し、`tools/profile_assets.py theme --official-back` で適用してください。
> 同梱の背景と裏面は保持します。カード表面画像は手元や公開資料からPC内だけに取得し、git add/push/Release uploadしないでください。
{reference}"""
    supplied = TOOLS.parent / 'profiles' / name / 'CODEX_COLLECT_IMAGES.md'
    if supplied.is_file():
        prompt = supplied.read_text(encoding='utf-8')
        profile_dir = root / 'profiles' / name
        profile_dir.mkdir(parents=True)
        shutil.copy2(supplied, profile_dir / supplied.name)
    common = TOOLS.parent / 'docs' / 'CODEX_IMAGE_COLLECTION.md'
    if common.is_file():
        (root / 'docs').mkdir(exist_ok=True)
        shutil.copy2(common, root / 'docs' / common.name)
    root_prompt = prompt.replace('../../docs/CODEX_IMAGE_COLLECTION.md', 'docs/CODEX_IMAGE_COLLECTION.md')
    (root / "COLLECT.md").write_text(root_prompt, encoding="utf-8")
    (root / "CODEX_COLLECT_IMAGES.md").write_text(root_prompt, encoding="utf-8")


def copy_runtime(project, target, profile, scene, official):
    source = project / RUNTIME
    pack = project / "pack"
    name = profile["id"]
    client = f"EDOPro-{profile['client']}.exe"
    database = PROFILES[name]
    puzzle = f"puzzles/{profile['client']}_Player_Match.lua"
    if (source / "config/tcg-profile.conf").read_text(encoding="utf-8-sig").strip() != name:
        raise ValueError("source runtime profile does not match the requested kit")
    card_ids = {card_id for card_id, _ in card_rows(source, profile)}
    if not card_ids:
        raise ValueError("matching card database is empty")

    def copy(path):
        if Path(path).suffix.lower() in IMAGE_EXTENSIONS and not allowed_image_role(path):
            return
        destination = target / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source / path, destination)

    for path in (client, "ocgcore.dll", "COPYING.txt", "LICENSE.txt", "config/strings.conf",
                 "config/tcg-profile.conf", f"expansions/{database}", puzzle):
        copy(path)
    (target / "config/configs.json").write_text('{"repos": [], "urls": [], "servers": []}\n', encoding="utf-8")
    (target / "config/system.conf").write_text(
        "textfont = fonts/NotoSansJP-Regular.otf 12\nnumfont = fonts/NotoSansJP-Regular.otf\n"
        "fallbackFonts = \"bundled 12\"\nlanguage = English\n"
        f"automonsterpos = 1\nautospellpos = 1\nskin = {DEFAULT_SKIN}\n", encoding="utf-8")
    for _, path in pack_files(source, ("fonts", "notices"),
                              {".otf", ".ttf", ".txt", ".xml", ".png", ".gif"}):
        copy(path)
    for path in (source / "textures").iterdir():
        if path.is_file():
            copy(path.relative_to(source))
    for directory in (source / "config/languages").iterdir():
        for filename in ("strings.conf", f"{name}-strings.conf", database):
            path = directory / filename
            if path.is_file():
                copy(path.relative_to(source))
    for path in (pack / "puzzles").glob("*.lua"):
        installed = source / "puzzles" / path.name
        if installed.is_file():
            copy(installed.relative_to(source))
    project_scripts = {path.name for path in (pack / "script").glob("*.lua")}
    for path in (source / "script").iterdir():
        if not path.is_file():
            continue
        filename = path.name
        stem = path.stem
        if (filename in BASE_SCRIPTS or filename in project_scripts
                or (path.suffix == ".lua" and stem.startswith("proc_"))
                or (path.suffix == ".lua" and stem[0:1] == "c" and stem[1:].isdigit() and int(stem[1:]) in card_ids)
                or (name in {"pokemon", "pokepoke"} and path.suffix == ".lua"
                    and stem.startswith(("pokemon_", "legacy_", "pocket_")))):
            copy(path.relative_to(source))
    for path in ("pics", "deck", "replay", "screenshots"):
        (target / path).mkdir(exist_ok=True)
    (target / "WindBot").mkdir()
    (target / "WindBot/bots.json").write_text("[]\n", encoding="utf-8")
    for path in (source/'textures/tcg').glob('*'):
        if path.is_file() and allowed_image_role(path.relative_to(source)):
            copy(path.relative_to(source))


def build(profile, output, project, official=None):
    local = project is not None
    suffix = "Windows-local" if local else "art-and-setup-kit"
    filename = f"edopro-{profile['id']}-{suffix}"
    output.mkdir(parents=True, exist_ok=True)
    with TemporaryDirectory(dir=output, prefix=".build-") as directory:
        root = Path(directory) / filename
        root.mkdir()
        write_kit(root, profile, local)
        if local:
            copy_runtime(project, root / RUNTIME, profile, None, None)
        contents = ((path, path.relative_to(root.parent).as_posix())
                    for path in sorted(root.rglob("*"))
                    if (path.is_file() and (path.suffix.lower() not in IMAGE_EXTENSIONS
                        or allowed_image_role(path.relative_to(root).as_posix().replace(RUNTIME+'/', ''))))
                    or (local and path.is_dir() and not any(path.iterdir())))
        target = output / f"{filename}.zip"
        contents=list(contents)
        allowed=[]
        for path,name in contents:
            if path.is_file() and path.suffix.lower() in IMAGE_EXTENSIONS:
                relative=path.relative_to(root).as_posix().replace(RUNTIME+'/', '')
                role=allowed_image_role(relative)
                if not role:raise ValueError('unapproved image in release')
                allowed.append({'scope':'zip','path':name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'role':role})
        allowfile=root/'ALLOWED_BACKGROUND_AND_SLEEVE_IMAGES.json'
        allowfile.write_text(json.dumps({'version':1,'allowed':allowed},indent=2)+'\n',encoding='utf-8')
        contents.append((allowfile,allowfile.relative_to(root.parent).as_posix()))
        write_zip(target, contents)
    print(target)
    return target


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("profile", choices=PROFILES)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--local-project", type=Path, help="build a local-only ZIP from this installed simulator")
    parser.add_argument("--official-art", type=Path, help="folder of publisher artwork to use in a local ZIP")
    args = parser.parse_args()
    if args.official_art:
        parser.error('Images are local-only: import artwork after extraction with profile_assets.py theme.')
    if args.official_art and (not args.local_project or not args.official_art.is_dir()):
        parser.error("--official-art requires a local project and an existing artwork directory")
    try:
        build(profile_for(args.profile), args.output, args.local_project, args.official_art)
    except ImportError:
        parser.error("Windows ZIP assembly needs Pillow. Run: python -m pip install Pillow")
    except (OSError, ValueError, sqlite3.Error) as error:
        parser.error(str(error))


if __name__ == "__main__":
    main()
