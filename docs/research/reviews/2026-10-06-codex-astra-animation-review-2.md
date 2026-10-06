**1. VERDICT: No.**

Do not use this as the production pattern for another 120 forms.

1. **Animation and gameplay disagree.** The ability fires before visual impact; movement resumes while the recovery pose remains locked; the death animation is never selected.
2. **Contact is not physically reliable.** The foot-roll tests conceal actual sole sliding, the run exceeds leg reach, and attacks slide the stepping foot home.
3. **The visual template is still wrong.** These read as tall, thin humanoids wearing different accessories. The reference has compressed bodies, stronger shoulder masses, bent limbs, and clearly separated weapons.

Read-only review of `f28eb957`. Tests run: **28/28 goblin-motion tests and 31/31 animation-math tests passed.** No files edited. No new Blender render or Godot run.

**2. ANIMATION DEFECTS**

The strips establish poses and silhouettes; they cannot independently prove velocity or sliding. Those findings below also use the code. **The tuning values are specific first-pass proposals, not rendered or verified fixes.** `L` means thigh-plus-shin length.

Pose-table references below are in [goblin_motion.py](/Users/sean/sites/isekai-game/.worktrees/blender-spike/tools/art/blender/goblin_motion.py:49).

| Clip | What reads wrong | Specific proposed correction |
|---|---|---|
| **Idle** | Upright, narrow silhouette; almost identical frames. The forearms held forward suggest a cautious human rather than a compressed goblin. | Lines 49–51: `CROUCH .82→.74`, `STANCE_HALF .31→.36`, `LEAN 28→36`, `HEAD_LEAN 12→20`. Line 175: breathing displacement `.012L→.020L`. Preserve planted feet; solve reach before accepting the wider stance. |
| **Walk** | Legs do most of the work while the upper body remains posed. Redcap’s weapon arm barely participates. The passing poses look lifted rather than loaded. | Line 54: `crouch .82→.76`, `lift .19→.14`, `bob .045→.035`, `lean 30→34`. Line 24: `guard_n` swing multiplier `.15→.40`, giving **7.2° rather than 2.7°** walk swing. Correct sole contact first. |
| **Run** | Long split poses alternate with tightly folded legs. It reads as bounding on thin legs; Redcap’s torso and weapon are too quiet relative to that stride. | Line 55: `lift .34→.27`, `bob -.085→-.060`; the same `guard_n .40` gives **16° rather than 6°** arm swing. Start by limiting stride to **1.15L**, then derive cadence from speed instead of imposing the current minimum cycle. |
| **Attack/chop** | Anticipation exists. The failure is the blow: the small brown axe reads like a stick, and the end position reads as presenting it forward. Recovery reverses the stepping foot along the ground. | Line 245: `item=(-62,10,58,40)→(-70,25,105,120)`; `fore_n=(235,140,58,34)→(235,140,70,45)`. Add return-foot lift keys `(0.55,0),(.63,.08),(.72,0)` in fractions of `L`. Render the terminal rest pose. |
| **Hurt** | Mostly straightening up and tipping the head. The body does not visibly absorb much of the hit; the final picture remains short of the recovery endpoint. | Lines 307–310, at `.11s`: chest lean `6→-6°`, head `-16→-26°`, pelvis X `-.09→-.13L`, Z `-.05→-.08L`. Split the final hold into `(.26,.06)` and **`(.32,.04)`**, so the keyed rest pose is actually rendered. |
| **Die** | The hands rise, the body folds, then becomes an elongated plank. There is no convincing hand/knee contact or compression at impact. | Lines 352–357: starting terminal targets: near thigh/shin **`-35/-130°`**, far **`-55/-115°`**, replacing nearly parallel trailing legs. Add hand contact at `.32s` and chest contact at `.44s`; derive root height from those contacts. Angles alone cannot fix this clip. |
| **Stab** | Reads as an overhead chop with a smaller prop. The cloak is more legible than the dagger; the windup sends the blade far above the attack area. | Line 248, for a forward stab: upper-arm tuple **`(20,65,85,70)`**, forearm **`(100,95,90,75)`**, item **`(-20,-65,-90,-75)`**. The dagger points downward at rest, so approximately `-90°` item tilt points it forward. Retain the existing `.22L` step initially. |
| **Cast** | Reads as raising and lowering a lantern. The free hand drops during release; there is no visible release event. | Line 254: `step .06→0`—currently it slides despite the “feet staying put” comment. Set far upper arm **`(120,80,95,85)`**, far forearm **`(150,100,100,90)`**. Keep the lantern upright with item tuple **`(0,0,0,0)`**. Add a release effect at impact; start with a **3-pixel core lasting 40 ms**. |
| **Swipe** | Small backward preparation followed by an upward reach. It lacks an unmistakable forward strike and arrested follow-through. | Line 257: upper-arm tuple **`(-65,35,85,110)`**, forearm **`(-25,65,95,105)`**. Keep the impact hand near shoulder height and make its silhouette clear of the face. Render the strike rather than relying on interpolation between sparse pictures. |

