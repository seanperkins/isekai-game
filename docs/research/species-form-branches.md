# Form 2 to 4 branches for the wolf, undead, spider, goblin and slime

A menu of evolution branches drawn from folklore and legend. **Proposal only: nothing new here is built** (the slime's built forms are marked in section 8). Sean's answers to the open questions are in section 10 (2026-10-04); the decided undead flesh path is marked in section 4. Written from recall of the legends; nothing was fetched and there are no URLs, so every source claim is tagged [inf] and should be checked before it goes into player-facing copy. Companion to `species-evolution-guide.md` (sections 6 to 9 sketch these same species; this replaces their ladders if adopted) and `isekai-chronicles-design-doc.md`.

Sean's four asks are marked **★**: the werewolf (W2A), a secret light-essence undead from the lich side (U4D1c), lumbering undead that swing weapons with heft (U2A, U3A2, U2B, U3B1, U4B1b, U4A2b) and a half-spider, half-person (S2A).

## 1. The shape, and what it changes

Every species gets the same shape: **form 1 → 3 or 4 form-2 lines → each splits into 2 form-3s → each of those into 2 form-4s.** Undead and goblin have four lines, wolf and spider three, and the slime keeps its six. Branches never rejoin, so the form-3 choice now decides the ending. That fixes the slime's soft spot (every stage-3 form leads to one shared stage 4, guide section 1). Decided (2026-10-04): **the slime moves to this shape too** (section 10). Its draft is section 8: it keeps its six lineages as the form-2 lines and its 24 built forms, and gains 18 new form-4s.

This is a different shape from the guide's ladders, which fork at stage 3 with one stage-2 form. Where the guide named a form, it keeps the name in the slot below.

| Guide name | Now |
|---|---|
| Wolf: Hunter (S2) | replaced by the three lines W2A to W2C |
| Wolf: Dire, Grim, Barghest | W3C1, W3C2, W3B1 |
| Wolf: Greatwolf, Warden, Omen, Hellhound | W4C1a, W4C2a, W4B1b, W4B1a |
| Wolf: Moonbound (secret, night-only) | W2A, now a normal branch (it can still ask for moonlight) |
| Undead: Zombie, Archer, Adept | U2A, U2C, U2D |
| Undead: Ghoul, Deadeye, Lich | U3A1, U3C1, U3D1 |
| Undead: Vampire, Skull, Abomination | U4A1a, U4D1b, U4A2b |
| Spider: Shadow-stalker, Venomspinner | S3C1, S3C2 |
| Spider: Broodmother, Brood Queen | S2B, S3B1 |
| Spider: Nightstalker, Plaguemother | S4C1a, S4C2a |
| Spider: Lure (secret, eat goblins) | S2A, S3A1 |
| Spider: Sparkweaver, Stormweaver | not placed; see the spares at the end of section 6 |
| Goblin: Tamer, Tinker, Skulker, Paladin | G2A, G2B, G2C, G3D2 |
| Goblin: Beastmaster, Engineer, Assassin | G4A2b, G3B1 and G3B2 (Knocker and Smith), G3C1 then G4C1a and G4C1b (Redcap's children) |

**Change to the design doc if adopted:** its "three directions off the skeleton" becomes four. A heavy-weapon **Bone Warrior** (U2B) joins flesh, bone-ranged and bone-magic. The decided flesh path (skeleton, zombie, ghoul, vampire) is unchanged: Zombie is U2A, Ghoul U3A1, Vampire U4A1a.

## 2. How the tables read

- **ID** encodes the parent: `W3A1` is the first form-3 under line A; `W4A1b` its second child. Form-1 is the species' base body.
- **Reads** is the essence it asks for. Every form-2 opens from the five elements that exist now (water, earth, air, light, dark). *Italics* mean an element that does not exist yet (fire, mind, blood): the form waits for it.
- **Opened by** respects each species' essence method: wolf and spider eat living things, undead drain life force, and the goblin never devours for essence, so its forms are opened by **lessons** (the first defeat, taming or interaction with a creature type). A **graft** (an undead part) or a **power** can also open a form.
- **Profile**: `same` uses the species' existing movement profile (`data/movement/`). `stance` swaps between two existing profiles. `new (what)` needs a new movement profile or mode, which is engine work, and species wiring into the real Player is still paused. A bigger body is a size on the creature size ladder, not a new profile, so it stays `same`.
- **Host** is the area: Cave, Grotto, Flooded, Deep (built) and forest, swamp, village, sacred, cemetery, crypt, volcano, demon (planned, art borrowed from a built biome by `data/area_art.json`).
- **Living traditions.** Some sources are living religious traditions or sacred figures (Pashupati, the Cave of Thawr, incorrupt saints, the Dewa Sanzan monks). They are fine as design references; check them before any becomes a player-facing name.
- **Ids** get a species prefix (`wolf_`, `undead_`, `spider_`, `goblin_`) so none collide with the slime's `data/forms/` ids (`arachne`, `weaver`, `snare`, `silkbound`, `venom`, `storm`, `tempest`, `phantom`, `echo` and more). Display names also avoid the slime's: the half-spider is **Weavermaid**, not Arachne.
- **Heft** is a proposed mechanic for the lumbering forms: a slow wind-up, a long arc, no turning mid-swing, super-armor while swinging, big knockback. The weapon comes from an arm graft (undead) or the form's own claws or club.

## 3. Wolf (quadruped; devours living things; pounce is the kill verb)

```
Pup
├─ W2A ★ Moonbound ─┬─ W3A1 Loup-Garou ─┬─ W4A1a Beast of Gévaudan
│                   │                   └─ W4A1b Lycaon
│                   └─ W3A2 Úlfheðinn ──┬─ W4A2a Wolfskin Champion
│                                       └─ W4A2b Sköll
├─ W2B Black Dog ───┬─ W3B1 Barghest ───┬─ W4B1a Hellhound (fire, later)
│                   │                   └─ W4B1b Black Shuck
│                   └─ W3B2 Cŵn Annwn ──┬─ W4B2a Gabriel Hound
│                                       └─ W4B2b Cù Sìth
└─ W2C Warg ────────┬─ W3C1 Dire Wolf ──┬─ W4C1a Fenrir
                    │                   └─ W4C1b Amarok
                    └─ W3C2 Church Grim ┬─ W4C2a Wepwawet
                                        └─ W4C2b Lupa
```

| ID | Form | Source [inf] | Reads | Verb | Gives up | Opened by | Host | Profile |
|---|---|---|---|---|---|---|---|---|
| W2A | ★ **Moonbound** | the werewolf: Ovid's Lycaon, the French loup-garou | dark | **Rise**: stand on two legs for claws and items, drop to four to gallop | rising costs a beat; no pounce while up | dark essence, plus a kill taken in moonlight (a moonlit forest room) or a rare Moonstone drop | forest | stance (wolf + biped) |
| W3A1 | **Loup-Garou** | cursed French and Canadian werewolf, bound by the moon and by breaking Lent | dark | **Frenzy**: each kill stokes a bloodlust meter (faster, bleeding bites); at full you cannot stop | no guard, no items while frenzied | Moonbound, plus Rise used many times | forest, swamp | stance |
| W4A1a | **Beast of Gévaudan** | the man-eater that terrorised the Gévaudan, 1764 to 1767; musket shot seemed not to hurt it | dark | **Stalk-kill**: a stealth opener that deals huge damage to the first target, shrugs off ranged hits | helpless against crowds | Loup-Garou, plus a no-damage kill streak | forest | stance |
| W4A1b | **Lycaon** | Ovid: the king who fed Zeus human flesh and was made the first wolf | dark | **First Wolf's roar**: wild wolves in the room join you briefly | weak alone | Loup-Garou, plus a bonded packmate | forest | stance |
| W3A2 | **Úlfheðinn** | Norse wolf-skin warriors, paired with the berserkers in the sagas (the Ynglinga saga says of Odin's berserk men that neither fire nor iron bit them) | dark + earth | **Skin**: you choose the change; a berserk window with no flinch and iron-proof | a crash after the window | Moonbound, plus earth | forest, Cave | stance |
| W4A2a | **Wolfskin Champion** | the same warriors at their peak: they howl and bite their shields | earth | **Shield-bite**: breaks guards; the berserk window refills on kills | still crashes if it ends dry | Úlfheðinn, plus broken guards | Cave | stance |
| W4A2b | **Sköll** | Norse: Sköll chases the sun and Hati the moon until Ragnarök | air + dark | **Chaser**: gallop never slows; mark a fleeing enemy and the pounce is free when you catch it | no stand-and-fight tools | Úlfheðinn, plus catching fleeing prey | Deep | stance |
| W2B | **Black Dog** | the British black dog omen: Black Shuck, the Barghest | dark + air | **Slink**: a silent gait in dark rooms; unseen until the pounce | weak in lit rooms | dark + air, plus kills from behind | cemetery, crypt | same |
| W3B1 | **Barghest** | Yorkshire's spectral black hound, an omen of death | dark | **Fear howl**: enemies falter and flee | cannot pounce while howling | Black Dog, plus a Howl power | crypt, Deep | same |
| W4B1a | **Hellhound** | Garmr at Hel's gate (Norse); Cerberus (Greek) | *fire* + dark | **Burning pounce** and a flame trail; a gate-guard verb | fire hurts your own packmate | Barghest, plus fire (later) | volcano, demon | same |
| W4B1b | **Black Shuck** | East Anglia's giant black dog with one burning red eye; the Bungay church story of 1577 | dark | **Omen**: mark one enemy; it dies in ten seconds unless it cleanses | one mark at a time | Barghest, plus a marked kill | crypt, Deep | same |
| W3B2 | **Cŵn Annwn** | Welsh hounds of the Otherworld: white with red ears, hunting souls | dark + light | **Spectral pack**: two echoes of you pounce with you | the echoes fade after eight seconds | Black Dog, plus light | cemetery, sacred | same |
| W4B2a | **Gabriel Hound** | northern England's Gabriel Ratchets and Devon's Wisht hounds: a ghost pack heard overhead, an omen | air + dark | **Hunt's passage**: the pack carries you over one gap (a short glide) | glide only after a kill | Cŵn Annwn, plus air | Deep | new (glide) |
| W4B2b | **Cù Sìth** | Scottish fairy hound, dark green and the size of a calf; it barks three times | earth + air | **Three barks**: two warnings, then a lunge you cannot dodge from range | stand still to bark | Cŵn Annwn, plus a ranged kill | forest | same |
| W2C | **Warg** | Norse vargr, "wolf" and "outlaw"; the war-wolf of fantasy | earth | **Bond**: a heavier pounce, knockback, one bonded packmate | slow gallop | earth, plus a bonded packmate | forest, Grotto | same |
| W3C1 | **Dire Wolf** | a fantasy staple, not folklore | earth | **Tank**: the pounce knocks down heavy targets; knockback-proof | slow | Warg, plus earth | Cave, Grotto | same |
| W4C1a | **Fenrir** | Norse: bound by Gleipnir, breaks all chains | earth | **Unbound**: breaks barriers and grates (a gate-breaking verb) | too big for small gaps | Dire Wolf, plus barriers broken | Deep | same |
| W4C1b | **Amarok** | Inuit: a giant lone wolf that hunts those who hunt alone at night | earth + water | **Lone hunter**: strongest with no packmate, hunts isolated prey | the bond is disabled | Dire Wolf, plus rooms cleared alone | Deep | same |
| W3C2 | **Church Grim** | the black dog buried at the church wall to guard the churchyard | light + earth | **Guardian**: wards a packmate, holds holy ground, unharmed in holy zones | tethered to a sacred spot | Warg, plus light | sacred, cemetery | same |
| W4C2a | **Wepwawet** | Egypt's wolf (or jackal) "Opener of the Ways", who leads the army and the dead | light + air | **Opener**: reveals hidden exits and shortcuts in a room | low damage | Church Grim, plus a hidden room found | sacred | same |
| W4C2b | **Lupa** | Rome's Capitoline she-wolf who nursed Romulus and Remus | light | **Suckle**: heals packmates and grows a pup into a second packmate | weak pounce | Church Grim, plus a long bond | forest | same |

## 4. Undead (biped; drains life force; grafts)

```
Skeleton
├─ U2A Zombie (decided) ──┬─ U3A1 Ghoul ────────┬─ U4A1a Vampire (decided, blood later)
│                         │                     └─ U4A1b Jiangshi
│                         └─ U3A2 ★ Draugr ─────┬─ U4A2a Barrow-King
│                                               └─ U4A2b ★ Abomination
├─ U2B ★ Bone Warrior ────┬─ U3B1 ★ Revenant Knight ─┬─ U4B1a Dullahan
│                         │                          └─ U4B1b ★ Bone Colossus
│                         └─ U3B2 Spartoi Hoplite ───┬─ U4B2a Sower of Teeth
│                                                    └─ U4B2b Master of the Dance
├─ U2C Skeletal Archer ───┬─ U3C1 Deadeye ──────┬─ U4C1a Arash
│                         │                     └─ U4C1b Wild Huntsman
│                         └─ U3C2 Corpse Candle ┬─ U4C2a Stingy Jack
│                                               └─ U4C2b Banshee
└─ U2D Adept ─────────────┬─ U3D1 Lich ─────────┬─ U4D1a Deathless
                          │                     ├─ U4D1b Demilich
                          │                     └─ U4D1c ★ Hierophant (secret, light)
                          └─ U3D2 Mummy-Priest ─┬─ U4D2a Pharaoh
                                                └─ U4D2b Heart-Weigher
```

| ID | Form | Source [inf] | Reads | Verb | Gives up | Opened by | Host | Profile |
|---|---|---|---|---|---|---|---|---|
| U2A | ★ **Zombie** (decided) | Haitian zombi; the shambling dead of film | earth + dark | **Devour** corpses to heal; **heft**: slow, heavy swings | slow, a low jump | ribs and flesh grafts, plus earth + dark | swamp, cemetery | same |
| U3A1 | **Ghoul** (decided) | the Arabic ghūl: a desert corpse-eater and shapeshifter | dark + earth | claws, a paralysing touch, a stench cloud | frail to light | Zombie, plus claw grafts | cemetery, crypt | same |
| U4A1a | **Vampire** (decided) | European vampire lore | dark + *blood* | uses items; devours blood | holy and speed trade (guide SA2) | Ghoul, plus blood (later) | demon | same |
| U4A1b | **Jiangshi** | the Chinese hopping corpse, stopped by talismans, sticky rice and peach wood | dark + air | **Hop**: bounding straight-line leaps that drain on touch | cannot turn mid-hop; talisman rooms stop it | Ghoul, plus air | village, cemetery | new (hop) |
| U3A2 | ★ **Draugr** | the Norse barrow-dweller: swells huge, guards a hoard | earth + dark | **Heft**: huge barrow-blade swings; it swells as it kills | no jump; slowest of all | Zombie, plus an arm graft with a weapon | cemetery, crypt, Deep | same |
| U4A2a | **Barrow-King** | the haugbúi, a mound-dweller sitting on its hoard | earth | **Barrow slam**: a ground-pound shockwave; armour while carrying items | stuck to the room's hoard | Draugr, plus carried items | Deep | same |
| U4A2b | ★ **Abomination** | Shelley's Frankenstein creature; the Warcraft abomination (guide) | earth + dark | **Heft** cleaver; extra graft slots (a stitched body) | stench; slow | Draugr, plus four grafts held | Deep | same |
| U2B | ★ **Bone Warrior** | the sown warriors of Cadmus and Jason, grown from dragon's teeth | earth + dark | **Heft**: a slow overhead cleave and a shield | slow | skeleton, plus a weapon arm graft and earth | crypt, Cave | same |
| U3B1 | ★ **Revenant Knight** | the revenant: the dead who return to take vengeance (medieval chronicles) | earth + dark | **Vengeance**: hits harder against the creature that killed your last life; heavy swings | slow turning; no ranged | Bone Warrior, plus killing what killed you | crypt | same |
| U4B1a | **Dullahan** | the Irish headless rider with a spine whip; no lock holds against it | dark | **Herald**: a long whip, a thrown head | no shield | Revenant Knight, plus whip-reach kills | crypt, Deep | same |
| U4B1b | ★ **Bone Colossus** | giants made of bone: Ymir, whose bones were the mountains | earth | **Juggernaut**: double size, stomp and heft cleave; walks through hazards | too big for narrow gaps | Revenant Knight, plus many bone grafts | Deep | same |
| U3B2 | **Spartoi Hoplite** | Cadmus's sown men | earth + dark | **Shield wall**: block and spear thrust; sow two bone soldiers | rooted while sowing | Bone Warrior, plus a summon power | crypt, Deep | same |
| U4B2a | **Sower of Teeth** | Cadmus sowing the dragon's teeth | earth + dark | a squad of four sown soldiers | weak alone | Spartoi Hoplite, plus corpses | crypt | same |
| U4B2b | **Master of the Dance** | the medieval Danse Macabre: Death leads every rank in a dance | dark | **Rise**: downed enemies stand up as dancers for ten seconds | only works near bodies | Spartoi Hoplite, plus bodies left | cemetery | same |
| U2C | **Skeletal Archer** (decided path) | the bone-ranged path in the design doc | air + dark | returning bone throws, bow arm | frail | bow-arm graft, plus air | cemetery, crypt | same |
| U3C1 | **Deadeye** | *Der Freischütz*: magic bullets; six hit true, the seventh is the Devil's | dark | six sure shots, then a cursed seventh | the seventh costs HP | Archer, plus a perfect-hit streak | crypt | same |
| U4C1a | **Arash** | Persian: the archer whose arrow marked the border and who died of the shot | air | **Life-arrow**: spend most of your HP on one arrow that crosses the room and pierces | leaves you at 1 HP | Deadeye, plus a far switch hit | Deep | same |
| U4C1b | **Wild Huntsman** | the Wild Hunt (Odin, Herne, the Gabriel hounds): the rider who runs prey down | dark + air | **Mark**: arrows home on one marked prey | one mark at a time | Deadeye, plus a long chase | forest, crypt | same |
| U3C2 | **Corpse Candle** | the Welsh canwyll corff: a light seen before a death; the will-o'-the-wisp | dark + air | **Lure-light**: enemies follow a drifting light into hazards | the light shows where you are | Archer, plus air | swamp | same |
| U4C2a | **Stingy Jack** | Irish: the man who tricked the Devil and wanders with a coal in a turnip | dark + *fire* | **Trick**: an enemy that touches your lure is held fast | needs the lure placed first | Corpse Candle, plus fire (later) | swamp | same |
| U4C2b | **Banshee** | the Irish bean sídhe: her wail foretells a death | air + dark | **Wail**: a cone that stuns and frightens | wakes sleeping enemies | Corpse Candle, plus a held wail | crypt | same |
| U2D | **Adept** | necromancy: the Witch of Endor raising Samuel; the Nekyia in the Odyssey | dark | a few bone minions; a focus | frail | skull or focus graft, plus dark | crypt, Deep | same |
| U3D1 | **Lich** (decided path) | the *lic* is the corpse; Koschei's hidden soul | dark | bouncing bone beams, a blink; a phylactery anchors remains | frail | Adept, plus a focus graft | crypt | same |
| U4D1a | **Deathless** | Koschei the Deathless: his soul sits in a needle in an egg in a duck in a hare in a chest under an oak | dark | **Hidden soul**: place an anchor; if you die in range you rise there once per life | the anchor can be destroyed | Lich, plus a phylactery shard | Deep | same |
| U4D1b | **Demilich** | tabletop lore: a lich reduced to a skull (guide's Skull) | dark | a floating skull, very frail, very strong | the frailest form | Lich, plus every limb graft shed | Deep | new (float) |
| U4D1c | ★ **Hierophant** (secret, light) | the arch-priest: the Dewa Sanzan monks who mummified themselves in life, incorrupt saints, the Greek hierophant | light + dark | **Consecrate**: a ring of light that heals you and your summons and burns the living | no life-drain (you absolve, you do not drain); weak dark powers | Lich, plus held light essence and a Vigil (section 5) | sacred | same |
| U3D2 | **Mummy-Priest** | the Egyptian embalmed priest-magician; the mummy's curse | dark + earth | **Wrap**: bandages bind enemies; a sand gust | fire hurts | Adept, plus earth and bandage grafts | crypt, Deep | same |
| U4D2a | **Pharaoh** | the Egyptian king buried with a household of the dead | dark | **Decree**: a curse ring marks everything in the room; tomb guards rise | slow | Mummy-Priest, plus a long reign (rooms held) | Deep | same |
| U4D2b | **Heart-Weigher** | Ammit, who eats hearts that weigh heavier than the feather | dark + earth | **Weigh**: if a creature's essence is lower than yours, drain it at once | useless against stronger foes | Mummy-Priest, plus drains of stronger prey | Deep | same |

## 5. The secret light undead, and what it answers

Sean's direction on guide decision 4 ("what does light do for an undead player?") is one secret light-aligned undead on the lich side. The mechanism below (the Vigil, the immunity, the no-drain trade-off) is a proposal for that: **light stays closed to undead everywhere except one secret form**, the Hierophant (U4D1c). Everything else about light stays as designed: holy halls hurt, and each form's `holy_resist` sets how much (guide SA2).

- **Getting light essence.** Undead drain life force, so they drain a light-bearing creature (the sacred area's, not yet authored). Light essence then sits in the pool like any other. It is not poisonous to hold; only standing in a holy emitter hurts.
- **The unlock (a secret condition, guide decision 3).** As a **Lich** (U3D1): hold at least a set amount of light essence, then complete a **Vigil**: stand in a consecrated hall's holy emitter for a set time without dying. The Lich's ward makes that possible but tight. Passing it turns the Lich into a Hierophant at the next evolution.
- **What it does to `holy_resist`.** The Hierophant is **immune**, and holy emitters heal it instead of hurting it. The cost is that it can no longer drain life (it heals from its own consecration instead) and its dark powers are weaker.
- **Tree screen.** It shows as a dotted-edge ??? stub (guide section 13: dotted for secret) once the Lich holds any light.
- **Story hook (optional).** An arch-priest who serves a god that is not the goddess, which suits her late reveal as the antagonist.

## 6. Spider (crawler; devours living things; cocoons)

```
Spiderling
├─ S2A ★ Weavermaid ─┬─ S3A1 Jorōgumo ──────┬─ S4A1a Seven Spider Spirits
│                    │                      └─ S4A1b Tsuchigumo
│                    └─ S3A2 Loom-Weaver ───┬─ S4A2a Norn
│                                           └─ S4A2b Anansi
├─ S2B Broodmother ──┬─ S3B1 Brood Queen ───┬─ S4B1a Cocoon-Mother
│                    │                      └─ S4B1b Swarm Sovereign
│                    └─ S3B2 Cave Matriarch ┬─ S4B2a Light-Eater
│                                           └─ S4B2b Chasm-Weaver
└─ S2C Stalker ──────┬─ S3C1 Shadow-stalker ┬─ S4C1a Nightstalker
                     │                      └─ S4C1b Veil-Spinner
                     └─ S3C2 Venomspinner ──┬─ S4C2a Plaguemother
                                            └─ S4C2b Tarantella
```

| ID | Form | Source [inf] | Reads | Verb | Gives up | Opened by | Host | Profile |
|---|---|---|---|---|---|---|---|---|
| S2A | ★ **Weavermaid** | the jorōgumo; the seven spider spirits of *Journey to the West*; the drider and the arachne of *Spider, So What?* (not Ovid's Arachne, who becomes wholly a spider) | air + dark | **Hands**: a person's torso on a spider body; uses items, tools and bows | a slower wall crawl | air + dark, plus eating goblins (the guide's Lure condition) | village, forest | new (hands) |
| S3A1 | **Jorōgumo** | Japanese: a spider that takes a woman's shape and lures men; her true form is revealed later | air + dark | **Veil**: pass as a goblin or villager (village standing reads you as welcome); revealing it bursts the veil | the veil drops when hit; no webbing while veiled | Weavermaid, plus a visit to the village unseen | village | new (hands) |
| S4A1a | **Seven Spider Spirits** | the spider demons of Pansi Cave in *Journey to the West* | dark | **Sisters**: split into seven decoys that web | each decoy dies in one hit | Jorōgumo, plus a veiled kill | Deep | new (hands) |
| S4A1b | **Tsuchigumo** | Japanese "earth spider": the giant that Minamoto no Raikō fought | earth + dark | **True form**: drop the veil into a giant; burrow a lair; call lesser spiders | too big for small gaps | Jorōgumo, plus earth | Deep | new (burrow) |
| S3A2 | **Loom-Weaver** | Ovid's Arachne, the weaver who challenged Athena | air + dark | **Tapestry**: weave a patterned web that stays as a trap and a snare | slow to weave | Weavermaid, plus Web Shot and Ground Web powers | forest, sacred | new (hands) |
| S4A2a | **Norn** | the Norns (Urðr, Verðandi, Skuld) weaving fate; the Greek Moirai | air + light | **Fate thread**: tie a thread to an enemy; the next hit it lands on you is sent back | fragile | Loom-Weaver, plus light | sacred | new (hands) |
| S4A2b | **Anansi** | the Akan trickster spider who bought all the stories from the sky god | air + dark | **Steal**: take a power or essence from a living enemy without killing it (the decided future method) | weak direct damage | Loom-Weaver, plus snaring and freeing a creature | village | new (hands) |
| S2B | **Broodmother** | wolf spiders carry their young; the spiderlings of *Spider, So What?* | earth + dark | **Brood**: cocoons hatch spiderlings that carry and harass | slow; fewer solo kills | earth + dark, plus the Cocoon power | forest | same |
| S3B1 | **Brood Queen** | the guide's S4 name, moved here | earth + dark | **Command**: spiderlings follow your lead | fewer solo kills | Broodmother, plus Brood Sac | forest, Grotto | same |
| S4B1a | **Cocoon-Mother** | (decided: a cocoon can hold living prey) | earth + dark | prey cocooned alive hatch into stronger young | takes time | Brood Queen, plus a cocooned live prey | forest | same |
| S4B1b | **Swarm Sovereign** | real spiderlings disperse in a cloud | dark + air | **Disperse**: the body breaks into a swarm that squeezes through grates and reforms (a traversal gate) | cannot fight while dispersed | Brood Queen, plus air | Deep | new (swarm) |
| S3B2 | **Cave Matriarch** | the giant cave spiders of epic fantasy: Shelob, Ungoliant | earth + dark | a huge lone hunter: heavy bite, a web wall | slow; no small gaps | Broodmother, plus the Taratect eaten | Deep | same |
| S4B2a | **Light-Eater** | Ungoliant, who devours light | dark | **Drink**: eat lamps and glow pools to darken a room and heal | hurt by sacred light | Cave Matriarch, plus lamps drunk | Deep, sacred | same |
| S4B2b | **Chasm-Weaver** | Atlach-Nacha (Clark Ashton Smith, "The Seven Geases"): the spider spinning a web bridge across a chasm | earth + air | **Span**: spin a permanent web bridge across a gap (a traversal gate) | slow; both ends need anchors | Cave Matriarch, plus gaps crossed | Deep | same |
| S2C | **Stalker** | trapdoor and huntsman spiders: the ambush hunter | dark + air | **Ambush**: a ceiling drop and a web zip | weak in lit rooms | air + dark, plus kills from the ceiling | crypt, Cave | same |
| S3C1 | **Shadow-stalker** | (guide) | dark + air | **Silent drop**: a bonus strike in dim light | weak in lit rooms | Stalker, plus kills in the dark | crypt | same |
| S4C1a | **Nightstalker** | (guide) | dark | kills reset the zip; unseen in shadow | needs shadow | Shadow-stalker, plus an unseen kill streak | crypt | same |
| S4C1b | **Veil-Spinner** | the spider that hid a fugitive in a cave: David from Saul (Jewish midrash), the Prophet at the Cave of Thawr (Islamic tradition) | air + earth | **Veil**: spin a web over a doorway that hides you and allies | the veil breaks on any attack | Shadow-stalker, plus time spent hidden | Cave, sacred | same |
| S3C2 | **Venomspinner** | (guide) | water + dark | webs apply poison that spreads through trap webs | lower direct damage | Stalker, plus Venom Fang and a poison power | swamp | same |
| S4C2a | **Plaguemother** | (guide) | water + dark | a poison cloud that spreads on death | slow | Venomspinner, plus a poison kill streak | swamp | same |
| S4C2b | **Tarantella** | tarantism in southern Italy: the tarantula's bite thought to cause frenzied dancing | water + air | **Dance-venom**: a bitten enemy staggers erratically into hazards | slow to take hold | Venomspinner, plus air | swamp | same |

Spares, not placed: **Sparkweaver** and **Stormweaver** (light + air lightning, after the guide) and a **Silverweaver** from the Ukrainian Christmas spider whose webs turned to silver (a light reading: heals, lights hidden routes). They can slot in as a fourth line, S2D.

## 7. Goblin (biped; learns instead of devouring; every form uses items)

```
Scrapper
├─ G2A Beastcaller ─┬─ G3A1 Pied Piper ───┬─ G4A1a Rat King
│                   │                     └─ G4A1b Orpheus
│                   └─ G3A2 Beast-Rider ──┬─ G4A2a Wolf-Lord
│                                         └─ G4A2b Lord of Beasts
├─ G2B Tinker ──────┬─ G3B1 Knocker ──────┬─ G4B1a Gremlin
│                   │                     └─ G4B1b Rumpelstiltskin
│                   └─ G3B2 Smith ────────┬─ G4B2a Mastersmith
│                                         └─ G4B2b Ring-Maker
├─ G2C Skulker ─────┬─ G3C1 Redcap ───────┬─ G4C1a Ironboot
│                   │                     └─ G4C1b Bloodcap
│                   └─ G3C2 Puck ─────────┬─ G4C2a Changeling
│                                         └─ G4C2b Leprechaun
└─ G2D Hob ─────────┬─ G3D1 Tomte ────────┬─ G4D1a Hearth-God
                    │                     └─ G4D1b Boggart
                    └─ G3D2 Paladin ──────┬─ G4D2a Horn-Bearer
                                          └─ G4D2b Giant-Killer
```

| ID | Form | Source [inf] | Reads | Verb | Gives up | Opened by (lessons) | Host | Profile |
|---|---|---|---|---|---|---|---|---|
| G2A | **Beastcaller** | goblin wolf-riders of fantasy; the Pied Piper; Orpheus | earth + air | **Offer**: an item to a weakened creature, which follows you (decided taming) | weak alone | earth + air, plus lessons from wolves, spiders and bats | forest, village | same |
| G3A1 | **Pied Piper** | Hamelin's piper, who led the rats away and then the children | air | **Tune**: a pipe call commands a small group and draws vermin | cannot throw while playing | Beastcaller, plus lessons from vermin | village | same |
| G4A1a | **Rat King** | the German *Rattenkönig*: rats whose tails are knotted into one | earth | **Knot**: a mobile swarm of tamed vermin acts as one big companion with area damage | stays one companion | Pied Piper, plus a tamed rat | Cave, village | same |
| G4A1b | **Orpheus** | Greek: the lyre that charmed beasts, trees and Hades | air + light | **Lull**: calm a hostile creature so it stops attacking and can be tamed | fails on bosses | Pied Piper, plus light | sacred | same |
| G3A2 | **Beast-Rider** | goblin wolf-riders (fantasy) | earth | **Mount**: fuse with the companion for a ride (the guide's Rider) | the companion is exposed | Beastcaller, plus a bonded large companion | forest | new (mounted) |
| G4A2a | **Wolf-Lord** | goblin wolf-rider chiefs (fantasy) | earth + air | a spear charge and gallop while mounted | on foot you are weak | Beast-Rider, plus a wolf bond | forest | new (mounted) |
| G4A2b | **Lord of Beasts** | the Master of Animals motif: Pashupati, Potnia Theron | earth + air | **Two companions** at once (a decided capstone exception to the one-at-a-time rule) | fragile companions | Beast-Rider, plus lessons from many types | Deep | same |
| G2B | **Tinker** | the kobold and the knocker; the dwarf-smiths Brokkr and Sindri | earth | crafted throwables, rigged traps, more recipe slots | weak in melee | earth, plus lessons from junk and ants | village, volcano | same |
| G3B1 | **Knocker** | the Cornish and Welsh mine spirits (knockers, bluecaps), whose taps warn of a collapse | earth | **Tap**: senses hidden walls, weak floors and traps in a room | low damage | Tinker, plus lessons from ants and bats | Cave, village | same |
| G4B1a | **Gremlin** | the RAF's gremlins, the saboteurs of machinery | earth + air | **Sabotage**: disable an enemy device or turn a trap against its owner | backfires sometimes | Knocker, plus rigged traps sprung | village | same |
| G4B1b | **Rumpelstiltskin** | Grimm: spins straw into gold at a price | earth + *mind* | **Spin**: transmute junk into a better part, two for one | wasteful | Knocker, plus mind (later) | village | same |
| G3B2 | **Smith** | Brokkr and Sindri forging Mjölnir and Draupnir | earth + *fire* | **Forge**: craft a named weapon from parts at a forge | needs a forge and time | Tinker, plus fire (later) | volcano | same |
| G4B2a | **Mastersmith** | the same smiths at the height of their craft | earth + *fire* | a second gear slot; flawless upgrades | high cost | Smith, plus a forged weapon | volcano | same |
| G4B2b | **Ring-Maker** | Alberich, who forged the cursed Ring of the Nibelungs | dark + *fire* | **Cursed gear**: huge stats with a real cost | the curse | Smith, plus dark | demon | same |
| G2C | **Skulker** | the redcap; Puck; Alberich's Tarnhelm | dark + air | sneak strike, smoke bomb | weak in melee | dark + air, plus lessons from bats and shadows | crypt, demon | same |
| G3C1 | **Redcap** | the Border legend: a goblin who dyes his cap in his victims' blood and must keep it wet | dark | **Dye**: each kill refreshes a blood-cap timer for speed and damage; if it dries you lose it | idle play wastes it; holy words repel | Skulker, plus a stealth kill chain | crypt | same |
| G4C1a | **Ironboot** | the redcap's iron-shod boots | earth + dark | **Stomp**: a heavy kick with heft | slow to sneak | Redcap, plus heavy kills | crypt | same |
| G4C1b | **Bloodcap** | the redcap's cap, fed to the full | dark | **Cap-throw**: a boomerang cap that returns, dyed | needs blood to dye it | Redcap, plus a full cap held | demon | same |
| G3C2 | **Puck** | Robin Goodfellow, the shapeshifter who leads travellers astray | air + dark | **Mislead**: illusions and decoys; reverse an enemy's facing | low damage | Skulker, plus lessons from wisps and moths | forest, swamp | same |
| G4C2a | **Changeling** | the fairy swap of a child | dark | **Swap**: trade places with a decoy; look like a creature to scout | the swap takes a beat | Puck, plus decoys used | village | same |
| G4C2b | **Leprechaun** | the Irish cobbler with a pot of gold | air + dark | **Pocket**: pickpocket items from a living creature without killing it; a short teleport | low damage | Puck, plus items stolen | forest | same |
| G2D | **Hob** | the brownie, the hob and the household spirit repaid in porridge | light | **Offer** and **Ward**: protects an area | passive, weak damage | light, plus lessons from light creatures | village, sacred | same |
| G3D1 | **Tomte** | the Scandinavian farm guardian: kind if respected, vicious if insulted | light + earth | **Hearth**: plant a ward-stone; creatures near it are slowed and you heal | static | Hob, plus a kept village | village | same |
| G4D1a | **Hearth-God** | the Roman Lares, guardians of the household | light | **Lar**: ward-stones link into one wider aura | immobile when it counts | Tomte, plus ward-stones placed | sacred | same |
| G4D1b | **Boggart** | the fallen hob: a house spirit that turns spiteful when wronged | dark | **Curse-stone** and a fear aura (a corrupted Tomte) | allies fear you too | Tomte, plus dark | swamp | same |
| G3D2 | **Paladin** | Charlemagne's paladins; Roland's horn, the Olifant | light | blessed throwables and a shield | slow | Hob, plus light | sacred | same |
| G4D2a | **Horn-Bearer** | Roland blowing the Olifant at Roncesvalles | light + air | **Horn**: a blast that stuns and rallies allies | loud | Paladin, plus a rally | sacred | same |
| G4D2b | **Giant-Killer** | Jack the Giant-Killer, Cornish folk tale; David and Goliath | light + earth | damage scales with the target's size | weak against small foes | Paladin, plus a large foe beaten | Deep | same |

## 8. Slime (bouncer; devours everything; parts in slots)

Sean's direction (section 10): the six built lineages stay as the form-2 lines; the stage-2 gate matches the other species; the tone is a mix of elementals and alchemy (Paracelsus's undine, sylph and gnome, the golem, the philosopher's stone) with jelly gags at the capstones.

What changes against what is built: all 24 forms keep their ids, art and stats. Each stage-3 form now has **its own two form-4s**. The six existing Sovereigns each keep one stage-3 parent (so `silkbound` and `storm`, for example, lose a parent) and 18 new form-4s are added. The stage-2 gate moves from "own any power of the lineage" (no cap, so nearly everyone sees the same five) to element-mix thresholds with powers as one input, like the other species; the Greater Slime fallback stays for a mixed diet. Existing form names are kept; the "Source" column is the folklore reading. Forms marked *(built)* exist today.

```
Slime
├─ J2W Weaver ────┬─ J3W1 Snare ─────┬─ J4W1a Silkbound Sovereign (built)
│                 │                  └─ J4W1b Gleipnir
│                 └─ J3W2 Arachne ───┬─ J4W2a Ariadne
│                                    └─ J4W2b Beanstalk
├─ J2T Tide ──────┬─ J3T1 Brook ─────┬─ J4T1a Tidal Sovereign (built)
│                 │                  └─ J4T1b Selkie
│                 └─ J3T2 Tempest ───┬─ J4T2a Kraken
│                                    └─ J4T2b Tiamat
├─ J2X Toxic ─────┬─ J3X1 Acid ──────┬─ J4X1a Venom Sovereign (built)
│                 │                  └─ J4X1b Alkahest
│                 └─ J3X2 Blight ────┬─ J4X2a Pestilence
│                                    └─ J4X2b Slime Mold
├─ J2B Bulwark ───┬─ J3B1 Golem ─────┬─ J4B1a Stone Sovereign (built)
│                 │                  └─ J4B1b Talos (fire, later)
│                 └─ J3B2 Crystal ───┬─ J4B2a Philosopher's Stone
│                                    └─ J4B2b Cube
├─ J2E Echo ──────┬─ J3E1 Phantom ───┬─ J4E1a Mimic (mind, later)
│                 │                  └─ J4E1b Poltergeist
│                 └─ J3E2 Sky ───────┬─ J4E2a Storm Sovereign (built)
│                                    └─ J4E2b Cloud-Rider
└─ J2G Greater ───┬─ J3G1 Vast ──────┬─ J4G1a Prime Sovereign (built)
                  │                  └─ J4G1b Shoggoth
                  └─ J3G2 Radiant ───┬─ J4G2a King Slime
                                     └─ J4G2b Quicksilver Slime
```

| ID | Form | Source [inf] | Reads | Verb | Gives up | Opened by | Host | Profile |
|---|---|---|---|---|---|---|---|---|
| J2W | **Weaver** (built) | Ariadne's thread; the spinner | dark | thread skills cost less | none | dark, plus Sticky Thread (three spiders eaten) | Cave, Grotto | same |
| J3W1 | **Snare** (built) | the Gordian knot, which nothing unties | dark | a living net: heavier, harder to shake off | slower thread | Weaver, plus dark | Grotto | same |
| J4W1a | **Silkbound Sovereign** (built) | the crowned spinner | dark + air | the web answers to you; wall cling | none | Snare, plus air | Grotto | same |
| J4W1b | **Gleipnir** | Norse: the ribbon of six impossible things that held Fenrir | dark | **Bind**: roots one big enemy or boss for a few seconds | long cooldown | Snare, plus a heavy enemy snared | Deep | same |
| J3W2 | **Arachne** (built) | the silk-legged climber | dark + air | wall cling | thin: low defence | Weaver, plus air | Grotto | same |
| J4W2a | **Ariadne** | the thread that led Theseus out of the labyrinth | dark + air | **Recall**: lay a trail, then return along it to its start | the trail must be laid first | Arachne, plus a long route walked | Deep | same |
| J4W2b | **Beanstalk** | Jack and the Beanstalk, the English folk tale | earth + air | **Stalk**: grow a climbable vine from the floor | one at a time, slow to grow | Arachne, plus earth | forest | same |
| J2T | **Tide** (built) | Paracelsus's undine, the water spirit | water | water skills cost less | none | water, plus Hydraulic Propulsion (four toads) | Cave, Flooded | same |
| J3T1 | **Brook** (built) | the undine | water | a quick, clear current: faster regen | little punch | Tide, plus water | Flooded | same |
| J4T1a | **Tidal Sovereign** (built) | the tide itself | water | the tide in a body | none | Brook, plus water | Flooded | same |
| J4T1b | **Selkie** | Scottish and Irish seal-folk who shed a skin to walk on land | water + earth | **Shed**: leave a husk decoy and slip away | the husk is gone until you rest | Brook, plus a decoy hit | Flooded | same |
| J3T2 | **Tempest** (built) | sea-storm lore; Prospero's tempest | water + air | a storm held in a body: harder hits | no extra regen | Tide, plus air | Flooded | same |
| J4T2a | **Kraken** | the Norwegian sea monster of Pontoppidan's 1752 account | water + dark | **Maelstrom**: a whirlpool that pulls enemies in | pulls loose parts too | Tempest, plus dark | Flooded, Deep | same |
| J4T2b | **Tiamat** | the Babylonian primordial sea, mother of monsters (Enūma Eliš) | water + dark | **Flood**: fills the room's low ground with water for a while | it slows you too unless you swim | Tempest, plus a flooded room cleared | Flooded | same |
| J2X | **Toxic** (built) | the Greek *pharmakon*, at once poison and remedy | water + dark | poison and spores; venom blood | none | water + dark, plus Poison Breath or Spore Cloud | Grotto | same |
| J3X1 | **Acid** (built) | the alchemists' aqua regia, which dissolves gold | water + earth | what touches you burns | weak defence | Toxic, plus earth | Grotto | same |
| J4X1a | **Venom Sovereign** (built) | the poisoner crowned | water + dark | every breath is a warning | none | Acid, plus dark | Grotto | same |
| J4X1b | **Alkahest** | the alchemists' universal solvent that dissolves every substance | water + earth | **Dissolve**: eat through a weak gate, grate or armour plate | corrodes your own held parts | Acid, plus a gate eaten | Flooded, Deep | same |
| J3X2 | **Blight** (built) | the miasma theory of plague; blighted crops | water + dark | a creeping rot you are immune to | low direct damage | Toxic, plus dark | Grotto, swamp | same |
| J4X2a | **Pestilence** | the Horseman of the Apocalypse; the Black Death's miasma | dark | **Contagion**: poison jumps between enemies standing close | slow to build | Blight, plus a poison kill streak | swamp | same |
| J4X2b | **Slime Mold** | the real *Physarum*, which finds the shortest route through a maze | earth + dark | **Network**: a growth spreads along the floor, slows enemies on it and shows the shortest route to a mark (a map aid) | creeps slowly | Blight, plus spores (air + dark) | forest, swamp | same |
| J2B | **Bulwark** (built) | the gnome, Paracelsus's earth spirit | earth | plated, slower, tougher | speed | earth, plus Body Armor, Hardened Shell or Tremor | Cave | same |
| J3B1 | **Golem** (built) | the Golem of Prague, clay animated by a word | earth | living stone: toughness | the slowest body | Bulwark, plus earth | Cave, Deep | same |
| J4B1a | **Stone Sovereign** (built) | a mountain that decided to move | earth | the heaviest armour | speed | Golem, plus earth | Deep | same |
| J4B1b | **Talos** | the Greek bronze giant whose one vein was sealed by a nail | earth + *fire* | **Guardian**: a patrol aura; if the visible nail is hit it drains you | the nail is a weak point | Golem, plus fire (later) | volcano | same |
| J3B2 | **Crystal** (built) | rock crystal in alchemy and folk belief | earth + light | a faceted body that turns blows aside | slow | Bulwark, plus light | Cave, sacred | same |
| J4B2a | **Philosopher's Stone** | alchemy's stone that turns base metal to gold | earth + light | **Transmute**: convert held essence of one element into another at a loss; digest parts faster | the conversion loss | Crystal, plus a mixed essence held | Deep | same |
| J4B2b | **Cube** | the tabletop gelatinous cube: a rigid jelly that engulfs | earth | **Engulf**: swallow a small enemy and hold it inside, digesting | big; a low jump | Crystal, plus enemies swallowed | Cave | same |
| J2E | **Echo** (built) | the nymph Echo (Ovid): a voice with no body | air | sonar: feel the shape of every room | none | air, plus Echolocation (three bats) | Cave | same |
| J3E1 | **Phantom** (built) | half a sound, half a body | air + dark | leap and a long jump | frail | Echo, plus dark | Deep | same |
| J4E1a | **Mimic** | the tabletop mimic; the absorb-and-copy slime of anime | air + *mind* | **Copy**: take the shape and one move of the last creature you inspected, for a short time | the copy fades | Phantom, plus mind (later) | Deep | same |
| J4E1b | **Poltergeist** | the German "noisy ghost" that hurls objects | air + earth | **Hurl**: throw loose rubble in the room at enemies | needs loose objects | Phantom, plus earth | Cave, Deep | same |
| J3E2 | **Sky** (built) | the sylph, Paracelsus's air spirit | air | light enough to ride the air: the highest jump | frail | Echo, plus air | Cave | same |
| J4E2a | **Storm Sovereign** (built) | thunder learned to walk | air | the fastest body | frail | Sky, plus air | Cave, Deep | same |
| J4E2b | **Cloud-Rider** | Sun Wukong's Somersault Cloud in *Journey to the West* | air | **Ride**: a short glide on a cloud | the cloud is brief | Sky, plus long jumps made | sacred | new (glide) |
| J2G | **Greater Slime** (built) | the fantasy-game jelly: simply a bigger slime | a mixed diet | adaptable; regeneration | none | no lineage open (the fallback) | Cave | same |
| J3G1 | **Vast Slime** (built) | Ymir, the first giant, whose body became the world (Norse) | water + earth | simply more of you: toughness | slow | Greater, plus bulk eaten | Cave, Deep | same |
| J4G1a | **Prime Sovereign** (built) | everything a slime can become | all five | regeneration, toughness, mana recovery | none | Vast, plus a mixed diet | Deep | same |
| J4G1b | **Shoggoth** | Lovecraft's shapeless protoplasm servants ("At the Mountains of Madness") | dark | **Pseudopod**: extrude long limbs for reach | shapeless: no steady form | Vast, plus dark | Deep | same |
| J3G2 | **Radiant Slime** (built) | *pwdre ser*, "star jelly", said in English folklore to fall with meteors | light | a steady inner light: mana recovery | frail | Greater, plus light | sacred | same |
| J4G2a | **King Slime** | the crowned slime of fantasy games | light + earth | **Court**: spawns a few lesser slimes that fight for you | the court dies in one hit | Radiant, plus slimes eaten | Cave, Grotto | same |
| J4G2b | **Quicksilver Slime** | alchemy's Mercurius; the metal slime gag | earth + air | fast and near-immune to damage but it flees; a tiny attack | cannot hold ground | Radiant, plus air | Cave | same |

## 9. Art, and where to start

This is 141 forms across five species (wolf 21, undead 29 including the secret, spider 21, goblin 28, slime 42), 117 of them new: the slime's 24 are built and 18 are added. Art cost drives how many to build. The cheapest are the modular ones: undead grafts and goblin gear are parts on a shared body, so most of those forms are recolours plus a part. Wolf and spider bodies cost more, and the forms marked `new` or `stance` in Profile cost engine work as well as art: the werewolf's stance swap (W2A, W3A1, W3A2 and children), the half-spider's hands (S2A and children), the Gabriel Hound's glide (W4B2a), Jiangshi's hop, Tsuchigumo's burrow, the Demilich's float, the Swarm Sovereign's squeeze, and the goblin mount.

A first slice that shows each new idea once, leaving the built slime forms as they are: **W2A** (stance), **S2A** (hands), **U2B and U3B1** (heft), **G2A** (taming, already decided).

## 10. Decided, and still open

Sean's answers, 2026-10-04:

1. **Scope:** keep all 99 forms as the design target. Lines can sit as stubs in the tree until their art exists.
2. **Lord of Beasts** (G4A2b): allowed as a capstone exception. One companion at a time stays the rule everywhere else.
3. **Hierophant** (U4D1c): earned by light essence plus a Vigil, as in section 5.
4. **Forms that need fire, mind or blood** show in the tree as ??? stubs now; the five-element forms are built first.
5. **Slime:** a full rebuild to this shape, not just splitting the six Sovereigns.
6. **Slime lineages:** the six built lineages (Weaver, Tide, Toxic, Bulwark, Echo, Greater) stay as the form-2 lines.
7. **Slime stage-2 gate:** absorbed-essence thresholds. A lineage opens when you have absorbed enough of its element or elements this life, tuned so a Cave run opens two or three; powers are one input. It replaces "own any power of the lineage". The numbers are open, and a top-three ranking was rejected (an earlier design found a ranking biased toward elements that level fast).
8. **Slime tone:** a mix of elementals and alchemy with jelly gags at the capstones.
9. **Next step:** draft the slime tree in this doc first (section 8), then decide the build with the whole picture on one page.
10. **Slime Sovereigns:** one stage-3 parent each, so no branch rejoins. The evolution tests encode the shared Sovereign today and are rewritten test-first with the build.
11. **Slime names:** every built name stays; the folklore reading lives in the blurb text.

Still open: the numeric absorbed-essence thresholds for each slime lineage, set against the real Cave and Grotto essence totals (`docs/ledgers/essence-calibration.md`).
