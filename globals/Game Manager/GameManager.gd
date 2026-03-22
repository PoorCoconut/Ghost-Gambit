extends Node

var CURRENT_WORLD_STATE : String = "Nothing"
const SAVE_PATH : String = "user://savegame.json"

func _ready() -> void:
	print("GAME MANAGER LOADED!")

##KEYS DICTIONARY
var collected_keys = {
	"Basement_Key": false,
	"FirstFloor_Key": false,
	"Attic_Key": false
}

##SAVE FILE LOGIC
func save_player_position(player_pos: Vector2) -> void:
	var save_data = {
		"player_x": player_pos.x,
		"player_y": player_pos.y
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(save_data, "\t"))
	print("Game Saved!")

func load_player_position():
	#Check if the player has ever saved the game before
	if not FileAccess.file_exists(SAVE_PATH):
		print("No save file found. Starting from the bottom!")
		return null # Returning null lets the Player node know to use its default spawn
		
	#Open the file and read the text
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var json_text = file.get_as_text()
	
	#Parse the JSON back into a dictionary
	var save_data = JSON.parse_string(json_text)
	
	#Extract the coordinates and return them as a usable Vector2
	if save_data and save_data.has("player_x") and save_data.has("player_y"):
		var loaded_pos = Vector2(save_data["player_x"], save_data["player_y"])
		print("Save loaded! Teleporting player to: ", loaded_pos)
		return loaded_pos
	return null

##Next Level Helper Functions
func load_next_level(next_level_path : String) -> void:
	await ScreenTransition.trans_in().finished
	LoadingScreen.load_level(next_level_path)

##Camera Helper Functions
func do_camera_shake(intensity:float, time:float):
	if get_tree().get_first_node_in_group("camera"):
		var camera = get_tree().get_first_node_in_group("camera")
		var camera_tween = get_tree().create_tween()
		camera_tween.tween_method(camera.startCameraShake, intensity, 1.0, time)
		camera.startCameraShake(intensity)
		await get_tree().create_timer(time).timeout
		camera.resetCameraOffset()

func move_camera_to_player(player_pos : Vector2):
	if get_tree().get_first_node_in_group("camera"):
		var camera = get_tree().get_first_node_in_group("camera")
		camera.moveCameraToEntity(player_pos)

## KEY HELPER FUNCTIONS
func has_key(key_name: String) -> bool:
	return collected_keys.get(key_name, false)

func collect_key(key_name: String) -> void:
	if collected_keys.has(key_name):
		collected_keys[key_name] = true
		do_camera_shake(5.0, 0.2)

## TILE LOGIC
func can_move_to_tile(tile_pos: Vector2i, tilemap: TileMapLayer) -> bool:
	var tile_data = tilemap.get_cell_tile_data(tile_pos)
	
	if tile_data:
		var key_needed = tile_data.get_custom_data("required_key")
		
		if key_needed != "":
			if has_key(key_needed):
				tilemap.erase_cell(tile_pos)
				return true
			else:
				do_camera_shake(5.0, 0.1)
				return false
	return true # If it's not lock movement allowed

## LEVEL TRANSITION LOGIC
func check_for_exit(tile_pos: Vector2i, tilemap: TileMapLayer) -> void:
	var tile_data = tilemap.get_cell_tile_data(tile_pos)
	
	if tile_data:
		var path = tile_data.get_custom_data("next_level")
		
		if path != "":
			load_next_level(path)
