extends Control

const COL_ACCENT    = Color(1.000, 0.851, 0.102, 1)
const COL_ACCENT_HV = Color(1.000, 0.920, 0.350, 1)
const COL_NAV_DARK  = Color(0.039, 0.027, 0.118, 1)
const COL_MUTED     = Color(0.533, 0.533, 0.667, 1)
const COL_CYAN      = Color(0.3, 0.95, 1.0, 1)
const COL_HIGHLIGHT = Color(1.0, 0.85, 0.1, 1)
const COL_DIM_BORDER = Color(0.25, 0.22, 0.40, 1)

# Car options — order matters for left/right nav
# Speed stat → max_speed: 4→310, 5→325, 6→340, 7→355, 8→370
# Luck stat → stun_duration: 2→2.2, 3→2.0, 4→1.8, 5→1.7, 6→1.5, 7→1.4
const SPEED_MAP = {4: 310.0, 5: 325.0, 6: 340.0, 7: 355.0, 8: 370.0}
const LUCK_MAP  = {2: 2.2, 3: 2.0, 4: 1.8, 5: 1.7, 6: 1.5, 7: 1.4}
# Style stat → turn_speed (handling): higher style = tighter turning
const STYLE_MAP = {4: 2.4, 5: 2.6, 6: 2.8, 7: 3.0, 8: 3.2}

const CAR_OPTIONS = [
	{name = "RED CAR",    type = "player", color = Color(1.0, 0.133, 0.133, 1), speed = 6, style = 5, luck = 4, boost_duration = 5.0},
	{name = "BLUE CAR",   type = "blue",   color = Color(0.2, 0.5, 1.0, 1),     speed = 4, style = 6, luck = 7, boost_duration = 5.0},
	{name = "GREEN CAR",  type = "green",  color = Color(0.2, 0.85, 0.3, 1),    speed = 7, style = 4, luck = 3, boost_duration = 5.0},
	{name = "ORANGE CAR", type = "orange", color = Color(1.0, 0.55, 0.1, 1),    speed = 5, style = 7, luck = 5, boost_duration = 5.0},
	{name = "PURPLE CAR", type = "purple", color = Color(0.85, 0.2, 0.85, 1),   speed = 8, style = 8, luck = 2, boost_duration = 3.5},
]

const DIFFICULTIES = ["EASY", "NORMAL", "HARD"]
var selected_index: int = 0
var selected_difficulty: int = 1  # 0=easy, 1=normal, 2=hard
var car_panels: Array = []  # references to the panel containers
var car_visuals: Array = []  # references to car_visual nodes
var _selection_tweens: Array = []  # active tweens from _update_selection()
var diff_buttons: Array = []  # difficulty button references
var name_label: Label
var stat_speed: ProgressBar
var stat_style: ProgressBar
var stat_luck: ProgressBar


func _ready() -> void:
	_draw_bg_stripes()
	_build_ui()
	_update_selection()

	# Title scale-in animation
	var title = $VBox/Title
	title.scale = Vector2(1.5, 1.5)
	title.pivot_offset = title.size / 2.0
	var tw = create_tween()
	tw.tween_property(title, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_BACK)