The largest reference gap is **mass distribution**, not simply needing more lean. Current limbs and torso are so narrow that the outline consumes much of their readable width.

For a shape pass, start with:

- Upper torso X radius `.104→.130` and upper-arm radii `.044/.034→.052/.040`: [goblin_kit.py:134](/Users/sean/sites/isekai-game/.worktrees/blender-spike/tools/art/blender/goblin_kit.py:134), `:175`.
- Shorten the nose tip X `.40→.32`: `goblin_kit.py:164`. The present profile reads beaky.
- Make Redcap’s axe an actual blade silhouette; its current head is an ellipsoid with radii `.08,.02,.11`. Start at **`.13,.025,.16`**, with a wedge mesh and steel colour: [goblin_gear.py:239](/Users/sean/sites/isekai-game/.worktrees/blender-spike/tools/art/blender/goblin_gear.py:239).

The reference separates small goblin, heavy hobgoblin, hunter and shaman through body shape and equipment placement. The tree largely repeats one narrow body. Its motion language similarly needs distinct weight and attack paths, not only accessory changes.

**3. CODE/MATH BUGS**

1. **Ability activation precedes the visible hit by 80 ms.**  
   [enemy.gd:768](/Users/sean/sites/isekai-game/.worktrees/blender-spike/scripts/enemies/enemy.gd:768) activates immediately when entering recover. Recover starts at `attack_3`; after export, frames 3 and 4 each last **40 ms**, so impact frame 5 appears **80 ms later**. Windup’s `.24s` clip also holds until the `.35s` verb transition. Use one attack timeline with an explicit impact event; retime the visible hit to the intended `.35s` gameplay event.

2. **The recovery lock freezes animation selection, not movement.**  
   [enemy.gd:659](/Users/sean/sites/isekai-game/.worktrees/blender-spike/scripts/enemies/enemy.gd:659) retains the recovery picture while `:779` releases the AI after `.30s`. Current source exports **`.48s`** recovery; installed Redcap has **`.52s`**. At its nominal **54 px/s**, that permits approximately **9.72/11.88 world pixels** of movement under the recovery animation, before tick effects. End movement restriction and visual recovery together, or author a locomoting recovery.

3. **Export changes timing, and installed assets are stale relative to source.**  
   [clips.py:27](/Users/sean/sites/isekai-game/.worktrees/blender-spike/tools/art/blender/clips.py:27) rounds each duration independently: idle **1.20→1.28s**, hurt **.36→.38s**. Current attack totals `.72s`; installed Redcap totals `.76s`. Quantize cumulative boundaries, or retain native durations. Export source/version fingerprints so stale art is detectable.

