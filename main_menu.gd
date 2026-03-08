extends Control

const COL_ACCENT    = Color(1.000, 0.851, 0.102, 1)
const COL_ACCENT_HV = Color(1.000, 0.920, 0.350, 1)
const COL_NAV_DARK  = Color(0.039, 0.027, 0.118, 1)
const COL_MUTED     = Color(0.533, 0.533, 0.667, 1)
const COL_CYAN      = Color(0.3, 0.95, 1.0, 1)
const COL_HIGHLIGHT = Color(1.0, 0.85, 0.1, 1)
const COL_DIM_BORDER = Color(0.25, 0.22, 0.40, 1)

# Car options — order matters for left/right nav
const CAR_OPTIONS = [
	{name = "RED CAR",    type = "player", color = Color(1.0, 0.133, 0.133, 1), speed = 6, style = 5, luck = 4},
	{name = "BLUE CAR",   type = "blue",   color = Color(0.2, 0.5, 1.0, 1),     speed = 4, style = 6, luck = 7},
	{name = "GREEN CAR",  type = "green",  color = Color(0.2, 0.85, 0.3, 1),    speed = 7, style = 4, luck = 3},
	{name = "ORANGE CAR", type = "orange", color = Color(1.0, 0.55, 0.1, 1),    speed = 5, style = 7, luck = 5},
	{name = "PURPLE CAR", type = "purple", color = Color(0.85, 0.2, 0.85, 1),   speed = 8, style = 8, luck = 2},
]

var selected_index: int = 0
var car_panels: Array = []  # references to the panel containers
var car_visuals: Array = []  # references to car_visual nodes
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

	# Style the start button
	_style_start_button()
	$VBox/RaceButton.grab_focus()


func _style_start_button() -> void:
	var btn = $VBox/RaceButton
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

	# Scale animation on selected car
	for i in range(car_visuals.size()):
		var target_scale = Vector2(1.1, 1.1) if i == selected_index else Vector2(0.9, 0.9)
		var tw = create_tween()
		tw.tween_property(car_visuals[i], "scale", target_scale, 0.15).set_trans(Tween.TRANS_BACK)


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


func _on_race_pressed() -> void:
	var car = CAR_OPTIONS[selected_index]
	GameData.player_color    = car.color
	GameData.player_car_type = car.type
	GameData.clear()
	_change_scene("res://main.tscn")
