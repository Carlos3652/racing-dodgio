# Racing Dodgio — Full UI/UX Audit
**Date:** 2026-02-28
**Auditor:** UIUXVisionary
**Build inspected:** Godot 4.6 / GDScript — main.tscn, main_menu.tscn, results.tscn

---

## Table of Contents
1. Executive Summary
2. Screen-by-Screen Wireframe Mockups (A / B variants)
3. User Flow Map (happy path + error/edge states)
4. Specific UX Issues — Annotated
5. Prioritized Improvement List
6. Visual Design Recommendations (Godot built-in nodes only)
7. Game Feel Guidance
8. Accessibility Notes

---

## 1. Executive Summary

Racing Dodgio has a clean, functional foundation: a working race loop, respawning obstacles, HUD labels, and a results screen. However, the current design leaves significant player experience value on the table across three vectors:

**Feedback vacuum** — The player receives almost no audio-visual confirmation that their actions are working (boost activation, crash penalty, position change, crossing finish line). Arcade racers live and die on input feedback.

**Information hierarchy** — The HUD stacks three labels with no visual containment, making them hard to scan while driving. Position ("2nd") is the most critical race information and should be the largest, most immediate element — it is currently rendered at 40pt with no background, competing with the road visuals.

**Screen polish gap** — The Main Menu and Results Screen are functional but visually sparse. Both use raw Labels on a solid background with no depth, motion, or brand identity. The "RACING DODGIO" title at 56pt on a flat navy rectangle is not doing enough to convey the energy of the game.

---

## 2. Screen-by-Screen Wireframe Mockups

### Screen 1 — Main Menu

#### Variant A: "Clean Arcade" (Recommended for this audience)

```
┌──────────────────────────────────────────────────┐
│  Background: Dark navy #13132E                   │
│                                                  │
│  [subtle decorative road stripe — ColorRect,     │
│   angled ~15 deg, gray #2A2A2A, 20px wide,       │
│   opacity 0.3, repeating across full screen]     │
│                                                  │
│                                                  │
│         ╔════════════════════════╗               │
│         ║  RACING DODGIO         ║  56pt Yellow  │
│         ║  ─────────────────     ║  #FFD91A      │
│         ║  Overland Park, KS     ║  22pt Gray    │
│         ║                        ║  #AAAAAA      │
│         ╚════════════════════════╝               │
│                                                  │
│              [  START RACE  ]                    │
│         Button: 280x64px, yellow fill #FFD91A    │
│         text: navy #13132E, 28pt, BOLD           │
│         hover: scale 1.03, border glow #FFFFFF   │
│         focus: solid 3px white border            │
│                                                  │
│    Arrow keys to drive  |  ESC to quit race      │
│    16pt, #666666                                 │
│                                                  │
│    ────────────────────────────────────────      │
│    Tip: Collect cookies for a speed boost!       │
│    14pt, #888888, italic                         │
│                                                  │
└──────────────────────────────────────────────────┘

Spacing:
  Title block top edge: 38% from top (y = ~380 / 1080 or proportional)
  Gap title → button: 40px
  Gap button → controls hint: 24px
  Gap hint → tip: 16px
```

Changes from current:
- Add diagonal road stripe background decoration (ColorRect nodes, angled transform)
- Add a thin 2px border rule under the title using another ColorRect
- Change button to FILLED yellow with dark text (current: outline style, low contrast)
- Add a rotating "gameplay tip" label at the bottom
- Add focus ring to button for keyboard navigation

#### Variant B: "Speedometer Splash"

```
┌──────────────────────────────────────────────────┐
│  Background gradient: #0D0D2B → #1A1A3A (top→btm)│
│  [Achieved with two overlapping ColorRects,      │
│   top half and bottom half, alpha blended]       │
│                                                  │
│  TOP BAR ─────────────────────────────────────   │
│  [ColorRect #1C1C3C, full width, 8px tall]       │
│  [Line2D yellow #FFD91A across full width, 2px]  │
│                                                  │
│                                                  │
│        ┌──────────────────────────────┐          │
│        │  RACING                      │  72pt    │
│        │  DODGIO                      │  Yellow  │
│        │                              │  #FFD91A │
│        │  ─── Overland Park, KS ───   │  20pt    │
│        └──────────────────────────────┘          │
│                                                  │
│         [  START RACE  ]   ← 300x70px button     │
│          Yellow outline, white text, 30pt        │
│          hover: fill yellow, text turns navy     │
│                                                  │
│   [WASD / Arrow keys]        [ESC = quit]        │
│   18pt icons left-aligned    18pt right-aligned  │
│                                                  │
│  BOTTOM BAR ──────────────────────────────────   │
│  [Line2D yellow, full width, 2px]                │
│                                                  │
└──────────────────────────────────────────────────┘
```

