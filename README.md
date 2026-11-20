# Windows Card Game Simulators — EDOPro Simulator Lab

[日本語](docs/README.ja.md) · [Download catalog / 配布一覧](docs/DOWNLOADS.md) · [note tip](https://note.com/muutan_ai_lab/n/n615b21d388af) · [GitHub Sponsors](https://github.com/sponsors/ranran747)

Unofficial Windows simulators for Duel Masters, ONE PIECE Card Game, Dragon Ball Fusion World, Gundam Card Game, Pokémon TCG, Pokémon TCG Pocket, UNION ARENA, Detective Conan TCG, Palworld OCG and Cyberpunk TCG.

## Download and play

Start with the [game-specific download catalog](docs/DOWNLOADS.md). It links each Windows build, installation guide and setup kit. A **Windows build** contains the client, core and matching card/rule pack. A **setup kit** provides launch/artwork tools for an existing installation and cannot start a match by itself.

Extract a Windows build into a new directory and run `Start.cmd`. Read that release's notes for tested modes, included decks, card-art coverage and known limitations. AI matches are one of the simulator features; the available modes depend on the game and release.

## Installation, support and source

- [Downloads and FAQ](docs/DOWNLOADS.md): Windows downloads, game names, installation, reports and source links.
- [Japanese guide](docs/README.ja.md): Windows setup and the difference between full builds and helper kits.
- [Pack documentation](docs/PACKS.md): database and Lua overlays for existing installations.
- [Issues](https://github.com/ranran747/edopro-simulator-lab/issues): include game, release, card ID and reproduction steps.
- [Source/dependency notices](docs/SOURCE.md): upstream licenses. Matching source archives are provided beside binary releases.

## Support development

The public previews are free. [Tip through the note article](https://note.com/muutan_ai_lab/n/n615b21d388af) or use [GitHub Sponsors](https://github.com/sponsors/ranran747) to support development, testing and maintenance. The amount is optional; game names describe compatibility with this independently maintained project.

## Developer sample

The separate [command-line demo](https://github.com/ranran747/edopro-simulator-lab/releases/tag/v0.1.1) runs 20 fixed-seed AI matches using two original decks and writes traces to `artifacts/`. It is distinct from the game-specific Windows clients.

To build that sample from source, install Visual Studio 2022 C++ Build Tools, Windows SDK and CMake, then run:

```powershell
.\tools\run-demo.ps1 -Seeds 20
```

The shared core includes modified upstream ocgcore and Lua. See [source and dependency notices](docs/SOURCE.md).
