extends Node2D

# ---------------------------------------------------------------------------
# Track waypoints — Overland Park map route
# ---------------------------------------------------------------------------
const TRACK_POINTS = [
	Vector2( 1200,    0),   # 0  START (right — car faces north at rotation=0)
	Vector2( 1200,  -700),  # 1  north on right
	Vector2(  500, -1300),  # 2  top-right
	Vector2( -500, -1300),  # 3  top (west)
	Vector2(-1200,  -700),  # 4  top-left
	Vector2(-1200,     0),  # 5  far left
	Vector2(-1200,   700),  # 6  bottom-left
	Vector2( -500,  1300),  # 7  bottom (east)
	Vector2(  400,  1300),  # 8  bottom-right
	Vector2(  900,   700),  # 9  FINISH
]

const ROAD_WIDTH     = 280.0
const BUMP_DIST      = 55.0   # car-to-car collision distance
const BUMP_COOLDOWN  = 2.0    # seconds between bump checks per pair
const SHOULDER_W     = 340.0
const ROAD_COLOR     = Color(0.172, 0.172, 0.220, 1)
const SHOULDER_COLOR = Color(0.102, 0.180, 0.102, 1)
const DASH_COLOR     = Color(1.000, 0.878, 0.200, 1)
const DASH_LEN       = 90.0
const GAP_LEN        = 55.0
const CURB_WHITE     = Color(0.941, 0.929, 0.878, 1)
const CURB_RED       = Color(0.800, 0.133, 0.000, 1)
const CURB_STRIPE_LEN   = 40.0
const CURB_STRIPE_WIDTH = 18.0

const AI_COLORS = [
	Color(0.2,  0.5,  1.0),
	Color(0.2,  0.85, 0.3),
	Color(1.0,  0.55, 0.1),
	Color(0.85, 0.2,  0.85),
]
const AI_NAMES = ["Blue", "Green", "Orange", "Purple"]

const COOKIE_RESPAWN_SEC = 10.0
const JEEP_RESPAWN_SEC   = 14.0
const COOKIE_OFFSETS = [0.18, 0.42, 0.65, 0.83]
const JEEP_OFFSETS   = [0.28, 0.55, 0.75]

const CAR_SCALE = Vector2(1.2, 1.2)

# ---------------------------------------------------------------------------
enum State { INTRO, COUNTDOWN, RACING, FINISHED }
var state: State = State.INTRO
var intro_timer: float = 2.4
var countdown_left: float = 3.0
var race_time: float = 0.0
var finishers_count: int = 0
var total_cars: int = 5

var player: Sprite2D
var ai_cars: Array = []
var track_path: Path2D
var finish_pos: Vector2

var cookie_timers: Dictionary = {}
var jeep_timers:   Dictionary = {}
var bump_cooldowns: Dictionary = {}  # pair key -> seconds remaining
var obstacles: Array = []  # all cookie + jeep sprites — avoids scanning get_children() every frame

# HUD node refs
var hud_place_numeral: Label
var hud_place_suffix:  Label
var hud_timer:         Label
var hud_speed:         Label
var hud_boost_status:  Label
var hud_div3:          ColorRect
var hud_place_up:      Label
var hud_countdown:     Label
var countdown_backing: ColorRect
var flash_rect:        ColorRect
var crash_label:       Label
var boost_bar:         ProgressBar
var hype_bar:          ProgressBar
var hype_label:        Label
var griddy_kid:        Node2D
var griddy_anim:       AnimationPlayer

var last_digit_shown: int = -1
var hype_timer:       float = 0.0
var _scene_changing:  bool  = false
var _last_place:      int   = 0
var _esc_dialog_open: bool  = false
var _finish_banner_shown: bool = false
var _player_finished: bool  = false
var _player_finish_timer: float = 0.0
const FORCE_FINISH_DELAY: float = 10.0
const RACE_TIMEOUT: float = 120.0

# New HUD refs
var esc_dialog:    Control
var esc_yes_btn:   Button
var esc_no_btn:    Button
var finish_banner: Label
var intro_card:    Label
var fade_overlay:  ColorRect
var camera:        Camera2D
var minimap:       Control

# StyleBoxFlat instances for dynamic bar coloring
var _boost_style:  StyleBoxFlat
var _crash_style:  StyleBoxFlat
var _bar_bg_style: StyleBoxFlat
var _hype_style:   StyleBoxFlat


