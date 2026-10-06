"""Follow-through for the things hung on a body (ears, a cap's tip, a cloak, a scarf, a pack, a tail): each chases the angle it would have if it
were rigid on a spring (anim.follow), so it trails the body. Pure Python; the creature modules own the tables that say which bones to treat so.

A table entry: `parents`, the chain of bones above whose angles it rides (or `after`, another entry whose followed angle it rides, for the
second link of a cloak or a tail); `bob`, how much the body's bounce shakes it (degrees per unit of height); `wind`, how far it is blown back
in a full walk (degrees); `k` and `c`, the spring's stiffness and damping.
"""
import anim


def abs_deg(rot, chain):
    """The absolute angle (degrees, forward positive) that a chain of bones' rotations add up to."""
    return -sum(rot.get(b, (0.0, 0.0, 0.0))[1] for b in chain)


def series(present, table, frames, wind, pre="", extra_chain=()):
    """Per frame, each hung thing's angle against the bone it hangs from. `present` is the set of bone names the rig has (the table's names with
    `pre` in front); `frames` is [(rot, root)] over a loop; `wind` scales every entry's wind (1 in a walk); `extra_chain` is bones of a mount."""
    n = len(frames)
    mean_z = sum(root[2] for _, root in frames) / n
    followed, out = {}, {}
    for name, cfg in table.items():
        if pre + name not in present:
            continue
        if "after" in cfg:
            parent = followed[cfg["after"]]
        else:
            chain = list(extra_chain) + [pre + b if b not in ("hips", "spine") or pre else b for b in cfg["parents"]]
            chain = [b for b in chain if b in present or b in extra_chain or b in ("hips", "spine", pre + "hips", pre + "spine")]
            parent = [abs_deg(rot, chain) for rot, _ in frames]
        driver = [pa + cfg["bob"] * (root[2] - mean_z) + wind * cfg["wind"] for pa, (_, root) in zip(parent, frames)]
        chased = anim.follow(driver, stiffness=cfg["k"], damping=cfg["c"])
        followed[name] = chased
        out[pre + name] = [c - pa for c, pa in zip(chased, parent)]
    return out
