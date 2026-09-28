# Slime Isekai Prototype — Design

**Date:** 2026-09-27
**Status:** Draft for review (panel rounds 1–3, plus the essence/enemy-skills/stats redesign)

## Goal

A playable 10–20 minute prototype that proves the core loop is fun: you play a
reincarnated slime (in the style of *That Time I Got Reincarnated as a Slime*)
that gains hidden skills by doing things and by eating enemies, with surprise
"Great Sage" announcements and a skill compendium that persists across deaths.
Eating builds up **essences**: you must eat several creatures to learn a skill,
and some skills mix essences from different creatures. Enemies have stats
and use their own skills. The slime has stats too, shown on an anime-style
status screen.

**Done when:**
1. A player can complete a full run and unlock at least 6 skills, of which at
   least 3 come from hidden proficiency or evolution triggers (not eating),
   without being told the conditions. Appraisal never reveals exact conditions
   (see Compendium and Appraisal).
2. After dying, those skills and their revealed slot states appear in the
   Compendium.
3. On the next run, the player reaches a later room, or gets their first hidden
   unlock sooner. Both metrics come from the per-run log.

## Decisions

| Topic | Decision |
|---|---|
| Genre | 2D action platformer |
| Engine | Godot 4 (GDScript), GUT for tests |
| Structure | Roguelite: death resets the run; Compendium persists |
| Skill system | Event bus + data-driven rules; every skill, including eating skills, unlocks through `SkillRules` |
| Eating | Essence accumulation: each creature adds its essences, and skills unlock on essence totals (several eats per skill) |
| Enemies | Stats + a skill list they actually use, defined with the same `SkillDef` files as player skills |
| Stats | HP, ATK, DEF, SPD for everyone; the slime's stats grow from skills and eating (no XP levels) |
| Scope | Full content list (see Content); no cuts |

## Architecture

Six runtime areas.

1. **`EventBus` (autoload).** Declares one signal,
   `game_event(name: StringName, tags: Dictionary)`. Gameplay code calls
   `EventBus.game_event.emit(Events.JUMPED, {from = "ground"})`. It has no
   knowledge of skills. Event names are constants in `Events`, creature and
   terrain ids are constants in `Sources`, and essence names are constants in
   `Essences`. Emitters, validation and the debug check all use these lists.
2. **`SkillRules` (autoload).** The only owner of per-run skill state:
   - **Counters.** A small internal `Ledger` helper class holds counts per event
     and tag set for the current run.
   - **Owned skills and their levels.**
   - **Rule evaluation.** It loads one `SkillDef` resource per skill from
     `res://data/skills/`, and runs each incoming event through a **work queue**:
     1. Record the event in the Ledger.
     2. Evaluate the rules that listen to it.
     3. Each unlock or level-up appends an internal `skill_unlocked` /
        `skill_leveled` event to the queue. It is never emitted recursively.
     4. Repeat until the queue is empty.

     A hard cap of 64 iterations per incoming event fails loudly: `push_error`,
     and an assert in debug builds. The cap exists to catch bad data; shipped
     cascades are only a few steps deep. Parents are always processed before the
     children they unlock.

     **Re-entrancy guard:** an external event that arrives while the queue is
     draining (for example, emitted by a signal handler) is appended to the
     queue, never processed recursively.

   **API:**
   - `start_run()` grants every `starting: true` skill at Lv1, without announcing,
     and sets `run_active = true`.
   - `reset_run()` sets `run_active = false`, then clears counters, owned skills
     and the unlock log.
   - `progress(id) -> {current, target}` is **internal**: it's used for the
     Appraisal bands and is never shown as numbers.
   - `owned() -> Array` lists the skills owned this run.
   - `unlock_log() -> Array[{id, run_time_s}]` records unlocks this run, for the
     death screen and the run log.

   **Signals:**
   - `skill_unlocked(id)`
   - `skill_leveled(id, level)`
   - `run_started()`: emitted by `start_run()` after starting skills are
     granted, including on the very first run at launch.
   - `inspect_processed(tags, appraisal_level)`: emitted after the work queue for
     an `inspected` event drains. Reveals therefore always use the Appraisal level
     *after* that inspect.

   **Event gating:** events are ignored while `run_active == false`, for example
   during scene teardown and while the next run is generated.
3. **`SkillSet` (component on the player and on every enemy).** The effects
   layer, applying effects (see effect kinds) to the actor's `Stats`.
   - **On the player,** it reads owned skills and levels from `SkillRules`, and
     manages the two active slots.
   - **On an enemy,** it reads a fixed `{skill_id, level}` list from that
     enemy's `CreatureDef`. The enemy AI triggers actives through the same
     ability scenes. Enemies never go through `SkillRules`.
4. **`Stats` (component on the player and on every enemy).**
   - Base values: HP, ATK, DEF, SPD.
   - On the slime, eat bonuses are added for the run (see Stats).
   - Modifiers from `SkillSet` are applied on top.
   - Other code reads the final values through `Stats.get_stat(key)`, where `key`
     comes from `StatKeys`.
