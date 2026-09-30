# Damage, Armor and Levels — Design

Status: revised after round 1 of the debate (2026-09-29). Answers Sean's note: "I saw something that was talking about how
damage and armor work in Diablo 4 where it uses an equation to determine damage. Can you research that and see if we can
improve our stats and damage calculations based on level and stats?" Research: `docs/research/damage-formulas.md` (Diablo
4, Diablo 3, Path of Exile, Elden Ring, Pokemon, Dragon Quest; our own code audited).

## What I understood

Sean wants damage, armor and level scaling to be a considered model instead of the flat subtraction the game uses now,
inspired by how Diablo 4 turns armor into a percentage with an equation. Success, stated to match what this spec
actually delivers:

- DEF stops being a cliff: a big hit is reduced by a percentage that never reaches 100%, and DEF beyond a hit's size still
  helps a little instead of being wasted.
- ATK matters to skills as well as tackles: a skill's damage grows with the player's ATK.
- Poison resistance reaches poison ticks, and stacked resistance percentages cannot exceed a cap.
- Creatures carry a **level**, and their numbers are derived from it by one formula, so a later area is stronger by data,
  not by hand-editing each creature. Appraisal and the Bestiary show the level and the real numbers.
- **A slime with DEF 0 and no resistance keeps today's numbers everywhere.** Armoured slimes and poisoned slimes change in
  a short, listed set of cases (below); those are accepted, not hidden.

What it does not do: at the game's integer scale (ATK at most 6, hits of 1-6) a percentage of a small hit still rounds to
whole HP, so the ATK 1 to 3 vs high DEF cliff mostly remains. A x10 HP and damage scale would remove it; that is its own
spec because it touches every number and test.

## What Diablo 4 actually does, and what we take from it

Diablo 4 (season 13, Maxroll): `damage = weapon x skill% x main-stat x additive-bucket x product(global multipliers) x (1 -
enemy DR)`; armor turns into a percentage as `DR = armor / (armor x 10/9 + C)` with `C` growing with level; resistances use
the same shape with a smaller constant, and separate sources multiply. Diablo 3 used `A / (A + 50 x attackerLevel)`. Both
are **hyperbolic**: diminishing percent, no immunity. Path of Exile makes armor depend on the size of the hit. (The Diablo
constants are from third-party write-ups and unverified; the design does not depend on them.)

We have no items and no bucket zoo, so we take: (1) DEF as a hyperbolic percent relative to the hit's size (Path of Exile's
form), (2) resistances clamped so they cannot reach 100%, (3) a level-derived power for creatures, (4) skills that scale
with ATK.

## What is wrong today (audited; find code by symbol, line numbers drift)

Damage is `max(1, floor(raw x (100 - p)/100 - flat))` in `Damage.direct_hit` (`scripts/stats/damage.gd`), and DEF is a flat
subtraction in `Player.receive_hit` and `Enemy.receive_hit`. Consequences:

1. DEF at or above a hit's power floors it at 1 and further DEF is wasted: Body Armor L5 (the stage-1 cap) already makes
   every hit from ATK 5 or less do 1.
2. ATK growth is a cliff against armour: the lizard (DEF 3) takes 1 from ATK 1 to 4.
3. Skill tables ignore ATK: Water Blade is always 3, Poison Breath is 2 to 16 by skill level only, the clouds a fixed 1.
4. Any poison resistance deletes 1-point poison ticks (`Damage.tick(1, p) = 0` for every p >= 1), and every tick source is
   1, so the resistance table does nothing against ticks.
5. Percent sources add and clamp at 100 (Poison Resistance L9 83% + Venom Blood 30% = 113%).
6. Creatures have no level; the Grotto (later content, ATK 1-3) is weaker than the Cave (ATK 3-5).
7. DEF also cuts poison damage (a stat that should be for physical hits).

(The reported "I cannot tackle a mushroom" problem shipped separately: `Enemy.WEAK_POINT_MULT`, a tackle from behind or on a
stunned armoured enemy ignores DEF and does double. This spec keeps it exactly.)

## Decisions

