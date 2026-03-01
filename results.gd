extends Control

const TROPHIES = ["[1ST]", "[2ND]", "[3RD]"]
const PLACES   = ["1st", "2nd", "3rd", "4th", "5th"]


func _ready() -> void:
	var order     = GameData.finish_order
	var container = $ScrollContainer/VBox

	for i in range(order.size()):
		var entry: Dictionary = order[i]
		var row = Label.new()
		row.add_theme_font_size_override("font_size", 30)

		var mins  = int(entry.time) / 60
		var secs  = fmod(entry.time, 60.0)
		var t_str = "%d:%05.2f" % [mins, secs]

		if i < 3:
			row.text = "%s  %s  —  %s  —  %s" % [TROPHIES[i], PLACES[i], entry.name, t_str]
			if i == 0:
				row.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1, 1))
			elif i == 1:
				row.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 1))
			else:
				row.add_theme_color_override("font_color", Color(0.8, 0.5, 0.2, 1))
		else:
			row.text = "     %s  —  %s  —  Better Luck Next Time!" % [PLACES[i], entry.name]
			row.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65, 1))

		container.add_child(row)


func _on_race_again_pressed() -> void:
	GameData.clear()
	get_tree().change_scene_to_file("res://main.tscn")


func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://main_menu.tscn")