5. **`CreatureDef` resources** (`res://data/creatures/`), one per `Sources` id.
   Each holds:
   - base stats;
   - `essences` (e.g. `{poison: 1, water: 1}`);
   - `skills: [{skill_id, level}]` that the creature uses;
   - `eat_bonus: {stat, amount, per}`: the slime's stat gain. `per` defaults to
     1 (every eat). For example, `{def, 1, per: 3}` means +1 DEF on every 3rd
     lizard eaten;
   - `predatable`;
   - `appraisal_target: bool` (default true; false for the serpent). The
     `inspected` event copies it into its tag.
6. **`Announcer` + `Compendium`.**
   - `Announcer` shows Great Sage–style pop-ups for **unlocks only**:
     - The game doesn't pause. Each pop-up shows for 2.5 s with a chime, one at a
       time.
     - The queue holds at most 4 pop-ups. Further unlocks in the same burst are
       merged into one "+N more (see Compendium)" entry, so nothing is silently
       dropped and parents still show before children.
     - **Level-ups** appear on a small non-blocking ticker, never as pop-ups.
     - **Slot replacements** also appear on the ticker. `SkillSet` emits
       `slot_replaced(new_id, old_id)`, so a replacement notice is never lost in a
       "+N more" merge.
     - Both the queue and the ticker are cleared on death.
   - `Compendium` is the persistent knowledge store. It listens to all `SkillRules`
     signals, including `inspect_processed`; it doesn't listen to `EventBus`
     directly (see Compendium and Appraisal).

**Data flow:**
- gameplay → `EventBus.game_event` → `SkillRules` (counts, queue, rules) →
  `skill_unlocked` / `skill_leveled` → `SkillSet` (effects) + `Announcer` (pop-up
  or ticker) + `Compendium` (reveal and save).
- `inspected` → `SkillRules`, which drains its queue and then emits
  `inspect_processed` → `Compendium`, which uses the `SkillRules.progress()`
  bands and the new Appraisal level.

**Death / rebirth order:**
1. The death screen reads `SkillRules.owned()` and this run's unlock list.
2. The run log is appended.
3. `Announcer` is cleared.
4. `SkillRules.reset_run()`.
5. The new run is generated.
6. `SkillRules.start_run()`.

## Event vocabulary

**All events are edge-triggered:** one emission per state change or action,
never one per frame.

**Only the player emits to `EventBus`.** That means the player's components
and the ability instances the player owns. Enemy `Stats`, `SkillSet` and
ability scenes owned by enemies never emit. So damage dealt *to* enemies, or
skills enemies use, never touch the slime's counters. Each shared component
takes an `emits_events` flag, set only on the player. `damaged` is emitted by
the defender's `Stats`, so only the player's `Stats` emits it. Player-owned
ability instances emit only `skill_used`.

`Events` defines these names:

| Event | Emitted when | Tags |
|---|---|---|
| `jumped` | Jump input starts a jump | `{from: ground\|wall\|air}` |
| `wall_touched` | `is_on_wall()` goes false→true while `!is_on_floor()` | — |
| `damaged` | Once per damage application (DoT ticks do **not** emit) | `{damage_type: physical\|poison}` |
| `hp_low_entered` | HP drops below 30% of max, only while not already latched low | — |
| `hp_low_exited` | HP rises to 60% of max or more, after `hp_low_entered` | — |

