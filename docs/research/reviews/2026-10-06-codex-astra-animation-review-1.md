**Verdict:** This still reads as a procedural puppet, with more plausible walking poses but unconvincing contact and force. The main problems are foot-contact discontinuities, feet following pelvis translation, an ineffective weapon trajectory, and secondary motion that barely registers. Adding Blender IK constraints will not fix those choices automatically.

I reviewed the supplied strips and code, ran all **19 animation tests and 7 goblin-table tests successfully**, and used in-memory numerical probes. I did not edit files or render new frames. The old hob and new redcap are different models, so they are not a controlled before/after comparison.

1. **[High] Pelvis translation moves supposedly planted feet.**  
   [goblin.py:148](/Users/sean/sites/isekai-game/.worktrees/blender-spike/tools/art/blender/creatures/goblin.py:148), [goblin.py:227](/Users/sean/sites/isekai-game/.worktrees/blender-spike/tools/art/blender/creatures/goblin.py:227)

   `Leg.solve()` uses the rest hip X. Idle and attack subsequently apply `root.x` to the whole hierarchy. Consequently, the solved feet move horizontally with the pelvis instead of remaining planted beneath it.

   For redcap, the rear ankle moves approximately **4.38 game pixels between attack frames 2 and 7**, despite having a fixed target. That is substantial at this resolution. The forward foot also travels farther than its authored step. Idle’s smaller sway produces the same error.

   **Fix:** Solve using the actual transformed hip and a target in the same coordinate space. Alternatively, subtract root translation from world-space targets before solving locally. Keep the rear support point fixed while the pelvis advances.

2. **[High] Foot roll introduces position jumps and does not actually lock the support point.**  
   [anim.py:80](/Users/sean/sites/isekai-game/.worktrees/blender-spike/tools/art/blender/anim.py:80), [goblin.py:139](/Users/sean/sites/isekai-game/.worktrees/blender-spike/tools/art/blender/creatures/goblin.py:139)

   `Leg.ankle()` adds `contact_lift()` only while grounded. At `u=0.6`, grounding switches off while pitch is still −34°. The redcap ankle therefore jumps from approximately **Z=0.2368 to 0.0990**: **3.58 game pixels downward**. At the loop boundary, the heel-strike correction jumps back on by another **0.62 pixels**. Twelve samples conceal the exact discontinuities; they do not remove them.

   The visible consequence is the odd **frame 7 → 8 → 9** sequence: the near ankle drops as swing starts, then rises again. Calculated knee flexion goes approximately **73° → 52° → 73°**, producing a double pumping action.

   Furthermore, adjusting ankle height alone cannot rotate a foot around a stationary heel or toe. The contact point also moves horizontally. Heel length is guessed from the bone, and different boots change the actual sole without changing the contact model.

   **Fix:** Define heel/ball/toe support points per foot or footwear. Derive ankle X and Z from the active pivot and pitch. Start swing from the final toe-off transform, continuously; land into the heel-contact transform. Test the composed ankle and sole trajectories.

3. **[High] The redcap attack lacks a convincing striking trajectory; the item rotation works against the hand.**  
   [goblin.py:64](/Users/sean/sites/isekai-game/.worktrees/blender-spike/tools/art/blender/creatures/goblin.py:64), [goblin.py:256](/Users/sean/sites/isekai-game/.worktrees/blender-spike/tools/art/blender/creatures/goblin.py:256)

   Frames **1–2** provide anticipation, but the hand travels backward and upward through a large shoulder rotation. Frames **3–4** scoop it underneath and forward. At **5**, the torso advances, but the axe points back toward the character; **6–7** extend the hand without extending the striking head meaningfully. Recovery **8–11** mostly unwinds the pose.

   Numerically, at frame 5 the hand is around **X=0.686**, while the axe-head centre is **X=0.505**, behind it. The axe-head centre at idle is approximately **X=0.517**. The intended impact practically returns the weapon head to its idle location.

   `_hold_items()` correctly cancels ancestor rotations for this all-Y hierarchy. The problem is the desired orientation: `item_n` keys are interpreted as **raw Y rotations**, while much of the surrounding animation uses `down()` conventions. For this upright axe, −62° turns the head backward.

   **Fix:** Author and inspect the weapon-head arc first. For this axe, roughly **+60° raw Y at impact**, rather than −62°, would put the head ahead of the hand. Rework anticipation to match that arc. Use separate attack profiles for axe, thrusting spear, shield, and held objects; one item-angle curve cannot suit them all.

