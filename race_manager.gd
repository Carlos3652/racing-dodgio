extends Node2D

# ---------------------------------------------------------------------------
# Track waypoints — loaded dynamically from GameData.TRACKS
# ---------------------------------------------------------------------------
var TRACK_POINTS: Array = []

const ROAD_WIDTH     = 380.0
const BUMP_DIST      = 55.0   # car-to-car collision distance
const BUMP_COOLDOWN  = 2.0    # seconds between bump checks per pair
const SHOULDER_W     = 500.0  # wider shoulder for visible off-road grass
var road_color     = Color(0.172, 0.172, 0.220, 1)
var shoulder_color = Color(0.102, 0.180, 0.102, 1)
const DASH_COLOR     = Color(1.000, 0.878, 0.200, 1)
const DASH_LEN       = 90.0
const GAP_LEN        = 55.0
const CURB_WHITE     = Color(0.941, 0.929, 0.878, 1)
var curb_alt_color   = Color(0.800, 0.133, 0.000, 1)
const CURB_STRIPE_LEN   = 50.0
const CURB_STRIPE_WIDTH = 24.0
const GATE_NEON_COLOR   = Color(0.0, 0.9, 1.0, 0.90)
const GATE_CORE_COLOR   = Color(1.0, 1.0, 1.0, 0.70)

const AI_COLORS = [
	Color(0.2,  0.5,  1.0),
	Color(0.2,  0.85, 0.3),
	Color(1.0,  0.55, 0.1),
	Color(0.85, 0.2,  0.85),
]
const AI_NAMES = ["Blue", "Green", "Orange", "Purple"]

# AI Personality Archetypes
const AI_PERSONALITIES = {
	"Blue":   {bump_radius_bonus = 10.0, bump_slow_duration = 1.5},                          # "The Blocker" — wider bump zone
	"Green":  {base_speed_bonus = 20.0, noise_variance = 8.0},                                 # "The Drifter" — faster, moderate noise
	"Orange": {bump_slow_duration = 0.75},                                                     # "The Tank" — shrugs off bumps
	"Purple": {base_speed_bonus = 30.0, boost_duration = 3.5},                                 # "The Phantom" — fastest, shorter boost
}

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
var _ai_star_radius: float = 55.0  # difficulty-adjusted in _ready()

# HUD node refs
var hud_place_numeral: Label
var hud_place_suffix:  Label
var hud_timer:         Label
var hud_speed:         Label
var hud_boost_status:  Label
var hud_lap:           Label
var hud_gap:           Label
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
var _perfect_start_pending: bool = false
var _false_start: bool = false
var _last_hud_lap: int = 0
var hype_timer:       float = 0.0
var _scene_changing:  bool  = false
var _last_place:      int   = 0
var _esc_dialog_open: bool  = false
var _finish_banner_shown: bool = false
var _player_finished: bool  = false
var _player_finish_timer: float = 0.0
const FORCE_FINISH_DELAY: float = 10.0
const RACE_TIMEOUT: float = 300.0
const BASE_ZOOM = Vector2(0.65, 0.65)
const BOOST_ZOOM_FACTOR = 0.88

# Race stats tracking (written to GameData at end)
var _stat_stars: int = 0
var _stat_stuns: int = 0
var _stat_bumps: int = 0
var _stat_boost_frames: int = 0
var _stat_total_frames: int = 0
var _stat_lead_changes: int = 0
var _stat_last_leader: String = ""
var _stat_close_calls: int = 0
var _close_call_cooldown: float = 0.0

# New HUD refs
var esc_dialog:    Control
var esc_yes_btn:   Button
var esc_no_btn:    Button
var finish_banner: Label
var intro_card:    Label
var fade_overlay:  ColorRect
var camera:        Camera2D
var _zoom_tween:   Tween = null
var _boost_was_active: bool = false
var _boost_bar_state: String = "none"  # "crash", "boost", or "none" — tracks last bar mode to avoid per-frame overrides
var minimap:       Control
var crash_sfx:     AudioStreamPlayer
var bump_sfx:      AudioStreamPlayer
var cd_beep_sfx:   AudioStreamPlayer
var cd_go_sfx:     AudioStreamPlayer

# StyleBoxFlat instances for dynamic bar coloring
var _boost_style:  StyleBoxFlat
var _crash_style:  StyleBoxFlat
var _bar_bg_style: StyleBoxFlat
var _hype_style:   StyleBoxFlat


func _ready() -> void:
	# Load track points from GameData based on current_track_index
	var idx = GameData.current_track_index
	var track_data
	if idx >= 0 and idx < GameData.TRACKS.size():
		track_data = GameData.TRACKS[idx]
	else:
		track_data = GameData.TRACKS[0]
	TRACK_POINTS = track_data.points.duplicate()

	# Apply per-track color theme
	if track_data.has("theme"):
		var theme = track_data.theme
		road_color     = theme.get("road_color", road_color)
		shoulder_color = theme.get("shoulder_color", shoulder_color)
		curb_alt_color = theme.get("curb_alt_color", curb_alt_color)

	# Difficulty-adjusted AI star pickup radius
	match GameData.difficulty:
		"easy":  _ai_star_radius = 50.0
		"hard":  _ai_star_radius = 70.0
		_:       _ai_star_radius = 55.0

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
	shoulder.default_color = shoulder_color
	shoulder.joint_mode = Line2D.LINE_JOINT_ROUND
	shoulder.begin_cap_mode = Line2D.LINE_CAP_NONE
	shoulder.end_cap_mode   = Line2D.LINE_CAP_NONE
	for p in TRACK_POINTS:
		shoulder.add_point(p)

	var road = $Road as Line2D
	road.width = ROAD_WIDTH
	road.default_color = road_color
	road.joint_mode = Line2D.LINE_JOINT_ROUND
	road.begin_cap_mode = Line2D.LINE_CAP_NONE
	road.end_cap_mode   = Line2D.LINE_CAP_NONE
	for p in TRACK_POINTS:
		road.add_point(p)

	# Build a shared curve used by dashes, stripes, arrows, and lane dividers
	var curve = Curve2D.new()
	for p in TRACK_POINTS:
		curve.add_point(p)

	_build_dashes(curve)
	_build_lane_dividers(curve)
	_build_curb_stripes(curve)
	_build_direction_arrows(curve)
	_build_corner_markers()

	# Start gate with posts
	var start_dir = (TRACK_POINTS[1] - TRACK_POINTS[0]).normalized()
	_add_start_gate(TRACK_POINTS[0], start_dir)

	# Checkered finish line at start/finish point
	_add_finish_checkered(TRACK_POINTS[0])

	# Figure Eight crossover marker (by track name, not hardcoded index)
	var idx_track = GameData.current_track_index
	if idx_track >= 0 and idx_track < GameData.TRACKS.size() and GameData.TRACKS[idx_track].name == "Figure Eight":
		_build_figure_eight_crossover()


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


