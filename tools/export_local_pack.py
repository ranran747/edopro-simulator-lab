"""Export a local simulator's installed content as two image-free overlays."""
import argparse
from pathlib import Path
import sqlite3
from tempfile import NamedTemporaryFile
from zipfile import ZIP_DEFLATED, ZipFile

PROFILES = {
    "conan": "conan.cdb", "cyberpunk": "cyberpunk.cdb", "dragonball": "dragonball.cdb",
    "duelmasters": "duelmasters.cdb", "gundam": "gundam.cdb", "onepiece": "onepiece.cdb",
    "palworld": "palworld.cdb", "pokemon": "pokemon-demo.cdb", "pokepoke": "pokepoke.cdb",
    "unionarena": "unionarena.cdb",
}


def pack_files(source, folders, extensions):
    for folder in folders:
        for path in sorted((source / folder).rglob("*")):
            rel = path.relative_to(source)
            if path.is_file() and path.suffix.lower() in extensions and not any(
                    part.startswith(".") for part in rel.parts):
                yield path, rel.as_posix()


def write_zip(output, items):
    with NamedTemporaryFile(dir=output.parent, delete=False) as temp:
        staged = Path(temp.name)
    try:
        with ZipFile(staged, "w", compression=ZIP_DEFLATED, compresslevel=6) as archive:
            for path, name in items:
                archive.write(path, name)
        staged.replace(output)
    finally:
        staged.unlink(missing_ok=True)


def installed_card_scripts(database, runtime, existing):
    with sqlite3.connect(database.resolve().as_uri() + "?mode=ro", uri=True) as db:
        card_ids = [row[0] for row in db.execute("SELECT id FROM datas ORDER BY id")]
    missing = 0
    for card_id in card_ids:
        name = f"runtime/ProjectIgnis/script/c{card_id}.lua"
        if name.casefold() in existing:
            continue
        path = runtime / "script" / f"c{card_id}.lua"
        if path.is_file():
            yield path, name
        else:
            missing += 1
    if missing:
        print(f"No individual Lua file installed for {missing} card IDs; check the source pack before use.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("profile", choices=PROFILES)
    parser.add_argument("--project", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    source = args.project / "pack"
    runtime = args.project / "runtime/ProjectIgnis"
    database = source / "expansions" / PROFILES[args.profile]
    if not database.is_file():
        parser.error(f"missing {database}; generate the pack in the source project first")
    data = [(database, f"runtime/ProjectIgnis/expansions/{database.name}")]
    data.extend(pack_files(source, ("card-text",), {".txt", ".json", ".tsv"}))
    rules = [(path, f"runtime/ProjectIgnis/{name}") for path, name in
             pack_files(source, ("script", "puzzles"), {".lua"})]
    rules.extend(installed_card_scripts(database, runtime, {name.casefold() for _, name in rules}))
    for path, name in pack_files(source, ("deck", "decks"), {".ydk", ".txt"}):
        rules.append((path, "runtime/ProjectIgnis/deck/" + name.split("/", 1)[1]))
    runtime_deck_index = runtime / "deck/player-decks.txt"
    if runtime_deck_index.is_file() and not any(n.endswith("/player-decks.txt") for _, n in rules):
        rules.append((runtime_deck_index, "runtime/ProjectIgnis/deck/player-decks.txt"))
    if not rules:
        parser.error(f"no rules found in {source}")
    if len({name.casefold() for _, name in rules}) != len(rules):
        parser.error("duplicate overlay paths; resolve the conflicting source files")
    args.output.mkdir(parents=True, exist_ok=True)
    for suffix, items in (("card-text", data), ("rules", rules)):
        output = args.output / f"{args.profile}-{suffix}.zip"
        write_zip(output, items)
        print(f"{output.name}: {len(items)} files")


if __name__ == "__main__":
    main()