The HP bands are re-evaluated whenever HP **or** max HP changes. Raising max HP
doesn't raise current HP.
| `stunned_enemy` | Tackle stuns an enemy | `{source}` |
| `predated` | Predation of a `Predatable` completes | `{source, kind: creature\|terrain}` |
| `absorbed` | Right after `predated`, once per essence **unit** of the eaten source (a pool's `water: 2` emits twice) | `{essence, source}` |
| `inspected` | Inspect used | `{target: self\|<source>, first_time: bool, appraisal_target: bool}` (`first_time` = first inspect of that target this run; the set lives in the player scene, which is rebuilt every run. `appraisal_target` is false for the serpent, so it never advances Appraisal) |
| `skill_used` | An active skill is activated | `{id}` |
| `skill_unlocked` | Internal, queued by `SkillRules` | `{id}` |
| `skill_leveled` | Internal, queued by `SkillRules` | `{id, level}` |

`Sources`: `bat`, `toad`, `lizard`, `spider`, `water_pool`, `serpent` (the boss,
which can be inspected but not eaten).

`Essences`: `sound`, `flight`, `poison`, `water`, `armor`, `earth`, `thread`.
`flight` and `earth` feed no skill in the prototype on purpose: they show on the
status screen and are reserved for later skills.

`StatKeys`: `max_hp`, `atk`, `def`, `spd`, `jump_height`, `slide_speed`,
`predation_time`, `regen_interval`.
- `max_hp`, `atk` and `def` are integers.
- `spd`, `jump_height`, `slide_speed` and `predation_time` are percents of base
  (base 100), so "−30%" means 70.
- `regen_interval` is in seconds.

**Counter matching:** `counter(event, tags)` sums every Ledger entry for that
event whose tags are a **superset** of the query tags. So
`counter(damaged, {})` counts all damage, and
`counter(damaged, {damage_type: poison})` counts only poison damage.

## `SkillDef` fields

- `id`, `display_name`, `description`, `hint`, `announce`
- `source`: `proficiency` | `essence` | `evolution` | `enemy_only` (used for
  display and validation). `enemy_only` skills, such as Flight or Tail Swipe,
  are used by creatures only. `SkillRules` never evaluates them and the
  Compendium never lists them. They need no `unlock`.
- `hidden`: bool. Essence skills are `false`, and are named by inspecting a
  creature that carries their essence (see Compendium and Appraisal).
  Proficiency and evolution skills are `true`.
- `starting`: bool (default false). Starting skills are granted by
  `start_run()` and may have an empty `unlock`. Every other skill needs at least
  one condition.
- `unlock`: a list of conditions, all of which must hold (AND). Condition kinds:
  - `counter(event, tags) >= n`
  - `reset_counter(event, tags, reset_on: event) >= n`: counts since the last
    `reset_on` event. Used for streaks such as Glutton.
  - `skill_level(id) >= n`: used by evolutions. Parents are not consumed.
- `listens_to`: **derived, not authored.** It is the set of event names
  referenced by `unlock` and `levels_on`, plus `skill_leveled` / `skill_unlocked`
  when there is a `skill_level` condition. Validation rejects internal event
  names inside `counter`, `reset_counter` or `levels_on`.
- **Levelling:**
  - Unlocking sets **Lv1** and emits only `skill_unlocked`.
  - `levels_on: {event, tags}` counts **only events after the unlock**:
    `SkillRules` snapshots the counter at unlock.
  - `level_curve`: the number of those events needed for each further level.
  - `max_level`. When `max_level == 1`, `levels_on` and `level_curve` may be
    omitted.
- `secret`: bool (default false). A secret skill is never listed by Appraisal
  and can only be discovered by owning it (Glutton).
- `effects`: a **list** of one or more effects, each of one of four kinds.
  Wherever an effect has `values: [lv1, lv2, …]`, validation requires exactly
  `max_level` entries.
  - `modifier`: a stat change, optionally scoped (e.g. damage taken, scoped to
    `damage_type: poison`), with `values`.
  - `conditional_modifier`: a modifier plus a condition (e.g. HP below 30%).
  - `capability`: a flag that player or world code checks (e.g. `wall_cling`,
    `reveals_hidden`), with an optional `min_level` and optional `values` (e.g.
    the reveal radius).
  - `active`: a path to an ability scene, with per-level values. `SkillSet`
    instantiates it as a child of the actor (the player or an enemy). The scene
    gets the actor reference and drives movement through a small `ActorMotor`
    API (`apply_impulse`, `set_state`). The same scene serves both sides: the
    serpent's Water Blade and the player's Water Blade are one definition. The
    actor also supplies its team and collision mask, so a projectile only hits
    the other side.
  - A `modifier` targets either a `StatKeys` key or scoped damage taken.
    Validation rejects any other target.
  - **A capability on an enemy is read by that enemy's AI:**
    - `reveals_hidden` means it detects the player in darkness (the bat's
      Echolocation).
    - The `enemy_only` capabilities are `flight` and `ceiling_walk`.
- `trigger` (optional): `{on: event, tags, action}`, e.g. Glutton's extra heal
  on `predated{kind: creature}`.

## Gameplay loop

1. Reborn as a weak slime at the cave entrance (base stats: HP 30, ATK 1,
   DEF 0, SPD 100). Tackle deals ATK damage and stuns for 3 s (tuned from 2 s after playtest). The stun timer doesn't expire during a
   predate hold. A cancelled hold leaves the remaining timer intact. The serpent
   can't be stunned.
   - **Damage math:** start from the attacker's ATK (or the skill's damage
     value), apply percent modifiers, then flat reductions including the
     defender's DEF, then floor. Direct hits deal at least 1. DEF and other flat
     reductions apply to direct hits only; DoT ticks take percent modifiers only
     and may reduce to 0.
   - **Downed enemies:** an enemy reduced to 0 HP is **downed**, not removed.
     A downed enemy stays predatable for 5 s without needing a stun, then
     vanishes. Like the stun timer, the downed timer pauses during a predate
     hold. A downed enemy runs no AI and deals no contact damage. The serpent at 0 HP
     is victory, not downed. A tackle that downs an enemy
     emits `stunned_enemy` as usual. So a strong tackle or an active never destroys a meal outright.
   - A reduced poison application still emits `damaged{damage_type: poison}`, so
     Poison Resistance keeps levelling.
2. Explore 8–12 rooms. Rooms are hand-authored chunks, and each non-boss chunk
   has 2–3 food slots. Generation is **constructive**, not shuffle-and-retry:
   1. Place the required chunks first:
      - The first **three** bats go within the first `ceil((n−1)/2)` non-boss
        rooms. At n = 8 that is 4 rooms, which leaves 3 rooms for passages.
      - The other minimums go into the remaining free slots in any room: ≥4 toads,
        ≥3 lizards, ≥3 spiders and ≥2 water pools per run. With the 3 bats, that is 15 food
        slots. Bonus rooms don't count toward these.
      - The smallest run has 7 non-boss rooms × up to 3 slots = 21 slots, so the
        placer picks chunks with enough slots.
   2. Fill the remaining rooms from the pool.
   3. The boss room is always last.
   4. Hidden passages, revealed by Echolocation, lead to optional bonus rooms that
      don't count toward the 8–12. Passages are built into their chunks, so the
      placer puts passage-bearing chunks only strictly after the third bat,
      because Echolocation needs 3 sound.
   5. If the chunk pool can't satisfy the rules, `push_error` and use a fixed
      authored fallback order.
