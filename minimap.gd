extends Control

# ---------------------------------------------------------------------------
# Minimap Race Tracker
# Shows the full track outline with colored dots for all cars.
# Attach to a Control node inside HUD (top-right corner).
# ---------------------------------------------------------------------------

const MAP_SIZE     = Vector2(120, 120)
const MAP_PADDING  = 10.0
const PLAYER_DOT_R = 5.0
const AI_DOT_R     = 3.5
const BG_COLOR     = Color(0.06, 0.05, 0.14, 0.80)
const BORDER_COLOR = Color(0.333, 0.200, 0.733, 0.90)
const TRACK_COLOR  = Color(0.45, 0.45, 0.55, 0.70)
const TRACK_WIDTH  = 2.5

var track_points: Array = []   # Array[Vector2] — raw world positions
var player_node: Node2D        # the player Sprite2D
var ai_nodes: Array = []       # Array of AI car nodes
var player_color: Color = Color(1, 0.2, 0.2)

# Computed in _recalc_bounds()
var _map_scale: Vector2 = Vector2.ONE
var _map_offset: Vector2 = Vector2.ZERO
var _scaled_track: PackedVector2Array = PackedVector2Array()

func setup(points: Array, player: Node2D, ais: Array, p_color: Color) -> void:
	track_points = points
	player_node  = player
	ai_nodes     = ais
	player_color = p_color
	custom_minimum_size = MAP_SIZE
	size = MAP_SIZE
	_recalc_bounds()


func _recalc_bounds() -> void:
	if track_points.is_empty():
		return

	var min_pt = Vector2(INF, INF)
	var max_pt = Vector2(-INF, -INF)
	for p in track_points:
		min_pt.x = min(min_pt.x, p.x)
		min_pt.y = min(min_pt.y, p.y)
		max_pt.x = max(max_pt.x, p.x)
		max_pt.y = max(max_pt.y, p.y)

	var world_size = max_pt - min_pt
	if world_size.x == 0: world_size.x = 1
	if world_size.y == 0: world_size.y = 1

	var inner = MAP_SIZE - Vector2(MAP_PADDING * 2, MAP_PADDING * 2)
	var sx = inner.x / world_size.x
	var sy = inner.y / world_size.y
	var s  = min(sx, sy)  # uniform scale
	_map_scale  = Vector2(s, s)
	_map_offset = -min_pt * s + Vector2(MAP_PADDING, MAP_PADDING)

	# Center the track if aspect ratio doesn't fill
	var used = world_size * s
	_map_offset.x += (inner.x - used.x) * 0.5
	_map_offset.y += (inner.y - used.y) * 0.5

	# Pre-compute scaled track points for drawing
	_scaled_track.clear()
	for p in track_points:
		_scaled_track.append(p * _map_scale + _map_offset)


func _world_to_map(world_pos: Vector2) -> Vector2:
	return world_pos * _map_scale + _map_offset


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _scaled_track.is_empty():
		return

	# Background panel
	var bg_rect = Rect2(Vector2.ZERO, MAP_SIZE)
	draw_rect(bg_rect, BG_COLOR)
	draw_rect(bg_rect, BORDER_COLOR, false, 2.0)

	# Track outline
	draw_polyline(_scaled_track, TRACK_COLOR, TRACK_WIDTH, true)

	# AI dots
	for ai in ai_nodes:
		if not is_instance_valid(ai):
			continue
		var dot_pos = _world_to_map(ai.global_position)
		draw_circle(dot_pos, AI_DOT_R, ai.car_color)

	# Player dot (larger, with white border)
	if is_instance_valid(player_node):
		var pp = _world_to_map(player_node.global_position)
		draw_circle(pp, PLAYER_DOT_R + 1.5, Color.WHITE)
		draw_circle(pp, PLAYER_DOT_R, player_color)

		# "YOU" label below dot
		var font = ThemeDB.fallback_font
		if font:
			draw_string(font, pp + Vector2(-10, PLAYER_DOT_R + 12), "YOU", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)
