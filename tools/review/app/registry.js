// The block types a creature page can show. A block module registers its renderer here; app.js looks it up by the block's `type`.
//
//   registerBlock(type, (el, data, ctx) => void | Promise<void>)
//
// `el` is the block's own element (empty); `data` is the block's JSON from page.json. `ctx` is made by app.js:
//   ctx.creature          the creature's id                      ctx.url(rel)       a URL for a file in the creature's folder (it is re-fetched when that file changes)
//   ctx.zoom()            the page's zoom                        ctx.speed()        the page's speed        ctx.playing()   whether it is playing
//   ctx.time()            seconds on the page's shared clock     ctx.onFrame(fn)    fn(time) every animation frame while this block is shown
//   ctx.onControls(fn)    fn(name) when zoom, speed or play changes
// Anything registered through ctx is removed when the block is re-rendered or the page is left; a block needs no clean-up of its own.
const blocks = new Map();

export function registerBlock(type, render) {
  blocks.set(type, render);
}

export function getBlock(type) {
  return blocks.get(type);
}
