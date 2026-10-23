# Anime-Base

Roblox base-building and raiding game with original anime-archetype factions.

- Design: [`docs/DESIGN.md`](docs/DESIGN.md)
- Version log: [`docs/VERSIONS.md`](docs/VERSIONS.md)
- Stat template: [`docs/Stat_Template_v1.1.xlsx`](docs/Stat_Template_v1.1.xlsx)
- Working rules for Claude: [`CLAUDE.md`](CLAUDE.md)

## Setup (Windows)

Requirements: Roblox Studio, Git for Windows, Rokit, Claude Code.

```powershell
git clone https://github.com/kepz94/anime-base.git
cd anime-base
rokit install          # installs Rojo 7.7.0 from rokit.toml
rojo plugin install    # installs the matching Rojo plugin into Studio
rojo serve             # starts live sync
```

Then in Roblox Studio: open a Baseplate place, click **Rojo** on the Plugins toolbar, and press **Connect**.

Smoke test: press Play. The Output window should show:

```
[Server] Anime-Base v0.1 (Project setup) loaded
[Client] Anime-Base v0.1 (Project setup) loaded
```
