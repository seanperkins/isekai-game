# Slime Forms, Animation and the Next Location — Design

Status: draft for review (2026-09-28). Builds on `2026-09-27-slime-prototype-design.md` and
`2026-09-28-exploration-world-design.md`.

## Goal

Make the slime feel alive and give a run a long arc. The slime gets real animation (running,
jumping, climbing, spreading flat, and eating by covering its prey). Enemies die in ways that
match how they were killed. The slime evolves through a branching tree, spider-anime style,
with skill levels held back until it does. The Fungal Grotto is built last, on the new art and
kit.

This is four sub-projects, each its own plan that ends in something you can play. The order
is fixed by your answers.

| # | Sub-project | Ends with |
|---|---|---|
| 1 | Slime feel: animation set, spread, eating cover, no torches | A slime that moves and eats with drawn animation |
| 2 | Enemies: individual sprites and kill-type death animations | Every enemy has frames, and dies to match the blow |
| 3 | Evolution: stages, forms, level cap, skill caps, raised skill maxima | You can evolve a slime through the tree |
| 4 | Fungal Grotto (Plan 2 of the exploration spec) | The next location, using the new art and kit |

## Decisions (from the interview)

| Topic | Decision |
|---|---|
| Sprite production | Generate every frame **individually**, then a tool assembles frames into sheets. A whole sheet is never generated in one shot |
| Torches | None anywhere in the wilderness. Light comes from glowing fungus, lichen and crystals. Human-made things (tablets, cracked stone) stay, and an unlit brazier may mark an abandoned camp later |
| Order | Slime feel → enemies → evolution → Fungal Grotto |
| Evolution structure | Spider-style choice: at the stage cap you pick one of 2–3 offered forms |
| Stages | 4 stages. The level cap is 10 per stage, and your level resets to 1 on evolving |
| First-stage lineages | Weaver (thread), Tide (water), Toxic (poison), Bulwark (armor + earth), Echo (sound + flight) |
| Skill levels | Capped by stage: max Lv5, 8, 12, 15. Every skill's overall max rises to 15. Progress is kept, so evolving unlocks the next levels |

## 1. Slime feel

### 1.1 Movement states and frames

The slime picks one state each frame. The first match in this order wins.

| State | When | Frames | Notes |
|---|---|---|---|
| `cover` | Eating (predation active) | 5 | See 1.3 |
| `wall` | Clinging to a wall (Wall Cling, airborne, touching the wall) | 2 | Slides down slowly. A second frame shows the grip shifting as it slides |
| `spread` | Left stick down (or S / ↓) held on the floor | 2 | See 1.2 |
| `rise` | Airborne, moving up | 1 | Stretched tall |
| `fall` | Airborne, moving down | 1 | Wider at the bottom |
| `land` | Just landed (0.12 s) | 1 | Squashed flat (exists today) |
| `run` | On the floor, moving | 4 | A squelching loop at 10 fps |
| `idle` | Otherwise | 2 | A slow "breathing" wobble at 3 fps |

Wall climbing keeps today's rules (slide slowly, Space to jump off). The new frames only show
what is already happening. The slime faces away from the wall, so its grip is drawn on the
wall side.

### 1.2 Spread

- Hold **down** (stick, D-pad, S or ↓) on the floor and the slime flattens into a puddle.
- Movement is half speed. The hitbox drops from 12 px to 5 px tall, so spit globs, bat
  dives and tall enemy attacks pass over it.
- It is still hittable by anything low (a lizard charge, contact).
- Jump while spread stands the slime up and jumps in the same press. Skills still work,
  and aiming down is unchanged (down is also the aim direction).
- Entering the pose takes two frames (a quick squash). Leaving it takes the same in reverse.
- A low gap the slime can only pass while spread (a 6 px crawlway) becomes a level-design tool
  in later rooms. No such gap ships in this pass.

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

The slime moves onto the target for the hold (the hold already requires being within 32 px).
The prey's own sprite is drawn under the slime's translucent frames and scales from 100% to
20% over the hold.

### 1.4 Torches out, glow in

- Every `torch` decor entry in `tools/build_world.gd` becomes a natural light. The choice
  depends on the spot: glowing fungus on the floor, hanging lichen under ledges, a crystal
  cluster on walls.
- New decor sprites (each generated individually): `glow_fungus` (2 variants), `lichen_hang`,
  `wall_crystal`. Each carries a soft `PointLight2D`.