func _build_ui() -> void:
	# Car display row
	var car_row = $VBox/CarRow
	for i in range(CAR_OPTIONS.size()):
		var panel = PanelContainer.new()
		panel.custom_minimum_size = Vector2(100, 120)

		var sbox = StyleBoxFlat.new()
		sbox.bg_color = Color(0.06, 0.05, 0.14, 1)
		sbox.border_width_left   = 3
		sbox.border_width_top    = 3
		sbox.border_width_right  = 3
		sbox.border_width_bottom = 3
		sbox.border_color = COL_DIM_BORDER
		sbox.corner_radius_top_left     = 8
		sbox.corner_radius_top_right    = 8
		sbox.corner_radius_bottom_right = 8
		sbox.corner_radius_bottom_left  = 8
		sbox.content_margin_left   = 8.0
		sbox.content_margin_top    = 8.0
		sbox.content_margin_right  = 8.0
		sbox.content_margin_bottom = 8.0
		panel.add_theme_stylebox_override("panel", sbox)

		# Car visual inside
		var vis = preload("res://car_visual.gd").new()
		vis.car_type = CAR_OPTIONS[i].type
		vis.car_color = CAR_OPTIONS[i].color
		vis.position = Vector2(50, 65)
		vis.scale = Vector2(0.9, 0.9)
		panel.add_child(vis)
		car_visuals.append(vis)

		# Initial letter label at bottom
		var lbl = Label.new()
		lbl.text = CAR_OPTIONS[i].name.substr(0, CAR_OPTIONS[i].name.find(" "))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", COL_MUTED)
		lbl.position = Vector2(0, 100)
		lbl.size = Vector2(100, 20)
		panel.add_child(lbl)

		car_row.add_child(panel)
		car_panels.append(panel)

	# Selected car name
	name_label = $VBox/SelectedName

	# Stat bars — already in scene
	stat_speed = $VBox/StatsBox/SpeedRow/SpeedBar
	stat_style = $VBox/StatsBox/StyleRow/StyleBar
	stat_luck  = $VBox/StatsBox/LuckRow/LuckBar

	# Style stat bars
	for bar in [stat_speed, stat_style, stat_luck]:
		bar.max_value = 8
		var bg_style = StyleBoxFlat.new()
		bg_style.bg_color = Color(0.10, 0.09, 0.20, 1)
		bg_style.corner_radius_top_left     = 4
		bg_style.corner_radius_top_right    = 4
		bg_style.corner_radius_bottom_right = 4
		bg_style.corner_radius_bottom_left  = 4
		bar.add_theme_stylebox_override("background", bg_style)
		var fill_style = StyleBoxFlat.new()
		fill_style.bg_color = COL_ACCENT
		fill_style.corner_radius_top_left     = 4
		fill_style.corner_radius_top_right    = 4
		fill_style.corner_radius_bottom_right = 4
		fill_style.corner_radius_bottom_left  = 4
		bar.add_theme_stylebox_override("fill", fill_style)

	# Difficulty buttons
	diff_buttons = [
		$VBox/DifficultyRow/EasyBtn,
		$VBox/DifficultyRow/NormalBtn,
		$VBox/DifficultyRow/HardBtn,
	]
	_update_difficulty_ui()

	# Style the start buttons
	_style_quick_race_button()
	_style_circuit_button()
	$VBox/ButtonRow/QuickRaceButton.grab_focus()


func _style_quick_race_button() -> void:
	var btn = $VBox/ButtonRow/QuickRaceButton
	var sn = StyleBoxFlat.new()
	sn.bg_color = COL_ACCENT
	var sh = StyleBoxFlat.new()
	sh.bg_color = COL_ACCENT_HV
	for sbox in [sn, sh]:
		sbox.corner_radius_top_left     = 10
		sbox.corner_radius_top_right    = 10
		sbox.corner_radius_bottom_left  = 10
		sbox.corner_radius_bottom_right = 10
	btn.add_theme_stylebox_override("normal",  sn)
	btn.add_theme_stylebox_override("hover",   sh)
	btn.add_theme_stylebox_override("pressed", sn)
	btn.add_theme_stylebox_override("focus",   sn)
	btn.add_theme_color_override("font_color",       COL_NAV_DARK)
	btn.add_theme_color_override("font_hover_color", COL_NAV_DARK)


func _style_circuit_button() -> void:
	var btn = $VBox/ButtonRow/CircuitButton
	var sn = StyleBoxFlat.new()
	sn.bg_color = COL_NAV_DARK
	sn.border_width_left   = 2
	sn.border_width_top    = 2
	sn.border_width_right  = 2
	sn.border_width_bottom = 2
	sn.border_color = COL_CYAN
	var sh = StyleBoxFlat.new()
	sh.bg_color = Color(0.06, 0.08, 0.20, 1)
	sh.border_width_left   = 2
	sh.border_width_top    = 2
	sh.border_width_right  = 2
	sh.border_width_bottom = 2
	sh.border_color = COL_CYAN
	for sbox in [sn, sh]:
		sbox.corner_radius_top_left     = 10
		sbox.corner_radius_top_right    = 10
		sbox.corner_radius_bottom_left  = 10
		sbox.corner_radius_bottom_right = 10
	btn.add_theme_stylebox_override("normal",  sn)
	btn.add_theme_stylebox_override("hover",   sh)
	btn.add_theme_stylebox_override("pressed", sn)
	btn.add_theme_stylebox_override("focus",   sn)
	btn.add_theme_color_override("font_color",       COL_CYAN)
	btn.add_theme_color_override("font_hover_color", COL_CYAN)


