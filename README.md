# Racing Dodgio

A top-down neon arcade racing game built in Godot 4.6 with GDScript.

## Overview

Racing Dodgio is a colorful top-down racer where you compete against 4 AI opponents across 5 closed-loop tracks. Collect cookies for speed boosts, dodge hazards, drift through corners, and race to the finish over 3 laps. Features a "Neon Arcade" visual style with a car select lobby, staggered starting grid, and cinematic finish sequence.

## Tech Stack

- **Engine:** Godot 4.6 (GDScript)
- **Physics:** Jolt Physics
- **Rendering:** Forward Plus (D3D12 on Windows)
- **Architecture:** Autoloads for GameData and Records, scene-based game states

## Prerequisites

- Godot 4.6+ (download from [godotengine.org](https://godotengine.org/))
- Windows 10/11 (D3D12 renderer configured; other platforms may need renderer adjustment)

## Running

1. Open the project in Godot 4.6:
   ```
   # Or from command line:
   "C:\Users\Rafa\AppData\Local\Programs\Godot\Godot_v4.6.1-stable_win64.exe" --editor --path .
   ```
2. Press **F5** to run the game

## Controls

| Key | Action |
|-----|--------|
| W / Up Arrow | Accelerate |
| S / Down Arrow | Brake / Reverse |
| A / Left Arrow | Turn left |
| D / Right Arrow | Turn right |
| Shift | Drift |

## Current Status

**Full game loop complete.** Main menu, car select, countdown, 3-lap racing, and results screen all working. "Neon Arcade" visual variant fully implemented. **22 improvement tasks** (rd-bug-01 through rd-hud-05) on the Mini-Me board in backlog.

## Completed Features

### Core Racing
- 3-lap closed-loop racing on 5 tracks
- Player car with acceleration, braking, and turning (HANDLING stat affects turn speed)
- 4 AI opponents using PathFollow2D with lap tracking
- Finish-line detection with anti-cheat (direction check, 70% minimum progress, cooldown)
- Lap-aware placement calculation with force-finish sorting
- Race timeout at 300 seconds

### Visual Style (Neon Arcade)
- Car select lobby with character stats (Speed, Boost, Handling)
- F1-style staggered starting grid (pole center, alternating left/right rows)
- Phase-synced curb stripes with multi-point subdivision and per-point normals
- Neon cyan gate curbs at start/finish line
- Cinematic finish sequence
- Cookie collectibles with Griddy dance celebration animation

### Gameplay Mechanics
- Cookie speed boost (5-second duration)
- Hazard blocks (stun on collision, clears active boost)
- Star pickups
- Obstacles and boosters with random lateral positioning across road width
- Minimap display

### Polish
- HUD with lap counter, position display, speed indicator
- Circuit standings tracking
- Results screen with race summary
- All 10 UX/UI backlog items completed

## What's Next

22 improvement tasks tracked on the Mini-Me board:

**P1 (10 tasks):** Grid fix, curb fix, drift boost, rubberband AI, speed trail, star particles, camera zoom, engine sound, crash sounds, countdown beeps.

**P2 (11 tasks):** Track themes, perfect start, lap flash, camera shake, shield pickup, gap display, lap animation, scenery, road glow, collect chime, music.

**P3 (5 tasks):** Shortcuts, arc speedometer, minimap arrows, crowd markers, boost label.

## Project Structure

```
racing-dodgio/
  project.godot            -- Godot project file
  main_menu.gd / .tscn     -- Main menu scene with car select
  main.tscn                -- Race scene
  race_manager.gd          -- Race lifecycle (countdown, laps, finish)
  player_car.gd            -- Player car controller
  ai_car.gd                -- AI car (PathFollow2D)
  car_visual.gd            -- Car sprite rendering
  game_data.gd             -- Autoload: shared game state (selected car, track, stats)
  records.gd               -- Autoload: race records persistence
  results.gd / .tscn       -- Results screen
  circuit_standings.gd     -- Circuit standings tracking
  minimap.gd               -- Minimap display
  hazard_block.gd          -- Hazard obstacle
  star_pickup.gd           -- Star collectible
  collect_burst.gd         -- Collection particle effect
  griddy_figure.gd         -- Griddy dance animation
  sprite_2d.gd             -- Sprite helper
  audio/                   -- Sound effects
  tests/                   -- GDScript + Python test files
```

## Running Tests

Python tests (for logic validation):
```bash
python -m pytest tests/ -v
```

GDScript tests are in `tests/test_*.gd` and can be run within the Godot editor.

## License

All rights reserved.
