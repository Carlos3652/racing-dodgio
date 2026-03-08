extends Control

# ── Palette ───────────────────────────────────────────────────────────────
const COL_GOLD       = Color(1.000, 0.843, 0.000, 1)
const COL_SILVER     = Color(0.753, 0.753, 0.753, 1)
const COL_BRONZE     = Color(0.804, 0.498, 0.196, 1)
const COL_MUTED      = Color(0.533, 0.533, 0.667, 1)
const COL_PANEL      = Color(0.078, 0.094, 0.188, 1)
const COL_ACCENT     = Color(1.000, 0.851, 0.102, 1)
const COL_ACCENT_HV  = Color(1.000, 0.920, 0.350, 1)
const COL_NAV_BTN    = Color(0.039, 0.027, 0.118, 1)
const COL_BTN_BORDER = Color(0.333, 0.200, 0.733, 1)
const COL_CYAN       = Color(0.3, 0.95, 1.0, 1)
const COL_GOLD_BG    = Color(0.120, 0.098, 0.028, 1)

var _is_final: bool = false


func _ready() -> void:
	_is_final = GameData.circuit_race >= 5

	# Title
	if _is_final:
		$Title.text = "CHAMPIONSHIP FINAL"
		$Title.add_theme_color_override("font_color", COL_GOLD)
	else:
		$Title.text = "CIRCUIT STANDINGS"

	# Subtitle
	var last_race = GameData.circuit_race  # already incremented by record_circuit_race
	var last_track = GameData.circuit_history[GameData.circuit_history.size() - 1].track_name if not GameData.circuit_history.is_empty() else ""
	$Subtitle.text = "Race %d/5 Complete — %s" % [last_race, last_track]

	# Build content
	_build_standings()
	_build_race_history()
	if _is_final:
		_build_championship_stats()

	# Buttons
	if _is_final:
		$ButtonRow/NextRaceButton.text = "MAIN MENU"
	else:
		var next_track_name = GameData.TRACKS[GameData.circuit_race].name if GameData.circuit_race < GameData.TRACKS.size() else "???"
		$ButtonRow/NextRaceButton.text = "NEXT: %s" % next_track_name

	_style_button($ButtonRow/NextRaceButton, true)
	_style_button($ButtonRow/QuitButton, false)

	if _is_final:
		$ButtonRow/QuitButton.visible = false

	$ButtonRow/NextRaceButton.grab_focus()


func _build_standings() -> void:
	var vbox = $ContentVBox

	# Sort standings by points descending
	var sorted_cars: Array = []
	for car_name in GameData.circuit_standings.keys():
		sorted_cars.append({name = car_name, points = GameData.circuit_standings[car_name]})
	sorted_cars.sort_custom(func(a, b): return a.points > b.points)

	# Champion celebration for final
	if _is_final and sorted_cars.size() > 0:
		var champ = sorted_cars[0]
		var champ_card = _make_champion_card(champ)
		vbox.add_child(champ_card)

	# Header row
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 0)
	var h_pos = Label.new()
	h_pos.text = "POS"
	h_pos.custom_minimum_size = Vector2(50, 0)
	h_pos.add_theme_font_size_override("font_size", 13)
	h_pos.add_theme_color_override("font_color", COL_MUTED)
	header.add_child(h_pos)

	var h_car = Label.new()
	h_car.text = "CAR"
	h_car.custom_minimum_size = Vector2(200, 0)
	h_car.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_car.add_theme_font_size_override("font_size", 13)
	h_car.add_theme_color_override("font_color", COL_MUTED)
	header.add_child(h_car)

	var h_pts = Label.new()
	h_pts.text = "POINTS"
	h_pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h_pts.custom_minimum_size = Vector2(80, 0)
	h_pts.add_theme_font_size_override("font_size", 13)
	h_pts.add_theme_color_override("font_color", COL_MUTED)
	header.add_child(h_pts)
	vbox.add_child(header)

	# Divider
	var div = ColorRect.new()
	div.custom_minimum_size = Vector2(0, 1)
	div.color = Color(0.200, 0.180, 0.380, 1)
	vbox.add_child(div)

	# Standings rows
	_leader_points = sorted_cars[0].points if sorted_cars.size() > 0 else 0
	for i in range(sorted_cars.size()):
		var car = sorted_cars[i]
		var row = _make_standings_row(i, car.name, car.points)
		vbox.add_child(row)


var _leader_points: int = 0  # set during _build_standings for points gap display

