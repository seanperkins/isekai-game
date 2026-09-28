# Slime Forms, Animation, Reincarnation and the Next Location — Design

Status: revised after a six-reviewer panel (2026-09-28). Builds on
`2026-09-27-slime-prototype-design.md` and `2026-09-28-exploration-world-design.md`.

## Goal

Make the slime feel alive, give a run a long arc, and make a bigger world cheaper to revisit
(you choose where to be reborn). The slime gets real animation (running, jumping, climbing,
spreading flat, and eating by covering its prey). Enemies die in ways that match how they
were killed. The slime evolves through a branching tree, spider-anime style, with skill
levels held back until it does. The Fungal Grotto is built last, on the new art and kit.

This is five sub-projects, each its own plan that ends in something you can play. The order
is fixed by your answers.

| # | Sub-project | Ends with |
|---|---|---|
| 1 | Slime feel: art pipeline, animation set, spread, eating cover, no torches | A slime that moves and eats with drawn animation |
| 2 | Enemies: individual sprites and kill-type death animations | Every enemy has frames, and dies to match the blow |
| 3 | Evolution: stages, forms, level cap, skill caps, raised skill maxima | You can evolve a slime through the tree |
| 4 | Reincarnation: rebirth pools, kits, the choice logic | Dying can send you back to any unlocked pool |
| 5 | Fungal Grotto (Plan 2 of the exploration spec) | The next location, with its rebirth pool and the menu UI |

## Decisions

| Topic | Decision |
|---|---|
| Sprite production | Generate every frame **individually**, then a tool assembles frames into sheets. A whole sheet is never generated in one shot |
| Torches | None anywhere in the wilderness. Light comes from glowing fungus, lichen and crystals. Human-made things (tablets, cracked stone) stay, and an unlit brazier may mark an abandoned camp later |
| Order | Slime feel → enemies → evolution → reincarnation → Fungal Grotto |
| Evolution structure | Spider-style choice: at the stage cap you pick one of 2–3 offered forms |
| Stages | 4 stages. The level cap is 10 per stage, and your level resets to 1 on evolving |
| First-stage lineages | Weaver (thread), Tide (water), Toxic (poison + spore), Bulwark (armor + earth + shell), Echo (sound + flight) |
| Skill levels | Capped by stage: max Lv5, 8, 12, 15. Levelling player skills get a higher max (up to 15, chosen per skill). Progress is kept, so evolving unlocks the next levels |
| Reincarnation locations | Distinct rebirth pools, unlocked by finding them, kept across runs. Glow Pools stay rest-only |
| Reincarnation power | A small head start sized to the location (a few basic skills, some character levels, seeded affinity), not a full reset and not a full carry-over |
| Species | Slime only. A `species` id is carried through the run and the save so a later species needs no migration. The `SpeciesDef` resource is added when a second species is designed |
| Reincarnation UI | On the death card, with the last choice pre-selected. The menu UI ships with the second pool (Sub-project 5) |

## What the reviewers changed

The first draft was reviewed by six reviewers and every one said "revise". The spec below is
the corrected one. The biggest corrections:

- **XP economy.** Level 10 needs **270 XP**, not 325. One pass through the Cave pays **62 XP**
  (124 if you also eat everything), not 180, and respawn-on-entry made it unbounded. The
  pacing gate is now respawn XP that dwindles (3.1).
- **Skill maxima.** "Every skill to 15" would fail the game's own startup check. It is now a
  per-skill maximum for skills that actually level (3.4).
- **Spread.** Every attack aims at the slime's centre and ends at floor level, so a flat slime
  cannot dodge any of them, and a strict rect-overlap contact rule would have stopped contact
  damage entirely. Spread is now a pose, not a defence, and hits are unchanged (1.2).
- **Reincarnation state.** The `Run` node is rebuilt on every scene reload, so the choice now
  lives in an autoload and the Profile (5.5).
- **Kill causes.** Only `tackle`, `blade` and `poison` have a live source today. `blast` is
  reserved (2.2).
- **Tree gaps.** The fallback form and stage 3→4 had no defined path (3.2, 3.3).

## 1. Slime feel

### 1.1 Movement states and frames

The slime picks one state each frame. The first match in this order wins.

