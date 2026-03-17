@tool
extends EditorScript
## Record-Race Guard — Verification Script
##
## Run from the Godot editor: File → Run Script  (select this file)
##
## Validates that:
##   1. record_race() has been moved OUT of _build_results()
##   2. _record_race_once() exists and is called in _ready()
##   3. _record_race_once() uses the _race_recorded guard
##   4. _build_results() no longer calls Records.record_race()
##   5. _get_player_position() helper exists
##   6. _is_pb and _prev_best instance vars are declared

func _run() -> void:
	print("\n══════════════════════════════════════════════════")
	print("  RECORD-RACE GUARD VERIFICATION")
	print("══════════════════════════════════════════════════\n")

	var issues := 0

	# ── 1. Load results.gd source ──────────────────────────
	var src_path := "res://results.gd"
	var src := FileAccess.get_file_as_string(src_path)
	if src.is_empty():
		print("  ✗ FAIL: Could not read %s" % src_path)
		return

	# ── 2. _record_race_once() function exists ────────────
	if src.find("func _record_race_once()") >= 0:
		print("  ✓  _record_race_once() function exists")
	else:
		print("  ✗ FAIL: _record_race_once() function not found")
		issues += 1

	# ── 3. _ready() calls _record_race_once() ─────────────
	# Extract _ready body (up to next top-level func)
	var ready_start := src.find("func _ready()")
	var ready_end := src.find("\nfunc ", ready_start + 1)
	if ready_start >= 0 and ready_end >= 0:
		var ready_body := src.substr(ready_start, ready_end - ready_start)
		if ready_body.find("_record_race_once()") >= 0:
			print("  ✓  _ready() calls _record_race_once()")
		else:
			print("  ✗ FAIL: _ready() does not call _record_race_once()")
			issues += 1
	else:
		print("  ✗ FAIL: Could not locate _ready() function body")
		issues += 1

	# ── 4. _record_race_once() uses _race_recorded guard ──
	var guard_start := src.find("func _record_race_once()")
	var guard_end := src.find("\nfunc ", guard_start + 1) if guard_start >= 0 else -1
	if guard_start >= 0 and guard_end >= 0:
		var guard_body := src.substr(guard_start, guard_end - guard_start)
		if guard_body.find("_race_recorded") >= 0:
			print("  ✓  _record_race_once() checks _race_recorded guard")
		else:
			print("  ✗ FAIL: _record_race_once() missing _race_recorded guard")
			issues += 1
		if guard_body.find("Records.record_race(") >= 0:
			print("  ✓  _record_race_once() calls Records.record_race()")
		else:
			print("  ✗ FAIL: _record_race_once() does not call Records.record_race()")
			issues += 1
	else:
		print("  ✗ FAIL: Could not locate _record_race_once() body")
		issues += 2

	# ── 5. _build_results() does NOT call Records.record_race ──
	var build_start := src.find("func _build_results()")
	var build_end := src.find("\nfunc ", build_start + 1) if build_start >= 0 else -1
	if build_start >= 0 and build_end >= 0:
		var build_body := src.substr(build_start, build_end - build_start)
		if build_body.find("Records.record_race(") < 0:
			print("  ✓  _build_results() does NOT call Records.record_race()")
		else:
			print("  ✗ FAIL: _build_results() still calls Records.record_race() — double-record risk!")
			issues += 1
		# Also verify it no longer calls Records.get_best_time directly
		if build_body.find("Records.get_best_time(") < 0:
			print("  ✓  _build_results() uses cached _prev_best (no direct Records call)")
		else:
			print("  ⚠  WARNING: _build_results() still calls Records.get_best_time() directly")
	else:
		print("  ✗ FAIL: Could not locate _build_results() body")
		issues += 1

	# ── 6. _get_player_position() helper exists ───────────
	if src.find("func _get_player_position(") >= 0:
		print("  ✓  _get_player_position() helper exists")
	else:
		print("  ✗ FAIL: _get_player_position() helper not found")
		issues += 1

	# ── 7. Instance variables _is_pb and _prev_best declared ──
	if src.find("var _is_pb") >= 0:
		print("  ✓  var _is_pb declared")
	else:
		print("  ✗ FAIL: var _is_pb not declared")
		issues += 1

	if src.find("var _prev_best") >= 0:
		print("  ✓  var _prev_best declared")
	else:
		print("  ✗ FAIL: var _prev_best not declared")
		issues += 1

	# ── 8. _build_results uses _is_pb and _prev_best ─────
	if build_start >= 0 and build_end >= 0:
		var build_body2 := src.substr(build_start, build_end - build_start)
		if build_body2.find("_is_pb") >= 0:
			print("  ✓  _build_results() references _is_pb")
		else:
			print("  ✗ FAIL: _build_results() does not reference _is_pb")
			issues += 1
		if build_body2.find("_prev_best") >= 0:
			print("  ✓  _build_results() references _prev_best")
		else:
			print("  ✗ FAIL: _build_results() does not reference _prev_best")
			issues += 1

	# ── Summary ─────────────────────────────────────────────
	print("\n══════════════════════════════════════════════════")
	if issues == 0:
		print("  ALL CHECKS PASSED (%d assertions)" % 10)
	else:
		print("  %d ISSUE(S) FOUND" % issues)
	print("══════════════════════════════════════════════════\n")
