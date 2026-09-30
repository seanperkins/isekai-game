# Damage, Armor and Levels — Design

Status: draft for debate (2026-09-29). Answers Sean's note: "I saw something that was talking about how damage and armor
work in Diablo 4 where it uses an equation to determine damage. Can you research that and see if we can improve our stats
and damage calculations based on level and stats?" Research: `docs/research/damage-formulas.md` (Diablo 4, Diablo 3, Path
of Exile, Elden Ring, Pokemon, Dragon Quest; our own code audited with file:line).

## What I understood

Sean wants damage, armor and level scaling to be a considered model instead of the simple subtraction the game uses now,
inspired by how Diablo 4 turns armor into a percentage with an equation. Success: the numbers a player sees (ATK, DEF,
level, stage, skill level, form) all matter and never hit a cliff, early play feels the same as today, and enemies can be
made stronger by biome without editing every creature.

## What Diablo 4 actually does, and what we take from it

Diablo 4 (season 13, Maxroll): `damage = weapon x skill% x main-stat x additive-bucket x product(global multipliers) x (1 -
enemy DR)`; armor turns into a percentage as `DR = armor / (armor x 10/9 + C)` with `C` growing with level (5678 at level
70); resistances use the same shape with a constant one fifth as large, and separate sources multiply. Diablo 3 used
`A / (A + 50 x attackerLevel)`. Both are **hyperbolic**: diminishing percent, no immunity, and effective HP grows linearly
with armor. Blizzard's 1.2.0 lesson is the pitfall to avoid: several separate multiplicative buckets made the best build
"stack everything", so they folded most sources into one additive bucket. Path of Exile makes armor depend on the size of the
hit (chip damage is nearly negated, big hits break through), and Elden Ring floors damage at 10% of the attack.

We have no items, no bucket zoo and no monster-level tax, so we take only: (1) DEF as a hyperbolic percent that depends on the
hit's size (Path of Exile's form), never reaching 100%; (2) resistances that combine multiplicatively and are capped; (3) a
level-derived power for enemies; (4) skills that scale with ATK instead of ignoring it.

## What is wrong today (audited)

Damage is `max(1, floor(raw x (100 - p)/100 - flat))` (`scripts/stats/damage.gd:6-8`), and DEF is a flat subtraction
(`player.gd:620-621`, `enemy.gd:189`). Consequences, each with a number:

1. DEF at or above a hit's power floors it at 1 and further DEF is wasted: Body Armor L5 (the stage-1 cap) already makes
   every creature but the unspawned serpent hit for 1.
2. ATK growth is a cliff: against the lizard (DEF 3) ATK 1 to 4 all do 1, ATK 8 does 5.
3. Skill tables ignore ATK: Water Blade is always 3 (a free tackle does more once ATK passes 3), Poison Breath is 2 to 16
   regardless of ATK, Spore Cloud a fixed 1. ATK-themed lineages never improve their own skills.
4. Any poison resistance deletes 1-point poison ticks (`Damage.tick(1, p) = 0` for every p >= 1) and every tick source is 1,
   so the resistance table L2-L12 does nothing against ticks.
5. Percent sources add and clamp at 100 (Poison Resistance L9 83% + Venom Blood 30% = 113%).
6. Enemies have no level: a stage-4 slime (124 HP) meets creatures topping out at ATK 6, and the Grotto (ATK 1-3) is weaker
   than the Cave (ATK 3-5) though it is later content.
7. DEF also cuts poison and the toad's own resistance is dead data.
8. Tackling a Mushroom Crab (HP 8, DEF 2) with a base slime does 1 a hit and never stuns from the front: eight tackles under its charges (verified by a probe: hp 7, 6, 5, 4, 3, 2, 1, 0).

## Decisions

