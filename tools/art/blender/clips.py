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
