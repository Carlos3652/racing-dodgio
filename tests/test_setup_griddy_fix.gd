@tool
extends EditorScript
## Double-Await & Silent No-Op Frame Fix — Verification Script
##
## Run from the Godot editor: File → Run Script  (select this file)
##
## Validates that:
## 1. _setup_griddy no longer contains `await` (not a coroutine)
## 2. griddy_kid.frame=0 is done via _reset_griddy_frame (type-safe)
## 3. _griddy_layout_step deferred helper exists
## 4. sprite_2d.gd also uses the safe frame-set pattern

func _run() -> void:
	print("\n══════════════════════════════════════════════════")
	print("  DOUBLE-AWAIT & GRIDDY FRAME FIX VERIFICATION")
	print("══════════════════════════════════════════════════\n")

	var issues := 0

	# ── Load sources ────────────────────────────────────────
	var rm_src := FileAccess.get_file_as_string("res://race_manager.gd")
	if rm_src.is_empty():
		print("  ✗ FAIL: Could not read race_manager.gd")
		return

	var sp_src := FileAccess.get_file_as_string("res://sprite_2d.gd")
	if sp_src.is_empty():
		print("  ✗ FAIL: Could not read sprite_2d.gd")
		return

	# ── 1. _setup_griddy must NOT contain await ────────────
	# Extract the body of _setup_griddy (up to next top-level func)
	var setup_start := rm_src.find("func _setup_griddy()")
	var setup_end := rm_src.find("\nfunc ", setup_start + 1)
	if setup_start < 0:
		print("  ✗ FAIL: func _setup_griddy() not found")
		issues += 1
	else:
		var setup_body := rm_src.substr(setup_start, setup_end - setup_start) if setup_end > 0 else rm_src.substr(setup_start)
		if setup_body.find("await") < 0:
			print("  ✓  _setup_griddy contains no await — not a coroutine")
		else:
			print("  ✗ FAIL: _setup_griddy still contains await — makes _ready a coroutine")
			issues += 1

	# ── 2. _reset_griddy_frame helper exists ────────────────
	if rm_src.find("func _reset_griddy_frame()") >= 0:
		print("  ✓  _reset_griddy_frame() helper exists")
	else:
		print("  ✗ FAIL: _reset_griddy_frame() helper not found")
		issues += 1

	# ── 3. _reset_griddy_frame uses property guard ─────────
	if rm_src.find('"frame" in griddy_kid') >= 0:
		print("  ✓  _reset_griddy_frame guards with '\"frame\" in griddy_kid'")
	else:
		print("  ✗ FAIL: _reset_griddy_frame missing property guard")
		issues += 1

	# ── 4. _reset_griddy_frame uses .set() for type safety ─
	if rm_src.find('griddy_kid.set("frame", 0)') >= 0:
		print("  ✓  Uses griddy_kid.set(\"frame\", 0) for type-safe assignment")
	else:
		print("  ✗ FAIL: Missing type-safe .set(\"frame\", 0) call")
		issues += 1

	# ── 5. No bare griddy_kid.frame = 0 remains ───────────
	# (should all go through _reset_griddy_frame now)
	var bare_pattern := "griddy_kid.frame"
	var bare_idx := rm_src.find(bare_pattern)
	# Skip occurrences in comments
	var has_bare := false
	while bare_idx >= 0:
		# Find start of line
		var line_start := rm_src.rfind("\n", bare_idx) + 1
		var line := rm_src.substr(line_start, bare_idx - line_start)
		if line.strip_edges().begins_with("#") or line.strip_edges().begins_with("##"):
			bare_idx = rm_src.find(bare_pattern, bare_idx + 1)
			continue
		has_bare = true
		break
	if not has_bare:
		print("  ✓  No bare griddy_kid.frame assignment in race_manager.gd")
	else:
		print("  ✗ FAIL: Bare griddy_kid.frame assignment still exists")
		issues += 1

	# ── 6. _griddy_layout_step deferred helper exists ──────
	if rm_src.find("func _griddy_layout_step(") >= 0:
		print("  ✓  _griddy_layout_step deferred helper exists")
	else:
		print("  ✗ FAIL: _griddy_layout_step deferred helper not found")
		issues += 1

	# ── 7. _griddy_layout_step does NOT contain await ──────
	var step_start := rm_src.find("func _griddy_layout_step(")
	if step_start >= 0:
		var step_end := rm_src.find("\nfunc ", step_start + 1)
		var step_body := rm_src.substr(step_start, step_end - step_start) if step_end > 0 else rm_src.substr(step_start)
		if step_body.find("await") < 0:
			print("  ✓  _griddy_layout_step contains no await")
		else:
			print("  ✗ FAIL: _griddy_layout_step still contains await")
			issues += 1

	# ── 8. Layout step uses CONNECT_ONE_SHOT ───────────────
	if rm_src.find("CONNECT_ONE_SHOT") >= 0:
		print("  ✓  Uses CONNECT_ONE_SHOT for deferred callbacks")
	else:
		print("  ✗ FAIL: Missing CONNECT_ONE_SHOT — signal could fire repeatedly")
		issues += 1

	# ── 9. _on_griddy_finished calls _reset_griddy_frame ──
	var fin_start := rm_src.find("func _on_griddy_finished(")
	if fin_start >= 0:
		var fin_end := rm_src.find("\nfunc ", fin_start + 1)
		var fin_body := rm_src.substr(fin_start, fin_end - fin_start) if fin_end > 0 else rm_src.substr(fin_start)
		if fin_body.find("_reset_griddy_frame()") >= 0:
			print("  ✓  _on_griddy_finished uses _reset_griddy_frame()")
		else:
			print("  ✗ FAIL: _on_griddy_finished does not call _reset_griddy_frame()")
			issues += 1

	# ── 10. sprite_2d.gd uses safe frame-set pattern ──────
	if sp_src.find('"frame" in') >= 0 and sp_src.find('.set("frame", 0)') >= 0:
		print("  ✓  sprite_2d.gd uses guarded .set(\"frame\", 0)")
	else:
		print("  ✗ FAIL: sprite_2d.gd still uses bare .frame = 0")
		issues += 1

	# ── 11. _ready does NOT await _setup_griddy ────────────
	var ready_start := rm_src.find("func _ready()")
	if ready_start >= 0:
		var ready_end := rm_src.find("\nfunc ", ready_start + 1)
		var ready_body := rm_src.substr(ready_start, ready_end - ready_start) if ready_end > 0 else rm_src.substr(ready_start)
		if ready_body.find("await") < 0:
			print("  ✓  _ready contains no await — synchronous initialization")
		else:
			print("  ✗ FAIL: _ready contains await — coroutine breaks init order")
			issues += 1

	# ── Summary ─────────────────────────────────────────────
	print("\n══════════════════════════════════════════════════")
	if issues == 0:
		print("  ALL %d CHECKS PASSED ✓" % 11)
	else:
		print("  %d ISSUE(S) FOUND — %d/%d checks passed" % [issues, 11 - issues, 11])
	print("══════════════════════════════════════════════════\n")