Pros of B: More dramatic, title takes up more visual real estate, bookend lines give structure.
Cons of B: Multi-line title requires more vertical space, harder to implement cleanly without custom font.
Best for: If a pixel/retro font is added later.

---

### Screen 2 — Race HUD

#### Variant A: "Panel HUD" (Recommended)

```
┌──────────────────────────────────────────────────────────┐
│ [TOP-LEFT PANEL]                    [TOP-RIGHT]          │
│ ┌────────────────────┐              ESC — Menu  (18pt)  │
│ │ ColorRect #00000099│              #555555              │
│ │ rounded 8px        │                                   │
│ │ padding 10px       │                                   │
│ │                    │                                   │
│ │  2nd               │  ← 48pt, WHITE, BOLD             │
│ │  0:45.23           │  ← 26pt, #CCCCCC                 │
│ │  38 km/h           │  ← 22pt, #7DEB7D (green)        │
│ └────────────────────┘                                   │
│                                                          │
│                                                          │
│            [COUNTDOWN: CENTER OF SCREEN]                 │
│                                                          │
│              ┌──────────────┐                           │
│              │    3         │  96pt Yellow #FFD91A       │
│              │ ColorRect bg │  semi-opaque black         │
│              │  200x120px   │  #00000088                 │
│              └──────────────┘                           │
│                                                          │
│            [BOOST ACTIVE: shown below countdown zone]    │
│            ┌─────────────────────────────────┐          │
│            │  BOOST  [████████████░░░] 4.2s  │          │
│            │  ColorRect yellow fill, 8px tall │          │
│            │  width animates from 100% → 0%  │          │
│            └─────────────────────────────────┘          │
│                                                          │
│            [CRASH INDICATOR: replaces boost bar]         │
│            ┌─────────────────────────────────┐          │
│            │  STUNNED  [██████░░░░░░░] 1.3s  │          │
│            │  ColorRect RED fill #FF4444       │         │
│            └─────────────────────────────────┘          │
└──────────────────────────────────────────────────────────┘

HUD Panel specs:
  - HUDPanel: PanelContainer, anchored top-left, 20px from edges
  - background: StyleBoxFlat, bg_color #000000 at alpha 0.60
  - corner_radius: 8px all corners
  - content_margin: 10px all sides
  - VBoxContainer inside with separation = 6

Position label:  font_size 48, bold, white
Timer label:     font_size 26, color #CCCCCC
Speed label:     font_size 22, color #7DEB7D

Boost/Crash bar:
  - Parent: CenterContainer anchored to bottom_center, y = 80% of screen
  - HBoxContainer: [Label "BOOST" 14pt yellow] [ProgressBar width=200px]
  - ProgressBar fill color = #FFD91A (boost) or #FF4444 (crash)
  - Visible only when boost_time > 0 or crash_time > 0
```

#### Variant B: "Minimal Corner Tags"