| State | When | Frames | Notes |
|---|---|---|---|
| `cover` | Eating (predation active) | 5 | See 1.3 |
| `hurt` | Just hit (the invulnerable flash) | 1 | Squashed and recoiling |
| `rope` | Hanging from a thread | 1 | Stretched toward the anchor |
| `wall` | Clinging (Wall Cling, airborne, holding into the wall) | 2 | Slides down slowly. A second frame shows the grip shifting |
| `tackle` | The tackle dash | 1 | Stretched flat and fast |
| `spread` | Down held on the floor | 2 | See 1.2 |
| `rise` | Airborne, moving up | 1 | Stretched tall |
| `fall` | Airborne, moving down | 1 | Wider at the bottom |
| `land` | Just landed (0.12 s) | 1 | Squashed flat (exists today) |
| `run` | On the floor, moving | 4 | A squelching loop at 10 fps |
| `idle` | Otherwise | 2 | A slow "breathing" wobble at 3 fps |

That is 21 frames per body. Wall climbing keeps today's rules (slide slowly, Space to jump
off). The new frames only show what is already happening. **The wall frame is flipped from
the wall's normal** (`get_wall_normal()`), not from `facing`: to cling you hold *into* the
wall, so `facing` points at it, and the grip has to be drawn on the wall side.

### 1.2 Spread

- Hold **down** on the floor and the slime flattens into a puddle. "Down" is derived from the
  same inputs as aiming down (S, ↓, D-pad down, left stick), so no new binding is needed.
  Spread starts when the grounded slime's snapped aim is **straight down**: `resolve_aim`
  returns `Vector2.DOWN`, and for a stick the raw `y ≥ 0.6` too. That uses the aim code's own
  22.5° window (no second constant to drift), so running diagonally, or S + D on the keys,
  does not spread. Once spread, the slime stays spread while `y ≥ 0.6`, whatever `x` is, so a
  spread crawl with the stick is not limited to the tiny sideways range left in the window.
