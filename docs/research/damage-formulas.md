# Damage, armor and level formulas: research and a proposal for the slime game

Sourcing key. **(read)** = page fetched this session; WebFetch returns a model-written extract, so equations are quoted as extracted, and formula images (Maxroll's damage page) were not readable. **(snippet)** = seen only in a search-result snippet, unverified. Claims are labelled by Diablo 4 era because the game changed its rules; do not merge eras.

---

# Part A. How other games do it

## A1. Diablo 4 damage

| Era | Source | Claim |
|---|---|---|
| Launch (Aug 2023) | [diablo4.gg](https://diablo4.gg/diablo-4-damage-buckets-and-formula-explained/) (read) | `Base x Additive x Vulnerable x Crit x MainStat x Global + Overpower`. Vulnerable = 20% + bonus, crit and vulnerable each a separate multiplicative bucket. "One point of main stat = +0.1% skill damage." Overpower is additive. |
| 1.2.0 (Oct 2023) | [Blizzard](https://news.blizzard.com/en-us/article/24014289/master-your-power-in-season-of-blood) (read) | Before: crit, vulnerable and overpower each sat in their own bucket and "the full amount of bonus damage from each bucket was multiplied together", so the best build stacked crit damage and vulnerable damage. After: only the baseline is multiplicative (x50% crit, x20% vulnerable, x50% overpower); all further crit/vulnerable/overpower damage is additive. Intent: sources "much more equal in value ... less mandatory for all builds." |
| S13 (page dated 12 Jun 2026) | [Maxroll](https://maxroll.gg/d4/resources/in-depth-damage-guide) (read) | Structure below. Crit 50%[x], vulnerable 20%[x], overpower 15%[+] per stack, max 4 stacks, 4 s (differs from Blizzard's 1.2.0 overpower baseline). |

S13 structure as Maxroll states it (average damage, no variance, no attack speed):

```
Damage = AvgWeaponDamage x Skill% x MainStatMult x AdditiveMult x Product(Global[x]) x (1 - EnemyDR)
MainStatMult = 1 + MainStat / Coef          Coef = 909.91 (Barbarian), 800 (other classes)
AdditiveMult = 1 + Sum(all [+]% affixes: close, distant, core, vs-X, to-X, vulnerable, crit, overpower)
Global       = every [x]% source multiplied together, each as (1 + x%)
EnemyDR      = "enemies take less damage based on your level, capped at 80% reduced at level 70"  -> factor 0.20
```

Worked (my arithmetic): [+]30% and [+]20% give x1.50; [x]30% and [x]20% give x1.56. Each added additive point is worth less as the bucket grows; each new multiplicative bucket is worth its full value, which is why buckets, not sizes, decide builds.

## A2. Diablo 4 armor, resistances, level

| Era | Source | Claim |
|---|---|---|
| Launch | [TheGamer](https://www.thegamer.com/diablo-4-how-armor-and-resistances-work/), [Dexerto on Skyline](https://www.dexerto.com/diablo/diablo-4-armor-calculator-formula-helpful-2215870/), [diablo4.gg](https://diablo4.gg/diablo-4-defenses-explained-armor-resistances-damage-reduction/) (all read) | Armor mitigation cap 85%. A level-1 attacker cancels 50 of your armor, so 150 armor reaches 85%; higher-level attackers cancel more. Skyline's sheet is "within 1 to 2 percent"; **no exact equation was published** and the [Blizzard forum thread](https://us.forums.blizzard.com/en/d4/t/how-does-armors-damage-reduction-scale-against-monster-level/138478) (read) has no staff formula. Resistances stack multiplicatively (20% then 20% = 36%). Armor also gave half its value against elements. |
| 1.2.0 | Blizzard (read) | Resistances become additive with a 70% base cap, 85% hard cap. "Armor now only reduces physical damage." |
| S13 (page dated 16 Aug 2026) | [Maxroll defenses](https://maxroll.gg/d4/getting-started/defenses-for-beginners) (read) | `DR = Armor / (Armor x 10/9 + C)`, C = 5678 at level 70, "level dependent ... smaller as level decreases" (the page does not say whose level). Resistance: same shape, C = 1136 at level 70 (one fifth, so resistance is 5x as efficient). The 10/9 term makes DR approach 90%. DR sources multiply: `1 - Product(1 - DR_i)`. Worked (mine): Armor = C gives 47.4%. |

Level difference in D4: monsters scale to the player ("play any content ... in any order"), with +2 in Strongholds/Helltide, and "you get weaker every time you level up" without gear ([TheGamer](https://www.thegamer.com/diablo-4-how-level-scaling-works/), read; undated, launch-era). Snippet-only, unverified: 13,441 armor needed at Nightmare Dungeon 100 (monster level 154); a 75% monster-DR cap; armor depreciation depends on attacker level rather than level difference.

## A3. Contrast systems and why the curves look the way they do

| Game | Equation | Where level or size enters | Bounds |
|---|---|---|---|
| Diablo 3 ([Maxroll](https://maxroll.gg/d3/resources/damage-reduction-explained), read) | `DR = A / (A + 50 x L_attacker)` (3500 at L70); resist `R / (R + 350)`; sources multiply | attacker level in the constant | below 100%, no immunity |
| Path of Exile ([GGG forum](https://www.pathofexile.com/forum/view-thread/1468738), [MMOJUGG](https://www.mmojugg.com/news/path-of-exile-2-armor-mechanics-explained.html), read) | `Red = A / (A + c x Hit)`; c = 10 (forum, older), 5 (PoE1) and 12 (PoE2) per MMOJUGG | the hit's own size, not level | 90% physical cap (forum comment); PoE2 armor "almost useless" vs bosses (MMOJUGG) |
| Elden Ring ([Fextralife](https://eldenring.wiki.fextralife.com/Calculating+Damage), read) | `r = AR/Def`; m(r) = 0.10 for r<0.125; 0.10+(r-0.125)^2/2.552 for r<1; 0.70-(2.5-r)^2/7.5 for r<2.5; 0.90-(8-r)^2/151.25 for r<8; 0.90 above; `dmg = AR x m(r) x (1 - negation)` | ratio of attack to defense | 10% to 90% of attack |
| Pokemon DPP ([Smogon](https://www.smogon.com/dp/articles/damage_formula), read) | `((((2L/5+2) x Power x A/50)/D) x Mod1 + 2) x CH x Mod2 x R/100 x STAB x Type`, floor after each step | attacker level, linear in the base term | min 1 |
| Dragon Quest / FF ([Game Developer](https://www.gamedeveloper.com/design/number-punchers-how-i-final-fantasy-i-and-i-dragon-quest-i-handle-combat-math), read) | DQ `(Atk - Def/2)/2`; FF1 `rand(Atk, 2 Atk) - Def` | none | flat subtraction |

Design goals visible in these sources:

1. **No immunity.** A/(A+K) is below 1 for every A (math); Elden Ring floors damage at 10% of the attack (Fextralife table above).
2. **Diminishing percent, linear effective HP** (my derivation, not sourced): EHP = HP/(1-DR) = HP x (1 + A/K). Every armor point is worth the same HP-equivalent, so armor stays comparable with max-HP stats even as the percent flattens.
3. **Level-relative power.** K proportional to attacker level (D3: 50 x L; D4: a level-dependent constant) makes a fixed armor number decay as content levels, and monster scaling to the player removes safe and unsafe zones.
4. **Hit-relative** (PoE): chip damage is nearly negated, big hits break through. Cost: bosses ignore armor.
5. **Flat subtraction** (DQ/FF) is simple to read. Harris says DQ's 2:1 weighting (attack worth twice defense) keeps combatants "in play" longer, "allowing even lower-level participants to do at least some damage", and warns that "a very high Defense" will "shut a battle down".

## A4. Pitfalls

- **Additive stacking makes one stat mandatory; separate multiplicative buckets make combos mandatory.** Pre-1.2.0 D4 is the case study (Blizzard, above). Blizzard's fix keeps one small multiplicative baseline and folds the rest into the additive bucket.
- **Flat subtraction cliffs.** Once Def >= Atk the hit floors and extra Def is wasted (DQ/FF); the opposite side is high-attack enemies flattening low-Def targets.
- **Level scaling that trivialises or hard-gates.** D4's "you get weaker every time you level up" (hard gate when gear lags) and armor requirements that grow with monster level (snippet: 13,441 at NMD 100). A level term inside the armor constant is the standard lever, but it turns armor into a treadmill.
- **Stat inflation.** Unbounded stat numbers obsolete fixed constants; ratio or hyperbolic forms (Elden Ring, D3) stay meaningful as numbers grow. D4 keeps caps (85%, 70%/85%, 90% asymptote) and revises formulas each era.
- **Mixing damage types in one defense stat.** Blizzard made armor physical-only in 1.2.0, the clean split for a game with a physical stat and a poison resistance.

---

# Part B. Our current model (read-only audit of /Users/sean/sites/isekai-game, main checkout)

There is no `tests/test_damage*.gd`: `Damage` is pinned only in `tests/test_stats.gd:47-58`, and level and stage numbers in `tests/test_levels.gd` and `tests/test_progression_stages.gd`.

## B(a). The equations, exactly

1. **Every direct hit, anyone:** `hit = max(1, floor(raw x (100 - p)/100 - flat))`, p clamped 0..100 (`scripts/stats/damage.gd:6-8`).
2. **Player tackle:** raw = the player's ATK (`player.gd:321`), enemy side p = 0, flat = enemy DEF (`enemy.gd:181`, `:189`): `max(1, ATK - DEF_enemy)`. Stun 3 s (`enemy_status.gd:11`); an armored front (lizard, crab) is hurt but not stunned (`enemy.gd:194`).
3. **Player skills on enemies:** raw = table value at skill level (`ability.gd:34-37`): Poison Breath (`poison_breath.gd:8`, type poison), Water Blade (`water_blade.gd:10`, physical), Spore Cloud fixed 1 per second (`spore_cloud_area.gd:42`). All go through equation 1 with enemy DEF; the enemy's own resistances are never read.
4. **Enemy contact:** raw = enemy ATK, every physics frame in contact (`enemy.gd:288-289`), on the player `max(1, ATK - (DEF + flat_off))` with `flat_off` = Pain Resistance (1..6, only below 30% HP) + Hard Shell 1 (`player.gd:620-621`, `player_skill_set.gd:58-67`). There is no physical percent source. One hit per 1.0 s (`player.gd:28`, `:618`).
5. **Poison:** the application is equation 1 with type poison, so DEF applies (`player.gd:628-632`); then each second `tick = max(0, floor(tick x (100 - p)/100))` (`damage.gd:11-13`, `player.gd:640-646`), and `Health.take_tick` never drops HP below 1 (`health.gd:29-33`). Toad spit: application 4 (`build_content.gd:168-169`, `enemy.gd:125-126`), tick 1 (`SPIT_TICK`, `enemy.gd:26`), 3 s, every 5 s. Moth puff: 1, tick 1, 2 s (`spore_puff.gd:8-10`).

## B(b). How the inputs feed in

- **One additive bucket:** `Stats.get_stat = base + eat (capped) + level bonus + sum of modifiers`, a `set` op overrides (`stats.gd:64-75`). Eat caps: HP +10, ATK +3, DEF +2 (`stats.gd:6`).
- **Level:** +2 HP and +1 MP per level-up and nothing else (`player.gd:33`, `:587-592`). 10 levels per stage, 9 level-ups (`progression.gd:11`); evolving resets level to 1 and keeps the bonuses (`progression.gd:69-75`). Level never reaches `Damage`.
- **Stage/form:** additive HP/MP/ATK/DEF from `STAGE_BASE` (`build_forms.gd:7-11`) plus lineage flavour; skill level cap `[5, 8, 12, 15]` per stage (`form.gd:5`, applied at `skill_rules_engine.gd:236`).
- **Skill level:** a value table indexed by level, clamped to its length (`skill_effects.gd:8-12`).
- **ATK is read in exactly two places:** the tackle (`player.gd:321`) and enemy contact (`enemy.gd:289`). Enemies deal contact ATK, the toad's spit and the moth's puff; `tail_swipe` [5], `constrict` [3] and the serpent's `water_blade` are data with empty `.tscn` scenes (`build_content.gd:168-174`; `enemy.gd:125-126` reads only `poison_spit`). CHARGE_MULT and DIVE_MULT scale speed, not damage.
- **Enemies have no level.** Stats come from `def.stats` plus their own skills' modifiers (Body Armor L2 gives the lizard DEF 3, `enemy.gd:118-124`, pinned at `test_enemy.gd:20`).

## B(c). Current numeric ranges

Player, before lineage flavour, eats and skills (formulas: HP = 30 + 2 x level-ups + stage HP; MP = 20 + level-ups + stage MP; level-ups = 9 x (stage-1) + level-1):

| Stage | Level | HP | MP | ATK | DEF | Skill cap |
|---|---|---|---|---|---|---|
| 1 | 1 / 10 | 30 / 48 | 20 / 29 | 1 | 0 | 5 |
| 2 | 1 / 10 | 53 / 71 | 32 / 41 | 1 | 0 | 8 |
| 3 | 1 / 10 | 78 / 96 | 44 / 53 | 2 | 0 | 12 |
| 4 | 1 / 10 | 106 / 124 | 57 / 66 | 3 | 1 | 15 |

Reachable extras: Toughness +3 HP per level (12 levels, +36); Body Armor +1 DEF per level (max 8; capped at 5 in stage 1); eat cap ATK +3, DEF +2; flavour: Stone DEF 4 total, Venom ATK 4 total, Bulwark DEF 1 (`data/forms/*.tres`). Maxima: **ATK 8, DEF 14** (+1 Hard Shell flat).

Creatures (`tools/build_content.gd:185-217`; spawn counts from `data/rooms/*.tres`):

| Creature | HP | ATK | DEF | SPD | XP | Spawns | Notes |
|---|---|---|---|---|---|---|---|
| Bat | 2 | 3 | 0 | 140 | 2 | cave 6 | swoops |
| Toad | 3 | 3 | 0 | 70 | 3 | cave 5 | spit 4 + 1/s x 3 s; lists Poison Resistance L2, unused |
| Lizard | 5 | 5 | 1+2 = 3 | 80 | 5 | cave 4 | armored front |
| Spider | 3 | 4 | 0 | 110 | 3 | cave 5 | |
| Spore Moth | 3 | 1 | 0 | 90 | 2 | grotto 10 | puff 1 + 1/s x 2 s |
| Mushroom Crab | 8 | 2 | 2 | 70 | 4 | grotto 12 | armored front |
| Vine Snake | 5 | 3 | 0 | 150 | 3 | grotto 6 | |
| Pale Moth | 6 | 1 | 0 | 110 | 8 | grotto 1 | |
| Serpent | 40 | 6 | 1 | 90 | 20 | none | not in any room; skills unwired |

Sample hits (the before column of the table in C4, computed through the real path): level-1 slime vs toad **1**; level-10 slime vs lizard **1** (ATK never grows with level); lizard vs level-10 slime with DEF 5 **1**.

## B(d). Where the current model is weak

1. **Any resistance deletes 1-point DoT.** `Damage.tick(1, p) = floor(1 x (100-p)/100) = 0` for every p >= 1, and every tick source in the game is 1 (`enemy.gd:26`, `spore_puff.gd:9`). Poison Resistance L1 (20%) or Venom Blood alone (30%, `form_effects.gd:19`) already cancels all poison DoT, so the L2-L12 table (32% to 92%, `build_content.gd:68`) does nothing on ticks.
2. **The flat-DEF ceiling.** DEF >= ATK floors every hit at 1; points above ATK are wasted. Body Armor L5 (the stage-1 cap) gives DEF 5, up to 7 with eats, which already reduces every creature in the roster, serpent included (6 - 5), to 1. From stage 2, DEF 5 plus Regeneration L6 (1 HP/s, `build_content.gd:136`) against at most one hit per second (`player.gd:28`) nets contact damage to about zero (my inference).
3. **ATK progress is invisible at the bottom.** Against the lizard (DEF 3) ATK 1 to 4 all do 1; ATK 8 does 5. The eat and form ATK ladder is a cliff, not a slope.
4. **Skill tables ignore ATK.** Water Blade has no `max_level` (default 1, `skill_def.gd:20`), so it is always 3, below a free tackle (which does ATK) once ATK passes 3; Poison Breath is 2..16 regardless of ATK; Spore Cloud is a fixed 1 per tick (`spore_cloud_area.gd:42`). ATK-themed lineages (Toxic, Acid, Venom, Tempest) never improve their own skills, and enemy DEF eats skill damage: Breath L1's 2 becomes 1 against lizard or serpent.
5. **Level and stage change survivability only, and enemies have no level.** A stage-4 slime has 124 HP against creatures whose ATK tops out at 6, and the grotto (ATK 1-3, HP 3-8) is weaker than the stage-1 cave (ATK 3-5) although it is later content, below the cave's Drop Shaft (`docs/superpowers/plans/2026-09-29-fungal-grotto.md:5`): biome progression is inverted, and HP cannot be scaled per biome without touching creature defs.
6. **Percent stacking is additive.** `skill_effects.gd:51` and `player_skill_set.gd:64` add, then clamp at 100: Poison Resistance L9 (83%) + venom 30% = 113%, immune to ticks and reduced to the floor on application.
7. **DEF also cuts poison** (application goes through `receive_hit`, `player.gd:631`), double-dipping with Poison Resistance; and the toad's Poison Resistance L2 is dead data (`enemy.gd:181` passes 0; `damage_taken` is not in `StatKeys.ALL`, `skill_effects.gd:17`).
8. **Drift:** the poison_spit description says "2 per second" (`build_content.gd:169`) while `SPIT_TICK` is 1, pinned by `test_tuning.gd`. XP is flat per creature (2 to 20).

---

# Part C. Proposal: one model, "hit-relative armor, ATK-amplified skills, levelled enemies"

Player levels keep buying HP and MP, forms keep buying flat ATK/DEF and skill caps, and every content table in `build_content.gd` stays as authored. Three things change: (1) DEF becomes a hyperbolic percent, relative to the size of the hit, and physical only; (2) skill tables are amplified by ATK (player) or by level (enemy) instead of ignoring both; (3) enemies get a level from their room's area, scaling their HP, ATK, DEF and skill values. There is no separate level-difference term: a higher-level attacker hits harder, so the same DEF removes a smaller share. All arithmetic is integer, in the `floori(float(n) / d)` idiom of `damage.gd:8`.

## C1. Constants

| Constant | Value | Why |
|---|---|---|
| `Damage.ARMOR_PER_HIT` | 80 | DEF that halves a hit is 0.8 x the hit. DEF 1, 2, 4 remove 20%, 33%, 50% of a 5-hit, which reproduces today's numbers |
| `Damage.ARMOR_CAP` | 80 | reached at DEF = 3.2 x hit |
| `Damage.RESIST_CAP` | 85 | Blizzard's 1.2.0 hard cap |
| `Levels.POWER_PCT_PER_LEVEL` | 8 | L6 grotto x1.4, L28 x3.16, L37 x3.88, tracking the player's own HP growth 30 to 124 (x4.1), so a level-matched bat hits for about 10% of max HP at any level |
| `Levels.AREA_LEVEL` | cave 1, grotto 6 | the run level (9 x (stage-1) + level, 1 to 37; used only to choose this table, never inside a formula) at which a player is expected to arrive. The Grotto plan puts the first evolution in G4 (`docs/superpowers/plans/2026-09-29-fungal-grotto.md:5`), so the grotto is met at run levels 6-10. New areas add a row; a spawn may add `"lv"` |
| `Damage.SKILL_ATK_PCT` | 25 | a player skill gains 25% of its table value per ATK point above the starting 1, so a fresh slime's tables are exactly today's; Water Blade beats a tackle below ATK 6 and ties it from 6 to 8 |

## C2. Formulas (GDScript-ready)

```gdscript
# scripts/stats/levels.gd (new)
class_name Levels
extends RefCounted
const POWER_PCT_PER_LEVEL := 8
const AREA_LEVEL := {"cave": 1, "grotto": 6}
static func power_pct(level: int) -> int:
	return 100 + POWER_PCT_PER_LEVEL * (maxi(level, 1) - 1)
static func scaled(base: int, level: int) -> int:        # round half up; 0 stays 0
	return floori(float(base * power_pct(level) + 50) / 100.0)
static func for_spawn(area: String, spawn: Dictionary) -> int:
	return int(AREA_LEVEL.get(area, 1)) + int(spawn.get("lv", 0))

# scripts/stats/damage.gd (added; direct_hit and tick stay untouched)
const ARMOR_PER_HIT := 80
const ARMOR_CAP := 80
const RESIST_CAP := 85
const SKILL_ATK_PCT := 25
## A player skill's table value amplified by ATK (ATK 1 = the table as authored).
static func skill_power(value: int, atk: int) -> int:
	return maxi(1, floori(float(value * (100 + SKILL_ATK_PCT * (maxi(atk, 1) - 1))) / 100.0))
static func armor_pct(defense: int, power: int) -> int:  # power = the hit before mitigation
	if defense <= 0 or power <= 0:
		return 0
	return mini(ARMOR_CAP, floori(10000.0 * defense / (100 * defense + ARMOR_PER_HIT * power)))
## Armor only touches physical hits; resistances and flats touch all. Percent first, then flat, min 1.
static func hit(power: int, defense: int, resist_pct: int, flat_off: int, physical: bool) -> int:
	var through := (100 - (armor_pct(defense, power) if physical else 0)) * (100 - clampi(resist_pct, 0, RESIST_CAP))
	return maxi(1, floori(float(power * through) / 10000.0) - flat_off)
static func combine_pct(a: int, b: int) -> int:          # multiplicative stacking, never reaches 100
	return 100 - floori(float((100 - a) * (100 - b)) / 100.0)
static func tick_milli(raw: int, resist_pct: int) -> int:  # thousandths of an HP per second
	return raw * (100 - clampi(resist_pct, 0, RESIST_CAP)) * 10
```

Call sites:

```gdscript
# player.gd receive_hit (replaces :620-621); DEF leaves flat_off
var m := skillset.incoming(damage_type, health.hp, health.max_hp)
health.take_hit(Damage.hit(raw, stats.get_stat("def"), m["percent_off"], m["flat_off"], damage_type == "physical"), damage_type)
# player.gd tick (replaces :645-646); carry the fraction, reset it in receive_poison
_poison_milli += Damage.tick_milli(_poison_tick, m["percent_off"])
var lost := _poison_milli / 1000       # int division
_poison_milli -= lost * 1000
health.take_tick(lost)
# enemy.gd: level, its own resistances, one resolution
func set_level(p_level: int) -> void:  # setup() calls it with 1; RoomBuilder calls it after spawn, like spawn_key
	level = maxi(1, p_level)
	stats.set_base(_scaled_base(level))   # max_hp, atk, def scaled by Levels.scaled; spd untouched
	stats.set_modifiers(...)              # each skill's max_hp/atk/def modifier value through Levels.scaled
	health.set_max_hp(stats.get_stat("max_hp"))
	health.heal(health.max_hp)
	_spit_damage = Levels.scaled(_spit_base, level)   # the poison_spit table value, 4 at level 1
	_spit_tick = Levels.scaled(SPIT_TICK, level)      # 1 at level 1; SporePuff.launch(at, level) does the same with 1 and 1
func receive_hit(raw, damage_type, from = Vector2.INF, cause = "") -> void:
	var m := SkillEffects.damage_reduction(_skill_pairs, damage_type, health.hp, health.max_hp)
	health.take_hit(Damage.hit(raw, stats.get_stat("def"), m["percent_off"], m["flat_off"], damage_type == "physical"), damage_type)
# tackle and contact raw stay the ATK stat (player.gd:321, enemy.gd:289)
# Ability.hit_power() = Damage.skill_power(value(), atk)  with atk = actor.stats ATK, or 1 when the actor has no stats
# Poison Breath and Water Blade pass hit_power() instead of value(). Spore Cloud's value() is its radius, so
# SporeCloud._perform computes Damage.skill_power(1, atk) and hands it to SporeCloudArea.launch(..., tick_damage := 1),
# which uses it in place of the literal 1 at spore_cloud_area.gd:42 (the optional argument keeps test_spore_cloud's 4-arg calls valid)
# SkillEffects.damage_reduction:  percent = Damage.combine_pct(percent, v)  (drop the mini(percent, 100))
# PlayerSkillSet.incoming venom:  out["percent_off"] = Damage.combine_pct(out["percent_off"], VENOM_PERCENT)
```

## C3. How every input feeds in

| Input | Effect |
|---|---|
| ATK | tackle and contact: raw = ATK. Skills: `value x (100 + 25 x (ATK - 1)) / 100`, min 1 |
| DEF | physical only, `armor_pct(DEF, power)`, capped 80%, always a slope; poison ignores it |
| Poison resistance | percent, multiplicative with Venom Blood, capped 85, also on ticks (fraction carried) |
| Flat (Hard Shell 1, Pain Resistance 1..6) | after the percents, min 1, as today |
| Player level | unchanged: +2 HP, +1 MP. Level buys survivability |
| Stage / form | unchanged: additive ATK/DEF (`STAGE_BASE`), skill cap `[5, 8, 12, 15]` |
| Skill level | indexes the same tables as today (Breath 2..16, Water Blade 3, spit 4), then the ATK amplifier; stage caps `[5, 8, 12, 15]` unchanged |
| Enemy level | `AREA_LEVEL[area] + spawn.lv`; HP, ATK, DEF, their skill modifiers, and their spit/puff numbers x `(100 + 8(L-1))%`; SPD and XP unchanged |
| Physical resistance | none; DEF is the physical stat |

## C4. Migration and before/after (real path for "before")

The grid ATK 1..5 x DEF 0..3 matches the old model in 19 of 20 cells; the one difference is ATK 4 vs DEF 3, 1 to 2. Every DEF-0 hit is identical.

| # | Hit | Before | After |
|---|---|---|---|
| 1 | Level-1 slime tackle vs toad (HP 3) | 1 | 1 |
| 2 | Level-10 slime tackle vs lizard (ATK 1, DEF 3, HP 5) | 1 | 1 (armor 78%, floors at 1) |
| 3 | Lizard (ATK 5) vs slime DEF 5 (Body Armor L5) | 1 | 2 (armor 55%) |
| 4 | Lizard vs slime DEF 2 | 3 | 3 |
| 5 | Bat (ATK 3) vs slime DEF 0 | 3 | 3 |
| 6 | Serpent (ATK 6) vs DEF 0 / DEF 1 | 6 / 5 | 6 / 4 (accepted: -1 at DEF 1 for an unspawned boss) |
| 7 | Toad spit application 4 vs Poison Res L2 (32%) with DEF 3 | 1 | 2 (armor ignores poison) |
| 8 | Toad ticks vs Poison Res L1 (20%), 3 s | 0 HP | 0.8/s, 2 HP over 3 s |
| 9 | Poison Breath L1, ATK 1 vs lizard | 1 | 2 (poison ignores armor) |
| 10 | Poison Breath L1, ATK 1 vs toad | 2 | 1 (toad's own 32% now applies) |
| 11 | Water Blade, ATK 5 vs lizard | 1 | 3 (raw 6, armor 38%) |
| 12 | Tackle ATK 4 (1 + eat cap 3) vs lizard | 1 | 2 |
| 13 | Poison Breath L15, ATK 8 (stage 4), no armor | 16 | 44 (24 at the stage-4 base ATK 3) |
| 14 | Level-28 lizard (ATK 16) vs stage-4 slime DEF 14 | 2 (needs hand-authored ATK 16) | 7 (armor 52%) |
| 15 | Stage-4 ATK-8 tackle vs level-28 lizard (DEF 9) | 1 | 3 |

Every table in `build_content.gd` stays as authored: at ATK 1 the skill amplifier is x1 and at level 1 `Levels.scaled` is the identity, so a fresh slime and the cave keep today's numbers. The only edits there are the Poison Resistance table, from `[20, 32, 42, 52, 60, 67, 73, 78, 83, 87, 90, 92]` to `[20, 32, 42, 52, 60, 67, 73, 78, 81, 83, 84, 85]` (L1-L8 unchanged and pinned; L10-L12 no longer clamped away by the 85 cap), and the poison_spit description. With Venom Blood, `combine_pct(78, 30) = 85` already hits the cap, so on the Toxic line PR L8 and above add nothing.

## C5. Tests

**New `tests/test_damage.gd`:** identity `hit(p, 0, 0, 0, true) == p`; `armor_pct(4, 5) == 50`, cap 80, monotone in DEF, decreasing in hit size; property loop (hit 1..60, DEF 0..80): result >= 1, non-increasing in DEF, `hit(40, 30, ...) == 20` (no plateau); the 20-cell legacy grid with its one difference; poison ignores DEF; `combine_pct(20, 30) == 44`, RESIST_CAP clamps at 85; `tick_milli(1, 20) == 800` and a `Player.tick` test that 3 s at 20% costs 2 HP; `Levels` (`power_pct` 100/140/316/388, `scaled(8, 6) == 11`, `scaled(0, n) == 0`, `for_spawn`); a level-6 enemy (crab HP 11, ATK 3, DEF 3; lizard DEF 4; toad spit `[6, 1]`, `[4, 1]` at level 1); `skill_power(v, 1) == v` for every Breath value, `skill_power(16, 8) == 44`, `skill_power(3, 8) == 8`.

**Stay green untouched:** `test_stats.gd:47-58` (functions kept), `test_player.gd:114-128` (DEF 0; `tick_milli(2, 0)` = 2000 per second), `test_enemy.gd:20,29-30`, `test_tuning.gd:54-60`, `test_levels.gd:75-82`, `test_player_skill_set.gd:43-46`, `test_skill_effects.gd:28-33`, `test_form_effects.gd:118,122` (single-source percents), and the enemy traces (`tests/support/enemy_trace_expected.json`, poisons `[[4, 1, 3.0]]`), because level-1 stats are unchanged.

**Green by the ATK-1 fallback:** `test_abilities.gd:52-54,62` and `test_aiming.gd:72` (stub actors have no `stats`, so hits stay 4 and 3). **Checked by grep, none break:** `test_spore_cloud.gd:38` (the toad's new 32% floors at 1, still hp - 1), `test_grotto_enemy_flags.gd:26` (crab and lizard tackles do 2), `test_levels.gd:149-152` (a cave bat, level 1). No test reads a grotto enemy from the full scene, asserts HP after a breath on a real toad, or sets a player DEF and then hits. The four `receive_poison` fakes keep their signature.

## C6. Files that change

`scripts/stats/damage.gd`, `scripts/stats/levels.gd` (new), `scripts/player/player.gd` (`:320-321`, `:620-621`, `:628-646`), `scripts/enemies/enemy.gd` (`setup`, `set_level`, `receive_hit`, contact `:289`, spit `:568`), `scripts/abilities/{ability,poison_breath,water_blade,spore_cloud_area}.gd`, `scripts/enemies/spore_puff.gd`, `scripts/core/skill_effects.gd:51,54`, `scripts/player/player_skill_set.gd:64`, `scripts/world/room_builder.gd:166-170` (call `set_level` when the node has one, next to `spawn_key`), `tools/build_content.gd` (Poison Resistance table, poison_spit description), `tests/test_damage.gd`. `direct_hit` and `tick` become dead code once both call sites move to `hit` and `tick_milli`: keep them until `test_damage.gd` carries the legacy grid, then delete them with their `test_stats.gd:47-58` pins. `Game._spawn` and the test spawn callables (`test_world.gd:24`, `test_progression_stages.gd:109`) keep their two-argument shape, and `setup()` keeps working at ~67 test call sites because level defaults to 1.

## C7. Risks

- **Small integers still floor.** With today's ATK <= 6 the curve changes little (row 2); it pays off once enemy raw is 16+ (rows 14-15). That is a resolution problem; multiplying all HP and damage by 10 later would fix it.
- **Out-levelling is intended.** DEF 3 removes 42% of a 5-hit but 16% of a 19-hit, and a stage-4 slime (DEF 14) takes 1 from cave lizards forever: the cave trivialises through the player's own stats, with no hidden level penalty. Whether a level-28 lizard (16 to a DEF-0 slime) gates a biome is an `AREA_LEVEL` decision, not a formula cliff.
- **Skills now grow with ATK.** Breath L15 is 16 at ATK 1, 24 at the stage-4 base ATK 3, 44 at ATK 8; a level-28 crab has HP 25, so a maxed stage-4 build one-shots it. `SKILL_ATK_PCT` is the knob (playtest, MP costs). The skill screen prints the raw table value (`skill_screen_model.gd:121-126`), so it says "Damage 6" for a Breath L5 that does 12 at ATK 5; showing the amplified number needs the player's ATK passed to `effect_lines`, left as an accepted mismatch.
- **Behaviour changes:** Body Armor no longer helps against toads (DEF is physical); Poison Resistance now reaches ticks.
- **Accepted deltas,** pinned in `test_damage.gd`: DEF 5 vs a 5-hit was 1 and is 2; ATK 4 vs DEF 3 was 1 and is 2; the serpent vs DEF 1 drops 5 to 4. Grotto fights get harder (level 6).
- **XP** stays flat (`creature_def.gd:18`); a level term belongs in a follow-up once levels ship.

## C8. What I would not adopt from Diablo 4

- **The bucket taxonomy** (additive, multiplicative, vulnerable, overpower, "damage to X" buckets). We have one stat bucket and no items; ATK-amplified tables plus flat modifiers are enough. Keep only the lesson: at most one small multiplicative baseline, the rest additive.
- **A hidden monster-level damage-reduction curve** (80% at level 70) and an undocumented armor constant: untestable. Our level enters through stats only and every constant is visible.
- **Armor that partly resists elements.** One physical stat (DEF), one poison stat (resistance).
- **World-tier resistance penalties, Overpower, Lucky Hit, Fortify.** No counterpart in a slime that grows by eating.
- **Player-level scaling of zones** ("play any content in any order"). Our areas are authored; a Metroidvania wants known gates.