func _sample_looped(curve: Curve2D, t: float, total: float) -> Vector2:
	return curve.sample_baked(fposmod(t, total))


func _curve_normal(curve: Curve2D, t: float, total: float, delta: float = 5.0) -> Vector2:
	var tan_vec = (_sample_looped(curve, t + delta, total) - _sample_looped(curve, t - delta, total)).normalized()
	return Vector2(-tan_vec.y, tan_vec.x)


func _build_curb_stripes(curve: Curve2D) -> void:
	var total_len = curve.get_baked_length()
	# Offset curb center so inner edge sits flush with road edge
	var offset    = (ROAD_WIDTH * 0.5) + (CURB_STRIPE_WIDTH * 0.5)

	# Phase-sync: fit an integer number of stripes so the loop closes exactly
	var stripe_count = int(total_len / CURB_STRIPE_LEN)
	if stripe_count < 1:
		stripe_count = 1
	var adj_len  = total_len / float(stripe_count)

	# Gate exclusion zone for neon gate curbs (Variant B)
	var gate_half = 100.0

	var pos      = 0.0
	var is_white = true

	while pos < total_len - 0.1:
		var end_pos = min(pos + adj_len, total_len)

		# Skip stripes inside the start/finish gate zone
		var near_start = pos < gate_half
		var near_end   = end_pos > (total_len - gate_half)

		if not near_start and not near_end:
			var col  = CURB_WHITE if is_white else curb_alt_color

			# Subdivide stripe into multiple points so it follows the curve on corners
			var sub_count = 8  # 8 sub-segments per stripe = 9 sample points
			var left = Line2D.new()
			left.width         = CURB_STRIPE_WIDTH
			left.default_color = col
			left.begin_cap_mode = Line2D.LINE_CAP_SQUARE
			left.end_cap_mode   = Line2D.LINE_CAP_SQUARE
			left.z_index = 1

			var right = Line2D.new()
			right.width         = CURB_STRIPE_WIDTH
			right.default_color = col
			right.begin_cap_mode = Line2D.LINE_CAP_SQUARE
			right.end_cap_mode   = Line2D.LINE_CAP_SQUARE
			right.z_index = 1

			for s in range(sub_count + 1):
				var t = pos + (end_pos - pos) * (float(s) / float(sub_count))
				var pt = _sample_looped(curve, t, total_len)
				var n  = _curve_normal(curve, t, total_len)
				left.add_point(pt - n * offset)
				right.add_point(pt + n * offset)

			add_child(left)
			add_child(right)

		pos      += adj_len
		is_white  = not is_white

	# Neon gate curbs at the start/finish seam
	_build_neon_gate_curbs(curve, total_len, gate_half)


func _build_neon_gate_curbs(curve: Curve2D, total_len: float, gate_half: float) -> void:
	var offset  = (ROAD_WIDTH * 0.5) + (CURB_STRIPE_WIDTH * 0.5)
	var outer_w = (CURB_STRIPE_WIDTH + 6.0) * 0.5  # 15px half-width
	var core_w  = 5.0

	# Sample positions at gate boundaries
	var p_before = curve.sample_baked(total_len - gate_half)
	var p_after  = curve.sample_baked(gate_half)

	# Per-endpoint normals so the gate follows the curve on banked starts
	var perp_before = _curve_normal(curve, total_len - gate_half, total_len)
	var perp_after  = _curve_normal(curve, gate_half, total_len)

	# Build neon band on each side of the road
	for side in [-1.0, 1.0]:
		var off_before = perp_before * offset * side
		var wv_before  = perp_before * side
		var off_after  = perp_after  * offset * side
		var wv_after   = perp_after  * side

		# Outer cyan neon quad
		var outer = Polygon2D.new()
		outer.polygon = PackedVector2Array([
			p_before + off_before - wv_before * outer_w,
			p_before + off_before + wv_before * outer_w,
			p_after  + off_after  + wv_after  * outer_w,
			p_after  + off_after  - wv_after  * outer_w,
		])
		outer.color   = GATE_NEON_COLOR
		outer.z_index = 2
		add_child(outer)

		# Inner white core quad
		var core = Polygon2D.new()
		core.polygon = PackedVector2Array([
			p_before + off_before - wv_before * core_w,
			p_before + off_before + wv_before * core_w,
			p_after  + off_after  + wv_after  * core_w,
			p_after  + off_after  - wv_after  * core_w,
		])
		core.color   = GATE_CORE_COLOR
		core.z_index = 3
		add_child(core)


