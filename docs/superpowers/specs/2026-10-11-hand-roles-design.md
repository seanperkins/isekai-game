# Primary and secondary hands: design

A goblin's two hands get roles. The **primary** hand acts (attacks, throws, casts, uses its tool) and the **secondary** hand is the off-hand (a shield, a lantern, tongs). Today the data, the engine, the review page and the animation all say near arm and far arm; this makes them say primary and secondary, and says which physical arm each is.

## What I understood

You asked for models that "work with a primary and secondary handed items", and chose:

- **Which arm is primary:** set per form, the near arm by default. A form whose off-hand item should be seen (the paladin's shield) makes the far arm primary, so the shield is on the near arm in front of the body.
- **Two-handed items** (spear, staff) fill the primary hand and block the secondary one.
- **The animations follow the roles:** the blow a form strikes and the arm it strikes with come from its primary hand; the secondary arm braces.
- **The paladin** holds a mace (the `club` piece) in the primary hand and the shield in the secondary, with the far arm primary.

Assumed, not said: nothing changes for the undead, wolf or spider kits (only the goblin kit has held items); the forms that exist today keep their look (their near item becomes primary and their far item secondary); a swapped-in item at run time does not change the baked animation (that is the later weapon-slot piece).

## Decisions

| Question | Decision |
|---|---|
| What roles are | Two, `primary` and `secondary`. Every held piece has a default role in `held.py`: weapons and tools are primary; the shield, lantern, tongs, coin and straw are secondary. A form's gear entry can say `hand="primary"` or `hand="secondary"` when it differs from the piece's default (the Puck's lantern is primary; the mastersmith's short sword, the hearth god's horn and the giant killer's sling are secondary). `side=` leaves the forms' data. |
| Which physical arm | A form's `handed` is `"n"` (default) or `"f"`: the physical arm of its primary hand; the secondary is the other. The render's hands stay physical (`hands` has `n` and `f` per frame, as now); the mapping to roles is made by whatever reads them. |
| Draw order | Unchanged and physical: the near arm's item is in front of the body, the far arm's behind it. A far-handed form's primary item is behind its body. |
| Two-handed | `held.TWO_HANDED = {"spear", "staff"}`. No current form holds one of them next to another item (the riders hold a spear alone; no form holds a staff), so none changes meaning. A two-handed item in the primary hand empties the secondary: a secondary item is refused while it is held and returns when the two-hander leaves. While a form's primary item is two-handed its secondary arm takes the primary arm's angles in every pose, so both hands are on the item. |
| Animation | Arm poses (`ARMS`) and attacks (`attack_kinds`, `biped_motion.ATTACKS`) stay authored with the first arm as the acting one, which is now the primary arm: `Body` maps primary and secondary to physical bones by `handed`. The swing of a walk or run stays tied to the physical leg, so a far-handed form's arms do not swing with the same-side leg. What it strikes with (`attack_kind`) comes from the item in its primary hand. |
| Paladin | `handed="f"`, `G("club")` (primary), `G("shield")` (secondary), `attack` removed (it plays the verb's gesture, the throw, from the primary arm; `throw_free` goes). |
| Scope | The model, the data, the render's gear placement, the gestures and the pickers. Not: pickup, stats, the weapon slot, or a swapped item changing the baked animation. |

Rejected: rebuilding every pose and attack in primary and secondary terms (it would re-render all 29 forms for no change in what they look like), and a data-only rename (you chose that the gestures follow the roles).

## Architecture

```
tools/art/blender/held.py             ROLE_OF (default role per piece), TWO_HANDED, held_of(gear, handed) by role, form_entry writes handed + roles
tools/art/blender/goblin_forms.py     gear `side=` becomes `hand=` only where the role differs from the piece's default; `handed` key; the paladin as above
tools/art/blender/goblin_gear.py      shield takes `side` like every held piece (it was fixed to the near arm)
tools/art/blender/creatures/goblin.py build() turns each held piece's role into the physical `side` by the form's `handed`
tools/art/blender/biped_motion.py     Body.primary / Body.secondary bone names; _arms, attack_pose, the hurt and die poses and _hold_items address arms by role; attack_kind reads the primary item; two-handed rule
tools/art/blender/export_forms.py, export_base.py   unchanged except through held.form_entry
data/held_items.json                  forms: {"scale", "handed", "primary", "secondary"}; items gain "two_handed"
scripts/ui/held_items.gd              form() returns the roles and handed; item() returns two_handed
scripts/ui/held_item_layer.gd         set_item / item take "primary" | "secondary"; the two-handed rule; the physical pivots are chosen by handed
tools/review/publish.py, app/blocks/held-draw.js, sprites.js   held.form carries handed, primary, secondary; items carry two_handed; the pickers are "primary hand" and "secondary hand"
```

### Data and gear

- `held.ROLE_OF[piece]` is `"primary"` or `"secondary"`; `held.HELD` (the piece names) stays. `held_of(gear)` returns `{"primary": id or "", "secondary": id or ""}` (the roles do not depend on `handed`; only `build()` and the layer need it). A gear entry's role is its `hand=` option, else `ROLE_OF[piece]`; two pieces in one role is a `ValueError`; a two-handed primary with a secondary piece is a `ValueError` (a form cannot be authored holding both).
- `goblin.build(variant, hold=True)` passes each held piece its physical side: the form's `handed` for a primary piece, the other for a secondary one. Gear functions keep their `side` parameter; the shield gains it (its geometry in front of the near arm is the `"n"` case; `"f"` mirrors it behind the far arm).
- `held.form_entry(form_name, ppu)` returns `{"scale", "handed", "primary", "secondary"}` (a role with nothing in it has no key, `handed` is always there). The item ids and the item sheets do not change: an item is the same picture whichever role holds it. `data/held_items.json["items"][id]` gains `"two_handed": true` for the two-handed pieces.
- The migration of the 28 forms' gear is mechanical (near becomes primary, far secondary, dropped when equal to the piece's default) and a test proves it: `held_of` of every form equals what it was by side.

### Animation

- `Body` gets `handed` from the form and `primary`/`secondary` (`"n"`/`"f"`): the bones are `arm_<side>`, `fore_<side>`, `item_<side>`. Every pose that keys the near arm and near item specially (`_arms`, `attack_pose`, hurt, die, `_hold_items`, `_rest_channels`) goes through `body.primary` for the acting arm and `body.secondary` for the other; with `handed="n"` that is what they do today, so those forms are unchanged.
- `_arms`: the preset's first pair of angles belongs to the primary arm and the second pair to the secondary, and the swing phase belongs to the physical side (the near arm swings against the near leg whichever role it has).
- Attacks: the preset's near-arm channels (`arm_n`, `fore_n`, `item_n`) are the primary arm's and its far-arm channels the secondary's. `attack_kind(form)` takes the blow of the primary item (`ATTACK_BY_GEAR`), else `swipe`, as it took the near item's.
- Two-handed: when the form's primary item is in `TWO_HANDED`, the secondary arm's bases and attack channels are the primary arm's, in every pose.
- The undead share `attack_kinds` through `register_undead` and are untouched (they have no `handed`).

### Engine

- `HeldItemLayer`: `set_item(role, id)`, `item(role)`, `bind(form_id)` and the overrides work in roles (`"primary"`, `"secondary"`). The layer reads the form's `handed` to put a role on a physical pivot (and a `hands` entry), so `HeldItemN` and `HeldItemF` stay the nodes they are and draw as they do. A role the form does not name holds what its default says.
- Two-handed: `HeldItems.item(id)["two_handed"]`. `set_item("secondary", id)` returns false while the primary item is two-handed; `item("secondary")` returns `""` while it is (the item the secondary hand held returns when the primary changes). Setting a two-handed item in the primary hand does not clear the stored secondary item.
- The bind on an evolution keeps overrides as before; `handed` is the new form's, so an override keeps its role.

### Review page

`publish.sheet_listing` carries `held.form = {primary, secondary, handed, scale}` and each item's `two_handed`. The sprites block's two pickers are "primary hand" and "secondary hand" and use the same rule (choosing a two-handed item for the primary hand sets the secondary to nothing and disables its picker; clearing it restores the choice). `held-draw.js` and `hands.js` take a role-to-side map to find a hand in `frame.hands`; the compare and lineup blocks draw the defaults as now.

## Paladin

His gear is `G("club")`, `G("shield")` and `handed="f"`: the mace on the far arm (behind his body), the shield on the near arm in front. The `ARMS["shield"]` pose and the shield geometry from the paladin branch stay, with the pairs reordered to primary first: `ARMS["shield"]` becomes (the mace arm's pair: hanging ready, the pair the far arm has now, the shield arm's pair: `(8, 84)`, the swing). His `attack` entry is removed, so he plays the verb's own gesture, the throw (`verb_anims`), from the primary arm, with the shield arm braced; `throw_free` is removed with its tests. His one attack clip is the Blessed throw: the mace goes with the throwing arm.

## Error handling

- A form authored with two pieces in one role, a two-handed primary beside a secondary piece, or a `handed` that is not `"n"` or `"f"` is a `ValueError` naming the form.
- `HeldItems.form(id)` for an unknown form is `handed "n"` with nothing in either hand and scale 1, as now. An unknown role in `set_item` is refused.
- A sheet exported before this change has `n`/`f` in the forms table: the engine reads only the new keys, so a stale table shows no items; the export always rewrites it.

## Testing

- Python: `held_of` by role equals the old by-side result for every form (the migration test); `held_of` refuses two pieces in a role and a two-hander with a secondary; `form_entry` has `handed` and roles; `build(hold=False)` still leaves out every held piece and a far-handed build puts the primary piece on the far arm (checked by the item bone each piece is bound to); `attack_kind` takes the primary item's blow; a far-handed `Body` swaps the acting arm's channels and keeps the gait's swing on the physical leg (poses of a form with `handed="f"` equal the near-handed poses with the arm channels exchanged, over a whole walk); a two-handed primary puts both hands at the same place in idle, walk and attack; the rendered sheets of every form except the paladin, the beast rider and the wolf lord are byte-identical after the change (the regression gate).
- GUT: `set_item`/`item` by role; `handed` puts the primary role on the far pivot; the two-handed rule in both directions; overrides keep their role across an evolution; the paladin's mace is on the far pivot behind the body and his shield on the near pivot in front.
- Review page: `publish` carries the roles and `two_handed`; the layout tests and a browser check that choosing the spear for the primary hand disables the secondary picker and restores it.

## Build order

1. **Data and gear:** roles, `handed`, `two_handed`, the migration, the shield's side, `build()`, with the unchanged-sheets gate for the forms that do not change.
2. **Animation:** `Body` roles, the arm poses, attacks, the two-handed rule, the paladin's pose and gesture; re-render the paladin and the two riders.
3. **Engine:** roles in the layer and the table, the two-handed rule, the tests.
4. **Review page:** roles in the listing and the pickers.

## Risks

- A far-handed primary arm is behind the body, so the paladin's throw is partly hidden and dimmed. It is the form's choice and is one key to change.
- The paladin's one attack clip is the verb's throw, thrown from the mace arm: the mace goes with the arm. A separate basic-attack clip needs the engine to play a second clip, which is not built.
- A runtime swap does not change the baked animation: a spear swapped into a goblin's primary hand shows without its secondary hand on it, and the secondary item is hidden. The animation that matches belongs to the weapon-slot piece.
- The beast rider and wolf lord change look (their second hand moves onto the spear); every other form's sheet must come out the same.
- This branch builds on `fix/paladin-shield` (the paladin's shield pose and `throw_free`), so it is merged with it.

## Out of scope

Pickup and the weapon slot, item stats, a swapped item changing a form's verb or baked animation, the undead, wolf and spider kits' held things, and a second (melee) attack clip.
