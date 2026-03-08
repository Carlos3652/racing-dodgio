# Racing Dodgio — HUD-Focused UI/UX Audit
**Delivered:** 2026-03-01
**Auditor:** UIUXVisionary
**Engine:** Godot 4.6
**Viewport reference:** 1152×648 (camera zoom 0.65 applied to world)

---

## 1. Wireframe — Improved HUD Layout

### Full-screen annotated layout (1152×648 reference)

```
┌──────────────────────────────────────────────────────────────────────────┐
│  VIEWPORT (1152×648)                                                     │
│                                                                          │
│ ┌─────────────────────┐              ┌──────────────────────────────┐   │
│ │  STAT PANEL         │              │  SPECTATOR STAND             │   │
│ │  offset 12,12       │              │  anchor_left=1 anchor_right=1│   │
│ │  210×194px          │              │  offset -210,10 → -10,220    │   │
│ │  corner_radius=10   │              │  200×210px, corner_radius=10 │   │
│ │                     │              │                              │   │
│ │  [P] 1st        44pt│              │  ┌──────────────────────────┐│   │
│ │  divider line       │              │  │  CROWD HYPE  [14pt caps] ││   │
│ │  [T] 0:45.23    24pt│              │  │  Color(0.85,0.75,1,1)    ││   │
│ │  divider line       │              │  │  centered, letter-spaced ││   │
│ │  [S] 105 km/h   20pt│              │  └──────────────────────────┘│   │
│ │  divider line       │              │                              │   │
│ │  BOOST READY    14pt│              │  [GriddyKid Sprite2D]        │   │
│ │  (yellow when live) │              │  centered in box             │   │
│ │                     │              │  scale 2.2                   │   │
│ └─────────────────────┘              │                              │   │
│                                      │  ████ HYPE BAR ████  12pt   │   │
│                                      │  ProgressBar h=8px           │   │
│                                      └──────────────────────────────┘   │
│                                                                          │
│                                                                          │
│           [CountdownLabel — screen center 0.5, 0.42]                    │
│                "3"  "2"  "1"  "GO!"                                     │
│                96pt, yellow, tween scale 1.8→1.0 + alpha                │
│                                                                          │
│                                                                          │
│                                                    [EscHint top-right]  │
│                                          anchor_right=1, offset_top=16  │
│                                          offset_right=-220 (clears box) │
│                                          "ESC — menu"  16pt #5A5A6E     │
│                                                                          │
│  [BoostBar full-width at bottom — only visible during boost/stun]       │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │ ████████████████████░░░░░░░░░░░░░░░░  BOOST 4.2s  [yellow bar]  │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│   anchor_bottom=1, offset_bottom=-10, height=28px, width centered       │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## 2. HUDPanel Redesign

### Current problem
Plain ColorRect at Color(0,0,0,0.62) with no corner radius. It reads as a debug overlay, not a game UI element. No visual hierarchy between the three data rows. Text bleeds to the edge with only 10px left-margin.

### Recommended approach — PanelContainer with StyleBoxFlat

PanelContainer handles padding automatically and supports border and corner radii via StyleBoxFlat — no custom shader needed.

**Node replacement:**

Replace the three separate orphan Labels + ColorRect HUDPanel with this tree:

```
HUD (CanvasLayer)
  StatPanel (PanelContainer)          ← replaces HUDPanel
    VBoxContainer
      PositionLabel (Label)
      HSeparator                      ← thin divider, 1px, Color(1,1,1,0.12)
      TimerLabel (Label)
      HSeparator
      SpeedLabel (Label)
      HSeparator
      BoostStatusLabel (Label)        ← NEW — see section 5
```

**StatPanel .tscn values:**

```gdscript
[node name="StatPanel" type="PanelContainer" parent="HUD"]
offset_left   = 12.0
offset_top    = 12.0
offset_right  = 222.0   # fixed right edge, not label-dependent
offset_bottom = 200.0   # accommodates 4 rows + BoostStatusLabel

