# Browser checks

The page's behaviour in time is checked in a real browser (Chrome tools, or any: open `http://127.0.0.1:<port>/?debug=1`). A hidden tab runs no animation frames, so with `?debug`
the clock is stepped by hand: `window.__reviewClock.advance(seconds)`. Each check below failed before its fix and passes after it. Use a throwaway creature (copy a sheet-based form
such as `goblin_skulker` to `zz_fix`, with a `sprites` block for `attack` and `idle` and a `compare` of `creatures/goblin/sprites.json` against `creatures/goblin_skulker/sprites.json`), and delete it afterwards.

| Check | Do | Expect |
|---|---|---|
| A one-shot clip opened late plays from its start | `advance(3)` on the index, open the creature, `advance(0.08)` eight times, read the attack canvas's `dataset.frame` | `0,1,2,...,9` (it was stuck on `9`); after it ends a click on the canvas shows `0` again |
| Compare draws each side at its own scale | read the two compare canvases' `style.width` | the widths are in the ratio of the listings' `scale` (1.12 against 1.0) |
| A typed note survives a live update | type in a clip's note box, rewrite that creature's `sprites.json` on disk | the box still holds the text |
| An index failure does not replace the open page | make `fetch` reject for `/api/creatures`, rewrite a file under `creatures/` | the creature's heading is still there |
| A goblin form shows what it holds, on its hand, in every frame of every clip | publish `sheet goblin_smith` into a throwaway content folder, open `#/creature/goblin_smith` | a hammer in the near hand and tongs in the far hand on `idle`, `walk`, `run`, `attack`, `hurt` and `die` (turned with the hand); the idle canvas is 52 x 39 (the hammer reaches above the body's 52 x 30) |
| Picking another item shows it at once, even with the page paused, and the canvas grows to hold it | click `pause`, set the near hand's `<select>` to `spear` (dispatch `change`), read the idle canvas's `getBoundingClientRect()` before and after | the spear replaces the hammer in the same frame; the displayed height grows (146 to 169 px at zoom 3, attributes 52 x 39 to 52 x 45); the spear's tip is not clipped on `walk`, `run` or `die` |
| Compare and lineup draw what a goblin holds (found by the branch review: they drew the body only) | publish `sheet goblin_smith` into a throwaway content folder, add a creature page with a `compare` of `creatures/goblin_smith/sprites.json` against itself on `idle` and a `lineup` of `goblin_smith`, open it | the compare canvases are 52 x 39 (they were 52 x 30) with the hammer in the near hand, and the lineup draws the smith with his hammer (its label keeps the body's size, 65x38) |