- Movement is half speed.
- **Spread is a pose and a traversal tool, not a defence.** Every attack in the game aims at
  the slime's centre and ends at floor level (a bat's dive runs until it touches the floor, a
  glob lands on the slime's origin), so a puddle on that floor is inside every strike. Damage
  checks are **unchanged** (`CONTACT_RANGE` and the glob radius stay as they are, measured
  from the slime's origin). The pose exists for the look and for low gaps in later rooms.
- **The collision shape is re-centred** whenever its height changes (12 px normal, 5 px
  spread), so its bottom stays at `BODY_BOTTOM`. Without that, the body would float 3.5 px
  and `is_on_floor()` would flicker.
- Standing up needs room: if something solid is within 7 px above, the slime stays spread until
  it clears.
- **Spread and aiming down share an input, on purpose.** A grounded slime that aims a skill
  straight down squashes into the puddle first and casts from it. That is cosmetic, because
  spread changes neither the aim vector nor the hit checks.
- Jump while spread stands the slime up and jumps in the same press, unless something solid is
  within 7 px above (then the slime stays spread and does not jump). Skills still work.
- Entering the pose takes two frames (a quick squash). Leaving it takes the same in reverse.
- A low gap only a spread slime can pass is a level-design tool for later rooms. None ships in
  this pass.

### 1.3 Eating by covering

The old animation pulls the prey toward the slime like a vacuum. The new one covers it:

1. **Lunge (frame 1):** the slime leaps up and over the target.
2. **Drape (frame 2):** it settles over the target like a blanket. The slime's translucent body
   shows the enemy's silhouette inside.
3. **Engulf (frames 3–4, looping):** it pulses while the eat bar fills. The enemy inside
   shrinks as progress rises.
4. **Release (frame 5):** on completion, the slime pops back to its normal shape and the
   creature is gone. If the hold is cancelled, the slime peels back and the enemy is
   still there.

How it works, without moving the body:

- The slime's **body does not move** during the hold: input is already zeroed, and both
  bodies are `CharacterBody2D`s on the same layer, so moving one onto the other would just
  stop at the edge. The hold already requires the target within 32 px.
- An `EatCover` node is added at the target's position for the hold. It hides the slime's own
  sprite **and the prey's own sprite**, then draws a copy of the prey's sprite (scaled from
  100% to 20% by progress) with the cover frames over it. The prey's node stays where it is,
  and its sprite shows again if the hold is cancelled.
- On completion or cancel, `EatCover` frees itself and the slime's sprite shows again.
- Every death effect (2.2) ends by settling into the creature's single `downed` pose, so the
  prey is always one sprite when it is eaten.

### 1.4 Torches out, glow in

- Every `torch` decor entry becomes a natural light. The choice depends on the spot: glowing
  fungus on the floor, hanging lichen under ledges, a crystal cluster on walls.
- New decor sprites (each generated individually): `glow_fungus` (2 variants), `lichen_hang`,
  `wall_crystal`. Each carries a soft `PointLight2D`.
- The lights keep their palette (teal, purple, blue, and a warm amber for the fungus). Fire
  orange goes away except in a human place, and there are none in the Cave.
- The sweep touches: the six `torch` entries in `tools/build_world.gd` (and the `FIRE`
  constant, which becomes unused), the generated `data/rooms/C1–C5.tres`, the `torch` entry
  in `tools/art/manifest.json`, `assets/sprites/torch.png` (and its import), and the comments
  in `art.gd` and `room_builder.gd`. A test asserts that no room decor id is `torch`. (The
  playtest checklist has no torch lines to update.)

### 1.5 The art pipeline

Every frame is one image, generated with Codex one at a time, then assembled.

```
tools/art/frames.json           every frame: name, prompt, reference frame, size, set
art_source/frames/<name>.png    one Codex image per frame on a magenta key (gitignored)
tools/art/generate_frame.sh     one frame → art_source/frames/<name>.png (uses image-generation)
tools/art/assemble_sheet.py     frames of one set → assets/sprites/sheets/<set>.png + <set>.json
scripts/ui/sprite_sheet.gd      SpriteSheet: loads a sheet + its json, returns frame textures
scripts/actors/animator.gd      Animator: plays a named clip (frames + fps + loop) on a Sprite2D
```

- **A spike comes first.** Before anything is built around the pipeline, Sub-project 1
  generates just the slime's 4-frame run cycle individually and you review it as a contact
  sheet. The risk is frames that drift from one another (jitter, a body that changes
  volume). If the spike is not good enough, the fallback is to generate a small clip as one
  image (a 2×2 sheet of that single clip) and still approve it frame by frame.
- **Consistency:** each generation gets the canonical `slime_idle` as a reference image, its
  neighbours in the clip once they exist, and a fixed style prompt (Style D, the same
  translucent blue, the same inner glow, facing right).
- **Keying and fitting:** the existing keying, box-filter downscale and alpha threshold from
  `slice_sheets.py` are reused, so frames match today's pixel look.
- **Assembly:** frames of a set are packed in a grid, and the JSON records each frame's cell,
  size, and its baseline (`bottom`) so feet line up across frames.
- **Review:** the first round for each set is a contact sheet of every frame, shown to you for
  approval before anything ships. A frame you dislike is regenerated alone.
- **Fallback:** a missing frame falls back to the closest existing pose, so the game runs with
  a partly generated set. A whole missing **form** is different (see 3.2).
- **Safety:** prompts and names come from `frames.json`. The script passes them as arguments
  or on stdin, never interpolated into a shell string, and validates each `name` against
  `^[a-z0-9_]+$`, since it becomes a filename.
- **Two loaders, on purpose:** `Art.texture` stays for icons, tiles and decor. The slime and
  the creatures move to sheets. Afterimage effects use the current frame's texture. The count
  asserted in `tests/test_art_assets.gd` is updated with the manifest.

### 1.6 Code

- `SlimeState.pick(...)` is a pure static function (like `Player.pick_frame`): inputs are
  eating, hurt, roped, wall, dashing, spread, on_floor, vertical speed, land timer, and
  speed; output is a state name. It is unit tested for every row of the table.
- `Animator` maps state → clip and advances frames from `_process`. `Player._update_visual`
  calls it instead of `Art.set_frame`.
- `Player` gains `spreading` (with the rules from 1.2).
- The eating cover is the small `EatCover` node from 1.3.

## 2. Enemies: sprites and kill-type deaths

### 2.1 Sprites

Each creature gets individually generated frames, assembled by the same pipeline:

| Creature | Frames |
|---|---|
| Bat | fly ×4, hover ×2, dive ×1, stunned ×1, hurt ×1 |
| Toad | idle ×2, walk ×3, puff ×2, spit ×1, stunned ×1, hurt ×1 |
| Lizard | idle ×2, walk ×4, windup ×2, charge ×3, rest ×2, stunned ×1, hurt ×1 |
| Spider | hang ×2, drop ×1, crawl ×4, stunned ×1, hurt ×1 |
| Serpent | reserved for its own plan |

The AI already has states for these: the telegraph states map onto the wind-up and rest
frames, and the eat window is the `STUNNED` state, which gets its own frame. Each creature
also gets one **downed** pose, drawn once.

### 2.2 Death matches the blow

The killing blow carries a `cause`, so the effect can match it. Only causes with a live source
today are built:

| Cause | Comes from | Death |
|---|---|---|
| `tackle` | The slime's tackle | The creature is knocked back in an arc, spins, and lands on its back |
| `poison` | Poison Breath (a direct hit) | The body slumps, turns green, and melts into a puddle over 1 s |
| `blade` | Water Blade | Cut in two along the blade's angle. The halves slide apart and fall |
| `other` | Anything else | The downed pose |

Reserved, built when a source exists: `blast` (Hydraulic Propulsion and Jet Dash only push
the slime today, and do not damage anything) and `shock` (Jolt, in the Flooded Tunnels plan).
Enemies also have no poison-over-time, so "poison ticks" is not a source.

- **Signature:** `receive_hit(raw, damage_type, from = Vector2.INF, cause = "")` on all three
  implementors. `Player` and `ShortcutSwitch` already take `from` as the third parameter, so
  `cause` is their fourth. `Enemy.receive_hit` takes only two today, so it gains **both**
  `from` and `cause`. A caller that passes no cause gets one derived from `damage_type`
  (`poison` → `poison`). Water Blade and Poison Breath now pass the attacker's position as the
  third argument and the cause as the fourth (`"blade"` and `"poison"`). Without both, the
  cause would be read as the position. `receive_tackle(atk, from_behind, from = Vector2.INF)`
  gains the tackler's position (the knockback needs a direction) on **both** `Enemy` and
  `ShortcutSwitch`, since the player tackles anything in the `actors` group, and a call with
  one argument too many would be a runtime error on the switch. `Enemy` passes `tackle`. The
  enemy stores the cause **before** `health.take_hit`, because `_on_died()` takes no arguments.
- **The effects are procedural** on the creature's own sprite (a shader for the melt, a
  two-sprite split for the cut, a tumble for the knockback), so all creatures share them and
  none needs its own frames. Only the downed pose is drawn per creature.