3. Tackle enemies to stun them, then hold **Predate** (~1 s, vulnerable) to eat
   them:
   - Water pools are `Predatable` without a stun. They are **single-use** and
     disappear when eaten.
   - Every successful eat heals 5 HP, capped at max HP.
   - The eat emits `predated`, then one `absorbed` per essence unit, and applies
     that creature's `eat_bonus` to the slime's `Stats` (see Stats).
   - Poison **ticks** can't reduce HP below 1. The spit application is a normal
     hit and can kill.
4. Hidden thresholds trigger announcements as the player acts.
5. The boss room at the end: a large cave serpent.
6. On death or victory: the death/Compendium screen, then rebirth.

**Controls:**
- Move, jump, tackle, predate.
- Inspect (Appraisal). With no target in range, it inspects yourself.
- Active skill 1, active skill 2.
- **Cycle:** tap to rotate the last-used slot through all owned actives *not
  already in the other slot*.
  - The last-used slot defaults to slot 1.
  - With 0 or 1 owned actives, Cycle does nothing.
  - A Cycle updates the LRU stamp only. It never emits `skill_used`, so it
    can't farm levels.

Passive skills apply automatically.

**Active slots:**
- A newly unlocked active, evolutions included, fills an empty slot. Otherwise
  it replaces the least-recently-used active, and the ticker says so.
- An evicted active stays owned, and Cycle brings it back. So no owned active is
  ever frozen out of levelling.

### Creatures (`CreatureDef` starting values)

Contact damage = ATK (physical).

| Source | HP | ATK | DEF | SPD | Essences | Skills it uses (level) | Eat bonus to slime |
|---|---|---|---|---|---|---|---|
| Bat | 2 | 3 | 0 | 140 | sound 1, flight 1 | Echolocation (1): finds you in the dark; Flight (1, enemy-only) | +2 SPD |
| Toad | 3 | 3 | 0 | 70 | poison 1, water 1 | Poison Spit (1, enemy-only): 4 poison on application, then 1/s DoT for 3 s, every 5 s, 90 px range (tuned after playtest); Poison Resistance (2) | +1 max HP |
| Lizard | 5 | 5 | 1 | 80 | armor 1, earth 1 | Body Armor (2); Tail Swipe (1, enemy-only). Armored front: tackle only stuns from behind | +1 DEF per 3 eaten |
| Spider | 3 | 4 | 0 | 110 | thread 1, poison 1 | Sticky Thread (1); Ceiling Walk (1, enemy-only): drops from ceilings | +1 ATK per 3 eaten |
| Water pool | — | — | — | — | water 2 | — (terrain) | — |
| Serpent (boss) | 40 | 6 | 1 | 90 | — (not predatable) | Water Blade (1); Constrict (1, enemy-only). Can't be stunned | — |

## Stats

- **Everyone has four stats:**
  - **HP** (max HP).
  - **ATK:** tackle and contact damage.
  - **DEF:** a flat damage reduction; hits still deal at least 1.
  - **SPD:** move speed, as a percent of base.
- **The slime has no XP levels.** For the current run, its stats are:
  base + eat bonuses + skill modifiers.
- **Eat bonuses have caps per run:** max HP +10, ATK +3, DEF +2, SPD +20.
  Everything resets on death.
- Enemy stats come from their `CreatureDef`, plus their own skills' modifiers.
  For example, a lizard's Body Armor raises its DEF.

**Status screen:** inspecting yourself at any Appraisal level opens an
anime-style status screen showing:
- your current stats, with eat and skill bonuses shown separately;
- owned skills with their levels;
- the essence totals for this run;
- the Appraisal hints from Lv2 up (see Compendium and Appraisal).

## Mana (added after playtest)

- The slime has an MP pool: **20 max MP**, regenerating **1 MP/s**, scaled by the `mp_regen` stat (a percent of base 100).
- Every player active has an **MP cost**:

  | Skill | MP cost |
  |---|---|
  | Poison Breath | 4 |
  | Hydraulic Propulsion | 3 |
  | Water Blade | 5 |
  | Sticky Thread | 3 |
  | Swing Thread | 4 |
  | Jet Dash | 5 |

  A cast with too little MP does nothing, and the ticker says "Not enough MP". A cast blocked by the cooldown costs nothing.
- **Eating:** each creature eaten restores **4 MP**. Every 3rd creature eaten adds **+2 max MP** (an eat bonus, capped at +10 per run).
- **Events:** every MP point spent emits one `mana_spent` event, like `absorbed` per essence unit.
- **Mana Recovery** is a hidden proficiency skill:
  - Unlocks on `counter(mana_spent) >= 60`.
  - Levels on `mana_spent` every 60 MP after unlock, max 3.
  - Effect: `mp_regen` +50/100/150%.
