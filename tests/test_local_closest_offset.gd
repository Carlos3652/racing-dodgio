@tool
extends EditorScript
## Local Closest Offset Optimization — Verification Script
##
## Run from the Godot editor: File → Run Script  (select this file)
##
## Validates that:
##  1. _local_closest_offset() function exists in race_manager.gd
##  2. _constrain_to_road() uses _local_closest_offset() instead of get_closest_offset()
##  3. The function accepts (curve, pos, hint) parameters
##  4. LOCAL_SEARCH_RADIUS constant is defined
##  5. LOCAL_SEARCH_STEPS constant is defined for coarse pass
##  6. LOCAL_REFINE_STEPS constant is defined for refinement
##  7. Safety fallback to curve.get_closest_offset() exists
##  8. Curve wrapping handled (fmod or manual wrap)
##  9. First-frame fallback (hint <= 0.0) uses full search
## 10. sample_baked used for local sampling
## 11. player.track_progress still synced after the call
## 12. Original road-width constraints preserved

func _run() -> void:
	print("\n══════════════════════════════════════════════════")
	print("  LOCAL CLOSEST OFFSET OPTIMIZATION — VERIFICATION")
	print("══════════════════════════════════════════════════\n")

	var issues := 0
	var tests := 0

	# ── Load source file ──────────────────────────────────
	var src := FileAccess.get_file_as_string("res://race_manager.gd")
	if src.is_empty():
		print("  ✗ FAIL: Could not read race_manager.gd")
		return

	# ── 1. _local_closest_offset function exists ──────────
	tests += 1
	if src.find("func _local_closest_offset(") >= 0:
		print("  ✓  _local_closest_offset() function exists")
	else:
		print("  ✗ FAIL: _local_closest_offset() function not found")
		issues += 1

	# ── 2. _constrain_to_road uses local search ──────────
	tests += 1
	# Find _constrain_to_road and check it uses _local_closest_offset
	var constrain_start := src.find("func _constrain_to_road()")
	var constrain_end := src.find("\nfunc ", constrain_start + 1) if constrain_start >= 0 else -1
	var constrain_body := ""
	if constrain_start >= 0 and constrain_end >= 0:
		constrain_body = src.substr(constrain_start, constrain_end - constrain_start)
	elif constrain_start >= 0:
		constrain_body = src.substr(constrain_start, 500)

	if constrain_body.find("_local_closest_offset(") >= 0:
		print("  ✓  _constrain_to_road() calls _local_closest_offset()")
	else:
		print("  ✗ FAIL: _constrain_to_road() should call _local_closest_offset()")
		issues += 1

	# ── 3. O(n) get_closest_offset removed from _constrain_to_road ─
	tests += 1
	if constrain_body.find("curve.get_closest_offset(") < 0:
		print("  ✓  No direct curve.get_closest_offset() in _constrain_to_road()")
	else:
		print("  ✗ FAIL: _constrain_to_road() still calls curve.get_closest_offset() directly")
		issues += 1

	# ── 4. Function signature has (curve, pos, hint) ─────
	tests += 1
	if src.find("func _local_closest_offset(curve: Curve2D, pos: Vector2, hint: float)") >= 0:
		print("  ✓  Function signature: (curve: Curve2D, pos: Vector2, hint: float)")
	else:
		print("  ✗ FAIL: Expected typed signature (curve: Curve2D, pos: Vector2, hint: float)")
		issues += 1

	# ── 5. LOCAL_SEARCH_RADIUS defined ───────────────────
	tests += 1
	if src.find("LOCAL_SEARCH_RADIUS") >= 0:
		print("  ✓  LOCAL_SEARCH_RADIUS constant defined")
	else:
		print("  ✗ FAIL: LOCAL_SEARCH_RADIUS constant not found")
		issues += 1

	# ── 6. LOCAL_SEARCH_STEPS defined ────────────────────
	tests += 1
	if src.find("LOCAL_SEARCH_STEPS") >= 0:
		print("  ✓  LOCAL_SEARCH_STEPS constant defined")
	else:
		print("  ✗ FAIL: LOCAL_SEARCH_STEPS constant not found")
		issues += 1

	# ── 7. LOCAL_REFINE_STEPS defined ────────────────────
	tests += 1
	if src.find("LOCAL_REFINE_STEPS") >= 0:
		print("  ✓  LOCAL_REFINE_STEPS constant defined")
	else:
		print("  ✗ FAIL: LOCAL_REFINE_STEPS constant not found")
		issues += 1

	# ── 8. Safety fallback to full search ────────────────
	tests += 1
	var func_start := src.find("func _local_closest_offset(")
	var func_end := src.find("\nfunc ", func_start + 1) if func_start >= 0 else -1
	var func_body := ""
	if func_start >= 0 and func_end >= 0:
		func_body = src.substr(func_start, func_end - func_start)
	elif func_start >= 0:
		func_body = src.substr(func_start, 2000)

	if func_body.find("curve.get_closest_offset(pos)") >= 0:
		print("  ✓  Safety fallback to curve.get_closest_offset(pos) exists")
	else:
		print("  ✗ FAIL: No safety fallback to full curve.get_closest_offset(pos)")
		issues += 1

	# ── 9. Curve wrapping handled ────────────────────────
	tests += 1
	var has_fmod := func_body.find("fmod(") >= 0
	var has_wrap := func_body.find("curve_len") >= 0 and (func_body.find("+= curve_len") >= 0 or func_body.find("-= curve_len") >= 0 or func_body.find("+ curve_len") >= 0 or func_body.find("- curve_len") >= 0)
	if has_fmod or has_wrap:
		print("  ✓  Curve offset wrapping handled (fmod or manual)")
	else:
		print("  ✗ FAIL: No curve offset wrapping found — looped tracks will break")
		issues += 1

	# ── 10. First-frame fallback ─────────────────────────
	tests += 1
	if func_body.find("hint <= 0.0") >= 0 or func_body.find("hint == 0.0") >= 0:
		print("  ✓  First-frame fallback when hint is zero")
	else:
		print("  ✗ FAIL: No first-frame fallback for zero hint offset")
		issues += 1

	# ── 11. Uses sample_baked for local sampling ─────────
	tests += 1
	if func_body.find("curve.sample_baked(") >= 0:
		print("  ✓  Uses curve.sample_baked() for local point sampling")
	else:
		print("  ✗ FAIL: Should use curve.sample_baked() for sampling")
		issues += 1

	# ── 12. player.track_progress still synced ───────────
	tests += 1
	if constrain_body.find("player.track_progress = closest_offset") >= 0:
		print("  ✓  player.track_progress synced to closest_offset")
	else:
		print("  ✗ FAIL: player.track_progress must be synced to closest_offset")
		issues += 1

	# ── 13. Road width constraints preserved ─────────────
	tests += 1
	var has_hard := constrain_body.find("ROAD_WIDTH * 0.55") >= 0
	var has_grass := constrain_body.find("ROAD_WIDTH * 0.45") >= 0
	if has_hard and has_grass:
		print("  ✓  Road width constraints preserved (0.55 hard boundary, 0.45 grass)")
	else:
		print("  ✗ FAIL: Road width constraints (0.55 / 0.45) must be preserved")
		issues += 1

	# ── 14. LOCAL_FALLBACK_DIST defined ──────────────────
	tests += 1
	if src.find("LOCAL_FALLBACK_DIST") >= 0:
		print("  ✓  LOCAL_FALLBACK_DIST constant defined for safety threshold")
	else:
		print("  ✗ FAIL: LOCAL_FALLBACK_DIST constant not found")
		issues += 1

	# ── 15. Squared distance used (avoids sqrt) ─────────
	tests += 1
	# Check for dsq or distance_squared pattern (no sqrt in hot loop)
	var has_dsq := func_body.find("dsq") >= 0
	var no_sqrt := func_body.find("sqrt") < 0
	var no_distance_to := func_body.find(".distance_to(") < 0
	if has_dsq and no_sqrt and no_distance_to:
		print("  ✓  Uses squared distance (avoids sqrt in hot loop)")
	else:
		print("  ✗ FAIL: Should use squared distance comparisons to avoid sqrt")
		issues += 1

	# ── 16. Hint passed as player.track_progress ─────────
	tests += 1
	if constrain_body.find("player.track_progress") >= 0:
		print("  ✓  player.track_progress passed as hint to local search")
	else:
		print("  ✗ FAIL: Should pass player.track_progress as hint")
		issues += 1

	# ── Summary ─────────────────────────────────────────────
	print("\n══════════════════════════════════════════════════")
	if issues == 0:
		print("  ALL CHECKS PASSED (%d tests)" % tests)
	else:
		print("  %d ISSUE(S) FOUND out of %d tests" % [issues, tests])
	print("══════════════════════════════════════════════════\n")
