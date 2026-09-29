# Skill Evolution Branches — Design

Status: draft for debate (2026-09-29). Answers Sean's two notes: "the evolved skill should replace the skill that it
evolved from" and "we could maybe choose two or three directions that an evolved skill could go towards", plus the
request to look at other Metroidvanias for abilities (`docs/research/metroidvania-reference.md`). Held/channelled casting
and new visual effects are a separate spec that follows this one (see "Not here").

## What I understood

Today an evolution is an extra skill that unlocks beside its parent (both stay in `owned()`), and only Swing Thread takes
its parent's slot (`replaces`). Sean wants the opposite default: evolving **turns** the skill into the new one. And the
choice should be a real choice, with two or three distinct directions per base skill, not one fixed upgrade.

Success: a player who reaches an evolution sees the directions on offer, picks one, and from then on has that skill
where the old one was; the other directions are closed for this life (a rebirth is the way to try another). Every base
active skill that can evolve has 2 or 3 directions that feel different (traversal vs control vs attack), each buildable
from behaviour the game already has.

## Decisions

| Topic | Decision |
|---|---|
| Replace | Evolving **retires** the parent. `SkillRulesEngine.owned()` no longer lists it, its slot goes to the child (`ActiveSlots.replace`, already there), and it stops levelling. `level_of(parent)` still returns the level it reached, so other `skill_level` conditions and the tests that read it keep working. Every evolution sets `replaces` (today only Swing Thread does) |
| Branches | Siblings are the evolutions that share a `replaces`. No new branch field. Taking one **closes** the rest for the run: their ready flag is erased, they never become ready again, and `evolve()` refuses them. `reset_run()` reopens everything. A parent with evolutions has 2 or 3 of them (validated) |
| Direction tag | New `SkillDef.direction: String` (one word: Traversal, Movement, Control, Attack, Area, Support). It only labels the choice; nothing reads it for behaviour |
| Level after evolving | The child starts at level 1 on its own curve (`levels_on: skill_used` of itself). Its values at level 1 are at least the parent's at level 5, so evolving never feels like a downgrade. The parent's progress does not carry over (one rule, no copy logic) |
| Cost | Unchanged: `evolution_cost(id)` is one EP per `skill_level` parent in the unlock |
| Grant path | `grant(id)` of an evolution (a rebirth kit, the debug flag) retires an owned parent and closes its siblings. `grant(parent)` is refused once any of its evolutions is owned or a sibling branch is taken, so a kit cannot hold a parent and its own evolution at once |
| Choosing | The Skills tab lists each ready evolution as a row "Name (Direction)". The detail card adds "Replaces X" and "Closes: Y, Z". Because it is permanent for the life, `accept()` needs two presses: the first arms the row (the card says "Press again to choose"), the second evolves; moving the selection disarms it |
| Owned card | An evolved skill's card says "Evolved from X". A retired parent no longer shows in the list |
| Compendium | Unchanged: an evolution keeps its slot and its hint; the row for a closed branch simply stays undiscovered until another life takes it |
| Audio, icons | Each new active needs an icon (`make_icons.py` recipe) and a `skill_used` cue in `data/audio/cues.json`; a new skill may point at a similar existing cue (Spore Cloud already maps to `skill_poison_breath`). `test_every_active_skill_has_its_own_cue` keeps holding |
| Forms | `FormEffects.THREAD_SKILLS` and `WATER_SKILLS` gain the new ids, so thread and water forms still boost their whole family |

## The trees

Sean's ask is 2 or 3 directions per base skill. The research's templates: Ori's Charge Flame has three modifiers (Burn,
Blast, Efficiency), Hollow Knight replaces a spell with one upgrade, Dawn of Sorrow adds a second axis. Here each base
skill gets one branch per *role* (how the player uses it), and every branch is a small change to code that exists.
Numbers are starting values, tuned by play.

**Sticky Thread** (thread essence) has three branches.

| Branch | Direction | Unlock (all) | MP | Behaviour | Built from |
|---|---|---|---|---|---|
| Swing Thread | Traversal | Sticky Thread 3, Wall Cling 2 | 4 | Exists: 200 px rope, swing, strong launch, holds enemies | `ThreadAbility` |
| Zip Line | Movement | Sticky Thread 3, Leap 2 | 4 | A thread that sticks to rock reels the slime in fast (about 520 px/s) and lets go at the anchor with a launch; range 200 px; on an enemy it slows and holds like Swing Thread | `ThreadAbility` plus an `auto_reel` mode on `Player.attach_rope` |
| Binding Web | Control | Sticky Thread 3, Poison Breath 2 | 4 | The thread holds an enemy at once (no slow tier first) and leaves a web patch (radius 40 px, 4 s) where it lands that slows anything crossing it | `ThreadAbility`, `SporeCloudArea` made a general zone (`damage`, `slow`, colour) |

**Hydraulic Propulsion** (water essence) has three branches.

| Branch | Direction | Unlock (all) | MP | Behaviour | Built from |
|---|---|---|---|---|---|
| Water Blade | Attack | Hydraulic Propulsion 2 | 5 | Exists: instant blade, 160 px, 3 damage | `WaterBlade` |
| Jet Dash | Movement | Hydraulic Propulsion 3, Leap 2 | 5 | Exists: long dash | `JetDash` |
| Torrent | Control | Hydraulic Propulsion 3, Body Armor 2 | 4 | A wave 130 px long and 56 px wide in front: 2 damage and a hard shove to every enemy inside, and a small recoil on the slime | `targets_in_front`, `receive_hit` knockback |

**Poison Breath** (poison essence) has two branches.