```
┌──────────────────────────────────────────────────────────┐
│                                                          │
│  2nd                               ESC — Menu           │
│  ↑ 40pt, white, NO background      ↑ 18pt, #555555      │
│    drop shadow only                                      │
│                                                          │
│  0:45.23                                                 │
│  ↑ 24pt, #CCCCCC                                        │
│                                                          │
│  38 km/h                                                 │
│  ↑ 20pt, #7DEB7D                                        │
│                                                          │
│  [This is essentially the current layout — kept as-is   │
│   but with drop shadows added via custom StyleBox]      │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

Pros of B: Zero implementation work, least visual noise.
Cons of B: Labels get lost against the road/grass colors; no feedback for boost/crash state.
Best for: Prototype only. Not recommended for shipped build.

---

### Screen 3 — Results Screen

#### Variant A: "Podium Card" (Recommended)

```
┌──────────────────────────────────────────────────┐
│  Background: #0D0D2B                             │
│                                                  │
│  RACE RESULTS                                    │
│  52pt Yellow #FFD91A, centered, y=40             │
│  [2px ColorRect separator below title, yellow]   │
│                                                  │
│  ┌────────────────────────────────────────────┐  │
│  │ TOP-3 CARDS — HBoxContainer, centered      │  │
│  │                                            │  │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐  │  │
│  │  │ GOLD     │ │ SILVER   │ │ BRONZE   │  │  │
│  │  │ #3D2E00  │ │ #1E1E2E  │ │ #2E1A00  │  │  │
│  │  │ bg fill  │ │ bg fill  │ │ bg fill  │  │  │
│  │  │          │ │          │ │          │  │  │
│  │  │  1st     │ │  2nd     │ │  3rd     │  │  │
│  │  │  [car]   │ │  [car]   │ │  [car]   │  │  │
│  │  │  name    │ │  name    │ │  name    │  │  │
│  │  │  0:32.11 │ │  0:33.45 │ │  0:35.80 │  │  │
│  │  └──────────┘ └──────────┘ └──────────┘  │  │
│  │   Card: 160x180px PanelContainer          │  │
│  │   border: 2px top = medal color           │  │
│  └────────────────────────────────────────────┘  │
│                                                  │
│  ┌────────────────────────────────────────────┐  │
│  │ 4th  Blue      —  Better Luck Next Time!   │  │
│  │ 5th  Orange    —  Better Luck Next Time!   │  │
│  │ Font: 20pt, #777777                        │  │
│  └────────────────────────────────────────────┘  │
│                                                  │
│     [  RACE AGAIN  ]        [  MAIN MENU  ]      │
│      yellow fill, 180x56     outline, 180x56     │
│      primary action          secondary action    │
│                                                  │
└──────────────────────────────────────────────────┘

Card color tokens:
  Gold card bg:   #3D2E00,  border top: #FFD91A
  Silver card bg: #1E1E2E,  border top: #C0C0C0
  Bronze card bg: #2E1A00,  border top: #CD7F32

Place text:     28pt, medal color (gold/silver/bronze)
Car name:       22pt, white
Time:           18pt, #AAAAAA
```

#### Variant B: "Leaderboard List"

```
┌──────────────────────────────────────────────────┐
│  RACE RESULTS        52pt Yellow, centered       │
│  ─────────────────────────────────────────────   │
│                                                  │
│  1st   You        0:31.44   [WINNER!]            │
│  ──────────────── gold #FFD91A ──────────────    │
│  2nd   Blue       0:33.10                        │
│  ──────────────── silver #C0C0C0 ────────────    │
│  3rd   Green      0:35.80                        │
│  ──────────────── bronze #CD7F32 ────────────    │
│  4th   Orange     0:37.22   Better Luck!         │
│  5th   Purple     0:40.01   Better Luck!         │
│                                                  │
│  Row height: 52px, alternating bg #0F0F22/#13132E│
│  Left-pad: 24px, divider line 1px #222244        │
│                                                  │
│     [  RACE AGAIN  ]        [  MAIN MENU  ]      │
└──────────────────────────────────────────────────┘
```

Pros of B: Simpler implementation, scales well if more cars added, consistent with the current GDScript approach.
Cons of B: Less visual drama, podium structure is more satisfying as a reward moment.
Best for: Quickest path to a polished-feeling results screen with minimal node changes.

---

## 3. User Flow Map

```
[LAUNCH]
   │
   ▼
[MAIN MENU]
   │  START RACE pressed (or Enter key)
   │  → GameData.clear()
   ▼
[RACE SCENE loads]
   │
   ▼
[COUNTDOWN: 3 → 2 → 1 → GO!]
   │  is_racing = false during countdown
   │  player input blocked
   ▼
[RACING STATE]
   │
   ├──► [Cookie collected]
   │        → boost_time = 5.0
   │        → Griddy animation plays
   │        → Cookie hidden, respawns in 10s
   │        → [MISSING: visual/audio feedback to player]
   │
   ├──► [Jeep hit]
   │        → crash_time = 2.0, speed = 0
   │        → input blocked for 2s
   │        → Jeep hidden, respawns in 14s
   │        → [MISSING: camera shake, red flash, crash sound]
   │
   ├──► [Player crosses FINISH]
   │        → has_finished = true, emits finished("You")
   │        → race continues for other cars
   │        → [MISSING: player celebration, speed lock, any feedback]
   │
   ├──► [ESC pressed]
   │        → immediate scene change to main_menu.tscn
   │        → [MISSING: confirmation dialog — accidental ESC mid-race]
   │
   └──► [All 5 cars finished]
            → 2s wait
            → change_scene_to results.tscn
            → [MISSING: transition animation]