4. **The foot-roll “contact point” is not a stationary material point.**  
   [anim.py:101](/Users/sean/sites/isekai-game/.worktrees/blender-spike/tools/art/blender/anim.py:101) blends heel→midpoint→toe, then `foot_pose` places that changing point on the prescribed ground trajectory. With Redcap’s boot dimensions, the physical heel slides **3.47 sprite pixels** during flattening, even after compensating for intended body travel. Use a fixed heel pivot during landing, a fixed flat-foot transform, then a fixed toe pivot during departure.

5. **Continuous position still contains discontinuous—and unbounded—velocity.**  
   [anim.py:142](/Users/sean/sites/isekai-game/.worktrees/blender-spike/tools/art/blender/anim.py:142) uses `sin(pi*s**.85)`. Its derivative diverges at `s=0`. The horizontal smoothstep also starts swing at zero velocity after a moving stance. Use endpoint-velocity-matched curves; merely changing `.85→1` removes the singularity but does not establish smooth support transfer.

6. **Run targets exceed reach; IK silently conceals it.**  
   [anim.py:73](/Users/sean/sites/isekai-game/.worktrees/blender-spike/tools/art/blender/anim.py:73) clamps unreachable targets without reporting residual error. Using current Redcap dimensions and saved `.60s` run timing, the target exceeds reach by **`.0751 units ≈1.71 sprite pixels`** near phase `.40`. [creatures/goblin.py:159](/Users/sean/sites/isekai-game/.worktrees/blender-spike/tools/art/blender/creatures/goblin.py:159) clamps cycle duration while continuing to increase stride. Solve feasible stride/pelvis/cadence together and assert endpoint error.

7. **Playback speed cannot maintain planted feet at actual movement speeds.**  
   [enemy.gd:656](/Users/sean/sites/isekai-game/.worktrees/blender-spike/scripts/enemies/enemy.gd:656) advances at an unchanged rate. Patrol moves at **0.5×**, slow changes speed, charges use **3×**, while run is authored for **1.9×**. Redcap’s patrol therefore already disagrees with its walk by approximately **27 world px/s**, before quantization. Scale gait phase by actual travelled distance and preserve phase across walk/run changes.

8. **Attack entry and exit violate stance/contact constraints.**  
   [goblin_motion.py:288](/Users/sean/sites/isekai-game/.worktrees/blender-spike/tools/art/blender/goblin_motion.py:288) ignores stance foot offsets. In the existing test fixture, Giant Killer’s near ankle jumps **`.20L`** at attack entry; Ironboot’s raised far foot drops approximately **`.322L`**. Line 235 then returns the forward foot `.20L` along the floor without lifting it. Also, the last attack picture samples `.60s`, not the `.72s` rest endpoint.

9. **Death is exported but unreachable through normal form playback.**  
   [enemy_state.gd:86](/Users/sean/sites/isekai-game/.worktrees/blender-spike/scripts/enemies/enemy_state.gd:86) maps DYING to hurt; [enemy.gd:592](/Users/sean/sites/isekai-game/.worktrees/blender-spike/scripts/enemies/enemy.gd:592) bypasses animation entirely during DeathFx. Downed then selects the final death picture. Separately, `die_pose` discards root height and `Rig.stand` grounds the lowest part—including equipment—rather than maintaining authored contacts. Coordinate death-animation ownership with DeathFx.

10. **The generic leg API assumes an unrotated parent.**  
    [limbs.py:38](/Users/sean/sites/isekai-game/.worktrees/blender-spike/tools/art/blender/limbs.py:38) derives local leg rotations without subtracting parent rotation. Current unrotated-hips goblin poses avoid this; reuse under a rotated pelvis or mount will not. `aim` does account for ancestors. This is a reuse limitation, not evidence that every existing goblin leg has a sign error.

11. **Cloth weights use the wrong coordinate space.**  
    [goblin_kit.py:129](/Users/sean/sites/isekai-game/.worktrees/blender-spike/tools/art/blender/goblin_kit.py:129) passes scaled/translated vertex Z to weights defined in standard goblin coordinates at [goblin_gear.py:132](/Users/sean/sites/isekai-game/.worktrees/blender-spike/tools/art/blender/goblin_gear.py:132). Convert with **`(z-origin_z)/(tall*scale)`**. Otherwise the bend region changes with form height and mount placement. Secondary springs also restart independently per clip; there is no transition-state continuity.