func _update_selection() -> void:
	var car = CAR_OPTIONS[selected_index]
	name_label.text = car.name
	name_label.add_theme_color_override("font_color", COL_HIGHLIGHT)

	stat_speed.value = car.speed
	stat_style.value = car.style
	stat_luck.value  = car.luck

	# Update panel borders — highlight selected, dim others
	for i in range(car_panels.size()):
		var sbox = car_panels[i].get_theme_stylebox("panel") as StyleBoxFlat
		if i == selected_index:
			sbox.border_color = COL_HIGHLIGHT
		else:
			sbox.border_color = COL_DIM_BORDER

	# Kill existing selection tweens to prevent accumulation
	for tw in _selection_tweens:
		if tw != null and tw.is_valid():
			tw.kill()
	_selection_tweens.clear()

	# Scale animation on selected car
	for i in range(car_visuals.size()):
		var target_scale = Vector2(1.1, 1.1) if i == selected_index else Vector2(0.9, 0.9)
		var tw = create_tween()
		tw.tween_property(car_visuals[i], "scale", target_scale, 0.15).set_trans(Tween.TRANS_BACK)
		_selection_tweens.append(tw)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		selected_index = (selected_index - 1 + CAR_OPTIONS.size()) % CAR_OPTIONS.size()
		_update_selection()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		selected_index = (selected_index + 1) % CAR_OPTIONS.size()
		_update_selection()
		get_viewport().set_input_as_handled()


func _draw_bg_stripes() -> void:
	var bg = $Background
	for i in range(-6, 16):
		var stripe = ColorRect.new()
		stripe.color = Color(1, 1, 1, 0.035)
		stripe.size  = Vector2(2400, 10)
		stripe.position = Vector2(-300, i * 72 - 40)
		stripe.rotation = deg_to_rad(-38)
		bg.add_child(stripe)


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


func _update_difficulty_ui() -> void:
	for i in range(diff_buttons.size()):
		var btn = diff_buttons[i]
		var sbox = StyleBoxFlat.new()
		sbox.corner_radius_top_left     = 6
		sbox.corner_radius_top_right    = 6
		sbox.corner_radius_bottom_left  = 6
		sbox.corner_radius_bottom_right = 6
		if i == selected_difficulty:
			sbox.bg_color = COL_ACCENT
			btn.add_theme_color_override("font_color", COL_NAV_DARK)
		else:
			sbox.bg_color = Color(0.06, 0.05, 0.14, 1)
			sbox.border_width_left   = 2
			sbox.border_width_top    = 2
			sbox.border_width_right  = 2
			sbox.border_width_bottom = 2
			sbox.border_color = COL_DIM_BORDER
			btn.add_theme_color_override("font_color", COL_MUTED)
		btn.add_theme_stylebox_override("normal",  sbox)
		btn.add_theme_stylebox_override("hover",   sbox)
		btn.add_theme_stylebox_override("pressed", sbox)
		btn.add_theme_stylebox_override("focus",   sbox)


func _on_diff_easy() -> void:
	selected_difficulty = 0
	_update_difficulty_ui()


func _on_diff_normal() -> void:
	selected_difficulty = 1
	_update_difficulty_ui()


func _on_diff_hard() -> void:
	selected_difficulty = 2
	_update_difficulty_ui()


func _apply_car_stats(car: Dictionary) -> void:
	GameData.player_color          = car.color
	GameData.player_car_type       = car.type
	GameData.player_max_speed      = SPEED_MAP.get(car.speed, 340.0)
	GameData.player_stun_duration  = LUCK_MAP.get(car.luck, 2.0)
	GameData.player_boost_duration = car.get("boost_duration", 5.0)
	GameData.player_turn_speed     = STYLE_MAP.get(car.style, 2.8)
	GameData.difficulty            = DIFFICULTIES[selected_difficulty].to_lower()


func _on_quick_race_pressed() -> void:
	var car = CAR_OPTIONS[selected_index]
	_apply_car_stats(car)
	GameData.clear_circuit()
	GameData.circuit_mode = false
	GameData.current_track_index = 0
	_change_scene("res://main.tscn")


func _on_circuit_pressed() -> void:
	var car = CAR_OPTIONS[selected_index]
	_apply_car_stats(car)
	GameData.clear_circuit()
	GameData.circuit_mode = true
	GameData.circuit_race = 0
	GameData.current_track_index = 0
	_change_scene("res://main.tscn")