- **A new `DYING` status.** `EnemyStatus` gains a fifth state, entered in `_on_died`. While
  `DYING` the creature is not active (no AI, no contact damage, no spit), is **not
  predatable**, and ignores `receive_hit`, `receive_tackle` and `receive_thread`. It has no
  timer, and `EnemyStatus.update()` must skip it (an unlisted state would count its zero timer
  down and become `GONE` on the first frame). The `downed` signal fires on **entering**
  `DYING`, so XP and the Bestiary update at once. A lethal tackle still counts as a stun-or-down
  for `stunned_enemy` (`receive_tackle` returns true for `DYING` as well as `DOWNED`). When the
  effect ends the enemy calls `down()`, which starts the 5 s eat window. Without this
  state a dying creature would keep attacking, could be stunned into `STUNNED` (edible while
  it is mid-effect and back on its feet afterwards), or start its eat timer too early.
- **The effect owns the body while it plays.** During `DYING` the enemy's per-frame code does
  not zero the velocity or overwrite the sprite's tint and flip. **Only the tackle death
  moves the body**: it moves at most 24 px and settles on the ground within 28 px of where the
  tackler stood at the kill (never off a ledge), so it is inside eat range (`PREDATE_RANGE` is
  32 px). Blade, poison and other kills leave the body where the effect ends (a Water Blade
  kill can be 160 px away), as today, and you walk over to eat it. A test checks the final
  distance for tackle kills only.
- **Every effect ends in the creature's `downed` pose** (a single sprite), so eating works the
  same for every kind of death.
- **The 5 s eat window starts when the effect ends**, not when the creature dies.

## 3. Evolution

### 3.1 Stages, level and XP

- Four stages: Slime → (2) Form → (3) Greater form → (4) Sovereign.
- The level cap is 10 per stage. At the cap, XP stops (extra XP is discarded) and the game
  says "Your body can evolve." Evolving resets your level to 1 in the new stage.
- **XP curve.** Today `xp_to_next(level) = 10 + 5 × (level − 1)`, so reaching level 10 needs
  **270 XP**. Each stage multiplies that curve by 1, 1.5, 2 and 2.5, **rounded down per
  level**, so a stage costs 270, 403, 540 and 673 XP (1886 in all). `Progression` gains a
  `stage` field, and `xp_to_next` gains a `stage` argument (default 1), which its callers (the
  HUD, the skill screen, `add_xp`, the tests) pass.
- **The Cave cannot be farmed to the cap.** One pass through the Cave pays **62 XP** for
  downing everything and **124** if you also eat everything. Because rooms respawn their
  enemies on every entry, this used to be unbounded. Now every spawn point has **two separate
  first-time rewards**, one for the first down and one for the first eat, each **full**. Any
  repeat pays **`floor(xp / 4)`**: bats (2) and toads and spiders (3) pay 0, lizards (5) pay 1.
  A full repeat lap through the Cave (4 lizards, down and eat) pays 8, so after the 124 of a
  first pass the remaining 146 XP takes about 19 laps. The cap is reachable in the Cave only by
  a long grind, which is the point.
