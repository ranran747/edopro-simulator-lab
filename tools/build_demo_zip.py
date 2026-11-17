"""Assemble the Windows CLI demo from verified local build outputs."""
import argparse
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

ROOT = Path(__file__).resolve().parents[1]
LAUNCHER = r"""@echo off
setlocal
set "ROOT=%~dp0."
"%ROOT%\MatchRunner.exe" "%ROOT%" 20 "%ROOT%\engine" "%ROOT%\shared-scripts" UnionArena_AI_vs_AI.lua
if errorlevel 1 exit /b 1
echo Match traces are in the artifacts folder.
"""


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    files = {"MatchRunner.exe": ROOT / "artifacts/UnionArenaSmoke.exe",
             "engine/ocgcore.dll": ROOT / "native/build/Release/ocgcore.dll",
             "COPYING": ROOT / "COPYING", "engine/LICENSE": ROOT / "native/ocgcore/LICENSE",
             "README.md": ROOT / "README.md", "docs/README.ja.md": ROOT / "docs/README.ja.md",
             "docs/SOURCE.md": ROOT / "docs/SOURCE.md",
             "docs/PACKS.md": ROOT / "docs/PACKS.md",
             "docs/IMPORT_IMAGES_WITH_CODEX.md": ROOT / "docs/IMPORT_IMAGES_WITH_CODEX.md",
             "tools/import_images.py": ROOT / "tools/import_images.py",
             "tools/export_local_pack.py": ROOT / "tools/export_local_pack.py"}
    for folder in ("pack", "shared-scripts"):
        for file in sorted((ROOT / folder).rglob("*")):
            if file.is_file() and file.suffix in (".lua", ".tsv", ".txt"):
                files[file.relative_to(ROOT).as_posix()] = file
    for file in files.values():
        if not file.is_file():
            parser.error(f"missing build input: {file}")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with ZipFile(args.output, "w", compression=ZIP_DEFLATED, compresslevel=6) as archive:
        for name, file in files.items():
            archive.write(file, name)
        archive.writestr("Run-demo.cmd", LAUNCHER.replace("\n", "\r\n"))
    print(args.output)


if __name__ == "__main__":
    main()