func _build_lane_dividers(curve: Curve2D) -> void:
	var offsets_arr = [-ROAD_WIDTH / 3.0, ROAD_WIDTH / 3.0]
	var total_len = curve.get_baked_length()
	for lane_off in offsets_arr:
		var pos = 30.0
		var drawing = true
		while pos < total_len - 30.0:
			if drawing:
				var t1 = curve.sample_baked(pos)
				var t2 = curve.sample_baked(min(pos + 45.0, total_len))
				# Compute perpendicular at each endpoint independently (prevents drift on curves)
				var d1 = (curve.sample_baked(min(pos + 1.0, total_len)) - t1).normalized()
				var p1 = Vector2(-d1.y, d1.x)
				var d2 = (curve.sample_baked(min(pos + 46.0, total_len)) - t2).normalized()
				var p2 = Vector2(-d2.y, d2.x)
				var line = Line2D.new()
				line.width = 6.0
				line.default_color = Color(0.88, 0.88, 0.88, 0.40)
				line.add_point(t1 + p1 * lane_off)
				line.add_point(t2 + p2 * lane_off)
				line.z_index = 2
				add_child(line)
				pos += 45.0
			else:
				pos += 35.0
			drawing = not drawing


func _build_direction_arrows(curve: Curve2D) -> void:
	var total_len = curve.get_baked_length()
	var pos = 200.0
	while pos < total_len - 200.0:
		var center = curve.sample_baked(pos)
		var ahead  = curve.sample_baked(min(pos + 20.0, total_len))
		var dir = (ahead - center).normalized()
		var perp = Vector2(-dir.y, dir.x)
		var tip = center + dir * 45.0
		var bl  = center - dir * 15.0 + perp * 28.0
		var br  = center - dir * 15.0 - perp * 28.0
		var arrow = Polygon2D.new()
		arrow.polygon = PackedVector2Array([tip, bl, br])
		arrow.color   = Color(1.0, 0.85, 0.10, 0.30)
		arrow.z_index = 2
		add_child(arrow)
		pos += 400.0


func _build_corner_markers() -> void:
	var pts = TRACK_POINTS
	for i in range(1, pts.size() - 1):
		var a = pts[i - 1]
		var b = pts[i]
		var c = pts[i + 1] if i + 1 < pts.size() else pts[0]
		var in_dir  = (b - a).normalized()
		var out_dir = (c - b).normalized()
		var angle   = in_dir.angle_to(out_dir)
		# Only mark sharp corners (more than 35 degrees)
		if abs(angle) < deg_to_rad(35.0):
			continue
		var perp = Vector2(-in_dir.y, in_dir.x)
		var inside = sign(angle)
		var marker_pos = b + perp * (ROAD_WIDTH * 0.35 * inside)
		var td = out_dir
		var tp = Vector2(-td.y, td.x)
		var dot = Polygon2D.new()
		dot.polygon = PackedVector2Array([
			marker_pos + td * 18.0,
			marker_pos - td * 10.0 + tp * 12.0,
			marker_pos - td * 10.0 - tp * 12.0,
		])
		dot.color   = Color(1.0, 0.45, 0.10, 0.75)
		dot.z_index = 3
		add_child(dot)


func _build_figure_eight_crossover() -> void:
	# Find the approximate crossover center — midpoint of the track
	var mid_idx = TRACK_POINTS.size() / 2
	var cross_center = TRACK_POINTS[mid_idx] if mid_idx < TRACK_POINTS.size() else Vector2.ZERO
	var sz = ROAD_WIDTH * 0.55
	# Yellow diamond marker on the road surface
	var diamond = Polygon2D.new()
	diamond.polygon = PackedVector2Array([
		cross_center + Vector2(0, -sz * 0.5),
		cross_center + Vector2(sz * 0.4, 0),
		cross_center + Vector2(0, sz * 0.5),
		cross_center + Vector2(-sz * 0.4, 0),
	])
	diamond.color   = Color(1.0, 0.85, 0.10, 0.50)
	diamond.z_index = 3
	add_child(diamond)
	# "X" label at center
	var lbl = Label.new()
	lbl.text = "X"
	lbl.add_theme_font_size_override("font_size", 48)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.10, 0.70))
	lbl.position = cross_center + Vector2(-18, -32)
	lbl.z_index  = 4
	add_child(lbl)


func _add_start_gate(pos: Vector2, dir: Vector2) -> void:
	var perp = Vector2(-dir.y, dir.x)
	var half = ROAD_WIDTH * 0.5 + 12.0

	# Full-width green stripe painted on asphalt
	for row_i in [-1, 0]:
		var stripe = Polygon2D.new()
		var row_offset = dir * float(row_i) * 18.0
		var c0 = pos + row_offset + perp * (-half)
		var c1 = pos + row_offset + perp * ( half)
		var c2 = pos + row_offset + dir * 18.0 + perp * ( half)
		var c3 = pos + row_offset + dir * 18.0 + perp * (-half)
		stripe.polygon = PackedVector2Array([c0, c1, c2, c3])
		stripe.color   = Color(0.08, 0.80, 0.20, 0.70)
		stripe.z_index = 3
		add_child(stripe)

	# Left post (small square straddling the road edge)
	var lc = pos + perp * (-(half + 10.0))
	var lpost = Polygon2D.new()
	lpost.polygon = PackedVector2Array([
		lc + perp * (-10.0) + dir * (-10.0), lc + perp * (10.0) + dir * (-10.0),
		lc + perp * (10.0) + dir * (10.0), lc + perp * (-10.0) + dir * (10.0),
	])
	lpost.color   = Color(0.08, 0.80, 0.20, 1.0)
	lpost.z_index = 4
	add_child(lpost)

	# Right post
	var rc = pos + perp * (half + 10.0)
	var rpost = Polygon2D.new()
	rpost.polygon = PackedVector2Array([
		rc + perp * (-10.0) + dir * (-10.0), rc + perp * (10.0) + dir * (-10.0),
		rc + perp * (10.0) + dir * (10.0), rc + perp * (-10.0) + dir * (10.0),
	])
	rpost.color   = Color(0.08, 0.80, 0.20, 1.0)
	rpost.z_index = 4
	add_child(rpost)

	# "START" label — larger, centered above gate
	var lbl = Label.new()
	lbl.text = "START / FINISH"
	lbl.add_theme_font_size_override("font_size", 42)
	lbl.add_theme_color_override("font_color", Color(0.08, 0.90, 0.25, 1.0))
	lbl.position = pos + dir * (-50.0) + perp * (-52.0)
	lbl.z_index  = 5
	add_child(lbl)


