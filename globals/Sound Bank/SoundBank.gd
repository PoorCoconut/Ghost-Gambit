extends Node

#Store sound effects here...
var sfx_dict : Dictionary = {
	"test_sfx" : preload("res://sound/sfx/sfx_example.mp3"),
	"explosion" : preload("res://sound/sfx/sfx_explosion1.mp3"),
	"heal1" : preload("res://sound/sfx/sfx_healing1.mp3"),
	"heal2" : preload("res://sound/sfx/sfx_healing2.mp3"),
	"hit1" : preload("res://sound/sfx/sfx_hit1.mp3"),
	"hit2" : preload("res://sound/sfx/sfx_hit2.mp3"),
	"hit3" : preload("res://sound/sfx/sfx_hit3.mp3"),
	"hit4" : preload("res://sound/sfx/sfx_hit4.mp3"),
	"magic" : preload("res://sound/sfx/sfx_magic1.mp3"),
	"shield1" : preload("res://sound/sfx/sfx_shield1.mp3"),
	"shield2" : preload("res://sound/sfx/sfx_shield2.mp3"),
	"shield3" : preload("res://sound/sfx/sfx_shield3.mp3"),
	"dash1" : preload("res://sound/sfx/sfx_woosh1.mp3"),
	"dash2" : preload("res://sound/sfx/sfx_woosh2.mp3")
}

#Here is an example:
#"swing_sword": preload("res://audio/sfx/swing.ogg"),
#"jump": preload("res://audio/sfx/jump.ogg"),
#"slide_friction": preload("res://audio/sfx/friction.wav")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func play_sfx(sfx_name : String, spawn_pos : Vector2) -> void:
	#Check if sound exists
	if not sfx_dict.has(sfx_name):
		push_error("GameManager: SFX '" + sfx_name + "' not found in dictionary.")
		return
		
	#Create an audio player
	var sfx_player = AudioStreamPlayer2D.new()
	
	#Give it the specific sound from the dictionary and set its position
	sfx_player.stream = sfx_dict[sfx_name]
	sfx_player.global_position = spawn_pos
	sfx_player.pitch_scale = randf_range(0.7, 1.2) #Change these values for more variation of the sounds
	sfx_player.bus = "SFX"
	
	#Add it to the GameManager, play it, and queue_free when done
	add_child(sfx_player)
	sfx_player.finished.connect(sfx_player.queue_free)
	sfx_player.play()
