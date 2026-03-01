extends Control


func _ready() -> void:
	$VBox/StartButton.grab_focus()


func _on_start_pressed() -> void:
	GameData.clear()
	get_tree().change_scene_to_file("res://main.tscn")


