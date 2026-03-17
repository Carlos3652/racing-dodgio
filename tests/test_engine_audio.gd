@tool
extends EditorScript
## Engine Audio with Speed-Based Pitch Shift — Verification Script
##
## Run from the Godot editor: File → Run Script  (select this file)
##
## Validates that engine audio is correctly wired:
## - engine_loop.wav exists in audio/ with correct RIFF/WAVE header and ~0.5s duration
## - AudioStreamPlayer node (EngineAudio) declared as child of PlayerCar in main.tscn
## - EngineAudio has autoplay enabled and correct volume
## - player_car.gd has engine_audio @onready reference
## - player_car.gd pitch_scale formula: lerp(0.6, 1.6, clampf(abs(speed)/MAX_SPEED, 0.0, 1.0))
## - Engine loops via finished signal reconnect
## - Engine pitch resets to idle (0.6) during crash stun
## - Engine stops when race finishes

func _run() -> void:
	print("\n══════════════════════════════════════════════════")
	print("  ENGINE AUDIO PITCH SHIFT VERIFICATION")
	print("══════════════════════════════════════════════════\n")

	var issues := 0
	var checks := 0

	# ── 1. engine_loop.wav exists and is a valid WAV ──────────────
	checks += 1
	var wav_path := "res://audio/engine_loop.wav"
	if FileAccess.file_exists(wav_path):
		var f := FileAccess.open(wav_path, FileAccess.READ)
		var header := f.get_buffer(12)
		f.close()
		if header.size() >= 12 and header.slice(0, 4).get_string_from_ascii() == "RIFF" and header.slice(8, 12).get_string_from_ascii() == "WAVE":
			print("  ✓  engine_loop.wav exists and has valid RIFF/WAVE header")
		else:
			print("  ✗ FAIL: engine_loop.wav is not a valid WAV file")
			issues += 1
	else:
		print("  ✗ FAIL: engine_loop.wav not found at %s" % wav_path)
		issues += 1

	# ── 2. engine_loop.wav is approximately 0.5 seconds ──────────
	checks += 1
	if FileAccess.file_exists(wav_path):
		var f := FileAccess.open(wav_path, FileAccess.READ)
		var file_size := f.get_length()
		f.close()
		# 16-bit mono 44100 Hz → 44100 * 2 = 88200 bytes/sec → 0.5s ≈ 44100 bytes data + 44 header
		# Accept range: 0.3s to 1.0s → roughly 26000 to 90000 bytes
		if file_size >= 26000 and file_size <= 90000:
			print("  ✓  engine_loop.wav file size %d bytes (reasonable for ~0.5s loop)" % file_size)
		else:
			print("  ✗ FAIL: engine_loop.wav file size %d bytes — expected ~44K for 0.5s" % file_size)
			issues += 1
	else:
		print("  ✗ FAIL: (skipped — file missing)")
		issues += 1

	# ── 3. main.tscn has EngineAudio as child of PlayerCar ───────
	var tscn_path := "res://main.tscn"
	var tscn_src := FileAccess.get_file_as_string(tscn_path)
	if tscn_src.is_empty():
		print("  ✗ FAIL: Could not read %s" % tscn_path)
		issues += 5
		checks += 5
	else:
		checks += 1
		if tscn_src.find("EngineAudio") >= 0 and tscn_src.find("AudioStreamPlayer") >= 0:
			print("  ✓  EngineAudio AudioStreamPlayer node found in main.tscn")
		else:
			print("  ✗ FAIL: EngineAudio AudioStreamPlayer not found in main.tscn")
			issues += 1

		# ── 4. EngineAudio is a child of PlayerCar ────────────────────
		checks += 1
		if tscn_src.find("parent=\"PlayerCar\"") >= 0 and tscn_src.find("EngineAudio") >= 0:
			# Check that EngineAudio specifically has parent=PlayerCar
			var ea_idx := tscn_src.find("EngineAudio")
			if ea_idx >= 0:
				# Look around the EngineAudio declaration
				var start := maxi(0, ea_idx - 100)
				var snippet := tscn_src.substr(start, 200)
				if snippet.find("parent=\"PlayerCar\"") >= 0:
					print("  ✓  EngineAudio is a child of PlayerCar")
				else:
					print("  ✗ FAIL: EngineAudio is not parented to PlayerCar")
					issues += 1
		else:
			print("  ✗ FAIL: EngineAudio not parented to PlayerCar")
			issues += 1

		# ── 5. EngineAudio references engine_loop.wav ─────────────────
		checks += 1
		if tscn_src.find("engine_loop.wav") >= 0:
			print("  ✓  engine_loop.wav referenced in main.tscn")
		else:
			print("  ✗ FAIL: engine_loop.wav not referenced in main.tscn")
			issues += 1

		# ── 6. EngineAudio has autoplay enabled ───────────────────────
		checks += 1
		# Find the EngineAudio node block and check for autoplay
		var ea_idx := tscn_src.find("EngineAudio")
		if ea_idx >= 0:
			var ea_block := tscn_src.substr(ea_idx, 200)
			if ea_block.find("autoplay = true") >= 0:
				print("  ✓  EngineAudio has autoplay = true")
			else:
				print("  ✗ FAIL: EngineAudio does not have autoplay = true")
				issues += 1
		else:
			print("  ✗ FAIL: EngineAudio node not found")
			issues += 1

		# ── 7. EngineAudio has volume_db set ──────────────────────────
		checks += 1
		if ea_idx >= 0:
			var ea_block := tscn_src.substr(ea_idx, 200)
			if ea_block.find("volume_db") >= 0:
				print("  ✓  EngineAudio has volume_db configured")
			else:
				print("  ✗ FAIL: EngineAudio missing volume_db")
				issues += 1

	# ── 8-15. player_car.gd checks ──────────────────────────────
	var pcar_path := "res://player_car.gd"
	var pcar_src := FileAccess.get_file_as_string(pcar_path)
	if pcar_src.is_empty():
		print("  ✗ FAIL: Could not read %s" % pcar_path)
		issues += 8
		checks += 8
	else:
		# ── 8. @onready engine_audio reference ────────────────────────
		checks += 1
		if pcar_src.find("engine_audio") >= 0 and pcar_src.find("$EngineAudio") >= 0:
			print("  ✓  engine_audio @onready reference to $EngineAudio in player_car.gd")
		else:
			print("  ✗ FAIL: engine_audio @onready reference not found")
			issues += 1

		# ── 9. pitch_scale lerp formula with correct range ────────────
		checks += 1
		if pcar_src.find("pitch_scale") >= 0 and pcar_src.find("lerp(0.6, 1.6") >= 0:
			print("  ✓  pitch_scale = lerp(0.6, 1.6, ...) formula present")
		else:
			print("  ✗ FAIL: pitch_scale lerp(0.6, 1.6) formula not found")
			issues += 1

		# ── 10. pitch_scale uses speed/MAX_SPEED ratio ────────────────
		checks += 1
		if pcar_src.find("speed") >= 0 and pcar_src.find("MAX_SPEED") >= 0 and pcar_src.find("pitch_scale") >= 0:
			print("  ✓  pitch_scale uses speed/MAX_SPEED ratio")
		else:
			print("  ✗ FAIL: pitch_scale speed/MAX_SPEED ratio not found")
			issues += 1

		# ── 11. Continuous loop via finished signal ───────────────────
		checks += 1
		if pcar_src.find("finished.connect") >= 0 and pcar_src.find("_on_engine_audio_finished") >= 0:
			print("  ✓  Engine audio loops via finished signal reconnect")
		else:
			print("  ✗ FAIL: Engine audio loop signal not found")
			issues += 1

		# ── 12. _on_engine_audio_finished replays the audio ───────────
		checks += 1
		var loop_idx := pcar_src.find("func _on_engine_audio_finished")
		if loop_idx >= 0:
			var loop_body := pcar_src.substr(loop_idx, 150)
			if loop_body.find("engine_audio.play()") >= 0:
				print("  ✓  _on_engine_audio_finished() calls engine_audio.play()")
			else:
				print("  ✗ FAIL: _on_engine_audio_finished() does not replay audio")
				issues += 1
		else:
			print("  ✗ FAIL: _on_engine_audio_finished() function not found")
			issues += 1

		# ── 13. Engine pitch resets to idle during crash ──────────────
		checks += 1
		var crash_idx := pcar_src.find("crash_time > 0")
		if crash_idx >= 0:
			var crash_block := pcar_src.substr(crash_idx, 200)
			if crash_block.find("pitch_scale") >= 0 and crash_block.find("0.6") >= 0:
				print("  ✓  Engine pitch resets to 0.6 (idle) during crash stun")
			else:
				print("  ✗ FAIL: Engine pitch not reset during crash — audio stays at speed pitch while stunned")
				issues += 1
		else:
			print("  ✗ FAIL: crash_time handling not found")
			issues += 1

		# ── 14. Engine stops at race finish ───────────────────────────
		checks += 1
		var finish_idx := pcar_src.find("func _cross_finish")
		if finish_idx >= 0:
			var finish_body := pcar_src.substr(finish_idx, 200)
			if finish_body.find("engine_audio") >= 0 and finish_body.find("stop()") >= 0:
				print("  ✓  Engine audio stops when race finishes")
			else:
				print("  ✗ FAIL: Engine audio not stopped at race finish")
				issues += 1
		else:
			print("  ✗ FAIL: _cross_finish() function not found")
			issues += 1

		# ── 15. clampf used to prevent pitch overflow ─────────────────
		checks += 1
		if pcar_src.find("clampf") >= 0:
			print("  ✓  clampf() used to clamp speed ratio (prevents pitch overflow during boost)")
		else:
			print("  ✗ FAIL: clampf not used — pitch could exceed 1.6 during boost")
			issues += 1

	# ── Summary ────────────────────────────────────────────────
	print("\n══════════════════════════════════════════════════")
	if issues == 0:
		print("  ✅  ALL %d CHECKS PASSED — engine audio with pitch shift correctly wired" % checks)
	else:
		print("  ✗  %d issue(s) found out of %d checks — see details above" % [issues, checks])
	print("══════════════════════════════════════════════════\n")