- **Spawn identity.** A spawn point is `"<room id>:<index>"` (its position in the room's spawn
  list). `Enemy` carries it as `spawn_key`, and it is passed to the down and eat awards. The
  claimed set (`key:down`, `key:eat`) lives on `Progression`, and a spawn is only marked claimed
  when XP is actually awarded (so a spawn killed while at the cap keeps its full reward for
  after you evolve), which is rebuilt every run, so it
  resets with the run and does not live on the `Run` node.
- **Pacing target, tested in two places.** The first evolution should land near the end of the
  Grotto. Sub-project 3 ships a data-only check on today's rooms: a first-time pass of the
  Cave stays below 270 XP, and evolution is tested with a debug command that grants XP. The
  second test, that a first-time pass of the **Cave plus the Grotto reaches 270**, needs the
  Grotto's spawns and belongs to Sub-project 5.
- **Level bonuses persist across a reset.** Each level still gives +2 max HP and +1 max MP.
  Those bonuses are part of your body's growth and are kept when the level resets, so a
  stage-4 slime has about +72 HP and +36 MP from levels (tuned in Sub-project 3).
- **EP persists too**, and is kept. EP is +1 per level-up, so a full run earns up to 36 against
  skill evolutions that cost 1–2. Sub-project 3's plan tests the total EP budget against the
  skill evolutions that exist, and rebalances if it is lopsided.
- Skill Evolution Points stay as they are: EP pays for **skill** evolutions (Water Blade,
  Swing Thread, and so on). Body evolution costs nothing but the level cap. The two systems get
  distinct wording and API names: the skill system keeps "Evolution available: [Skill] — N EP
  in Skills", `evolve()` and `try_evolve()`. The body system says "Your body can evolve" and
  uses `Form.advance()`.

### 3.2 The tree

Names are draft and can be narrowed with you in Sub-project 3's plan.

```
Stage 1  Slime
Stage 2  Weaver      Tide        Toxic       Bulwark      Echo       (+ Greater Slime)
           │           │           │            │           │              │
Stage 3  Snare|Arachne Brook|Tempest Acid|Blight Golem|Crystal Phantom|Sky  Vast|Radiant
           └────┬───┘   └────┬───┘   └────┬───┘   └───┬────┘   └───┬───┘   └──┬──┘
Stage 4  Silkbound   Tidal       Venom        Stone       Storm         Prime
         Sovereign   Sovereign   Sovereign    Sovereign   Sovereign     Sovereign
```

- Stage 2 → 3 offers **the two children of your form**, and both are always available.
- Stage 3 → 4 has **one** child: both stage-3 forms of a lineage lead to that lineage's
  Sovereign. That step is a confirmation with no choice, and it says so.
- **Greater Slime** (the neutral fallback) has two stage-3 children, Vast Slime and Radiant
  Slime, and both lead to **Prime Sovereign**. So every branch reaches stage 4.
- Each form defines:
  - a **look** (its own sprite set, tint, glow and size), assembled by the same pipeline;
  - **stat changes** (for example Bulwark: +HP, +DEF, −SPD);
  - **passive traits** (Tide: swims freely, water skills cost less);
  - **granted skills** (Weaver: an upgrade to Sticky Thread and a web shot).
- **A form without its own art still works.** It renders the slime's base sprite set, tinted
  with the form's colour and scaled to its size. Art ships lineage by lineage: Sub-project 3
  draws the Weaver lineage end to end (Weaver, Snare, Arachne, Silkbound: 84 frames), and
  the other 20 forms (420 frames) use the tinted fallback until their art is generated. The per-frame fallback
  in 1.5 covers a partly generated set, and this rule covers a missing one.
- An extra active slot is **not** part of a form. The game has four slots on four inputs, and
  a fifth would need its own binding, HUD cell and assignment path. That is out of scope.

### 3.3 Offers

**Affinity decides the stage 1 → 2 offers only.** Stage 2 → 3 always offers your form's two
children (3.2), and stage 3 → 4 is the one Sovereign. When you reach the stage 1 cap, up to
three forms are offered, chosen by what the slime has done this run:

- Each lineage's **affinity** is the units of its essences absorbed this run **divided by that
  lineage's supply**: the units of those essences across every spawn in the areas that have
  shipped. Supply is computed from the room data, so it grows by itself as areas ship and
  needs no hand-tuned numbers.
  - Weaver: thread
  - Tide: water
  - Toxic: poison + spore
  - Bulwark: armor + earth + shell
  - Echo: sound + flight
- A lineage is **eligible** at an affinity of at least **0.6**. Raw units would have left
  Weaver (5 thread in the whole Cave, one per spider) permanently behind Echo (12), Toxic (10)
  and Tide (9), even though it is the one lineage with full art. As a ratio, a slime that ate
  most of what a lineage offers is that lineage, whatever the lineage's size.
