extends CharacterBody2D

@export var grid_size: int = 80
@export var move_speed: float = 0.2
@export var max_hp: int = 3
@export var health: int
@export var enemy_type: String = "Pawn"

var astar = AStarGrid2D.new()
var is_moving: bool = false
var is_charging: bool = false 
var player: CharacterBody2D
var target_tile_pos: Vector2 = Vector2.ZERO

func _ready():
	health = max_hp
	add_to_group("enemies") 
	#remove once you get the look
	modulate = Color(1, 0, 0)
	#this is just centering it
	position = position.snapped(Vector2(grid_size, grid_size)) + Vector2(grid_size/2, grid_size/2)
	setup_astar_map()
	
	player = get_tree().get_first_node_in_group("player")
	if player and player.has_signal("moved_one_tile"):
		player.moved_one_tile.connect(_on_player_turn_finished)
#idk whats this but it works
func setup_astar_map():
	astar.region = Rect2i(-100, -100, 400, 400)
	astar.cell_size = Vector2(grid_size, grid_size)
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	
	var map = get_tree().current_scene.find_child("TileMapLayer", true, false)
	if map:
		for cell in map.get_used_cells():
			var data = map.get_cell_tile_data(cell)
			if data and data.get_collision_polygons_count(0) > 0:
				astar.set_point_solid(cell, true)

func _on_player_turn_finished():
	if not is_moving and is_instance_valid(self):
		var turn_delay = (get_instance_id() % 20) * 0.04
		await get_tree().create_timer(0.05 + turn_delay).timeout
		pathfind_to_player()

func pathfind_to_player():
	var start_tile = Vector2i(position / grid_size)
	var end_tile = Vector2i(player.position / grid_size)
	var diff = (end_tile - start_tile).abs()
	
	if diff.x <= 1 and diff.y <= 1:
		if not is_charging:
			is_charging = true
			modulate = Color(5, 5, 0)
		else:
			attack_player()
		return
	
	if is_charging:
		attack_player()
		return

	var path = astar.get_id_path(start_tile, end_tile)
	if path.size() > 1:
		var next_pos = (Vector2(path[1]) * grid_size) + Vector2(grid_size/2, grid_size/2)
		if is_tile_blocked(next_pos): return 
		move_to_tile(path[1])
#attack
func attack_player():
	is_moving = true
	is_charging = false
	
	var dir_to_target = (player.position - position).normalized()
	var original_pos = position
	var tween = create_tween()
	
	tween.tween_property(self, "position", position + (dir_to_target * 60), 0.08)
	tween.tween_property(self, "position", original_pos, 0.15)
	
	check_for_hit_at_pos(position + (dir_to_target * grid_size))
	
	modulate = Color(1, 0, 0)
	await tween.finished
	is_moving = false
#hit player
func check_for_hit_at_pos(hit_pos: Vector2):
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var hit_box = RectangleShape2D.new()
	hit_box.size = Vector2(grid_size * 0.7, grid_size * 0.7)
	query.shape = hit_box
	query.transform = Transform2D(0, hit_pos)
	query.collision_mask = 1 
	
	var results = space_state.intersect_shape(query)
	for res in results:
		if res.collider == player:
			player.take_damage(1)

#take damage HAHAHAHHA
func receive_knockback(push_dir: Vector2):
	# 1. Check Shield Negation first
	if randf() < 0.25:
		play_shield_vfx()
		return 

	is_charging = false
	modulate = Color(1, 0, 0)
	health -= 1
	flash_damage()
	
	if health <= 0:
		var p = get_tree().get_first_node_in_group("player")
		if is_instance_valid(p) and p.has_method("add_essence_to_queue"):
			p.add_essence_to_queue(enemy_type)
		
		queue_free()
		return
		
	if test_move(transform, push_dir * (grid_size - 5)): return
	
	is_moving = true
	var kb_target = position + (push_dir * grid_size)
	var tween = create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", kb_target, 0.15)
	await tween.finished
	is_moving = false
#shield
func play_shield_vfx():
	var tween = create_tween().set_parallel(false)
	var old_mod = modulate
	# Flash Cyan/Blue to indicate shield block
	modulate = Color(0, 5, 10) 
	await get_tree().create_timer(0.5).timeout
	modulate = Color(1, 0, 0)
	await tween.finished
	modulate = old_mod
#check nothing much
func is_tile_blocked(target_pos: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var sensor = RectangleShape2D.new()
	sensor.size = Vector2(70, 70)
	query.shape = sensor
	query.transform = Transform2D(0, target_pos)
	query.collision_mask = 2 | 4 
	var results = space_state.intersect_shape(query)
	for res in results:
		if res.collider != self: return true
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy != self:
			if enemy.target_tile_pos.distance_to(target_pos) < 5: return true
	return false
#move
func move_to_tile(tile_coords: Vector2i):
	is_moving = true
	target_tile_pos = (Vector2(tile_coords) * grid_size) + Vector2(grid_size/2, grid_size/2)
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", target_tile_pos, move_speed)
	await tween.finished
	is_moving = false
	target_tile_pos = Vector2.ZERO
#take damage
func flash_damage():
	var old_mod = modulate
	modulate = Color(10, 10, 10)
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(self): modulate = old_mod
#heal
func apply_healing(amount: int):
	health += amount
	health = min(health, max_hp)
