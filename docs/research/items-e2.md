# E2: lessons, bonds, hands and cocoons

What E2 builds, and why. It makes the 27 gate atoms that wait on E2 (`Deeds.RESERVED`) reachable by real play, using the buttons the game has. Source: `docs/isekai-chronicles-design-doc.md` (goblin lessons, taming, traps, cocoons) and `docs/research/species-form-branches.md` (each form's "Opened by"). E2 ships as four pieces, each its own plan, branch and review: **E2a** lessons, **E2b** bonds and companions, **E2c** the goblin's hands (pickpocket, traps, ward-stones, forging), **E2d** spider cocoons.

## The one new button rule

Every face button is taken, so the species' social action rides on `inspect` (Y), the way altars already do. Pressing it picks the first that applies: an interactable (altar, shrine); then the species action below; then inspect as today.

| Species | Nearby thing | Action | Deed |
|---|---|---|---|
| wolf | a stunned creature that can join a pack (`bonds` has `pack`) | bond | `bond_formed {kind: pack}` |
| goblin | a stunned creature that can be tamed (`bonds` has `tame`), and a part in the pack | offer the part: tame it | `bond_formed {kind: tame}` |
| goblin | a living creature with something to take | pickpocket | `item_stolen` |
| spider | a stunned living creature | cocoon it | `prey_cocooned` |
| spider | nothing to inspect, a cocoon carried | free the prey | `prey_freed` |

"Weakened" means stunned and alive (`EnemyStatus.STUNNED`); a downed corpse cannot bond or be cocooned.

## E2a: lessons (the goblin's essence)

- A **lesson** is the goblin's first dealing with a creature type in a life: downing it, eating it, taming it. It says `lesson_learned {creature, species, element}` (`element` is the creature's largest essence, ties in `Essences.ALL` order) and pays that creature's essences once as `absorbed`.
- A repeat with the same type pays a **trickle**: 1 unit of its largest essence, no deed. A creature is paid once however it ends (downed then eaten pays once).
- The goblin **eats only to heal**: eating pays no essence by itself. Every other species is unchanged.
- Lessons are per life (the ledger is), and the set resets with a new run.
- `junk` is a support monster (a heap of scrap, earth) so the Tinker's "lesson from junk" has a source; F2 places it.

## E2b: bonds and companions (built)

Built 2026-10-05: `CreatureDef.bonds`, `Enemy.can_be_bonded`, `Companion`, `Player.try_bond`. `pack`: `gloom_wolf`, `bone_hound` and the 21 wolf twins. `tame`: `cave_rat`, `gloom_wolf`, `tusker_boar`, `stone_drake`. `large`: `tusker_boar` and `stone_drake` (their stats are small or not, so size is data and not `max_hp`). A goblin offers the first carried part. A companion never strikes a stunned creature, so it cannot kill what the player means to eat or bond.

- A **companion** is a creature that follows the player and fights beside it with its own stats. It has HP and is hurt by the contact hits of enemies near it; it is **lost for good** when it dies, and with the player's death or a new run. It follows through room changes. Cap one at a time, two for the Lord of Beasts form.
- `CreatureDef.bonds: Array` names the bonds a creature accepts (`pack`, `tame`). Wolf-kind creatures take `pack`; vermin, wolves and boars take `tame`.
- A bond says `bond_formed {kind, creature}`. A creature whose `bonds` list `large` also says it with `kind: large`. A bond that has lasted `LONG_BOND_SECONDS` of play says it once more with `kind: long`.
- A goblin's companion grows with the goblin's lessons of its type (+1 ATK per three dealings with its type, the first included, up to +3).
- Taming is also a lesson (E2a), and a bond is not a kill: the creature is not downed and says no `defeated`.

## E2c: the goblin's hands

- **Pickpocket** (Y near a living, not-stunned creature with drops): rolls the creature's drops once (`Drops.roll`); a part found is taken without a fight (`part_harvested`, `item_stolen`), and the creature cannot be robbed twice. An empty pocket costs nothing and says nothing.
- **Traps**: the Tinker's verb becomes `trap`: it rigs a trap at the player's feet that an enemy springs by stepping in (damage and a stun). A sprung trap says `trap_sprung`. Traps outlive evolution, so rigging three as a Tinker opens the Gremlin from the Knocker.
- **Ward-stones**: a verb spec may carry `deed`; the Tomte's and the Hearth God's zones say `ward_stone_placed` when cast.
- **Forging**: the Smith's verb carries `needs_parts: 2` and `deed: weapon_forged`: it spends two carried parts, then grants a lasting +2 ATK for the life (a named weapon), and says the deed. Without the parts it does nothing and costs nothing. (The design says "at a forge"; forges arrive with the village in F2, so for now it is portable.)

## E2d: cocoons

- A cocoon holds one living creature. It is carried like any item: the id `cocoon:<creature>` in the inventory, held (never worn), at most two at once, left in the remains with the rest.
- Cocooning removes the creature (it is not downed) and says `prey_cocooned {creature}`.
- **Eaten later**: with a cocoon carried and nothing to eat, the predate button eats it: that creature's essences and an eat's heal, as eating it alive would.
- **Freed**: Y with nothing to inspect, a cocoon carried: the creature is let out beside the spider, stunned, and the deed `prey_freed` is said.

## What stays for F2

`weapon_forged` at real forges, junk piles as interactables, and the traps and hidden things the Knocker's reveal finds are rooms' content (F2). E2 leaves their gates met by the portable versions above.

## Not built here

The goblin's radial wheel and item combine; recipes beyond the forge; what each tamed creature adds beyond its own stats; the Beast Rider's fused ride; the Rat King's swarm. Their verbs stay as the C2 approximations.
