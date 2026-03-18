extends PathFollow2D

# --- Difficulty-adjusted speeds (set in _ready from GameData.difficulty) ---
var BASE_SPEED: float    = 300.0
var MAX_SPEED: float     = 340.0
var MIN_SPEED: float     = 120.0
var noise_bias: float    = 0.0

# --- Option D: AI can collect star boosts ---
const BOOST_SPEED   = 480.0
const BOOST_DURATION = 5.0

# --- Option E: Progressive speedup every 10s ---
const SPEEDUP_INTERVAL = 10.0
const SPEEDUP_AMOUNT   = 15.0
var SPEEDUP_CAP: float  = 380.0

# --- Rubber-band catch-up / pullback ---
@export var CATCHUP_BONUS: float = 25.0
@export var PULLBACK_PENALTY: float = 15.0
var player_ref: Node2D = null

var speed: float = BASE_SPEED
var is_racing: bool = false
var has_finished: bool = false
var car_label: String = "AI"
var car_color: Color = Color.CYAN
var lane_offset: float = 0.0  # perpendicular offset from path center (pixels)

# Lap tracking
var current_lap: int = 0
var total_laps: int = 3
var _prev_progress_ratio: float = 0.0

# Collision penalty
var bump_time: float = 0.0
var BUMP_SLOW_DURATION: float = 1.5
const BUMP_SPEED_MULT = 0.4

# Personality — set by race_manager at spawn time
var personality: Dictionary = {}
var bump_radius_bonus: float = 0.0  # added to base bump_dist for "blocker" types
var ai_boost_duration: float = 5.0  # can be shortened for "phantom"

# Rubber-band catch-up / pullback
@export var CATCHUP_BONUS: float = 25.0
@export var PULLBACK_PENALTY: float = 15.0
var player_ref: Node2D = null

# "Mind of their own" fields
var noise_speed: float = 0.0
var noise_timer: float = 0.0
var noise_interval: float = 2.0

# Option D: boost state
var boost_time: float = 0.0

# Option E: progressive speedup state
var race_timer: float = 0.0
var speed_bonus: float = 0.0

signal finished(car_name: String)


const _VisScene = preload("res://car_visual.gd")

func _ready() -> void:
	loop = true
	rotates = true

	# Apply difficulty settings
	match GameData.difficulty:
		"easy":
			BASE_SPEED = 240.0
			MAX_SPEED  = 280.0
			noise_bias = -20.0
			SPEEDUP_CAP = 300.0
		"hard":
			BASE_SPEED = 320.0
			MAX_SPEED  = 360.0
			noise_bias = 10.0
			SPEEDUP_CAP = 400.0
		_:  # normal
			BASE_SPEED = 300.0
			MAX_SPEED  = 340.0
			noise_bias = 0.0
			SPEEDUP_CAP = 380.0

	# Apply personality overrides (set by race_manager before _ready)
	if personality.has("base_speed_bonus"):
		BASE_SPEED += personality.base_speed_bonus
	if personality.has("noise_variance"):
		noise_bias += personality.noise_variance
	if personality.has("bump_slow_duration"):
		BUMP_SLOW_DURATION = personality.bump_slow_duration
	if personality.has("bump_radius_bonus"):
		bump_radius_bonus = personality.bump_radius_bonus
	if personality.has("boost_duration"):
		ai_boost_duration = personality.boost_duration

	# Sync speed to post-difficulty BASE_SPEED (declared default is stale)
	speed = BASE_SPEED

	# Randomize starting noise so cars don't all move identically
	noise_speed = randf_range(-40.0, 20.0) + noise_bias
	noise_interval = randf_range(1.5, 4.0)

	# Build the procedural car visual as a child
	# Car shapes are drawn pointing UP (-Y), but PathFollow2D rotates along +X,
	# so offset by -90 degrees to align car nose with travel direction
	var vis = _VisScene.new()
	vis.car_type  = car_label.to_lower()  # "Blue" -> "blue" etc.
	vis.car_color = car_color
	vis.rotation  = -PI / 2.0
	add_child(vis)


func _process(delta: float) -> void:
	if not is_racing or has_finished:
		return

	# --- Bump penalty countdown ---
	if bump_time > 0:
		bump_time -= delta

	# --- Option E: progressive speedup ---
	race_timer += delta
	speed_bonus = min(floor(race_timer / SPEEDUP_INTERVAL) * SPEEDUP_AMOUNT, SPEEDUP_CAP - BASE_SPEED)

	# Update random behavior
	noise_timer += delta
	if noise_timer >= noise_interval:
		noise_timer = 0.0
		noise_interval = randf_range(1.0, 4.5)
		noise_speed = randf_range(-50.0, 30.0) + noise_bias

	# --- Option D: boost handling ---
	if boost_time > 0:
		boost_time -= delta
		speed = BOOST_SPEED
	else:
		var current_base = BASE_SPEED + speed_bonus

		# Rubber-band catch-up / pullback
		if player_ref != null and is_instance_valid(player_ref) and not player_ref.has_finished:
			var curve_len := 0.0
			if get_parent() is Path2D:
				curve_len = (get_parent() as Path2D).curve.get_baked_length()
			if curve_len > 0.0:
				var total_track := curve_len * float(total_laps)
				var threshold := total_track * 0.1
				var player_total := float(player_ref.current_lap) * curve_len + player_ref.track_progress
				var ai_total := get_total_progress()
				var gap := player_total - ai_total
				if gap > threshold:
					current_base += CATCHUP_BONUS
				elif gap < -threshold:
					current_base -= PULLBACK_PENALTY

		var current_max = min(MAX_SPEED + speed_bonus, SPEEDUP_CAP)
		speed = clamp(current_base + noise_speed, MIN_SPEED, current_max)

	# Apply bump slowdown
	if bump_time > 0:
		speed *= BUMP_SPEED_MULT

	progress += speed * delta

	# Apply lane offset perpendicular to path direction (loop-safe with fmod)
	# FIX: set absolute position instead of accumulating with +=
	if lane_offset != 0.0 and get_parent() is Path2D:
		var curve = (get_parent() as Path2D).curve
		var curve_len = curve.get_baked_length()
		var sample_pos = fmod(progress, curve_len)
		var sample_ahead = fmod(progress + 5.0, curve_len)
		var base_pos = curve.sample_baked(sample_pos)
		var tangent = (curve.sample_baked(sample_ahead) - base_pos).normalized()
		var perp = Vector2(-tangent.y, tangent.x)
		position = base_pos + perp * lane_offset

	# Detect lap completion: ratio wraps from >0.8 to <0.2
	if _prev_progress_ratio > 0.8 and progress_ratio < 0.2:
		current_lap += 1
		if current_lap >= total_laps:
			_cross_finish()
	_prev_progress_ratio = progress_ratio


# --- Option D: called by race_manager when AI hits a star ---
func apply_boost() -> void:
	boost_time = ai_boost_duration


func apply_bump() -> void:
	if bump_time <= 0:
		bump_time = BUMP_SLOW_DURATION


func get_total_progress() -> float:
	var curve_len = 0.0
	if get_parent() is Path2D:
		curve_len = (get_parent() as Path2D).curve.get_baked_length()
	return float(current_lap) * curve_len + fmod(progress, max(curve_len, 1.0))


func _cross_finish() -> void:
	if has_finished:
		return
	has_finished = true
	speed = 0.0
	finished.emit(car_label)