- **StatKeys** gain `max_mp` (integer) and `mp_regen` (percent).

## Display (added after playtest)

- **Internal resolution:** a fixed 640×360, scaled to the window (`canvas_items` stretch, keep aspect).
- **Why:** text and pixel art scale together in fullscreen.
- **Camera:** zoom is 1.

## Skill screen and aiming (added after playtest)

**Skill screen** (approved concept: `art_source/skill_screen_concept.png`)
- **Opening:** Esc / Start opens it and pauses the game.
- **Skills tab:**
  - A stats panel: portrait, HP and MP bars, ATK/DEF/SPD, essence totals.
  - Owned skills grouped by Proficiency, Essence and Evolution, each with an icon, level and pips. A "???" row is shown where unowned, non-secret skills remain.
  - A detail card: description, MP cost, effect lines, a next-level bar, and a U/O slot badge.
- **Compendium tab:** every slot at its discovery state. The exact condition shows only once a skill is owned.
- **Controls:** Enter / A on an active assigns it to U, and pressing again assigns it to O. Q/E or LB/RB switch tabs. Esc / B closes.

**Aiming**
- Actives cast toward the held direction (stick, or W/S/↑/↓ with A/D), snapped to 8 ways. With nothing held, they cast forward.
- Keyboard jump is Space only.

## Character levels and evolution points (added after playtest)

This replaces the earlier "no XP levels" rule.

- **XP:** downing a creature gives XP, and eating it gives the same amount again. Values: bat 2, toad 3, spider 3, lizard 5, serpent 20; water pools give none. `CreatureDef.xp` holds the value.
- **Level curve:** Lv1 → Lv2 needs 10 XP, and each later level needs 5 more (10, 15, 20, …). Levels reset each run.
- **Each level-up gives:**
  - +1 Evolution Point (EP);
  - +2 max HP and +1 max MP. These are level bonuses, kept separate from skill modifiers and eat bonuses.
- **Evolutions no longer unlock automatically:**
  - When an evolution's conditions are met, `SkillRules` emits `evolution_ready` once. A Great Sage pop-up reads "Evolution available: [X] — N EP in Skills", and the Compendium names the slot.
  - The player evolves it on the skill screen by spending EP: 1 per parent skill (Water Blade 1, Swing Thread and Jet Dash 2).
- **Enemies** emit a direct `downed` signal (not an EventBus event) that awards the player XP.

## Four skill slots (added after playtest)

- **Buttons:** LB, RB, LT, RT on controller (triggers count at a half-pull); U, O, H, L on keyboard.
- **Removed:** the Cycle action. The D-pad's up and down aim instead.
- **Slot rules:** a new active fills the first empty slot, else replaces the least recently used. On the skill screen, Enter / A moves an active to the next slot.
- **Debugging:** F3 / Back toggles an input debug overlay showing the raw stick, the resolved aim and the last cast's direction.

## Content

These are starting values for tuning. The pacing column is a hypothesis, to be
checked against the per-run log.

### Proficiency skills

| Skill | Hidden trigger | Effect (per level) | Levels on (after unlock) | Expected unlock |
|---|---|---|---|---|
| Leap | `counter(jumped, {}) >= 40` | modifier: jump height +10/15/20/25/30% | `jumped` ×40/level, max 5 | rooms 1–2 |
| Wall Cling | `counter(wall_touched, {}) >= 15` | capability: `wall_cling`; slide speed −30/45/60% | `wall_touched` ×20/level, max 3 | rooms 2–4 |
| Poison Resistance | `counter(damaged, {damage_type: poison}) >= 6` | modifier: poison damage −20/35/50/65/80% | `damaged{damage_type: poison}` ×6/level, max 5 | rooms 3–6 |
| Pain Resistance | `counter(hp_low_exited, {}) >= 2` | conditional_modifier: below 30% HP, damage −1/−2/−3 (minimum 1) | `hp_low_exited` ×2/level, max 3 | mid–late run |
| Toughness | `counter(damaged, {damage_type: physical}) >= 20` | modifier: `max_hp` +3/+6/+9/+12/+15 | `damaged{damage_type: physical}` ×20/level, max 5 | mid run |
| Appraisal | Starting skill (`starting: true`) | See Compendium and Appraisal | `inspected{first_time: true, appraisal_target: true}` ×2/level, max 4 | — |
| Glutton (`secret: true`) | `reset_counter(predated, {kind: creature}, reset_on: damaged) >= 5` | modifier: predation time −30/45/60%; trigger: +3 HP on eating a creature | `predated{kind: creature}` ×5/level, max 3 (Lv3 may need bonus-room creatures) | rare on run 1 |

### Essence skills (from eating)

`source: essence`. Each unlocks on an eating counter, so every one of them
needs several eats. Most use `absorbed` essence totals; Regeneration counts
creatures eaten. A skill isn't limited to what one creature has: Poison Breath
accepts poison from toads **or** spiders, and Regeneration is a skill that no
creature has.