4. **[Medium] The walk has the right broad phase, but the contact/down/up distinctions remain weak.**  
   [goblin.py:180](/Users/sean/sites/isekai-game/.worktrees/blender-spike/tools/art/blender/creatures/goblin.py:180)

   The intended sequence is identifiable: contacts at **0/6**, down near **1/7**, passing around **3–4/9–10**. At those latter poses, the overlapping legs make the redcap look briefly like a single boot beneath a largely unchanged torso. The old hob’s **2/6** poses have clearer leg separation, although their exaggerated spread is not evidence of better mechanics.

   The pelvis phase is **correct for the stated duty factor**: minima at `t=0.05, 0.55`, maxima at `0.30, 0.80`. It is not inverted. Redcap’s sampled pelvis excursion is about **1.48 pixels**, enough to read if the contacts support it.

   The problem is the resulting leg choreography: late-stance toe lift folds the knee aggressively, then the contact discontinuity interrupts the swing. More bob would exaggerate that defect.

   **Fix:** Repair contact first, then strengthen the four readable poses. Start around **10–20° knee flexion at contact**, **25–35° on loading**, and **50–65° in swing**, treating these as art targets rather than universal anatomical limits. Keep a visibly distinct passing foot and reserve an up pose before the next contact.

5. **[High] The committed previews do not reproduce the declared timing.**  
   [spike.py:102](/Users/sean/sites/isekai-game/.worktrees/blender-spike/tools/art/blender/spike.py:102), [goblin_tree.py:125](/Users/sean/sites/isekai-game/.worktrees/blender-spike/tools/art/blender/goblin_tree.py:125)

   `HOLDS` is exported as metadata, but the committed individual GIF writer uses **110 ms per unique pose**, ignoring both holds and per-animation FPS. The tree GIF uses the **average walk FPS across forms**, despite claiming to show each form at its own speed.

   If playback honors the declared attack metadata, it uses **70 ms ticks**, not 24 fps: **19 ticks / 1,330 ms total**, impact starts at **560 ms**, and pose 5 lasts **210 ms**. The supplied strip cannot establish those durations.

   The stride equation itself is correct:

   `stance speed = stride / (duty × cycle) = speed / ppu`

   That guarantee applies only at the corresponding playback rate, before contact-roll errors and reach clamping. It also cannot cover changing runtime speed: the enemy animation currently advances by unscaled `delta`, including when movement is slowed.

   **Fix:** Use one timestamped clip definition for rendering previews, secondary simulation, and export. Preview walking over a scrolling ground reference at the intended speed; scale locomotion playback when runtime velocity changes.

6. **[Medium] `follow()` is a usable periodic filter, but not a general seamless-loop or one-shot solution.**  
   [anim.py:111](/Users/sean/sites/isekai-game/.worktrees/blender-spike/tools/art/blender/anim.py:111), [goblin.py:277](/Users/sean/sites/isekai-game/.worktrees/blender-spike/tools/art/blender/creatures/goblin.py:277)

   Repeating a periodic driver until a damped spring settles is reasonable. **Six cycles are not a convergence guarantee**, however; the test validates one particular waveform and parameter set. Seamlessness requires matching spring position and velocity across the periodic boundary, not equal first and last sampled poses.

   More seriously, simulation time is measured in **pose indices**. A 6-fps idle, roughly 21-fps redcap walk, and unevenly held attack all use the same numerical timestep. The attack is warmed up as though several identical attacks preceded it, then its entire secondary pose freezes during repeated frames.

   **Fix:** Integrate in seconds with explicit initial position/velocity. Use periodic convergence for loops; initialize attacks from the preceding state and let them settle. Apply actual hold durations during simulation, with deliberate whole-character hit-stop only where desired.

