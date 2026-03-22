extends CharacterBody2D

@export var grid_size: int = 80
@export var move_speed: float = 0.2
@export var max_hp: int = 5
@export var heal_amount: int = 2
@export var enemy_type: String = "Bishop"
var health: int
var is_moving: bool = false
var turn_counter: int = 0
var heal_fatigue_turns: int = 0
var target_tile_pos: Vector2 = Vector2.ZERO
var player: CharacterBody2D

func _ready():
	health = max_hp
	add_to_group("enemies")
	#remove this
	modulate = Color(0.8, 0.2, 0.8)
	position = position.snapped(Vector2(grid_size, grid_size)) + Vector2(grid_size/2, grid_size/2)
	
	player = get_tree().get_first_node_in_group("player")
	if player:
		player.moved_one_tile.connect(_on_player_turn_finished)

func _on_player_turn_finished():
	if is_moving or not is_instance_valid(self): return
	
	if heal_fatigue_turns > 0:
		heal_fatigue_turns -= 1
		modulate.a = 0.4
		return 
	
	modulate.a = 1.0 
	turn_counter += 1
	if turn_counter >= 3:
		turn_counter = 0
		execute_heal_pulse()
		heal_fatigue_turns = 5
		return 
	
	process_diagonal_kiting()

func process_diagonal_kiting():
	var my_grid = Vector2i((position / grid_size).floor())
	var directions = [Vector2i(1,1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(-1,-1)]
	
	var best_tile = my_grid
	var ideal_dist_px = grid_size * 3.5
	var best_score = 999999.0 

	for dir in directions:
		for distance in range(1, 3):
			var target = my_grid + (dir * distance)
			var target_px = (Vector2(target) * grid_size) + Vector2(grid_size/2, grid_size/2)
			
			if is_tile_blocked(target_px): break 
			
			var d_to_p = target_px.distance_to(player.position)
			var score = abs(d_to_p - ideal_dist_px)
			
			if score < best_score:
				best_score = score
				best_tile = target

	if best_tile != my_grid:
		move_to_tile(best_tile)

func execute_heal_pulse():
	is_moving = true
	var original_color = Color(0.8, 0.2, 0.8)
	#vfx, greeny
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(0, 10, 0), 0.2) 
	await tween.finished
	
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy != self:
			var dist = position.distance_to(enemy.position)
			if dist < grid_size * 6: 
				flash_target_green(enemy)
				if enemy.has_method("apply_healing"):
					enemy.apply_healing(heal_amount)
				else:
					enemy.health = min(enemy.health + heal_amount, 10)

	var reset = create_tween()
	reset.tween_property(self, "modulate", original_color, 0.3)
	await reset.finished
	#when its tired, it goes ghostly, you can change that
	modulate.a = 0.4
	is_moving = false

func flash_target_green(target):
	var old_color = target.modulate
	target.modulate = Color(0, 10, 0)
	#making the others green, kamo na bahala
	get_tree().create_timer(0.2).timeout.connect(func():
		if is_instance_valid(target):
			target.modulate = old_color
	)
#move
func move_to_tile(tile_coords: Vector2i):
	is_moving = true
	target_tile_pos = (Vector2(tile_coords) * grid_size) + Vector2(grid_size/2, grid_size/2)
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "position", target_tile_pos, move_speed)
	await tween.finished
	is_moving = false
	target_tile_pos = Vector2.ZERO

func is_tile_blocked(target_pos: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = RectangleShape2D.new()
	query.shape.size = Vector2(50, 50)
	query.transform = Transform2D(0, target_pos)
	query.collision_mask = 2 | 3 | 4
	return space_state.intersect_shape(query).size() > 0

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
	
	#knockback also take damge
	var kb_target = position + (push_dir * grid_size)
	if not is_tile_blocked(kb_target):
		var tween = create_tween()
		tween.tween_property(self, "position", kb_target, 0.15)
#temp vfx
func flash_damage():
	var old_mod = modulate
	modulate = Color(10, 10, 10)
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(self): modulate = old_mod

func apply_healing(amount: int):
	health += amount
	health = min(health, max_hp)
