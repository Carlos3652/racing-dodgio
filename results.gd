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
const COL_BG         = Color(0.039, 0.027, 0.118, 1)

# ── Cinematic state machine ──────────────────────────────────────────────
enum Phase { FLASH, REVEAL, RESULTS }
var phase: Phase = Phase.FLASH
var _skipped: bool = false

# Node refs built during cinematic
var flash_rect: ColorRect
var reveal_container: Control
var winner_car: Node2D
var winner_title_hbox: HBoxContainer
var results_layer: Control  # holds Title, Subtitle, ContentVBox, ButtonRow


func _ready() -> void:
	# Hide the static results content initially — reveal in Phase 3
	$Title.modulate.a = 0.0
	$Subtitle.modulate.a = 0.0
	$ContentVBox.modulate.a = 0.0
	$ButtonRow.modulate.a = 0.0

	_start_phase_flash()


# ── Skip: ENTER/SPACE jumps to results ───────────────────────────────────
func _input(event: InputEvent) -> void:
	if _skipped:
		return
	if event.is_action_pressed("ui_accept") and phase != Phase.RESULTS:
		_skipped = true
		_skip_to_results()


func _skip_to_results() -> void:
	# Kill all tweens
	for child in get_children():
		if child is Tween:
			child.kill()

	# Clean up cinematic elements
	if flash_rect:
		flash_rect.color.a = 0.0
	if reveal_container:
		reveal_container.queue_free()
		reveal_container = null

	# Jump straight to results
	phase = Phase.RESULTS
	_show_results_instant()


# ═════════════════════════════════════════════════════════════════════════
# PHASE 1: FINISH LINE FLASH
# ═════════════════════════════════════════════════════════════════════════
func _start_phase_flash() -> void:
	phase = Phase.FLASH

	flash_rect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.color   = Color(1, 1, 1, 1)
	flash_rect.z_index = 50
	add_child(flash_rect)

	var tw = create_tween()
	# Bright white flash → fade to black
	tw.tween_property(flash_rect, "color", Color(1, 1, 1, 1), 0.05)
	tw.tween_property(flash_rect, "color", Color(0, 0, 0, 1), 0.5).set_trans(Tween.TRANS_QUAD)
	tw.tween_interval(0.3)
	tw.tween_callback(_start_phase_reveal)


# ═════════════════════════════════════════════════════════════════════════
# PHASE 2: WINNER REVEAL
# ═════════════════════════════════════════════════════════════════════════
func _start_phase_reveal() -> void:
	phase = Phase.REVEAL

	var order = GameData.finish_order
	if order.is_empty():
		_start_phase_results()
		return

	var winner = order[0]
	var vp_size = get_viewport_rect().size

	# Container for all reveal elements
	reveal_container = Control.new()
	reveal_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	reveal_container.z_index = 40
	add_child(reveal_container)

	# ── "1ST PLACE" letter drop-in ────────────────────────────────────────
	var reveal_text = "1ST PLACE"
	winner_title_hbox = HBoxContainer.new()
	winner_title_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	winner_title_hbox.set_anchors_preset(Control.PRESET_CENTER_TOP)
	winner_title_hbox.offset_top = vp_size.y * 0.2
	winner_title_hbox.offset_left = -200
	winner_title_hbox.offset_right = 200
	winner_title_hbox.add_theme_constant_override("separation", 4)
	reveal_container.add_child(winner_title_hbox)

	for i in range(reveal_text.length()):
		var ch = Label.new()
		ch.text = reveal_text[i]
		ch.add_theme_font_size_override("font_size", 56)
		ch.add_theme_color_override("font_color", COL_GOLD)
		ch.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ch.custom_minimum_size = Vector2(32 if reveal_text[i] != " " else 16, 0)
		ch.modulate.a = 0.0
		ch.position.y = -60  # start above
		winner_title_hbox.add_child(ch)

		var tw = create_tween()
		tw.tween_interval(0.08 * i)
		tw.tween_property(ch, "position:y", 0.0, 0.3).set_trans(Tween.TRANS_BACK)
		tw.parallel().tween_property(ch, "modulate:a", 1.0, 0.2)

	# ── Winner name below ─────────────────────────────────────────────────
	var name_lbl = Label.new()
	name_lbl.text = winner.name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	name_lbl.offset_top = vp_size.y * 0.2 + 70
	name_lbl.offset_left = -200
	name_lbl.offset_right = 200
	name_lbl.add_theme_font_size_override("font_size", 36)
	name_lbl.add_theme_color_override("font_color", _car_color(winner.name))
	name_lbl.modulate.a = 0.0
	reveal_container.add_child(name_lbl)

	var ntw = create_tween()
	ntw.tween_interval(0.08 * reveal_text.length() + 0.2)
	ntw.tween_property(name_lbl, "modulate:a", 1.0, 0.3)

	# ── Spinning winner car ───────────────────────────────────────────────
	winner_car = preload("res://car_visual.gd").new()
	winner_car.car_type  = _car_type_from_name(winner.name)
	winner_car.car_color = _car_color(winner.name)
	winner_car.position  = Vector2(vp_size.x / 2.0, vp_size.y * 0.55)
	winner_car.scale     = Vector2(2.5, 2.5)
	winner_car.modulate.a = 0.0
	reveal_container.add_child(winner_car)

	var ctw = create_tween()
	ctw.tween_interval(0.08 * reveal_text.length() + 0.1)
	ctw.tween_property(winner_car, "modulate:a", 1.0, 0.3)
	ctw.tween_property(winner_car, "rotation", TAU, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# ── Time display ──────────────────────────────────────────────────────
	var time_lbl = Label.new()
	time_lbl.text = _fmt_time(winner.time)
	time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	time_lbl.offset_top = vp_size.y * 0.72
	time_lbl.offset_left = -100
	time_lbl.offset_right = 100
	time_lbl.add_theme_font_size_override("font_size", 28)
	time_lbl.add_theme_color_override("font_color", COL_MUTED)
	time_lbl.modulate.a = 0.0
	reveal_container.add_child(time_lbl)

	var ttw = create_tween()
	ttw.tween_interval(0.08 * reveal_text.length() + 0.8)
	ttw.tween_property(time_lbl, "modulate:a", 1.0, 0.3)

	# ── "Press ENTER" skip hint ───────────────────────────────────────────
	var skip_lbl = Label.new()
	skip_lbl.text = "PRESS ENTER"
	skip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skip_lbl.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	skip_lbl.offset_top = -50
	skip_lbl.offset_left = -100
	skip_lbl.offset_right = 100
	skip_lbl.add_theme_font_size_override("font_size", 14)
	skip_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.3))
	reveal_container.add_child(skip_lbl)

	# Blink the skip hint
	var stw = create_tween().set_loops()
	stw.tween_property(skip_lbl, "modulate:a", 0.3, 0.6)
	stw.tween_property(skip_lbl, "modulate:a", 1.0, 0.6)

	# Auto-advance to Phase 3 after reveal completes
	var advance_tw = create_tween()
	advance_tw.tween_interval(3.5)
	advance_tw.tween_callback(_start_phase_results)