| Skill | Unlock | Satisfiable from minimums? | Effect (per level) | Levels on (after unlock) |
|---|---|---|---|---|
| Echolocation | `counter(absorbed, {essence: sound}) >= 3` (3 bats) | 3 bats ✓ | capability: `reveals_hidden`, radius values 1/2/3 | `absorbed{essence: sound}` ×1/level, max 3 (bonus-room bats) |
| Poison Breath | `counter(absorbed, {essence: poison}) >= 4` | 4 toads + 3 spiders = 7 ✓ | active: short-range poison cone; damage 2/3/4/5/6 | `skill_used{id: poison_breath}` ×8/level, max 5 |
| Body Armor | `counter(absorbed, {essence: armor}) >= 3` (3 lizards) | 3 lizards ✓ | modifier: DEF +1/+2/+3 (absolute per level, like every `values` row) | `damaged{}` ×10/level, max 3 |
| Sticky Thread | `counter(absorbed, {essence: thread}) >= 3` (3 spiders) | 3 spiders ✓ | active: thread that slows (Lv1–2) or holds (Lv3+) an enemy | `skill_used{id: sticky_thread}` ×8/level, max 5 |
| Hydraulic Propulsion | `counter(absorbed, {essence: water}) >= 4` | 2 pools × 2 + 4 toads = 8 ✓ | active: short water-powered burst; distance values 1/1.2/1.4/1.6/1.8 | `skill_used{id: hydraulic_propulsion}` ×6/level, max 5 |
| Regeneration | `counter(predated, {kind: creature}) >= 10` | 13 creatures ✓ | modifier: regen 1 HP every 8/6/4 s | `predated{kind: creature}` ×8/level, max 3 (Lv2–3 are intended to need bonus-room creatures) |

### Enemy-only skills

`source: enemy_only`, `max_level: 1`. The slime can't obtain these, and the
Compendium doesn't list them.

| Skill | Effect |
|---|---|
| Flight | capability `flight` (AI flies and ignores ground pathing) |
| Ceiling Walk | capability `ceiling_walk` (AI clings to ceilings and drops on the player) |
| Poison Spit | active projectile: 4 poison on application, then 1/s DoT for 3 s (tuned after playtest) |
| Tail Swipe | active melee: 5 physical and knockback |
| Constrict | active grab: a 3-physical direct hit each second for 2 s (DEF applies, minimum 1); jumping twice breaks free |

Validation: each `enemy_only` skill has `max_level: 1`, and no `skill_level`
condition may reference one.

### Evolutions

`source: evolution`, `hidden: true`, `max_level: 1`. Parents are kept.

| Skill | Unlock | Effect |
|---|---|---|
| Water Blade | `skill_level(hydraulic_propulsion) >= 2` | active: ranged water projectile, 3 damage |
| Swing Thread | `skill_level(sticky_thread) >= 3` AND `skill_level(wall_cling) >= 2` | active: grappling hook |
| Jet Dash | `skill_level(hydraulic_propulsion) >= 3` AND `skill_level(leap) >= 2` | active: long horizontal dash |

**Reachability check:**
- Hydraulic Propulsion reaches Lv3 after 12 uses. Water Blade takes a slot at
  Lv2, but Cycle keeps Hydraulic Propulsion usable.
- Leap reaches Lv2 at 80 jumps.
- Sticky Thread reaches Lv3 after 16 uses.
- Wall Cling reaches Lv2 at 35 wall touches.
- Sticky Thread needs 3 spiders, and Hydraulic Propulsion needs 4 water.
  Placement guarantees both.

## Compendium and Appraisal

- The Compendium lists **every** non-`enemy_only` `SkillDef` as a slot from the
  first launch. Each
  slot's state only ever increases:
  `unknown → named → hinted → owned-once`.
  Only owning a skill reveals its exact condition, which is shown on
  `owned-once` slots.
- **Appraisal** levels once for every 2 distinct targets inspected this run
  (`first_time` and `appraisal_target` only). Yourself counts as one target;
  the serpent doesn't count. So repeated presses can't grind it.
  - **Inspecting a creature reveals more at each level:**
    - **Lv1:** its name and HP.
    - **Lv2:** also its stats, essences and eat bonus. Every essence skill that
      uses one of those essences goes to `named`. A water pool shows only its
      essences.
    - **Lv3:** also its full skill list, including enemy-only skills. Listed
      skills that are neither secret nor `enemy_only` go to `named` (for
      example, a toad shows Poison Resistance).
    - The Lv2 and Lv3 naming steps apply only when the inspect has
      `appraisal_target: true`. So a target with `appraisal_target: false` (the
      serpent) shows its info but never names a Compendium slot. Its Water Blade
      stays unnamed.
    - A self-inspect always emits `appraisal_target: true`.
  - **Lv2:** inspecting yourself adds, on the status screen, locked, non-secret
    proficiency and essence skills that are at least `ceil(50%)` of the way to
    unlock. Progress is shown
    only as a **qualitative band**, never as numbers: "Something stirs when you
    jump…" at 50% or more, "…it's close" at 80% or more. Those slots go to
    `named`.
  - **Lv3:** the same list also shows each skill's hint, and the slots go to
    `hinted`.
  - **Lv4:** inspecting yourself also names evolutions whose parents are all
    owned ("Hydraulic Propulsion could become more…"). Those slots go to `named`.
