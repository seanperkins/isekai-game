"""Timed frames into the engine's clips. The engine (SlimeAnimator, data/enemy_clips.json) plays a clip as {"frames": [names], "fps": f,
"loop": bool} at one rate, so uneven timing is expressed by repeating a frame's name: the base rate is the shortest frame's length and every
frame is held a whole number of those. Pure Python.
"""


def clip(names, durations, loop, tolerance=0.12):
    """A clip from frame names and how long each lasts in seconds. Raises ValueError if the lengths are not (close to) whole multiples of the
    shortest, since the engine could not play them."""
    if len(names) != len(durations):
        raise ValueError("%d names but %d durations" % (len(names), len(durations)))
    tick = min(durations)
    frames = []
    for name, d in zip(names, durations):
        count = d / tick
        if abs(count - round(count)) > tolerance * max(1.0, round(count)):
            raise ValueError("frame %s lasts %.3f s, not a whole number of %.3f s" % (name, d, tick))
        frames += [name] * int(round(count))
    return {"frames": frames, "fps": 1.0 / tick, "loop": bool(loop)}


def table(creature, by_state):
    """{creature: {state: clip}} in the shape of data/enemy_clips.json, states in name order."""
    return {creature: {state: by_state[state] for state in sorted(by_state)}}


def on_grid(names, durations, loop, tick=0.02):
    """A clip from frame names and how long each lasts in seconds, on the engine's one rate: a frame is held by repeating its name. Each frame ends
    on the tick nearest where it should end in time (so the errors do not add up: a clip is as long as it should be to within half a tick, however
    many frames it has), and no frame is shorter than one tick. A pose that would fill none of a tick (a loop of poses shorter than the tick, a fast
    gallop) is left out of a loop, so the cycle is not stretched and the feet do not slide; an action keeps every pose, the first of a loop is always kept."""
    if len(names) != len(durations):
        raise ValueError("%d names but %d durations" % (len(names), len(durations)))
    frames, used, elapsed = [], 0, 0.0
    for name, d in zip(names, durations):
        elapsed += d
        count = int(round(elapsed / tick + 1e-9)) - used
        if count < 1 and not (loop and frames):
            count = 1
        count = max(count, 0)
        frames += [name] * count
        used += count
    return {"frames": frames, "fps": round(1.0 / tick, 6), "loop": bool(loop)}