[RESULTS SCREEN]
   │
   ├──► [RACE AGAIN] → GameData.clear() → main.tscn
   │
   └──► [MAIN MENU]  → main_menu.tscn

ERROR / EDGE STATES CURRENTLY UNHANDLED:
  - Player presses ESC during countdown → exits immediately (no confirmation)
  - Player finishes but no feedback until ALL cars finish (could be 10-20 seconds of dead time)
  - If all AI cars somehow never reach progress_ratio >= 0.99 → race never ends (soft lock)
  - results.tscn with empty GameData.finish_order → renders blank VBox
  - No "You didn't place" path — player is always listed in finish_order
```

---

## 4. Specific UX Issues — Annotated

### Issue 1 — CRITICAL: No Feedback on Boost Activation
**Where:** player_car.gd `apply_boost()`, race_manager.gd `_check_player_collisions()`
**Problem:** Cookie collection triggers a 5-second boost, but the only visual change is the Griddy Kid animation playing at `position = Vector2(0, -300)` relative to the car. This puts Griddy 300 units above the car in world space — during active driving, the camera follows the car, so Griddy appears in a different screen zone each frame. The player may not notice the boost activated at all.
**Fix:** Add a HUD boost bar (see Variant A wireframe) that shows countdown. Even a simple Label "BOOST ACTIVE" that fades in/out would be a major improvement. Godot's `Tween` on a ColorRect opacity is zero-effort.

### Issue 2 — CRITICAL: No Feedback on Crash
**Where:** player_car.gd `apply_crash()`
**Problem:** When a Jeep hits the player, speed is zeroed and input is locked for 2 seconds. There is no visual signal to the player that this happened — no flash, no screen shake, no HUD message. The car simply stops. Players unfamiliar with the mechanic will assume it is a bug.
**Fix (Godot built-in only):**
  - Flash the screen red: full-screen ColorRect in HUD CanvasLayer, alpha 0 normally, tween to 0.5 alpha for 0.1s then back to 0
  - Show "CRASH!" Label in HUD center, fade out over 1.5s using Tween
  - Camera shake: modify Camera2D offset with a sin wave (no external assets needed)

### Issue 3 — HIGH: HUD Labels Have No Legibility Backing
**Where:** main.tscn, HUD/PositionLabel, HUD/TimerLabel, HUD/SpeedLabel
**Problem:** All three labels are plain Labels with no background. When the road (gray), grass, or a yellow center line appears behind the text, contrast degrades. The EscHint at #555555 on a dark navy menu is fine, but during racing on a varied road/grass background, it can drop below WCAG AA (4.5:1).
**Fix:** Wrap HUD labels in a PanelContainer with StyleBoxFlat, `bg_color = Color(0,0,0,0.6)`, `corner_radius_all = 8`. This is achievable entirely in Godot scene nodes.

### Issue 4 — HIGH: Position Display Missing Suffix Readability
**Where:** race_manager.gd `_update_hud()`
**Problem:** The ordinal suffix array `["", "st", "nd", "rd", "th", "th"]` uses index 0 for place 0 (which should never happen) and place 5 maps to index 5 ("th") correctly. However, the place text "2nd" at 40pt with no visual weight differentiation between place and suffix is harder to scan at a glance. During a race, the player glances for ~150ms at the HUD.
**Fix:** Display the number at 48pt bold and the suffix at 28pt — stack them or use RichTextLabel `[b]2[/b][font_size=28]nd[/font_size]`. This is the convention used in Mario Kart and F-Zero for good reason.

### Issue 5 — HIGH: ESC Exits Without Confirmation
**Where:** player_car.gd `_process()`, line `get_tree().change_scene_to_file("res://main_menu.tscn")`
**Problem:** A single ESC key press immediately abandons the race with no confirmation. On keyboards where ESC is near function keys or arrow keys, this is an accidental exit risk. For a family game played by a child, this is high-severity frustration.
**Fix:** Show a centered PanelContainer overlay: "Quit race? [YES] [NO]". Pause the game tree while shown. Input focus goes to [NO] by default (safest option as default). This is entirely doable with Godot CanvasLayer + Control nodes.

### Issue 6 — HIGH: Griddy Kid Spawns Above Car, Not on Screen
**Where:** main.tscn, GriddyKid node `position = Vector2(0, -300)`
**Problem:** GriddyKid is a child of PlayerCar at world-space offset (0, -300). At Camera2D zoom 0.55, 300 world units is ~165 screen pixels above the car. In a top-down view, the player's car is typically near screen center, so GriddyKid appears in the upper-center of the screen — which is actually acceptable. However, at some road angles, the car rotates and "above" in world space is not "above" on screen. The animation likely looks correct only when the car faces up.
**Fix UX side:** Attach GriddyKid to the HUD CanvasLayer instead of PlayerCar. Pin it to bottom-center of the screen. This guarantees it is always in the same place, always visible, always correctly oriented. Size: 120x120px area, 6-frame animation.

### Issue 7 — MEDIUM: Results Screen Uses Emoji Trophies (Platform Risk)
**Where:** results.gd, TROPHIES constant
**Problem:** `["🥇", "🥈", "🥉"]` renders correctly on Windows 11 if the system emoji font is available. However, Godot's default font does not include emoji glyphs. These will likely render as blank rectangles unless a system font with emoji support is explicitly set. Testing on a different machine or build configuration could break this.
**Fix:** Replace emoji with text tags: "GOLD", "SILVER", "BRONZE" in medal colors, or use ColorRect blocks (16x16px) as visual indicators instead of emoji characters.

### Issue 8 — MEDIUM: Results Screen ScrollContainer Is Premature
**Where:** results.tscn, ScrollContainer height 430-130=300px for 5 entries
**Problem:** With exactly 5 cars and 5 result rows at 30pt font (~40px per row), the total content height is ~220px. The scroll container is 300px tall, so scrolling never actually triggers. The ScrollContainer adds unnecessary complexity (and its default scrollbar styling may look mismatched) without serving any function.
**Fix:** Replace ScrollContainer with a plain VBoxContainer for the current 5-car design. If you expand to more cars later, reintroduce the ScrollContainer.

### Issue 9 — MEDIUM: Main Menu Button Styling
**Where:** main_menu.tscn, StartButton
**Problem:** The StartButton uses Godot's default Button theme — gray background, dark text. Against the dark navy background, it does not read as the primary CTA. It blends into the theme as a neutral element rather than a prominent call to action.
**Fix:** Apply a custom StyleBoxFlat as the button's Normal style: `bg_color = #FFD91A`, `corner_radius_all = 6`, `border_color = #FFD91A`. Set the font color override to `#13132E` (dark navy). This makes it visually pop as the primary action. For Hover: `bg_color = #FFF176`, `expand_margin_all = 2`.

