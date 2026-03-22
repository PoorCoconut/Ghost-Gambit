extends CharacterBody2D

@export var grid_size: int = 80
@export var move_speed: float = 0.15
@export var max_hp : int = 3
@export var health: int
@export var enemy_type: String = "Knight"

var is_moving: bool = false
var is_charging: bool = false
var locked_target_pos: Vector2 
var return_pos: Vector2
var target_tile_pos: Vector2 = Vector2.ZERO 
var player: CharacterBody2D
var turn_counter: int = 0

const L_MOVES = [
	Vector2i(2, 1), Vector2i(2, -1), Vector2i(-2, 1), Vector2i(-2, -1),
	Vector2i(1, 2), Vector2i(1, -2), Vector2i(-1, 2), Vector2i(-1, -2)
]

@onready var sprite:Sprite2D = $Sprite

func _ready():
	health = max_hp
	add_to_group("enemies")
	modulate = Color(0.2, 0.8, 0.2)
	sprite.frame = 0
	position = (Vector2i(position / grid_size) * grid_size) + Vector2i(grid_size/2, grid_size/2)
	player = get_tree().get_first_node_in_group("player")
	if player and player.has_signal("moved_one_tile"):
		player.moved_one_tile.connect(_on_player_turn_finished)
func _on_player_turn_finished():
	if is_moving or not is_instance_valid(self): return
	
	var turn_delay = (get_instance_id() % 20) * 0.05
	await get_tree().create_timer(0.05 + turn_delay).timeout
	
	await execute_knight_logic()
	
	if is_instance_valid(self):
		await get_tree().create_timer(0.1).timeout
		
		await execute_knight_logic()
#jumpieeeeeeeee logic
func execute_knight_logic():
	if is_charging:
		sprite.frame = 1
		await execute_knight_jump(locked_target_pos, true)
		return

	var my_grid = Vector2i((position / grid_size).floor())
	var p_grid = Vector2i((player.position / grid_size).floor())
	var diff = (p_grid - my_grid).abs()
	
	# Check if player is in "L" range
	if (diff.x == 2 and diff.y == 1) or (diff.x == 1 and diff.y == 2):
		sprite.frame = 1
		is_charging = true
		locked_target_pos = (Vector2(p_grid) * grid_size) + Vector2(grid_size/2, grid_size/2)
		target_tile_pos = locked_target_pos
		modulate = Color(5, 5, 0)
	else:
		var best_l_target = find_best_l_jump(my_grid, p_grid, true)
		if best_l_target != position:
			await execute_knight_jump(best_l_target, false)
#helper
func find_best_l_jump(my_grid: Vector2i, p_grid: Vector2i, closer: bool) -> Vector2:
	var best_px = position
	var best_dist = position.distance_to(player.position) if closer else 0.0
	
	for offset in L_MOVES:
		var target_grid = my_grid + offset
		var target_px = (Vector2(target_grid) * grid_size) + Vector2(grid_size/2, grid_size/2)
		
		if not is_tile_blocked(target_px):
			var d = target_px.distance_to(player.position)
			if closer:
				if d < best_dist:
					best_dist = d
					best_px = target_px
			else:
				if d > best_dist:
					best_dist = d
					best_px = target_px
	return best_px
#jump
func execute_knight_jump(target: Vector2, is_attack: bool):
	is_moving = true
	is_charging = false
	return_pos = position
	
	target_tile_pos = target 
	sprite.frame = 1
	
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", target, move_speed)
	
	await tween.finished
	
	sprite.frame = 0
	
	if is_attack:
		if position.distance_to(player.position) < 20:
			if player.has_method("take_damage"):
				player.take_damage(1)
			
			target_tile_pos = return_pos 
			
			var back_tween = create_tween().set_trans(Tween.TRANS_SINE)
			back_tween.tween_property(self, "position", return_pos, move_speed)
			await back_tween.finished
	
	target_tile_pos = Vector2.ZERO 
	modulate = Color(0.2, 0.8, 0.2)
	is_moving = false

#damage
func receive_knockback(push_dir: Vector2):
	health -= 1
	flash_damage()
	
	if health <= 0:
		#essence
		var p = get_tree().get_first_node_in_group("player")
		if is_instance_valid(p) and p.has_method("add_essence_to_queue"):
			p.add_essence_to_queue(enemy_type)
			
		queue_free()
		return

	is_charging = false
	var my_grid = Vector2i((position / grid_size).floor())
	var p_grid = Vector2i((player.position / grid_size).floor())
	
	var escape_pos = find_best_l_jump(my_grid, p_grid, false)
	
	if escape_pos != position:
		execute_knight_jump(escape_pos, false)
	else:
		var kb_target = position + (push_dir * grid_size)
		if not is_tile_blocked(kb_target):
			var tween = create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
			tween.tween_property(self, "position", kb_target, 0.15)

func is_tile_blocked(target_pos: Vector2) -> bool:
	# 1. Check Physics (Walls/Static Objects)
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = RectangleShape2D.new()
	query.shape.size = Vector2(50, 50)
	query.transform = Transform2D(0, target_pos)
	query.collision_mask = 2 # Walls Layer
	
	if space_state.intersect_shape(query).size() > 0: 
		return true
	
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy != self:
			if enemy.position.distance_to(target_pos) < 10: 
				return true
			if enemy.get("target_tile_pos") != null:
				if enemy.target_tile_pos.distance_to(target_pos) < 10:
					return true
					
	return false

func flash_damage():
	var old_mod = modulate
	modulate = Color(10, 10, 10)
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(self): modulate = old_mod
#you may design this
func apply_healing(amount: int):
	health += amount
	health = min(health, max_hp)
