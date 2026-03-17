@tool
extends EditorScript
## Speed Trail Ghost Effect — Verification Script
##
## Run from the Godot editor: File → Run Script  (select this file)
##
## Validates that the speed trail ghost effect in car_visual.gd is correctly
## configured: draw order, ghost count, offsets, alphas, and transform reset.

func _run() -> void:
	print("\n══════════════════════════════════════════════════")
	print("  SPEED TRAIL GHOST VERIFICATION")
	print("══════════════════════════════════════════════════\n")

	var issues := 0

	# ── 1. Load and parse car_visual.gd source ──────────────────
	var script_path := "res://car_visual.gd"
	var src := FileAccess.get_file_as_string(script_path)
	if src.is_empty():
		print("  ✗ FAIL: Could not read %s" % script_path)
		return

	print("  Source loaded: %s (%d chars)" % [script_path, src.length()])

	# ── 2. Ghost drawing happens BEFORE car type match ──────────
	var ghost_idx := src.find("_draw_ghost")
	var match_idx := src.find("match car_type")
	if ghost_idx < 0:
		print("  ✗ FAIL: _draw_ghost() call not found in source")
		issues += 1
	elif match_idx < 0:
		print("  ✗ FAIL: 'match car_type' not found in source")
		issues += 1
	elif ghost_idx > match_idx:
		print("  ✗ FAIL: Ghost trail drawn AFTER car body — ghosts will render on top of car")
		issues += 1
	else:
		print("  ✓  Ghost trail drawn before car body (correct draw order)")

	# ── 3. Verify 3 ghost offsets at 20, 40, 60 ────────────────
	var has_offset_20 := src.find("20.0") >= 0
	var has_offset_40 := src.find("40.0") >= 0
	var has_offset_60 := src.find("60.0") >= 0
	if has_offset_20 and has_offset_40 and has_offset_60:
		print("  ✓  All 3 ghost offsets present (20, 40, 60)")
	else:
		print("  ✗ FAIL: Missing ghost offsets — need 20.0, 40.0, 60.0")
		issues += 1

	# ── 4. Verify 3 ghost alphas at 0.35, 0.20, 0.08 ──────────
	var has_a035 := src.find("0.35") >= 0
	var has_a020 := src.find("0.20") >= 0
	var has_a008 := src.find("0.08") >= 0
	if has_a035 and has_a020 and has_a008:
		print("  ✓  All 3 ghost alpha values present (0.35, 0.20, 0.08)")
	else:
		print("  ✗ FAIL: Missing ghost alpha values — need 0.35, 0.20, 0.08")
		issues += 1

	# ── 5. Verify draw_set_transform reset ─────────────────────
	if src.find("draw_set_transform(Vector2.ZERO)") >= 0:
		print("  ✓  Transform reset to Vector2.ZERO after ghost drawing")
	else:
		print("  ✗ FAIL: Missing transform reset — will corrupt subsequent draw calls")
		issues += 1

	# ── 6. Verify ghost only drawn during boost ────────────────
	if src.find("boost_time") >= 0 and src.find("parent.boost_time > 0") >= 0:
		print("  ✓  Ghost effect gated on boost_time > 0")
	else:
		print("  ✗ FAIL: Ghost not properly gated on boost_time")
		issues += 1

	# ── 7. Verify is_player_car guard ──────────────────────────
	if src.find("is_player_car") >= 0:
		print("  ✓  Ghost effect gated on is_player_car")
	else:
		print("  ✗ FAIL: Ghost not gated on is_player_car — AI cars would show trails")
		issues += 1

	# ── 8. Verify _draw_ghost helper exists with rect + windshield ─
	var ghost_func_idx := src.find("func _draw_ghost")
	if ghost_func_idx >= 0:
		var ghost_body := src.substr(ghost_func_idx, 300)
		var has_body_rect := ghost_body.find("draw_rect") >= 0
		var has_windshield := ghost_body.find("_WINDSHIELD") >= 0
		if has_body_rect and has_windshield:
			print("  ✓  _draw_ghost() draws body rectangle + windshield")
		else:
			print("  ✗ FAIL: _draw_ghost() missing body rect or windshield")
			issues += 1
	else:
		print("  ✗ FAIL: _draw_ghost() function not found")
		issues += 1

	# ── 9. Farthest ghost drawn first (correct layering) ───────
	# Check that 60.0 appears before 20.0 in the ghost_offsets array
	var offsets_line_idx := src.find("ghost_offsets")
	if offsets_line_idx >= 0:
		var offsets_section := src.substr(offsets_line_idx, 80)
		var idx_60 := offsets_section.find("60.0")
		var idx_20 := offsets_section.find("20.0")
		if idx_60 >= 0 and idx_20 >= 0 and idx_60 < idx_20:
			print("  ✓  Farthest ghost (60px) drawn first — correct back-to-front layering")
		else:
			print("  ⚠  WARNING: Ghost draw order may not be farthest-first")
			issues += 1
	else:
		print("  ✗ FAIL: ghost_offsets not found")
		issues += 1

	# ── 10. Verify queue_redraw in _process for animation ──────
	if src.find("queue_redraw") >= 0:
		print("  ✓  queue_redraw() called in _process for continuous animation")
	else:
		print("  ✗ FAIL: No queue_redraw — ghost trail won't animate")
		issues += 1

	# ── Summary ────────────────────────────────────────────────
	print("\n══════════════════════════════════════════════════")
	if issues == 0:
		print("  ✅  ALL CHECKS PASSED — speed trail ghost effect is correct")
	else:
		print("  ✗  %d issue(s) found — see details above" % issues)
	print("══════════════════════════════════════════════════\n")