### Issue 10 — MEDIUM: No Finish Feedback for Player
**Where:** player_car.gd `_cross_finish()`, race_manager.gd `_on_car_finished()`
**Problem:** When the player crosses the finish line, speed is set to 0, `finished.emit("You")` fires, and then the game silently waits for all AI cars to finish (potentially 10-30 seconds). The player has no indication that they finished — no message, no HUD change, no fanfare.
**Fix (HUD-only approach):** When player finishes, show a centered HUD Label "RACE COMPLETE — [1st PLACE]!" for the duration of the wait, and replace the race timer with a static display. Show the final place clearly.

### Issue 11 — LOW: Speed Conversion Is Misleading
**Where:** player_car.gd `get_speed_kmh()`, returns `int(abs(speed) * 0.05)`
**Problem:** MAX_SPEED is 350 px/s. At that speed: 350 * 0.05 = 17.5 km/h. BOOST_SPEED is 500 px/s → 25 km/h. The HUD description says the car does "38 km/h" in the spec but the math doesn't support that. The multiplier feels arbitrary.
**UX Impact:** Minor — but if the player sees "17 km/h" on a racing game, it feels slow. Consider multiplying by 0.3 to get 350 * 0.3 = 105 km/h at full speed, which feels like an actual road race.

### Issue 12 — LOW: No Visual START / FINISH Gate
**Where:** race_manager.gd `_add_marker()`
**Problem:** Start and Finish are marked by floating Label nodes in world space at small 26pt text. These labels float in world space with no visual structure, making them easy to miss or confuse with other labels.
**Fix:** For each marker, draw a Line2D perpendicular to the road direction at that waypoint, colored green (START) and checkered-pattern alternating (FINISH). Width = ROAD_WIDTH (90px). This uses no external assets.

---

## 5. Prioritized Improvement List

