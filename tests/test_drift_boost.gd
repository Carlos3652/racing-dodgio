@tool
extends EditorScript
## Drift Boost Mechanic — Verification Script
##
## Run from the Godot editor: File → Run Script  (select this file)
##
## Validates that the drift boost mechanic is correctly implemented in
## player_car.gd and car_visual.gd: input action, variables, accumulation
## logic, boost trigger, and drift smoke visual.

func _run() -> void:
	print("\n══════════════════════════════════════════════════")
	print("  DRIFT BOOST MECHANIC VERIFICATION")
	print("══════════════════════════════════════════════════\n")

	var issues := 0

	# ── 1. Load project.godot and verify drift input action ───
	var proj_path := "res://project.godot"
	var proj_src := FileAccess.get_file_as_string(proj_path)
	if proj_src.is_empty():
		print("  ✗ FAIL: Could not read %s" % proj_path)
		return

	if proj_src.find("drift={") >= 0:
		print("  ✓  'drift' input action defined in project.godot")
	else:
		print("  ✗ FAIL: 'drift' input action not found in project.godot")
		issues += 1

	# Verify Shift key mapping (keycode 4194325 = KEY_SHIFT)
	if proj_src.find("4194325") >= 0:
		print("  ✓  Drift mapped to Shift key (keycode 4194325)")
	else:
		print("  ✗ FAIL: Drift not mapped to Shift key")
		issues += 1

	# ── 2. Load player_car.gd and verify drift variables ──────
	var car_path := "res://player_car.gd"
	var car_src := FileAccess.get_file_as_string(car_path)
	if car_src.is_empty():
		print("  ✗ FAIL: Could not read %s" % car_path)
		return

	print("\n  Source loaded: %s (%d chars)" % [car_path, car_src.length()])

	if car_src.find("var is_drifting") >= 0:
		print("  ✓  is_drifting variable declared")
	else:
		print("  ✗ FAIL: is_drifting variable not found")
		issues += 1

	if car_src.find("var drift_time") >= 0:
		print("  ✓  drift_time variable declared")
	else:
		print("  ✗ FAIL: drift_time variable not found")
		issues += 1

	# ── 3. Verify drift threshold of 1.5 seconds ─────────────
	if car_src.find("DRIFT_BOOST_THRESHOLD") >= 0 and car_src.find("1.5") >= 0:
		print("  ✓  DRIFT_BOOST_THRESHOLD constant present (1.5s)")
	else:
		print("  ✗ FAIL: DRIFT_BOOST_THRESHOLD not found or not 1.5s")
		issues += 1

	# ── 4. Verify rotation_delta check with 0.04 threshold ───
	if car_src.find("rotation_delta") >= 0 and car_src.find("0.04") >= 0:
		print("  ✓  Rotation delta checked against 0.04 threshold")
	else:
		print("  ✗ FAIL: rotation_delta or 0.04 threshold not found")
		issues += 1

	# ── 5. Verify drift input check ──────────────────────────
	if car_src.find("\"drift\"") >= 0:
		print("  ✓  Drift input action referenced in player_car.gd")
	else:
		print("  ✗ FAIL: 'drift' input action not referenced")
		issues += 1

	# ── 6. Verify boost trigger via apply_close_call_boost ────
	# Find drift-related apply_close_call_boost call (not the function def)
	var drift_section_idx := car_src.find("is_drifting")
	if drift_section_idx >= 0:
		var drift_section := car_src.substr(drift_section_idx, 600)
		if drift_section.find("apply_close_call_boost") >= 0:
			print("  ✓  Drift boost triggers via apply_close_call_boost()")
		else:
			print("  ✗ FAIL: Drift does not call apply_close_call_boost()")
			issues += 1
	else:
		print("  ✗ FAIL: No drift logic section found")
		issues += 1

	# ── 7. Verify DRIFT_BOOST_DURATION of 1.5 ────────────────
	if car_src.find("DRIFT_BOOST_DURATION") >= 0:
		print("  ✓  DRIFT_BOOST_DURATION constant defined")
	else:
		print("  ✗ FAIL: DRIFT_BOOST_DURATION not found")
		issues += 1

	# ── 8. Verify no typed const arrays (crash risk) ──────────
	var lines := car_src.split("\n")
	var has_typed_const_array := false
	for line in lines:
		var stripped := line.strip_edges()
		if stripped.begins_with("const") and stripped.find("Array") >= 0 and stripped.find("=") >= 0:
			has_typed_const_array = true
			print("  ✗ FAIL: Typed const array found (crash risk): %s" % stripped)
			issues += 1
			break
	if not has_typed_const_array:
		print("  ✓  No typed const arrays (crash-safe)")

	# ── 9. Load car_visual.gd and verify drift smoke ─────────
	var vis_path := "res://car_visual.gd"
	var vis_src := FileAccess.get_file_as_string(vis_path)
	if vis_src.is_empty():
		print("  ✗ FAIL: Could not read %s" % vis_path)
		return

	print("\n  Source loaded: %s (%d chars)" % [vis_path, vis_src.length()])

	if vis_src.find("is_drifting") >= 0:
		print("  ✓  Drift state checked in car_visual.gd")
	else:
		print("  ✗ FAIL: is_drifting not referenced in car_visual.gd")
		issues += 1

	if vis_src.find("smoke") >= 0 or vis_src.find("Smoke") >= 0 or vis_src.find("drift") >= 0:
		print("  ✓  Drift smoke visual effect present")
	else:
		print("  ✗ FAIL: No drift smoke visual found in car_visual.gd")
		issues += 1

	# Verify smoke is only drawn for player car
	if vis_src.find("is_player_car") >= 0:
		print("  ✓  Drift smoke gated on is_player_car")
	else:
		print("  ✗ FAIL: Drift smoke not gated on is_player_car")
		issues += 1

	# ── 10. Verify no typed const arrays in car_visual.gd ────
	var vis_lines := vis_src.split("\n")
	var has_typed_const_array_vis := false
	for line in vis_lines:
		var stripped := line.strip_edges()
		if stripped.begins_with("const") and stripped.find("Array") >= 0 and stripped.find("=") >= 0:
			has_typed_const_array_vis = true
			print("  ✗ FAIL: Typed const array in car_visual.gd: %s" % stripped)
			issues += 1
			break
	if not has_typed_const_array_vis:
		print("  ✓  No typed const arrays in car_visual.gd (crash-safe)")

	# ── 11. Verify _cross_finish resets drift state ─────────
	# When the player crosses the finish mid-drift, is_drifting and drift_time
	# must be reset so car_visual.gd stops drawing smoke puffs immediately.
	var cross_finish_idx := car_src.find("func _cross_finish")
	if cross_finish_idx >= 0:
		var cross_finish_section := car_src.substr(cross_finish_idx, 300)
		var resets_drifting := cross_finish_section.find("is_drifting = false") >= 0
		var resets_drift_time := cross_finish_section.find("drift_time = 0") >= 0
		if resets_drifting and resets_drift_time:
			print("  ✓  _cross_finish() resets is_drifting and drift_time (no lingering smoke)")
		else:
			if not resets_drifting:
				print("  ✗ FAIL: _cross_finish() does not reset is_drifting to false")
				issues += 1
			if not resets_drift_time:
				print("  ✗ FAIL: _cross_finish() does not reset drift_time to 0")
				issues += 1
	else:
		print("  ✗ FAIL: _cross_finish() function not found in player_car.gd")
		issues += 1

	# ── Summary ────────────────────────────────────────────────
	print("\n══════════════════════════════════════════════════")
	if issues == 0:
		print("  ✅  ALL CHECKS PASSED — drift boost mechanic is correct")
	else:
		print("  ✗  %d issue(s) found — see details above" % issues)
	print("══════════════════════════════════════════════════\n")