12. **Shading stability and palette limits are not enforced as advertised.**  
    [shade.py:126](/Users/sean/sites/isekai-game/.worktrees/blender-spike/tools/art/blender/shade.py:126) inherits the previous screen pixel’s band without material identity. A moving hand can inherit a torso’s shading history. [spike.py:83](/Users/sean/sites/isekai-game/.worktrees/blender-spike/tools/art/blender/spike.py:83) cyclically warms up even nonlooping attacks/deaths. Its `colours=24` argument is unused, and `toon.palette_of` truncates after 256 entries. The standalone GIF writer also uses a fixed 110 ms per frame.

Integration details that should not be misdiagnosed:

- **Horizontal normal mirroring is implemented correctly:** image flip plus `R=255-R`, [sprite_sheet.gd:84](/Users/sean/sites/isekai-game/.worktrees/blender-spike/scripts/ui/sprite_sheet.gd:84).
- **The fixed hurtbox is deliberate but visually misleading.** It remains **16×12**, while installed Redcap’s occupied idle art is **28×39**, drawn at **1.25× =35×48.75**. Much of its visible body is outside that box. Choose intentional per-form hurt volumes; do not blindly include weapons and cloaks.
- **Repeated hurt events do not restart hurt:** [slime_animator.gd:30](/Users/sean/sites/isekai-game/.worktrees/blender-spike/scripts/player/slime_animator.gd:30) ignores the same state. Stunned→hurt fallback eventually holds a nearly recovered upright pose.
- **Mounted forms lack the claimed six-clip coverage:** [creatures/goblin.py:37](/Users/sean/sites/isekai-game/.worktrees/blender-spike/tools/art/blender/creatures/goblin.py:37) supplies only idle/walk/attack, without the windup split. Their verb states fall back to idle.

**4. TEST GAPS**

Mutations can preserve the current green suite while breaking:

- **Physical foot planting:** tests check the same synthetic contact definition used by production. Track actual heel/toe vertices in world space through support transitions.
- **Production reach:** `test_goblin_motion.py:14` uses identical synthetic feet, and `:99` generally uses fixed `.5` stride. Sweep actual form geometry, cadence, scale and speed; assert endpoint residuals.
- **Real weapon trajectories:** `test_goblin_motion.py:171` substitutes an imaginary upward `.5-unit` weapon. Test actual axe head, reverse-grip dagger tip and sword edge, including body clearance.
- **Rendered endpoints:** hurt recovery is tested by evaluating a time that is never rendered (`:257`). Check the final exported picture against the next clip’s first picture.
- **Gameplay/animation synchronization:** `test_twin_clips.gd:84` checks that recovery remains selected, but never advances AI movement or compares activation time with impact.
- **Death reachability, stance transitions, repeated hits and mounted fallbacks.**
- **Scaled cloth weights, cross-material shading history, one-shot initialization and palette limits.**

**5. RANKED TOP 8 FIXES**

| Rank | Fix | Effort |
|---:|---|:---:|
| 1 | Unify attack event timing, recovery completion and movement restriction; regenerate stale exports. | M |
| 2 | Replace synthetic foot contact with fixed support pivots; match gait phase to travelled distance. | L |
| 3 | Establish the compressed body proportions and readable silhouettes before propagating the template. | M |
| 4 | Constrain gait reach and remove velocity discontinuities at lift-off/landing. | M |
| 5 | Author attacks around actual weapon tips, preserving form stances and lifting the returning foot. | L |
| 6 | Implement contact-driven death and connect it to the engine’s death lifecycle. | L |
| 7 | Preserve timing/end poses through export; add end-to-end behavioral tests. | M |
| 8 | Correct cloth coordinate space, secondary transitions and shading-history ownership. | M |