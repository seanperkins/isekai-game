# Verbs, full: ledger

Goal: every form verb does what `docs/research/species-form-branches.md` agreed (its DOC text), **and its DRAW is a mechanic**, not flavour. A row is `full` when a test casts the real verb and checks both. Packs: **A** mind (flee, calm, lure, confuse, reverse, unseen, swap), **B** stances and meters (kill windows, crash, swell), **C** companions (bond, tame, summon, ward-stones), **D** projectiles (return, home, cost, count, warn), **E** the world (water, vine, bridge, hidden, dissolvable, poison spread), **F** body and items.

Status: `todo`, `done` (full, tested), `kept approx` (needs a system that does not exist; listed in the report).

## Form verbs

| Form | Verb | Was | Pack | Agreed (DOC) | Drawback (DRAW, a mechanic) | Test | Status |
|---|---|---|---|---|---|---|---|
| gleipnir | Bind | full | audit | **Bind**: roots one big enemy or boss for a few seconds | long cooldown | | todo |
| shoggoth | Pseudopod | full | audit | **Pseudopod**: extrude long limbs for reach | shapeless: no steady form | | todo |
| poltergeist | Hurl | approx | D | **Hurl**: throw loose rubble in the room at enemies | needs loose objects | tests/test_pack_d_forms.gd + test_pack_d_mechanics.gd | done |
| kraken | Maelstrom | approx | E | **Maelstrom**: a whirlpool that pulls enemies in | pulls loose parts too | | todo |
| tiamat | Flood | approx | E | **Flood**: fills the room's low ground with water for a while | it slows you too unless you swim | | todo |
| alkahest | Dissolve | approx | E | **Dissolve**: eat through a weak gate, grate or armour plate | corrodes your own held parts | | todo |
| pestilence | Contagion | full | audit | **Contagion**: poison jumps between enemies standing close | slow to build | | todo |
| slime_mold | Network | approx | E | **Network**: a growth spreads along the floor, slows enemies on it and shows the shortest route to a mark (a map aid) | creeps slowly | | todo |
| talos | Guardian | approx | F | **Guardian**: a patrol aura; if the visible nail is hit it drains you | the nail is a weak point | | todo |
| cube | Engulf | approx | F | **Engulf**: swallow a small enemy and hold it inside, digesting | big; a low jump | | todo |
| cloud_rider | Ride | approx | E | **Ride**: a short glide on a cloud | the cloud is brief | | todo |
| ariadne | Recall | approx | E | **Recall**: lay a trail, then return along it to its start | the trail must be laid first | | todo |
| selkie | Shed | approx | A | **Shed**: leave a husk decoy and slip away | the husk is gone until you rest | tests/test_pack_a_forms.gd + test_verb_mind.gd | done |
| king_slime | Court | approx | C | **Court**: spawns a few lesser slimes that fight for you | the court dies in one hit | tests/test_pack_c_forms.gd + test_verb_allies/companions/stones + test_pack_c_mechanics | done |
| beanstalk | Stalk | approx | E | **Stalk**: grow a climbable vine from the floor | one at a time, slow to grow | | todo |
| philosophers_stone | Transmute | approx | E | **Transmute**: convert held essence of one element into another at a loss; digest parts faster | the conversion loss | | todo |
| mimic | Copy | needs | F | **Copy**: take the shape and one move of the last creature you inspected, for a short time | the copy fades | | todo |
| wolf_moonbound | Rise | approx | B | **Rise**: stand on two legs for claws and items, drop to four to gallop | rising costs a beat; no pounce while up | tests/test_pack_b_forms.gd + test_rage.gd + test_pack_b_mechanics.gd | done |
| wolf_loup_garou | Frenzy | approx | B | **Frenzy**: each kill stokes a bloodlust meter (faster, bleeding bites); at full you cannot stop | no guard, no items while frenzied | tests/test_pack_b_forms.gd + test_rage.gd + test_pack_b_mechanics.gd | done |
| wolf_beast_of_gevaudan | Stalk-kill | approx | A | **Stalk-kill**: a stealth opener that deals huge damage to the first target, shrugs off ranged hits | helpless against crowds | tests/test_pack_a_forms.gd + test_verb_mind.gd | done |
| wolf_lycaon | First Wolf's roar | approx | C | **First Wolf's roar**: wild wolves in the room join you briefly | weak alone | tests/test_pack_c_forms.gd + test_verb_allies/companions/stones + test_pack_c_mechanics | done |
| wolf_ulfhedinn | Skin | approx | B | **Skin**: you choose the change; a berserk window with no flinch and iron-proof | a crash after the window | tests/test_pack_b_forms.gd + test_rage.gd + test_pack_b_mechanics.gd | done |
| wolf_wolfskin_champion | Shield-bite | approx | B | **Shield-bite**: breaks guards; the berserk window refills on kills | still crashes if it ends dry | tests/test_pack_b_forms.gd + test_rage.gd + test_pack_b_mechanics.gd | done |
| wolf_skoll | Chaser | approx | A | **Chaser**: gallop never slows; mark a fleeing enemy and the pounce is free when you catch it | no stand-and-fight tools | tests/test_pack_a_forms.gd + test_verb_mind.gd | done |
| wolf_black_dog | Slink | approx | A | **Slink**: a silent gait in dark rooms; unseen until the pounce | weak in lit rooms | tests/test_pack_a_forms.gd + test_verb_mind.gd | done |
| wolf_barghest | Fear howl | approx | A | **Fear howl**: enemies falter and flee | cannot pounce while howling | tests/test_pack_a_forms.gd + test_verb_mind.gd | done |
| wolf_hellhound | Burning pounce | approx | E | **Burning pounce** and a flame trail; a gate-guard verb | fire hurts your own packmate | | todo |
| wolf_black_shuck | Omen | approx | A | **Omen**: mark one enemy; it dies in ten seconds unless it cleanses | one mark at a time | tests/test_pack_a_forms.gd + test_verb_mind.gd | done |
| wolf_cwn_annwn | Spectral pack | approx | C | **Spectral pack**: two echoes of you pounce with you | the echoes fade after eight seconds | tests/test_pack_c_forms.gd + test_verb_allies/companions/stones + test_pack_c_mechanics | done |
| wolf_gabriel_hound | Hunt's passage | approx | E | **Hunt's passage**: the pack carries you over one gap (a short glide) | glide only after a kill | | todo |
| wolf_cu_sith | Three barks | approx | D | **Three barks**: two warnings, then a lunge you cannot dodge from range | stand still to bark | tests/test_pack_d_forms.gd + test_pack_d_mechanics.gd | done |
| wolf_warg | Bond | approx | C | **Bond**: a heavier pounce, knockback, one bonded packmate | slow gallop | tests/test_pack_c_forms.gd + test_verb_allies/companions/stones + test_pack_c_mechanics | done |
| wolf_dire_wolf | Tank | approx | B | **Tank**: the pounce knocks down heavy targets; knockback-proof | slow | tests/test_pack_b_forms.gd + test_rage.gd + test_pack_b_mechanics.gd | done |
| wolf_fenrir | Unbound | approx | E | **Unbound**: breaks barriers and grates (a gate-breaking verb) | too big for small gaps | | todo |
| wolf_amarok | Lone hunter | approx | B | **Lone hunter**: strongest with no packmate, hunts isolated prey | the bond is disabled | tests/test_pack_b_forms.gd + test_rage.gd + test_pack_b_mechanics.gd | done |
| wolf_church_grim | Guardian | approx | C | **Guardian**: wards a packmate, holds holy ground, unharmed in holy zones | tethered to a sacred spot | tests/test_pack_c_forms.gd + test_verb_allies/companions/stones + test_pack_c_mechanics | done |
| wolf_wepwawet | Opener | needs | E | **Opener**: reveals hidden exits and shortcuts in a room | low damage | | todo |
| wolf_lupa | Suckle | approx | C | **Suckle**: heals packmates and grows a pup into a second packmate | weak pounce | tests/test_pack_c_forms.gd + test_verb_allies/companions/stones + test_pack_c_mechanics | done |
| undead_zombie | Devour | approx | B | Devour corpses to heal; slow, heavy swings. |  | tests/test_pack_b_forms.gd + test_rage.gd + test_pack_b_mechanics.gd | done |
| undead_ghoul | Rend | approx | B | Claws, a paralysing touch, a stench cloud. |  | tests/test_pack_b_forms.gd + test_rage.gd + test_pack_b_mechanics.gd | done |
| undead_vampire | Drain | approx | B | Uses items; devours blood. |  | tests/test_pack_b_forms.gd + test_rage.gd + test_pack_b_mechanics.gd | done |
| undead_jiangshi | Hop | approx | B | **Hop**: bounding straight-line leaps that drain on touch | cannot turn mid-hop; talisman rooms stop it | tests/test_pack_b_forms.gd + test_rage.gd + test_pack_b_mechanics.gd | done |
| undead_draugr | Heft | approx | B | **Heft**: huge barrow-blade swings; it swells as it kills | no jump; slowest of all | tests/test_pack_b_forms.gd + test_rage.gd + test_pack_b_mechanics.gd | done |
| undead_barrow_king | Barrow slam | approx | B | **Barrow slam**: a ground-pound shockwave; armour while carrying items | stuck to the room's hoard | tests/test_pack_b_forms.gd + test_rage.gd + test_pack_b_mechanics.gd | done |
| undead_abomination | Cleaver | approx | B | **Heft** cleaver; extra graft slots (a stitched body) | stench; slow | tests/test_pack_b_forms.gd + test_rage.gd + test_pack_b_mechanics.gd | done |
| undead_bone_warrior | Overhead cleave | approx | B | **Heft**: a slow overhead cleave and a shield | slow | tests/test_pack_b_forms.gd + test_rage.gd + test_pack_b_mechanics.gd | done |
| undead_revenant_knight | Vengeance | approx | B | **Vengeance**: hits harder against the creature that killed your last life; heavy swings | slow turning; no ranged | tests/test_pack_b_forms.gd + test_rage.gd + test_pack_b_mechanics.gd | done |
| undead_dullahan | Herald | approx | D | **Herald**: a long whip, a thrown head | no shield | tests/test_pack_d_forms.gd + test_pack_d_mechanics.gd | done |
| undead_bone_colossus | Juggernaut | approx | B | **Juggernaut**: double size, stomp and heft cleave; walks through hazards | too big for narrow gaps | tests/test_pack_b_forms.gd + test_rage.gd + test_pack_b_mechanics.gd | done |
| undead_spartoi_hoplite | Sow | approx | C | **Shield wall**: block and spear thrust; sow two bone soldiers | rooted while sowing | tests/test_pack_c_forms.gd + test_verb_allies/companions/stones + test_pack_c_mechanics | done |
| undead_sower_of_teeth | Squad | approx | C | a squad of four sown soldiers | weak alone | tests/test_pack_c_forms.gd + test_verb_allies/companions/stones + test_pack_c_mechanics | done |
| undead_master_of_the_dance | Rise | approx | C | **Rise**: downed enemies stand up as dancers for ten seconds | only works near bodies | tests/test_pack_c_forms.gd + test_verb_allies/companions/stones + test_pack_c_mechanics | done |
| undead_skeletal_archer | Bone throw | approx | D | Returning bone throws, bow arm. |  | tests/test_pack_d_forms.gd + test_pack_d_mechanics.gd | done |
| undead_deadeye | Sure shot | approx | D | six sure shots, then a cursed seventh | the seventh costs HP | tests/test_pack_d_forms.gd + test_pack_d_mechanics.gd | done |
| undead_arash | Life-arrow | approx | D | **Life-arrow**: spend most of your HP on one arrow that crosses the room and pierces | leaves you at 1 HP | tests/test_pack_d_forms.gd + test_pack_d_mechanics.gd | done |
| undead_wild_huntsman | Mark | approx | D | **Mark**: arrows home on one marked prey | one mark at a time | tests/test_pack_d_forms.gd + test_pack_d_mechanics.gd | done |
| undead_corpse_candle | Lure-light | approx | A | **Lure-light**: enemies follow a drifting light into hazards | the light shows where you are | tests/test_pack_a_forms.gd + test_verb_mind.gd | done |
| undead_stingy_jack | Trick | approx | A | **Trick**: an enemy that touches your lure is held fast | needs the lure placed first | tests/test_pack_a_forms.gd + test_verb_mind.gd | done |
| undead_banshee | Wail | full | A | **Wail**: a cone that stuns and frightens | wakes sleeping enemies | tests/test_pack_a_forms.gd + test_verb_mind.gd | done |
| undead_adept | Minions | approx | C | a few bone minions; a focus | frail | tests/test_pack_c_forms.gd + test_verb_allies/companions/stones + test_pack_c_mechanics | done |
| undead_lich | Bone beams | approx | F | Bouncing bone beams, a blink; a phylactery anchors remains. |  | tests/test_pack_c_forms.gd + test_verb_allies/companions/stones + test_pack_c_mechanics | done |
| undead_deathless | Hidden soul | approx | F | **Hidden soul**: place an anchor; if you die in range you rise there once per life | the anchor can be destroyed | tests/test_pack_c_forms.gd + test_verb_allies/companions/stones + test_pack_c_mechanics | done |
| undead_demilich | Float | approx | E | a floating skull, very frail, very strong | the frailest form | tests/test_pack_b_forms.gd + test_rage.gd + test_pack_b_mechanics.gd | done |
| undead_hierophant | Consecrate | approx | C | A ring of light that heals you and your summons and burns the living. |  | tests/test_pack_c_forms.gd + test_verb_allies/companions/stones + test_pack_c_mechanics | done |
| undead_mummy_priest | Wrap | full | audit | **Wrap**: bandages bind enemies; a sand gust | fire hurts | | todo |
| undead_pharaoh | Decree | approx | C | **Decree**: a curse ring marks everything in the room; tomb guards rise | slow | tests/test_pack_c_forms.gd + test_verb_allies/companions/stones + test_pack_c_mechanics | done |
| undead_heart_weigher | Weigh | approx | B | **Weigh**: if a creature's essence is lower than yours, drain it at once | useless against stronger foes | tests/test_pack_b_forms.gd + test_rage.gd + test_pack_b_mechanics.gd | done |
| spider_weavermaid | Hands | approx | B | **Hands**: a person's torso on a spider body; uses items, tools and bows | a slower wall crawl | tests/test_pack_b_forms.gd + test_pack_b3.gd | done |
| spider_jorogumo | Veil | approx | A | **Veil**: pass as a goblin or villager (village standing reads you as welcome); revealing it bursts the veil | the veil drops when hit; no webbing while veiled | tests/test_pack_a_forms.gd + test_verb_mind.gd | done |
| spider_seven_spider_spirits | Sisters | approx | C | **Sisters**: split into seven decoys that web | each decoy dies in one hit | tests/test_pack_c_forms.gd + test_verb_allies/companions/stones + test_pack_c_mechanics | done |
| spider_tsuchigumo | True form | approx | B | **True form**: drop the veil into a giant; burrow a lair; call lesser spiders | too big for small gaps | tests/test_pack_b_forms.gd + test_pack_b3.gd | done |
| spider_loom_weaver | Tapestry | approx | E | **Tapestry**: weave a patterned web that stays as a trap and a snare | slow to weave | | todo |
| spider_norn | Fate thread | approx | A | **Fate thread**: tie a thread to an enemy; the next hit it lands on you is sent back | fragile | tests/test_pack_a_forms.gd + test_verb_mind.gd | done |
| spider_anansi | Steal | needs | F | **Steal**: take a power or essence from a living enemy without killing it (the decided future method) | weak direct damage | | todo |
| spider_broodmother | Brood | approx | C | **Brood**: cocoons hatch spiderlings that carry and harass | slow; fewer solo kills | tests/test_pack_c_forms.gd + test_verb_allies/companions/stones + test_pack_c_mechanics | done |
| spider_brood_queen | Command | approx | C | **Command**: spiderlings follow your lead | fewer solo kills | tests/test_pack_c_forms.gd + test_verb_allies/companions/stones + test_pack_c_mechanics | done |
| spider_cocoon_mother | Hatch | approx | C | prey cocooned alive hatch into stronger young | takes time | tests/test_pack_c_forms.gd + test_verb_allies/companions/stones + test_pack_c_mechanics | done |
| spider_swarm_sovereign | Disperse | approx | A | **Disperse**: the body breaks into a swarm that squeezes through grates and reforms (a traversal gate) | cannot fight while dispersed | tests/test_pack_a_forms.gd + test_verb_mind.gd | done |
| spider_cave_matriarch | Heavy bite | approx | B | a huge lone hunter: heavy bite, a web wall | slow; no small gaps | tests/test_pack_b_forms.gd + test_pack_b3.gd | done |
| spider_light_eater | Drink | approx | E | **Drink**: eat lamps and glow pools to darken a room and heal | hurt by sacred light | | todo |
| spider_chasm_weaver | Span | approx | E | **Span**: spin a permanent web bridge across a gap (a traversal gate) | slow; both ends need anchors | | todo |
| spider_stalker | Ambush | approx | B | **Ambush**: a ceiling drop and a web zip | weak in lit rooms | tests/test_pack_b_forms.gd + test_rage.gd + test_pack_b_mechanics.gd | done |
| spider_shadow_stalker | Silent drop | approx | B | **Silent drop**: a bonus strike in dim light | weak in lit rooms | tests/test_pack_b_forms.gd + test_rage.gd + test_pack_b_mechanics.gd | done |
| spider_nightstalker | Reset | approx | A | kills reset the zip; unseen in shadow | needs shadow | tests/test_pack_b_forms.gd + test_rage.gd + test_pack_b_mechanics.gd | done |
| spider_veil_spinner | Veil | approx | A | **Veil**: spin a web over a doorway that hides you and allies | the veil breaks on any attack | tests/test_pack_a_forms.gd + test_verb_mind.gd | done |
| spider_venomspinner | Venom web | approx | E | webs apply poison that spreads through trap webs | lower direct damage | | todo |
| spider_plaguemother | Miasma | approx | E | a poison cloud that spreads on death | slow | | todo |
| spider_tarantella | Dance-venom | approx | A | **Dance-venom**: a bitten enemy staggers erratically into hazards | slow to take hold | tests/test_pack_a_forms.gd + test_verb_mind.gd | done |
| goblin_beastcaller | Offer | approx | C | **Offer**: an item to a weakened creature, which follows you (decided taming) | weak alone | tests/test_pack_c_forms.gd + test_verb_allies/companions/stones + test_pack_c_mechanics | done |
| goblin_pied_piper | Tune | approx | C | **Tune**: a pipe call commands a small group and draws vermin | cannot throw while playing | tests/test_pack_c_forms.gd + test_verb_allies/companions/stones + test_pack_c_mechanics | done |
| goblin_rat_king | Knot | approx | C | **Knot**: a mobile swarm of tamed vermin acts as one big companion with area damage | stays one companion | tests/test_pack_c_forms.gd + test_verb_allies/companions/stones + test_pack_c_mechanics | done |
| goblin_orpheus | Lull | approx | A | **Lull**: calm a hostile creature so it stops attacking and can be tamed | fails on bosses | tests/test_pack_a_forms.gd + test_verb_mind.gd | done |
| goblin_beast_rider | Mount | approx | C | **Mount**: fuse with the companion for a ride (the guide's Rider) | the companion is exposed | tests/test_pack_c_forms.gd + test_verb_allies/companions/stones + test_pack_c_mechanics | done |
| goblin_wolf_lord | Spear charge | approx | C | a spear charge and gallop while mounted | on foot you are weak | tests/test_pack_c_forms.gd + test_verb_allies/companions/stones + test_pack_c_mechanics | done |
| goblin_lord_of_beasts | Two companions | approx | C | **Two companions** at once (a decided capstone exception to the one-at-a-time rule) | fragile companions | tests/test_pack_c_forms.gd + test_verb_allies/companions/stones + test_pack_c_mechanics | done |
| goblin_tinker | Rig | approx | E | crafted throwables, rigged traps, more recipe slots | weak in melee | | todo |
| goblin_knocker | Tap | needs | E | **Tap**: senses hidden walls, weak floors and traps in a room | low damage | | todo |
| goblin_gremlin | Sabotage | approx | A | **Sabotage**: disable an enemy device or turn a trap against its owner | backfires sometimes | tests/test_pack_a_forms.gd + test_verb_mind.gd | done |
| goblin_rumpelstiltskin | Spin | approx | E | **Spin**: transmute junk into a better part, two for one | wasteful | | todo |
| goblin_smith | Forge | approx | E | **Forge**: craft a named weapon from parts at a forge | needs a forge and time | | todo |
| goblin_mastersmith | Flawless gear | approx | B | a second gear slot; flawless upgrades | high cost | tests/test_pack_b_forms.gd + test_rage.gd + test_pack_b_mechanics.gd | done |
| goblin_ring_maker | Cursed gear | approx | B | **Cursed gear**: huge stats with a real cost | the curse | tests/test_pack_b_forms.gd + test_rage.gd + test_pack_b_mechanics.gd | done |
| goblin_skulker | Sneak strike | approx | A | sneak strike, smoke bomb | weak in melee | tests/test_pack_a_forms.gd + test_verb_mind.gd | done |
| goblin_redcap | Dye | approx | B | **Dye**: each kill refreshes a blood-cap timer for speed and damage; if it dries you lose it | idle play wastes it; holy words repel | tests/test_pack_b_forms.gd + test_rage.gd + test_pack_b_mechanics.gd | done |
| goblin_ironboot | Stomp | approx | B | **Stomp**: a heavy kick with heft | slow to sneak | tests/test_pack_b_forms.gd + test_rage.gd + test_pack_b_mechanics.gd | done |
| goblin_bloodcap | Cap-throw | approx | D | **Cap-throw**: a boomerang cap that returns, dyed | needs blood to dye it | tests/test_pack_d_forms.gd + test_pack_d_mechanics.gd | done |
| goblin_puck | Mislead | approx | A | **Mislead**: illusions and decoys; reverse an enemy's facing | low damage | tests/test_pack_a_forms.gd + test_verb_mind.gd | done |
| goblin_changeling | Swap | approx | A | **Swap**: trade places with a decoy; look like a creature to scout | the swap takes a beat | tests/test_pack_a_forms.gd + test_verb_mind.gd | done |
| goblin_leprechaun | Pocket | approx | A | **Pocket**: pickpocket items from a living creature without killing it; a short teleport | low damage | tests/test_pack_a_forms.gd + test_verb_mind.gd | done |
| goblin_hob | Ward | approx | C | **Offer** and **Ward**: protects an area | passive, weak damage | tests/test_pack_c_forms.gd + test_verb_allies/companions/stones + test_pack_c_mechanics | done |
| goblin_tomte | Hearth | approx | C | **Hearth**: plant a ward-stone; creatures near it are slowed and you heal | static | tests/test_pack_c_forms.gd + test_verb_allies/companions/stones + test_pack_c_mechanics | done |
| goblin_hearth_god | Lar | approx | C | **Lar**: ward-stones link into one wider aura | immobile when it counts | tests/test_pack_c_forms.gd + test_verb_allies/companions/stones + test_pack_c_mechanics | done |
| goblin_boggart | Fear aura | approx | A | **Curse-stone** and a fear aura (a corrupted Tomte) | allies fear you too | tests/test_pack_c_forms.gd + test_verb_allies/companions/stones + test_pack_c_mechanics | done |
| goblin_paladin | Blessed throw | approx | D | blessed throwables and a shield | slow | tests/test_pack_d_forms.gd + test_pack_d_mechanics.gd | done |
| goblin_horn_bearer | Horn | approx | B | **Horn**: a blast that stuns and rallies allies | loud | tests/test_pack_c_forms.gd + test_verb_allies/companions/stones + test_pack_c_mechanics | done |
| goblin_giant_killer | Giant-slayer | approx | B | damage scales with the target's size | weak against small foes | tests/test_pack_b_forms.gd + test_rage.gd + test_pack_b_mechanics.gd | done |

## Monster kits (section 10.3)

| Creature | Agreed kit | Test | Status |
|---|---|---|---|
| imp | holds position, curses | | todo |
| demon_hound | a dasher with a wind-up | | todo |
| caller | emits imps while its glyph is lit | | todo |
| blinker | a short teleport with a fake-out | | todo |
| ward_bearer | nullifies hits from one side | | todo |
| rider | possesses a dormant corpse | | todo |
| chapel_priest | spits holy light, carries the emitter, drops a focus | | todo |
| shield_guard | an armoured charger; drops a weapon arm | | todo |
| gargoyle | a ceiling dropper; earth | | todo |
| ghost | a drifter; mind, and a drain target for undead | | todo |
| goblin_shaman | a source of its essences; no special kit agreed | | todo |
| candle_wisp | a source of its essences; no special kit agreed | | todo |
| stained_glass_moth | a source of its essences; no special kit agreed | | todo |
| carrion_crow | a source of its essences; no special kit agreed | | todo |
| vampire_bat | a source of its essences; no special kit agreed | | todo |
| bone_hound | a source of its essences; no special kit agreed | | todo |
| ember_beetle | a source of its essences; no special kit agreed | | todo |
| lava_salamander | a source of its essences; no special kit agreed | | todo |
| ash_moth | a source of its essences; no special kit agreed | | todo |
| moon_hare | a source of its essences; no special kit agreed | | todo |
| tusker_boar | a source of its essences; no special kit agreed | | todo |
| blood_leech | a source of its essences; no special kit agreed | | todo |
| bog_wisp | a source of its essences; no special kit agreed | | todo |
| firefly_swarm | a source of its essences; no special kit agreed | | todo |
| cave_rat | a source of its essences; no special kit agreed | | todo |
| junk | a source of its essences; no special kit agreed | | todo |
| wild_slime | a source of its essences; no special kit agreed | | todo |
| skeleton | a source of its essences; no special kit agreed | | todo |
| village_goblin | a source of its essences; no special kit agreed | | todo |
