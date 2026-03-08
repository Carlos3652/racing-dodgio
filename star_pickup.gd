extends Node2D

# Visual constants
const OUTER_R    = 13.0
const INNER_R    =  6.0
const GLOW_R1    = 22.0
const GLOW_R2    = 16.0
const STAR_COLOR = Color(1.000, 0.871, 0.000, 1)
const GLOW_COL1  = Color(1.000, 0.700, 0.000, 1)
const GLOW_COL2  = Color(1.000, 0.850, 0.000, 1)

var _base_y:     float = 0.0
var _bob_t:      float = 0.0
var _glow_alpha: float = 0.30
var _star_pts:   PackedVector2Array
var _teal_pts:   PackedVector2Array


func _ready() -> void:
	_base_y = position.y
	# Pre-compute the 10-point star polygon (5 outer, 5 inner, alternating)
	_star_pts = PackedVector2Array()
	for i in range(10):
		var angle = deg_to_rad(i * 36.0 - 90.0)
		var r     = OUTER_R if i % 2 == 0 else INNER_R
		_star_pts.append(Vector2(cos(angle) * r, sin(angle) * r))
	# Pre-compute teal glow circle (16-sided polygon, radius 28)
	_teal_pts = PackedVector2Array()
	for i in range(16):
		var a = i * TAU / 16.0
		_teal_pts.append(Vector2(cos(a), sin(a)) * 28.0)


func _process(delta: float) -> void:
	_bob_t      += delta
	position.y   = _base_y + sin(_bob_t * 2.5) * 3.5
	_glow_alpha  = 0.25 + 0.20 * sin(_bob_t * 3.5)
	queue_redraw()


func _draw() -> void:
	# Teal ground glow — filled circle behind everything for pickup visibility
	var teal_alpha = 0.30 + 0.12 * sin(_bob_t * 3.0)
	draw_colored_polygon(_teal_pts, Color(0.10, 0.85, 0.80, teal_alpha))

	# Outer glow rings (drawn first so they appear behind the star)
	draw_arc(Vector2.ZERO, GLOW_R1, 0.0, TAU, 24,
			 Color(GLOW_COL1.r, GLOW_COL1.g, GLOW_COL1.b, _glow_alpha), true)
	draw_arc(Vector2.ZERO, GLOW_R2, 0.0, TAU, 24,
			 Color(GLOW_COL2.r, GLOW_COL2.g, GLOW_COL2.b, _glow_alpha * 0.6), true)

	# Five-pointed star
	draw_colored_polygon(_star_pts, STAR_COLOR)

	# Small white highlight — gives the star a shiny top-left facet
	draw_colored_polygon(PackedVector2Array([
		Vector2(-3.0, -11.0),
		Vector2(-6.0,  -5.0),
		Vector2( 0.0,  -6.0),
	]), Color(1.0, 1.0, 1.0, 0.50))