- The three highest-affinity eligible lineages are offered, ties broken by lineage order
  (Weaver, Tide, Toxic, Bulwark, Echo). A full first pass through the Cave, eating everything,
  gives every lineage 1.0, so Weaver is offered first. A test asserts exactly that, and that
  eating only bats offers Echo.
- Greater Slime is added until there are at least two offers. So with no eligible lineage the
  list is just Greater Slime (a confirmation, not a choice), with one it is that lineage and
  Greater Slime, and with two or more Greater Slime is not added. Every run can always evolve.
- **Reincarnating deep must not lock you out of lineages.** A pool's kit can seed affinity
  units (see 5.3; seeded units count toward the ratio). For every pool **except the default Cave mouth** (whose kit is nothing,
  because a run from the start earns its affinity), a test asserts that its kit leaves at least
  two lineages eligible.

### 3.4 Skill caps

- Only **player skills that level** change: those with a `levels_on` rule, which are the
  proficiency and essence skills. Enemy-only skills stay at level 1 (the validator requires
  it), and the three skill evolutions (Water Blade, Swing Thread, Jet Dash) have no
  levelling rule, so they stay at level 1 until a later plan gives them one.
- Each levelling skill gets its own new `max_level`, up to 15, and its own `level_curve`.
  `level_curve` stays a single number (the events per level). Only the effect `values`
  arrays are extended to the new `max_level`, which the validator requires.
- **A skill's max is what its source can support.** For example, Appraisal levels on the
  first inspection of each creature type (about 9 types by the Grotto, counting the water
  pool), so a max of 15 would be unreachable. Its max today is 4, and it rises only to 5, which
  needs 8 first-time inspections. Leap needs 14 × 40 = 560 jumps for level 15, which
  is a lot, so its curve is lowered. Echolocation levels on each bat's sound essence at a
  curve of 1, so it would be trivially farmable: its curve is raised. Sub-project 3's plan
  sets every skill with a table and a test that each skill's top level is reachable in a run
  but not trivially.
- The stage cap is **5, 8, 12, 15**. A skill above the cap of the current stage stops
  levelling. Its counters keep counting. The engine derives a level from the counter, so
  clamping it at the cap means the events earned while capped are kept and could give
  several levels at once on evolving. That is intended: **on evolving, every owned skill is
  re-checked and levels straight to its new cap**. The re-check runs one skill at a time,
  each with its own drain, so a burst of level-ups cannot pass the engine's 64-item queue
  limit and drop events (a test proves this with all levelling skills at once).
- The skill screen:
  - shows "capped until you evolve" on a skill sitting at the stage cap with progress stored;
  - shows the level as a number plus a compact bar, since 15 pips at 8 px do not fit the
    row (they would end at 461 px, and the detail panel starts at 410).
- **Announcements.** The re-check emits one `skill_leveled` per level gained, and the popup
  queue holds 4 before merging into "+N more". During the re-check the individual level-up
  lines are suppressed and one line, "Your skills grew," is shown instead.
- Tests that pin today's maxima (for example `body_armor.max_level == 3`) are updated on
  purpose, along with the tab-cycle test (below).

### 3.5 Code

- `FormDef`: a Resource in `data/forms/*.tres`, written by hand (24 static forms with
  hand-tuned numbers do not need a generator). It holds `id`, `display_name`, `stage`,
  `parents`, `essences`, `stats`, `traits`, `grants` (skill ids) and the sprite set.
- `Form` state on the player: `stage`, `form_id`, and `cap()` for skills. It resets with the
  run. `Form.advance(id)` is the only way to change it.
- `SkillRulesEngine` reads the stage cap when it levels a skill, and gains
  `recheck_levels()` for the re-check on evolving.
- `Progression.add_xp` uses its own stage, discards XP at the level-10 cap, and
  `start_at(level)` (5.5) fires `leveled_up` for each level, so the stat bonuses apply,
  but grants no EP.
- The **Form** tab is the fifth menu tab and appears only once `stage > 1` or a body
  evolution is available. It shows your current form and traits, and, when evolution is
  available, lists the offered forms with their look and changes. Choosing one plays the
  evolution animation (the slime glows, swells and splits into the new shape). Five tabs need
  a narrower layout: width 100 at a pitch of 106, so the fifth ends at 552 px. The layout is
  chosen by the number of tabs shown, so four tabs keep today's widths. `TABS` stops being a
  constant of four, and `test_tabs_cycle_through_all_four` is rewritten: the cycle length
  depends on whether the Form tab is shown, so the test covers both.

## 4. Fungal Grotto