7. **[Medium] The cloak behaves like a trailing board; the bob/wind model is not geometry-aware.**  
   [goblin.py:83](/Users/sean/sites/isekai-game/.worktrees/blender-spike/tools/art/blender/creatures/goblin.py:83), [goblin_gear.py:115](/Users/sean/sites/isekai-game/.worktrees/blender-spike/tools/art/blender/goblin_gear.py:115)

   Bloodcap’s cloak keeps nearly the same diagonal silhouette throughout **0–5 and 6–11**. The calculated local walk variation is only about **0.42° for cloak1 and 0.66° for cloak2**. Most of the pose comes from constant −7°/−9° offsets, not visible traveling overlap.

   There is **no blanket sign reversal** in `_secondary()`: converting parent rotations to forward-positive angles and applying `down(chased-parent)` is consistent. Negative wind correctly pushes a downward-hanging cloak backward. But the same negative rotation moves the **upward-pointing ear tips forward**, contrary to the stated trailing intent.

   The bob term uses height displacement as angular forcing. Positive bob rotates backward-pointing tips downward; that is a stylized coupling, not acceleration-derived inertia. A universal sign cannot make it physical for every attachment orientation.

   **Fix:** Use attachment-specific response axes and pivot acceleration, or deliberately author the overlap. Give the cloak tip roughly **1–2 pixels of visible motion**, delayed behind the upper segment. The rigidly weighted tube pieces also need a better-connected cloth silhouette if bending becomes stronger.

8. **[Medium] Arms, torso, and idle silhouette still conceal most of the performance.**  
   [goblin.py:165](/Users/sean/sites/isekai-game/.worktrees/blender-spike/tools/art/blender/creatures/goblin.py:165), [goblin_forms.py:120](/Users/sean/sites/isekai-game/.worktrees/blender-spike/tools/art/blender/goblin_forms.py:120)

   Arm opposition is correct: the near arm goes back when the near foot comes forward. But redcap’s `guard_n` multiplier reduces **both arms** to only **2.7° swing amplitude**, including the supposedly free far arm. Elbow variation is just **1.62°**, tied directly to the upper-arm cosine without independent overlap.

   Head counter-rotation stabilizes orientation somewhat, but does not stabilize head position against pelvis translation. The spine remains one rigid hinge.

   In paladin idle, **all twelve poses retain essentially the same dominant shield/cape silhouette**. The shield obscures the face, and the original nearly coincident feet make the character appear one-legged. Breathing is subordinate to those readability problems.

   **Fix:** Separate left/right arm gains, keep the guard arm restrained, and give the free arm roughly **12–18°** swing with a small delayed elbow response. Lower/reposition the shield and separate the idle feet before increasing breathing motion.