func _ready() -> void:
	_create_bar_styles()
	_build_road()
	_build_track_path()
	_place_obstacles()
	_setup_hud_refs()
	_setup_minimap()
	_setup_griddy()


# ---------------------------------------------------------------------------
# StyleBoxFlat — created in code so we can swap them at runtime
# ---------------------------------------------------------------------------
func _create_bar_styles() -> void:
	_boost_style = StyleBoxFlat.new()
	_boost_style.bg_color = Color(1, 0.85, 0.1, 1)

	_crash_style = StyleBoxFlat.new()
	_crash_style.bg_color = Color(1, 0.25, 0.25, 1)

	_bar_bg_style = StyleBoxFlat.new()
	_bar_bg_style.bg_color = Color(0.10, 0.09, 0.20, 1)

	_hype_style = StyleBoxFlat.new()
	_hype_style.bg_color = Color(0.85, 0.55, 1.0, 1)


# ---------------------------------------------------------------------------
# Road — shoulder + asphalt + dashed center line
# ---------------------------------------------------------------------------
func _build_road() -> void:
	var shoulder = $Shoulder as Line2D
	shoulder.width = SHOULDER_W
	shoulder.default_color = SHOULDER_COLOR
	shoulder.joint_mode = Line2D.LINE_JOINT_ROUND
	shoulder.begin_cap_mode = Line2D.LINE_CAP_ROUND
	shoulder.end_cap_mode   = Line2D.LINE_CAP_ROUND
	for p in TRACK_POINTS:
		shoulder.add_point(p)

	var road = $Road as Line2D
	road.width = ROAD_WIDTH
	road.default_color = ROAD_COLOR
	road.joint_mode = Line2D.LINE_JOINT_ROUND
	road.begin_cap_mode = Line2D.LINE_CAP_ROUND
	road.end_cap_mode   = Line2D.LINE_CAP_ROUND
	for p in TRACK_POINTS:
		road.add_point(p)

	# Build a shared curve used by dashes and curb stripes
	var curve = Curve2D.new()
	for p in TRACK_POINTS:
		curve.add_point(p)

	_build_dashes(curve)
	_build_curb_stripes(curve)
	_add_marker(TRACK_POINTS[0], "START", Color(0.1, 0.95, 0.1))
	_add_finish_checkered(TRACK_POINTS[TRACK_POINTS.size() - 1])


func _build_dashes(curve: Curve2D) -> void:
	var total_len = curve.get_baked_length()
	var pos       = DASH_LEN
	var drawing   = true

	while pos < total_len - DASH_LEN:
		if drawing:
			var p1 = curve.sample_baked(pos)
			var p2 = curve.sample_baked(min(pos + DASH_LEN, total_len))
			var dash = Line2D.new()
			dash.width = 10.0
			dash.default_color = DASH_COLOR
			dash.add_point(p1)
			dash.add_point(p2)
			dash.z_index = 2
			add_child(dash)
			pos += DASH_LEN
		else:
			pos += GAP_LEN
		drawing = not drawing


func _build_curb_stripes(curve: Curve2D) -> void:
	var total_len = curve.get_baked_length()
	var offset    = (ROAD_WIDTH * 0.5) + 8.0
	var pos       = 0.0
	var is_white  = true

	while pos < total_len:
		var end_pos = min(pos + CURB_STRIPE_LEN, total_len)
		var p1      = curve.sample_baked(pos)
		var p2      = curve.sample_baked(end_pos)
		var dir     = (p2 - p1).normalized()
		var perp    = Vector2(-dir.y, dir.x)
		var col     = CURB_WHITE if is_white else CURB_RED

		# Left edge stripe
		var left = Line2D.new()
		left.width         = CURB_STRIPE_WIDTH
		left.default_color = col
		left.add_point(p1 - perp * offset)
		left.add_point(p2 - perp * offset)
		left.z_index = 1
		add_child(left)

		# Right edge stripe
		var right = Line2D.new()
		right.width         = CURB_STRIPE_WIDTH
		right.default_color = col
		right.add_point(p1 + perp * offset)
		right.add_point(p2 + perp * offset)
		right.z_index = 1
		add_child(right)

		pos      += CURB_STRIPE_LEN
		is_white  = not is_white


