"""The photo stage: the one camera and scale every render goes through, so a sprite is made the same way every time. Pure Python.

The camera is side-on and orthographic: it sits in front of the subject at -Y and looks along +Y, X is right, Z is up, and a creature faces +X
(rigkit.py's convention). A canvas of `canvas` game pixels covers `canvas / ppu` units, so one game pixel is 1 / ppu units on the stage. The movement
review (stage_review.py) builds the game's own course on the same stage, with the same camera, so what is judged there is what gets baked.
"""

CAMERA = {"axis": "Y", "y_distance": 20.0}  # in front of the subject, looking along +Y
GRID_PX = 16  # the stage's grid step, in game pixels (the editor's cell size is 16 as well)


def px_to_units(px, ppu):
    """A length in game pixels as stage units, at `ppu` pixels per unit."""
    return px / ppu


def game_to_stage(point, ppu):
    """A game point (x right, y DOWN, the movement course's convention) as stage (x, z): x right, z up."""
    return (px_to_units(point[0], ppu), px_to_units(-point[1], ppu))


def camera_params(canvas, ppu, margin, supersample, center_x=0.0):
    """What the camera is set to: the ortho scale, its place (looking along +Y, the ground `margin` pixels above the bottom of the frame), its
    rotation in degrees and the render's side in pixels."""
    return {
        "ortho_scale": canvas / ppu,
        "location": (center_x, -CAMERA["y_distance"], canvas / (2.0 * ppu) - margin / ppu),
        "rotation_deg": (90.0, 0.0, 0.0),
        "resolution": canvas * supersample,
    }


def tracking_camera_params(view_w_px, ppu, center_x, center_z):
    """A camera that follows a body for the movement review: the same side-on ortho camera, `view_w_px` game pixels wide, centred on (center_x, center_z) in units."""
    return {
        "ortho_scale": view_w_px / ppu,
        "location": (center_x, -CAMERA["y_distance"], center_z),
        "rotation_deg": (90.0, 0.0, 0.0),
    }
