# Damage, Armor and Levels — Design

Status: revised after round 3 of the debate (2026-09-29). Answers Sean's note: "I saw something that was talking about how
damage and armor work in Diablo 4 where it uses an equation to determine damage. Can you research that and see if we can
improve our stats and damage calculations based on level and stats?" Research: `docs/research/damage-formulas.md` (Diablo
4, Diablo 3, Path of Exile, Elden Ring, Pokemon, Dragon Quest; our own code audited).

## What I understood

Sean wants damage, armor and level scaling to be a considered model instead of the flat subtraction the game uses now,
inspired by how Diablo 4 turns armor into a percentage with an equation. Success, stated to match what this spec delivers:

- DEF stops being a cliff: a hit is reduced by a percentage that never reaches 100%, and DEF beyond a hit's size still
  helps a little instead of being wasted.
- ATK matters to skills as well as tackles: the damage of the direct-damage skills (Poison Breath and its evolutions'
  cones, Water Blade, Venom Bolt) grows with the player's ATK.
- Poison is not reduced by DEF (DEF is for physical hits) and Poison Resistance reaches poison ticks; resistance
  percentages stack up to a cap.
- A creature's numbers come from a **level** by one formula in the content generator, so a later area is stronger by
  declaring a level rather than by hand-editing each creature; the Grotto creatures are level 4. Appraisal and the Bestiary
  already read the generated numbers, so what is shown is what is fought.

**What stays the same:** at ATK 1 in the Cave, damage *taken* by a slime with DEF 0 and no resistance is unchanged on every
path (contact, spit and its ticks, puffs), and so are its tackles and its skill hits on DEF-0 targets. Everything else that
changes is a class listed below: physical hits against DEF above 0, poison against any DEF (both directions), poison ticks
under resistance, skills at ATK 2 or more, and the Grotto's level. Those are accepted, not hidden.

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
3. Skill tables ignore ATK: Water Blade is always 3, Poison Breath is 2 to 16 by skill level only.
4. Any poison resistance deletes 1-point poison ticks (`Damage.tick(1, p) = 0` for every p >= 1), and every tick source is
   1, so the resistance table does nothing against ticks.
5. Percent sources add and clamp at 100 (Poison Resistance L9 83% + Venom Blood 30% = 113%).
6. Creatures have no level; the Grotto (later content, ATK 1-3) is weaker than the Cave (ATK 3-5). (Level 4 raises Grotto HP 4-10 against the Cave's 2-5; ATK moves only where the base is 3 or more, so only the snake's rises.)
7. DEF also cuts poison damage (a stat that should be for physical hits).

(The reported "I cannot tackle a mushroom" problem shipped separately: `Enemy.WEAK_POINT_MULT`, a tackle from behind or on a
stunned armoured enemy ignores DEF and does double. This spec keeps it exactly.)

## Decisions

