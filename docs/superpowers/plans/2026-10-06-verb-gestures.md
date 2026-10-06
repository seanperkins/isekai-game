# Verb gestures on the 3D stage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use ml:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every verb a form can cast plays a gesture that reads as what the verb does, from a small shared vocabulary authored per rig family, judged on the 3D photo stage before it is baked into the form's attack clip.

**Architecture:** One data table (`tools/verb_anims.json`) says which gesture (archetype) each verb kind uses, and the game's own kind list is tested against it so a new kind cannot ship without one. Each rig family gets the archetypes as presets in its existing four-key attack tables (`biped_motion.ATTACKS`, `quad_motion.ATTACKS`, `spider_motion.GESTURES`, ...), so every existing timing and foot test covers them. The stage renders a form casting in place on the game's course with the engine's windup and recovery times and a keyframe sheet; a family without an archetype is a named gap, not an idle pose. Movement verbs (dash, glide, blink, hop, mount, vine) are recorded from the real Player in a later plan.

**Tech Stack:** Python 3 (pure motion modules, unittest), Blender 4 (`-b -P`), Godot 4.7 headless (GUT), Pillow.

**Spec:** `docs/ledgers/verbs-full-ledger.md` (what each verb does, agreed) and the user's direction of 2026-10-06 (each verb a 3D motion, judged on the stage); memory bank blender-spike-3r71thp19526g.

## Global Constraints

- The engine's timing is the animation's: windup 0.35 s, recovery 0.30 s, hurt 0.25 s (`export_forms.check_timing` reads `scripts/enemies/enemy.gd`); an archetype's impact frame is the first frame after its windup.
- The gesture is chosen by `spec.kind` only (the 56 kinds in `VerbKinds.KINDS`); a weapon blow stays a weapon blow when a form holds a weapon and its verb is a `bolt` or `burst` (`attack_kinds.choose`).
- A form that casts a kind it has no archetype for in its family says so in a KNOWN_MISSING table; it never falls back to another form's clip silently.
- Bake output of every form whose verb kind is unchanged stays byte-identical.
- No time or effort estimates anywhere.

## Review Focus

- A verb kind added to `verb_kinds.gd` with no row in `verb_anims.json` must fail a test.
- A form whose verb has an archetype its family cannot play must show in the gap list, not as the weapon blow.
- Two archetypes that are the same pose under two names (a gesture nobody can tell apart) must be caught on the stage sheet, not shipped.
- A verb that needs both hands (summon, craft) on a form whose hands hold a weapon must not drop the weapon through its body.

---

### Task 1: The vocabulary

**Files:**
- Create: `tools/verb_anims.json`, `tools/art/blender/verb_anims.py`, `tools/art/blender/test_verb_anims.py`, `tests/test_verb_anims.gd`
- Modify: `tools/build_form_verbs.py` (rows get an `anim` tag), `tools/art/blender/verbs.py` (`kind_of` stays; add `anim_of(form_id)`)

**Interfaces:**
- Produces: `verb_anims.ARCHETYPES` (the ids: existing `slam roar lunge claw guard cast` and new `point throw summon drink craft sneak pulse`), `verb_anims.table() -> {kind: archetype}`, `verb_anims.archetype_of(kind) -> str`, `verbs.anim_of(form_id) -> str | None`.

- [ ] **Step 1: Write the failing tests.** `test_verb_anims.py`: every kind in `scripts/abilities/verb_kinds.gd` `KINDS` (parsed) is a key of the table; every value is in `ARCHETYPES`; every archetype is used by at least one kind; every row of `tools/form_verbs.json` and `tools/monster_verbs.json` has an archetype. `tests/test_verb_anims.gd`: `VerbKinds.KINDS` ⊆ the JSON keys.
- [ ] **Step 2: Run** `python3 -m unittest tools/art/blender/test_verb_anims.py` and `tools/run_tests.sh verb_anims` — Expected: FAIL (no table).
- [ ] **Step 3: Write `tools/verb_anims.json`** from the ledger's agreed text: gestures by what the body does (bolt/chain/pull → cast; burst/ring → slam; dash/chase → lunge; zone/ward/anchor → guard; mark/hunt/fate/omen → point; decoy/stone/trap → throw; summon/raise/companion/offer/mount → summon; drink/devour/engulf/suckle → drink; forge/spin/rig/transmute/bridge/vine/network/flood/reveal → craft; veil/stalk/swap/blink/trail/steal/sabotage → sneak; heal/buff/soul/light/weigh/copy/disperse/glide → pulse; roar/bark/aura/rage → roar; dissolve → claw). Implement `verb_anims.py`, and the `anim` tag in the builder.
- [ ] **Step 4: Run** both tests plus `python3 -m unittest discover -s tools/art/blender -p "test_*.py"` — Expected: PASS.
- [ ] **Step 5: Commit** `feat: the verb gesture vocabulary: one table from verb kind to archetype, tested against the game's kinds`.

### Task 2: The gesture gallery on the stage