### Priority 1 — CRITICAL (player will be confused without these)
| # | Item | Godot Node Approach | Effort |
|---|------|---------------------|--------|
| C1 | Crash feedback: red screen flash + "CRASH!" HUD label | CanvasLayer ColorRect tween + Label | 1 hour |
| C2 | Boost feedback: HUD boost bar with countdown | ProgressBar or ColorRect width tween | 1 hour |
| C3 | Player finish feedback: HUD "RACE COMPLETE!" overlay | Label in CanvasLayer, shown on finish | 30 min |
| C4 | HUD label legibility: add semi-opaque dark panel behind all HUD elements | PanelContainer + StyleBoxFlat | 30 min |

### Priority 2 — HIGH (noticeably degrades experience)
| # | Item | Godot Node Approach | Effort |
|---|------|---------------------|--------|
| H1 | ESC confirmation dialog | CanvasLayer + PanelContainer, set_process_input pause | 2 hours |
| H2 | Griddy Kid moved to HUD CanvasLayer | Reparent node, adjust position to HUD coordinates | 1 hour |
| H3 | Results screen emoji → text labels | Edit results.gd TROPHIES constant | 15 min |
| H4 | Button styling: filled yellow primary CTA | StyleBoxFlat on StartButton + both results buttons | 45 min |
| H5 | Main menu tip text: add gameplay tip | Label node in VBox, italic, rotating tips optional | 20 min |

### Priority 3 — MEDIUM (polish and clarity improvements)
| # | Item | Godot Node Approach | Effort |
|---|------|---------------------|--------|
| M1 | Results: remove ScrollContainer, use plain VBoxContainer | Edit results.tscn | 15 min |
| M2 | Results: podium card layout (top 3 side-by-side) | HBoxContainer with PanelContainer cards | 2 hours |
| M3 | START/FINISH gate lines perpendicular to road | Line2D nodes added programmatically | 1 hour |
| M4 | Speed multiplier adjusted to realistic km/h | Edit player_car.gd get_speed_kmh() | 5 min |
| M5 | Place label: large number + small suffix | RichTextLabel with BBCode | 30 min |

### Priority 4 — NICE TO HAVE (juice and delight)
| # | Item | Godot Node Approach | Effort |
|---|------|---------------------|--------|
| N1 | Road stripe background decoration on Main Menu | ColorRect array, rotated | 30 min |
| N2 | Countdown scale animation (3 grows in, then shrinks out) | Tween on scale | 30 min |
| N3 | Scene transition: brief fade-to-black between screens | CanvasLayer ColorRect alpha tween | 1 hour |
| N4 | Cookie sparkle: brief ColorRect flash at pickup location | Tween scale + alpha | 30 min |
| N5 | Camera shake on crash | Tween on Camera2D offset with sin oscillation | 45 min |
| N6 | Results screen: animate each row sliding in from left | Tween on offset_left per row | 1 hour |

---

## 6. Visual Design Recommendations (Godot Built-In Nodes Only)

### Color System

```
Background (menus):   #0D0D2B   (deep navy)
Background (results): #0D0D2B   (match for consistency)
Road asphalt:         #616161   (current #606060, fine)
Center line:          #F2E61A   (current, fine)
Grass:                Implied by background camera area

Primary Yellow:   #FFD91A   — title, primary buttons, countdown, gold place
White:            #FFFFFF   — position label, car name in results
Light Gray:       #CCCCCC   — timer, secondary info
Muted Gray:       #888888   — hints, tips, ESC label
Green:            #7DEB7D   — speed label (keep, good color coding)
Boost bar:        #FFD91A   — matches yellow brand
Crash bar:        #FF4444   — urgent red
Gold card:        #3D2E00 bg / #FFD91A border
Silver card:      #202035 bg / #C0C0C0 border
Bronze card:      #2E1A06 bg / #CD7F32 border
```

### Typography Scale

```
Title (menu):       56pt, bold uppercase, Yellow #FFD91A
Subtitle (menu):    22pt, regular, Gray #AAAAAA
Button primary:     28pt, bold, Navy #0D0D2B on Yellow
Button secondary:   22pt, regular, White on transparent
HUD position:       48pt, bold, White (increase from current 40)
HUD timer:          26pt, regular, #CCCCCC (decrease from current 28, fits panel)
HUD speed:          22pt, regular, #7DEB7D (decrease from current 24)
HUD hint:           18pt, regular, #555555
Countdown:          96pt, bold, Yellow (current, correct)
Results title:      52pt, bold, Yellow (current, correct)
Results place:      28pt, bold, medal color
Results name:       22pt, regular, White
Results time:       18pt, regular, #AAAAAA
Results miss:       20pt, regular, #777777
Tip text:           14pt, italic, #888888
```

