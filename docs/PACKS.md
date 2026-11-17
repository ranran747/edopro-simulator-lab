# Game profiles and local pack overlays

The pack tools support these local project layouts.

| Profile | Card database |
| --- | --- |
| `conan` | `conan.cdb` |
| `cyberpunk` | `cyberpunk.cdb` |
| `dragonball` | `dragonball.cdb` |
| `duelmasters` | `duelmasters.cdb` |
| `gundam` | `gundam.cdb` |
| `onepiece` | `onepiece.cdb` |
| `palworld` | `palworld.cdb` |
| `pokemon` | `pokemon-demo.cdb` |
| `pokepoke` | `pokepoke.cdb` |
| `unionarena` | `unionarena.cdb` |

Export from an existing project after its pack build and local install have completed. The value of `--project` is the directory containing `pack/` and `runtime/`. The rules ZIP also includes per-card Lua generated in the installed runtime for IDs in that pack's database.

```powershell
python tools/export_local_pack.py unionarena --project C:\path\to\edopro-unionarena --output dist
```

Extract both ZIPs at the root of a copy of the matching game project. The runtime needs the matching modified client, core, configuration, and shared EDOPro scripts. Database and scripting versions must match. Optional images can be imported after extraction. Use a new copy when switching pack versions. Treat Lua as executable code and install packs from sources you trust.

The table lists recognized local layouts. Availability of packs and clients is determined by their maintainers. The GitHub preview itself provides the shared tools and original sample data.