func _add_finish_checkered(pos: Vector2) -> void:
	# Direction of road at start/finish (same as start gate direction)
	var dir  = (TRACK_POINTS[1] - TRACK_POINTS[0]).normalized()
	var perp = Vector2(-dir.y, dir.x)
	var half = ROAD_WIDTH * 0.5 + 12.0

	# Checkerboard pattern
	const COLS = 10
	const ROWS = 3
	var cell_w = ROAD_WIDTH / float(COLS)
	var cell_h = 20.0

	for col_i in range(COLS):
		for row_i in range(ROWS):
			var col_t  = (float(col_i) / COLS) - 0.5 + (0.5 / COLS)
			var row_t  = (float(row_i) - float(ROWS) * 0.5 + 0.5) * cell_h
			var center = pos + perp * (col_t * ROAD_WIDTH) + dir * row_t

			var hw = cell_w * 0.5
			var hh = cell_h * 0.5
			var c0 = center + perp * (-hw) + dir * (-hh)
			var c1 = center + perp * ( hw) + dir * (-hh)
			var c2 = center + perp * ( hw) + dir * ( hh)
			var c3 = center + perp * (-hw) + dir * ( hh)

			var poly = Polygon2D.new()
			poly.polygon = PackedVector2Array([c0, c1, c2, c3])
			poly.color   = Color(1, 1, 1, 0.95) if (col_i + row_i) % 2 == 0 else Color(0, 0, 0, 0.95)
			poly.z_index = 3
			add_child(poly)

	# Left post (small square)
	var lc = pos + perp * (-(half + 10.0))
	var lpost = Polygon2D.new()
	lpost.polygon = PackedVector2Array([
		lc + perp * (-10.0) + dir * (-10.0), lc + perp * (10.0) + dir * (-10.0),
		lc + perp * (10.0) + dir * (10.0), lc + perp * (-10.0) + dir * (10.0),
	])
	lpost.color   = Color(0.95, 0.95, 0.95, 1.0)
	lpost.z_index = 4
	add_child(lpost)

	# Right post
	var rc = pos + perp * (half + 10.0)
	var rpost = Polygon2D.new()
	rpost.polygon = PackedVector2Array([
		rc + perp * (-10.0) + dir * (-10.0), rc + perp * (10.0) + dir * (-10.0),
		rc + perp * (10.0) + dir * (10.0), rc + perp * (-10.0) + dir * (10.0),
	])
	rpost.color   = Color(0.95, 0.95, 0.95, 1.0)
	rpost.z_index = 4
	add_child(rpost)

	# "FINISH" label — larger
	var lbl = Label.new()
	lbl.text = "FINISH"
	lbl.add_theme_font_size_override("font_size", 42)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	lbl.position = pos + dir * (-55.0) + perp * (-60.0)
	lbl.z_index  = 5
	add_child(lbl)


# ---------------------------------------------------------------------------
# Path2D + player + AI
# ---------------------------------------------------------------------------
func _build_track_path() -> void:
	track_path = $TrackPath as Path2D
	var curve = Curve2D.new()
	for p in TRACK_POINTS:
		curve.add_point(p)
	track_path.curve = curve

	finish_pos = TRACK_POINTS[0]

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

	# F1-style staggered grid: 2 columns, rows spaced behind the start line
	# Grid positions: row 0 = pole, row 1 = P2/P3, row 2 = P4/P5
	var total_slots = 1 + spawn_count
	var row_spacing = 110.0  # distance between grid rows along the track (~2 car lengths)
	var col_offset  = ROAD_WIDTH * 0.27  # lateral offset from center (~204px apart)

	# Build grid slots: [{row, side}] — side: -1 = left, +1 = right
	# Row 0: center (pole). Row 1+: alternating left/right
	var grid_slots: Array = []
	grid_slots.append({row = 0, side = 0.0})       # P1 — pole position (center)
	for i in range(1, total_slots):
		var row = (i + 1) / 2  # P2/P3 = row 1, P4/P5 = row 2
		var side = -1.0 if (i % 2 == 1) else 1.0
		grid_slots.append({row = row, side = side})

	# Player starts in P3 (middle of the pack), randomize in future if desired
	var player_grid = total_slots / 2

	player = $PlayerCar
	player.scale = CAR_SCALE
	var p_slot = grid_slots[player_grid]
	var p_back = start_dir * (-row_spacing * p_slot.row)
	var p_side = start_perp * (col_offset * p_slot.side)
	player.position = TRACK_POINTS[0] + p_back + p_side
	# Face the player in the direction of travel (car draws pointing UP = -Y)
	player.rotation = start_dir.angle() + PI / 2.0
	# Set up finish line for player lap detection
	var fl_perp = Vector2(-start_dir.y, start_dir.x)
	var fl_half = ROAD_WIDTH * 0.6
	player.finish_line_a = TRACK_POINTS[0] + fl_perp * (-fl_half)
	player.finish_line_b = TRACK_POINTS[0] + fl_perp * fl_half
	player.finish_line_dir = start_dir
	player.total_laps = GameData.TOTAL_LAPS
	player.min_progress_for_lap = track_path.curve.get_baked_length() * 0.7
	player._prev_pos = player.position
	player.finished.connect(_on_car_finished)
	camera = $PlayerCar/Camera2D

	# Attach procedural visual — use selected car from menu
	var pvis = preload("res://car_visual.gd").new()
	pvis.car_type      = GameData.player_car_type
	pvis.car_color     = GameData.player_color
	pvis.is_player_car = true
	player.add_child(pvis)

	# Spawn AI cars in remaining grid slots
	var ai_slot_idx = 0
	for i in range(spawn_count):
		if ai_slot_idx == player_grid:
			ai_slot_idx += 1
		var slot = grid_slots[ai_slot_idx]
		var ai = preload("res://ai_car.gd").new()
		ai.car_label    = ai_roster[i].name
		ai.car_color    = ai_roster[i].color
		# Stagger start progress along track based on grid row (further back = less progress)
		ai.progress     = max(row_spacing - slot.row * row_spacing, 0.0)
		ai.lane_offset  = col_offset * slot.side
		ai.scale        = CAR_SCALE
		ai.total_laps = GameData.TOTAL_LAPS
		# Apply personality archetype
		if AI_PERSONALITIES.has(ai_roster[i].name):
			ai.personality = AI_PERSONALITIES[ai_roster[i].name].duplicate()
		ai.player_ref = player
		ai.finished.connect(_on_car_finished)
		track_path.add_child(ai)
		ai_cars.append(ai)
		ai_slot_idx += 1

	total_cars = 1 + ai_cars.size()  # player + AI