| Branch | Direction | Unlock (all) | MP | Behaviour | Built from |
|---|---|---|---|---|---|
| Miasma | Area | Poison Breath 4 | 5 | The cone as today, and where it ends a poison cloud lingers (radius 36 px, 3 s, 1 poison per second) | `PoisonBreath`, `SporeCloudArea` |
| Venom Bolt | Attack | Poison Breath 4, Echolocation 2 | 5 | One bolt along the aim that pierces: it hits every enemy on its path once for 3 poison and stops at rock; range 260 px | a `SpitBlob`-style projectile flown straight, player team |

**Spore Cloud** (spore essence) has two branches.

| Branch | Direction | Unlock (all) | MP | Behaviour | Built from |
|---|---|---|---|---|---|
| Healing Spores | Support | Spore Cloud 4, Regeneration 2 | 4 | The cloud does not poison; the slime heals 1 HP a second while inside it and enemies inside are still slowed | `SporeCloudArea` with `heals` |
| Puffball | Area | Spore Cloud 4, Leap 2 | 5 | A pod lobbed along the aim (arc, 0.5 s) bursts where it lands into a cloud of twice the radius | `SporeCloud`, projectile arc as `SpitBlob` |

Seven abilities are new (Zip Line, Binding Web, Torrent, Miasma, Venom Bolt, Healing Spores, Puffball); three exist.
The Poison Breath and Spore Cloud trees are the second wave in the plan, so they can be cut without touching the model.
Deferred on purpose, from the research: a Weaver (summoned spiders), Sporelings (hatchlings), a Thread Recall teleport, a
charged Jet Dash and a held Water Blade. The last two belong to the channelling spec.

## Engine and data changes

- `SkillDef`: add `direction`. `replaces` is now required on every evolution that has an active.
- `SkillRulesEngine`: `_retired: Dictionary` (parent id to child id) and `_closed: Dictionary` (branch parent id to chosen
  child id). `owned()` skips retired ids; `is_retired(id)`, `branch_of(id)` (the `replaces` of an evolution), `siblings_of(id)`
  and `evolved_from(id)` are new read helpers. `evolve()` and `grant()` retire and close through one private `_take_branch(d)`.
  `_evaluate` does not mark a closed branch's evolution ready. `recheck_levels()` and the rest of the loops over `_owned`
  use `owned()`.
- `PlayerSkillSet.on_skill_unlocked` is unchanged (it already replaces by `replaces`); `refresh()` uses `owned()`.
- `DefValidator`: every evolution names an existing non-evolution active in `replaces` and has a `skill_level` condition on
  it; each parent has 2 or 3 evolutions; `direction` is set on every evolution and unique among siblings.
- `SkillScreenModel` and `SkillScreen`: ready rows carry the direction; the detail card, the armed state and the two-press
  accept; retired parents are not rows.
- `tools/build_content.gd` defines the seven new skills and sets `replaces`/`direction` on the three that exist; the
  `data/skills/*.tres` are regenerated. `RebirthKit` seeds are untouched apart from the validator's rules.

## Failure modes and edge cases

- Two evolutions become ready in the same drain: both are ready, the first `evolve()` closes the other.
- An evolution is ready and the player evolves a different branch: the ready row disappears and the HUD/announcer do not
  fire for it again.
- A kit grants `water_blade` while `hydraulic_propulsion` is owned: the parent retires, the slot is taken, no EP is spent.
- Death and rebirth: `reset_run()` clears `_retired` and `_closed`; a kit re-grants through `grant`.
- The slot the parent held is not the slime's last-used slot: `ActiveSlots.replace` keeps position, so muscle memory holds.
- Enemy-only skills and passives are untouched; only actives evolve.

## Testing

Engine (RED first): evolving retires the parent (owned, slot, `level_of`), closes siblings (ready erased, `evolve` false, no
later ready), `grant` of an evolution retires an owned parent and refuses a taken branch's parent, `reset_run` reopens.
Validator: each rule with a bad def. UI model: rows with direction, retired parent absent, armed then confirm evolves,
moving disarms. Each new ability: its behaviour (Zip Line reaches the anchor and releases; Binding Web holds at once and the
patch slows; Torrent damages and shoves in the box and not outside it; Miasma leaves a poisoning cloud; Venom Bolt pierces
two enemies and stops at rock; Healing Spores heals only while inside; Puffball bursts at its landing point). Data: every new
skill loads, has an icon and a cue, and its unlock names real skills. An end-to-end run per tree evolves each branch in a
fresh run and checks the others close.

## Rulings I made

1. **Exclusive per life**, not re-pickable. The game's loop is reincarnation, so trying the other branch is a rebirth away;
   Hollow Knight-style re-picking is a different game. Cost if wrong: an unhappy player restarts; a later "respec" is one
   call to `reset` a branch.
2. **Child restarts at level 1.** Carrying the parent's level needs a mapping between two value tables. Cost if wrong: a short
   regrind; the level-1 values are set high enough that it is not felt.
3. **`replaces` is the branch key**, not a new group field, so the data cannot disagree with itself.
4. **Cross-skill unlocks** (Zip Line needs Leap, Binding Web needs Poison Breath) pair skills the way the existing
   evolutions already do, so the branch you can take depends on what you have eaten. Cost if wrong: an unreachable branch in
   a life; the validator only checks the skills exist, and the plan adds a test that every branch is reachable from some kit.
5. **Two presses to evolve** because the choice is permanent for the life and the current single press would lose it to a
   stray Enter.

## Not here

Hold-to-channel casting, the water stream that becomes a blade, the web that can be held, and the new visual effects for
web, water and blade (a separate spec, next). Passive evolutions. Summons. A respec.