func _add_marker(pos: Vector2, label_text: String, col: Color) -> void:
	var lbl = Label.new()
	lbl.text = label_text
	lbl.position = pos + Vector2(-50, -70)
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.add_theme_color_override("font_color", col)
	add_child(lbl)

	var line = Line2D.new()
	line.width = ROAD_WIDTH
	line.default_color = Color(col.r, col.g, col.b, 0.35)
	line.add_point(pos + Vector2(-20, 0))
	line.add_point(pos + Vector2(20, 0))
	add_child(line)


func _add_finish_checkered(pos: Vector2) -> void:
	var lbl = Label.new()
	lbl.text = "FINISH"
	lbl.position = pos + Vector2(-50, -70)
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	add_child(lbl)

	# Direction of road at finish (from prev waypoint to finish)
	var prev = TRACK_POINTS[TRACK_POINTS.size() - 2]
	var dir  = (pos - prev).normalized()
	var perp = Vector2(-dir.y, dir.x)  # perpendicular to road direction

	const COLS = 8
	const ROWS = 2
	var cell_w = ROAD_WIDTH / float(COLS)
	var cell_h = 22.0

	for col in range(COLS):
		for row in range(ROWS):
			var col_t  = (float(col) / COLS) - 0.5 + (0.5 / COLS)
			var row_t  = (float(row) - float(ROWS) * 0.5 + 0.5) * cell_h
			var center = pos + perp * (col_t * ROAD_WIDTH) + dir * row_t

			var hw = cell_w * 0.5
			var hh = cell_h * 0.5
			var c0 = center + perp * (-hw) + dir * (-hh)
			var c1 = center + perp * ( hw) + dir * (-hh)
			var c2 = center + perp * ( hw) + dir * ( hh)
			var c3 = center + perp * (-hw) + dir * ( hh)

			var poly = Polygon2D.new()
			poly.polygon = PackedVector2Array([c0, c1, c2, c3])
			poly.color   = Color(1, 1, 1, 0.95) if (col + row) % 2 == 0 else Color(0, 0, 0, 0.95)
			poly.z_index = 3
			add_child(poly)


# ---------------------------------------------------------------------------
# Path2D + player + AI
# ---------------------------------------------------------------------------
func _build_track_path() -> void:
	track_path = $TrackPath as Path2D
	var curve = Curve2D.new()
	for p in TRACK_POINTS:
		curve.add_point(p)
	track_path.curve = curve

	finish_pos = TRACK_POINTS[TRACK_POINTS.size() - 1]

	# Compute start direction and perpendicular for lane offsets
	var start_dir = (TRACK_POINTS[1] - TRACK_POINTS[0]).normalized()
	var start_perp = Vector2(-start_dir.y, start_dir.x)  # perpendicular (right of travel)

	# Build AI roster — skip the color the player chose
	var ai_roster: Array = []
	for i in range(AI_NAMES.size()):
		if AI_NAMES[i].to_lower() == GameData.player_car_type or \
		   (GameData.player_car_type == "player" and AI_NAMES[i] == ""):
			continue
		ai_roster.append({name = AI_NAMES[i], color = AI_COLORS[i]})
	var spawn_count = min(ai_roster.size(), 4)

	# Lane offsets: spread all cars evenly across the road width
	# total_slots = 1 (player) + spawn_count (AI)
	var total_slots = 1 + spawn_count
	var lane_offsets: Array = []
	for i in range(total_slots):
		# Evenly spaced from -half_road to +half_road
		var t = (float(i) / float(total_slots - 1)) - 0.5 if total_slots > 1 else 0.0
		lane_offsets.append(t * ROAD_WIDTH * 0.7)  # 70% of road to leave margin

	# Player gets the middle lane (or first if odd)
	var player_lane_idx = total_slots / 2

	player = $PlayerCar
	player.scale = CAR_SCALE
	player.position = TRACK_POINTS[0] + start_perp * lane_offsets[player_lane_idx]
	player.finish_position = finish_pos
	player.finished.connect(_on_car_finished)
	camera = $PlayerCar/Camera2D

	# Attach procedural visual — use selected car from menu
	var pvis = preload("res://car_visual.gd").new()
	pvis.car_type      = GameData.player_car_type
	pvis.car_color     = GameData.player_color
	pvis.is_player_car = true
	player.add_child(pvis)

	# Spawn AI cars in remaining lanes
	var ai_lane = 0
	for i in range(spawn_count):
		if ai_lane == player_lane_idx:
			ai_lane += 1
		var ai = preload("res://ai_car.gd").new()
		ai.car_label    = ai_roster[i].name
		ai.car_color    = ai_roster[i].color
		ai.progress     = 10.0  # slight offset so they're not at exact point 0
		ai.lane_offset  = lane_offsets[ai_lane]
		ai.scale        = CAR_SCALE
		ai.finished.connect(_on_car_finished)
		track_path.add_child(ai)
		ai_cars.append(ai)
		ai_lane += 1

	total_cars = 1 + ai_cars.size()  # player + AI


