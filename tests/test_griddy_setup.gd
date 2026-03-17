@tool
extends EditorScript
## Verify _setup_griddy() fix: no await, guarded frame access.
## Run via: File → Run Script  (in Godot editor)

func _run() -> void:
	var path = "res://race_manager.gd"
	var src = FileAccess.get_file_as_string(path)
	if src.is_empty():
		printerr("FAIL — could not read %s" % path)
		return

	var passed := 0
	var failed := 0

	# --- helper ---
	var _extract = func(fn_name: String) -> String:
		var pat = "func %s(" % fn_name
		var start = src.find(pat)
		if start < 0:
			return ""
		var next = src.find("\nfunc ", start + 1)
		if next < 0:
			next = src.length()
		return src.substr(start, next - start)

	# 1. _setup_griddy has no await
	var body = _extract.call("_setup_griddy")
	if body.find("await") == -1:
		passed += 1
		print("PASS  _setup_griddy has no await")
	else:
		failed += 1
		printerr("FAIL  _setup_griddy still contains await")

	# 2. _setup_griddy connects to process_frame
	if body.find("process_frame.connect(") >= 0:
		passed += 1
		print("PASS  _setup_griddy uses process_frame signal")
	else:
		failed += 1
		printerr("FAIL  _setup_griddy missing process_frame.connect")

	# 3. _set_griddy_frame exists
	if src.find("func _set_griddy_frame(") >= 0:
		passed += 1
		print("PASS  _set_griddy_frame helper exists")
	else:
		failed += 1
		printerr("FAIL  _set_griddy_frame helper missing")

	# 4. _set_griddy_frame checks type
	var frame_body = _extract.call("_set_griddy_frame")
	if frame_body.find("AnimatedSprite2D") >= 0 and frame_body.find("Sprite2D") >= 0:
		passed += 1
		print("PASS  _set_griddy_frame checks sprite types")
	else:
		failed += 1
		printerr("FAIL  _set_griddy_frame missing type checks")

	# 5. No direct griddy_kid.frame = outside helper
	var outside = src.replace(frame_body, "")
	if outside.find("griddy_kid.frame") == -1:
		passed += 1
		print("PASS  no direct griddy_kid.frame assignment")
	else:
		failed += 1
		printerr("FAIL  direct griddy_kid.frame assignment found outside helper")

	# 6. _on_griddy_finished uses helper
	var fin_body = _extract.call("_on_griddy_finished")
	if fin_body.find("_set_griddy_frame(") >= 0:
		passed += 1
		print("PASS  _on_griddy_finished uses _set_griddy_frame")
	else:
		failed += 1
		printerr("FAIL  _on_griddy_finished not using _set_griddy_frame")

	# 7. _on_griddy_layout_tick disconnects
	var tick_body = _extract.call("_on_griddy_layout_tick")
	if tick_body.find("disconnect(") >= 0:
		passed += 1
		print("PASS  _on_griddy_layout_tick disconnects signal")
	else:
		failed += 1
		printerr("FAIL  _on_griddy_layout_tick does not disconnect")

	# 8. _ready has no await
	var ready_body = _extract.call("_ready")
	if ready_body.find("await") == -1:
		passed += 1
		print("PASS  _ready has no await")
	else:
		failed += 1
		printerr("FAIL  _ready contains await")

	print("\n--- Results: %d passed, %d failed ---" % [passed, failed])
