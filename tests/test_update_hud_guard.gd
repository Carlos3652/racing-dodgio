@tool
extends EditorScript
## _update_hud Player-Validity Guard — Verification Script
##
## Run from the Godot editor: File → Run Script  (select this file)
##
## Validates that:
##   1. _update_hud() begins with an is_instance_valid(player) guard
##   2. The guard returns early (prevents access to freed player)

func _run() -> void:
	print("\n══════════════════════════════════════════════════")
	print("  _UPDATE_HUD PLAYER-VALIDITY GUARD VERIFICATION")
	print("══════════════════════════════════════════════════\n")

	var issues := 0

	# ── 1. Load race_manager.gd source ───────────────────
	var src_path := "res://race_manager.gd"
	var src := FileAccess.get_file_as_string(src_path)
	if src.is_empty():
		print("  ✗ FAIL: Could not read %s" % src_path)
		return

	# ── 2. Find _update_hud function body ────────────────
	var fn_start := src.find("func _update_hud(")
	if fn_start < 0:
		print("  ✗ FAIL: func _update_hud() not found in race_manager.gd")
		issues += 1
	else:
		print("  ✓  func _update_hud() found")

		# Extract function body up to next top-level func
		var fn_end := src.find("\nfunc ", fn_start + 1)
		if fn_end < 0:
			fn_end = src.length()
		var fn_body := src.substr(fn_start, fn_end - fn_start)

		# ── 3. Guard present ─────────────────────────────
		if fn_body.find("is_instance_valid(player)") >= 0:
			print("  ✓  is_instance_valid(player) guard present")
		else:
			print("  ✗ FAIL: is_instance_valid(player) guard NOT found in _update_hud")
			issues += 1

		# ── 4. Guard is early-return (before any player. access) ─
		var guard_pos := fn_body.find("is_instance_valid(player)")
		var first_player_access := fn_body.find("player.")
		if guard_pos >= 0 and first_player_access >= 0:
			if guard_pos < first_player_access:
				print("  ✓  Guard appears before first player.* access")
			else:
				print("  ✗ FAIL: Guard appears AFTER first player.* access")
				issues += 1
		elif guard_pos >= 0:
			print("  ✓  Guard present (no player.* access found — trivially safe)")
		else:
			print("  ✗ FAIL: Could not verify guard ordering")
			issues += 1

		# ── 5. Guard has return statement ────────────────
		# Look for "return" on the lines near the guard
		var guard_line_end := fn_body.find("\n", guard_pos)
		var next_line_end := fn_body.find("\n", guard_line_end + 1)
		var guard_region := fn_body.substr(guard_pos, (next_line_end if next_line_end >= 0 else fn_body.length()) - guard_pos)
		if guard_region.find("return") >= 0:
			print("  ✓  Guard includes early return")
		else:
			print("  ✗ FAIL: Guard does not include early return")
			issues += 1

	# ── Summary ──────────────────────────────────────────
	print("\n──────────────────────────────────────────────────")
	if issues == 0:
		print("  ✅  ALL CHECKS PASSED  (%d tests)" % 4)
	else:
		print("  ❌  %d CHECK(S) FAILED" % issues)
	print("──────────────────────────────────────────────────\n")