Unchanged from the exploration spec's Plan 2 (rooms G1–G6, the creatures Spore Moth, Mushroom
Crab, Vine Snake and Pale Moth, the spore and shell essences, and Spore Cloud and Hardened
Shell), with these additions from this spec:

- No torches. The Grotto's light is fungus and spores.
- Its creatures are drawn with the individual-frame pipeline and use the kill-type deaths from
  the start.
- Its skills are written for the raised maxima.
- Its spore and shell essences feed the Toxic and Bulwark lineages (3.3).
- G1 holds the Grotto's rebirth pool and the `ReincarnationMenu` UI (5.2).
- An abandoned camp is allowed here as a story beat: a cold, unlit brazier by a tablet.

## 5. Reincarnation

This replaces the exploration spec's rule that death always restarts in C1, and its rule that
Glow Pools are not respawn points (they still are not).

### 5.1 Rebirth pools

- A **rebirth pool** is a room feature (`"kind": "rebirth_pool"`) with an `id`, an `area` and
  a `kit`. It looks different from a Glow Pool (pale violet-white glow, a ring of small
  motes), so the two never blur together. The Map shows it with its own icon.
- Reaching one (Inspect: "Y: attune") unlocks it for every future run. The Cave's first room
  (C1) has one, already unlocked, so the game always has a default spawn.
- Each later area has one, placed a little way in from the area's entrance (the Grotto's is
  in G1).
- Unlocked pools are saved in the Profile under `rebirths`, together with the other
  `WorldProgress` sections (one writer, not two). **Pool ids are validated against the room
  data** when the world loads. An unknown id, or a pre-selected last choice whose pool no
  longer exists, falls back to C1. (The Profile only checks that a list holds strings; it
  cannot know what a valid pool is.)

### 5.2 The death card and the choice

1. The "You dissolve." card shows as now.
2. **Logic (Sub-project 4).** A pure `RebirthChoice` decides what happens next: with one
   unlocked pool it starts the run there directly. With more, it returns the list (unlocked
   pools first, then locked ones as "???"), with the last choice pre-selected, and accepts
   only an unlocked entry. It is unit tested with no UI.
3. **UI (Sub-project 5).** The `ReincarnationMenu` renders that list once there is a second
   pool to pick:
   ```
   Reincarnate at:
     ▸ Cave mouth
       Grotto rebirth pool
       ???  (not found yet)
   [A] Confirm
   ```
   Until then the menu would always be skipped, so the UI is built with the first content that
   shows it.
4. A second `died` during the menu does nothing (the existing guard). After a victory (Plan 3
   of the exploration spec) the same choice runs.

### 5.3 The head start

Each pool defines a `kit`, sized to the area:

| Pool | Kit |
|---|---|
| Cave mouth (C1) | Nothing |
| Grotto (G1) | Leap and Wall Cling granted at skill level 1, character level 3, and seeded affinity |
| Flooded Tunnels (F1), illustrative until that plan | Adds Sticky Thread, character level 6 |

- "Level" in a kit is the **character level**, capped by stage 1's cap of 10. Kit skills start
  at skill level 1, so they sit under stage 1's skill cap of 5.
- A kit may seed **affinity** units, so skipping the early areas does not lock you out of
  lineages (3.3). A test asserts that every pool except the default Cave mouth leaves at least
  two lineages eligible.
- **Kit skills are granted** at level 1. They count as known (Compendium `NAMED`), not as
  discovered, so their conditions stay hidden until you earn them the normal way, and
  exploring still matters. Their counters start from zero.
- A starting level gives the level's stat bonuses but **no EP**. EP is still earned.
- The stage is always 1 on reincarnating.
- Kits are data on the pool. A test checks that every id exists and every level is within the
  cap. It also asserts that a granted skill's dependants (for example Swing Thread, which
  needs Wall Cling 2) stay locked until the level is earned.

### 5.4 Species

- A `species` id (`"slime"`) is carried on the run and saved in the Profile alongside the last
  choice, so a later species needs no save migration.
- There is no `SpeciesDef` resource, no `data/species/` directory, no "Species" row on the
  death card and no species screen in this pass. Nothing else exists to choose.
- When a second species (spider, human, goblin...) is designed, its design introduces
  `SpeciesDef` (body, skills, movement, evolution tree, unlock) and the menu row. The forms in
  3.2 belong to the species `slime`.

### 5.5 Code

- `RebirthPool`: an interactable, like `GlowPool` and `Tablet`, built by `RoomFeatures`.
- **State lives outside the scene.** The `Run` node is rebuilt when the scene reloads, so it
  cannot hold the choice. `Compendium.progress` (on the autoload) holds an in-memory
  `pending_start` (`{pool, species}`), and the Profile stores the persistent pieces: the
  attuned pools and the last choice. The Profile gains a scalar getter/setter for the last
  choice, since it only exposes string lists today.
