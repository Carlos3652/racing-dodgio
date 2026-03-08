extends Node

# Shared state passed between scenes
var finish_order: Array[Dictionary] = []  # [{name: String, time: float}]

# Car selection — set by main_menu, read by race_manager
var player_color: Color = Color(1.0, 0.133, 0.133, 1)  # default red
var player_car_type: String = "player"  # visual style key

# Replay + Share data — written by race_manager at race end
var track_points: Array = []              # Array[Vector2] — track waypoints
var final_positions: Dictionary = {}      # {car_name: Vector2} — where each car ended
var race_stats: Dictionary = {}           # {stars: int, stuns: int, bumps: int, boost_pct: float, lead_changes: int}

func clear():
	finish_order.clear()
	track_points.clear()
	final_positions.clear()
	race_stats.clear()
