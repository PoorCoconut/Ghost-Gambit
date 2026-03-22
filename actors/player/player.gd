extends CharacterBody2D

signal moved_one_tile

@export var grid_size: int = 80
@export var move_speed: float = 0.15
@export var max_hp: int = 10
var icon_pawn: Texture2D = preload("res://game_assets/HUD_Assets/Ability_icons/pawn.png")
var icon_knight: Texture2D = preload("res://game_assets/HUD_Assets/Ability_icons/knight.png")
var icon_rook: Texture2D = preload("res://game_assets/HUD_Assets/Ability_icons/Rook.png")
var icon_bishop: Texture2D = preload("res://game_assets/HUD_Assets/Ability_icons/bishop.png")
var icon_queen: Texture2D = preload("res://game_assets/HUD_Assets/Ability_icons/queen.png")

var health: int = max_hp
var is_moving: bool = false
var is_turn_processing: bool = false
var target_position: Vector2
var last_dir = Vector2.RIGHT

var essence_queue: Array = []
@export var max_queue_size: int = 5
var is_blitz_active: bool = false
var blitz_moves_left: int = 0
var is_shielded: bool = false

@onready var sprite:Sprite2D = $Sprite

func _ready():
	add_to_group("player")
	position = position.snapped(Vector2(grid_size, grid_size)) + Vector2(grid_size/2, grid_size/2)
	target_position = position
	health = max_hp
	Events.player_hp_updated.emit(health, max_hp)

func _physics_process(_delta):
	if is_moving or is_turn_processing: return

	if Input.is_action_just_pressed("ui_accept") and essence_queue.size() > 0:
		var skill = essence_queue.pop_front()
		execute_stolen_skill(skill)
		return

	var input_dir = Vector2.ZERO
	if Input.is_action_pressed("move_right"): input_dir = Vector2.RIGHT
	elif Input.is_action_pressed("move_left"): input_dir = Vector2.LEFT
	elif Input.is_action_pressed("move_up"): input_dir = Vector2.UP
	elif Input.is_action_pressed("move_down"): input_dir = Vector2.DOWN
	
	if input_dir == Vector2.LEFT and !sprite.flip_h:
		sprite.flip_h = true
	elif input_dir == Vector2.RIGHT and sprite.flip_h:
		sprite.flip_h = false

	if input_dir != Vector2.ZERO:
		last_dir = input_dir
		check_path_and_action(input_dir)
#maybe add special effect when you get essesnce, like sound or somthing
func get_icon_for_type(type: String) -> Texture2D:
	match type:
		"Pawn":   return icon_pawn
		"Knight": return icon_knight
		"Rook":   return icon_rook
		"Bishop": return icon_bishop
		"Queen":  return icon_queen
	return null

func add_essence_to_queue(type: String):
	if essence_queue.size() >= max_queue_size:
		return
		
	if essence_queue.has(type):
		return 
	essence_queue.push_back(type)
	
	Events.ability_stolen.emit({
		"type":type,
		"icon":get_icon_for_type(type)
	})
#using skills
func execute_stolen_skill(type: String):
	Events.ability_used.emit()
	match type:
		"Pawn":
			is_shielded = true
			modulate = Color(2, 2, 2)
		"Knight":
			is_blitz_active = true
			blitz_moves_left = 5
			modulate = Color(0.5, 2, 0.5)
		"Rook":
			execute_fortress_swap(last_dir)
		"Bishop":
			health = max_hp
			Events.player_hp_updated.emit(health,max_hp)
			modulate = Color(0.5, 10, 0.5)
			get_tree().create_timer(0.4).timeout.connect(reset_visuals)
		"Queen":
			execute_player_nuke()
#this is sending signal to rest
func _on_turn_end():
	is_moving = false
	is_turn_processing = true
	position = target_position 
	
	# --- PORTAL CHECK ---
	var portal_map = get_layer("portal")
	if portal_map:
		var current_tile = portal_map.local_to_map(global_position)
		GameManager.check_for_exit(current_tile, portal_map)
	
	if is_blitz_active:
		blitz_moves_left -= 1
		if blitz_moves_left > 0:
			is_turn_processing = false 
			return
		else:
			is_blitz_active = false
			modulate = Color(1, 1, 1)
	
	moved_one_tile.emit()
	
	await get_tree().create_timer(0.1).timeout
	is_turn_processing = false
#pathing
func get_layer(group_name: String) -> TileMapLayer:
	return get_tree().get_first_node_in_group(group_name) as TileMapLayer