# ---------------------------------------------------------------------------
# Cookies & Jeeps
# ---------------------------------------------------------------------------
const _StarScene   = preload("res://star_pickup.gd")
const _HazardScene = preload("res://hazard_block.gd")

func _place_obstacles() -> void:
	for r in COOKIE_OFFSETS:
		var pos  = track_path.curve.sample_baked(track_path.curve.get_baked_length() * r)
		var star = _StarScene.new()
		star.position = pos
		star.scale    = Vector2(1.8, 1.8)
		star.set_meta("kind", "cookie")
		add_child(star)
		obstacles.append(star)

	for r in JEEP_OFFSETS:
		var pos    = track_path.curve.sample_baked(track_path.curve.get_baked_length() * r)
		var hazard = _HazardScene.new()
		hazard.position = pos
		hazard.scale    = Vector2(1.6, 1.6)
		hazard.set_meta("kind", "jeep")
		add_child(hazard)
		obstacles.append(hazard)


# ---------------------------------------------------------------------------
# HUD setup
# ---------------------------------------------------------------------------
func _setup_hud_refs() -> void:
	hud_place_numeral = $HUD/StatPanel/StatVBox/PositionRow/PlaceNumeral
	hud_place_suffix  = $HUD/StatPanel/StatVBox/PositionRow/PlaceSuffix
	hud_timer         = $HUD/StatPanel/StatVBox/TimerLabel
	hud_speed         = $HUD/StatPanel/StatVBox/SpeedLabel
	hud_boost_status  = $HUD/StatPanel/StatVBox/BoostStatusLabel
	hud_div3          = $HUD/StatPanel/StatVBox/Div3
	hud_place_up      = $HUD/PlaceUpLabel
	hud_countdown     = $HUD/CountdownLabel
	countdown_backing = $HUD/CountdownBacking
	flash_rect        = $HUD/FlashRect
	crash_label       = $HUD/CrashLabel
	boost_bar         = $HUD/BoostBar
	hype_bar          = $HUD/StandPanel/StandVBox/HypeBar
	hype_label        = $HUD/StandPanel/StandVBox/HypeLabel
	finish_banner     = $HUD/FinishBanner
	intro_card        = $HUD/IntroCard
	fade_overlay      = $HUD/FadeOverlay
	esc_dialog        = $HUD/EscDialog
	esc_yes_btn       = $HUD/EscDialog/EscPanel/EscVBox/EscBtnRow/EscYesBtn
	esc_no_btn        = $HUD/EscDialog/EscPanel/EscVBox/EscBtnRow/EscNoBtn

	# Apply bar background styles
	boost_bar.add_theme_stylebox_override("background", _bar_bg_style)
	hype_bar.add_theme_stylebox_override("fill",        _hype_style)
	hype_bar.add_theme_stylebox_override("background",  _bar_bg_style)

	# Style ESC dialog panel
	var esc_sbox = StyleBoxFlat.new()
	esc_sbox.bg_color = Color(0.07, 0.06, 0.18, 0.96)
	esc_sbox.border_width_left   = 2
	esc_sbox.border_width_top    = 2
	esc_sbox.border_width_right  = 2
	esc_sbox.border_width_bottom = 2
	esc_sbox.border_color = Color(0.333, 0.200, 0.733, 1)
	esc_sbox.corner_radius_top_left     = 12
	esc_sbox.corner_radius_top_right    = 12
	esc_sbox.corner_radius_bottom_right = 12
	esc_sbox.corner_radius_bottom_left  = 12
	esc_sbox.content_margin_left   = 24.0
	esc_sbox.content_margin_top    = 20.0
	esc_sbox.content_margin_right  = 24.0
	esc_sbox.content_margin_bottom = 20.0
	$HUD/EscDialog/EscPanel.add_theme_stylebox_override("panel", esc_sbox)

	esc_yes_btn.pressed.connect(_on_esc_yes)
	esc_no_btn.pressed.connect(_on_esc_no)

	hud_countdown.text = ""