- `World.enter_at(room_id, pos)` starts the run at a pool: its room, and its own position.
  `enter_start()` stays for the default, and the world validator keeps requiring exactly one
  start room.
- **Order on load.** The game's `_ready` enters the world (`enter_start()`, or `enter_at` for a
  pool) **before** it calls `SkillRules.start_run()`, which clears the owned skills and
  replaces the progression. So the kit is applied **after** `start_run()`, at the end of
  `_ready`. Kit skills are not `starting` skills, so `on_run_started` never raises them, and
  the explicit `NAMED` raise below is what marks them known. Applying it is: `grant()` for each kit skill, `Progression.start_at(level)`, the
  seeded affinity, then `pending_start` is cleared so a later unrelated reload does not
  replay it.
- `SkillRulesEngine.grant(id)` wraps the engine's existing private `_grant(d, announce)` (which
  sets the skill's counter baseline to the current count) and puts the skill in `_owned` **without** emitting
  `skill_unlocked`, because that signal both reveals the Compendium and (through the player)
  is the only path that puts an active into a slot. So after a grant, the game calls
  `skillset.refresh()`, `slots.add(id)` for actives, and `compendium.raise(id, NAMED)`.
- **Discovery of a granted skill.** The engine tracks a `_granted` set. The normal unlock
  check also runs for granted skills, and when their conditions are met it emits
  `skill_discovered(id)` (not `skill_unlocked`), which raises the Compendium to `OWNED_ONCE`.
  `_evaluate` needs a new branch for this: today an owned skill goes straight to its level
  check and never re-tests its unlock. Discovery announces one ticker line ("You understand
  [Skill]."), so it does not feel like nothing happened, without a full popup.
- `Progression` gains `start_at(level)`.

## Testing approach

- Pure logic gets unit tests: `SlimeState.pick`, the spread rules (including that damage checks
  are unchanged, the stand-up rule and the snapped-aim-straight-down rule), the death causes and the `receive_hit` arguments on all three implementors (Enemy gaining both), the `DYING`
  guards (no contact damage, no stun, not predatable, no timer), form offers and eligibility (including the boundaries at 0, 1 and 2+ eligible),
  every form's path to stage 4, the stage XP curve and rounding, the XP cap, the first-time
  versus repeat XP (down and eat separately, `floor(xp / 4)`), the skill caps and the re-check burst, `RebirthChoice`, kits, `grant`
  and `skill_discovered`.
- Reachability: one Cave pass stays under 270 XP (Sub-project 3), the Cave plus Grotto reaches
  it (Sub-project 5), five spiders make Weaver eligible, and each levelling skill's top level is
  reachable in a run.
- Reload: `pending_start` survives `reload_current_scene`, the pool's room and position are
  used, and the kit is applied after `start_run`.
- Data: every frame and sheet has a test that its JSON matches the image and that no frame is
  missing from its set. No decor is `torch`. The validator accepts the new maxima. Existing
  assertions that pin today's maxima or the sprite count are updated on purpose.
- The animation and evolution flows get scripted-run tests, and real screenshots for the
  visual pieces.

## Out of scope for this pass

- Sounds and music.
- The Flooded Tunnels and the serpent (their own plan).
- A crawlway that needs Spread to pass.
- Damage from Hydraulic Propulsion and Jet Dash (and so the `blast` death).
- Enemy poison-over-time.
- A fifth active slot.
- A `SpeciesDef` and any second species.
- Naming beyond Stage 4's draft.

## Build order (five plans)

1. **Slime feel:** the art-pipeline spike, then the pipeline, the slime's frame sets,
   `SlimeState`, `Animator`, spread (a pose, with the re-centred collision shape), `EatCover`, and the torch replacement
   with its decor art.
2. **Enemies:** frames for each creature, the `receive_hit` arguments (Enemy gains two), and the death
   effects.
3. **Evolution:** the stage state and XP curve, dwindling respawn XP, `FormDef`, offers, the
   skill caps and raised maxima, `recheck_levels`, the Form tab, and the Weaver lineage's art
   end to end (the other lineages use the tinted fallback).
4. **Reincarnation:** rebirth pools, `RebirthChoice`, kits, `grant` and `skill_discovered`,
   `enter_at`, the state that survives a reload, and C1's pool.
5. **Fungal Grotto:** Plan 2 of the exploration spec, including G1's rebirth pool, the
   `ReincarnationMenu` UI, and the pacing test that a first-time pass of the Cave plus the
   Grotto reaches 270 XP.