| Topic | Decision |
|---|---|
| Armor | **DEF is physical only and hit-relative**: `armor_pct(def, power) = min(80, floor(10000 x def / (100 x def + 80 x power)))`. A DEF equal to 0.8 x the hit's power removes half of it. Small DEF reads as today (DEF 1, 2, 4 remove 20%, 33%, 50% of a 5-hit), large DEF is a slope with no plateau. Capped at 80% |
| One resolution | `Damage.hit(power, def, resist_pct, flat_off, physical)`: armor percent (physical only) and resistance percent multiply, then the flat reductions subtract, minimum 1. Player and enemy both use it. `Damage.direct_hit` and `Damage.tick` stay until their tests are carried over, then are deleted |
| Resistances | Combine multiplicatively, `combine_pct(a, b) = 100 - floor((100-a)(100-b)/100)`, hard cap 85. Poison Resistance, Venom Blood and the other percent sources go through it in `SkillEffects.damage_reduction` and `PlayerSkillSet.incoming`. The Poison Resistance table's top levels are adjusted so none is clamped away (`[20, 32, 42, 52, 60, 67, 73, 78, 81, 83, 84, 85]`; L1-L8 unchanged) |
| Poison ticks | Fractional: the tick is `raw x (100 - resist)/100` HP a second carried in thousandths (`tick_milli`), so 1 HP ticks at 20% resistance lose 0.2 HP a second instead of vanishing. `Health.take_tick` still never drops HP below 1 |
| Skills scale with ATK | A player skill's table value is amplified: `skill_power(value, atk) = max(1, floor(value x (100 + 25 x (atk - 1)) / 100))`. ATK 1 is today's table exactly. Breath L15 is 16 at ATK 1, 24 at the stage-4 base ATK 3, 44 at ATK 8. Spore Cloud's per-tick damage goes through it too. The Skills tab shows the amplified number for the player's current ATK |
| Enemy level | `Enemy.level` from the room's area plus an optional spawn `lv`: `Levels.AREA_LEVEL = {cave: 1, grotto: 6}`. An enemy's HP, ATK, DEF, its skills' stat modifiers and its spit and puff numbers are scaled by `Levels.scaled(base, level) = round(base x (100 + 8 x (level - 1)) / 100)` (0 stays 0); SPD and XP do not change. Level 1 is the identity, so the Cave keeps today's numbers and only the Grotto gets harder (level 6, x1.4) |
| Player level | Unchanged: +2 HP and +1 MP per level, stages and forms keep granting flat ATK/DEF and the skill caps. Level buys survivability; ATK and DEF come from stage, form, eating and skills |
| Enemies read their own resistances | `Enemy.receive_hit` applies `SkillEffects.damage_reduction` for the enemy's own skills (the toad's Poison Resistance L2 finally does something), and DEF only against physical hits |
| Weak points | **Shipped separately** (the reported Mushroom Crab problem): a tackle from behind, or on an armored enemy that is already stunned, ignores DEF and does double (`Enemy.WEAK_POINT_MULT`). It is restricted to armored enemies because doubling every backstab kills a bat (HP 2) instead of stunning it for the eat. Diablo 4's Vulnerable idea, in our scale. This spec keeps it as it is |
| Nothing hidden | Every constant is a named `const` in `Damage` or `Levels`; there is no monster-level damage tax on the player and no hidden curve |

## Formulas (GDScript-ready)

```gdscript
# scripts/stats/damage.gd (added)
const ARMOR_PER_HIT := 80
const ARMOR_CAP := 80
const RESIST_CAP := 85
const SKILL_ATK_PCT := 25
static func skill_power(value: int, atk: int) -> int:
	return maxi(1, floori(float(value * (100 + SKILL_ATK_PCT * (maxi(atk, 1) - 1))) / 100.0))
static func armor_pct(defense: int, power: int) -> int:
	if defense <= 0 or power <= 0:
		return 0
	return mini(ARMOR_CAP, floori(10000.0 * defense / (100 * defense + ARMOR_PER_HIT * power)))
static func hit(power: int, defense: int, resist_pct: int, flat_off: int, physical: bool) -> int:
	var through := (100 - (armor_pct(defense, power) if physical else 0)) * (100 - clampi(resist_pct, 0, RESIST_CAP))
	return maxi(1, floori(float(power * through) / 10000.0) - flat_off)
static func combine_pct(a: int, b: int) -> int:
	return 100 - floori(float((100 - a) * (100 - b)) / 100.0)
static func tick_milli(raw: int, resist_pct: int) -> int:  # thousandths of an HP per second
	return raw * (100 - clampi(resist_pct, 0, RESIST_CAP)) * 10

# scripts/stats/levels.gd (new)
class_name Levels
const POWER_PCT_PER_LEVEL := 8
const AREA_LEVEL := {"cave": 1, "grotto": 6}
static func power_pct(level: int) -> int:
	return 100 + POWER_PCT_PER_LEVEL * (maxi(level, 1) - 1)
static func scaled(base: int, level: int) -> int:
	return floori(float(base * power_pct(level) + 50) / 100.0)
static func for_spawn(area: String, spawn: Dictionary) -> int:
	return int(AREA_LEVEL.get(area, 1)) + int(spawn.get("lv", 0))
```

Call sites: `Player.receive_hit` (DEF leaves `flat_off` and enters `hit` as `defense`, physical only), `Player.tick` and
`receive_poison` (the fractional tick), `Enemy.receive_hit` (its resistances; DEF physical only), a new `Enemy.set_level`
called by `RoomBuilder` after spawn beside `spawn_key`, `Ability.hit_power()` (`skill_power(value(), atk)`, with ATK 1 for
an actor without stats, so stub-actor tests are unchanged) used by Poison Breath, Water Blade and the new evolutions,
`SporeCloud` / `SporeCloudArea` (per-tick damage), `SkillEffects.damage_reduction` and `PlayerSkillSet.incoming`
(`combine_pct`), `SkillScreenModel.effect_lines` (the amplified value).