# ═════════════════════════════════════════════════════════════════════════
# PHASE 3: FULL RESULTS SLIDE IN
# ═════════════════════════════════════════════════════════════════════════
func _start_phase_results() -> void:
	if phase == Phase.RESULTS:
		return
	phase = Phase.RESULTS

	# Fade out the black overlay
	if flash_rect:
		var ftw = create_tween()
		ftw.tween_property(flash_rect, "color:a", 0.0, 0.4)
		ftw.tween_callback(func(): flash_rect.queue_free(); flash_rect = null)

	# Shrink + move reveal container to top-right corner
	if reveal_container:
		var rtw = create_tween()
		rtw.set_parallel(true)
		rtw.tween_property(reveal_container, "modulate:a", 0.0, 0.5)
		rtw.chain().tween_callback(func():
			if reveal_container:
				reveal_container.queue_free()
				reveal_container = null
		)

	# Build and show results
	_build_results()

	# Slide everything in from below
	var vp_h = get_viewport_rect().size.y

	$Title.position.y += vp_h * 0.5
	$Subtitle.position.y += vp_h * 0.5
	$ContentVBox.position.y += vp_h * 0.5
	$ButtonRow.position.y += vp_h * 0.3

	var stw = create_tween()
	stw.tween_property($Title, "modulate:a", 1.0, 0.3)
	stw.parallel().tween_property($Title, "position:y", $Title.position.y - vp_h * 0.5, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	stw.parallel().tween_property($Subtitle, "modulate:a", 1.0, 0.3).set_delay(0.08)
	stw.parallel().tween_property($Subtitle, "position:y", $Subtitle.position.y - vp_h * 0.5, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(0.08)

	stw.parallel().tween_property($ContentVBox, "modulate:a", 1.0, 0.3).set_delay(0.16)
	stw.parallel().tween_property($ContentVBox, "position:y", $ContentVBox.position.y - vp_h * 0.5, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(0.16)

	stw.parallel().tween_property($ButtonRow, "modulate:a", 1.0, 0.3).set_delay(0.3)
	stw.parallel().tween_property($ButtonRow, "position:y", $ButtonRow.position.y - vp_h * 0.3, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(0.3)

	stw.tween_callback(func(): $ButtonRow/RaceAgainButton.grab_focus())


func _show_results_instant() -> void:
	_build_results()
	$Title.modulate.a = 1.0
	$Subtitle.modulate.a = 1.0
	$ContentVBox.modulate.a = 1.0
	$ButtonRow.modulate.a = 1.0
	if flash_rect:
		flash_rect.queue_free()
		flash_rect = null
	$ButtonRow/RaceAgainButton.grab_focus()


# ═════════════════════════════════════════════════════════════════════════
# BUILD RESULTS CARDS (shared by cinematic + skip)
# ═════════════════════════════════════════════════════════════════════════
func _build_results() -> void:
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

	var swatch = ColorRect.new()
	swatch.custom_minimum_size = Vector2(10, 0)
	swatch.color               = _car_color(entry.name)
	hbox.add_child(swatch)

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


# ── Scene fade transition helper ──────────────────────────────────────────

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


# ── Helpers ───────────────────────────────────────────────────────────────

func _car_color(car_name: String) -> Color:
	match car_name:
		"Blue":   return Color(0.200, 0.600, 1.000, 1)
		"Green":  return Color(0.133, 0.800, 0.333, 1)
		"Orange": return Color(1.000, 0.533, 0.000, 1)
		"Purple": return Color(0.800, 0.200, 1.000, 1)
		"You":    return GameData.player_color
		_:        return Color(0.600, 0.600, 0.600, 1)


func _car_type_from_name(car_name: String) -> String:
	match car_name:
		"Blue":   return "blue"
		"Green":  return "green"
		"Orange": return "orange"
		"Purple": return "purple"
		"You":    return GameData.player_car_type
		_:        return "player"


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
	_change_scene("res://main.tscn")


func _on_main_menu_pressed() -> void:
	GameData.clear()
	_change_scene("res://main_menu.tscn")
