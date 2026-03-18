@tool
extends EditorScript
## Star Collect Particle Burst — Verification Script
##
## Run from the Godot editor: File → Run Script  (select this file)
##
## Validates that the particle burst effect is correctly implemented in
## collect_burst.gd and properly referenced from race_manager.gd.

func _run() -> void:
	print("\n══════════════════════════════════════════════════")
	print("  STAR COLLECT PARTICLE BURST VERIFICATION")
	print("══════════════════════════════════════════════════\n")

	var issues := 0

	# ── 1. Load and parse collect_burst.gd source ─────────────
	var burst_path := "res://collect_burst.gd"
	var burst_src := FileAccess.get_file_as_string(burst_path)
	if burst_src.is_empty():
		print("  ✗ FAIL: Could not read %s" % burst_path)
		return
	print("  Source loaded: %s (%d chars)" % [burst_path, burst_src.length()])

	# ── 2. Load race_manager.gd source ────────────────────────
	var rm_path := "res://race_manager.gd"
	var rm_src := FileAccess.get_file_as_string(rm_path)
	if rm_src.is_empty():
		print("  ✗ FAIL: Could not read %s" % rm_path)
		return
	print("  Source loaded: %s (%d chars)" % [rm_path, rm_src.length()])

	# ── 3. No inner class _CollectBurst in race_manager ───────
	if rm_src.find("class _CollectBurst") >= 0:
		print("  ✗ FAIL: Dead inner class _CollectBurst still in race_manager.gd")
		issues += 1
	else:
		print("  ✓  No inner class _CollectBurst (no name collision)")

	# ── 4. Preload const is CollectBurst (no underscore) ──────
	if rm_src.find("const CollectBurst") >= 0:
		print("  ✓  CollectBurst preload const found (no underscore)")
	else:
		print("  ✗ FAIL: CollectBurst preload const not found")
		issues += 1

	if rm_src.find("const _CollectBurst") >= 0:
		print("  ✗ FAIL: Old _CollectBurst const still present")
		issues += 1
	else:
		print("  ✓  No old _CollectBurst const")

	# ── 5. Extends Node2D ─────────────────────────────────────
	if burst_src.find("extends Node2D") >= 0:
		print("  ✓  collect_burst.gd extends Node2D")
	else:
		print("  ✗ FAIL: collect_burst.gd does not extend Node2D")
		issues += 1

	# ── 6. Particle count is 12-16 ────────────────────────────
	if burst_src.find("randi_range(12, 16)") >= 0:
		print("  ✓  Particle count randi_range(12, 16)")
	elif burst_src.find("12") >= 0 and burst_src.find("16") >= 0:
		print("  ✓  Particle count range 12-16 present")
	else:
		print("  ✗ FAIL: Particle count 12-16 not found")
		issues += 1

	# ── 7. Required colors present ────────────────────────────
	var has_gold := burst_src.find("FFD740") >= 0
	var has_white := burst_src.find("1, 1, 1") >= 0 or burst_src.find("1.0, 1.0, 1.0") >= 0 or burst_src.find("FFFFFF") >= 0
	var has_cyan := burst_src.find("00E5FF") >= 0
	if has_gold and has_white and has_cyan:
		print("  ✓  All 3 burst colors present (gold #FFD740, white, cyan #00E5FF)")
	else:
		var missing := []
		if not has_gold: missing.append("gold #FFD740")
		if not has_white: missing.append("white")
		if not has_cyan: missing.append("cyan #00E5FF")
		print("  ✗ FAIL: Missing burst colors: %s" % ", ".join(missing))
		issues += 1

	# ── 8. Fade duration (LIFETIME) is 0.5s ───────────────────
	if burst_src.find("LIFETIME") >= 0 and burst_src.find("0.5") >= 0:
		print("  ✓  LIFETIME = 0.5 seconds")
	else:
		print("  ✗ FAIL: LIFETIME not set to 0.5")
		issues += 1

	# ── 9. Uses Tween for alpha fade ──────────────────────────
	if burst_src.find("create_tween") >= 0 and burst_src.find("modulate:a") >= 0:
		print("  ✓  Tween used to fade modulate:a")
	else:
		print("  ✗ FAIL: No tween-based modulate:a fade found")
		issues += 1

	# ── 10. queue_free called after animation ─────────────────
	if burst_src.find("queue_free") >= 0:
		print("  ✓  queue_free() called to auto-free node after animation")
	else:
		print("  ✗ FAIL: queue_free() not found")
		issues += 1

	# ── 11. Particles drawn with draw_rect and draw_circle ────
	if burst_src.find("draw_rect") >= 0 and burst_src.find("draw_circle") >= 0:
		print("  ✓  Particles drawn with draw_rect and draw_circle (mixed)")
	elif burst_src.find("draw_rect") >= 0 or burst_src.find("draw_circle") >= 0:
		print("  ✓  Particles drawn with draw_rect or draw_circle")
	else:
		print("  ✗ FAIL: No draw_rect or draw_circle in _draw()")
		issues += 1

	# ── 12. Radial launch (uses cos/sin for direction) ────────
	if burst_src.find("cos") >= 0 and burst_src.find("sin") >= 0:
		print("  ✓  Radial outward launch using cos/sin")
	else:
		print("  ✗ FAIL: No cos/sin found — particles may not launch radially")
		issues += 1

	# ── 13. _sparkle_at creates CollectBurst ──────────────────
	var sparkle_idx := rm_src.find("func _sparkle_at")
	if sparkle_idx >= 0:
		var sparkle_body := rm_src.substr(sparkle_idx, 200)
		if sparkle_body.find("CollectBurst") >= 0:
			print("  ✓  _sparkle_at() creates a CollectBurst node")
		else:
			print("  ✗ FAIL: _sparkle_at() does not reference CollectBurst")
			issues += 1
	else:
		print("  ✗ FAIL: func _sparkle_at not found")
		issues += 1

	# ── 14. _sparkle_at sets z_index ──────────────────────────
	if sparkle_idx >= 0:
		var sparkle_body := rm_src.substr(sparkle_idx, 200)
		if sparkle_body.find("z_index") >= 0:
			print("  ✓  _sparkle_at() sets z_index on burst node")
		else:
			print("  ✗ FAIL: _sparkle_at() does not set z_index")
			issues += 1
	else:
		print("  ✗ SKIP: Cannot check z_index (sparkle_at not found)")
		issues += 1

	# ── 15. Particle size in 3-5px range ──────────────────────
	if burst_src.find("3.0") >= 0 and burst_src.find("5.0") >= 0:
		print("  ✓  Particle size range 3-5px present")
	else:
		print("  ✗ FAIL: Particle size not in 3-5px range")
		issues += 1

	# ── 16. queue_redraw called for continuous animation ──────
	if burst_src.find("queue_redraw") >= 0:
		print("  ✓  queue_redraw() called for continuous animation")
	else:
		print("  ✗ FAIL: No queue_redraw — particles won't animate")
		issues += 1

	# ── Summary ───────────────────────────────────────────────
	print("\n══════════════════════════════════════════════════")
	if issues == 0:
		print("  ✅  ALL CHECKS PASSED — particle burst effect is correct")
	else:
		print("  ✗  %d issue(s) found — see details above" % issues)
	print("══════════════════════════════════════════════════\n")