func check_path_and_action(dir: Vector2):
	var lock_map = get_layer("lock")
	if not lock_map: return
	var current_tile = lock_map.local_to_map(global_position)
	var target_tile = current_tile + Vector2i(dir.x, dir.y)
	
	# --- LOCK CHECK ---
	if not GameManager.can_move_to_tile(target_tile, lock_map):
		return

	var next_tile_pos = position + (dir * grid_size)
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = next_tile_pos
	query.collision_mask = 4 
	var results = space_state.intersect_point(query)
	
	if results.size() > 0:
		bump_attack(results[0].collider, dir)
		return 

	if test_move(transform, dir * (grid_size - 5)):
		return 

	# 4. ALL CLEAR: Proceed to slide
	execute_slide(next_tile_pos)
#attack
func bump_attack(enemy, dir):
	is_moving = true
	var tween = create_tween()
	tween.tween_property(self, "position", position + (dir * 25), 0.05)
	tween.tween_property(self, "position", position, 0.05)
	if enemy.has_method("receive_knockback"):
		enemy.receive_knockback(dir)
	await tween.finished
	_on_turn_end()

func execute_slide(next_pos):
	is_moving = true
	target_position = next_pos
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", target_position, move_speed)
	await tween.finished
	_on_turn_end()
#im bout to bust
func execute_player_nuke():
	is_moving = true
	modulate = Color(20, 20, 20)
	var my_grid_pos = Vector2i((position / grid_size).floor())
	
	for x in range(-2, 3):
		for y in range(-2, 3):
			var target_grid = my_grid_pos + Vector2i(x, y)
			var target_px = (Vector2(target_grid) * grid_size) + Vector2(grid_size/2, grid_size/2)
			spawn_nuke_vfx(target_px)
			
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(enemy) and enemy.position.distance_to(target_px) < 10:
					if enemy.has_method("receive_knockback"):
						var push_dir = (enemy.position - position).normalized()
						enemy.receive_knockback(push_dir)

	await get_tree().create_timer(0.3).timeout
	reset_visuals()
	_on_turn_end()
#crystal dash, kamo na bahala vfx oi
func execute_fortress_swap(dash_dir: Vector2):
	modulate = Color(0.5, 0.5, 2) 
	var start_pos = position
	var current_test_pos = position
	var hit_enemy = null

	while true:
		var danger_zone = current_test_pos + (dash_dir * grid_size * 2)
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsShapeQueryParameters2D.new()
		var scan_shape = RectangleShape2D.new()
		scan_shape.size = Vector2(grid_size - 4, grid_size - 4)
		query.shape = scan_shape
		query.transform = Transform2D(0, danger_zone)
		query.collision_mask = 6 
		
		var results = space_state.intersect_shape(query)
		if results.size() > 0:
			for res in results:
				if res.collider.collision_layer & 4:
					hit_enemy = res.collider
			break
			
		current_test_pos += (dash_dir * grid_size)
		if current_test_pos.length() > 5000: break 

	if current_test_pos != start_pos:
		is_moving = true
		target_position = current_test_pos 
		var tween = create_tween().set_trans(Tween.TRANS_LINEAR)
		var dist = start_pos.distance_to(current_test_pos)
		var duration = clamp(dist / 800.0, 0.4, 1.5) 
		tween.tween_property(self, "position", current_test_pos, duration)
		await tween.finished
		
		if hit_enemy and is_instance_valid(hit_enemy):
			if hit_enemy.has_method("receive_knockback"):
				hit_enemy.receive_knockback(dash_dir)
		
		reset_visuals()
		_on_turn_end()
	else:
		reset_visuals()
#Busting VFX
func spawn_nuke_vfx(pos: Vector2):
	var vfx = ColorRect.new()
	vfx.color = Color(1, 1, 1, 0.8)
	vfx.size = Vector2(grid_size - 10, grid_size - 10)
	vfx.position = pos - Vector2((grid_size-10)/2, (grid_size-10)/2)
	get_parent().add_child(vfx)
	var t = create_tween().set_parallel(true)
	t.tween_property(vfx, "modulate", Color(1, 0, 0, 0), 0.4)
	t.tween_property(vfx, "scale", Vector2(2, 2), 0.4)
	t.chain().tween_callback(vfx.queue_free)

func reset_visuals():
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1), 0.3)
#damages
func take_damage(amount: int):
	if is_shielded:
		is_shielded = false
		modulate = Color(1, 1, 1)
		return
	health -= amount
	modulate = Color(10, 0, 0)
	create_tween().tween_property(self, "modulate", Color(1, 1, 1), 0.2)
	Events.player_hp_updated.emit(health, max_hp)
	if health <= 0:
		get_tree().reload_current_scene()

#func try_move(direction: Vector2i):
	#var target_tile = current_tile + direction   
	## 1. LOCK CHECK
	#if GameManager.can_move_to_tile(target_tile, wall_tilemap_layer):
		## Execute the move
		#current_tile = target_tile
		#global_position = wall_tilemap_layer.map_to_local(current_tile)
		## 2. PORTAL CHECK
		## We check the 'Floor' or 'Props' layer for next_level_path data
		#GameManager.check_for_exit(current_tile, floor_tilemap_layer)
