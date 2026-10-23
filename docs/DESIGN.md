# Anime-Base — Game Design

**Active design version: v2.4**
**Scope: vertical slice — Ninja + Ki Warriors (2 of 5 factions)**

This document is the locked design. Rules here change only on an explicit decision by the owner. Every change gets a new version number and an entry in `docs/VERSIONS.md`.

---

## 1. Governing rules

### 1.1 Mirror rule
Any mechanic that Clash of Clans has is copied as-is. Only mechanics Clash of Clans does **not** have are designed fresh, and each one is decided explicitly by the owner.

### 1.2 Zero-assumption rule
If a rule is missing or ambiguous, stop and ask. Do not fill gaps with "standard" practice. Values marked **TBD** stay TBD until decided.

### 1.3 Original IP only
All names, characters, and designs are original archetypes. Faction sources below describe the *style* only. Using names, characters, or signature designs from Naruto, Dragon Ball, Demon Slayer, Jujutsu Kaisen, or My Hero Academia is not allowed (Roblox removes games over copyright claims).

---

## 2. Core loop (Clash of Clans structure)

Build a base → collect resources → train troops → raid other players' offline bases → defend → upgrade on timers.

---

## 3. Factions

Five mechanical factions. Each has its own buildings, defenses, characters, and stats.

| # | Faction | Style source | In vertical slice |
|---|---|---|---|
| 1 | Ki Warriors | DBZ-style | **Yes** |
| 2 | Ninja | Naruto-style | **Yes** |
| 3 | Devil Hunters | Demon Slayer-style | No |
| 4 | Sorcerers | JJK-style | No |
| 5 | Heroes | MHA-style | No |

**Faction rules**
- Town Hall starts at level 0 on faction selection.
- Switching factions is allowed and resets Town Hall to 0.
- **Town Hall 0** (v2.4) is the state right after faction selection: the player owns a level 0 Town Hall and nothing else. Upgrading 0 → 1 costs 0 Coins, takes 0 time, and happens automatically. Switching factions returns the player to this state.
- **Starting kit** (v2.4, test values), granted at Town Hall 0 → 1: 2 Builder Huts and Market level 1 (both placed free), and 1,500 Coins.
- Every faction has heroes across multiple elements, so no faction is weak in any weather.
- Characters, buildings, and slots unlock by Town Hall level (mirror).
- Heroes both defend and raid.

---

## 4. Elements and weather

**Elements (4):** Fire ↔ Water, Lightning ↔ Shadow. Every hero has exactly one element. There is no Neutral element.

**Weather (4):**

| Weather | Boosts | Debuffs |
|---|---|---|
| Rain | Water | Fire |
| Solar Eclipse | Fire | Water |
| Thunderstorm | Lightning | Shadow |
| Blood Moon | Shadow | Lightning |

**TBD:** weather frequency and duration per weather type.

---

## 5. Mutations and Awakenings (two separate systems)

| System | Target | Earned by | Effect |
|---|---|---|---|
| Mutations | Base buildings, defenses, collectors | Weather occurring while the player is at their base | Permanent; increases the building's coin sell value |
| Awakenings | Heroes only (not regular troops) | A successful raid with an element-matched hero during that element's boosting weather | 10 leveled tiers |

- Weather while at base → Mutations land on the base.
- Weather while raiding → Awakenings land on heroes.
- Both sides' permanent effects apply in every raid: attacker's hero Awakenings + defender's base Mutations, whether the defender is online or offline.
- A building can stack multiple Mutations (all count toward sell value). The player marks **one** as active; the active Mutation gives a defense bonus during raids. Each weather's Mutation gives a different defense bonus (**TBD:** bonus values per weather).
- "Successful raid" = at least 1 star (mirror).

**Awakening curve** (successful matched raids needed per tier):

| Tier | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | Total |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Raids | 1 | 2 | 2 | 3 | 8 | 12 | 18 | 26 | 36 | 50 | 158 |

To be retuned once weather frequency is set.

---

## 6. Economy

- **Coins** are the single currency and buy everything.
- **Building rarity tier** is chosen by the player at purchase; higher tiers cost more. Mutations never change tier.
- **Resources** (shared across all factions; collectors are visually themed per faction):

| Resource | Value | Unlock | CoC analogue |
|---|---|---|---|
| Ore | Low | Town Hall 1 | Gold |
| Essence | Medium | Town Hall 1 | Elixir |
| Relic Shards | High | Town Hall 7 | Dark Elixir |

- Resources are farmed, then sold for Coins at the **Market** building.
- The Market has a per-cycle sell limit that grows with Market upgrades (prevents instant-selling from making raids worthless). Rules (v2.4, test values):
  - The limit resets daily at 00:00 UTC, at the same time for everyone.
  - Market level N requires Town Hall N.
  - Limit at Market level N = the Coin value (at the sell prices) of the total Ore + Essence storage capacity available at Town Hall N: the maximum number of storages at their maximum level for Town Hall N, plus the Town Hall's own storage if Clash of Clans gives it one at that level.
  - Footprint 3x3, 1 Market per Town Hall level. Market level N uses the hitpoints, upgrade time, and Coin cost of the highest Essence Storage level available at Town Hall N. Market level 1 is placed free (starting kit).