- Lv4 needs all 6 pre-boss targets (yourself and all 5 sources). This is
  intentional: it's a completionist reward.
- **Starting skills** (Appraisal) are marked `owned-once` by the Compendium when it receives `run_started`, by
  reading `SkillRules.owned()`.
- The Appraisal level itself is run state and resets on death. Slot states
  **ratchet** into the Compendium and persist.
- **Save timing:** write on every slot-state change. The save path is a
  constructor parameter, so tests use a temp path, not the real save.
- **Save safety:**
  1. Write `compendium.json.tmp`.
  2. Verify it by reading it back and parsing it.
  3. Rename it over `compendium.json`.

  The file carries a `version` field.
- **Loading:**
  - Parse only with `JSON.parse_string`, never `str_to_var` or `bytes_to_var`.
  - Type-check the parsed data: the top level must be a Dictionary, `version`
    must match, and every slot state must be one of the 4 enum values.
  - Drop skill ids that aren't in the loaded `SkillDef` set, and drop
    `enemy_only` ids.
  - If `compendium.json` is missing or corrupt but a valid `.tmp` exists, adopt
    the `.tmp`. A corrupt main file is moved to a timestamped `.bak` first. On Windows, Godot's rename is remove-then-rename, so this case can
    happen.
- **Corrupt or mismatched file:** move it to
  `compendium.<timestamp>.bak`, start a fresh Compendium, and log a warning. It
  is never silently overwritten.
- Run state is not saved; quitting mid-run ends the run. Discoveries made
  during it are already saved.
- **Per-run log:** one JSON line per run, appended to `user://runs.jsonl`:
  `{run, rooms_reached (ordinal), first_hidden_unlock_s, skills_owned, death_cause}`.

## Error handling

- At startup, `SkillRules` validates every `SkillDef`:
  - Required fields are present, taking the `max_level == 1` and `starting`
    rules into account.
  - Event names come from `Events`, source tags come from `Sources`, and
    essence tags come from `Essences`.
  - Every `CreatureDef` is valid:
    - its essences are in `Essences`;
    - its skill ids exist, at levels within their `max_level`;
    - every `Sources` id has exactly one `CreatureDef`;
    - `appraisal_target` is a bool, and false only on non-predatable sources.
  - `enemy_only` skills have no `unlock` and have `max_level: 1`. Every other
    non-starting skill has an `unlock`. No `skill_level` condition references an
    `enemy_only` skill.
  - Every `modifier` target is a `StatKeys` key or scoped damage taken, and
    every `eat_bonus.stat` is a `StatKeys` key.
  - Each `values` array has exactly `max_level` entries.
  - No internal event names are used in counters or `levels_on`.
  - `skill_level` references point at existing ids.
  - The skill-level dependency graph has no cycles.
  - `active` scene paths exist.
  - Any failure → `push_error` with the file path, then quit (debug and
    release). No partial rule set ever runs.
- If an event name isn't in `Events` at runtime, it's logged once per name in
  debug builds.
- The work-queue iteration cap (64) → `push_error`, and an assert in debug.

## Testing