- The lights keep their colour palette (teal, purple, blue, and a warm amber for the fungus).
  Warm fire orange goes away except in a human place, and there are no such places in the
  Cave.
- Playtest checklist lines that mention torches are updated.

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

- **Consistency:** each generation is given the canonical `slime_idle` as a reference image,
  and its neighbours in the clip once they exist, plus a fixed style prompt (Style D, the same
  translucent blue, the same inner glow, facing right).
- **Keying and fitting:** the existing keying, box-filter downscale and alpha threshold from
  `slice_sheets.py` are reused, so frames match today's pixel look.
- **Assembly:** frames of a set are packed in a grid, and the JSON records each frame's cell,
  size, and the baseline (`bottom`) so feet line up across frames.
- **Review:** the first round for each set is a contact sheet of every frame, shown to you for
  approval before anything ships. A frame you dislike is regenerated alone.
- **Fallback:** a missing frame falls back to the closest existing pose, so the game runs with
  a partly generated set.

### 1.6 Code

- `SlimeState.pick(...)` is a pure static function (like `Player.pick_frame`): inputs are
  eating, wall, spread, on_floor, vy, land timer, and speed; output is a state name. It is
  unit tested for every row of the table.
- `Animator` maps state → clip and advances frames from `_process`. `Player._update_visual`
  calls it instead of `Art.set_frame`.
- `Player` gains a `spreading` flag with the rules from 1.2, driven by the down input while
  `is_on_floor()`.
- The eating cover is a small `EatCover` node that follows `predation.target`.

## 2. Enemies: sprites and kill-type deaths

### 2.1 Sprites

Each creature gets individually generated frames, assembled by the same pipeline:

| Creature | Frames |
|---|---|
| Bat | fly ×4, hover ×2, dive ×1, hurt ×1 |
| Toad | idle ×2, walk ×3, puff ×2, spit ×1, hurt ×1 |
| Lizard | idle ×2, walk ×4, windup ×2, charge ×3, rest ×2, hurt ×1 |
| Spider | hang ×2, drop ×1, crawl ×4, hurt ×1 |
| Serpent | reserved for its own plan |

The AI already has states for these (Plan "Enemy AI"): the telegraph states map straight onto
the wind-up and rest frames. Each creature also gets one **downed** pose, drawn once.

### 2.2 Death matches the blow

The killing blow carries a `cause`, so the effect can match it:

| Cause | Comes from | Death |
|---|---|---|
| `tackle` | The slime's tackle | The creature is knocked back in an arc, spins, and lands on its back |
| `poison` | Poison Breath, poison ticks | The body slumps, turns green, and melts into a puddle over 1 s |
| `blade` | Water Blade | Cut in two along the blade's angle. The halves slide apart and fall |
| `blast` | Hydraulic Propulsion, Jet Dash | Thrown away fast in a spin, with a streak, and thumps into the floor |
| `shock` | (Jolt, in the Flooded Tunnels plan) | Stiffens, flashes white, and drops smoking |
| `other` | Anything else | The downed pose |

- `receive_hit` gets a `cause` argument, with abilities passing theirs. Unknown causes use
  `other`.
- The effects are procedural on the creature's own sprite (a shader for the melt, a
  two-sprite split for the cut, a tumble for the knockback), so all creatures share them and
  none needs its own frames. Only the downed pose is drawn per creature.
- A downed body stays edible for 5 s, as now. The effect plays first, then the body rests.
  The melted and cut bodies still count as downed, and are eaten like any other.

## 3. Evolution

### 3.1 Stages and level

- Four stages: Slime → (2) Form → (3) Greater form → (4) Sovereign.
- The level cap is 10 per stage. At the cap, XP stops and the voice says "Evolution
  available." Your level then resets to 1 on evolving, and the cap applies to the new stage.
- XP needed per level rises with the stage (a multiplier of 1, 1.5, 2, 2.5 on today's
  curve), so later stages are longer.
- The first evolution is tuned to arrive at the end of the Fungal Grotto, not the Cave: the
  Cave alone offers about 180 XP against 325 needed for level 10. That is intended, and
  Sub-project 3's plan sets the numbers with a test that a full clear of the shipped
  areas can reach it.
- Skill Evolution Points stay as they are: EP pays for skill evolutions (Water Blade,
  Swing Thread, and so on). Body evolution costs nothing but the level cap.

### 3.2 The tree

