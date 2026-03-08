extends Node

# Personal best records — persisted to user://records.json
# Schema: { tracks: { "track_name": { best_position: int, best_time: float, total_races: int } },
#            lifetime: { total_stars: int, total_races: int } }

var data: Dictionary = {}
const SAVE_PATH = "user://records.json"


func _ready() -> void:
	_load()


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		data = {tracks = {}, lifetime = {total_stars = 0, total_races = 0}}
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		data = {tracks = {}, lifetime = {total_stars = 0, total_races = 0}}
		return
	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	file.close()
	if err == OK and json.data is Dictionary:
		data = json.data
	else:
		data = {tracks = {}, lifetime = {total_stars = 0, total_races = 0}}


func _save() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


func record_race(track_name: String, position: int, time: float, stars: int) -> bool:
	# Returns true if this is a new personal best (position or time)
	if not data.has("tracks"):
		data["tracks"] = {}
	if not data.has("lifetime"):
		data["lifetime"] = {total_stars = 0, total_races = 0}

	var is_pb = false

	if not data.tracks.has(track_name):
		data.tracks[track_name] = {best_position = position, best_time = time, total_races = 1}
		is_pb = (position == 1)
	else:
		var rec = data.tracks[track_name]
		rec.total_races = rec.get("total_races", 0) + 1
		if position < rec.get("best_position", 6):
			rec.best_position = position
			is_pb = true
		# Only store best time for 1st place finishes
		if position == 1 and time < rec.get("best_time", INF):
			rec.best_time = time
			is_pb = true

	data.lifetime.total_stars = data.lifetime.get("total_stars", 0) + stars
	data.lifetime.total_races = data.lifetime.get("total_races", 0) + 1

	_save()
	return is_pb


func get_best_time(track_name: String) -> float:
	if data.has("tracks") and data.tracks.has(track_name):
		return data.tracks[track_name].get("best_time", INF)
	return INF


func get_best_position(track_name: String) -> int:
	if data.has("tracks") and data.tracks.has(track_name):
		return data.tracks[track_name].get("best_position", 6)
	return 6
