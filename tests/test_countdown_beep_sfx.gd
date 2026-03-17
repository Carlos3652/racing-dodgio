@tool
extends EditorScript
## Countdown Beep Sound Effects — Verification Script
##
## Run from the Godot editor: File → Run Script  (select this file)
##
## Validates that countdown beep audio is correctly wired:
## - WAV files exist in audio/ with correct RIFF/WAVE headers
## - AudioStreamPlayer nodes declared in main.tscn
## - race_manager.gd references and triggers them properly

func _run() -> void:
	print("\n══════════════════════════════════════════════════")
	print("  COUNTDOWN BEEP SOUND EFFECTS VERIFICATION")
	print("══════════════════════════════════════════════════\n")

	var issues := 0
	var checks := 0

	# ── 1. countdown_beep.wav exists and is a valid WAV ─────────
	checks += 1
	var beep_path := "res://audio/countdown_beep.wav"
	if FileAccess.file_exists(beep_path):
		var f := FileAccess.open(beep_path, FileAccess.READ)
		var header := f.get_buffer(12)
		f.close()
		if header.size() >= 12 and header.slice(0, 4).get_string_from_ascii() == "RIFF" and header.slice(8, 12).get_string_from_ascii() == "WAVE":
			print("  ✓  countdown_beep.wav exists and has valid RIFF/WAVE header")
		else:
			print("  ✗ FAIL: countdown_beep.wav is not a valid WAV file")
			issues += 1
	else:
		print("  ✗ FAIL: countdown_beep.wav not found at %s" % beep_path)
		issues += 1

	# ── 2. countdown_go.wav exists and is a valid WAV ───────────
	checks += 1
	var go_path := "res://audio/countdown_go.wav"
	if FileAccess.file_exists(go_path):
		var f := FileAccess.open(go_path, FileAccess.READ)
		var header := f.get_buffer(12)
		f.close()
		if header.size() >= 12 and header.slice(0, 4).get_string_from_ascii() == "RIFF" and header.slice(8, 12).get_string_from_ascii() == "WAVE":
			print("  ✓  countdown_go.wav exists and has valid RIFF/WAVE header")
		else:
			print("  ✗ FAIL: countdown_go.wav is not a valid WAV file")
			issues += 1
	else:
		print("  ✗ FAIL: countdown_go.wav not found at %s" % go_path)
		issues += 1

	# ── 3-6. main.tscn has countdown audio nodes ─────────────────
	var tscn_path := "res://main.tscn"
	var tscn_src := FileAccess.get_file_as_string(tscn_path)
	if tscn_src.is_empty():
		print("  ✗ FAIL: Could not read %s" % tscn_path)
		issues += 4
		checks += 4
	else:
		checks += 1
		if tscn_src.find("CountdownBeepAudio") >= 0 and tscn_src.find("AudioStreamPlayer") >= 0:
			print("  ✓  CountdownBeepAudio AudioStreamPlayer node found in main.tscn")
		else:
			print("  ✗ FAIL: CountdownBeepAudio node not found in main.tscn")
			issues += 1

		checks += 1
		if tscn_src.find("CountdownGoAudio") >= 0:
			print("  ✓  CountdownGoAudio AudioStreamPlayer node found in main.tscn")
		else:
			print("  ✗ FAIL: CountdownGoAudio node not found in main.tscn")
			issues += 1

		checks += 1
		if tscn_src.find("countdown_beep.wav") >= 0:
			print("  ✓  countdown_beep.wav referenced in main.tscn")
		else:
			print("  ✗ FAIL: countdown_beep.wav not referenced in main.tscn")
			issues += 1

		checks += 1
		if tscn_src.find("countdown_go.wav") >= 0:
			print("  ✓  countdown_go.wav referenced in main.tscn")
		else:
			print("  ✗ FAIL: countdown_go.wav not referenced in main.tscn")
			issues += 1

	# ── 7-12. race_manager.gd checks ─────────────────────────────
	var mgr_path := "res://race_manager.gd"
	var mgr_src := FileAccess.get_file_as_string(mgr_path)
	if mgr_src.is_empty():
		print("  ✗ FAIL: Could not read %s" % mgr_path)
		issues += 6
		checks += 6
	else:
		checks += 1
		if mgr_src.find("cd_beep_sfx") >= 0:
			print("  ✓  cd_beep_sfx variable declared in race_manager.gd")
		else:
			print("  ✗ FAIL: cd_beep_sfx not found in race_manager.gd")
			issues += 1

		checks += 1
		if mgr_src.find("cd_go_sfx") >= 0:
			print("  ✓  cd_go_sfx variable declared in race_manager.gd")
		else:
			print("  ✗ FAIL: cd_go_sfx not found in race_manager.gd")
			issues += 1

		# ── 9. _setup_audio binds countdown audio nodes ──────────
		checks += 1
		var setup_idx := mgr_src.find("func _setup_audio")
		if setup_idx >= 0:
			var setup_body := mgr_src.substr(setup_idx, 400)
			if setup_body.find("cd_beep_sfx") >= 0 and setup_body.find("CountdownBeepAudio") >= 0:
				print("  ✓  cd_beep_sfx bound to CountdownBeepAudio in _setup_audio()")
			else:
				print("  ✗ FAIL: cd_beep_sfx not bound in _setup_audio()")
				issues += 1
		else:
			print("  ✗ FAIL: _setup_audio function not found")
			issues += 1

		checks += 1
		if setup_idx >= 0:
			var setup_body := mgr_src.substr(setup_idx, 400)
			if setup_body.find("cd_go_sfx") >= 0 and setup_body.find("CountdownGoAudio") >= 0:
				print("  ✓  cd_go_sfx bound to CountdownGoAudio in _setup_audio()")
			else:
				print("  ✗ FAIL: cd_go_sfx not bound in _setup_audio()")
				issues += 1

		# ── 11. cd_beep_sfx.play() called during countdown digits ─
		checks += 1
		var cd_section := mgr_src.find("State.COUNTDOWN")
		if cd_section >= 0:
			var cd_body := mgr_src.substr(cd_section, 500)
			if cd_body.find("cd_beep_sfx.play()") >= 0:
				print("  ✓  cd_beep_sfx.play() triggered during countdown digits")
			else:
				print("  ✗ FAIL: cd_beep_sfx.play() not found in COUNTDOWN state")
				issues += 1
		else:
			print("  ✗ FAIL: State.COUNTDOWN not found in race_manager.gd")
			issues += 1

		# ── 12. cd_go_sfx.play() called for GO ────────────────────
		checks += 1
		if cd_section >= 0:
			var cd_body := mgr_src.substr(cd_section, 500)
			if cd_body.find("cd_go_sfx.play()") >= 0:
				print("  ✓  cd_go_sfx.play() triggered for GO!")
			else:
				print("  ✗ FAIL: cd_go_sfx.play() not found in COUNTDOWN state")
				issues += 1

	# ── Summary ────────────────────────────────────────────────
	print("\n══════════════════════════════════════════════════")
	if issues == 0:
		print("  ✅  ALL %d CHECKS PASSED — countdown beep SFX are correctly wired" % checks)
	else:
		print("  ✗  %d issue(s) found out of %d checks — see details above" % [issues, checks])
	print("══════════════════════════════════════════════════\n")