# ---------------------------------------------------------------------------
# Cookies & Jeeps
# ---------------------------------------------------------------------------
const _StarScene   = preload("res://star_pickup.gd")
const _HazardScene = preload("res://hazard_block.gd")

func _place_obstacles() -> void:
	# Read track-specific offsets, falling back to defaults
	var idx = GameData.current_track_index
	var track_data = GameData.TRACKS[idx] if idx >= 0 and idx < GameData.TRACKS.size() else {}
	var star_offs = track_data.get("star_offsets", COOKIE_OFFSETS)
	var jeep_offs = track_data.get("jeep_offsets", JEEP_OFFSETS)

	var curve = track_path.curve
	var curve_len = curve.get_baked_length()
	var lane_range = ROAD_WIDTH * 0.35  # max lateral offset from center

	for r in star_offs:
		var dist = curve_len * r
		var pos  = curve.sample_baked(dist)
		# Randomize lateral position across the road
		var lateral = randf_range(-lane_range, lane_range)
		var normal  = _curve_normal(curve, dist, curve_len)
		pos += normal * lateral
		var star = _StarScene.new()
		star.position = pos
		star.scale    = Vector2(1.8, 1.8)
		var kind = "shield" if randf() < 0.20 else "cookie"
		star.set_meta("kind", kind)
		add_child(star)
		obstacles.append(star)

	for r in jeep_offs:
		var dist   = curve_len * r
		var pos    = curve.sample_baked(dist)
		# Randomize lateral position — avoid same lane as stars
		var lateral = randf_range(-lane_range, lane_range)
		var normal  = _curve_normal(curve, dist, curve_len)
		pos += normal * lateral
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

	# Create lap counter label dynamically
	hud_lap = Label.new()
	hud_lap.text = "LAP 1/%d" % GameData.TOTAL_LAPS
	hud_lap.add_theme_font_size_override("font_size", 22)
	hud_lap.add_theme_color_override("font_color", Color(0.9, 0.85, 1.0, 1))
	hud_lap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Insert after SpeedLabel (index 3 in StatVBox: PositionRow, TimerLabel, SpeedLabel)
	var stat_vbox = $HUD/StatPanel/StatVBox
	stat_vbox.add_child(hud_lap)
	stat_vbox.move_child(hud_lap, stat_vbox.get_child_count() - 1)

	# Gap-to-leader label
	hud_gap = Label.new()
	hud_gap.text = ""
	hud_gap.add_theme_font_size_override("font_size", 18)
	hud_gap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stat_vbox.add_child(hud_gap)

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
	crash_sfx         = $CrashSFX
	bump_sfx          = $BumpSFX
	cd_beep_sfx       = $CountdownBeepSFX
	cd_go_sfx         = $CountdownGoSFX

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
	_set_griddy_frame(0)
	griddy_anim.animation_finished.connect(_on_griddy_finished)

	# Wait 2 frames for layout to settle before reading GriddyFrame position.
	# Frame 1: skip via ONE_SHOT, then reconnect for frame 2.
	get_tree().process_frame.connect(_on_griddy_layout_first_frame, CONNECT_ONE_SHOT)


func _on_griddy_layout_first_frame() -> void:
	# Frame 1 elapsed; wait one more frame then finalise position.
	get_tree().process_frame.connect(_on_griddy_layout_ready, CONNECT_ONE_SHOT)


func _on_griddy_layout_ready() -> void:
	if not is_inside_tree():
		return
	var frame_rect = $HUD/StandPanel/StandVBox/GriddyFrame.get_global_rect()
	griddy_kid.position = frame_rect.get_center()
	_show_intro()


func _set_griddy_frame(f: int) -> void:
	# Intentional silent no-op when griddy_kid is null — can happen if the HUD
	# node tree hasn't been set up yet or was freed between frames.
	if griddy_kid == null:
		push_warning("_set_griddy_frame called with null griddy_kid — skipping (this is expected during teardown)")
		return
	if griddy_kid is AnimatedSprite2D or griddy_kid is Sprite2D:
		griddy_kid.frame = f
	else:
		push_warning("griddy_kid is %s, expected AnimatedSprite2D or Sprite2D" % griddy_kid.get_class())


