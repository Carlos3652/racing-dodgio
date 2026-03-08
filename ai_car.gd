extends PathFollow2D

# --- Option A: Bumped base speeds to compete with player (MAX 350) ---
const BASE_SPEED    = 300.0
const MAX_SPEED     = 340.0
const MIN_SPEED     = 120.0

# --- Option D: AI can collect star boosts ---
const BOOST_SPEED   = 480.0
const BOOST_DURATION = 5.0

# --- Option E: Progressive speedup every 10s ---
const SPEEDUP_INTERVAL = 10.0
const SPEEDUP_AMOUNT   = 15.0
const SPEEDUP_CAP      = 380.0

var speed: float = BASE_SPEED
var is_racing: bool = false
var has_finished: bool = false
var car_label: String = "AI"
var car_color: Color = Color.CYAN
var lane_offset: float = 0.0  # perpendicular offset from path center (pixels)

# Collision penalty
var bump_time: float = 0.0
const BUMP_SLOW_DURATION = 1.5
const BUMP_SPEED_MULT = 0.4

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
	loop = false
	rotates = true
	# Randomize starting noise so cars don't all move identically
	noise_speed = randf_range(-40.0, 20.0)
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
		noise_speed = randf_range(-50.0, 30.0)

	# --- Option D: boost handling ---
	if boost_time > 0:
		boost_time -= delta
		speed = BOOST_SPEED
	else:
		var current_base = BASE_SPEED + speed_bonus
		var current_max = min(MAX_SPEED + speed_bonus, SPEEDUP_CAP)
		speed = clamp(current_base + noise_speed, MIN_SPEED, current_max)

	# Apply bump slowdown
	if bump_time > 0:
		speed *= BUMP_SPEED_MULT

	progress += speed * delta

	# Apply lane offset perpendicular to path direction
	if lane_offset != 0.0 and get_parent() is Path2D:
		var curve = (get_parent() as Path2D).curve
		var offs = curve.get_closest_offset(position)
		var tangent = (curve.sample_baked(min(offs + 5.0, curve.get_baked_length())) - curve.sample_baked(offs)).normalized()
		var perp = Vector2(-tangent.y, tangent.x)
		# PathFollow2D resets position each frame, so we offset via transform
		position += perp * lane_offset

	if progress_ratio >= 0.99:
		_cross_finish()


# --- Option D: called by race_manager when AI hits a star ---
func apply_boost() -> void:
	boost_time = BOOST_DURATION


func apply_bump() -> void:
	if bump_time <= 0:
		bump_time = BUMP_SLOW_DURATION


func _cross_finish() -> void:
	if has_finished:
		return
	has_finished = true
	speed = 0.0
	finished.emit(car_label)