func _setup_minimap() -> void:
	minimap = $HUD/Minimap
	var points: Array = []
	for p in TRACK_POINTS:
		points.append(p)
	minimap.setup(points, player, ai_cars, GameData.player_color)


func _setup_griddy() -> void:
	griddy_kid  = $HUD/GriddyKid
	griddy_anim = $HUD/GriddyKid/AnimationPlayer
	griddy_kid.frame = 0
	griddy_anim.animation_finished.connect(_on_griddy_finished)

	# Wait for layout to settle before reading GriddyFrame position
	await get_tree().process_frame
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var frame_rect = $HUD/StandPanel/StandVBox/GriddyFrame.get_global_rect()
	griddy_kid.position = frame_rect.get_center()
	_show_intro()


func _on_griddy_finished(anim_name: String) -> void:
	if anim_name == "griddy":
		griddy_kid.frame = 0


# ---------------------------------------------------------------------------
# Countdown helpers
# ---------------------------------------------------------------------------
func _show_countdown_digit(txt: String, col: Color, font_size: int = 96) -> void:
	hud_countdown.text = txt
	hud_countdown.add_theme_color_override("font_color", col)
	hud_countdown.add_theme_font_size_override("font_size", font_size)
	countdown_backing.color = Color(0, 0, 0, 0.45)
	hud_countdown.scale = Vector2(1.8, 1.8)
	var tw = create_tween()
	tw.tween_property(hud_countdown, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BACK)


func _hide_countdown() -> void:
	var tw = create_tween()
	tw.tween_property(hud_countdown,     "modulate:a",  0.0, 0.45)
	tw.parallel().tween_property(countdown_backing, "color:a", 0.0, 0.45)
	tw.tween_callback(func():
		hud_countdown.text       = ""
		hud_countdown.modulate.a = 1.0
		countdown_backing.color  = Color(0, 0, 0, 0.0)
	)


# ---------------------------------------------------------------------------
# HUD update (called every racing frame)
# ---------------------------------------------------------------------------
func _update_hud(delta: float) -> void:
	var place = _get_player_place()
	var sfx   = ["", "st", "nd", "rd", "th", "th"]
	hud_place_numeral.text = str(place)
	hud_place_suffix.text  = sfx[clamp(place, 0, 5)]

	match place:
		1: hud_place_numeral.add_theme_color_override("font_color", Color(1.0,  0.85, 0.10, 1))  # gold
		2: hud_place_numeral.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75, 1))  # silver
		3: hud_place_numeral.add_theme_color_override("font_color", Color(0.80, 0.50, 0.20, 1))  # bronze
		_: hud_place_numeral.add_theme_color_override("font_color", Color(1.0,  1.0,  1.0,  1))  # white

	# Place-Up flash — trigger when player gains a position
	if _last_place > 0 and place < _last_place:
		_flash_place_up()
	_last_place = place

	var mins = int(race_time) / 60
	var secs = fmod(race_time, 60.0)
	hud_timer.text = "%d:%05.2f" % [mins, secs]
	hud_speed.text = "%d km/h" % player.get_speed_kmh()

	# Boost status label — only visible during boost, stun, or bump (hidden when idle)
	if player.bump_time > 0 and player.crash_time <= 0:
		hud_boost_status.visible = true
		hud_div3.visible         = true
		hud_boost_status.text    = "BUMPED! %.1fs" % player.bump_time
		hud_boost_status.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2, 1))
	elif player.crash_time > 0:
		hud_boost_status.visible = true
		hud_div3.visible         = true
		hud_boost_status.text    = "STUNNED %.1fs" % player.crash_time
		hud_boost_status.add_theme_color_override("font_color", Color(1.0, 0.20, 0.20, 1))
	elif player.boost_time > 0:
		hud_boost_status.visible = true
		hud_div3.visible         = true
		hud_boost_status.text    = "BOOST %.1fs" % player.boost_time
		hud_boost_status.add_theme_color_override("font_color", Color(1.0, 0.85, 0.10, 1))
	else:
		hud_boost_status.visible = false
		hud_div3.visible         = false

	# Boost / stun bar at screen bottom
	if player.crash_time > 0:
		boost_bar.max_value = 2.0
		boost_bar.value = player.crash_time
		boost_bar.add_theme_stylebox_override("fill", _crash_style)
	elif player.boost_time > 0:
		boost_bar.max_value = 5.0
		boost_bar.value = player.boost_time
		boost_bar.add_theme_stylebox_override("fill", _boost_style)
	else:
		boost_bar.value = 0.0

	# Hype bar — drains after cookie collect
	if hype_timer > 0.0:
		hype_timer = max(0.0, hype_timer - delta)
		hype_bar.value = hype_timer
		hype_label.text = "HYPE!" if hype_timer > 1.0 else "..."
	else:
		hype_bar.value = 0.0
		hype_label.text = "..."