| Topic | Decision |
|---|---|
| One resolution | `Damage.hit(power, damage_type, defense, resist_pct, flat_off) -> int`: DEF becomes an armor percent **only for `"physical"`**; resistance percent (clamped at `RESIST_CAP` 95) applies to any type; the two multiply; the flat reductions subtract; minimum 1. Player and enemy both call it; `Damage.direct_hit` and `Damage.tick` are **deleted in the same change** and the nine pins in `tests/test_stats.gd` are ported (`direct_hit(raw, p, flat)` becomes `hit(raw, "physical", 0, p, flat)`; the flat argument stays `flat_off`, so `direct_hit(6, 0, 1) == 5` stays 5) |
| Armor | `armor_pct(def, power) = floor(10000 x def / (100 x def + 80 x power))` for `def, power > 0`, else 0. No cap: it is below 100 for every finite DEF, and the minimum-1 rule is the only floor. A DEF equal to 0.8 x the hit's power removes half of it |
| Weak point | `Enemy.receive_hit(raw, damage_type, from, cause, ignore_def := false)` keeps its signature: when `ignore_def` the defense passed to `hit` is 0. Enemies do not read their own resistances (deferred), so `Enemy.receive_hit` passes `resist_pct` 0. The double-damage tackle is unchanged |
| Resistances | Additive, as today, but clamped at `RESIST_CAP := 95` inside `hit` and `tick_milli` (above the Poison Resistance table's maximum of 92, so the shipped table is not edited and stays honest on the Skills tab). No `combine_pct`. Consequences, accepted: on the Toxic line (Poison Resistance plus Venom Blood 30%) L6 is 97 today and L7-L12 clamp at 100, and all now clamp at 95, so a maxed Toxic slime takes 0.05 HP a second of poison ticks instead of none; and the Toxic and Acid forms (Venom Blood 30%, no Poison Resistance), tick-immune today, now take 0.7 HP a second (2 HP of ticks from a toad spit). Blight's flavour line "A creeping rot you are immune to." (`build_forms.gd`) is now less true and is outside this spec |
| Poison ticks | Fractional: `tick_milli(raw, resist_pct) = floor(raw x (100 - clamp(resist, 0, 95)) x MILLI / 100)` thousandths of an HP per second (`MILLI := 1000`), carried in a persistent `Player._poison_milli` (initialised 0; a new life is a new `Player`, so nothing needs clearing) that is **not reset by a new application**, and separate from `_poison_acc`. A whole HP drawn from the carry is consumed even at HP 1 (`Health.take_tick` holds HP at 1; ticks never kill). `receive_poison` keeps whole-HP arguments (`SPIT_TICK` stays 1) |
| Skills scale with ATK | `Damage.skill_power(value, atk) = max(1, floor(value x (100 + 25 x (max(atk, 1) - 1)) / 100))`. ATK 1 is today's table exactly. Applied to the **direct-damage** abilities only: Poison Breath (Miasma extends it and calls `super._perform()`, so its cone is amplified exactly once), Water Blade and Venom Bolt, through a base-class `Ability.actor_atk()` (the actor's `stats` ATK read with `actor.get("stats")`, ATK 1 for a test stub without stats). **The clouds (Spore Cloud, Miasma's cloud, Puffball) stay a fixed 1**: they are area control, their tick value 1 is all rounding cliff (`skill_power(1, atk)` is 1 until ATK 5), and nothing on the Skills tab would show it. The Skills tab shows the amplified number for the player's ATK on the lines labelled "Damage" only; `SkillScreenModel.detail` and `effect_lines` take an ATK argument defaulting to 1 and `SkillScreen` passes the player's current ATK where it calls `detail` |
| Creature level | Level is a **generator concept**: `tools/build_content.gd` keeps each creature's hand-written base numbers and derives the generated stats through `_at_level(level, stats)` (level first), applied to the `"stats"` dictionary of the four Grotto entries only (`"stats": _at_level(4, {"max_hp": 8, "atk": 2, "def": 2, "spd": 70})`), so the creature dictionary gains no `level` key (`_cr` copies every key onto `CreatureDef` and a `level` key would be dropped) and the Cave entries keep their code path. `_at_level` scales only the `max_hp`, `atk` and `def` keys that are present with `_scaled(base, level) = floor((base x (100 + 8 x (level - 1)) + 50) / 100)` (0 stays 0, level 1 is the identity); SPD, XP, skill values and the spit and puff numbers are not scaled. The four Grotto creatures declare level 4 (x1.24). Regeneration is idempotent from the base numbers, and after it `git status --short data/` lists exactly the four Grotto creature files and the three edited skill files (`body_armor`, `poison_resistance`, `poison_spit`) with the six level-1 creature files unchanged. There is no `level` field, no validator rule, no `Lv` label and no runtime code: `Enemy`, `RoomBuilder`, `Game._spawn`, `SporePuff`, `CompendiumModel` are untouched, and appraisal and the Bestiary already show the generated numbers because they read the def's stats. A visible `Lv` label is a later, independent change |
| Player level | Unchanged: +2 HP and +1 MP per level; stages and forms keep granting flat ATK/DEF and the skill caps |
| Deferred | Enemies reading their own resistances (the toad's Poison Resistance L2 stays dead data; turning it on is a Cave nerf to Poison Breath 2 to 1 and needs its own decision), combine_pct, per-creature XP by level, a visible `Lv`, cloud amplification, and the x10 scale |

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
	return floori(float(raw * (100 - clampi(resist_pct, 0, RESIST_CAP)) * MILLI) / 100.0)
static func skill_power(value: int, atk: int) -> int:
	return maxi(1, floori(float(value * (100 + SKILL_ATK_PCT * (maxi(atk, 1) - 1))) / 100.0))

# tools/build_content.gd (generation time only)
static func _scaled(base: int, level: int) -> int:
	return floori(float(base * (100 + 8 * (maxi(level, 1) - 1)) + 50) / 100.0)
```

Call sites (search by symbol): `Player.receive_hit` (DEF leaves `flat_off` and enters `hit`), `Player.tick` and
`receive_poison` (the carried tick), `Enemy.receive_hit` (DEF physical only; `ignore_def`; resist 0), `Ability.actor_atk()` and
Poison Breath, Water Blade and Venom Bolt (`Damage.skill_power(value(), actor_atk())`), `SkillScreenModel.detail` and
`effect_lines`, and `SkillScreen` where it calls `detail`, `tools/build_content.gd` (`_at_level`, the four Grotto entries and the
skill descriptions below) with the regenerated `data/creatures/*.tres` and `data/skills/*.tres`. The descriptions that
change: Body Armor (raises DEF, which no longer helps against poison), Poison Resistance, and Poison Spit ("4 poison on hit,
then 1 per second for 3 s": it says 2 today, `SPIT_TICK` is 1).

## What changes, by class (all others are the identity)

Every damage-taken path at DEF 0 with no resistance is identical at ATK 1 in the Cave. These change; each has a row pinned
(in `tests/test_damage.gd` where the row is pure formula, and in a `Player` or content test where it is not):

| Case | Before | After |
|---|---|---|
| Spider (ATK 4) vs DEF 3 | 1 | 2 |
| Lizard (ATK 5) vs DEF 4, 5, 6 | 1 | 2 |
| Serpent (ATK 6, unspawned) vs DEF 1 | 5 | 4 |
| Tackle at ATK 4 vs lizard | 1 | 2 |
| Water Blade at ATK 5 vs lizard | 1 | 3 |
| Poison Breath L1 / L2 / L3 / L4 vs lizard (DEF 3), ATK 1 | 1 / 1 / 1 / 2 | 2 / 3 / 4 / 5 (poison ignores DEF) |
| Venom Bolt vs lizard | 6 | 9 |
| Poison Breath L1 / L4 vs crab (DEF 2) | 1 / 3 | 2 / 5 (poison ignores DEF) |
| Poison Breath L15 at ATK 8 (DEF 0) | 16 | 44 |
| Poison Breath L1 at ATK 3 (DEF 0) | 2 | 3 |
| Toad spit on a DEF-3 slime, no resistance (fresh `Player`) | 1 + 3 ticks = 4 | 4 + 3 ticks = 7 |
| Toad spit on a DEF-5 slime with Poison Resistance L1 (fresh `Player`) | 1 + 0 = 1 | 3 + 2 = 5 |
| Toad-spit ticks vs Poison Resistance L1, 3 s (fresh `Player`) | 0 HP | 2 HP |
| Moth puff ticks vs Poison Resistance L1, 2 s (fresh `Player`; the 1 HP application is unchanged) | 0 HP | 1 HP |
| Toxic or Acid form (Venom Blood 30%, no Poison Resistance): toad-spit ticks (fresh `Player`) | 0 HP | 2 HP (700 a second: 700, 1400, 1100) |
| Two toad spits at 67% resistance, each after the previous poison has run out (3 s apart) | ticks 0 HP | ticks 1 HP (carry 980) |
| Three toad spits at 67% resistance, each 3 s after the last | ticks 0 HP, 3 HP applications | ticks 2 HP (carry 970), 3 HP applications |
| Grotto crab / snake / moth / pale moth (level 4) | 8 HP, ATK 2, DEF 2 / 5, 3, 0 / 3, 1, 0 / 6, 1, 0 | 10, 2, 2 / 6, 4, 0 / 4, 1, 0 / 7, 1, 0 |

The poison rows are the biggest outgoing change: every poison skill now gains back min(DEF, value - 1) of what the target's DEF used to take (Breath L1 against the lizard gains 1, from 1 to 2).
That includes the crab, whose weak point exists so that ATK 1 can hurt it: Poison Breath L1 now does 2 to it from any side and
at range. Keeping it is a decision (Ruling 2): DEF is for physical hits. The carried tick makes resistance rows depend on
history (PR L1 ticks cost 2, 2, 3, 2, 3 HP over five consecutive toad spits, each after the last poison ran out); the rows
above are from a fresh `Player`, and the carry rows need each spit at least `Enemy.SPIT_SECONDS` (3 s) after the previous:
a new application resets the remaining poison time, so closer spits discard unrun ticks and the carry differs (1 s apart:
1 HP, carry 320, after two spits). One toad's own spit cooldown (5 s) keeps its spits apart in play.

## Failure modes and edge cases

- Integer resolution: percentages of hits of 1-6 round to whole HP, so the win shows once enemy raw damage is 16 or more;
  the Grotto's scaling is modest (x1.24) and rounds unevenly on tiny numbers (`scaled(1, 4) = 1`, `scaled(2, 4) = 2`).
- Out-levelling is intended: a stage-4 slime (DEF 14) takes 1 from Cave lizards forever.
- Skills now grow with ATK: a maxed stage-4 build one-shots a level-4 crab (HP 10). `SKILL_ATK_PCT` is the knob. Water Blade
  (a single value) still converges toward a free tackle at high ATK; that is not a regression.
- A level-4 crab needs 5 weak-point tackles instead of 4 (HP 10, double damage 2). The tackle gate is 0.15 s, so the fifth
  lands at 0.6 s of the 3.0 s stun (a test pins `4 x TACKLE_SECONDS < STUN_SECONDS` and the sequence).
- The level is per creature id, not per area: a crab reused in a later area at a different strength would need a new id
  (and its own Bestiary entry) or a re-level that also moves the Grotto crab. "A later area is stronger by data" holds for new
  creatures; runtime levels return when one creature must appear at two strengths.
- Body Armor no longer helps against poison (DEF is physical); Poison Resistance now reaches ticks. The skill descriptions say so.
- Appraisal shows the def's baked stats; a creature's runtime DEF also includes its own skills' modifiers (the lizard's Body
  Armor), which the report already omitted before this change. Out of scope.
- The Toxic line's clamp at 95 (Resistances row).

## Testing

New `tests/test_damage.gd`: identity (`hit(p, "physical", 0, 0, 0) == p`), `armor_pct(4, 5) == 50`, `hit(40, "physical", 30,
0, 0) == 20`, monotone in DEF and non-decreasing in power over a property loop (power 1..60, DEF 0..80), poison ignores DEF,
a clamp test that can fail (`hit(100, "poison", 0, 113, 0) == 5`, which a clamp of 100 would make 1, and `tick_milli(1, 100)
== 50`, which a clamp of 100 would make 0), the 20-cell legacy grid ATK 1..5 x DEF 0..3 as literal expected values (one
difference, ATK 4 vs DEF 3), the pure-formula rows of the table, `tick_milli(1, 20) == 800`, `skill_power(v, 1) == v` for every
Breath value and `skill_power(16, 8) == 44`. `Player` tests on a fresh player with each application after the previous poison has run out (three `tick(1.0)` calls, which
also clears the 1 s invulnerability) and with the skill's level asserted unchanged at the end (each application is a
"damaged" event that levels Poison Resistance): the carry rows above (2 spits at 67% cost 1 HP of ticks with carry 980; 3
spits cost 2 HP with carry 970 plus 3 HP of applications), a whole HP drawn at HP 1 is consumed, the DEF-3 and DEF-5 spit
rows and the moth-puff row. Content: the regenerated `.tres` pin (Grotto numbers, in `test_grotto_data.gd` and the pale moth
in `test_pale_moth.gd:23`), the four crab weak-point tests in `test_enemy.gd` re-derived for HP 10 (the front tackle 7 becomes
9, from behind 6 becomes 8, stunned 4 becomes 6, and "falls in four" becomes five tackles, plus the stale "would take eight"
comment in `enemy.gd`), the crab stun-window test (`receive_tackle(1, true)` then four times `status.update(Player.TACKLE_SECONDS)`
and `receive_tackle(1, false)`, STUNNED before the last, DYING after), the Skills tab shows the amplified value on "Damage"
lines and not on radius, distance or hold lines (`effect_lines` keeps its two-argument form working), the poison-vs-lizard and
poison-vs-crab rows with real enemies and a real `Player` at ATK 3 casting Poison Breath at a real toad, Miasma at ATK 3
(the cone is `skill_power(9, 3) == 13`, not the doubly amplified 19) and its cloud and the Spore Cloud and Puffball clouds at
ATK 5 still dealing 1 (`skill_power(1, 5)` would be 2), a bound `SkillScreen` showing the player's ATK-amplified "Damage" line
(`skill_screen.gd` passes `_player.stats.get_stat("atk")`), and the regenerated skill-description pins (Body Armor says it
raises DEF against physical damage, Poison Resistance says it reduces poison damage and poison over time, Poison Spit says
"4 poison on hit, then 1 per second for 3 s"). Existing pins that must stay green: `test_stats.gd` (ported: the five `direct_hit` pins, and the four `tick` pins become `tick_milli(2, 0) == 2000`, `tick_milli(2, 35) == 1300`, `tick_milli(2, 65) == 700` and `tick_milli(10, 90) == 1000`; the "may reach zero" name goes, since the clamp leaves at least 50), `test_player.gd`, `test_tuning.gd`,
`test_levels.gd`, `test_player_skill_set.gd`, `test_skill_effects.gd`, `test_skill_screen.gd`, `test_hardened_shell.gd`,
`test_spore_cloud.gd`, `test_abilities.gd`, `test_evolution_abilities.gd`, `test_zone.gd` (the zero-damage pin), `test_form_effects.gd`,
`test_compendium_model.gd`, `test_status_text.gd` and the enemy traces.

## Rulings I made

1. **Hit-relative hyperbolic armor** (Path of Exile's form) rather than level-relative (Diablo's), because creature level
   enters through the creature's stats, so a level term in the armor constant would double-count it. Cost if wrong: one
   constant and one function.
2. **DEF physical only, resistance for poison**, as Blizzard did in 1.2.0. Cost if wrong: Body Armor no longer helps against
   toads, and every poison skill ignores enemy armour (the table lists both).
3. **Levels are a generator concept, baked into creature data**, with no runtime code, field or label: appraisal and the
   Bestiary show the real numbers for free. Cost if wrong: a visible `Lv` or per-area strength needs a later change.
4. **Grotto is level 4** (x1.24). Cost if wrong: one number.
5. **ATK amplifies the direct-damage skills by 25% per point above 1; the clouds stay fixed.** Cost if wrong: playtest
   tuning of one constant, or cloud amplification later.
6. **Resistances stay additive with a 95 clamp** and the shipped Poison Resistance table is not edited. Cost if wrong: a
   multiplicative rule later is one function and two call sites.
7. **The integer scale is kept.** Cost if wrong: the ATK-vs-armour cliff at small numbers remains until the x10 spec.
8. **The poison carry persists across applications.** Cost if wrong: resistance rows are history-dependent.

## Not here

Enemies reading their own resistances, combine_pct, per-creature XP by level, a visible `Lv`, cloud amplification, a dodge or
block stat, damage types beyond physical and poison, an item system, the x10 scale, runtime enemy levels.