| Topic | Decision |
|---|---|
| One resolution | `Damage.hit(power, damage_type, defense, resist_pct, flat_off) -> int`: DEF becomes an armor percent **only for `"physical"`**; resistance percent (clamped at `RESIST_CAP` 95) applies to any type; the two multiply; the flat reductions subtract; minimum 1. Player and enemy both call it; `Damage.direct_hit` and `Damage.tick` are **deleted in the same change** and their nine pins in `tests/test_stats.gd` are ported to `hit` and `tick_milli` |
| Armor | `armor_pct(def, power) = floor(10000 x def / (100 x def + 80 x power))` for `def, power > 0`, else 0. No cap: it is below 100 for every finite DEF, and the minimum-1 rule is the only floor. A DEF equal to 0.8 x the hit's power removes half of it |
| Weak point | `Enemy.receive_hit(raw, damage_type, from, cause, ignore_def := false)` keeps its signature: when `ignore_def` the defense passed to `hit` is 0 (resistance still applies). The double-damage tackle is unchanged |
| Resistances | Additive, as today, but clamped at `RESIST_CAP := 95` inside `hit` and `tick_milli` (above the Poison Resistance table's maximum of 92, so the shipped table is not edited and stays honest on the Skills tab). No `combine_pct`: multiplicative stacking is a design taste, not a fix, and only two poison sources exist |
| Poison ticks | Fractional: `tick_milli(raw, resist_pct) = raw x (100 - clamp(resist, 0, 95)) x MILLI / 100` thousandths of an HP per second (`MILLI := 1000`), carried in a persistent `Player._poison_milli` and **not reset by a new application** (only on death or a new life), so a 3 s toad tick at 67% resistance costs its 0.99 HP over three spits rather than 0 forever. `receive_poison` keeps whole-HP arguments (`SPIT_TICK` stays 1). `Health.take_tick` still never drops HP below 1 |
| Skills scale with ATK | `Damage.skill_power(value, atk) = 0 if value <= 0 else max(1, floor(value x (100 + 25 x (max(atk, 1) - 1)) / 100))`. ATK 1 is today's table for every value including 0. Applied to the **damaging** abilities only: Poison Breath, Water Blade, Venom Bolt (their direct hit), and the damage the poison clouds pass to `SporeCloudArea` (Spore Cloud, Miasma's cloud, Puffball, via the `damage` option **at the ability, never inside `SporeCloudArea`**, so Healing Spores and Binding Web keep damage 0). An actor without `stats` (test stubs) uses ATK 1. The Skills tab shows the amplified number for the player's ATK on the lines labelled "Damage" only (radius, distance and hold lines are not amplified) |
| Creature level | New `CreatureDef.level: int` (default 1, validated >= 1). `tools/build_content.gd` keeps each creature's hand-written base numbers and writes the generated `.tres` with `max_hp`, `atk` and `def` scaled by `CreatureScale.scaled(base, level) = floor((base x (100 + 8 x (level - 1)) + 50) / 100)` (0 stays 0, level 1 is the identity); SPD, XP, skill values and the spit and puff numbers are not scaled. The Cave creatures are level 1 (unchanged); the Grotto creatures are **level 4** (x1.24). `CompendiumModel.creature_report`, the Bestiary card and the appraisal show `Lv N` and the baked numbers, so what is shown is what is fought. There is no runtime level plumbing: `Enemy`, `RoomBuilder`, `Game._spawn` and `SporePuff` are untouched |
| Player level | Unchanged: +2 HP and +1 MP per level; stages and forms keep granting flat ATK/DEF and the skill caps |
| Deferred | Enemies reading their own resistances (the toad's Poison Resistance L2 stays dead data; turning it on is a Cave nerf to Poison Breath 2 to 1 and needs its own decision), combine_pct, per-creature XP by level, and the x10 scale |

## Formulas (GDScript-ready)

```gdscript
# scripts/stats/damage.gd (Damage.direct_hit and Damage.tick are removed)
const ARMOR_PER_HIT := 80
const RESIST_CAP := 95
const SKILL_ATK_PCT := 25
const MILLI := 1000
static func armor_pct(defense: int, power: int) -> int:
	if defense <= 0 or power <= 0:
		return 0
	return floori(10000.0 * defense / (100 * defense + ARMOR_PER_HIT * power))
static func hit(power: int, damage_type: String, defense: int, resist_pct: int, flat_off: int) -> int:
	var armor := armor_pct(defense, power) if damage_type == "physical" else 0
	var through := (100 - armor) * (100 - clampi(resist_pct, 0, RESIST_CAP))
	return maxi(1, floori(float(power * through) / 10000.0) - flat_off)
static func tick_milli(raw: int, resist_pct: int) -> int:  # thousandths of an HP per second
	return raw * (100 - clampi(resist_pct, 0, RESIST_CAP)) * MILLI / 100
static func skill_power(value: int, atk: int) -> int:
	if value <= 0:
		return 0
	return maxi(1, floori(float(value * (100 + SKILL_ATK_PCT * (maxi(atk, 1) - 1))) / 100.0))

# scripts/stats/creature_scale.gd (new; pure, used by tools/build_content.gd)
class_name CreatureScale
const POWER_PCT_PER_LEVEL := 8
static func power_pct(level: int) -> int:
	return 100 + POWER_PCT_PER_LEVEL * (maxi(level, 1) - 1)
static func scaled(base: int, level: int) -> int:
	return floori(float(base * power_pct(level) + 50) / 100.0)
```

Call sites (search by symbol): `Player.receive_hit` (DEF leaves `flat_off` and enters `hit`), `Player.tick` and
`receive_poison` (the carried tick), `Enemy.receive_hit` (DEF physical only; `ignore_def`), the damaging abilities (a small
`Ability.actor_atk()` returns the actor's ATK or 1 for a stub; each damaging ability calls `Damage.skill_power(value(), atk)`
itself), `SporeCloud`, `Miasma`, `Puffball` (the `damage` option), `SkillScreenModel.detail` and `effect_lines` (an ATK
argument, default 1, applied to "Damage" lines), `CompendiumModel.creature_report` and the Bestiary card (level),
`tools/build_content.gd` and the regenerated `data/creatures/*.tres`, `DefValidator` (level >= 1).

## Accepted changes for armoured or poisoned slimes (all others are the identity)

Every DEF-0, resistance-free hit is identical to today. These change, each pinned in `tests/test_damage.gd`:

| Case | Before | After |
|---|---|---|
| Spider (ATK 4) vs DEF 3 | 1 | 2 |
| Lizard (ATK 5) vs DEF 4, 5, 6 | 1 | 2 |
| Serpent (ATK 6, unspawned) vs DEF 1 | 5 | 4 |
| Toad spit on a DEF-3 slime, no resistance | 1 + 3 ticks = 4 | 4 + 3 ticks = 7 (the application no longer loses 3 to DEF; the ticks are unchanged) |
| Toad spit on a DEF-5 slime with Poison Resistance L1 | 1 + 0 = 1 | 3 + 2 = 5 |
| Toad ticks vs Poison Resistance L1, 3 s | 0 HP | 2 HP |
| Poison Breath L1 vs lizard (DEF 3) | 1 | 2 |
| Water Blade at ATK 5 vs lizard | 1 | 3 |
| Tackle at ATK 4 vs lizard | 1 | 2 |
| Poison Breath L15 at ATK 8 (DEF 0) | 16 | 44 |
| Grotto crab / snake / moth / pale moth (level 4) | 8 HP, ATK 2, DEF 2 / 5, 3, 0 / 3, 1, 0 / 6, 1, 0 | 10, 2, 2 / 6, 4, 0 / 4, 1, 0 / 7, 1, 0 |

## Failure modes and edge cases

- Integer resolution: percentages of hits of 1-6 round to whole HP, so the win shows once enemy raw damage is 16 or more;
  the Grotto's scaling is modest (x1.24) and rounds unevenly on tiny numbers (`scaled(1, 4) = 1`, `scaled(2, 4) = 2`).
- Out-levelling is intended: a stage-4 slime (DEF 14) takes 1 from Cave lizards forever.
- Skills now grow with ATK: a maxed stage-4 build one-shots a level-4 crab (HP 10). `SKILL_ATK_PCT` is the knob. Water Blade
  (a single value) still converges toward a free tackle at high ATK; that is not a regression.
- The carried tick: `_poison_milli` is cleared on death and on a new life, never on a new application; `receive_poison` and
  `SPIT_TICK` keep their whole-HP meaning, so the enemy trace fixtures and `test_tuning.gd` stay green.
- A level-4 crab needs 5 weak-point tackles instead of 4 (HP 10, double damage 2): the stun window is checked by a test that
  runs the real tackle rate.
- Body Armor no longer helps against poison (DEF is physical); Poison Resistance now reaches ticks. The skill descriptions say so.
- Appraisal shows the def's baked stats; a creature's runtime DEF also includes its own skills' modifiers (the lizard's Body
  Armor), which the report already omitted before this change. Out of scope.