func _get_player_place() -> int:
	var player_prog = player.track_progress
	var ahead = 0
	for ai in ai_cars:
		# Finished AI cars are always "ahead" — treat their progress as infinite
		var ai_prog = INF if ai.has_finished else ai.progress
		if ai_prog > player_prog:
			ahead += 1
	return ahead + 1


# ---------------------------------------------------------------------------
# State machine
# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	# ESC — available in any state except FINISHED
	if state != State.FINISHED and Input.is_action_just_pressed("ui_cancel"):
		if _esc_dialog_open:
			_hide_esc_dialog()
		else:
			_show_esc_dialog()
		return

	if _esc_dialog_open:
		return

	match state:
		State.INTRO:
			intro_timer -= delta
			if intro_timer <= 0:
				state = State.COUNTDOWN

		State.COUNTDOWN:
			countdown_left -= delta
			if countdown_left > 0:
				var d = ceili(countdown_left)
				if d != last_digit_shown:
					last_digit_shown = d
					_show_countdown_digit(str(d), Color(1, 0.9, 0.1))
			elif last_digit_shown != 0:
				last_digit_shown = 0
				_show_countdown_digit("GO!", Color(0.2, 1.0, 0.3), 108)
			if countdown_left <= -0.6:
				_hide_countdown()
				state = State.RACING
				player.is_racing = true
				for ai in ai_cars:
					ai.is_racing = true

		State.RACING:
			race_time += delta
			_update_hud(delta)
			_constrain_to_road()
			_check_player_collisions()  # check before respawn so newly-visible items can't hit same frame
			_check_car_bumps(delta)
			_tick_respawns(delta)
			_check_force_finish(delta)

		State.FINISHED:
			pass


# ---------------------------------------------------------------------------
# Collisions
# ---------------------------------------------------------------------------
func _check_player_collisions() -> void:
	for child in obstacles:
		if not child.visible:
			continue

		var dist = player.position.distance_to(child.position)
		match child.get_meta("kind"):
			"cookie":
				if dist < 55:
					player.apply_boost()
					_play_griddy()
					_sparkle_at(child.position)
					_hide_pickup(child, cookie_timers, COOKIE_RESPAWN_SEC)
			"jeep":
				if dist < 65 and player.crash_time <= 0:
					player.apply_crash()
					_flash_screen()
					_hide_pickup(child, jeep_timers, JEEP_RESPAWN_SEC)

	# --- Option D: AI cars can also collect stars ---
	_check_ai_collisions()


func _check_ai_collisions() -> void:
	for ai in ai_cars:
		if ai.has_finished:
			continue
		var ai_pos = ai.global_position
		for child in obstacles:
			if not child.visible:
				continue
			var dist = ai_pos.distance_to(child.position)
			match child.get_meta("kind"):
				"cookie":
					if dist < 60:
						ai.apply_boost()
						_sparkle_at(child.position)
						_hide_pickup(child, cookie_timers, COOKIE_RESPAWN_SEC)