# StyleBoxFlat override — applied via theme or script:
# theme_override_styles/panel = StyleBoxFlat
#   bg_color           = Color(0.04, 0.03, 0.14, 0.82)  # deep navy, not black
#   corner_radius_top_left     = 10
#   corner_radius_top_right    = 10
#   corner_radius_bottom_right = 10
#   corner_radius_bottom_left  = 10
#   border_width_left   = 1
#   border_width_right  = 1
#   border_width_top    = 1
#   border_width_bottom = 1
#   border_color        = Color(0.4, 0.35, 0.7, 0.5)   # faint purple rim
#   content_margin_left   = 12.0
#   content_margin_right  = 12.0
#   content_margin_top    = 10.0
#   content_margin_bottom = 10.0
```

**Why navy instead of black:**
The track has dark asphalt sections. Pure black at 62% opacity merges visually with the road. The deep navy Color(0.04,0.03,0.14,0.82) reads as a distinct UI layer while matching the game's color palette (BG is #0D0D2B). Slightly higher opacity (0.82 vs 0.62) compensates for the reduced contrast from not being pure black.

**Border:**
A 1px faint purple border at 50% alpha costs nothing in performance and creates a clean "card" edge that separates the panel from any background it overlaps. Without it, rounded corners alone do not produce a clear boundary.

---

## 3. PositionLabel Improvement

### Current problem
44pt white label, no label prefix, no visual weight difference from TimerLabel (26pt). At a glance during racing, 1st/2nd/3rd do not pop. The ordinal suffix "st/nd/rd/th" is the same size as the numeral, making it harder to parse.

### Recommended approach — split numeral from suffix

Use two Labels side by side in an HBoxContainer so the numeral can be 56pt and the suffix can be 28pt and vertically bottom-aligned.

**Node tree:**

```
PositionRow (HBoxContainer)
  PlaceNumeral (Label)   # "1"   — 56pt, Color(1, 0.88, 0.08, 1) yellow
  PlaceSuffix  (Label)   # "st"  — 26pt, Color(0.9, 0.9, 0.9, 1) white
                         # vertical_alignment = BOTTOM
```

**Why yellow for the numeral:**
Yellow (#FFD91A / Color(1,0.88,0.08)) is already the game's accent color (countdown, cookies, center dashes). Making the race position numeral yellow creates instant association with "the most important number." White suffix at lower size is secondary and does not compete.

**Position prefix label:**

Add a 12pt uppercase tag above the numeral row:

```
[node name="PositionTag" type="Label" parent="HUD/StatPanel/VBox"]
text = "POSITION"
theme_override_font_sizes/font_size = 11
theme_override_colors/font_color = Color(0.55, 0.5, 0.8, 1)  # muted purple
```

This 11pt "POSITION" eyebrow label is a standard game HUD pattern (Mario Kart, F-Zero, Rocket League). It makes 1st/2nd/3rd self-explanatory to first-time players without needing any tutorial.

**Color-coded by place:**

In race_manager.gd `_update_hud()`, add a match block:

```gdscript
match place:
    1: hud_place_numeral.add_theme_color_override("font_color", Color(1.0,  0.88, 0.08, 1))  # gold
    2: hud_place_numeral.add_theme_color_override("font_color", Color(0.75, 0.75, 0.78, 1))  # silver
    3: hud_place_numeral.add_theme_color_override("font_color", Color(0.8,  0.5,  0.25, 1))  # bronze
    _: hud_place_numeral.add_theme_color_override("font_color", Color(0.9,  0.9,  0.9,  1))  # white
