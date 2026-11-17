# Source and dependency notices

- The native engine includes modified [edo9300/ygopro-core at 158aebe758be3c46249c75d602e3f16d63d2ef31](https://github.com/edo9300/ygopro-core/tree/158aebe758be3c46249c75d602e3f16d63d2ef31) source. The project-specific changes add a per-duel option for using the Extra Deck for other resources plus bench and card-state management. See [engine notices](../native/ocgcore/LICENSE) and [AGPL text](../COPYING).
- [Lua at 1ab3208a1fceb12fca8f24ba57d6e13c5bff15e3](https://github.com/lua/lua/tree/1ab3208a1fceb12fca8f24ba57d6e13c5bff15e3) is included in the native tree. Its notice is in [lua.h](../native/ocgcore/lua/src/lua.h).
- In this repository the shared simulator tools, original sample content and Lua rule engine are provided under AGPL-3.0-or-later. Existing upstream notices govern upstream files.
- The shared EDOPro scripts for the runner come from the user's matching local [Project Ignis installation](https://github.com/edo9300/edopro), or a matching [CardScripts revision](https://github.com/ProjectIgnis/CardScripts).
- EDOPro and the game names are used to describe compatibility. This project is independently maintained.
