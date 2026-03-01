extends Node2D

# ---------------------------------------------------------------------------
# Track waypoints — Overland Park map route
# ---------------------------------------------------------------------------
const TRACK_POINTS = [
	Vector2(1000,  600),   # 0  START
	Vector2(1000,  900),   # 1  south to 167th
	Vector2( 200,  900),   # 2  west
	Vector2(-500,  900),   # 3  west
	Vector2(-900,  900),   # 4  corner
	Vector2(-900, -200),   # 5  north (west edge)
	Vector2(-900, -700),   # 6  continue north
	Vector2(-200, -700),   # 7  east jog
	Vector2( 600, -700),   # 8  east along 159th
	Vector2(1200, -700),   # 9  continue east
	Vector2(1200,    0),   # 10 south on Antioch
	Vector2( 400,  300),   # 11 west into Wyngate
	Vector2(-200,  300),   # 12 continue west
	Vector2(-600,  600),   # 13 south Lakeshore
	Vector2(-1000, 400),   # 14 northwest Mills Farm
	Vector2(-1000,   0),   # 15 north
	Vector2(-1200, -100),  # 16 FINISH
]

const ROAD_WIDTH     = 280.0
const SHOULDER_W     = 320.0
const ROAD_COLOR     = Color(0.42, 0.42, 0.42, 1)
const SHOULDER_COLOR = Color(0.25, 0.25, 0.25, 1)
const DASH_COLOR     = Color(0.97, 0.88, 0.1, 1)
const DASH_LEN       = 70.0
const GAP_LEN        = 80.0

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

const CAR_SCALE    = Vector2(0.35, 0.35)
const JEEP_SCALE   = Vector2(0.38, 0.38)
const COOKIE_SCALE = Vector2(0.22, 0.22)

# ---------------------------------------------------------------------------
enum State { COUNTDOWN, RACING, FINISHED }
var state: State = State.COUNTDOWN
var countdown_left: float = 3.0
var race_time: float = 0.0
var finishers_count: int = 0
const TOTAL_CARS: int = 5

var player: Sprite2D
var ai_cars: Array = []
var track_path: Path2D
var finish_pos: Vector2

var cookie_timers: Dictionary = {}
var jeep_timers:   Dictionary = {}
var obstacles: Array = []  # all cookie + jeep sprites — avoids scanning get_children() every frame

# HUD node refs
var hud_place_numeral: Label
var hud_place_suffix:  Label
var hud_timer:         Label
var hud_speed:         Label
var hud_boost_status:  Label
var hud_countdown:     Label
var countdown_backing: ColorRect
var flash_rect:        ColorRect
var crash_label:       Label
var boost_bar:         ProgressBar
var hype_bar:          ProgressBar
var hype_label:        Label
var griddy_kid:        Sprite2D
var griddy_anim:       AnimationPlayer

var last_digit_shown: int = -1
var hype_timer: float = 0.0
var _scene_changing: bool = false

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

	_build_dashes()
	_add_marker(TRACK_POINTS[0],                       "START",  Color(0.1, 0.95, 0.1))
	_add_marker(TRACK_POINTS[TRACK_POINTS.size() - 1], "FINISH", Color(0.95, 0.15, 0.15))


func _build_dashes() -> void:
	var curve = Curve2D.new()
	for p in TRACK_POINTS:
		curve.add_point(p)

	var total_len = curve.get_baked_length()
	var pos       = DASH_LEN
	var drawing   = true

	while pos < total_len - DASH_LEN:
		if drawing:
			var p1 = curve.sample_baked(pos)
			var p2 = curve.sample_baked(min(pos + DASH_LEN, total_len))
			var dash = Line2D.new()
			dash.width = 7.0
			dash.default_color = DASH_COLOR
			dash.add_point(p1)
			dash.add_point(p2)
			dash.z_index = 1
			add_child(dash)
			pos += DASH_LEN
		else:
			pos += GAP_LEN
		drawing = not drawing


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

	player = $PlayerCar
	player.scale = CAR_SCALE
	player.finish_position = finish_pos
	player.finished.connect(_on_car_finished)

	for i in range(4):
		var ai = preload("res://ai_car.gd").new()
		ai.car_label = AI_NAMES[i]
		ai.car_color = AI_COLORS[i]
		ai.progress  = float(i) * 40.0
		ai.finished.connect(_on_car_finished)
		track_path.add_child(ai)
		ai_cars.append(ai)


