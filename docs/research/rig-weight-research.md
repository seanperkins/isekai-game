# Rigs and animation that have weight

2026-10-06. Why the goblin, spider and wolf animations look cartoony, what professionals do about it, what tools exist, and the plan that follows. Facts are from the sources linked; anything that is my own reading is marked.

## What "weight" is

Weight is not a number in a rig. It is what the viewer infers from four things: **where the centre of mass goes** (the pelvis, in a person), **when the body meets the ground** (contact, absorbing it, pushing off), **timing and spacing** (heavy things move slowly and settle hard, light things float; [Sprite AI](https://www.sprite-ai.art/guides/animation-principles)), and **overlap** (the parts of a body do not move in step; they follow through and settle). A rig only has to make those four easy to express.

## What the sources say

**A person walking** ([Spotlight FX](https://spotlightfx.com/blog/walk-cycle-animation-beginners-guide-to-creating-realistic-movement), [Rusty Animator](https://rustyanimator.com/walk-cycle-animation/), [Sessions](https://documents.sessions.edu/eforms/courseware/coursedocuments/character_animation_i/lesson2.html), [gait references](https://www.physio-pedia.com/The_Gait_Cycle)):
- the poses are contact, down, passing, up, then contact on the other side; the centre of gravity is at the pelvis, so the hips are the main control;
- at **down** the weight is on the front foot, the hips are at their lowest and the knee of that leg bends to absorb the landing; at **passing** the swinging leg goes by the planted one; the rear leg's last push lifts the body up and over;
- stance is about 60% of the cycle and swing 40%; both feet are down for 25 to 30% of it;
- the knee flexes to about 60 degrees in swing; the pelvis rises and falls like a sine with an amplitude of about 4 to 5 cm at normal speed (about 2.5% of height);
- arms, head and torso overlap: they follow the hips and settle, they do not move in sync.

**A four-legged animal** ([Animator Notebook](https://www.animatornotebook.com/learn/quadrupeds-gaits), [Game Developer](https://www.gamedeveloper.com/art/animating-four-legged-beasts), [AnimSchool](https://blog.animschool.edu/tag/quadruped-walk-cycle/)):
- a **walk** is four beats (back-left, front-left, back-right, front-right) with two or three feet always down; a **trot** is two beats, diagonal pairs together, with a slight bounce between them; the diagonal pairs I animated and called a walk is a trot;
- the front legs carry more weight and take shorter strides, the hind legs drive;
- hips and chest are two offset "bouncing balls"; the head and tail are more bouncing balls offset from those, animated last, one axis at a time; carnivores have a flexible trunk that compresses as the front legs lift and extends before they land;
- heavy animals barely bend their legs and swing them like pendulums; light ones keep them bent.

**A spider** ([alternating tetrapod gait](https://github.com/dean451/DeanHack/pull/287), [Spider Walker](https://github.com/iltaen/spider_walker)): legs R1 R3 L2 L4 step together, then the other four; four feet are always down; a leg lifts only while swinging forward; the body dips slightly at each footfall.

**Small pixel sprites** ([Sprite AI](https://www.sprite-ai.art/guides/animation-principles), [pixel-art timing guide](https://www.sprite-ai.art/guides/how-to-animate-pixel-art)):
- uneven timing is what separates amateur from professional: anticipation held 60 to 80 ms, the swing fast, the impact held 120 to 200 ms, recovery 80 to 100 ms (one source holds the impact frame longer, another makes it the shortest; both agree the swing frames are fast and there is a held beat at the hit);
- anticipation is non-negotiable: one frame of the opposite motion before any action; a heavy attack uses 5 to 8 frames, a light one 3 to 5;
- secondary motion is one or two frames at 32 px, a pixel at 16 px; squash and stretch is about two pixels at most; weapon paths are arcs, never straight lines.

## What professional rigs have

From [rigging guides](https://game-ace.com/blog/character-rigging-for-video-games/) and [Rigify's rig types](https://animalanimator.com/blender-rigify-for-rigging-animals-and-making-epic-animations/): a skeleton of root, pelvis, spine chain, neck and head; **IK on every limb that touches the ground so feet stay locked**, with a **foot roll** (heel, ball, toe) and a pole target for the knee; **FK for spines and arcs**; a **master COG control** for the pelvis; IK/FK switches; secondary chains for tails, ears and cloth. Rigify, which ships with your Blender (it is in `addons_core`), has meta-rigs for Basic Human, Human, Basic Quadruped, Cat, Wolf, Horse and Shark, with leg, paw (the hock quadrupeds need), front-paw (IK/FK, toe curl, heel placement) and stretchy-spine pieces. Game engines play baked FK; IK exists in the rig to make the animator's job physical.

## Tools worth knowing (none installed or run)

| Tool | What it adds | Licence / cost | Use here |
| --- | --- | --- | --- |
| [Rigify](https://docs.blender.org/manual/en/2.81/addons/rigging/rigify.html) | Whole control rigs from a meta-rig: IK legs, foot roll, spine, wolf and cat | bundled with Blender | the wolf and any hero creature |
| [Wiggle Bones](https://extensions.blender.org/add-ons/wiggle-bones/) | Bones as springy dynamic bodies (pinning, several solvers, mesh collisions), baked to keyframes with a preroll and a loop so a cycle stays seamless | GPL-3, free, Blender 4.5+, v1.1.2 (Sep 2026) | ears, cloaks, tails, the rat pack; also [EXea Jiggle](https://extensions.blender.org/add-ons/exea-jiggle/) |
| [Spider Walker](https://github.com/iltaen/spider_walker) | Procedural multi-leg gait with ground raycasts, bakes to keyframes | MIT, Blender 5.2+ | the spider |
| Cascadeur ([AutoPhysics](https://www.cgchannel.com/2022/12/nekki-releases-cascadeur-2022-3/), [pricing](https://tooliverse.ai/tools/cascadeur)) | Physics-assisted keyframing: "AutoPhysics" turns a keyed animation into a physically plausible one; exports FBX, DAE, glTF | free for non-commercial (.casc only), Indie $19/month per that review | a hero animation if a hand-keyed one needs weight; not the pipeline |
| [Retarget](https://extensions.blender.org/add-ons/retarget/) with Mixamo | Real captured human motion onto a rig | free | biped goblins; needs your Adobe download |

## Why ours looks cartoony (my diagnosis, from the code and the research)

1. **Sine waves on rigid joints.** Every cycle is `sin(phase)`: constant speed, no contact, no push-off. A real step accelerates and lands.
2. **No IK.** Feet are driven by thigh and shin angles, so they slide and skate. The ground lock lowers the whole body to the lowest foot, which is the opposite of a pelvis that bobs from the legs.
3. **No centre of mass.** There is no pelvis control; the body height falls out of the grounding.
4. **The wolf's "walk" is a trot**, a bouncy two-beat gait where a real walk is four-beat; **the spider's legs all swing by the same sine**.
5. **Everything moves in step.** Ears, cloaks, scarves, the rat pack, hats and tails are rigid parts bound to the head or spine; there is nothing to follow through.
6. **Every frame is the same length.** No held anticipation, no fast swing, no held impact, so an attack reads as a metronome.
7. **Frame counts are low** (6 to 8), so the in-betweens that carry weight (down, up) are missing.

## Plan

Phase 1, now, no new tools: a tested animation toolkit used by every creature, replacing the sines.
- **Gait**: stance 60% and swing 40% with a foot path (planted and moving back at constant speed in stance, an arc with a lift in swing), foot pitch for heel strike and toe-off, and a pelvis height that follows the sine of about 2.5% of body height with the lowest point at heel strike.
- **Leg IK**: a two-bone solver (knee forward for people, hock back for wolves) so the planted foot stays planted; the pelvis, not a ground lock, sets the height.
- **Wolf**: a four-beat walk in the order back-left, front-left, back-right, front-right; keep the trot for fast; hips and chest as offset bouncing balls; the head and tail as followers.
- **Spider**: alternating tetrapod, four feet always down, lift only in swing, the body dips at each footfall.
- **Overlap**: a spring that makes ears, cloaks, scarves, hats and the rat pack lag the bone that carries them (simulated over several cycles so the loop is seamless), which needs those parts bound to their own bones.
- **Timed actions**: attacks as eased keyframes with uneven timing: a held anticipation with a lean back and a crouch, a fast swing, a held impact, an overshoot, a slow recovery, 10 to 12 frames.
- **Idle**: breathing in the spine and shoulders, a slow weight shift between the feet, an ear flick.

Phase 2, if you want to animate by hand: a real control rig inside the `.blend`. Legs on Blender IK constraints with pole targets, foot controls with roll, a COG bone, a three-bone spine, controls an animator can grab, Rigify for the wolf, Wiggle Bones for baked secondary motion. The motion maths from Phase 1 would drive the controls, so the same cycles stay available as a starting point.

My recommendation is to do Phase 1 first and look at it before committing to Phase 2. It fixes what makes the motion cartoony and keeps everything testable and reproducible; Phase 2 buys editability in Blender, which is worth having only once you want to key by hand.
