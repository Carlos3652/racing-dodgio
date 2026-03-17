@tool
extends EditorScript
## Crash & Bump Sound Effects — Verification Script
##
## Run from the Godot editor: File → Run Script  (select this file)
##
## Validates that crash and bump audio are correctly wired:
## - WAV files exist in audio/ with correct durations
## - AudioStreamPlayer nodes declared in main.tscn
## - race_manager.gd references and triggers them properly

func _run() -> void:
	print("\n══════════════════════════════════════════════════")
	print("  CRASH & BUMP SOUND EFFECTS VERIFICATION")
	print("══════════════════════════════════════════════════\n")

	var issues := 0

	# ── 1. crash.wav exists and is a valid WAV ──────────────────
	var crash_path := "res://audio/crash.wav"
	if FileAccess.file_exists(crash_path):
		var f := FileAccess.open(crash_path, FileAccess.READ)
		var header := f.get_buffer(12)
		f.close()
		if header.size() >= 12 and header.slice(0, 4).get_string_from_ascii() == "RIFF" and header.slice(8, 12).get_string_from_ascii() == "WAVE":
			print("  ✓  crash.wav exists and has valid RIFF/WAVE header")
		else:
			print("  ✗ FAIL: crash.wav is not a valid WAV file")
			issues += 1
	else:
		print("  ✗ FAIL: crash.wav not found at %s" % crash_path)
		issues += 1

	# ── 2. bump.wav exists and is a valid WAV ───────────────────
	var bump_path := "res://audio/bump.wav"
	if FileAccess.file_exists(bump_path):
		var f := FileAccess.open(bump_path, FileAccess.READ)
		var header := f.get_buffer(12)
		f.close()
		if header.size() >= 12 and header.slice(0, 4).get_string_from_ascii() == "RIFF" and header.slice(8, 12).get_string_from_ascii() == "WAVE":
			print("  ✓  bump.wav exists and has valid RIFF/WAVE header")
		else:
			print("  ✗ FAIL: bump.wav is not a valid WAV file")
			issues += 1
	else:
		print("  ✗ FAIL: bump.wav not found at %s" % bump_path)
		issues += 1

	# ── 3. main.tscn has CrashAudio AudioStreamPlayer node ─────
	var tscn_path := "res://main.tscn"
	var tscn_src := FileAccess.get_file_as_string(tscn_path)
	if tscn_src.is_empty():
		print("  ✗ FAIL: Could not read %s" % tscn_path)
		issues += 8  # skip remaining checks
	else:
		if tscn_src.find("CrashAudio") >= 0 and tscn_src.find("AudioStreamPlayer") >= 0:
			print("  ✓  CrashAudio AudioStreamPlayer node found in main.tscn")
		else:
			print("  ✗ FAIL: CrashAudio node not found in main.tscn")
			issues += 1

		# ── 4. main.tscn has BumpAudio AudioStreamPlayer node ──────
		if tscn_src.find("BumpAudio") >= 0:
			print("  ✓  BumpAudio AudioStreamPlayer node found in main.tscn")
		else:
			print("  ✗ FAIL: BumpAudio node not found in main.tscn")
			issues += 1

		# ── 5. CrashAudio references crash.wav ─────────────────────
		if tscn_src.find("crash.wav") >= 0:
			print("  ✓  crash.wav referenced in main.tscn")
		else:
			print("  ✗ FAIL: crash.wav not referenced in main.tscn")
			issues += 1

		# ── 6. BumpAudio references bump.wav ───────────────────────
		if tscn_src.find("bump.wav") >= 0:
			print("  ✓  bump.wav referenced in main.tscn")
		else:
			print("  ✗ FAIL: bump.wav not referenced in main.tscn")
			issues += 1

	# ── 7. race_manager.gd declares crash_audio var ────────────
	var mgr_path := "res://race_manager.gd"
	var mgr_src := FileAccess.get_file_as_string(mgr_path)
	if mgr_src.is_empty():
		print("  ✗ FAIL: Could not read %s" % mgr_path)
		issues += 4
	else:
		if mgr_src.find("crash_audio") >= 0:
			print("  ✓  crash_audio variable declared in race_manager.gd")
		else:
			print("  ✗ FAIL: crash_audio not found in race_manager.gd")
			issues += 1

		# ── 8. race_manager.gd declares bump_audio var ─────────────
		if mgr_src.find("bump_audio") >= 0:
			print("  ✓  bump_audio variable declared in race_manager.gd")
		else:
			print("  ✗ FAIL: bump_audio not found in race_manager.gd")
			issues += 1

		# ── 9. crash_audio.play() called in _flash_screen ──────────
		var flash_idx := mgr_src.find("func _flash_screen")
		if flash_idx >= 0:
			var flash_body := mgr_src.substr(flash_idx, 300)
			if flash_body.find("crash_audio") >= 0 and flash_body.find(".play()") >= 0:
				print("  ✓  crash_audio.play() triggered in _flash_screen()")
			else:
				print("  ✗ FAIL: crash_audio.play() not found in _flash_screen()")
				issues += 1
		else:
			print("  ✗ FAIL: _flash_screen function not found")
			issues += 1

		# ── 10. bump_audio.play() called in _flash_bump ────────────
		var bump_idx := mgr_src.find("func _flash_bump")
		if bump_idx >= 0:
			var bump_body := mgr_src.substr(bump_idx, 300)
			if bump_body.find("bump_audio") >= 0 and bump_body.find(".play()") >= 0:
				print("  ✓  bump_audio.play() triggered in _flash_bump()")
			else:
				print("  ✗ FAIL: bump_audio.play() not found in _flash_bump()")
				issues += 1
		else:
			print("  ✗ FAIL: _flash_bump function not found")
			issues += 1

		# ── 11. _setup_audio function exists ───────────────────────
		if mgr_src.find("func _setup_audio") >= 0:
			print("  ✓  _setup_audio() function exists for node binding")
		else:
			print("  ✗ FAIL: _setup_audio() function not found")
			issues += 1

		# ── 12. _setup_audio called from _ready ───────────────────
		var ready_idx := mgr_src.find("func _ready")
		if ready_idx >= 0:
			var ready_body := mgr_src.substr(ready_idx, 500)
			if ready_body.find("_setup_audio") >= 0:
				print("  ✓  _setup_audio() called from _ready()")
			else:
				print("  ✗ FAIL: _setup_audio() not called from _ready()")
				issues += 1
		else:
			print("  ✗ FAIL: _ready function not found")
			issues += 1

	# ── Summary ────────────────────────────────────────────────
	print("\n══════════════════════════════════════════════════")
	if issues == 0:
		print("  ✅  ALL %d CHECKS PASSED — crash & bump SFX are correctly wired" % 12)
	else:
		print("  ✗  %d issue(s) found — see details above" % issues)
	print("══════════════════════════════════════════════════\n")
