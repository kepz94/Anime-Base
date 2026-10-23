# CLAUDE.md — Anime-Base

Roblox base-building/raiding game (Clash of Clans structure, original anime-archetype factions).
Design: `docs/DESIGN.md` (active version listed at its top). Version log: `docs/VERSIONS.md`.

## Dev Hub (every session)

- **Start of session:** call Dev Hub `get_context` with slug `anime-base` before any other work. It serves the SRD, Working Agreements, Architecture, open decisions, and recent session logs.
- **End of session:** call Dev Hub `add_session_log` for `anime-base` covering what was done, where it stopped, and what's next.
- When an open decision is answered by the owner, record it with `resolve_decision`.
- When `docs/DESIGN.md` or this file changes, update the matching Dev Hub doc (`srd` or `agreements`) so both stay in sync.

## Owner's coding principles (mandatory)

1. **Cumulative architecture (add, never subtract).** Treat existing code as a fixed foundation. All changes are additive (extensions, new modules, new layers). Do not remove, refactor out, or alter existing structural logic unless explicitly told to.
2. **Upstream grounding (GitHub first).** Before writing, suggesting, or reviewing code, read the current state of the repository. Never assume functions or past iterations exist without verifying them in the repo.
3. **Absolute context preservation.** Keep system variables, states, and frameworks consistent across sessions. Never change defaults, thresholds, or baseline logic without explicit instruction.
4. **Zero-assumption fidelity.** Work only from literal requirements. If a requirement is ambiguous or conflicts with the existing design, stop and ask. Do not apply outside "standard" practices that deviate from the design.
5. **Deterministic logic mapping.** Code follows exact mathematical and conditional mappings. In every conditional hierarchy, handle every branch explicitly. No dead ends, no unhandled edge cases.
6. **Scope restraint and isolation.** Changes are tightly scoped and modular, so features can be toggled or updated without destabilizing other systems.
7. **Explicit version branding.** Every iteration is tagged with an explicit version (e.g. v0.2). Reference the active version in all discussion. Update `src/shared/Version.luau` and `docs/VERSIONS.md`, and create a matching git tag.
8. **Structural layout consistency.** UI, dashboards, and notifications follow the designated layouts exactly (column order, color coding, priorities). Never reorganize visual presentation unprompted.
9. **Exact diagnostic tracking.** Every state change has a traceable path showing which condition triggered it.
10. **Direct technical execution.** Deliver solutions cleanly and directly. No filler or conceptual explanation unless asked.

- **Vocabulary restraint:** use technical, structural, logical terms only.
- **"Do not touch" default:** if it's unclear whether an existing component should change, leave it unchanged and ask.

## Design rules

- **Mirror rule:** any mechanic Clash of Clans has is copied as-is. Only non-CoC mechanics are designed fresh, and only on explicit owner decision.
- **Original IP only:** no names, characters, or signature designs from existing anime or games.
- Values marked **TBD** in `docs/DESIGN.md` stay TBD until the owner decides. Do not invent them.

## Toolchain

- **GitHub is the source of truth for all code.** Repo: `kepz94/Anime-Base`.
- **Rojo 7.7.0** (pinned in `rokit.toml`) syncs `src/` into Studio:
  - `src/shared` → `ReplicatedStorage.Shared`
  - `src/server` → `ServerScriptService.Server`
  - `src/client` → `StarterPlayer.StarterPlayerScripts.Client`
- File types: `*.server.luau` = Script, `*.client.luau` = LocalScript, `*.luau` = ModuleScript.
- **Roblox Studio MCP** (built into Studio) is used for playtesting, reading console output, inspecting instances, and running test Luau.

### Hard rules for the Rojo + MCP split
- **All code edits go through files in this repo.** Never edit a Rojo-managed script through the Studio MCP (`multi_edit`), because Rojo overwrites it.
- Non-code world content (models, terrain, parts built in Studio) lives in the place file and is versioned by Roblox's place version history, not Git. Place files are git-ignored.
- The place file is saved locally as `Anime-Base.rbxl` in the repo folder (git-ignored).
- The game is saved to Roblox as a **private** game (owner, 2026-10-23), with Studio Access to API Services enabled so real DataStores work. **Releasing it to the public requires the owner's explicit instruction.**
- Studio testing uses the **same DataStores as the live game**. A separate test copy of the game is needed before public release.
- After each tested phase: commit, push, and tag the version in Git.
- Saving the place is not needed after code changes: Rojo restores all code on connect. Only if Studio-built content (models, terrain) is added, flag once that the place needs saving.

## Working loop

1. Pull Dev Hub context, then read the relevant current code and `docs/DESIGN.md`.
2. Make the scoped, additive change in `src/`.
3. Confirm Rojo has synced it into Studio.
4. Playtest through the Studio MCP and read the console output.
5. Fix until clean, then commit, push, and tag. Do not release the game to the public.
6. Write the Dev Hub session log.