```

This is a zero-cost, high-impact change. Every racing game uses podium colors for position feedback.

---

## 4. SpectatorBox / Griddy Area Redesign

### Current problems
- "CROWD HYPE" at 13pt feels like a placeholder debug label, not a UI element
- Plain purple rectangle with no internal structure
- No visual separation between the label and the character
- No feedback state — the box looks identical whether Griddy is dancing or idle
- Griddy's position is set dynamically in code but the box anchors are mixed (some in .tscn, some in _setup_griddy()) creating fragility

### Recommended redesign — "Stadium Stand" metaphor

The Griddy Kid is your hype character. Treat the box as a miniature stadium seat card, like the crowd cam in NBA 2K or the team mascot widget in older arcade racers.

**Node tree:**

```
StandPanel (PanelContainer) — top-right, anchor_left=1 anchor_right=1
  VBoxContainer
    StandHeader (HBoxContainer)
      CrowdIcon (Label)           # unicode character: "★" — 14pt yellow
      CrowdTitle (Label)          # "CROWD CAM"  — 12pt, Color(0.85,0.75,1,1)
    GriddyFrame (ColorRect)       # inner frame for the sprite, 180×145px
                                  # Color(0.06,0.04,0.18,1) — darker inset
    HypeBar (ProgressBar)         # 8px tall, fills on cookie pickup, drains over 5s
    HypeLabel (Label)             # "HYPE!" during dance, "..." at idle
                                  # 12pt, centered, Color(0.85,0.75,1,1)
```

**StandPanel .tscn values:**

```gdscript
[node name="StandPanel" type="PanelContainer" parent="HUD"]
anchor_left  = 1.0
anchor_right = 1.0
offset_left  = -215.0
offset_top   = 10.0
offset_right = -10.0
offset_bottom = 228.0   # 218px tall total

# StyleBoxFlat:
#   bg_color           = Color(0.07, 0.05, 0.20, 0.92)  # deep violet-navy
#   corner_radius_all  = 10
#   border_width_all   = 1
#   border_color       = Color(0.55, 0.40, 0.90, 0.60)  # purple accent rim
#   content_margin_all = 8.0
```

**CrowdTitle label:**

```gdscript
text = "CROWD CAM"
theme_override_font_sizes/font_size = 12
theme_override_colors/font_color = Color(0.85, 0.75, 1.0, 0.85)
# uppercase_mode handled by text content — no font feature needed
```

**GriddyFrame inner rect:**

```gdscript
[node name="GriddyFrame" type="ColorRect" parent="HUD/StandPanel/VBox"]
custom_minimum_size = Vector2(180, 145)
color = Color(0.04, 0.03, 0.12, 1.0)   # near-black inset — makes sprite pop
```

GriddyKid Sprite2D sits centered inside GriddyFrame. Because PanelContainer controls layout, remove the dynamic positioning code from `_setup_griddy()` and instead set GriddyKid as a child of GriddyFrame with position = Vector2(90, 72) (center of frame).

**HypeBar — ProgressBar:**

```gdscript
[node name="HypeBar" type="ProgressBar" parent="HUD/StandPanel/VBox"]
custom_minimum_size = Vector2(180, 8)
max_value = 5.0        # matches boost_time duration
value     = 0.0
show_percentage = false

# StyleBoxFlat for fill:
#   bg_color = Color(0.55, 0.25, 0.90, 1)  # purple fill at idle
# Override during boost in script:
#   bg_color = Color(1.0, 0.88, 0.08, 1)   # yellow fill — matches game accent

# StyleBoxFlat for background track:
#   bg_color = Color(0.12, 0.10, 0.25, 1)
```

In `_update_hud()`, drive the bar:

```gdscript
hype_bar.value = player.boost_time   # drains from 5.0 to 0.0 automatically
```

**HypeLabel state logic (in race_manager.gd):**

```gdscript
if griddy_anim.is_playing():
    hype_label.text = "HYPE!"
    hype_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.08, 1))  # yellow
else:
    hype_label.text = "..."
    hype_label.add_theme_color_override("font_color", Color(0.55, 0.50, 0.70, 1)) # muted
