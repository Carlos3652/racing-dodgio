extends Node2D
## Particle burst effect spawned when a star/cookie is collected.
## Draws 12-16 small particles that launch radially outward in gold, white,
## and cyan, fading out over 0.5 s before auto-freeing.

const COLORS: Array[Color] = [
	Color("#FFD740"),          # gold
	Color(1.0, 1.0, 1.0, 1),  # white
	Color("#00E5FF"),          # cyan
]

var _particles: Array[Dictionary] = []
var _elapsed: float = 0.0
const LIFETIME: float = 0.5


func _ready() -> void:
	z_index = 25
	var count = randi_range(12, 16)
	for i in count:
		var angle = TAU * float(i) / float(count) + randf_range(-0.15, 0.15)
		var speed = randf_range(120.0, 220.0)
		var size  = randf_range(3.0, 5.0)
		var color = COLORS[i % COLORS.size()]
		var use_rect = randi() % 3 == 0  # ~33% chance of rect
		_particles.append({
			"pos": Vector2.ZERO,
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"size": size,
			"color": color,
			"rect": use_rect,
		})

	# Tween modulate alpha to 0 over lifetime, then free
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, LIFETIME)
	tw.tween_callback(queue_free)


func _process(delta: float) -> void:
	_elapsed += delta
	# Decelerate particles
	var drag = 1.0 - 3.0 * delta  # friction
	if drag < 0.0:
		drag = 0.0
	for p in _particles:
		p["pos"] += p["vel"] * delta
		p["vel"] *= drag
	queue_redraw()


func _draw() -> void:
	for p in _particles:
		var c: Color = p["color"]
		c.a = modulate.a  # respect tween fade
		var s: float = p["size"]
		var pos: Vector2 = p["pos"]
		if p["rect"]:
			draw_rect(Rect2(pos - Vector2(s, s) * 0.5, Vector2(s, s)), c)
		else:
			draw_circle(pos, s, c)