func _make_standings_row(pos: int, car_name: String, points: int) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)

	# Position number
	var pos_lbl = Label.new()
	pos_lbl.text = _place_str(pos + 1)
	pos_lbl.custom_minimum_size = Vector2(50, 0)
	pos_lbl.add_theme_font_size_override("font_size", 20)
	match pos:
		0: pos_lbl.add_theme_color_override("font_color", COL_GOLD)
		1: pos_lbl.add_theme_color_override("font_color", COL_SILVER)
		2: pos_lbl.add_theme_color_override("font_color", COL_BRONZE)
		_: pos_lbl.add_theme_color_override("font_color", COL_MUTED)
	row.add_child(pos_lbl)

	# Color swatch
	var swatch = ColorRect.new()
	swatch.custom_minimum_size = Vector2(10, 28)
	swatch.color = _car_color(car_name)
	row.add_child(swatch)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(10, 0)
	row.add_child(spacer)

	# Car name
	var name_lbl = Label.new()
	name_lbl.text = car_name
	name_lbl.custom_minimum_size = Vector2(180, 0)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	row.add_child(name_lbl)

	# Points
	var pts_lbl = Label.new()
	pts_lbl.text = str(points) + " pts"
	pts_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pts_lbl.custom_minimum_size = Vector2(80, 0)
	pts_lbl.add_theme_font_size_override("font_size", 20)
	match pos:
		0: pts_lbl.add_theme_color_override("font_color", COL_GOLD)
		1: pts_lbl.add_theme_color_override("font_color", COL_SILVER)
		2: pts_lbl.add_theme_color_override("font_color", COL_BRONZE)
		_: pts_lbl.add_theme_color_override("font_color", COL_MUTED)
	row.add_child(pts_lbl)

	# Points gap from leader
	if pos > 0 and _leader_points > 0:
		var gap_lbl = Label.new()
		gap_lbl.text = "-%d" % (_leader_points - points)
		gap_lbl.custom_minimum_size = Vector2(50, 0)
		gap_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		gap_lbl.add_theme_font_size_override("font_size", 14)
		gap_lbl.add_theme_color_override("font_color", COL_MUTED)
		row.add_child(gap_lbl)

	return row


func _make_champion_card(champ: Dictionary) -> PanelContainer:
	var card = PanelContainer.new()
	var sbox = StyleBoxFlat.new()
	sbox.bg_color = COL_GOLD_BG
	sbox.border_width_top    = 3
	sbox.border_width_bottom = 3
	sbox.border_width_left   = 3
	sbox.border_width_right  = 3
	sbox.border_color = COL_GOLD
	sbox.corner_radius_top_left     = 10
	sbox.corner_radius_top_right    = 10
	sbox.corner_radius_bottom_left  = 10
	sbox.corner_radius_bottom_right = 10
	sbox.content_margin_top    = 12.0
	sbox.content_margin_bottom = 12.0
	sbox.content_margin_left   = 16.0
	sbox.content_margin_right  = 16.0
	card.add_theme_stylebox_override("panel", sbox)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var swatch = ColorRect.new()
	swatch.custom_minimum_size = Vector2(10, 0)
	swatch.color = _car_color(champ.name)
	hbox.add_child(swatch)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)

	var crown_lbl = Label.new()
	crown_lbl.text = "CHAMPION"
	crown_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crown_lbl.add_theme_font_size_override("font_size", 14)
	crown_lbl.add_theme_color_override("font_color", COL_GOLD)
	vb.add_child(crown_lbl)

	var name_lbl = Label.new()
	name_lbl.text = champ.name + "  —  " + str(champ.points) + " pts"
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 32)
	name_lbl.add_theme_color_override("font_color", COL_GOLD)
	vb.add_child(name_lbl)

	hbox.add_child(vb)
	card.add_child(hbox)
	return card


func _build_championship_stats() -> void:
	var vbox = $ContentVBox
	var stats = GameData.circuit_total_stats
	if stats.is_empty():
		return

	var div = ColorRect.new()
	div.custom_minimum_size = Vector2(0, 1)
	div.color = Color(0.200, 0.180, 0.380, 1)
	vbox.add_child(div)

	var header = Label.new()
	header.text = "CHAMPIONSHIP STATS"
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", COL_GOLD)
	vbox.add_child(header)

	var stat_row = func(label_text: String, value_text: String) -> HBoxContainer:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var lbl = Label.new()
		lbl.text = label_text
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", COL_MUTED)
		row.add_child(lbl)
		var val = Label.new()
		val.text = value_text
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val.add_theme_font_size_override("font_size", 14)
		val.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		row.add_child(val)
		return row

	vbox.add_child(stat_row.call("Total Stars", str(int(stats.get("stars", 0)))))
	vbox.add_child(stat_row.call("Total Stuns", str(int(stats.get("stuns", 0)))))
	vbox.add_child(stat_row.call("Total Bumps", str(int(stats.get("bumps", 0)))))
	# Average boost_pct across completed races instead of showing raw sum
	var num_races = GameData.circuit_history.size()
	if num_races > 0:
		var avg_boost = stats.get("boost_pct", 0.0) / float(num_races)
		vbox.add_child(stat_row.call("Avg Boost Time", "%d%%" % int(avg_boost)))
	vbox.add_child(stat_row.call("Lead Changes", str(int(stats.get("lead_changes", 0)))))
	if stats.get("close_calls", 0) > 0:
		vbox.add_child(stat_row.call("Close Calls", str(int(stats.get("close_calls", 0)))))