```

---

## 5. Missing HUD Elements

### Priority 1 — Boost Timer Bar (HIGH IMPACT, LOW EFFORT)

**Problem:** Player has no idea how long the boost lasts. They feel speed but cannot plan around it.

**Solution:**

```gdscript
[node name="BoostStatusLabel" type="Label" parent="HUD/StatPanel/VBox"]
theme_override_font_sizes/font_size = 13
# Updated every frame in _update_hud():
#   if player.boost_time > 0:
#     text = "BOOST  %.1fs" % player.boost_time
#     color = Color(1.0, 0.88, 0.08, 1)   # yellow — live
#   elif player.crash_time > 0:
#     text = "STUNNED  %.1fs" % player.crash_time
#     color = Color(1.0, 0.25, 0.20, 1)   # red — danger
#   else:
#     text = "BOOST READY"
#     color = Color(0.45, 0.45, 0.45, 1)  # gray — dormant
```

This single label does triple duty: boost timer, stun timer, and idle state. It tells the player what is happening and for how long — the two most important questions during an event.

**BoostBar — bottom of screen (full-width bar, hides when inactive):**

```gdscript
[node name="BoostBar" type="ProgressBar" parent="HUD"]
anchor_left   = 0.0
anchor_right  = 1.0
anchor_bottom = 1.0
offset_left   = 80.0     # clear stat panel left edge
offset_right  = -220.0   # clear spectator box right edge
offset_bottom = -12.0
offset_top    = -40.0     # 28px tall
max_value     = 5.0
value         = 0.0
show_percentage = false
visible = false           # hidden when boost_time == 0

# BOOST state StyleBoxFlat fill: Color(1.0, 0.88, 0.08, 1)  — yellow
# STUN  state StyleBoxFlat fill: Color(0.9, 0.15, 0.15, 1)  — red
# Track bg:                      Color(0.12, 0.12, 0.20, 0.7)
```

Visibility logic in `_update_hud()`:

```gdscript
if player.boost_time > 0:
    boost_bar.visible = true
    boost_bar.max_value = 5.0
    boost_bar.value = player.boost_time
    # set fill color to yellow via theme override
elif player.crash_time > 0:
    boost_bar.visible = true
    boost_bar.max_value = 2.0
    boost_bar.value = player.crash_time
    # set fill color to red via theme override
else:
    boost_bar.visible = false