func _on_griddy_finished(anim_name: String) -> void:
	if anim_name == "griddy":
		_set_griddy_frame(0)


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
	if not is_instance_valid(player):
		return
	var place = _get_player_place()
	var sfx   = ["", "st", "nd", "rd", "th", "th"]
	hud_place_numeral.text = str(place)
	hud_place_suffix.text  = sfx[clamp(place, 1, 5)]

	match place:
		1: hud_place_numeral.add_theme_color_override("font_color", Color(1.0,  0.85, 0.10, 1))  # gold
		2: hud_place_numeral.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75, 1))  # silver
		3: hud_place_numeral.add_theme_color_override("font_color", Color(0.80, 0.50, 0.20, 1))  # bronze
		_: hud_place_numeral.add_theme_color_override("font_color", Color(1.0,  1.0,  1.0,  1))  # white

	# Place-Up flash — trigger when player gains a position
	if _last_place > 0 and place < _last_place:
		_flash_place_up()
	_last_place = place

	var secs = fmod(race_time, 60.0)
	var mins = int(race_time) / 60
	if secs >= 59.995:
		secs = 0.0
		mins += 1
	hud_timer.text = "%d:%05.2f" % [mins, secs]
	hud_speed.text = "%d km/h" % player.get_speed_kmh()
	hud_lap.text = "LAP %d/%d" % [min(player.current_lap + 1, GameData.TOTAL_LAPS), GameData.TOTAL_LAPS]

	# Lap change — punch animation + gold border flash
	if player.current_lap != _last_hud_lap and player.current_lap > 0 and player.current_lap < GameData.TOTAL_LAPS:
		_last_hud_lap = player.current_lap
		# Punch scale on lap counter
		var tw_lap = create_tween()
		hud_lap.scale = Vector2(1.6, 1.6)
		tw_lap.tween_property(hud_lap, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_BOUNCE)
		# Gold border flash
		var flash = ColorRect.new()
		flash.color = Color(1.0, 0.85, 0.2, 0.6)
		flash.anchors_preset = Control.PRESET_FULL_RECT
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flash.z_index = 100
		var canvas = get_node("CanvasLayer") if has_node("CanvasLayer") else self
		canvas.add_child(flash)
		var tw_flash = create_tween()
		tw_flash.tween_property(flash, "color:a", 0.0, 0.4)
		tw_flash.tween_callback(flash.queue_free)
	elif player.current_lap != _last_hud_lap:
		_last_hud_lap = player.current_lap

	# Gap-to-leader (or lead over 2nd)
	var curve_len = track_path.curve.get_baked_length()
	var player_total = float(player.current_lap) * curve_len + player.track_progress
	if place == 1:
		# Show lead over 2nd place
		var best_ai_total = 0.0
		for ai in ai_cars:
			var ai_total = ai.get_total_progress()
			if ai_total > best_ai_total:
				best_ai_total = ai_total
		var gap_dist = player_total - best_ai_total
		var avg_speed = maxf(abs(player.speed), 100.0)
		var gap_secs = gap_dist / avg_speed
		hud_gap.text = "-%.1fs" % gap_secs
		hud_gap.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3, 1))
	else:
		# Show gap to leader
		var leader_total = 0.0
		for ai in ai_cars:
			var ai_total = ai.get_total_progress()
			if ai_total > leader_total:
				leader_total = ai_total
		var gap_dist = leader_total - player_total
		var avg_speed = maxf(abs(player.speed), 100.0)
		var gap_secs = gap_dist / avg_speed
		hud_gap.text = "+%.1fs" % gap_secs
		hud_gap.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2, 1))

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
	# Only apply theme overrides and max_value when state changes — not every frame
	if player.crash_time > 0:
		if _boost_bar_state != "crash":
			boost_bar.max_value = player.STUN_DURATION
			boost_bar.add_theme_stylebox_override("fill", _crash_style)
			_boost_bar_state = "crash"
		boost_bar.value = player.crash_time
	elif player.boost_time > 0:
		if _boost_bar_state != "boost":
			boost_bar.max_value = player.BOOST_DURATION
			boost_bar.add_theme_stylebox_override("fill", _boost_style)
			_boost_bar_state = "boost"
		boost_bar.value = player.boost_time
	else:
		if _boost_bar_state != "none":
			boost_bar.value = 0.0
			_boost_bar_state = "none"

	# Hype bar — drains after cookie collect
	if hype_timer > 0.0:
		hype_timer = max(0.0, hype_timer - delta)
		hype_bar.value = hype_timer
		hype_label.text = "HYPE!" if hype_timer > 1.0 else "..."
	else:
		hype_bar.value = 0.0
		hype_label.text = "..."

	# Camera zoom-out while boost is active
	var boost_active = player.boost_time > 0
	if boost_active and not _boost_was_active:
		if _zoom_tween and _zoom_tween.is_valid():
			_zoom_tween.kill()
		_zoom_tween = create_tween()
		_zoom_tween.tween_property(camera, "zoom", BASE_ZOOM * BOOST_ZOOM_FACTOR, 0.3) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	elif not boost_active and _boost_was_active:
		if _zoom_tween and _zoom_tween.is_valid():
			_zoom_tween.kill()
		_zoom_tween = create_tween()
		_zoom_tween.tween_property(camera, "zoom", BASE_ZOOM, 0.3) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_boost_was_active = boost_active


