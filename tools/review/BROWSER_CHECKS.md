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
| The index shows a thumbnail, name and stage on every tile | open `#/`; for each `.creature-tile` read its `.title`, its `.meta` and whether its `canvas.thumb` has drawn pixels | every tile has a name and a stage line (and `from <parent>`), none is empty (it was 0 of 32 with a thumbnail), and each sprite fills at least about half of the 112 x 96 box (a sheet cell's transparent padding is cropped away) |
| `fitScale` scales to whole pixels | `import('/app/thumbs.js')`, call `fitScale(32, 47)`, `fitScale(10, 10)`, `fitScale(200, 50)` | `2`, `4` (the cap), `0.56` (a sprite wider than the box is reduced) |