# ---------------------------------------------------------------------------
# Cookies & Jeeps
# ---------------------------------------------------------------------------
func _place_obstacles() -> void:
	var cookie_tex = preload("res://cookie.png")
	var jeep_tex   = preload("res://Jeep.png")

	for r in COOKIE_OFFSETS:
		var pos = track_path.curve.sample_baked(track_path.curve.get_baked_length() * r)
		var c = _make_sprite(cookie_tex, pos, COOKIE_SCALE)
		c.set_meta("kind", "cookie")
		add_child(c)
		obstacles.append(c)

	for r in JEEP_OFFSETS:
		var pos = track_path.curve.sample_baked(track_path.curve.get_baked_length() * r)
		var j = _make_sprite(jeep_tex, pos, JEEP_SCALE)
		j.set_meta("kind", "jeep")
		add_child(j)
		obstacles.append(j)


func _make_sprite(tex: Texture2D, pos: Vector2, sc: Vector2) -> Sprite2D:
	var s = Sprite2D.new()
	s.texture = tex
	s.position = pos
	s.scale = sc
	return s


# ---------------------------------------------------------------------------
# HUD setup
# ---------------------------------------------------------------------------
func _setup_hud_refs() -> void:
	hud_place_numeral = $HUD/StatPanel/StatVBox/PositionRow/PlaceNumeral
	hud_place_suffix  = $HUD/StatPanel/StatVBox/PositionRow/PlaceSuffix
	hud_timer         = $HUD/StatPanel/StatVBox/TimerLabel
	hud_speed         = $HUD/StatPanel/StatVBox/SpeedLabel
	hud_boost_status  = $HUD/StatPanel/StatVBox/BoostStatusLabel
	hud_countdown     = $HUD/CountdownLabel
	countdown_backing = $HUD/CountdownBacking
	flash_rect        = $HUD/FlashRect
	crash_label       = $HUD/CrashLabel
	boost_bar         = $HUD/BoostBar
	hype_bar          = $HUD/StandPanel/StandVBox/HypeBar
	hype_label        = $HUD/StandPanel/StandVBox/HypeLabel

	# Apply bar background styles
	boost_bar.add_theme_stylebox_override("background", _bar_bg_style)
	hype_bar.add_theme_stylebox_override("fill",        _hype_style)
	hype_bar.add_theme_stylebox_override("background",  _bar_bg_style)

	hud_countdown.text = ""


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
	hud_countdown.text = ""
	countdown_backing.color = Color(0, 0, 0, 0.0)


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

	var mins = int(race_time) / 60
	var secs = fmod(race_time, 60.0)
	hud_timer.text = "%d:%05.2f" % [mins, secs]
	hud_speed.text = "%d km/h" % player.get_speed_kmh()

	# Boost status label (triple-state)
	if player.crash_time > 0:
		hud_boost_status.text = "STUNNED %.1fs" % player.crash_time
		hud_boost_status.add_theme_color_override("font_color", Color(1.0, 0.20, 0.20, 1))
	elif player.boost_time > 0:
		hud_boost_status.text = "BOOST %.1fs" % player.boost_time
		hud_boost_status.add_theme_color_override("font_color", Color(1.0, 0.85, 0.10, 1))
	else:
		hud_boost_status.text = "BOOST READY"
		hud_boost_status.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55, 1))

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
	match state:
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
			_check_player_collisions()  # check before respawn so newly-visible items can't hit same frame
			_tick_respawns(delta)

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
					_hide_pickup(child, cookie_timers, COOKIE_RESPAWN_SEC)
			"jeep":
				if dist < 65:
					player.apply_crash()
					_flash_screen()
					_hide_pickup(child, jeep_timers, JEEP_RESPAWN_SEC)


func _play_griddy() -> void:
	if not griddy_anim.is_playing():
		griddy_anim.play("griddy")
	hype_timer = 5.0


func _flash_screen() -> void:
	crash_label.visible = true
	var tw = create_tween()
	tw.tween_property(flash_rect, "color:a", 0.45, 0.08)
	tw.tween_property(flash_rect, "color:a", 0.0,  0.25)
	tw.tween_interval(0.2)
	tw.tween_callback(func(): crash_label.visible = false)


func _hide_pickup(node: Sprite2D, timer_dict: Dictionary, delay: float) -> void:
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
# Finish
# ---------------------------------------------------------------------------
func _on_car_finished(car_name: String) -> void:
	if _scene_changing:
		return
	GameData.finish_order.append({name = car_name, time = race_time})
	finishers_count += 1
	if finishers_count >= TOTAL_CARS:
		_scene_changing = true
		state = State.FINISHED
		await get_tree().create_timer(2.0).timeout
		get_tree().change_scene_to_file("res://results.tscn")