func _get_player_place() -> int:
	# Once player has finished, lock to their recorded finish position
	if player.has_finished:
		for i in range(GameData.finish_order.size()):
			if GameData.finish_order[i].name == "You":
				return i + 1
		return 1
	var curve_len = track_path.curve.get_baked_length()
	var player_total = float(player.current_lap) * curve_len + player.track_progress
	var ahead = 0
	for ai in ai_cars:
		if ai.has_finished:
			ahead += 1
			continue
		var ai_total = ai.get_total_progress()
		if ai_total > player_total:
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
					cd_beep_sfx.play()
			elif last_digit_shown != 0:
				last_digit_shown = 0
				_show_countdown_digit("GO!", Color(0.2, 1.0, 0.3), 108)
				cd_go_sfx.play()
			# Perfect start detection
			if Input.is_action_just_pressed("ui_up") and not _false_start:
				if countdown_left <= 0.3 and countdown_left > -0.1:
					_perfect_start_pending = true
				elif countdown_left > 0.3:
					_false_start = true
					_show_countdown_digit("TOO EARLY!", Color(1.0, 0.2, 0.2), 72)
			if countdown_left <= -0.6:
				_hide_countdown()
				state = State.RACING
				player.is_racing = true
				for ai in ai_cars:
					ai.is_racing = true
				# Apply perfect start boost or false start stun
				if _perfect_start_pending:
					player.apply_close_call_boost(1.0)
					_show_countdown_digit("PERFECT START!", Color(0.2, 1.0, 0.5), 72)
					var tw = create_tween()
					tw.tween_property(hud_countdown, "scale", Vector2.ZERO, 1.0).set_trans(Tween.TRANS_BACK)
					tw.tween_callback(func(): hud_countdown.text = "")
				elif _false_start:
					player.speed = 0.0
					player.crash_time = 1.0

		State.RACING:
			race_time += delta
			if _close_call_cooldown > 0:
				_close_call_cooldown -= delta
			_update_hud(delta)
			_constrain_to_road()
			_check_player_collisions()  # check before respawn so newly-visible items can't hit same frame
			_check_car_bumps(delta)
			_tick_respawns(delta)
			_check_force_finish(delta)
			_track_race_stats()

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
					_stat_stars += 1
			"shield":
				if dist < 55:
					player.has_shield = true
					_sparkle_at(child.position)
					_hide_pickup(child, cookie_timers, COOKIE_RESPAWN_SEC)
					_stat_stars += 1
			"jeep":
				if dist < 65 and player.crash_time <= 0:
					player.apply_crash()
					_flash_screen()
					crash_sfx.play()
					_hide_pickup(child, jeep_timers, JEEP_RESPAWN_SEC)
					_stat_stuns += 1
				elif dist >= 65 and dist < 90 and player.crash_time <= 0 and _close_call_cooldown <= 0:
					_close_call_cooldown = 2.0
					player.apply_close_call_boost(1.5)
					_sparkle_close_call(child.position)
					_stat_close_calls += 1

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
					if dist < _ai_star_radius:
						ai.apply_boost()
						_sparkle_at(child.position)
						_hide_pickup(child, cookie_timers, COOKIE_RESPAWN_SEC)
						break  # prevent multiple AI collecting same star in one frame


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
			var effective_bump_dist = BUMP_DIST + ai.bump_radius_bonus
			if dist < effective_bump_dist:
				player.apply_bump()
				ai.apply_bump()
				bump_cooldowns[pair_key] = BUMP_COOLDOWN
				_flash_bump(player.position)
				_stat_bumps += 1

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
			var effective_bump_dist_ai = BUMP_DIST + max(ai_cars[i].bump_radius_bonus, ai_cars[j].bump_radius_bonus)
			if dist < effective_bump_dist_ai:
				ai_cars[i].apply_bump()
				ai_cars[j].apply_bump()
				bump_cooldowns[pair_key] = BUMP_COOLDOWN


func _flash_bump(pos: Vector2) -> void:
	if bump_sfx and not bump_sfx.playing:
		bump_sfx.play()
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


# ---------------------------------------------------------------------------
# Bounded local curve search — O(1) replacement for Curve2D.get_closest_offset()
# Uses track_progress (previous frame) as hint; searches ±SEARCH_RADIUS only.
# Falls back to full O(n) search on first frame or when local result is too far.
# ---------------------------------------------------------------------------
const LOCAL_SEARCH_RADIUS: float = 300.0   # px along curve; covers ~36 frames at boost speed
const LOCAL_SEARCH_STEPS: int    = 16      # coarse samples in the window
const LOCAL_REFINE_STEPS: int    = 8       # bisection refinement passes
const LOCAL_FALLBACK_DIST: float = 250.0   # if closest pt > this, redo full search

func _local_closest_offset(curve: Curve2D, pos: Vector2, hint: float) -> float:
	var curve_len := curve.get_baked_length()
	if curve_len <= 0.0:
		return 0.0

	# First frame — no valid hint yet, use full (O(n)) search once
	if hint <= 0.0 and player.track_progress <= 0.0:
		return curve.get_closest_offset(pos)

	# Coarse pass: sample LOCAL_SEARCH_STEPS points in [hint - R, hint + R]
	var lo := hint - LOCAL_SEARCH_RADIUS
	var hi := hint + LOCAL_SEARCH_RADIUS
	var step := (hi - lo) / float(LOCAL_SEARCH_STEPS)
	var best_off := hint
	var best_dsq := INF

	for i in range(LOCAL_SEARCH_STEPS + 1):
		var off := lo + step * float(i)
		# Wrap into [0, curve_len) for looped tracks
		if off < 0.0:
			off += curve_len
		elif off >= curve_len:
			off -= curve_len
		var pt := curve.sample_baked(off)
		var dsq := (pt.x - pos.x) * (pt.x - pos.x) + (pt.y - pos.y) * (pt.y - pos.y)
		if dsq < best_dsq:
			best_dsq = dsq
			best_off = off

	# Refine: binary-search between the two neighbors of the best sample
	var refine_lo := best_off - step
	var refine_hi := best_off + step
	for _r in range(LOCAL_REFINE_STEPS):
		var mid_a := refine_lo + (refine_hi - refine_lo) * 0.333
		var mid_b := refine_lo + (refine_hi - refine_lo) * 0.667
		# Wrap into valid range using fposmod (handles negative values at track seam)
		var off_a := fposmod(mid_a, curve_len)
		var off_b := fposmod(mid_b, curve_len)
		var pt_a := curve.sample_baked(off_a)
		var pt_b := curve.sample_baked(off_b)
		var dsq_a := (pt_a.x - pos.x) * (pt_a.x - pos.x) + (pt_a.y - pos.y) * (pt_a.y - pos.y)
		var dsq_b := (pt_b.x - pos.x) * (pt_b.x - pos.x) + (pt_b.y - pos.y) * (pt_b.y - pos.y)
		if dsq_a < dsq_b:
			refine_hi = mid_b
			if dsq_a < best_dsq:
				best_dsq = dsq_a
				best_off = off_a
		else:
			refine_lo = mid_a
			if dsq_b < best_dsq:
				best_dsq = dsq_b
				best_off = off_b

	# Safety fallback: if the local search found something too far, do a full search
	if best_dsq > LOCAL_FALLBACK_DIST * LOCAL_FALLBACK_DIST:
		return curve.get_closest_offset(pos)

	return best_off


