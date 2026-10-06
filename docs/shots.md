# Shot tools

The scripts under `tools/` that capture the real game (`*_shots.gd`, `shoot_*.gd`, `enemy_in_game.gd`, `slime_in_game.gd`,
`moveset_gifs.gd`) need a renderer, and Godot cannot render headless (its `--headless` driver is the dummy one, so a texture reads
back empty). `tools/shot_run.sh` runs any of them without taking over the screen or making a sound:

```
tools/shot_run.sh tools/room_shots.gd -- C1 300,180 1000,180
tools/shot_run.sh tools/evolution_shots.gd
SHOT_HOME="$PWD/.tmp/editor-home" tools/shot_run.sh tools/editor_shots.gd
tools/menagerie_shots.sh 1000 4400          # frames of the Menagerie room at those positions
tools/creature_sheet.sh                      # one contact sheet of every creature, named, at .tmp/creature-sheet/sheet.png
```

What it does:

- **A tiny window.** The game starts fullscreen (`display/window/size/mode=3`), which takes over a Space on macOS and ignores
  `--windowed` and `--position`. The run uses a throwaway project of symlinks to the real one with a rewritten `project.godot`
  (`tools/shot_project.py`): a 32x18 borderless window that cannot take focus. The real `project.godot` is never touched.
- **A stage.** A tool mounts its game on a `ShotStage` (`tools/shot_stage.gd`), a SubViewport of the frame size (1280x720 by default,
  the game drawn at twice its 640x360), and saves `view.get_texture()` where it used to save the root's. Input events pushed to the
  root do not reach a stage: a tool that sends mouse events pushes them to `view`, and none may warp the real cursor. The stage also
  marks the opening seen in memory, so a fresh profile does not play it over every frame.
- **No sound.** `--audio-driver Dummy`; `SHOT_AUDIO=1` leaves it on.
- **Focus.** If Godot takes focus, the app you were in gets it back, by process id through System Events. Never by app name with
  `tell application "..." to activate`: that launches whatever app has the name, and two builds of one terminal shared one.
- **A check.** The run fails with a warning if the window was not a tiny windowed one (a tool that did not use `ShotStage`).

Environment: `GODOT` (the binary), `SHOT_HOME` (HOME for the run, default `.tmp/gdhome`), `SHOT_GODOT_ARGS` (extra flags, e.g.
`--fixed-fps 60`), `SHOT_DIR` (where the project copy and log go), `SHOT_AUDIO`. Written and tested on macOS. It needs a display, so
run it unsandboxed. The room MCP's `menagerie_shot` tool uses it too.

A new shot tool: `view = ShotStage.mount(root, game)`, save `view.get_texture().get_image()`, and run it with `tools/shot_run.sh`.
