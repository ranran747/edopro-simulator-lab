# Windows Card Game Simulators — EDOPro Simulator Lab

[日本語](docs/README.ja.md) · [Download catalog](docs/DOWNLOADS.md) · [Collect card faces with Codex](docs/CODEX_IMAGE_COLLECTION.md) · [note tip](https://note.com/muutan_ai_lab/n/n615b21d388af) · [GitHub Sponsors](https://github.com/sponsors/ranran747)

Unofficial Windows simulators for ten card games. Choose a game in the [download catalog](docs/DOWNLOADS.md). The client, core, matching card/rule pack, launcher, backgrounds and card sleeves are included. **Card-face images are not distributed.** Add them locally with the common Codex collection prompt or the game-specific prompt linked in the catalog.

Extract the Windows build into a new directory and run `Start.cmd`. Card faces may show `NO IMAGE` until local artwork is added. Read the matching release notes for tested modes, decks and known limitations. [The 33-second introduction](https://www.youtube.com/watch?v=6zaFEprMObA) shows a local installation after card-face artwork was added.

## Installation, reports and source

- [Downloads and FAQ](docs/DOWNLOADS.md)
- [Japanese guide](docs/README.ja.md)
- [Pack documentation](docs/PACKS.md)
- [Issues](https://github.com/ranran747/edopro-simulator-lab/issues): game, release, card ID and reproduction steps.
- [Source/dependency notices](docs/SOURCE.md): retain upstream licenses and use the matching source archive beside each binary.

## Support development

The previews are free. [Note tips](https://note.com/muutan_ai_lab/n/n615b21d388af) and [GitHub Sponsors](https://github.com/sponsors/ranran747) support development, testing and maintenance voluntarily.

## Developer sample

The separate [command-line demo](https://github.com/ranran747/edopro-simulator-lab/releases/tag/v0.1.1) runs 20 fixed-seed AI matches with two original decks. It is distinct from game-specific Windows clients. The native core includes modified upstream ocgcore and Lua; see the source/dependency notices.