func _build_race_history() -> void:
	var vbox = $ContentVBox

	if GameData.circuit_history.is_empty():
		return

	# Divider
	var div = ColorRect.new()
	div.custom_minimum_size = Vector2(0, 1)
	div.color = Color(0.200, 0.180, 0.380, 1)
	vbox.add_child(div)

	# Header
	var header = Label.new()
	header.text = "RACE RESULTS"
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", COL_CYAN)
	vbox.add_child(header)

	# Each race summary
	for i in range(GameData.circuit_history.size()):
		var race = GameData.circuit_history[i]
		var winner_name = race.finish_order[0].name if race.finish_order.size() > 0 else "???"
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var race_lbl = Label.new()
		race_lbl.text = "Race %d" % (i + 1)
		race_lbl.custom_minimum_size = Vector2(60, 0)
		race_lbl.add_theme_font_size_override("font_size", 14)
		race_lbl.add_theme_color_override("font_color", COL_MUTED)
		row.add_child(race_lbl)

		var track_lbl = Label.new()
		track_lbl.text = race.track_name
		track_lbl.custom_minimum_size = Vector2(180, 0)
		track_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		track_lbl.add_theme_font_size_override("font_size", 14)
		track_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
		row.add_child(track_lbl)

		var swatch = ColorRect.new()
		swatch.custom_minimum_size = Vector2(8, 20)
		swatch.color = _car_color(winner_name)
		row.add_child(swatch)

		var winner_lbl = Label.new()
		winner_lbl.text = winner_name
		winner_lbl.custom_minimum_size = Vector2(80, 0)
		winner_lbl.add_theme_font_size_override("font_size", 14)
		winner_lbl.add_theme_color_override("font_color", _car_color(winner_name))
		row.add_child(winner_lbl)

		vbox.add_child(row)


# ── Button styling ────────────────────────────────────────────────────────

func _style_button(btn: Button, is_primary: bool) -> void:
	var sbox_normal = StyleBoxFlat.new()
	var sbox_hover  = StyleBoxFlat.new()

	if is_primary:
		sbox_normal.bg_color = COL_ACCENT
		sbox_hover.bg_color  = COL_ACCENT_HV
		btn.add_theme_color_override("font_color",       COL_NAV_BTN)
		btn.add_theme_color_override("font_hover_color", COL_NAV_BTN)
	else:
		sbox_normal.bg_color = COL_NAV_BTN
		sbox_normal.border_width_top    = 2
		sbox_normal.border_width_bottom = 2
		sbox_normal.border_width_left   = 2
		sbox_normal.border_width_right  = 2
		sbox_normal.border_color = COL_BTN_BORDER
		sbox_hover.bg_color      = Color(0.14, 0.18, 0.32, 1)
		sbox_hover.border_width_top    = 2
		sbox_hover.border_width_bottom = 2
		sbox_hover.border_width_left   = 2
		sbox_hover.border_width_right  = 2
		sbox_hover.border_color  = COL_BTN_BORDER
		btn.add_theme_color_override("font_color",       Color(1, 1, 1, 1))
		btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))

	for sbox in [sbox_normal, sbox_hover]:
		sbox.corner_radius_top_left     = 8
		sbox.corner_radius_top_right    = 8
		sbox.corner_radius_bottom_left  = 8
		sbox.corner_radius_bottom_right = 8

	btn.add_theme_stylebox_override("normal", sbox_normal)
	btn.add_theme_stylebox_override("hover",  sbox_hover)
	btn.add_theme_stylebox_override("pressed", sbox_normal)
	btn.add_theme_stylebox_override("focus",   sbox_normal)


# ── Scene transition ──────────────────────────────────────────────────────

func _change_scene(path: String) -> void:
	var overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color        = Color(0, 0, 0, 0)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index      = 100
	add_child(overlay)
	var tw = create_tween()
	tw.tween_property(overlay, "color:a", 1.0, 0.4)
	tw.tween_callback(func(): get_tree().change_scene_to_file(path))


# ── Button handlers ───────────────────────────────────────────────────────

func _on_next_race() -> void:
	if _is_final:
		GameData.clear_circuit()
		_change_scene("res://main_menu.tscn")
	else:
		GameData.clear()  # per-race reset only — keeps circuit state
		GameData.current_track_index = GameData.circuit_race
		_change_scene("res://main.tscn")


func _on_main_menu() -> void:
	GameData.clear_circuit()
	_change_scene("res://main_menu.tscn")


# ── Helpers ───────────────────────────────────────────────────────────────

func _car_color(car_name: String) -> Color:
	match car_name:
		"Blue":   return Color(0.200, 0.600, 1.000, 1)
		"Green":  return Color(0.133, 0.800, 0.333, 1)
		"Orange": return Color(1.000, 0.533, 0.000, 1)
		"Purple": return Color(0.800, 0.200, 1.000, 1)
		"You":    return GameData.player_color
		_:        return Color(0.600, 0.600, 0.600, 1)


func _place_str(n: int) -> String:
	match n:
		1: return "1st"
		2: return "2nd"
		3: return "3rd"
		4: return "4th"
		5: return "5th"
		_: return str(n) + "th"
