extends Sprite2D

var current_speed = 0.0
var boost_time = 0.0
var crash_time = 0.0

@onready var griddy_anim = $"../GriddyKid/AnimationPlayer"

func _ready():
	griddy_anim.animation_finished.connect(_on_griddy_finished)

func _process(delta: float) -> void:
	if crash_time > 0:
		crash_time -= delta
		return

	if Input.is_action_pressed("ui_left"):  rotation -= delta * 4
	if Input.is_action_pressed("ui_right"): rotation += delta * 4

	if boost_time > 0:
		boost_time -= delta
	else:
		if Input.is_action_pressed("ui_up"):
			current_speed = min(current_speed + delta * 20, 10)
		elif Input.is_action_pressed("ui_down"):
			current_speed = max(current_speed - delta * 30, -5)
		else:
			current_speed = max(current_speed - delta * 10, 0)

	position += Vector2.UP.rotated(rotation) * current_speed * delta * 60

	# Cookies
	for c in [$"../Cookie1", $"../Cookie2"]:
		if is_instance_valid(c) and position.distance_to(c.position) < 40:
			c.queue_free()
			boost_time = 5.0
			griddy_anim.play("griddy")

	# Jeeps
	for j in [$"../Jeep1", $"../Jeep2"]:
		if is_instance_valid(j) and position.distance_to(j.position) < 45:
			current_speed = 0
			crash_time = 2.0
			j.position.x += 8
			await get_tree().create_timer(0.1).timeout
			j.position.x -= 16
			await get_tree().create_timer(0.1).timeout
			j.position.x += 8
			await get_tree().create_timer(1.7).timeout
			j.queue_free()
			break

func _on_griddy_finished(anim_name: String):
	if anim_name == "griddy":
		var gk = $"../GriddyKid"
		if "frame" in gk:
			gk.set("frame", 0)