# ---------------------------------------------------------------------------
# Car-to-car bump collisions
# ---------------------------------------------------------------------------
func _check_car_bumps(delta: float) -> void:
	# Tick down cooldowns
	var expired: Array = []
	for key in bump_cooldowns.keys():
		bump_cooldowns[key] -= delta
		if bump_cooldowns[key] <= 0:
			expired.append(key)
	for key in expired:
		bump_cooldowns.erase(key)

	# Player vs AI
	if not player.has_finished and player.crash_time <= 0:
		for ai in ai_cars:
			if ai.has_finished:
				continue
			var pair_key = "player_" + ai.car_label
			if bump_cooldowns.has(pair_key):
				continue
			var dist = player.position.distance_to(ai.global_position)
			if dist < BUMP_DIST:
				player.apply_bump()
				ai.apply_bump()
				bump_cooldowns[pair_key] = BUMP_COOLDOWN
				_flash_bump(player.position)

	# AI vs AI
	for i in range(ai_cars.size()):
		if ai_cars[i].has_finished:
			continue
		for j in range(i + 1, ai_cars.size()):
			if ai_cars[j].has_finished:
				continue
			var pair_key = ai_cars[i].car_label + "_" + ai_cars[j].car_label
			if bump_cooldowns.has(pair_key):
				continue
			var dist = ai_cars[i].global_position.distance_to(ai_cars[j].global_position)
			if dist < BUMP_DIST:
				ai_cars[i].apply_bump()
				ai_cars[j].apply_bump()
				bump_cooldowns[pair_key] = BUMP_COOLDOWN


func _flash_bump(pos: Vector2) -> void:
	var lbl = Label.new()
	lbl.text = "BUMP!"
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2, 1))
	lbl.position = pos + Vector2(-30, -30)
	lbl.z_index  = 20
	add_child(lbl)
	var tw = create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 40, 0.5)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func(): lbl.queue_free())


func _play_griddy() -> void:
	if not griddy_anim.is_playing():
		griddy_anim.play("griddy")
	hype_timer = 5.0


func _constrain_to_road() -> void:
	var curve          = track_path.curve
	var closest_offset = curve.get_closest_offset(player.position)
	var closest_pt     = curve.sample_baked(closest_offset)
	var dist           = player.position.distance_to(closest_pt)
	if dist > ROAD_WIDTH * 0.48:
		player.position = closest_pt + (player.position - closest_pt).normalized() * ROAD_WIDTH * 0.48


func _flash_screen() -> void:
	crash_label.visible    = true
	crash_label.modulate.a = 1.0
	_do_camera_shake()
	var tw = create_tween()
	tw.tween_property(flash_rect,   "color:a",    0.45, 0.08)
	tw.tween_property(flash_rect,   "color:a",    0.0,  0.25)
	tw.tween_interval(0.25)
	tw.tween_property(crash_label, "modulate:a", 0.0,  0.45)
	tw.tween_callback(func(): crash_label.visible = false)


