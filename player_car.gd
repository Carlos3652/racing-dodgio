extends Sprite2D

var MAX_SPEED: float     = 350.0
const BOOST_SPEED = 500.0
const ACCEL       = 600.0
const BRAKE       = 900.0
const COAST       = 300.0
const TURN_SPEED  = 2.8
const FINISH_DIST = 220.0  # must be > ROAD_WIDTH * 0.55 (currently 209px)
const BUMP_SLOW_DURATION = 1.5
const BUMP_SPEED_MULT = 0.4
var STUN_DURATION: float = 2.0
var BOOST_DURATION: float = 5.0

var speed: float = 0.0
var boost_time: float = 0.0
var crash_time: float = 0.0
var bump_time: float = 0.0
var has_finished: bool = false
var is_racing: bool = false
var finish_position: Vector2 = Vector2.ZERO
var track_progress: float = 0.0  # cumulative forward distance — used for place calc

signal finished(car_name: String)


func _ready() -> void:
	texture = null  # visual handled by car_visual child added by race_manager
	MAX_SPEED      = GameData.player_max_speed
	STUN_DURATION  = GameData.player_stun_duration
	BOOST_DURATION = GameData.player_boost_duration


func _process(delta: float) -> void:
	if not is_racing or has_finished:
		return

	if bump_time > 0:
		bump_time -= delta
	if crash_time > 0:
		crash_time -= delta
		return

	if Input.is_action_pressed("ui_left"):
		rotation -= TURN_SPEED * delta
	if Input.is_action_pressed("ui_right"):
		rotation += TURN_SPEED * delta

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
	if speed > 0:
		track_progress += speed * delta

	if finish_position != Vector2.ZERO and track_progress >= 500.0 and position.distance_to(finish_position) < FINISH_DIST:
		_cross_finish()


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
	crash_time = STUN_DURATION


func get_speed_kmh() -> int:
	# 0.3 multiplier → 105 km/h at MAX_SPEED, 150 at boost — feels like a real race
	return int(abs(speed) * 0.3)


func _cross_finish() -> void:
	if has_finished:
		return
	has_finished = true
	speed = 0.0
	finished.emit("You")
