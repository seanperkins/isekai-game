# Spider crawl spike: findings

Throwaway spike for build step 4 of the species movesets spec. Code: `spikes/spider_crawl/` on branch `spike/spider-crawl` (not for the game). Feel inputs: [spider-locomotion.md](spider-locomotion.md). Run the checks with `spikes/spider_crawl/run.sh` (about half a second) and play it with `godot --path . res://spikes/spider_crawl/crawl_spike.tscn`.

## What was built

A crawler on a real `CharacterBody2D`, driven one tick at a time, over axis-aligned terrain like the rooms: a floor, a block, a pillar under a slab (every surface orientation and both corner kinds), a one-way ledge, two touching blocks (a tile seam), and the end walls. Eleven headless scenarios drive it with scripted input and print every surface change; a playable scene shows it with the real spider sprite.

## The model that worked

- **Surface state:** `n`, the outward normal of the surface under the feet (one of four, because rooms are axis-aligned), and `t = n.rotated(90°)`, the clockwise tangent. The body never rotates (the player's root must not): only the 28x24 collision box swaps to 24x28 on walls.
- **Per tick:** sweep forward along the tangent (`test_move`). A hit on a hard wall facing back at it is a **concave corner**: turn up it, shifting the centre 2 px on each axis. Otherwise move, then cast a ray from the centre along the inward normal. If it finds nothing the centre has passed the end: a **convex corner**. The box is turned rigidly about the corner (centre one half-height out from the end face, level with the corner), then a zero move lets physics recover any overlap.
- **Which way is forward:** a signed speed `sigma` along `t`. Off a corner it is screen-relative (`input · t`, which handles floor, ceiling and walls in one line). At a corner the **latch** takes the held direction and keeps the same rotational sense on the new surface while the input stays within about 45° of it. Releasing keeps the latch (no motion); a clearly different direction drops it.
- **Back round a corner:** with nothing along the current surface, pressing back the way it came within 0.6 s of a corner reverses it round the corner.
- **Hop:** launches along the surface normal at the base jump speed (330), then plain gravity with 0.6 air control; it lands on the floor always and attaches to a wall or ceiling only if the input presses toward it.

## Results

| Scenario | Result |
|---|---|
| Over the block, held right and held left | Pass: 4 surface changes each, one held direction |
| Round the pillar and slab, clockwise and counterclockwise | Pass: 6 surface changes each, all four normals, both corner kinds |
| The same with noisy input (5% dropouts, 10% diagonals) | Pass |
| Diagonal stick over the block | Pass |
| Press back right after a corner | Pass: goes back round it and down to the floor |
| Hop up through a one-way ledge, land on it, walk off the end | Pass: falls at the end (`ledge_end = "fall"`) or stops (`"stop"`) |
| Hop off a wall | Pass: arcs away and lands on the floor |
| Ceiling walk | Pass: no drift, no fall |
| Over a tile seam of two touching blocks | Pass: no catch, no extra corner |

## Answers to the spike's questions

**Corner latching and hysteresis.** Three things were needed that the first version lacked:
1. The latch must **survive a release**. Dropping it on a one-tick stick dropout stranded the crawler on a wall, because "right" has no meaning on a vertical face.
2. Corners need a **lockout**. With 0.06 s, a stick wiggled at a corner (left and right every 4 frames) rounded it 60 times in 4 seconds, 15 a second. With **0.10 s or more** it wrapped once and stayed. Recommend **0.10 s**.
3. The **back-round rule** (0.6 s) is the only way to return across a corner with a screen-relative stick. After 0.6 s the crawler needs an input along the face (up or down on a wall), which reads as the right behaviour.

**One-way ledges.** The top is a floor and nothing else. It cannot be wrapped (the end has no face), so the crawler **falls off its end**; a "stop at the end" variant also works. The hop passes up through it from below. Two details: a landing must check that the **centre** is over the ledge, otherwise the box's rim catches the end and it loops attach, fall, attach; and a ledge's side and underside must never be probed (the ledge sits on a separate collision layer and the surface ray ignores it unless the surface is a floor).

**How far the body moves at a corner.** A concave corner moves the centre 3 to 4 px. A convex corner moves it about 19 px (28 px if the box were put flush below the corner). The collision body changes surface in one tick, so the **sprite must ease**: rotation and position over about 0.12 s, which the playable scene does.

## Feel, from playing it

Sean: crawling on the ceiling and around corners feels good. Two fixes: the silk trail from every hop and fall was a mystery with no job, so it is gone until the web zip and silk drop need a thread; and the two-frame `hang` idle looked like movement, so a stopped spider now holds the stride frame it was on.

## What the build needs (probes and shape)

- **Probes on `MoveInput`**, filled by the caller (the sandbox now, the player later): a **sweep** (`motion -> hit, travel, normal, layer`) and a **ray** (`from, to -> hit, layer`). The spec already adds a ray callable for the zip, so the crawl reuses it. The only per-tile information needed is "hard or one-way" (and later "slick").
- **A pure `SurfaceStep` over those probes**, tested on a small fake world of rectangles (milliseconds), plus a handful of real-collision scenarios like this harness. The model is deterministic, so the scenarios above become the tests.
- **A hand-off to the existing step:** while attached, the surface step owns movement (as a burst owns horizontal velocity); a hop or a fall hands back to `GroundAirStep` with the hop's velocity.
- Speed stays 140 on every surface; instant start and stop (0.03 and 0.02) apply along the surface.

## Not covered

Slick surfaces, moving platforms and enemies, slopes (the rooms are axis-aligned; confirm no angled solids exist), gaps narrower than the box, hard ledges thinner than the box (the end face is shorter than the body: the model reports it as `convex_nothing` and falls), water, and the priority table (hurt, rope, evolve). Each needs a scenario before the surface model ships.

## Decisions for the spec

1. **Corner lockout 0.10 s.**
2. **A one-way ledge's end drops the spider** (the alternative is a stop; both work).
3. Spider crawl speed is 140 on floors, walls and ceilings.
4. The spider's idle is a held pose; its silk appears only for the zip and the silk drop.
