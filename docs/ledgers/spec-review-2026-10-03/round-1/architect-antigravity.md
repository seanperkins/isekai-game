As The Architect, I have reviewed the structural integrity and boundaries of the proposed implementation plan. Here are the critical flaws, boundary violations, and architectural gaps in the design.

### 1. Most Expensive Decision to Reverse: Breaking the Event-Sourced Ledger
**The Finding:** The decision to store `_spent` essence as a mutable per-life state variable on `SkillRulesEngine` is a fundamental boundary violation.
**The Problem:** The game's economy is currently built on an event-sourced ledger (income is derived from counting `ABSORBED` events). By imperatively mutating a `_spent` dictionary when `evolve()` is called, you are fracturing the state architecture: income is event-sourced, but expenses are mutable state. 
**The Cost:** If you ever need to reconstruct the state of a run—for replays, future save/load implementations, analytics, or undo mechanics—you cannot accurately rebuild the player's essence balance because spending was never recorded in the ledger. 
**The Fix:** `evolve()` must emit an event (e.g., `SKILL_EVOLVED` with its price payload) into the ledger. `held()` should then be a pure projection: the sum of `ABSORBED` events minus the sum of prices in `SKILL_EVOLVED` events.

### 2. The Tree Graph Boundary Error: Dangling Edges from Mixed State Lifecycles
**The Finding:** The Tree tab models global, permanent knowledge ("a record of the soul"), but it uses ephemeral, per-run state to dictate form visibility. 
**The Problem:** A skill node is visible if it is in the persistent Compendium. A stage-2 form node is visible only if its lineage is `open this life` (or previously `reached`). If a player unlocks Poison Breath in Life 1, the power enters the Compendium and is visible in Life 2. However, because they haven't re-earned the power in Life 2 yet, the Toxic form is NOT `open this life` and is hidden. The graph will attempt to draw the "opens" edge from the visible Poison Breath node to the non-existent Toxic form, resulting in a dangling edge and a broken layout.
**The Fix:** Form node visibility must share the same lifecycle boundary as the skills. If the prerequisite power is in the Compendium, the form node must be visible as a stub, decoupling the permanent Tree from the ephemeral `open this life` rule.

### 3. Graph Filtering Flaw in `forms_focus` Fallback
**The Finding:** The `forms_focus` fallback filter breaks the graph topology by culling nodes without culling their incoming edges.
**The Problem:** When `forms_focus` is active, it keeps only the current form's evolutionary line, culling all other forms. However, the spec dictates that "the power band is unchanged." Because all power nodes remain, the "opens" edges originating from those powers will point to stage-2 forms that have just been deleted by the filter.
**The Fix:** If a node is filtered out of the model, all edges pointing to it must also be filtered out before the layout is returned to the renderer.

### 4. Logic Inversion in Rebirth Kits Decoupled from Elements
**The Finding:** Granting powers directly via Rebirth Kits (e.g., D1 granting Tremor) bypasses the elemental threshold architecture.
**The Problem:** Tremor is the third tier of the earth element sequence (Body Armor → Hardened Shell → Tremor). If a kit grants Tremor directly to a new life, the player starts with the Tier 3 power but zero `absorbed` earth. As they play and absorb earth, they will retroactively unlock Tier 1 and Tier 2. 
**The Fix:** If kits are to grant powers without granting the underlying essence, the design must account for how threshold-based base powers behave when unlocked out of sequence, or the kits should grant the element capacity directly rather than the specific power.

### 5. Loss of Magnitude in Predation Unlocks
**The Finding:** Replacing the `thread` essence with a `PREDATED` event tag (`family: spider`) fundamentally changes how the engine weights creatures.
**The Problem:** In the old system, a large enemy like the Taratect yielded `thread 3`, accelerating progression. The engine's event matching ("matches a counter on any tag subset") only counts the *number of events*. Eating a Taratect (1 event) now contributes the exact same amount toward the "third spider" unlock as eating a basic Black Spider. The system loses the ability to weight larger prey for tag-based unlocks unless the engine is modified to sum tag values instead of just counting events.

VERDICT: REVISE
