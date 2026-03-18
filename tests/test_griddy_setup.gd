@tool
extends EditorScript
## Verify _setup_griddy() fix: no await, guarded frame access, CONNECT_ONE_SHOT.
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

	# 2. _setup_griddy connects to process_frame with CONNECT_ONE_SHOT
	if body.find("process_frame.connect(") >= 0 and body.find("CONNECT_ONE_SHOT") >= 0:
		passed += 1
		print("PASS  _setup_griddy uses process_frame + CONNECT_ONE_SHOT")
	else:
		failed += 1
		printerr("FAIL  _setup_griddy missing process_frame.connect or CONNECT_ONE_SHOT")

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

	# 5. _set_griddy_frame handles null griddy_kid
	if frame_body.find("griddy_kid == null") >= 0 and frame_body.find("push_warning") >= 0:
		passed += 1
		print("PASS  _set_griddy_frame handles null griddy_kid with warning")
	else:
		failed += 1
		printerr("FAIL  _set_griddy_frame missing null griddy_kid guard")

	# 6. No direct griddy_kid.frame = outside helper
	var outside = src.replace(frame_body, "")
	if outside.find("griddy_kid.frame") == -1:
		passed += 1
		print("PASS  no direct griddy_kid.frame assignment")
	else:
		failed += 1
		printerr("FAIL  direct griddy_kid.frame assignment found outside helper")

	# 7. _on_griddy_finished uses helper
	var fin_body = _extract.call("_on_griddy_finished")
	if fin_body.find("_set_griddy_frame(") >= 0:
		passed += 1
		print("PASS  _on_griddy_finished uses _set_griddy_frame")
	else:
		failed += 1
		printerr("FAIL  _on_griddy_finished not using _set_griddy_frame")

	# 8. _on_griddy_layout_first_frame chains to _on_griddy_layout_ready
	var first_body = _extract.call("_on_griddy_layout_first_frame")
	if first_body.find("_on_griddy_layout_ready") >= 0 and first_body.find("CONNECT_ONE_SHOT") >= 0:
		passed += 1
		print("PASS  _on_griddy_layout_first_frame chains with ONE_SHOT")
	else:
		failed += 1
		printerr("FAIL  _on_griddy_layout_first_frame missing chain or ONE_SHOT")

	# 9. _on_griddy_layout_ready has is_inside_tree guard
	var ready_body = _extract.call("_on_griddy_layout_ready")
	if ready_body.find("is_inside_tree()") >= 0:
		passed += 1
		print("PASS  _on_griddy_layout_ready has is_inside_tree guard")
	else:
		failed += 1
		printerr("FAIL  _on_griddy_layout_ready missing is_inside_tree guard")

	# 10. _griddy_defer_frames variable removed
	if src.find("var _griddy_defer_frames") == -1:
		passed += 1
		print("PASS  _griddy_defer_frames instance variable removed")
	else:
		failed += 1
		printerr("FAIL  _griddy_defer_frames instance variable still present")

	# 11. _ready has no await
	var ready_main = _extract.call("_ready")
	if ready_main.find("await") == -1:
		passed += 1
		print("PASS  _ready has no await")
	else:
		failed += 1
		printerr("FAIL  _ready contains await")

	print("\n--- Results: %d passed, %d failed ---" % [passed, failed])
