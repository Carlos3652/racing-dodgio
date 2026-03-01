extends Sprite2D

const MAX_SPEED   = 350.0
const BOOST_SPEED = 500.0
const ACCEL       = 600.0
const BRAKE       = 900.0
const COAST       = 300.0
const TURN_SPEED  = 2.8
const FINISH_DIST = 120.0

var speed: float = 0.0
var boost_time: float = 0.0
var crash_time: float = 0.0
var has_finished: bool = false
var is_racing: bool = false
var finish_position: Vector2 = Vector2.ZERO
var track_progress: float = 0.0  # cumulative forward distance — used for place calc

signal finished(car_name: String)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		GameData.clear()
		get_tree().change_scene_to_file("res://main_menu.tscn")
		return

	if not is_racing or has_finished:
		return

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

	position += Vector2.UP.rotated(rotation) * speed * delta
	if speed > 0:
		track_progress += speed * delta

	if finish_position != Vector2.ZERO and position.distance_to(finish_position) < FINISH_DIST:
		_cross_finish()


func apply_boost() -> void:
	boost_time = 5.0


func apply_crash() -> void:
	if crash_time > 0:
		return
	speed = 0.0
	crash_time = 2.0


func get_speed_kmh() -> int:
	# 0.3 multiplier → 105 km/h at MAX_SPEED, 150 at boost — feels like a real race
	return int(abs(speed) * 0.3)


func _cross_finish() -> void:
	if has_finished:
		return
	has_finished = true
	speed = 0.0
	finished.emit("You")
