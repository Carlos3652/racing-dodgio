@tool
extends EditorScript
## Star Collect Particle Burst — Verification Script
##
## Run from the Godot editor: File → Run Script  (select this file)
##
## Validates that the particle burst effect in race_manager.gd is correctly
## configured: particle count, colors, fade duration, queue_free, draw calls.

func _run() -> void:
	print("\n══════════════════════════════════════════════════")
	print("  STAR COLLECT PARTICLE BURST VERIFICATION")
	print("══════════════════════════════════════════════════\n")

	var issues := 0

	# ── 1. Load and parse race_manager.gd source ─────────────────
	var script_path := "res://race_manager.gd"
	var src := FileAccess.get_file_as_string(script_path)
	if src.is_empty():
		print("  ✗ FAIL: Could not read %s" % script_path)
		return

	print("  Source loaded: %s (%d chars)" % [script_path, src.length()])

	# ── 2. _CollectBurst inner class exists ──────────────────────
	var class_idx := src.find("class _CollectBurst")
	if class_idx < 0:
		print("  ✗ FAIL: class _CollectBurst not found in source")
		issues += 1
	else:
		print("  ✓  _CollectBurst inner class found")

	# ── 3. Extends Node2D ────────────────────────────────────────
	if src.find("_CollectBurst extends Node2D") >= 0:
		print("  ✓  _CollectBurst extends Node2D")
	else:
		print("  ✗ FAIL: _CollectBurst does not extend Node2D")
		issues += 1

	# ── 4. Particle count is 12-16 ──────────────────────────────
	var count_idx := src.find("PARTICLE_COUNT")
	if count_idx >= 0:
		var count_section := src.substr(count_idx, 40)
		var found_valid_count := false
		for n in range(12, 17):
			if count_section.find(str(n)) >= 0:
				found_valid_count = true
				print("  ✓  PARTICLE_COUNT = %d (within 12-16 range)" % n)
				break
		if not found_valid_count:
			print("  ✗ FAIL: PARTICLE_COUNT not in 12-16 range")
			issues += 1
	else:
		print("  ✗ FAIL: PARTICLE_COUNT constant not found")
		issues += 1

	# ── 5. Required colors present ───────────────────────────────
	var has_gold := src.find("FFD740") >= 0
	var has_white := src.find("1, 1, 1") >= 0 or src.find("1.0, 1.0, 1.0") >= 0 or src.find("FFFFFF") >= 0
	var has_cyan := src.find("00E5FF") >= 0
	if has_gold and has_white and has_cyan:
		print("  ✓  All 3 burst colors present (gold #FFD740, white, cyan #00E5FF)")
	else:
		var missing := []
		if not has_gold: missing.append("gold #FFD740")
		if not has_white: missing.append("white")
		if not has_cyan: missing.append("cyan #00E5FF")
		print("  ✗ FAIL: Missing burst colors: %s" % ", ".join(missing))
		issues += 1

	# ── 6. Fade duration is 0.5s ────────────────────────────────
	var has_duration := src.find("BURST_DURATION") >= 0
	var has_05 := false
	if has_duration:
		var dur_idx := src.find("BURST_DURATION")
		var dur_section := src.substr(dur_idx, 40)
		has_05 = dur_section.find("0.5") >= 0
	if has_05:
		print("  ✓  BURST_DURATION = 0.5 seconds")
	else:
		print("  ✗ FAIL: BURST_DURATION not set to 0.5")
		issues += 1

	# ── 7. Uses Tween for alpha fade ────────────────────────────
	# Check that there's a tween on _alpha within the class
	if class_idx >= 0:
		var class_body := src.substr(class_idx, 1200)
		if class_body.find("create_tween") >= 0 and class_body.find("_alpha") >= 0:
			print("  ✓  Tween used to fade _alpha")
		else:
			print("  ✗ FAIL: No tween-based alpha fade found in _CollectBurst")
			issues += 1
	else:
		print("  ✗ SKIP: Cannot check tween (class not found)")
		issues += 1

	# ── 8. queue_free called after animation ────────────────────
	if class_idx >= 0:
		var class_body := src.substr(class_idx, 1200)
		if class_body.find("queue_free") >= 0:
			print("  ✓  queue_free() called to auto-free node after animation")
		else:
			print("  ✗ FAIL: queue_free() not found in _CollectBurst")
			issues += 1
	else:
		print("  ✗ SKIP: Cannot check queue_free (class not found)")
		issues += 1

	# ── 9. Particles drawn with draw_rect or draw_circle ────────
	if class_idx >= 0:
		var class_body := src.substr(class_idx, 1200)
		if class_body.find("draw_rect") >= 0 or class_body.find("draw_circle") >= 0:
			print("  ✓  Particles drawn with draw_rect/draw_circle")
		else:
			print("  ✗ FAIL: No draw_rect or draw_circle in _CollectBurst._draw()")
			issues += 1
	else:
		print("  ✗ SKIP: Cannot check draw calls (class not found)")
		issues += 1

	# ── 10. Radial launch (uses cos/sin for direction) ──────────
	if class_idx >= 0:
		var class_body := src.substr(class_idx, 1200)
		if class_body.find("cos") >= 0 and class_body.find("sin") >= 0:
			print("  ✓  Radial outward launch using cos/sin")
		else:
			print("  ✗ FAIL: No cos/sin found — particles may not launch radially")
			issues += 1
	else:
		print("  ✗ SKIP: Cannot check radial launch (class not found)")
		issues += 1

	# ── 11. _sparkle_at creates _CollectBurst ────────────────────
	var sparkle_idx := src.find("func _sparkle_at")
	if sparkle_idx >= 0:
		var sparkle_body := src.substr(sparkle_idx, 200)
		if sparkle_body.find("_CollectBurst") >= 0:
			print("  ✓  _sparkle_at() creates a _CollectBurst node")
		else:
			print("  ✗ FAIL: _sparkle_at() does not reference _CollectBurst")
			issues += 1
	else:
		print("  ✗ FAIL: func _sparkle_at not found")
		issues += 1

	# ── 12. _sparkle_at sets z_index ─────────────────────────────
	if sparkle_idx >= 0:
		var sparkle_body := src.substr(sparkle_idx, 200)
		if sparkle_body.find("z_index") >= 0:
			print("  ✓  _sparkle_at() sets z_index on burst node")
		else:
			print("  ✗ FAIL: _sparkle_at() does not set z_index")
			issues += 1
	else:
		print("  ✗ SKIP: Cannot check z_index (sparkle_at not found)")
		issues += 1

	# ── 13. Particle size in 3-5px range ─────────────────────────
	if class_idx >= 0:
		var class_body := src.substr(class_idx, 1200)
		if class_body.find("3.0") >= 0 and class_body.find("5.0") >= 0:
			print("  ✓  Particle size range 3-5px present")
		else:
			print("  ✗ FAIL: Particle size not in 3-5px range")
			issues += 1
	else:
		print("  ✗ SKIP: Cannot check particle size (class not found)")
		issues += 1

	# ── 14. queue_redraw called for continuous animation ─────────
	if class_idx >= 0:
		var class_body := src.substr(class_idx, 1200)
		if class_body.find("queue_redraw") >= 0:
			print("  ✓  queue_redraw() called for continuous animation")
		else:
			print("  ✗ FAIL: No queue_redraw — particles won't animate")
			issues += 1
	else:
		print("  ✗ SKIP: Cannot check queue_redraw (class not found)")
		issues += 1

	# ── Summary ────────────────────────────────────────────────
	print("\n══════════════════════════════════════════════════")
	if issues == 0:
		print("  ✅  ALL CHECKS PASSED — particle burst effect is correct")
	else:
		print("  ✗  %d issue(s) found — see details above" % issues)
	print("══════════════════════════════════════════════════\n")