- **GUT unit tests (headless):**
  - **Ledger:** superset tag matching; `reset_counter` resets on its event and not
    on unrelated events.
  - **SkillRules:**
    - Unlocks at n and not at n−1.
    - Level baseline: Leap is Lv1 at 40 jumps and Lv2 at 80. Body Armor
      unlocked after 30 hits starts at Lv1.
    - Levelling stops at `max_level`.
    - The essence unlock path: poison from toads and spiders sums; a pool emits 2 `absorbed{water}`; 2 bats do not unlock Echolocation and 3 do.
    - `skill_level` unlocks, and cascade order (parent before child).
    - Each skill unlocks exactly once.
    - The iteration cap.
    - `listens_to` derivation: a rule is not evaluated on unrelated events.
    - `start_run()` grants Appraisal without an unlock signal.
    - `reset_run()` clears state but leaves the Compendium untouched.
    - Events are ignored while `run_active == false`.
  - **Evolution reachability:** drive the real `SkillSet` slot rules and Cycle
    with synthetic input, then assert that Water Blade, Swing Thread **and** Jet
    Dash can each be reached, including Hydraulic Propulsion reaching Lv3 after
    Water Blade unlocks.
  - **Emitters:** using a stub body and a stub health component:
    - `wall_touched` fires once per contact.
    - `hp_low_entered` / `hp_low_exited` fire once per crossing, and an exit
      requires a prior entry.
    - Poison ticks stop at 1 HP.
    - Eating heals and is capped at max HP.
    - A water pool is single-use.
    - Glutton ignores pools, and Glutton's +3 HP trigger fires.
    - `hp_low_entered` doesn't re-fire while latched low.
    - Damage math: percent, then flat, then floor; direct hits deal at least 1.
    - Ticks ignore DEF.
    - A reduced poison application still emits `damaged`.
  - **Effects:**
    - A scoped modifier affects poison damage only.
    - A conditional modifier turns on below 30%.
    - Capability `min_level` gates the flag.
    - Per-level values are applied.
  - **Compendium:**
    - Save/load round-trip, written on unlock.
    - Verified atomic write, and `.tmp` recovery.
    - Type- and enum-checked load; a non-Dictionary is treated as corrupt, and
      the corrupt file is preserved as a timestamped `.bak`.
    - Unknown ids are dropped.
    - Slot states ratchet across a simulated death.
    - Inspect reveal rules at each Appraisal level, including the exact inspect
      that raises the level (the reveal uses the new level).
    - Bands show no numbers.
    - Secret skills are never listed.
    - Starting skills are marked `owned-once` on `start_run()`.
    - The `ceil(50%)` boundary.
    - Repeated inspects of the same target don't level Appraisal.
  - **Announcer:**
    - Order, and one pop-up at a time.
    - Overflow merges into "+N more".
    - Level-ups go to the ticker only.
    - Cleared on death.
  - **Active slots:**
    - Filling an empty slot, and LRU replacement with a `slot_replaced` notice.
    - Cycle order with 2 slots and 3 owned actives: no duplicates.
    - Cycle with 0 or 1 owned actives does nothing.
    - `run_active` is toggled by `start_run` and `reset_run`.
    - `unlock_log()` timestamps.
  - **Effects validation:** a compound effect (Wall Cling) loads, and a `values`
    array of the wrong length fails.
  - **Stats:**
    - Final value = base + eat bonus + modifiers.
    - Eat bonuses stop at their caps.
    - "Per 3 eaten" bonuses apply on the 3rd eat, not the 2nd.
    - DEF lowers damage, with a minimum of 1.
    - Everything resets on death.
  - **Enemy skills:**
    - An enemy's `SkillSet` instantiates its `CreatureDef` skills at the listed
      levels.
    - A lizard's Body Armor raises its DEF.
    - An `enemy_only` skill never appears in `SkillRules` or the Compendium.
    - The serpent's Water Blade and the player's share one ability scene, and
      each side's projectile only hits the other side.
    - **Actor boundary:** an enemy taking damage, or using a skill, produces no
      Ledger entry. The player's Poison Breath hitting a toad produces only
      `skill_used`, never `damaged`.
    - A bat's `reveals_hidden` makes its AI detect the player in darkness.
  - **Downed enemies:**
    - An enemy at 0 HP is downed and predatable without a stun for 5 s, then
      vanishes.
    - The downed timer pauses during a predate hold.
    - A downed enemy runs no AI and deals no contact damage. The serpent at 0 HP
     is victory, not downed.
    - Toughness unlocks at 20 physical hits and not at 19, and raises max HP.
      Poison hits don't count toward it.
    - Eating a downed enemy emits the same `predated` and `absorbed` events as
      eating a stunned one.
    - Regeneration counts creatures and ignores pools.
  - **Inspect:** the serpent never advances Appraisal and never names a slot. A Lv3 creature inspect
    names that creature's non-secret, non-`enemy_only` skills.
  - **Re-entrancy:** an event emitted from a `skill_unlocked` handler is queued,
    not processed recursively.
  - **Other checks:**
    - Cycle never emits `skill_used`.
    - The stun timer doesn't expire during a predate hold.
    - A `slot_replaced` notice lands on the Announcer ticker.
  - **Status screen:** it shows stats with bonuses split out, owned skills with
    levels, and essence totals. Creature inspect reveals name and HP at Lv1,
    stats and essences at Lv2, and skills at Lv3.
  - **Room generation:** the placement rules hold for 200 seeds, including all 3
    bats before any passage chunk; generation never
    retries; an impossible chunk pool falls back with an error.
  - **Run log:** one well-formed line per run.
- **Data validation test:** loads every `SkillDef`, asserts that all of them pass,
  and asserts that deliberately broken fixture defs fail. The fixtures cover:
  - a missing field
  - an unknown event
  - an internal event used in a counter
  - a cycle
  - an evolution without `max_level`
  - an empty directory
  - a `CreatureDef` with an unknown essence
  - a `CreatureDef` with a skill above its `max_level`
  - an `enemy_only` skill with an `unlock`, or with `max_level` above 1
  - a `CreatureDef` with an unknown skill id
  - a missing or duplicate `CreatureDef` for a `Sources` id
  - a `skill_level` condition that references an `enemy_only` skill
  - a `modifier` target that isn't in `StatKeys`
  - an `eat_bonus.stat` that isn't in `StatKeys`
- **Scripted run test:** feeds a synthetic event sequence that exercises at least
  6 unlocks, including a streak broken by `damaged`, a `skill_level` evolution,
  and a death. Then it starts a second run and asserts that the Compendium kept
  the slot states and that Appraisal was re-granted.
- **Manual playtest checklist:**
  - Jump feel.
  - Predation timing.
  - Pop-up readability, including during the boss fight.
  - A full run lasts 10–20 minutes.
  - The run log reports rooms reached and time to first hidden unlock.

## Out of scope

- Final art (placeholder shapes and sprites only)
- Sound and music, apart from the announcement chime
- Additional biomes, NPCs, story, monster naming, humanoid form
- Input remapping, settings menus, an active-skill equip menu (Cycle replaces it)
- Balancing beyond a playable 10–20 minute run