func _flash_place_up() -> void:
	hud_place_up.visible    = true
	hud_place_up.modulate.a = 1.0
	hud_place_up.scale      = Vector2(1.4, 1.4)
	var tw = create_tween()
	tw.tween_property(hud_place_up, "scale",      Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(0.8)
	tw.tween_property(hud_place_up, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func(): hud_place_up.visible = false)


func _hide_pickup(node: Node2D, timer_dict: Dictionary, delay: float) -> void:
	node.visible = false
	timer_dict[node] = delay


func _tick_respawns(delta: float) -> void:
	var to_show: Array = []
	for node in cookie_timers.keys():
		cookie_timers[node] -= delta
		if cookie_timers[node] <= 0:
			to_show.append(node)
	for node in to_show:
		node.visible = true
		cookie_timers.erase(node)

	to_show.clear()
	for node in jeep_timers.keys():
		jeep_timers[node] -= delta
		if jeep_timers[node] <= 0:
			to_show.append(node)
	for node in to_show:
		node.visible = true
		jeep_timers.erase(node)


# ---------------------------------------------------------------------------
# Force-finish safety — prevent infinite waiting
# ---------------------------------------------------------------------------
func _check_force_finish(delta: float) -> void:
	if _scene_changing:
		return

	# After player finishes, start countdown to force-finish remaining AI
	if _player_finished:
		_player_finish_timer += delta
		if _player_finish_timer >= FORCE_FINISH_DELAY:
			_force_finish_remaining()
			return

	# Absolute race timeout — force everyone to finish
	if race_time >= RACE_TIMEOUT:
		_force_finish_remaining()


func _force_finish_remaining() -> void:
	if _scene_changing:
		return
	# Write ALL remaining cars to finish_order synchronously BEFORE any await.
	# Calling _on_car_finished() in a loop was wrong: the first call that hits
	# finishers_count >= total_cars sets _scene_changing = true and suspends on
	# await, causing every subsequent call in the loop to return early — leaving
	# those cars absent from finish_order and the results screen empty.
	for ai in ai_cars:
		if not ai.has_finished:
			ai.has_finished = true
			ai.speed = 0.0
			_record_finish(ai.car_label)
	if not player.has_finished:
		player.has_finished = true
		player.speed = 0.0
		_record_finish("You")
	# All data is written — now trigger the single scene change.
	_trigger_scene_change()


# ---------------------------------------------------------------------------
# Finish
# ---------------------------------------------------------------------------

## Called by car signals (player_car / ai_car emit `finished`).
## Writes one entry to finish_order, then kicks off scene change when all done.
func _on_car_finished(car_name: String) -> void:
	if _scene_changing:
		return
	_record_finish(car_name)
	if finishers_count >= total_cars:
		_trigger_scene_change()


## Writes a single finish entry, guarded against duplicates.
## Does NOT await — safe to call in a loop.
func _record_finish(car_name: String) -> void:
	# Deduplicate: ignore if this car already has an entry (signal + force-finish race)
	for entry in GameData.finish_order:
		if entry.name == car_name:
			return
	GameData.finish_order.append({name = car_name, time = race_time})
	finishers_count += 1

	if car_name == "You":
		_player_finished = true

	# Show player finish banner immediately when the player crosses the line
	if car_name == "You" and not _finish_banner_shown:
		_finish_banner_shown = true
		var place    = finishers_count
		var suffixes = ["", "st", "nd", "rd", "th", "th"]
		var suf      = suffixes[clamp(place, 0, 5)]
		finish_banner.text = "RACE COMPLETE - %d%s!" % [place, suf]
		finish_banner.visible    = true
		finish_banner.modulate.a = 0.0
		var bw = create_tween()
		bw.tween_property(finish_banner, "modulate:a", 1.0, 0.3)


## Initiates the 2-second pause and scene transition to results.tscn.
## Must only be called AFTER all finish_order writes are complete.
func _trigger_scene_change() -> void:
	if _scene_changing:
		return
	_scene_changing = true
	state = State.FINISHED
	await get_tree().create_timer(2.0).timeout
	_change_scene("res://results.tscn")


# ---------------------------------------------------------------------------
# AI Intro Card
# ---------------------------------------------------------------------------
func _show_intro() -> void:
	intro_card.visible    = true
	intro_card.modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(intro_card, "modulate:a", 1.0, 0.35)
	tw.tween_interval(1.4)
	tw.tween_property(intro_card, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func(): intro_card.visible = false)


# ---------------------------------------------------------------------------
# ESC Confirmation Dialog
# ---------------------------------------------------------------------------
func _show_esc_dialog() -> void:
	_esc_dialog_open  = true
	esc_dialog.visible = true
	esc_no_btn.grab_focus()


func _hide_esc_dialog() -> void:
	_esc_dialog_open   = false
	esc_dialog.visible = false


func _on_esc_yes() -> void:
	_esc_dialog_open = false
	GameData.clear()
	_change_scene("res://main_menu.tscn")


func _on_esc_no() -> void:
	_hide_esc_dialog()


# ---------------------------------------------------------------------------
# Camera shake
# ---------------------------------------------------------------------------
func _do_camera_shake() -> void:
	var tw   = create_tween()
	var amp  = 8.0
	var steps = 10
	var dur  = 1.0
	for i in range(steps):
		var frac = 1.0 - float(i) / float(steps)
		var ox   = randf_range(-1.0, 1.0) * amp * frac
		var oy   = randf_range(-1.0, 1.0) * amp * frac
		tw.tween_property(camera, "offset", Vector2(ox, oy), dur / steps)
	tw.tween_property(camera, "offset", Vector2.ZERO, 0.06)


# ---------------------------------------------------------------------------
# Star sparkle on cookie collect
# ---------------------------------------------------------------------------
func _sparkle_at(pos: Vector2) -> void:
	var lbl = Label.new()
	lbl.text = "* BOOST! *"
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.1, 1))
	lbl.position = pos + Vector2(-52, -24)
	lbl.z_index  = 20
	add_child(lbl)
	var tw = create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 50, 0.6)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func(): lbl.queue_free())


# ---------------------------------------------------------------------------
# Scene fade transition helper
# ---------------------------------------------------------------------------
func _change_scene(path: String) -> void:
	fade_overlay.visible = true
	fade_overlay.color   = Color(0, 0, 0, 0)
	var tw = create_tween()
	tw.tween_property(fade_overlay, "color:a", 1.0, 0.4)
	tw.tween_callback(func(): get_tree().change_scene_to_file(path))
