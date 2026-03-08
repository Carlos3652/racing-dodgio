extends Node

# Shared state passed between scenes
var finish_order: Array[Dictionary] = []  # [{name, time, color_name}]

# Car selection — set by main_menu, read by race_manager
var player_color: Color = Color(1.0, 0.133, 0.133, 1)  # default red
var player_car_type: String = "player"  # visual style key

func clear():
	finish_order.clear()