- **Sell prices** (v2.4, test values): 1 Ore = 1 Coin, 1 Essence = 2 Coins. Relic Shards: **TBD** (they unlock at Town Hall 7).
- **Coin prices** (v2.4, test values): a building's Coin cost = its Clash of Clans build cost × the sell price of the matching resource (Gold → Ore, Elixir → Essence). These are base-tier prices; **TBD:** how the rarity tier is selected and the price multiplier per tier.
- Raids steal **unsold** resources from collectors and storage. Coins are not lootable.

---

## 7. Battle rules (mirrored from Clash of Clans)

### 7.1 Battle flow
- 30-second scouting phase, then a 3-minute attack phase.
- Battle ends on surrender, timer expiry, or 100% destruction.
- Every building has a no-deploy zone around it. Traps have none (troops can be deployed on top of traps).
- Buildings are never lost; the base rebuilds after an attack. Only resources are taken.

### 7.2 Stars and destruction
- 1 star: Town Hall destroyed.
- 2 stars: 50% destruction.
- 3 stars: 100% destruction.
- Walls do not count toward destruction % and are not required for 100%.

### 7.3 Troop targeting
- Each troop has a preferred target: None, Defenses, Resources, or Walls.
- Once all its preferred targets are destroyed, a troop attacks the nearest building of any type.
- A troop does not switch to enemy units until its current target is destroyed.
- Preferred-target troops ignore defending Clan Castle units until their preferred targets are destroyed.
- Wall-targeting troops only target walls that fully or partially enclose a building, never a standalone wall segment.

### 7.4 Defenses
- Each defense has a fixed target domain: Ground, Air, or Ground+Air.
- Attack types: single-target, splash, chain, multi-target.
- Some defenses have a minimum-range blind spot.
- Some defenses have player-set modes (e.g. single vs multi-target; ground-only vs ground+air with reduced range).
- A defense under upgrade does not fire.
- Clan Castle units deploy when an enemy enters the trigger radius.

### 7.5 Traps
- Hidden until triggered.
- Re-arm automatically and for free when the owner logs in. An un-re-armed trap is absent from the next battle.
- Placing and re-arming traps does not need a builder; upgrading does.

### 7.6 Village rules
- Each builder works on one building at a time.
- All available buildings must be placed before upgrading the Town Hall.
- That rule counts only buildings that exist in the Stat Template at that Town Hall level (v2.4). Defenses join once the rosters are decided.
- Builders (v2.4): the slice starts with 2 builders, from the 2 Builder Huts in the starting kit (Clash of Clans default). Extra builders are not purchasable; **TBD:** how extra builders are priced.

### 7.7 Heroes (mirror)
- Hero Hall level caps every hero's maximum level.
- Hero slots are tied to Hero Hall level.
- Each hero equips 2 pieces of equipment.
- A hero under upgrade cannot be used to attack.
- No hero recovery time; troop training is instant and free (Clash Anytime, March 2025). Army Camp space is the only limit.

---

## 8. Multiplayer rules (v2.3)

### 8.1 Battle modes
- Regular Battles only in the vertical slice.
- Ranked Battles are deferred to a later version.

### 8.2 Shields
- 8-hour shield after the base is attacked. Attacking does not shorten it.
- Shields are purchasable in the shop with Coins:

| Shield | Cooldown | Coin price |
|---|---|---|
| 1 day | 4 days | TBD |
| 2 days | 7 days | TBD |
| 1 week | 35 days | TBD |

- No Village Guard (removed in Clash of Clans' October 2025 rework).

### 8.3 Revenge
- 12-hour window to Revenge a player who took a significant amount of resources.
- Fought against a shadow copy of their base; the real player is not attacked.
- Works even if the target is shielded.
- The shadow base holds at least the resources that were taken.

### 8.4 Loot

| Source | Lootable |
|---|---|
| Ore / Essence collectors | Up to 50% of unsold resources |
| Relic Shard collectors | Up to 75% of unsold resources |
| Storage | % capped by defender's Town Hall level — **values TBD** |
| Town Hall gap | Penalty vs lower Town Halls, bonus vs higher — **values TBD** |
| Defender loot cart | Defender gets back 10% of what was stolen |
| Coins | Not lootable |

---

## 9. Content data

Unit, hero, defense, and trap stats are defined in `docs/Stat_Template_v1.3.xlsx` (one row per unit/defense/trap, per-level numbers on the Levels tabs). Game code reads stats from config modules generated from this template; balance changes never require logic changes.

Building values for Town Hall 1–3 mirror Clash of Clans (source cited in each cell comment); both factions currently have identical values. Rows holding test values are marked Value status = Test. Economy settings (sell prices, Market reset, starting kit) are on the Economy tab. (v2.4)

---

## 10. Open items

| Item | Needed for |
|---|---|
| Weather schedule (frequency, duration per type) | Awakening curve retune, Mutation rates |
| Mutation defense bonus values per weather | Battle balance |
| Relic Shard sell price | Economy (Town Hall 7) |
| Extra builder pricing | Economy |
| Rarity tier selection and price multiplier per tier | Economy |
| Clan Castle, Spell Factory, Blacksmith in the vertical slice | Scope |
| Storage loot % and caps per Town Hall | Economy |
| Town Hall gap loot penalty/bonus values | Economy |
| Shield Coin prices | Economy |
| Ninja and Ki Warriors rosters (troops, heroes, defenses, traps) | Content |