9. **[Medium] The IK mathematics is sound within assumptions that the next rigs will violate.**  
   [goblin.py:132](/Users/sean/sites/isekai-game/.worktrees/blender-spike/tools/art/blender/creatures/goblin.py:132), [rigkit.py:109](/Users/sean/sites/isekai-game/.worktrees/blender-spike/tools/art/blender/rigkit.py:109)

   For this planar rig, `d1=a1-rest1`, `d2=a2-rest2`, followed by thigh `d1`, shin `d2-d1`, and foot `pitch-d2`, is correct. Foot pitch is a rotation of the **neutral foot geometry**, not the literal foot-bone direction; its sloped rest bone does not by itself prove a missing subtraction.

   Problems begin with rotated hips, unequal hip heights, out-of-plane limbs, or added spine/shoulder ancestors. `_length()` discards Y; `Leg.solve()` assumes no inherited hip rotation; item and secondary chains are manually enumerated. Summing Euler Y angles works here because all relevant rotations share one axis.

   **FK driven by IK targets is a reasonable architecture.** You already have real Blender armatures; what is missing is a control rig. Separate world/root motion, pelvis/COG control, foot targets, heel/ball/toe pivots, knee poles, spine/neck controls, and clavicles. Add IK/FK switching where it benefits animation. Blender exposes target, pole, and chain-length controls directly. [Blender IK documentation](https://docs.blender.org/manual/en/dev/animation/constraints/tracking/ik_solver.html)

   **Fix:** Preserve trajectories as control data and introduce a backend that drives Blender controls. Do not translate the current world-axis angle dictionaries directly into bone-local Euler keys.

   A wolf’s hind leg needs its knee/hock/metatarsal structure; simply using `bend=-1` on a human two-link leg is insufficient. Spider limbs need explicit 3D solve planes and contact scheduling. An undead biped can reuse the contact system with different pose/timing choices. Slime deformation needs squash/stretch controls absent from this rigid rotation-only interface. Riders currently still use the old wolf gait and whole-model grounding.

10. **[Medium] Tests validate components while missing the integration contracts responsible for weight.**  
    [test_anim.py:52](/Users/sean/sites/isekai-game/.worktrees/blender-spike/tools/art/blender/test_anim.py:52)

    The “planted foot” test checks the uncorrected path, not the final ankle or sole. No test covers `Leg.solve()` through the rig hierarchy, root translation, gear contact geometry, weapon orientation, held attack time, or secondary-state transitions.

    **Fix:** Add focused checks for final world-space contact drift, ankle continuity at `duty` and wrap, actual FK endpoint reconstruction with transformed parents, weapon-head position at impact, spring convergence, and preview/export duration agreement. Fail visibly on unreachable stance targets instead of silently accepting a clamp.

11. **[Low] There is a real loop-sampling edge case, and the research overstates what the implementation proves.**  
    [anim.py:48](/Users/sean/sites/isekai-game/.worktrees/blender-spike/tools/art/blender/anim.py:48), [rig-weight-research.md:47](/Users/sean/sites/isekai-game/.worktrees/blender-spike/docs/research/rig-weight-research.md:47)

    `sample_loop()` breaks when the first key is after zero. Keys at times 2 and 6 with period 8 approach value 4 before wrap, then jump to 0 at time 0. Handle the previous cycle’s final segment, or require a first key at zero.

    The research also calls sine motion “constant speed”; its derivative is not constant. A 60% duty factor with half-cycle leg separation gives **20% double support**, not 25–30%. More frames and IK do not establish weight without contact, silhouette, and timing validation.

**The five improvements I would make, in order:**

1. **Repair contact and coordinate spaces.** Continuous heel/toe pivots, actual sole dimensions, and world-space support targets. Aim for under **0.25 game-pixel sampled contact drift**, with no mathematical jump at contact transitions.
2. **Rebuild the redcap attack around the axe-head arc.** At **24 fps**, try **3–4 anticipation frames (125–167 ms)**, **1–2 swing frames (42–83 ms)**, **1–2 impact frames**, **2 follow-through frames (83 ms)**, and **4–6 recovery frames (167–250 ms)**. Tune to gameplay hit timing.
3. **Polish one walk against moving ground.** Keep twelve distinct poses initially; at 24 fps that is **500 ms per cycle**. Preserve the existing roughly **1–1.5-pixel pelvis excursion**, remove the double knee pump, clarify passing poses, and restore the free arm’s swing.
4. **Unify timing and make overlap visible.** Seconds-based springs, correct preview holds, one-shot initialization, and cloak-tip movement of **1–2 pixels** with roughly **1–2 frames of downstream delay at 24 fps**.
5. **Build the Blender control rig around those corrected trajectories.** Independent COG and foot controls first, then poles, foot roll, spine/neck, shoulders, and suitable species-specific limbs.

Two concurrent working-tree edits appeared during review—idle foot spacing and shield geometry. These findings address `139a11a` and the supplied strips.