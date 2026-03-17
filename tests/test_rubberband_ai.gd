@tool
extends EditorScript
## Rubber-band AI Catch-up / Pullback — Verification Script
##
## Run from the Godot editor: File → Run Script  (select this file)
##
## Validates that:
##  1. ai_car.gd declares player_ref, CATCHUP_BONUS, PULLBACK_PENALTY
##  2. CATCHUP_BONUS and PULLBACK_PENALTY are @export vars with correct defaults
##  3. _process() contains rubber-band logic using 10% threshold
##  4. race_manager.gd sets ai.player_ref = player before adding to scene
##  5. get_total_progress() helper exists for AI progress calculation
##  6. Rubber-band adjustment is additive to current_base (not multiplicative)

func _run() -> void:
	print("\n══════════════════════════════════════════════════")
	print("  RUBBER-BAND AI CATCH-UP / PULLBACK VERIFICATION")
	print("══════════════════════════════════════════════════\n")

	var issues := 0
	var tests := 0

	# ── Load source files ──────────────────────────────────
	var ai_src := FileAccess.get_file_as_string("res://ai_car.gd")
	if ai_src.is_empty():
		print("  ✗ FAIL: Could not read ai_car.gd")
		return

	var rm_src := FileAccess.get_file_as_string("res://race_manager.gd")
	if rm_src.is_empty():
		print("  ✗ FAIL: Could not read race_manager.gd")
		return

	# ── 1. player_ref variable declared with correct type ──
	tests += 1
	if ai_src.find("var player_ref") >= 0 and ai_src.find("Node2D") >= 0:
		print("  ✓  player_ref: Node2D variable declared in ai_car.gd")
	else:
		print("  ✗ FAIL: player_ref: Node2D not found in ai_car.gd")
		issues += 1

	# ── 2. CATCHUP_BONUS is @export with default 25.0 ─────
	tests += 1
	if ai_src.find("@export var CATCHUP_BONUS") >= 0 and ai_src.find("25.0") >= 0:
		print("  ✓  @export var CATCHUP_BONUS = 25.0 found")
	else:
		print("  ✗ FAIL: @export var CATCHUP_BONUS: float = 25.0 not found")
		issues += 1

	# ── 3. PULLBACK_PENALTY is @export with default 15.0 ──
	tests += 1
	if ai_src.find("@export var PULLBACK_PENALTY") >= 0 and ai_src.find("15.0") >= 0:
		print("  ✓  @export var PULLBACK_PENALTY = 15.0 found")
	else:
		print("  ✗ FAIL: @export var PULLBACK_PENALTY: float = 15.0 not found")
		issues += 1

	# ── 4. 10% threshold calculation present ───────────────
	tests += 1
	if ai_src.find("0.1") >= 0 and ai_src.find("threshold") >= 0:
		print("  ✓  10%% threshold calculation found (total_track * 0.1)")
	else:
		print("  ✗ FAIL: 10%% threshold logic not found in ai_car.gd")
		issues += 1

	# ── 5. CATCHUP_BONUS added to current_base ─────────────
	tests += 1
	if ai_src.find("current_base += CATCHUP_BONUS") >= 0:
		print("  ✓  CATCHUP_BONUS is additive to current_base")
	else:
		print("  ✗ FAIL: 'current_base += CATCHUP_BONUS' not found — must be additive")
		issues += 1

	# ── 6. PULLBACK_PENALTY subtracted from current_base ───
	tests += 1
	if ai_src.find("current_base -= PULLBACK_PENALTY") >= 0:
		print("  ✓  PULLBACK_PENALTY is subtractive from current_base")
	else:
		print("  ✗ FAIL: 'current_base -= PULLBACK_PENALTY' not found — must be subtractive")
		issues += 1

	# ── 7. get_total_progress() helper exists ──────────────
	tests += 1
	if ai_src.find("func get_total_progress()") >= 0:
		print("  ✓  get_total_progress() helper function exists")
	else:
		print("  ✗ FAIL: get_total_progress() not found in ai_car.gd")
		issues += 1

	# ── 8. Player total progress uses player_ref fields ────
	tests += 1
	if ai_src.find("player_ref.current_lap") >= 0 and ai_src.find("player_ref.track_progress") >= 0:
		print("  ✓  Player progress computed from player_ref.current_lap & track_progress")
	else:
		print("  ✗ FAIL: Player progress not computed from player_ref fields")
		issues += 1

	# ── 9. Null-safety check for player_ref ────────────────
	tests += 1
	if ai_src.find("player_ref != null") >= 0 and ai_src.find("is_instance_valid(player_ref)") >= 0:
		print("  ✓  Null-safety: checks player_ref != null and is_instance_valid()")
	else:
		print("  ✗ FAIL: Missing null-safety check for player_ref")
		issues += 1

	# ── 10. race_manager sets ai.player_ref = player ───────
	tests += 1
	if rm_src.find("ai.player_ref = player") >= 0:
		print("  ✓  race_manager.gd sets ai.player_ref = player")
	else:
		print("  ✗ FAIL: race_manager.gd must set ai.player_ref = player")
		issues += 1

	# ── 11. player_ref is set before add_child ─────────────
	tests += 1
	var ref_pos := rm_src.find("ai.player_ref = player")
	var add_child_pos := rm_src.find("track_path.add_child(ai)")
	if ref_pos >= 0 and add_child_pos >= 0 and ref_pos < add_child_pos:
		print("  ✓  player_ref assigned before AI is added to scene tree")
	else:
		print("  ✗ FAIL: player_ref must be set before track_path.add_child(ai)")
		issues += 1

	# ── 12. Rubber-band uses total_laps for full track calc ─
	tests += 1
	if ai_src.find("total_laps") >= 0 and ai_src.find("curve_len") >= 0:
		print("  ✓  Total track distance uses total_laps * curve_len")
	else:
		print("  ✗ FAIL: Rubber-band should use total_laps for full track distance")
		issues += 1

	# ── 13. has_finished guard prevents rubber-band on done player ─
	tests += 1
	if ai_src.find("player_ref.has_finished") >= 0:
		print("  ✓  Rubber-band disabled when player has finished")
	else:
		print("  ✗ FAIL: Should check player_ref.has_finished to avoid post-race adjustments")
		issues += 1

	# ── Summary ─────────────────────────────────────────────
	print("\n══════════════════════════════════════════════════")
	if issues == 0:
		print("  ALL CHECKS PASSED (%d tests)" % tests)
	else:
		print("  %d ISSUE(S) FOUND out of %d tests" % [issues, tests])
	print("══════════════════════════════════════════════════\n")
