extends Node2D

# Colors
const COL_BODY      = Color(0.250, 0.298, 0.149, 1)   # olive green
const COL_CAB       = Color(0.200, 0.239, 0.118, 1)   # darker cab
const COL_BUMPER    = Color(0.141, 0.169, 0.086, 1)   # front slab
const COL_WINDSHLD  = Color(0.102, 0.161, 0.200, 0.90)
const COL_CHEVRON   = Color(0.950, 0.600, 0.000, 1)   # orange warning
const COL_HEADLIGHT = Color(0.900, 0.698, 0.102, 0.85)# amber
const COL_TAILLIGHT = Color(0.850, 0.102, 0.102, 1)   # red

var _pulse_t: float = 0.0


func _process(delta: float) -> void:
	_pulse_t += delta
	queue_redraw()


func _draw() -> void:
	var pulse = 0.25 + 0.22 * sin(_pulse_t * 4.0)

	# 1. Danger halo — pulsing red ring (drawn first so it's behind everything)
	draw_arc(Vector2.ZERO, 28.0, 0.0, TAU, 24, Color(1.0, 0.1, 0.1, pulse), true)

	# 2. Drop shadow
	draw_arc(Vector2(1, 5), 22.0, 0.0, TAU, 16, Color(0.0, 0.0, 0.0, 0.38), true)

	# 3. Main body (olive, boxy)
	draw_rect(Rect2(-18, -22, 36, 40), COL_BODY)

	# 4. Raised cab section
	draw_rect(Rect2(-14, -28, 28, 22), COL_CAB)

	# 5. Front bumper slab
	draw_rect(Rect2(-18, -28, 36,  6), COL_BUMPER)

	# 6. Windshield (small, mean)
	draw_rect(Rect2(-10, -24, 20, 10), COL_WINDSHLD)

	# 7. Orange warning chevrons on front corners
	draw_colored_polygon(PackedVector2Array([
		Vector2(-18, -28), Vector2(-10, -28),
		Vector2(-14, -22), Vector2(-18, -22),
	]), COL_CHEVRON)
	draw_colored_polygon(PackedVector2Array([
		Vector2( 10, -28), Vector2( 18, -28),
		Vector2( 18, -22), Vector2( 14, -22),
	]), COL_CHEVRON)

	# 8. Amber headlights
	draw_rect(Rect2(-17, -30,  6, 3), COL_HEADLIGHT)
	draw_rect(Rect2( 11, -30,  6, 3), COL_HEADLIGHT)

	# 9. Red taillights
	draw_rect(Rect2(-17,  16,  6, 3), COL_TAILLIGHT)
	draw_rect(Rect2( 11,  16,  6, 3), COL_TAILLIGHT)