Names are draft and can be narrowed with you in Sub-project 3's plan.

```
Stage 1  Slime
Stage 2  Weaver      Tide        Toxic       Bulwark      Echo
           │           │           │            │           │
Stage 3  Snare|Arachne Brook|Tempest Acid|Blight Golem|Crystal Phantom|Sky
           │           │           │            │           │
Stage 4  Silkbound   Tidal       Venom        Stone       Storm     (Sovereigns)
```

Each form defines:
- a **look** (its own sprite set, tint, glow and size), assembled by the same pipeline;
- **stat changes** (for example Bulwark: +HP, +DEF, −SPD);
- **passive traits** (Tide: swims freely, water skills cost less);
- **granted skills** (Weaver: an upgrade to Sticky Thread and a web shot);
- **slot count** (+1 active slot at stage 3);
- **offer rules** (which forms appear, below).

### 3.3 Offers

When you reach the cap, up to three forms are offered, chosen by what the slime has done this
run:

- Each lineage has an **affinity score**: the units of its essences absorbed this run (Weaver:
  thread; Tide: water; Toxic: poison; Bulwark: armor + earth; Echo: sound + flight).
- A lineage is **eligible** with an affinity of at least 4.
- The three highest eligible lineages are offered, ties broken by lineage order.
- If fewer than two are eligible, a **Greater Slime** (a neutral, generic form) fills the list.
  Every run can always evolve.
- Later stages offer the two children of your form, and both are always available.

### 3.4 Skill caps

- Every skill's `max_level` rises to 15. `level_curve` and effect values are extended to 15
  entries (the validator already requires values to match `max_level`).
- The stage cap is **5, 8, 12, 15**. A skill above the cap of the current stage stops
  levelling. Its counters keep counting, so the progress is kept, and evolving lets it
  level on the next event.
- The skill screen shows "capped until you evolve" on any skill sitting at the cap with
  progress stored.
- A skill's tier-based active values (Sticky Thread's hold tier, Poison Breath damage) are
  extended with a curve, so levels beyond 5 keep helping.

### 3.5 Code

- `FormDef`: a Resource in `data/forms/*.tres`, generated by `tools/build_forms.gd`. It holds
  `id`, `display_name`, `stage`, `parents`, `essences`, `stats`, `traits`, `grants` (skill ids),
  `extra_slots` and the sprite set.
- `Form` state on the player: `stage`, `form_id`, and `cap()` for skills. It resets with the
  run.
- `SkillRulesEngine` reads the stage cap when it levels a skill.
- A **Form** tab (the fifth menu tab, always visible) shows your current form and its
  traits. When evolution is available it lists the offered forms with their look and changes.
  Choosing one plays the evolution animation (the slime glows, swells and splits into the
  new shape).

## 4. Fungal Grotto

Unchanged from the exploration spec's Plan 2 (rooms G1–G6, the creatures Spore Moth, Mushroom
Crab, Vine Snake and Pale Moth, the spore and shell essences, and Spore Cloud and Hardened
Shell), with these additions from this spec:

- No torches. The Grotto's light is fungus and spores.
- Its creatures are drawn with the individual-frame pipeline and use the kill-type deaths from
  the start.
- Its skills are written for levels up to 15.
- An abandoned camp is allowed here as a story beat: a cold, unlit brazier by a tablet.

## Testing approach

- Pure logic gets unit tests: `SlimeState.pick`, the spread rules, form offers and eligibility,
  the skill cap, the level curve per stage, and death-cause plumbing.
- Every frame and sheet has a test that its JSON matches the image and that no frame is
  missing from its set.
- The animation and evolution flows get scripted-run tests, and real screenshots for the
  visual pieces.

## Out of scope for this pass

- Sounds and music.
- The Flooded Tunnels and the serpent (their own plan).
- A crawlway that needs Spread to pass.
- Naming beyond Stage 4's draft.

## Build order (four plans)

1. **Slime feel:** the art pipeline, the slime's frame sets, `SlimeState`, `Animator`, the
   spread, the `EatCover` node, and the torch replacement with its decor art.
2. **Enemies:** frames for each creature, the `cause` argument, and the death effects.
3. **Evolution:** `FormDef`, the stage state, offers, the skill caps and raised maxima, the
   form screen, and one lineage's art end to end (the rest follow in the same pipeline).
4. **Fungal Grotto:** Plan 2 of the exploration spec.
