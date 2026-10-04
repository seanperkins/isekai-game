**The round-2 edits resolve most of the reported issues, but I found four points to revise:**

1. [Spec 2’s detail rule](/Users/sean/sites/isekai-game/docs/superpowers/specs/2026-10-03-skill-tree-screen-design.md:42) says the essence overhaul adds `family` wording to `condition_text`. [Spec 1](/Users/sean/sites/isekai-game/docs/superpowers/specs/2026-10-03-essence-overhaul-design.md:32) now uses a `source` tag and adds a `source` wording branch. Update Spec 2 to match.

2. [Spec 2](/Users/sean/sites/isekai-game/docs/superpowers/specs/2026-10-03-skill-tree-screen-design.md:37) shows an unknown evolution stub whenever its parent is merely *Named*. The [design doc](/Users/sean/sites/isekai-game/docs/isekai-chronicles-design-doc.md:158) calls for branch stubs after the power has been owned. As written, Appraisal could reveal a power’s branches before the player earns it. Set the visibility threshold explicitly.

3. [Spec 2](/Users/sean/sites/isekai-game/docs/superpowers/specs/2026-10-03-skill-tree-screen-design.md:38) both packs skills into a name-ordered grid without reserving a secret skill’s slot and promises that discovering any node never moves another. When secret Glutton enters that packed grid, one rule must give. Specify a stable placement for newly revealed secrets or narrow the stability promise.

4. [Spec 1’s success criterion](/Users/sean/sites/isekai-game/docs/superpowers/specs/2026-10-03-essence-overhaul-design.md:16) still requires *every* Cave-start unlock within one eat of today, while its [calibration decision](/Users/sean/sites/isekai-game/docs/superpowers/specs/2026-10-03-essence-overhaul-design.md:35) explicitly moves Tremor from the Deep to the Flooded. State that exception in the criterion.

This was a read-only review; I did not run the test suite.

VERDICT: REVISE