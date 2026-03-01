extends Control

# ── Palette ───────────────────────────────────────────────────────────────
const COL_GOLD       = Color(1.000, 0.843, 0.000, 1)
const COL_SILVER     = Color(0.753, 0.753, 0.753, 1)
const COL_BRONZE     = Color(0.804, 0.498, 0.196, 1)
const COL_MUTED      = Color(0.533, 0.533, 0.667, 1)
const COL_PANEL      = Color(0.078, 0.094, 0.188, 1)
const COL_GOLD_BG    = Color(0.120, 0.098, 0.028, 1)
const COL_ACCENT     = Color(1.000, 0.851, 0.102, 1)
const COL_NAV_BTN    = Color(0.039, 0.027, 0.118, 1)
const COL_BTN_BORDER = Color(0.333, 0.200, 0.733, 1)


func _ready() -> void:
	var order = GameData.finish_order
	var vbox  = $ContentVBox

	if order.is_empty():
		var lbl = Label.new()
		lbl.text = "No race data."
		lbl.add_theme_color_override("font_color", COL_MUTED)
		vbox.add_child(lbl)
	else:
		# ── 1st place — full-width gold card ──────────────────────────────
		if order.size() >= 1:
			vbox.add_child(_make_first_card(order[0]))

		# ── 2nd + 3rd — side-by-side ──────────────────────────────────────
		if order.size() >= 2:
			var mid = HBoxContainer.new()
			mid.add_theme_constant_override("separation", 12)
			for i in [1, 2]:
				if i < order.size():
					mid.add_child(_make_podium_card(order[i], i))
			vbox.add_child(mid)

		# ── Divider ───────────────────────────────────────────────────────
		if order.size() > 3:
			var div = ColorRect.new()
			div.custom_minimum_size = Vector2(0, 1)
			div.color = Color(0.200, 0.180, 0.380, 1)
			vbox.add_child(div)

		# ── 4th + 5th — compact rows ──────────────────────────────────────
		for i in [3, 4]:
			if i < order.size():
				vbox.add_child(_make_lower_row(order[i], i))

	# ── Style buttons ─────────────────────────────────────────────────────
	_style_button($ButtonRow/RaceAgainButton, true)
	_style_button($ButtonRow/MenuButton,      false)
	$ButtonRow/RaceAgainButton.grab_focus()

	# ── Win celebration ───────────────────────────────────────────────────
	if not order.is_empty() and order[0].name == "You":
		_play_win_celebration()


# ── Card builders ─────────────────────────────────────────────────────────

func _make_first_card(entry: Dictionary) -> PanelContainer:
	var card = PanelContainer.new()
	var sbox = StyleBoxFlat.new()
	sbox.bg_color             = COL_GOLD_BG
	sbox.border_width_top     = 3
	sbox.border_width_bottom  = 3
	sbox.border_width_left    = 3
	sbox.border_width_right   = 3
	sbox.border_color         = COL_GOLD
	sbox.corner_radius_top_left     = 10
	sbox.corner_radius_top_right    = 10
	sbox.corner_radius_bottom_left  = 10
	sbox.corner_radius_bottom_right = 10
	sbox.content_margin_top    = 14.0
	sbox.content_margin_bottom = 14.0
	sbox.content_margin_left   = 16.0
	sbox.content_margin_right  = 16.0
	card.add_theme_stylebox_override("panel", sbox)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)

	# Color swatch strip
	var swatch = ColorRect.new()
	swatch.custom_minimum_size = Vector2(10, 0)
	swatch.color               = _car_color(entry.name)
	hbox.add_child(swatch)

	# Place + name + time
	var vb = VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 2)

	var place_lbl = Label.new()
	place_lbl.text = "1ST PLACE"
	place_lbl.add_theme_font_size_override("font_size", 13)
	place_lbl.add_theme_color_override("font_color", COL_GOLD)
	vb.add_child(place_lbl)

	var name_row = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 0)

	var name_lbl = Label.new()
	name_lbl.text = "[* WINNER *]   " + entry.name
	name_lbl.add_theme_font_size_override("font_size", 36)
	name_lbl.add_theme_color_override("font_color", COL_GOLD)
	name_row.add_child(name_lbl)

	var time_lbl = Label.new()
	time_lbl.text                   = "   " + _fmt_time(entry.time)
	time_lbl.vertical_alignment     = VERTICAL_ALIGNMENT_BOTTOM
	time_lbl.add_theme_font_size_override("font_size", 22)
	time_lbl.add_theme_color_override("font_color", COL_MUTED)
	name_row.add_child(time_lbl)

	vb.add_child(name_row)
	hbox.add_child(vb)

	card.add_child(hbox)
	return card


