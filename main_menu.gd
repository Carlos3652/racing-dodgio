extends Control

const COL_ACCENT    = Color(1.000, 0.851, 0.102, 1)
const COL_ACCENT_HV = Color(1.000, 0.920, 0.350, 1)
const COL_NAV_DARK  = Color(0.039, 0.027, 0.118, 1)


func _ready() -> void:
	_style_start_button()
	$VBox/StartButton.grab_focus()


func _style_start_button() -> void:
	var btn = $VBox/StartButton
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


func _on_start_pressed() -> void:
	GameData.clear()
	get_tree().change_scene_to_file("res://main.tscn")