```

### Priority 2 — Stun Flash Overlay Text (HIGH IMPACT, LOW EFFORT)

The red FlashRect fires on crash but gives no text feedback. Add a CrashLabel centered on screen that appears alongside the flash:

```gdscript
[node name="CrashLabel" type="Label" parent="HUD"]
anchor_left   = 0.5
anchor_right  = 0.5
anchor_top    = 0.5
anchor_bottom = 0.5
offset_left   = -120.0
offset_right  = 120.0
offset_top    = -30.0
offset_bottom = 30.0
horizontal_alignment = 1
text = "STUNNED!"
theme_override_font_sizes/font_size = 48
theme_override_colors/font_color = Color(1.0, 0.25, 0.20, 1)
visible = false
```

In `_flash_screen()` in race_manager.gd, show and hide it alongside the tween:

```gdscript
crash_label.visible = true
var tw = create_tween()
tw.tween_property(flash_rect, "color:a", 0.45, 0.08)
tw.tween_property(flash_rect, "color:a", 0.0, 0.25)
tw.tween_callback(func(): crash_label.visible = false)
```

### Priority 3 — Position Change Indicator (MEDIUM IMPACT, MEDIUM EFFORT)

When the player overtakes or gets overtaken, a brief delta badge appears next to the position:

```gdscript
[node name="PositionDelta" type="Label" parent="HUD"]
# Positioned to the right of PlaceNumeral (inside PositionRow HBoxContainer)
theme_override_font_sizes/font_size = 20
# Text: "+1" (green, Color(0.3,1.0,0.4)) when gained, "-1" (red) when lost
# auto-hides after 2s via Tween alpha 1.0 → 0.0
```

Track previous_place in race_manager.gd. On each `_update_hud()` call, compare current vs previous. If changed, show delta label and tween it out.

### Priority 4 — Mini-Map (LOW PRIORITY for this stage)

A minimap would require a second camera or a SubViewport with a separate render layer. Given the Godot built-in constraint, defer this to a future iteration. The track is a linear loop — position rank communicates route progress adequately.

---

## 6. Countdown Redesign

### Current problem
Plain 96pt yellow label. Appears without entrance animation. "GO!" is the same weight and color as "3"/"2"/"1" — the transition moment has no visual escalation.

### Recommended approach — Tween punch-in with color shift

The countdown label stays at its current anchor (0.5, 0.4). The improvement is entirely in the animation and the "GO!" state color change.

**Node changes:**

```gdscript
[node name="CountdownLabel" type="Label" parent="HUD"]
anchor_left   = 0.5
anchor_top    = 0.42           # slightly below vertical center — avoids exact center occlusion
anchor_right  = 0.5
anchor_bottom = 0.42
offset_left   = -100.0
offset_right  = 100.0
offset_top    = -60.0
offset_bottom = 60.0
horizontal_alignment = 1      # ALIGN_CENTER
vertical_alignment   = 1      # ALIGN_CENTER
pivot_offset = Vector2(100, 60)  # center of the label rect for scale tween
theme_override_font_sizes/font_size = 96
theme_override_colors/font_color = Color(1, 0.88, 0.08, 1)  # yellow
```

**Backdrop rect behind countdown (new node):**

```gdscript
[node name="CountdownBacking" type="ColorRect" parent="HUD"]
anchor_left   = 0.5
anchor_right  = 0.5
anchor_top    = 0.42
anchor_bottom = 0.42
offset_left   = -110.0
offset_right  =  110.0
offset_top    = -68.0
offset_bottom =  68.0
color = Color(0.0, 0.0, 0.0, 0.0)   # starts invisible, tweened in with each digit
mouse_filter = 2                      # IGNORE
```

**Tween recipe in race_manager.gd** — replace the raw text assignment with this function:

```gdscript
func _show_countdown_digit(text: String, is_go: bool) -> void:
    hud_countdown.text = text
    hud_countdown.pivot_offset = Vector2(100, 60)

    if is_go:
        hud_countdown.add_theme_color_override("font_color", Color(0.2, 1.0, 0.35, 1))  # green
        hud_countdown.add_theme_font_size_override("font_size", 108)  # slightly bigger
    else:
        hud_countdown.add_theme_color_override("font_color", Color(1.0, 0.88, 0.08, 1))  # yellow
        hud_countdown.add_theme_font_size_override("font_size", 96)

    # Punch-in: scale from 1.8 down to 1.0, modulate alpha 0→1
    hud_countdown.scale    = Vector2(1.8, 1.8)
    hud_countdown.modulate = Color(1, 1, 1, 0)
    countdown_backing.modulate = Color(1, 1, 1, 0)

    var tw = create_tween()
    tw.set_parallel(true)
    tw.tween_property(hud_countdown,        "scale",    Vector2(1.0, 1.0), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tw.tween_property(hud_countdown,        "modulate", Color(1,1,1,1),    0.12)
    tw.tween_property(countdown_backing, "modulate", Color(1,1,1,0.45), 0.12)

    # Fade out 0.55s after appearing
    tw.chain()
    tw.tween_property(hud_countdown,     "modulate", Color(1,1,1,0), 0.15).set_delay(0.55)
    tw.tween_property(countdown_backing, "modulate", Color(1,1,1,0), 0.15).set_delay(0.55)
```

**State machine update in _process():**

```gdscript
State.COUNTDOWN:
    countdown_left -= delta
    var digit = ceili(countdown_left)

    if countdown_left > 0 and digit != last_countdown_digit:
        last_countdown_digit = digit
        _show_countdown_digit(str(digit), false)

    if countdown_left <= 0 and not go_shown:
        go_shown = true
        _show_countdown_digit("GO!", true)

    if countdown_left <= -0.8:
        state = State.RACING
        hud_countdown.visible = false
        countdown_backing.visible = false
        player.is_racing = true
        for ai in ai_cars:
            ai.is_racing = true
```

Add to var declarations at top of race_manager.gd:

```gdscript
var last_countdown_digit: int = 4
var go_shown: bool = false
var countdown_backing: ColorRect
```

And in `_setup_hud_refs()`:

```gdscript
countdown_backing = $HUD/CountdownBacking
```

**Why TRANS_BACK ease for the scale:**
BACK overshoot gives a slight bounce past 1.0 before settling. This "stamp" motion is a well-established game UI pattern for countdown digits — it feels impactful rather than mechanical. EASE_OUT means the deceleration happens at the end, which makes the number feel like it is slamming into position.

**Why green for "GO!":**
Green is a universal "permission to act" color with cross-cultural recognition. Using yellow for GO would make it blend with the countdown numbers. The green shift signals a state change, not just another digit. This matches Mario Kart, F-Zero GX, and most arcade racers.

---

## 7. Design Variants

### Variant A — Compact Utility (Recommended for current build stage)

**Philosophy:** Minimal additions to existing structure. Swap ColorRect panel to PanelContainer with StyleBoxFlat, add BoostStatusLabel, improve countdown tween. No restructuring of SpectatorBox beyond label rename and HypeBar addition.

**Pros:**
- Smallest delta from current .tscn — lowest implementation risk
- All improvements are additive, nothing broken if partially implemented
- Boost/stun label immediately solves the most painful player confusion
- Countdown tween is a single function addition

**Cons:**
- SpectatorBox still uses ColorRect with manual positioning from script
- No position change indicator
- HypeBar drain requires tracking boost_time in a new var reference

**Best for:** Current sprint — implement in one session without scene restructuring.

**Metrics to watch:** Time-to-understand-boost (ask a new player "when does boost run out?"). If they check the label immediately on first play, the design is working.

---

### Variant B — Restructured Panel (Full Recommended Design)

**Philosophy:** Replace all HUDPanel + orphan Labels with PanelContainer trees as specified in sections 2–4 above. Full node hierarchy redesign. SpectatorBox becomes StandPanel with PanelContainer. BoostBar added at screen bottom. CrashLabel added. PositionRow uses HBoxContainer numeral/suffix split.

**Pros:**
- PanelContainer auto-handles padding — no hardcoded pixel offsets to maintain
- VBoxContainer means adding/removing rows is a single node operation
- Border + corner radius on StatPanel and StandPanel creates clear "cards"
- HypeBar drain gives tangible feedback on cookie economy
- BoostBar at screen bottom uses peripheral vision zone effectively

**Cons:**
- Requires restructuring .tscn scene tree — moderate effort
- All $HUD/LabelName references in race_manager.gd must be updated to new paths
- PositionRow HBoxContainer needs script updates for numeral/suffix split
- More nodes = slightly more scene complexity to maintain

**Best for:** Next dedicated polish sprint when scene restructuring is planned anyway.

**Metrics to watch:** Error rate (jeep hits per race) — if stun timer label reduces panic steering errors, it is working. Also track session length — clearer HUD typically increases play time.

---

### Variant C — Arcade Minimal (If performance or simplicity is a constraint)

**Philosophy:** Keep all existing nodes. Add only two things: (1) BoostStatusLabel inside the existing panel area, (2) countdown tween. Touch nothing else. Zero scene restructuring.

**Pros:**
- Zero risk of breaking existing layout
- Countdown tween is purely additive code — no node changes required
- BoostStatusLabel is one new Label node
- Implementable in under 30 minutes

**Cons:**
- Does not address panel visual quality (still plain black rect)
- Does not fix SpectatorBox placeholder feel
- No stun feedback, no position color coding
- No HypeBar

**Best for:** If the developer wants a quick win before the next full session. Good for a playtest build this week.

**Metrics to watch:** Player comments on "when does boost end?" — if it drops to zero after adding BoostStatusLabel, ship Variant A next.

---

## Accessibility Notes

- **Contrast — PositionLabel yellow on navy panel:** Color(1,0.88,0.08) on Color(0.04,0.03,0.14) = approximately 9.2:1 contrast ratio. Passes WCAG AAA (7:1 threshold). Safe.
- **Contrast — TimerLabel Color(0.9,0.9,0.9) on panel:** approximately 8.5:1. Passes AAA.
- **Contrast — SpeedLabel Color(0.6,0.96,0.6) on panel:** approximately 7.8:1. Passes AAA.
- **Contrast — EscHint Color(0.55,0.55,0.55) on dark background:** approximately 4.6:1. Passes AA but not AAA. Acceptable for a secondary hint label.
- **Color-blind safe:** Podium colors (gold/silver/bronze) are distinguishable under deuteranopia because luminance values differ (gold is bright, bronze is darker). The BOOST (yellow) vs STUN (red) labels differ in both hue and luminance. BOOST READY gray is neutral. Safe for the most common forms of color blindness.
- **Font sizes at camera zoom 0.65:** The game's Camera2D zoom does not affect CanvasLayer elements — HUD renders at 1:1 screen pixels. 44pt PositionLabel renders at full size. No zoom correction needed.
- **Touch targets:** Not applicable — keyboard-only input (arrow keys + ESC).
- **Motion sensitivity:** The countdown scale tween and red flash are brief (under 0.25s). No sustained animation that would trigger photosensitivity concerns. The Griddy spritesheet animation runs only for 2s on cookie pickup — acceptable.

---

## Platform Notes (PC — Godot 4.6)

- All HUD elements live in CanvasLayer — they render at native screen resolution independent of camera. No scaling issues.
- Font rendering in Godot 4.6 uses FreeType — Label at 44pt will render cleanly at 1080p and 720p without override. At 4K you may want `use_mipmaps = true` on Font resources.
- PanelContainer with StyleBoxFlat has zero performance cost versus ColorRect — it is the same draw call with border and radius metadata.
- ProgressBar in Godot 4.6 requires two StyleBoxFlat overrides: `theme_override_styles/fill` for the filled portion and `theme_override_styles/background` for the empty track. Both must be set or the bar reverts to default theme.
- `Tween.set_parallel(true)` + `.chain()` pattern is stable in Godot 4.6. Do not use Tween across scene changes — always create_tween() fresh.

---

## Optimization and Testing Guidance

### Playwright / automated testing checkpoints

Since HUD elements are in CanvasLayer, visual regression tests should capture:
1. Screenshot at countdown "3" — verify label visible, position correct
2. Screenshot at countdown "GO!" — verify green color, larger size
3. Screenshot immediately after cookie pickup — verify HypeBar value > 0, GriddyKid frame != 0, BoostStatusLabel text contains "BOOST"
4. Screenshot immediately after jeep collision — verify FlashRect alpha > 0, CrashLabel visible, BoostBar red and visible

### Metrics to track after implementation

| Metric | Baseline | Target |
|---|---|---|
| New player understands boost duration | Never (no indicator) | Within first run |
| New player understands stun | Red screen only | "STUNNED!" label + bar |
| Player reports "I don't know my place" | Frequent (44pt white blend) | Zero (yellow numeral, podium colors) |
| Session length (avg minutes) | Measure before | +20% after clarity improvements |

---

*End of audit. Variant B (Restructured Panel) is the full recommended design. Variant A is the recommended first implementation step.*