func _make_podium_card(entry: Dictionary, idx: int) -> PanelContainer:
	var border_col = COL_SILVER if idx == 1 else COL_BRONZE
	var text_col   = COL_SILVER if idx == 1 else COL_BRONZE
	var place_str  = "2ND" if idx == 1 else "3RD"

	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var sbox = StyleBoxFlat.new()
	sbox.bg_color             = COL_PANEL
	sbox.border_width_top     = 2
	sbox.border_width_bottom  = 2
	sbox.border_width_left    = 2
	sbox.border_width_right   = 2
	sbox.border_color         = border_col
	sbox.corner_radius_top_left     = 8
	sbox.corner_radius_top_right    = 8
	sbox.corner_radius_bottom_left  = 8
	sbox.corner_radius_bottom_right = 8
	sbox.content_margin_top    = 12.0
	sbox.content_margin_bottom = 12.0
	sbox.content_margin_left   = 14.0
	sbox.content_margin_right  = 14.0
	card.add_theme_stylebox_override("panel", sbox)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)

	var swatch = ColorRect.new()
	swatch.custom_minimum_size = Vector2(8, 0)
	swatch.color               = _car_color(entry.name)
	hbox.add_child(swatch)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)

	var place_lbl = Label.new()
	place_lbl.text = place_str
	place_lbl.add_theme_font_size_override("font_size", 13)
	place_lbl.add_theme_color_override("font_color", text_col)
	vb.add_child(place_lbl)

	var name_row = HBoxContainer.new()
	var name_lbl = Label.new()
	name_lbl.text = entry.name
	name_lbl.add_theme_font_size_override("font_size", 26)
	name_lbl.add_theme_color_override("font_color", text_col)
	name_row.add_child(name_lbl)

	var time_lbl = Label.new()
	time_lbl.text               = "   " + _fmt_time(entry.time)
	time_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	time_lbl.add_theme_font_size_override("font_size", 18)
	time_lbl.add_theme_color_override("font_color", COL_MUTED)
	name_row.add_child(time_lbl)

	vb.add_child(name_row)
	hbox.add_child(vb)
	card.add_child(hbox)
	return card


func _make_lower_row(entry: Dictionary, idx: int) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var swatch = ColorRect.new()
	swatch.custom_minimum_size = Vector2(8, 28)
	swatch.color               = _car_color(entry.name)
	row.add_child(swatch)

	var lbl = Label.new()
	lbl.text = "  %s  —  %s   %s   Better luck next time!" % [
		_place_str(idx + 1), entry.name, _fmt_time(entry.time)
	]
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", COL_MUTED)
	row.add_child(lbl)
	return row


# ── Button styling ────────────────────────────────────────────────────────

func _style_button(btn: Button, is_primary: bool) -> void:
	var sbox_normal = StyleBoxFlat.new()
	var sbox_hover  = StyleBoxFlat.new()

	if is_primary:
		sbox_normal.bg_color = COL_ACCENT
		sbox_hover.bg_color  = Color(1.0, 0.92, 0.35, 1)
		btn.add_theme_color_override("font_color",       Color(0.039, 0.027, 0.118, 1))
		btn.add_theme_color_override("font_hover_color", Color(0.039, 0.027, 0.118, 1))
	else:
		sbox_normal.bg_color    = COL_NAV_BTN
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


# ── Win celebration ───────────────────────────────────────────────────────

func _play_win_celebration() -> void:
	var flash = ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color   = Color(1.0, 0.843, 0.0, 0.0)
	flash.z_index = 10
	add_child(flash)

	var banner = Label.new()
	banner.text                    = ">> YOU WIN! <<"
	banner.horizontal_alignment    = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment      = VERTICAL_ALIGNMENT_CENTER
	banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	banner.z_index                 = 11
	banner.add_theme_font_size_override("font_size", 52)
	banner.add_theme_color_override("font_color", COL_GOLD)
	banner.modulate.a = 0.0
	add_child(banner)

	var tw = create_tween()
	tw.tween_property(flash,  "color:a",    0.30, 0.15)
	tw.tween_property(flash,  "color:a",    0.0,  0.55)
	tw.parallel().tween_property(banner, "modulate:a", 1.0, 0.20)
	tw.tween_interval(0.8)
	tw.tween_property(banner, "modulate:a", 0.0,  0.40)
	tw.tween_callback(func():
		flash.queue_free()
		banner.queue_free()
	)


# ── Helpers ───────────────────────────────────────────────────────────────

func _car_color(name: String) -> Color:
	match name:
		"Blue":   return Color(0.200, 0.600, 1.000, 1)
		"Green":  return Color(0.133, 0.800, 0.333, 1)
		"Orange": return Color(1.000, 0.533, 0.000, 1)
		"Purple": return Color(0.800, 0.200, 1.000, 1)
		"You":    return Color(1.000, 0.133, 0.133, 1)
		_:        return Color(0.600, 0.600, 0.600, 1)


func _place_str(n: int) -> String:
	match n:
		1: return "1st"
		2: return "2nd"
		3: return "3rd"
		4: return "4th"
		5: return "5th"
		_: return str(n) + "th"


func _fmt_time(t: float) -> String:
	return "%d:%05.2f" % [int(t) / 60, fmod(t, 60.0)]


# ── Button signal handlers ────────────────────────────────────────────────

func _on_race_again_pressed() -> void:
	GameData.clear()
	get_tree().change_scene_to_file("res://main.tscn")


func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://main_menu.tscn")