## Before and after (real path for "before")

The grid ATK 1..5 x DEF 0..3 matches the old model in 19 of 20 cells (ATK 4 vs DEF 3 goes 1 to 2). Every DEF-0 hit is
identical, and a fresh slime plus the Cave keep today's numbers.

| Hit | Before | After |
|---|---|---|
| Level-1 tackle vs toad (HP 3) | 1 | 1 |
| Lizard (ATK 5) vs slime DEF 5 | 1 | 2 (armor 55%) |
| Lizard vs slime DEF 2 | 3 | 3 |
| Bat (ATK 3) vs DEF 0 | 3 | 3 |
| Serpent (ATK 6) vs DEF 1 | 5 | 4 |
| Toad ticks vs Poison Resistance L1, 3 s | 0 HP | 2 HP |
| Poison Breath L1, ATK 1 vs lizard | 1 | 2 (poison ignores armor) |
| Water Blade, ATK 5 vs lizard | 1 | 3 |
| Tackle ATK 4 vs lizard | 1 | 2 |
| Poison Breath L15, ATK 8 | 16 | 44 |
| Level-28 lizard (ATK 16) vs stage-4 slime DEF 14 | 2 | 7 |

## Failure modes and edge cases

- Integer resolution: with ATK at most 6 the curve changes little at low levels; it pays off once enemy ATK is 16+. If it
  feels coarse, multiply all HP and damage by 10 later; nothing in the formulas assumes the scale.
- Out-levelling is intended: a stage-4 slime (DEF 14) takes 1 from Cave lizards forever. Whether a biome gates is an
  `AREA_LEVEL` and `lv` decision, not a formula cliff.
- Skills now grow with ATK: a maxed stage-4 build one-shots a level-28 crab (HP 25). `SKILL_ATK_PCT` is the knob.
- A skill used by an actor with no `stats` (test stubs, enemies using the tables) uses ATK 1, so nothing changes for them.
- Body Armor no longer helps against poison (DEF is physical); Poison Resistance now reaches ticks. Both are called out in
  the skill descriptions.
- An enemy created without a room (tests) has level 1: `setup()` works at its roughly 67 existing call sites unchanged.
- `spawn.lv` missing or 0 means the area level.

## Testing

New `tests/test_damage.gd`: identity (`hit(p, 0, 0, 0, true) == p`), `armor_pct(4, 5) == 50`, the cap, monotone in DEF and
decreasing in hit size, a property loop (hit 1..60, DEF 0..80: result >= 1, non-increasing in DEF, `hit(40, 30, ...) == 20`
with no plateau), the 20-cell legacy grid with its one difference, poison ignores DEF, `combine_pct(20, 30) == 44` and the
85 cap, `tick_milli(1, 20) == 800` and a `Player.tick` test that 3 s at 20% costs 2 HP, `Levels` (`power_pct` 100/140/316/388,
`scaled(8, 6) == 11`, `scaled(0, n) == 0`, `for_spawn`), a level-6 crab (HP 11, ATK 3, DEF 3), `skill_power(v, 1) == v` for
every Breath value, `skill_power(16, 8) == 44`. Existing pins that stay green because level 1 and ATK 1 are the identity:
`test_stats.gd:47-58`, `test_player.gd:114-128`, `test_enemy.gd:20,29-30`, `test_tuning.gd:54-60`, `test_levels.gd:75-82`,
`test_player_skill_set.gd:43-46`, `test_skill_effects.gd:28-33`, the enemy traces. New pins for the Grotto's level and for the
Skills tab showing the amplified value.

## Rulings I made

1. **Hit-relative hyperbolic armor** (Path of Exile's form) rather than level-relative (Diablo 3/4's), because our enemies'
   level enters through their stats, so a level term in the armor constant would double-count it. Cost if wrong: one constant
   and one function.
2. **DEF physical only, resistance for poison**, as Blizzard did in 1.2.0. Cost if wrong: Body Armor no longer helps against
   toads; a poison source can be given DEF back with a flag.
3. **Only the Grotto is levelled up (6)**; the Cave stays level 1 so early play is unchanged. Cost if wrong: an `AREA_LEVEL`
   number.
4. **ATK amplifies skills by 25% per point above 1.** It makes ATK lineages matter and is one constant. Cost if wrong:
   playtest tuning.
5. **XP stays flat** per creature; a level term is a follow-up once levels ship.
6. **No Diablo bucket taxonomy, no Overpower, no Fortify, no monster-level damage tax.** One additive stat bucket and named
   constants are enough for a game with no items.

## Not here

Per-creature XP scaling by level, a dodge or block stat, damage types beyond physical and poison, an item system, changing
player level rewards, and the new areas' `AREA_LEVEL` rows (added with each area).