func _constrain_to_road() -> void:
	var curve          = track_path.curve
	var closest_offset = _local_closest_offset(curve, player.position, player.track_progress)
	var closest_pt     = curve.sample_baked(closest_offset)
	var dist           = player.position.distance_to(closest_pt)
	# Sync player.track_progress to curve offset so it's on the same scale as AI.progress
	player.track_progress = closest_offset
	if dist > ROAD_WIDTH * 0.55:
		# Hard boundary — snap back (further out than before)
		player.position = closest_pt + (player.position - closest_pt).normalized() * ROAD_WIDTH * 0.55
	elif dist > ROAD_WIDTH * 0.45:
		# Off-road grass penalty — cap speed instead of multiplying (prevents exponential decay)
		player.speed = min(player.speed, player.MAX_SPEED * 0.45)


func _flash_screen() -> void:
	if crash_sfx and not crash_sfx.playing:
		crash_sfx.play()
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
	# Collect unfinished cars with lap-aware total progress, sort descending
	var curve_len = track_path.curve.get_baked_length()
	var unfinished: Array = []
	for ai in ai_cars:
		if not ai.has_finished:
			unfinished.append({node = ai, name = ai.car_label, prog = ai.get_total_progress()})
	if not player.has_finished:
		var player_total = float(player.current_lap) * curve_len + player.track_progress
		unfinished.append({node = player, name = "You", prog = player_total})

	unfinished.sort_custom(func(a, b): return a.prog > b.prog)

	for entry in unfinished:
		entry.node.has_finished = true
		entry.node.speed = 0.0
		_record_finish(entry.name)

	_save_race_data()
	_trigger_scene_change()


# ---------------------------------------------------------------------------
# Race stats tracking
# ---------------------------------------------------------------------------
func _track_race_stats() -> void:
	_stat_total_frames += 1
	if player.boost_time > 0:
		_stat_boost_frames += 1

	# Track lead changes — who is in 1st place right now? (lap-aware)
	var curve_len = track_path.curve.get_baked_length()
	var leader = "You"
	var best_prog = float(player.current_lap) * curve_len + player.track_progress
	for ai in ai_cars:
		var ai_prog = INF if ai.has_finished else ai.get_total_progress()
		if ai_prog > best_prog:
			best_prog = ai_prog
			leader = ai.car_label
	if _stat_last_leader != "" and leader != _stat_last_leader:
		_stat_lead_changes += 1
	_stat_last_leader = leader


func _save_race_data() -> void:
	# Track points for minimap snapshot on results screen
	GameData.track_points.clear()
	for p in TRACK_POINTS:
		GameData.track_points.append(p)

	# Final positions of all cars
	GameData.final_positions["You"] = player.position
	for ai in ai_cars:
		GameData.final_positions[ai.car_label] = ai.global_position

	# Race stats
	var boost_pct = 0.0
	if _stat_total_frames > 0:
		boost_pct = float(_stat_boost_frames) / float(_stat_total_frames) * 100.0
	GameData.race_stats = {
		stars = _stat_stars,
		stuns = _stat_stuns,
		bumps = _stat_bumps,
		boost_pct = boost_pct,
		lead_changes = _stat_lead_changes,
		close_calls = _stat_close_calls,
	}


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
		_save_race_data()
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
		var suf      = suffixes[clamp(place, 1, 5)]
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
	# Update intro card text
	if GameData.circuit_mode:
		var track_name = GameData.TRACKS[GameData.current_track_index].name
		var race_num = GameData.circuit_race + 1
		intro_card.text = "RACE %d/5 — %s — %d LAPS" % [race_num, track_name, GameData.TOTAL_LAPS]
	else:
		intro_card.text = "%s — %d LAPS" % [GameData.TRACKS[GameData.current_track_index].name, GameData.TOTAL_LAPS]
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
	GameData.clear_circuit()
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
# Star sparkle on cookie collect – particle burst + floating label
# ---------------------------------------------------------------------------
const CollectBurst = preload("res://collect_burst.gd")

func _sparkle_at(pos: Vector2) -> void:
	# Particle burst effect
	var burst = CollectBurst.new()
	burst.position = pos
	burst.z_index  = 20
	add_child(burst)

	# Floating "BOOST!" label
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


func _sparkle_close_call(pos: Vector2) -> void:
	var lbl = Label.new()
	lbl.text = "CLOSE CALL!"
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color", Color(0.3, 0.95, 1.0, 1))
	lbl.position = pos + Vector2(-70, -30)
	lbl.z_index  = 20
	add_child(lbl)
	var tw = create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 55, 0.7)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.7)
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
