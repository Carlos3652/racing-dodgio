extends PathFollow2D

# "8 mph equivalent" — 220 px/s base, capped at 265 px/s
const BASE_SPEED    = 220.0
const MAX_SPEED     = 265.0
const MIN_SPEED     = 80.0

var speed: float = BASE_SPEED
var is_racing: bool = false
var has_finished: bool = false
var car_label: String = "AI"
var car_color: Color = Color.CYAN

# "Mind of their own" fields
var noise_speed: float = 0.0
var noise_timer: float = 0.0
var noise_interval: float = 2.0

signal finished(car_name: String)


const _CAR_TEX = preload("res://Red Car.png")

func _ready() -> void:
	loop = false
	rotates = true
	# Randomize starting noise so cars don't all move identically
	noise_speed = randf_range(-40.0, 20.0)
	noise_interval = randf_range(1.5, 4.0)

	# Build the car sprite as a child
	var sprite = Sprite2D.new()
	sprite.texture = _CAR_TEX
	sprite.scale = Vector2(0.25, 0.25)
	sprite.modulate = car_color
	add_child(sprite)


func _process(delta: float) -> void:
	if not is_racing or has_finished:
		return

	# Update random behavior
	noise_timer += delta
	if noise_timer >= noise_interval:
		noise_timer = 0.0
		noise_interval = randf_range(1.0, 4.5)
		# Bias toward slowing down occasionally for variety
		noise_speed = randf_range(-60.0, 25.0)

	speed = clamp(BASE_SPEED + noise_speed, MIN_SPEED, MAX_SPEED)
	progress += speed * delta

	if progress_ratio >= 0.99:
		_cross_finish()


func _cross_finish() -> void:
	if has_finished:
		return
	has_finished = true
	speed = 0.0
	finished.emit(car_label)
