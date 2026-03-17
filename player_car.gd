extends Sprite2D

var MAX_SPEED: float     = 350.0
const BOOST_SPEED = 500.0
const ACCEL       = 600.0
const BRAKE       = 900.0
const COAST       = 300.0
var TURN_SPEED: float = 2.8
const BUMP_SLOW_DURATION = 1.5
const BUMP_SPEED_MULT = 0.4
var STUN_DURATION: float = 2.0
var BOOST_DURATION: float = 5.0

var speed: float = 0.0
@onready var engine_audio: AudioStreamPlayer = $EngineAudio
var boost_time: float = 0.0
var crash_time: float = 0.0
var bump_time: float = 0.0
var has_finished: bool = false
var is_racing: bool = false
var track_progress: float = 0.0  # curve offset — used for place calc

# Drift boost
var is_drifting: bool = false
var drift_time: float = 0.0
const DRIFT_BOOST_THRESHOLD = 1.5
const DRIFT_BOOST_MULT = 1.25
const DRIFT_BOOST_DURATION = 1.5
var _prev_rotation: float = 0.0

# Lap tracking
var current_lap: int = 0
var total_laps: int = 3
var finish_line_a: Vector2 = Vector2.ZERO
var finish_line_b: Vector2 = Vector2.ZERO
var finish_line_dir: Vector2 = Vector2.ZERO
var min_progress_for_lap: float = 0.0
var _progress_since_last_lap: float = 0.0
var _prev_pos: Vector2 = Vector2.ZERO
var _lap_cooldown: float = 1.0  # start at 1.0 to prevent false trigger at spawn

signal finished(car_name: String)


func _ready() -> void:
	texture = null  # visual handled by car_visual child added by race_manager
	MAX_SPEED      = GameData.player_max_speed
	STUN_DURATION  = GameData.player_stun_duration
	BOOST_DURATION = GameData.player_boost_duration
	TURN_SPEED     = GameData.player_turn_speed
	# Engine audio loops continuously — restart when stream finishes
	if engine_audio:
		engine_audio.finished.connect(_on_engine_audio_finished)
		engine_audio.pitch_scale = 0.6


func _process(delta: float) -> void:
	if not is_racing or has_finished:
		if engine_audio and not is_racing:
			engine_audio.pitch_scale = 0.6
		return

	if bump_time > 0:
		bump_time -= delta
	if crash_time > 0:
		crash_time -= delta
		# Keep engine at idle pitch while stunned
		if engine_audio:
			engine_audio.pitch_scale = 0.6
		return

	if Input.is_action_pressed("ui_left"):
		rotation -= TURN_SPEED * delta
	if Input.is_action_pressed("ui_right"):
		rotation += TURN_SPEED * delta

	# Drift boost accumulation
	var rotation_delta = rotation - _prev_rotation
	_prev_rotation = rotation
	var drift_held = Input.is_action_pressed("drift")
	if drift_held and abs(rotation_delta) > 0.04:
		is_drifting = true
		drift_time += delta
	elif drift_held and is_drifting:
		# Still holding drift but not turning hard — keep accumulating at half rate
		drift_time += delta * 0.5
	else:
		# Released drift or never held
		if is_drifting and drift_time >= DRIFT_BOOST_THRESHOLD:
			apply_close_call_boost(DRIFT_BOOST_DURATION)
		is_drifting = false
		drift_time = 0.0

	var top = BOOST_SPEED if boost_time > 0 else MAX_SPEED
	if boost_time > 0:
		boost_time -= delta
		speed = min(speed + ACCEL * delta, top)
	elif Input.is_action_pressed("ui_up"):
		speed = min(speed + ACCEL * delta, top)
	elif Input.is_action_pressed("ui_down"):
		speed = max(speed - BRAKE * delta, -MAX_SPEED * 0.4)
	else:
		speed = move_toward(speed, 0.0, COAST * delta)

	var effective_speed = speed * (BUMP_SPEED_MULT if bump_time > 0 else 1.0)
	position += Vector2.UP.rotated(rotation) * effective_speed * delta

	# Engine pitch follows speed
	if engine_audio:
		engine_audio.pitch_scale = lerp(0.6, 1.6, clampf(abs(speed) / MAX_SPEED, 0.0, 1.0))

	# Lap detection
	if _lap_cooldown > 0:
		_lap_cooldown -= delta
	var moved = position.distance_to(_prev_pos) if _prev_pos != Vector2.ZERO else 0.0
	_progress_since_last_lap += moved
	if finish_line_a != Vector2.ZERO and _lap_cooldown <= 0:
		if _segments_intersect(_prev_pos, position, finish_line_a, finish_line_b):
			var cross_dir = (position - _prev_pos).normalized()
			if cross_dir.dot(finish_line_dir) > 0 and _progress_since_last_lap >= min_progress_for_lap:
				current_lap += 1
				_progress_since_last_lap = 0.0
				_lap_cooldown = 2.0
				if current_lap >= total_laps:
					_cross_finish()
	_prev_pos = position


func apply_boost() -> void:
	boost_time = BOOST_DURATION


func apply_close_call_boost(duration: float) -> void:
	boost_time = max(boost_time, duration)


func apply_bump() -> void:
	if bump_time <= 0 and crash_time <= 0:
		bump_time = BUMP_SLOW_DURATION


func apply_crash() -> void:
	if crash_time > 0:
		return
	speed = 0.0
	boost_time = 0.0
	crash_time = STUN_DURATION


func get_speed_kmh() -> int:
	# 0.3 multiplier → 105 km/h at MAX_SPEED, 150 at boost — feels like a real race
	return int(abs(speed) * 0.3)


static func _segments_intersect(p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2) -> bool:
	var d1 = p2 - p1
	var d2 = p4 - p3
	var denom = d1.x * d2.y - d1.y * d2.x
	if abs(denom) < 0.001:
		return false
	var t = ((p3.x - p1.x) * d2.y - (p3.y - p1.y) * d2.x) / denom
	var u = ((p3.x - p1.x) * d1.y - (p3.y - p1.y) * d1.x) / denom
	return t >= 0.0 and t <= 1.0 and u >= 0.0 and u <= 1.0


func _on_engine_audio_finished() -> void:
	if engine_audio and not has_finished:
		engine_audio.play()


func _cross_finish() -> void:
	if has_finished:
		return
	has_finished = true
	speed = 0.0
	if engine_audio:
		engine_audio.stop()
	finished.emit("You")
