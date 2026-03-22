extends CharacterBody2D

@export var grid_size: int = 80
var health: int = 2
var type: String = "Pawn"
var tiles_moved: int = 0 #just counter, cause grdding aint working gang
var move: bool = false
@export var rook: PackedScene = preload("res://game_scenes/En-Tities/Scenes/rook.tscn")
@export var knight: PackedScene = preload("res://game_scenes/En-Tities/Scenes/knight.tscn")
@export var queen: PackedScene = preload("res://game_scenes/En-Tities/Scenes/queen.tscn")
@export var bishop: PackedScene = preload("res://game_scenes/En-Tities/Scenes/bishop.tscn")

@onready var sprite:Sprite2D = $Sprite

func _ready():
	add_to_group("enemies")
	
	var player = get_tree().get_first_node_in_group("player")
	position = position.snapped(Vector2(grid_size, grid_size)) + Vector2(grid_size/2, grid_size/2)
	if player and player.has_signal("moved_one_tile"):
		player.moved_one_tile.connect(_on_player_moved)
	else:
		await get_tree().process_frame
		player = get_tree().get_first_node_in_group("player")
		if player and player.has_signal("moved_one_tile"):
			player.moved_one_tile.connect(_on_player_moved)

func _on_player_moved():
	var next_pos = position + Vector2(0, grid_size)
	move = !move
	if(move):
		return
	if not test_move(transform, Vector2(0, grid_size - 5)):
		sprite.frame = 0
		var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "position", next_pos, 0.2)
		await tween.finished
		
		tiles_moved += 1
		check_promotion()
#maybe effects??
func check_promotion():
	if tiles_moved >= 7 and type == "Pawn":
		promote()
		
func promote():
	var roll = randf()
	var new_scene: PackedScene
	var new_type: String

	if roll < 0.10: # 10% Chance
		new_scene = queen
		new_type = "Queen"
	elif roll < 0.30:
		new_scene = rook
		new_type = "Rook"
	elif roll < 0.65:
		new_scene = knight
		new_type = "Knight"
	else:
		new_scene = bishop
		new_type = "Bishop"

	spawn_official(new_scene, new_type)
#add some special effects
func spawn_official(scene: PackedScene, elite_type: String):
	if scene:
		var official = scene.instantiate()
		official.position = position
		if "type" in official:
			official.type = elite_type
		
		get_parent().add_child(official)
		queue_free()
#char take damagte naman, jokes on you receive knockback japon ang gi call
func take_damage(amount: int):
	health -= amount
	modulate = Color(10, 10, 10)
	var t = create_tween()
	t.tween_property(self, "modulate", Color(1, 1, 1), 0.2)
	
	sprite.frame = 1
	
	if health <= 0:
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_method("add_essence_to_queue"):
			player.add_essence_to_queue(type)
		queue_free()
#just duke mfker
func receive_knockback(dir: Vector2):
	take_damage(1)
	if health<=0: return
	
	var target = position + (dir * grid_size)
	if not test_move(transform, dir * (grid_size - 5)):
		var tween = create_tween()
		tween.tween_property(self, "position", target, 0.1)
