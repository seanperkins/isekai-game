# How spiders actually move, and what it means for the spider's feel

Research for the spider's crawl model and animation (species movesets spec, build step 4). Written 2026-10-04 from the biomechanics literature. Where I read only an abstract or a search summary, the line says so; corner transitions come from cockroach studies, because I found no spider study of them.

## What real spiders do

**Gait and rhythm**
- Eight legs in an **alternating tetrapod**: R1 R3 L2 L4 step together, then L1 L3 R2 R4 ([Hololena, J. Arachnology](https://bioone.org/journals/the-journal-of-arachnology/volume-39/issue-1/B10-45.1/Gait-characteristics-of-two-fast-running-spider-species-span-classgenus/10.1636/B10-45.1.short), abstract). At least half the legs are always down, and a runner only leaves the ground entirely above about 54 body lengths per second.
- **Speed comes from how fast the legs cycle, not from longer steps.** In Cupiennius the distance a foot stays planted is nearly constant (about 30 mm front legs, 24 mm hind) at every speed; the swing gets longer and the stride rate climbs to roughly 6 to 8 per second at a fast run ([PLoS ONE](https://pmc.ncbi.nlm.nih.gov/articles/PMC3689776/)).
- **The body hardly moves.** Cupiennius's vertical bob is about 1.7 mm on a centre of mass 10 mm up, with pitch, yaw and roll of 5 to 7 degrees, and no bounce spring-mass style. It sprawls low and glides while the legs do the work (same paper).
- **Speed is modest in body lengths for ordinary running** (4 to 5 body lengths per second is a normal dart) and enormous only in sprints; the impression of speed is acceleration. Starts and stops are near instant ([Biology Insights summary](https://biologyinsights.com/how-fast-are-wolf-spiders-and-what-makes-them-quick/), secondary).
- **Stop and go.** Many spiders run 10 to 20 cm or less and then freeze, for camouflage, for sensing and to save energy (secondary summary; the pattern is standard).

**Turning**
- A jumping spider **pivots on the spot**: the legs on the turning side step backward and the others forward, one leg stepping per 9 degrees of turn. It changes turn speed by stepping faster, from 120 to 1200 degrees per second, so a half turn takes about 0.15 s at its fastest ([Land 1972, J. Exp. Biol.](https://journals.biologists.com/jeb/article/57/1/15/22001/Stepping-Movements-Made-by-Jumping-Spiders-During)). It does not arc.

**Walls, ceilings and corners**
- On a vertical surface a tarantula keeps **all its legs in contact at once**; the front legs grip mostly with claw tufts and the hind legs with the pad hairs (scopulae). Adhesion is directional, strong when a leg pushes and weak when it is pulled, and a leg's pad twitches just before the leg lifts ([PMC4736027](https://pmc.ncbi.nlm.nih.gov/articles/PMC4736027/)).
- Cockroach corner studies (proxy, not spiders): at an **inside corner** the animal rears the front of the body up and uses its middle legs to put the front feet on the new surface, then levels off; at an **outside corner** it bends the body to stay close to the surface and reaches round the edge with the front legs first ([JEB](https://journals.biologists.com/jeb/article/225/10/jeb243605/275496/Cockroaches-adjust-body-and-appendages-to-traverse), [Stanford ICRA 2008](http://bdml.stanford.edu/twiki/pub/RisePrivate/ReviewsForICRA08/ICRA08_1369_MS.pdf)). **The head leads and the body rotates progressively.**

**Jumping, silk and posture**
- A jumping spider jump is **hydraulic**: the legs snap straight in about 8 to 9 ms, taking off at 0.7 to 0.8 m/s and about 5 g, covering roughly 10 body lengths (search summaries of [Peckhamia](https://peckhamia.com/peckhamia/PECKHAMIA_167.1.pdf) and takeoff studies). The slow part is the ritual before it: face the target, raise the front legs, anchor a **dragline**, pause, launch. It never leaps without the safety line.
- Spiders **rappel head first**, controlling the thread with a claw on a hind leg, and silk resists twisting so the descent does not spin ([phys.org](https://phys.org/news/2017-07-strange-silk-rappelling-spiders-dont.html)).
- Resting posture is sprawled, legs bent hip low, knee high, foot low, so the knees stand above the body in side view ([bioRxiv, black widow](https://www.biorxiv.org/content/10.1101/484238v1.full)).

## What it means for the game

1. **The spider is the opposite of the slime.** The slime bounces, stretches and squashes. The spider glides on a rigid body with a blur of legs. No squash and stretch, no body bob beyond a pixel, no bounce on landing: a landing is a short leg flex.
2. **Step phase follows distance, not time.** Advance the leg cycle by the distance travelled (as `SpeciesLook.crawl_advance` already does for the slime's wobble), so feet never slide and legs freeze the instant it stops. Stride rate rises with speed: the existing `crawl` clip is 4 frames at 8 fps, about 2 strides per second at full speed against a real 6 to 8, so full speed should run it at 12 to 16 fps, scaled by speed.
3. **Instant start and stop is right.** The spec's 0.03 s start and 0.02 s stop match a creature that goes from still to full speed with no ramp. Feel comes from the hold: when it stops it **freezes**, with a tiny leg twitch and the front legs lifting every few seconds (the `hang` clip), not a decelerating skid.
4. **Turn on the spot.** Reversing is instant in movement; show it as a quick pivot (about 0.08 to 0.12 s: the sprite squeezes narrow and back, legs stepping), never an arc and never a skid.
5. **Corners are head-led and eased, not snapped.** Collision can change surface in one tick, but the sprite rotates to the new surface over about 0.12 s about its front end (reach, then body), with speed dipping to about 0.7 during the turn so the corner reads as effort. A rotated side-view sprite is correct on walls and ceilings (feet toward the surface); no new frames are needed for that.
6. **Speed stays 140 everywhere.** Real spiders slow a little on verticals, but the design wants a tight, predictable crawl; make the wall and ceiling feel different with posture (body hugging the surface, legs splayed) rather than speed.
7. **Jump with no anticipation delay.** The real takeoff is an 8 ms snap with the crouch long before, so launch on the press tick (no wind-up frames that add latency) and let the legs extend on the first frame. The wind-up tell belongs to the web zip's aim, not the hop: front legs raised for 0.08 to 0.12 s before the thread fires.
8. **Show the dragline.** A thread trailing from the take-off point or last anchor sells the spider, ties the hop to the zip and the silk drop, and costs a line draw. Silk drop: head down, hind leg working the thread; reeling up is slower than down, as in the spec (60 against 90).

## Art the clips can and cannot carry today

Spider sheet: `hang` (2 frames), `crawl` (4), `drop` (1), side view, abdomen left, head right, legs tucked short; the abdomen is a big dark round with red marks. Procedural rotation, the pivot squeeze, stride-rate scaling and the dragline need no new art. The art list (species spec) already names wall and ceiling crawl, zip, idle, rise and fall; this adds a **turn frame** and a **corner reach** frame (front legs forward and up), and a **head-down** silk pose.

## What the crawl spike should settle

- Does a head-led eased rotation over about 0.12 s stay in step with a body that changes surface in one tick, with no wobble when the stick is held on a corner or reversed mid-turn?
- Which input rule keeps one held direction going round a block, and when does a latch break?
- What happens at the end of a one-way ledge, which has no side or underside to wrap onto?
