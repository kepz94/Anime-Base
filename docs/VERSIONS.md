# Version log

Build versions track the code. Design versions track `docs/DESIGN.md`.

| Build | Date | Design | Summary |
|---|---|---|---|
| v0.1 | 2026-10-23 | v2.3 | Project setup: Rojo 7.7.0 project (pinned via Rokit), `src/` layout, server/client sync smoke test, design doc, CLAUDE.md working rules, Stat Template v1.1. No game logic. |
| v0.2 | 2026-10-23 | v2.3 | Data layer: Stat Template v1.2 (adds Buildings + Building Levels tabs: Town Hall, Collector, Storage, Market, Army Camp, Builder Hut, Hero Hall, Laboratory, Barracks, Wall; all values empty). Converter `tools/stat_converter.py` (Python + openpyxl 3.1.5; run `python tools/stat_converter.py`) generates `src/shared/Config/Schema.luau` and `src/shared/Config/Data/*.luau`; enum values come from the template's dropdown lists. `src/shared/Config/Validate.luau` + `src/server/ConfigCheck.server.luau` validate the config at server start (types, enums, ID format and faction code, duplicates, references, per-building-type columns). Structure only, no stat values. |

## Planned build order (vertical slice)

| Build | Scope |
|---|---|
| v0.1 | Project setup |
| v0.2 | Data layer: stat config modules + Stat Template converter |
| v0.3 | Base: grid placement, Town Hall, builders, upgrade timers, collectors, storage, Market sell limit, saving |
| v0.4 | Battle: scouting phase, deploy zones, troop targeting, defenses, traps, stars/destruction, loot caps |
| v0.5 | Multiplayer: offline raids against saved bases, matchmaking by Town Hall, shields, Revenge |
| v0.6 | Faction content: Ninja + Ki Warriors troops, defenses, heroes with elements |
| v0.7 | Weather, Mutations, Awakenings |
| v0.8 | UI and art pass |