- `CreatureDef.level` missing in an old `.tres` loads as 1.

## Testing

New `tests/test_damage.gd`: identity (`hit(p, "physical", 0, 0, 0) == p`), `armor_pct(4, 5) == 50`, `hit(40, "physical", 30,
0, 0) == 20`, monotone in DEF and non-decreasing in power over a property loop (power 1..60, DEF 0..80), poison ignores DEF,
the resistance clamp (`hit(10, "poison", 0, 200, 0)` and 113% behave as 95%), the 20-cell legacy grid ATK 1..5 x DEF 0..3
as literal expected values (one difference, ATK 4 vs DEF 3), every row of the accepted-changes table, `tick_milli(1, 20) ==
800` and a `Player` test that three 3 s toad applications at 67% cost 1 HP in total with the carry surviving between
applications and cleared on death, `skill_power(v, 1) == v` for every Breath value and `skill_power(0, n) == 0`,
`skill_power(16, 8) == 44`. `CreatureScale`: `power_pct` at levels 1, 4, 6, 28, `scaled(8, 4) == 10`, `scaled(0, n) == 0`,
`scaled(v, 1) == v`. Content: the regenerated `.tres` pin (Grotto numbers), `DefValidator` rejects level 0, the appraisal and
the Bestiary card show `Lv` and the baked numbers, the Skills tab shows the amplified value on "Damage" lines and not on
radius, distance or hold lines (`effect_lines` keeps its two-argument form working). Integration: a real `Player` at ATK 3
casting Poison Breath at a real toad; Healing Spores and Binding Web still do no damage (`test_zone.gd`'s zero-damage pin);
Spore Cloud, Miasma's cloud and Puffball amplify. Existing pins that must stay green: `test_stats.gd` (ported), `test_player.gd`,
`test_enemy.gd` (weak-point tests re-derived for the Grotto crab), `test_tuning.gd`, `test_levels.gd`, `test_player_skill_set.gd`,
`test_skill_effects.gd`, `test_skill_screen.gd`, `test_hardened_shell.gd`, `test_spore_cloud.gd`, `test_abilities.gd`,
`test_evolution_abilities.gd`, `test_zone.gd`, `test_form_effects.gd`, `test_grotto_data.gd` (re-pinned) and the enemy traces.

## Rulings I made

1. **Hit-relative hyperbolic armor** (Path of Exile's form) rather than level-relative (Diablo's), because creature level
   enters through the creature's stats, so a level term in the armor constant would double-count it. Cost if wrong: one
   constant and one function.
2. **DEF physical only, resistance for poison**, as Blizzard did in 1.2.0. Cost if wrong: Body Armor no longer helps
   against toads (the accepted-changes table lists it).
3. **Levels are baked into creature data at generation time**, not computed at spawn: appraisal and the Bestiary then show
   the real numbers for free and no runtime code changes. Cost if wrong: re-deriving numbers means regenerating content.
4. **Grotto is level 4** (x1.24) so early play is unchanged and the Grotto is modestly harder. Cost if wrong: one number.
5. **ATK amplifies skills by 25% per point above 1.** Cost if wrong: playtest tuning of one constant.
6. **Resistances stay additive with a 95 clamp** and the shipped Poison Resistance table is not edited. Cost if wrong: a
   multiplicative rule later is one function and two call sites.
7. **The integer scale is kept.** Cost if wrong: the ATK-vs-armour cliff at small numbers remains until the x10 spec.

## Not here

Enemies reading their own resistances, combine_pct, per-creature XP by level, a dodge or block stat, damage types beyond
physical and poison, an item system, the x10 scale, runtime enemy levels, and the new areas' level rows (added with each area).
