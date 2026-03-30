extends Node2D

# Set these before add_child():
#   car_type  — "player" | "blue" | "green" | "orange" | "purple"
#   car_color — main body Color
var car_type:  String = "player"
var car_color: Color  = Color(1.0, 0.133, 0.133, 1)

const _WINDSHIELD = Color(0.15, 0.20, 0.35, 0.88)
const _FONT_SIZE  = 14


var is_player_car: bool = false

func _process(_delta: float) -> void:
	if is_player_car:
		# Redraw every frame so boost glow reacts to boost_time changes
		queue_redraw()


func _draw() -> void:
	# Boost speed trail ghosts — drawn BEFORE car body so the car renders on top
	if is_player_car:
		var parent = get_parent()
		if parent and "boost_time" in parent and parent.boost_time > 0:
			# Speed trail: 3 ghost copies behind the car along negative velocity
			# In local space, the car faces -Y so "behind" is +Y
			# Draw farthest ghost first so closer (brighter) ghosts layer on top
			var ghost_offsets := [60.0, 40.0, 20.0]
			var ghost_alphas := [0.08, 0.20, 0.35]
			for i in range(3):
				draw_set_transform(Vector2(0, ghost_offsets[i]))
				_draw_ghost(Color(car_color.r, car_color.g, car_color.b, ghost_alphas[i]))
			draw_set_transform(Vector2.ZERO)

	match car_type:
		"player": _draw_player()
		"blue":   _draw_blue()
		"green":  _draw_green()
		"orange": _draw_orange()
		"purple": _draw_purple()

	# Drift smoke — drawn AFTER car body, behind the car
	if is_player_car:
		var parent = get_parent()
		if parent and "is_drifting" in parent and parent.is_drifting:
			var dt = parent.drift_time if "drift_time" in parent else 0.0
			# Smoke puffs at rear wheels — intensity grows with drift_time
			var smoke_alpha = clampf(dt / 1.5, 0.15, 0.55)
			var smoke_radius = lerp(6.0, 14.0, clampf(dt / 1.5, 0.0, 1.0))
			# Left rear wheel smoke
			draw_circle(Vector2(-18, 32), smoke_radius, Color(0.85, 0.85, 0.85, smoke_alpha))
			draw_circle(Vector2(-18, 38), smoke_radius * 0.7, Color(0.80, 0.80, 0.80, smoke_alpha * 0.6))
			# Right rear wheel smoke
			draw_circle(Vector2(18, 32), smoke_radius, Color(0.85, 0.85, 0.85, smoke_alpha))
			draw_circle(Vector2(18, 38), smoke_radius * 0.7, Color(0.80, 0.80, 0.80, smoke_alpha * 0.6))
			# Ready indicator — glow when drift_time >= threshold
			if dt >= 1.5:
				draw_circle(Vector2(-18, 32), smoke_radius + 3, Color(1.0, 0.6, 0.1, 0.35))
				draw_circle(Vector2(18, 32), smoke_radius + 3, Color(1.0, 0.6, 0.1, 0.35))

	# Boost exhaust glow — drawn AFTER car body so it appears on top
	if is_player_car:
		var parent = get_parent()
		if parent and "boost_time" in parent and parent.boost_time > 0:
			draw_arc(Vector2(0, 40), 10, 0, TAU, 12, Color(1.0, 0.85, 0.10, 0.65), true)
			draw_arc(Vector2(0, 40), 17, 0, TAU, 12, Color(1.0, 0.85, 0.10, 0.22), true)

	# Shield hexagon outline — drawn last so it's always visible
	if is_player_car:
		var parent2 = get_parent()
		if parent2 and "has_shield" in parent2 and parent2.has_shield:
			var hex_r = 48.0
			var hex_pts = PackedVector2Array()
			for i in range(6):
				var angle = TAU / 6.0 * i - PI / 6.0
				hex_pts.append(Vector2(cos(angle) * hex_r, sin(angle) * hex_r))
			hex_pts.append(hex_pts[0])
			draw_polyline(hex_pts, Color(0.2, 0.8, 1.0, 0.7), 3.0, true)


# ── Helpers ───────────────────────────────────────────────────────────────

func _shade(col: Color, f: float) -> Color:
	return Color(col.r * f, col.g * f, col.b * f, col.a)

func _shadow(ry: float = 12.0) -> void:
	draw_arc(Vector2(2.0, 5.0), ry * 2.0, 0.0, TAU, 16, Color(0, 0, 0, 0.30), true)

func _draw_ghost(col: Color) -> void:
	# Simplified car body (rectangle + windshield) used for speed trail ghosts
	draw_rect(Rect2(-22, -36, 44, 72), col)
	draw_rect(Rect2(-14, -28, 28, 16), Color(_WINDSHIELD.r, _WINDSHIELD.g, _WINDSHIELD.b, col.a * 0.5))

func _initial(text: String) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(0, 5),
			text, HORIZONTAL_ALIGNMENT_CENTER, -1, _FONT_SIZE,
			Color(1, 1, 1, 0.85))


# ── PLAYER — Chevron nose + rear spoiler ──────────────────────────────────