**Files:**
- Modify: `tools/art/blender/stage_review.py`, `tools/art/stage_review.py`, `tools/art/blender/test_stage_review.py`

**Interfaces:**
- Consumes: Task 1's `ARCHETYPES`; a creature module's `clips_of`.
- Produces: `stage_review.cast_recording(archetype, windup=0.35, recover=0.30, fps=60) -> recording` (a body standing at START whose `verb` is the archetype for the cast), `gesture_clips(creature, rig, variant, archetype) -> clips | raises NoPose` (the creature's attack clip rebuilt with that archetype), CLI `stage_review.py goblin --gesture slam` writing `.tmp/stage/<creature>/gesture_<archetype>/` (GIF, `review_sheet.png` of windup, impact and follow-through).

- [ ] **Step 1: Write the failing test** (pure): `cast_recording("slam")` has a standing tick before the cast, `ceil(0.35*60)` ticks of windup then `ceil(0.30*60)` of recovery, all `verb == "slam"`, and the body does not move; `state_of` gives the cast state `"cast"` for it.
- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Implement** `cast_recording`, the `cast` state (clip `attack`, phase by time since the cast began), `gesture_clips` per family (goblin/undead/werewolf through `attack_kinds`, wolf through `quad_motion`, spider through `GESTURES`, slime), and the CLI flag.
- [ ] **Step 4: Run** `python3 tools/art/stage_review.py goblin --gesture slam` and read the sheet — Expected: a goblin slams on the course floor, hands overhead then down at the impact frame.
- [ ] **Step 5: Render the six existing archetypes for the five families, read the sheets, and write the families' gaps into `KNOWN_ARCHETYPES` (the table of what each family cannot play yet).**
- [ ] **Step 6: Commit** `feat: cast a gesture on the stage`.

### Task 3: Biped gestures (goblin, undead, werewolf kits)

**Files:** Modify `tools/art/blender/attack_kinds.py` (new presets through `register`), `tools/art/blender/undead_motion.py` if the float-bodied undead differ; Test `tools/art/blender/test_attack_kinds.py`.

- [ ] **Step 1: Write the failing tests:** every archetype in `verb_anims.ARCHETYPES` has a biped preset (or is in the gap table); each new preset's channels are valid four-key paths and pass the generic loops in `test_biped_motion.py` (timing, far foot planted, last frame is the rest pose).
- [ ] **Step 2: Run** — Expected: FAIL for `point throw summon drink craft sneak pulse`.
- [ ] **Step 3: Author the seven presets** (`_attack(...)` numbers): point (one arm straight out along the sight line, the chest turned into it), throw (overhand: arm back and over, the step forward), summon (both arms raised palms up, the head back), drink (a hand to the mouth, the head tipped back), craft (a deep crouch, both hands working low in front), sneak (low and forward, one hand trailing), pulse (hands drawn to the chest, then opened outward).
- [ ] **Step 4: Run** the Blender-tool suite — Expected: PASS.
- [ ] **Step 5: Render each on the stage for the goblin and the undead, read the sheets, and adjust until each reads as its verb and none duplicates another.**
- [ ] **Step 6: Commit** `feat: seven gesture presets for the two-legged bodies`.

### Task 4: Quadruped gestures (wolf)

Same shape as Task 3 on `quad_motion.ATTACKS`: the wolf's counterparts (`point` a nose-and-foreleg lift, `throw` a head toss, `summon` a rear-and-howl, `drink` a lap at the ground, `craft` a paw dig, `sneak` a belly-low stalk, `pulse` a shake). Test: every archetype has a preset or a gap row; the generic quad tests pass; the paws stay planted. Commit `feat: gesture presets for the wolf body`.

### Task 5: Spider and slime gestures

Spider through `spider_motion.GESTURES` (drider forms already have cast, bow, fan, throw, smash: map archetypes onto them and add what is missing); slime through `slime_motion` (squash, stretch, pulse, split are natural: `pulse`, `summon` and `drink` first, the rest named gaps). Tests as above. Commit `feat: gesture presets for the spider and the slime`.

### Task 6: Wire it to the forms and bake

**Files:** Modify `tools/art/blender/attack_kinds.py` (`BY_VERB` and `BY_VERB_QUAD` read the table), `tools/art/blender/export_forms.py`, tests; Regenerate `data/form_clips.json`, `assets/sheets/anim_*.png`.

- [ ] **Step 1: Write the failing test:** for every form with a verb, `attack_kinds.resolve` returns the archetype `verb_anims` names for its kind (or its weapon blow where `choose` keeps it); forms whose kind is unchanged still resolve to what they did.
- [ ] **Step 2: Run** — Expected: FAIL for the kinds that were not in `BY_VERB`.
- [ ] **Step 3: Implement** the table lookup; **Step 4:** run `export_forms` for every species, then the whole Blender-tool suite and the Godot suite — Expected: PASS; unchanged forms byte-identical.
- [ ] **Step 5: Send contact sheets of one form per archetype for review; commit** `feat: every form casts its verb's gesture`.
