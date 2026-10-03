**Previous concerns addressed:** the revision removes the already-built or unnecessary changes, gives spending a single ledger-based source of truth, and makes the calibration cover rebirth starts and area-end skill levels. It also clarifies the family hint and validation rules, controller bindings, form persistence, and the tree’s visibility and navigation behavior.

I found one new claim that needs correction: the tree spec says the base slime is always reached, but the persistence design stores only forms reached through successful `advance_form` calls. The stage-1 slime is never passed to that method, so it will not be recorded unless the tree treats it as reached by definition or initializes it in `forms_reached`.

**VERDICT: REVISE**