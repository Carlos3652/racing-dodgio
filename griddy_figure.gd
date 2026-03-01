extends Node2D
## Procedural stick-figure dancer.  The AnimationPlayer drives `frame` (0-4)
## exactly as it did with the old Sprite2D sheet — no scene changes needed.

# ── Colours ───────────────────────────────────────────────────────────────
const _HEAD  = Color(1.00, 0.80, 0.60, 1)
const _SHIRT = Color(0.20, 0.55, 1.00, 1)
const _PANTS = Color(0.10, 0.12, 0.38, 1)
const _SHOES = Color(0.10, 0.06, 0.04, 1)

# ── Dimensions ────────────────────────────────────────────────────────────
const HEAD_R = 13.0
const BODY_H = 26.0
const LEG_L  = 36.0
const ARM_L  = 26.0

# ── Pose table ────────────────────────────────────────────────────────────
# [hip_x, hip_y,  left_arm_deg, right_arm_deg,  left_leg_deg, right_leg_deg]
# Arm degrees: 0 = pointing UP; +90 = right; -90 = left; 180 = down.
# Leg degrees: 0 = pointing DOWN; +30 = right of down; -30 = left of down.
const POSES = [
	[  0, -5,   -90,   90,   -20,  20 ],  # 0  idle — arms spread
	[ -5, -4,   -55,  145,   -44,   8 ],  # 1  step L — left arm pumps up
	[  5, -4,  -145,   55,    -8,  44 ],  # 2  step R — right arm pumps up
	[ -6,  2,   -42,  138,   -54,   6 ],  # 3  crouch L — left arm high
	[  6,  2,  -138,   42,    -6,  54 ],  # 4  crouch R — right arm high
]

# ── frame property (AnimationPlayer writes to this) ───────────────────────
var frame: int = 0:
	set(v):
		frame = v
		queue_redraw()


func _draw() -> void:
	var p   = POSES[clamp(frame, 0, POSES.size() - 1)]
	var hip = Vector2(float(p[0]), float(p[1]))
	var la  = deg_to_rad(float(p[2]))
	var ra  = deg_to_rad(float(p[3]))
	var ll  = deg_to_rad(float(p[4]))
	var rl  = deg_to_rad(float(p[5]))

	var chest = hip   + Vector2(0, -BODY_H)
	var head  = chest + Vector2(0, -(HEAD_R + 4.0))

	# Shadow ellipse
	draw_arc(Vector2(hip.x, 18), 20, 0, TAU, 12, Color(0, 0, 0, 0.25), true)

	# ── Legs (draw before body so hips are covered) ──────────────────────
	var lfoot = hip + Vector2(sin(ll),  cos(ll)) * LEG_L
	var rfoot = hip + Vector2(sin(rl),  cos(rl)) * LEG_L
	draw_line(hip, lfoot, _PANTS, 7, true)
	draw_line(hip, rfoot, _PANTS, 7, true)
	draw_arc(lfoot, 6, 0, TAU, 8, _SHOES, true)
	draw_arc(rfoot, 6, 0, TAU, 8, _SHOES, true)

	# ── Body ─────────────────────────────────────────────────────────────
	draw_line(hip, chest, _SHIRT, 11, true)

	# ── Arms ─────────────────────────────────────────────────────────────
	var lhand = chest + Vector2(sin(la), -cos(la)) * ARM_L
	var rhand = chest + Vector2(sin(ra), -cos(ra)) * ARM_L
	draw_line(chest, lhand, _HEAD, 5, true)
	draw_line(chest, rhand, _HEAD, 5, true)
	draw_arc(lhand, 5, 0, TAU, 8, _HEAD, true)
	draw_arc(rhand, 5, 0, TAU, 8, _HEAD, true)

	# ── Head ─────────────────────────────────────────────────────────────
	draw_arc(head, HEAD_R, 0, TAU, 16, _HEAD, true)
	# Hair stripe
	draw_arc(head, HEAD_R, PI + 0.4, TAU - 0.4, 8, _SHOES, false, 4.0)
	# Eyes
	draw_arc(head + Vector2(-4.5, -2.5), 2.5, 0, TAU, 8, Color(0.1, 0.1, 0.2, 1), true)
	draw_arc(head + Vector2( 4.5, -2.5), 2.5, 0, TAU, 8, Color(0.1, 0.1, 0.2, 1), true)
	# Smile
	draw_arc(head + Vector2(0, 2), 5, 0.25, PI - 0.25, 8, Color(0.2, 0.08, 0.08, 1), false, 1.5)