### Spacing System (8px grid)

```
Screen edge margin:  20px (current, fine)
VBox separation:     20px (menu), 16px (results) — current, fine
Panel padding:       10px all sides (new)
Button min-height:   56px (current 60px — acceptable, slightly generous)
Button min-width:    260px (menu), 180px (results) — current, fine
Card min-width:      160px, min-height 180px (new for podium variant)
```

### Godot Node Recipes

**Semi-opaque HUD panel:**
```
PanelContainer
  └ StyleBoxFlat:
      bg_color: Color(0, 0, 0, 0.6)
      corner_radius_top_left: 8
      corner_radius_top_right: 8
      corner_radius_bottom_left: 8
      corner_radius_bottom_right: 8
      content_margin_left: 10
      content_margin_right: 10
      content_margin_top: 8
      content_margin_bottom: 8
```

**Primary yellow button:**
```
Button
  └ Normal StyleBoxFlat:
      bg_color: #FFD91A
      corner_radius_all: 6
      border_width_all: 0
  └ Hover StyleBoxFlat:
      bg_color: #FFF176
      expand_margin_all: 2
  └ Pressed StyleBoxFlat:
      bg_color: #E6C200
  └ Font color override: #0D0D2B
  └ Font size override: 28
```

**Red screen flash (crash feedback):**
```
CanvasLayer (in HUD)
  └ ColorRect (FlashRect)
      anchor: full screen (0,0 → 1,1)
      color: Color(1, 0, 0, 0)  ← starts invisible
      mouse_filter: IGNORE
      [Tween in GDScript: flash to alpha 0.45, then back to 0 over 0.3s]
```

**Boost progress bar:**
```
CanvasLayer (HUD)
  └ VBoxContainer (BoostBar), anchor: bottom_center, y offset -80
      └ Label ("BOOST") — 14pt Yellow, hidden when inactive
      └ ProgressBar
            custom_minimum_size: Vector2(200, 10)
            fill_mode: LEFT_TO_RIGHT
            [override fill color via StyleBoxFlat on "fill" theme item]
            value: set to (boost_time / 5.0) * 100 every frame
```

---

## 7. Game Feel Guidance

### Countdown Sequence
**Current:** Numbers appear instantly, "GO!" holds for 0.6s, then disappears.
**Recommended:** Each number should:
1. Scale from 2.5x to 1.0x over 0.25s (Tween, EASE_OUT)
2. Hold at 1.0x for 0.65s
3. Fade out (alpha 1 → 0) over 0.1s
"GO!" should scale from 1.0x to 1.4x over 0.3s while fading out — explosive energy.
All achievable with Godot's Tween and `pivot_offset` set to center of the Label.

