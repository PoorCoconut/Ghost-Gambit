extends CharacterBody2D

@export var grid_size: int = 80
@export var move_speed: float = 0.25 
@export var max_hp: int = 3
@export var health: int
@export var rook_clone_scene: PackedScene = preload("res://game_scenes/En-Tities/Scenes/rook_clone.tscn")
@export var enemy_type: String = "Rook"
@export var is_clone: bool = false

var is_moving: bool = false
var is_charging: bool = false 
var cooldown_turns: int = 0 
var player: CharacterBody2D

func _ready():
	health = max_hp
	add_to_group("enemies")
	modulate = Color(0, 0.6, 1)
	position = position.snapped(Vector2(grid_size, grid_size)) + Vector2(grid_size/2, grid_size/2)
	
	player = get_tree().get_first_node_in_group("player")
	if player:
		player.moved_one_tile.connect(_on_player_turn_finished)

func _on_player_turn_finished():
	if not is_moving and is_instance_valid(self):
		if cooldown_turns > 0:
			cooldown_turns -= 1
			modulate.a = 0.3
			return
		
		modulate.a = 1.0
		await get_tree().create_timer(0.05).timeout
		check_for_alignment()

func check_for_alignment():
	if not is_instance_valid(player): return
	
	var my_grid_pos = Vector2i((position / grid_size).round())
	var player_grid_pos = Vector2i((player.position / grid_size).round())
	var diff = player_grid_pos - my_grid_pos

	if diff.x == 0 or diff.y == 0:
		if diff == Vector2i.ZERO: return
		
		var move_dir = Vector2(sign(diff.x), sign(diff.y))
		var distance_tiles = abs(diff.x) + abs(diff.y)
		
		if distance_tiles == 1:
			if not is_charging:
				wind_up()
			else:
				attack_player()
			return
		
		if is_charging:
			is_charging = false
			modulate = Color(0, 0.6, 1)

		var steps = distance_tiles - 1
		if steps > 0:
			scan_and_jump(move_dir, steps)

func wind_up():
	is_charging = true
	modulate = Color(5, 5, 0) 

func attack_player():
	is_moving = true
	is_charging = false
	modulate = Color(0, 0.6, 1)
	
	var dir_to_player = (player.position - position).normalized()
	var original_pos = position
	
	var tween = create_tween()
	tween.tween_property(self, "position", position + (dir_to_player * 45), 0.1)
	tween.tween_property(self, "position", original_pos, 0.1)
	
	if player.has_method("take_damage"):
		player.take_damage(1)
	
	await tween.finished
	is_moving = false

func scan_and_jump(dir: Vector2, max_steps: int):
	var possible_steps = 0
	for i in range(1, max_steps + 1):
		var check_pos = position + (dir * grid_size * i)
		if is_tile_blocked(check_pos):
			break 
		possible_steps = i
	
	if possible_steps > 0:
		perform_jump(dir, possible_steps)

func perform_jump(dir: Vector2, steps: int):
	is_moving = true
	var target_pos = position + (dir * grid_size * steps)
	cooldown_turns = steps 
	
	var tween = create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", target_pos, move_speed)
	
	await tween.finished
	
	var my_grid_pos = Vector2i((position / grid_size).round())
	var player_grid_pos = Vector2i((player.position / grid_size).round())
	var diff = player_grid_pos - my_grid_pos
	
	if abs(diff.x) + abs(diff.y) == 1:
		attack_player()
	else:
		is_moving = false


func receive_knockback(push_dir: Vector2):
	is_charging = false
	modulate = Color(0, 0.6, 1)
	modulate.a = 1.0 
	
	health -= 1
	flash_damage()
	
	if health <= 0:
		# --- ESSENCE COLLECTION ---
		# We only give essence if this is the ORIGINAL Rook, not a clone
		if not is_clone:
			var p = get_tree().get_first_node_in_group("player")
			if is_instance_valid(p) and p.has_method("add_essence_to_queue"):
				p.add_essence_to_queue(enemy_type)
		
		queue_free()
		return
		
	spawn_rook_clone()
	
	if test_move(transform, push_dir * (grid_size - 5)):
		return
		
	is_moving = true
	var kb_target = position + (push_dir * grid_size)
	var tween = create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", kb_target, 0.15)
	
	await tween.finished
	is_moving = false

func spawn_rook_clone():
	if not rook_clone_scene or not is_instance_valid(player): return
	
	# Get current grid coordinates
	var my_grid = Vector2i((position / grid_size).floor())
	var p_grid = Vector2i((player.position / grid_size).floor())
	var diff = p_grid - my_grid
	
	var dir_to_p = Vector2i(sign(diff.x), sign(diff.y))
	
	var clone_grid = my_grid 
	
	if test_move(transform, Vector2(dir_to_p) * 5):
		clone_grid = my_grid + dir_to_p

	var clone_pos = (Vector2(clone_grid) * grid_size) + Vector2(grid_size/2, grid_size/2)
	
	if clone_grid != p_grid and not is_tile_blocked(clone_pos):
		call_deferred("_do_spawn", clone_pos)
	else:
		var fallback_pos = (Vector2(my_grid) * grid_size) + Vector2(grid_size/2, grid_size/2)
		if my_grid != p_grid:
			call_deferred("_do_spawn", fallback_pos)

func _do_spawn(spawn_pos: Vector2):
	var clone = rook_clone_scene.instantiate()
	get_parent().add_child(clone)
	clone.position = spawn_pos

func flash_damage():
	var old_mod = modulate
	modulate = Color(10, 10, 10)
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(self):
		modulate = old_mod

func is_tile_blocked(target_pos: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var sensor = RectangleShape2D.new()
	sensor.size = Vector2(50, 50) 
	query.shape = sensor
	query.transform = Transform2D(0, target_pos)
	query.collision_mask = 2 | 4 
	query.exclude = [get_rid()] 
	var results = space_state.intersect_shape(query)
	return results.size() > 0

func apply_healing(amount: int):
	health += amount
	health = min(health, max_hp)