func _draw_player() -> void:
	var c      = car_color
	var dark   = _shade(c, 0.65)
	var spoiler = Color(0.18, 0.18, 0.22, 1)

	_shadow(13.0)

	# Main body
	draw_rect(Rect2(-22, -36, 44, 72), c)

	# Chevron nose — aggressive V at the front
	draw_colored_polygon(PackedVector2Array([
		Vector2(-22, -36), Vector2(0, -50), Vector2(22, -36),
	]), dark)

	# Windshield
	draw_rect(Rect2(-14, -28, 28, 16), _WINDSHIELD)

	# Cockpit / roof
	draw_rect(Rect2(-12, -20, 24, 22), dark)

	# Rear spoiler — bar + two struts (player identity marker)
	draw_rect(Rect2(-24,  30, 48,  5), spoiler)
	draw_rect(Rect2(-18,  28,  4,  7), spoiler)
	draw_rect(Rect2( 14,  28,  4,  7), spoiler)

	# White center stripe
	draw_rect(Rect2(-1, -36, 2, 72), Color(1, 1, 1, 0.55))

	# Headlights
	draw_rect(Rect2(-20, -38,  8, 4), Color(1.0, 0.97, 0.80, 1))
	draw_rect(Rect2( 12, -38,  8, 4), Color(1.0, 0.97, 0.80, 1))

	# Taillights
	draw_rect(Rect2(-20,  34,  7, 4), Color(0.90, 0.10, 0.10, 1))
	draw_rect(Rect2( 13,  34,  7, 4), Color(0.90, 0.10, 0.10, 1))

	_initial("Y")


# ── BLUE — Wide & Stubby "The Blocker" ────────────────────────────────────

func _draw_blue() -> void:
	var c    = car_color
	var dark = _shade(c, 0.55)
	var mid  = _shade(c, 0.75)

	_shadow(14.0)

	# Wide main body
	draw_rect(Rect2(-28, -30, 56, 58), c)

	# Dark front bumper slab — bully look
	draw_rect(Rect2(-28, -30, 56,  7), dark)

	# Wide short windshield
	draw_rect(Rect2(-18, -24, 36, 14), _WINDSHIELD)

	# Roof
	draw_rect(Rect2(-14, -16, 28, 20), mid)

	# Wide-set headlights
	draw_rect(Rect2(-26, -32,  9, 4), Color(0.90, 0.95, 1.0, 1))
	draw_rect(Rect2( 17, -32,  9, 4), Color(0.90, 0.95, 1.0, 1))

	# Taillights
	draw_rect(Rect2(-26,  26,  8, 4), Color(0.85, 0.10, 0.10, 1))
	draw_rect(Rect2( 18,  26,  8, 4), Color(0.85, 0.10, 0.10, 1))

	_initial("B")


# ── GREEN — Narrow & Long "The Drifter" ───────────────────────────────────

func _draw_green() -> void:
	var c    = car_color
	var dark = _shade(c, 0.62)
	var mid  = _shade(c, 0.78)

	_shadow(10.0)

	# Narrow tall body
	draw_rect(Rect2(-18, -42, 36, 80), c)

	# Chevron wedge nose (shares design language with player, but slimmer)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-18, -42), Vector2(0, -56), Vector2(18, -42),
	]), dark)

	# Narrow tall windshield
	draw_rect(Rect2(-11, -36, 22, 16), _WINDSHIELD)

	# Roof
	draw_rect(Rect2(-9, -24, 18, 28), mid)

	# Headlights
	draw_rect(Rect2(-16, -44,  6, 4), Color(1.0, 1.0, 0.80, 1))
	draw_rect(Rect2( 10, -44,  6, 4), Color(1.0, 1.0, 0.80, 1))

	# Taillights
	draw_rect(Rect2(-16,  36,  6, 4), Color(0.85, 0.10, 0.10, 1))
	draw_rect(Rect2( 10,  36,  6, 4), Color(0.85, 0.10, 0.10, 1))

	_initial("G")


# ── ORANGE — Van / Boxy "The Tank" ────────────────────────────────────────

func _draw_orange() -> void:
	var c      = car_color
	var dark   = _shade(c, 0.60)
	var darker = _shade(c, 0.42)

	_shadow(14.0)

	# Main body
	draw_rect(Rect2(-26, -36, 52, 70), c)

	# Raised cab section — van aesthetic
	draw_rect(Rect2(-22, -42, 44, 22), dark)

	# Flat vertical front face
	draw_rect(Rect2(-22, -42, 44,  6), darker)

	# Wide low windshield
	draw_rect(Rect2(-18, -36, 36, 12), _WINDSHIELD)

	# Wide-set amber headlights
	draw_rect(Rect2(-24, -44, 10, 5), Color(1.0, 0.95, 0.75, 1))
	draw_rect(Rect2( 14, -44, 10, 5), Color(1.0, 0.95, 0.75, 1))

	# Taillights
	draw_rect(Rect2(-24,  32,  9, 5), Color(0.85, 0.10, 0.10, 1))
	draw_rect(Rect2( 15,  32,  9, 5), Color(0.85, 0.10, 0.10, 1))

	_initial("O")


# ── PURPLE — Tapered Wedge "The Phantom" ──────────────────────────────────

func _draw_purple() -> void:
	var c    = car_color
	var dark = _shade(c, 0.55)

	_shadow(11.0)

	# Trapezoid body — wide at rear, narrow at front
	draw_colored_polygon(PackedVector2Array([
		Vector2(-20,  40),
		Vector2( 20,  40),
		Vector2( 13, -40),
		Vector2(-13, -40),
	]), c)

	# Center spine — semi-transparent lighter streak
	draw_rect(Rect2(-2, -40, 4, 80), Color(1.0, 1.0, 1.0, 0.18))

	# Trapezoidal windshield
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10, -30), Vector2( 10, -30),
		Vector2( 12, -14), Vector2(-12, -14),
	]), _WINDSHIELD)

	# Thin angular "evil eye" headlights
	draw_rect(Rect2(-12, -42,  5, 3), Color(0.95, 0.82, 1.0, 1))
	draw_rect(Rect2(  7, -42,  5, 3), Color(0.95, 0.82, 1.0, 1))

	# Purple-tinted taillights
	draw_rect(Rect2(-18,  38,  8, 3), dark)
	draw_rect(Rect2( 10,  38,  8, 3), dark)

	_initial("P")