### Boost Collection Moment
**Target feeling:** "Oh yeah, I'm flying now."
**What to do:**
- Frame 0 (cookie contact): Flash cookie location with a white ColorRect circle, scale 0 → 1.5, alpha 1 → 0 over 0.15s
- Frame 0: HUD boost bar snaps to 100% and pulses yellow once (scale 1.0 → 1.05 → 1.0 over 0.2s)
- Frame 0: Griddy Kid appears in HUD (not world space) for 2 seconds
- Frames 1-300: Car moves noticeably faster (already coded — boost_time drives it)
- During boost: Speed label turns brighter (#B0FFB0 instead of #7DEB7D) — subtle cue

### Crash Moment
**Target feeling:** "Oof, that hurt, but I can recover."
**What to do:**
- Frame 0: Screen flash red (ColorRect tween, 0.3s total)
- Frame 0: "CRASH!" Label appears center-HUD, 48pt red, fades out over 1.5s
- Frames 1-60 (1s): Camera2D offset oscillates ±8px on X axis (sin wave, dampen over time)
- Frame 120 (2s): Input re-enables, HUD crash timer reaches 0, bar disappears

### Finish Line Crossing
**Target feeling:** "I DID IT." or "Ugh, 3rd again."
**What to do:**
- Player crosses finish: HUD position label stops updating
- Show "FINISHED — [PLACE]!" full-width banner for the wait period
- If player is 1st: banner is gold #FFD91A
- If player is 2nd/3rd: banner is silver/bronze
- If player is 4th/5th: banner is gray "FINISHED — 4th place"
- After all cars finish: 2s wait (current) → fade to black (1s) → results scene

### Scene Transitions
**Current:** Instant scene change (jarring).
**Recommended:** Fade to black over 0.5s before scene change, fade from black over 0.5s after load.
Implementation: AnimationPlayer on a full-screen CanvasLayer ColorRect. Simple 2-keyframe animation on `color.a`. Call before every `change_scene_to_file()`.

### AI Car Personality
**Current:** AI uses PathFollow2D with speed noise. Functionally fine.
**Suggestion (no code change needed):** Give each AI car a distinct name visible on screen at start of race (brief 2s overlay listing all racers). "You vs Blue, Green, Orange, Purple — RACE!" This makes the AI feel like opponents, not obstacles.

---

## 8. Accessibility Notes

### Contrast Ratios (current state)

| Element | Foreground | Background | Ratio | WCAG AA Pass? |
|---------|-----------|-----------|-------|---------------|
| Title "RACING DODGIO" | #FFD91A | #13132E | ~13.1:1 | PASS |
| Subtitle "Overland Park, KS" | #CCCCCC | #13132E | ~9.8:1 | PASS |
| Controls hint | #999999 | #13132E | ~5.3:1 | PASS |
| HUD position (white on dark road) | #FFFFFF | #616161 (road gray) | ~3.9:1 | FAIL — needs panel |
| HUD timer (#CCCCCC on road) | #CCCCCC | #616161 | ~2.6:1 | FAIL — needs panel |
| HUD speed (#7DEB7D on road) | #7DEB7D | #616161 | ~2.3:1 | FAIL — needs panel |
| ESC hint (#555555 on nav) | #555555 | #13132E | ~4.6:1 | PASS (barely) |
| Results trophy labels | gold on #0D0D2B | ~11:1 | PASS |
| Results "Better Luck" | #777777 on #0D0D2B | ~4.5:1 | BORDERLINE PASS |

**Action required:** Add the semi-opaque HUD panel (Issue 3) to bring all HUD text ratios above 7:1 (WCAG AA for large text is 3:1, for normal text 4.5:1 — the HUD labels are large but the panel eliminates risk entirely).

### Keyboard Navigation
- Main Menu: StartButton gets `grab_focus()` on `_ready()` — GOOD. Enter key fires action — GOOD.
- Results Screen: No `grab_focus()` call on either button — ISSUE. After race ends, tab focus is lost. Add `$ButtonRow/RaceAgainButton.grab_focus()` in results.gd `_ready()`.
- During race: No UI navigation needed (keyboard = game input).

### Colorblind Considerations
- 4 AI cars: Blue, Green, Orange, Purple. Blue/Purple confusion for tritanopia is possible, but unlikely to cause gameplay issues since AI car identity is non-critical.
- Boost bar yellow / crash bar red: Safe for deuteranopia (yellow vs red are distinguishable by hue). Acceptable for a family arcade game.
- If expanding: consider adding text labels to AI cars ("B", "G", "O", "P") as children of their Sprite2D nodes.

### Touch Target Sizing
- PC-only game, keyboard controls — not applicable.
- However, button minimum sizes (260x60px menu, 180x52px results) are generous and fine.

### Font Sizing at Distance
- The 40pt position label is readable at arm's length from a monitor. Recommended increase to 48pt.
- The 18pt ESC hint and 16pt controls hint are borderline at low-resolution displays — acceptable for a family PC game on a standard monitor.

---

## Appendix: Quick-Win Implementation Order

If implementing all recommendations is too much, here is the fastest path to a dramatically improved experience:

**In 2 hours:**
1. Add StyleBoxFlat panel behind HUD labels (30 min)
2. Style StartButton to filled yellow (15 min)
3. Add "CRASH!" Label + red flash tween (45 min)
4. Add HUD boost bar (30 min)

**In 4 more hours:**
5. Move Griddy Kid to HUD CanvasLayer (1 hour)
6. Player finish overlay "RACE COMPLETE!" (30 min)
7. Countdown scale/fade animation (30 min)
8. Fix results emoji → text trophy labels + add grab_focus (30 min)
9. Remove ScrollContainer from results.tscn (15 min)
10. Add scene fade transition (1 hour)

Total: ~6 hours of implementation for a game that feels significantly more polished and complete.
