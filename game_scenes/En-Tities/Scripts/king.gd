extends CharacterBody2D

@export var grid_size: int = 80
@export var pawn_scene: PackedScene = preload("res://game_scenes/En-Tities/Scenes/pawn.tscn")
var health: int = 15
var turn_counter: int = 0
var spawn_timer: int = 1
var min_wait: int = 6
var max_wait: int = 10

@onready var sprite:Sprite2D = $Sprite

func _ready():
	#spawn ig
	add_to_group("enemies")
	
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_signal("moved_one_tile"):
		player.moved_one_tile.connect(_on_player_turn)
#respond to signal
func _on_player_turn():
	spawn_timer -= 1
	
	if spawn_timer <= 0:
		sprite.frame = 1
		spawn_pawn()
		spawn_timer = min_wait + (randi() % 5)
#spawn helper
func spawn_pawn():
	if pawn_scene:
		# Picks a random lane (from -4 to 3)
		var lane = randi() % 8 - 4
		
		var spawn_x = global_position.x + (lane * grid_size)
		var spawn_y = global_position.y + (grid_size * 3)
		
		take_damage(1)
		
		var new_pawn = pawn_scene.instantiate()
		new_pawn.global_position = Vector2(spawn_x, spawn_y)
		
		if "tiles_moved" in new_pawn:
			new_pawn.tiles_moved = 0
			
		get_parent().add_child(new_pawn)
		flash_king()
		
#visuals, edit please
func flash_king():
	modulate = Color(5, 5, 0)
	var t = create_tween()
	t.tween_property(self, "modulate", Color(1, 1, 1), 0.3)
	sprite.frame = 0
#useless tbh
func take_damage(amount: int):
	health -= amount
	var t = create_tween()
	t.tween_property(self, "modulate", Color(1, 1, 1), 0.2)
	
	if health <= 0:
		#dead
		queue_free()
