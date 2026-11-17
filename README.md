# EDOPro Simulator Lab

[日本語](docs/README.ja.md) · [Support development](https://github.com/sponsors/ranran747)

Build and test local card-game simulators on EDOPro. This developer preview contains an ocgcore source tree, an AI-vs-AI match runner, two original sample decks, and tools for assembling separately installed card packs and artwork. The existing game-specific clients use their matching card and rule packs.

## Run the sample on Windows

From PowerShell, with Visual Studio 2022 C++ Build Tools, a Windows SDK, CMake, and the shared scripts from a matching EDOPro installation:

```powershell
.\tools\run-demo.ps1 -ProjectIgnis "C:\path\to\ProjectIgnis" -Seeds 20
```

To use your existing modified Win32 ocgcore DLL, pass its directory as `-CoreDirectory`. Stock ocgcore does not provide the extra-deck extension used here. The runner requires a winner and a final count of 53 cards (50 deck + 3 AP) for both seats. Individual traces are written to `artifacts/`. The sample's code and decks are English-facing, and run without card art.

## Use an existing card pack

Open the game-specific build with its matching pack. Extract the rules and card text overlays into the parent of `runtime/`. The `*-card-text.zip` overlay holds the database and any separate card text. The `*-rules.zip` overlay holds Lua, scenarios and decks. See [profile and pack instructions](docs/PACKS.md) to generate these from an existing local project.

Optional artwork goes into `runtime/ProjectIgnis/pics` using the simulator's numeric IDs. Requires Python 3.10 or newer.

```powershell
python tools/import_images.py --runtime runtime/ProjectIgnis --local C:\path\to\your\art
python tools/import_images.py --runtime runtime/ProjectIgnis --manifest images.tsv --allow-host assets.example.org
```

The TSV is one numeric ID and one authorized direct HTTPS URL per line, separated by a tab. Existing images are preserved. [Codex prompt for importing images](docs/IMPORT_IMAGES_WITH_CODEX.md).

The English README is the default. A Japanese guide is linked above. Text and language choices in individual game builds depend on the client and card pack.

## Licensing and support

See [source and dependency notices](docs/SOURCE.md). The funding link supports maintenance of the public tooling, test fixtures and documentation. Access to source and sample decks is free.
