extends CharacterBody2D

@export var grid_size: int = 80
@export var move_speed: float = 0.1 
@export var health: int = 6
@export var enemy_type: String = "Queen"
enum State { HUNTING, WINDING, DASHING, COOLDOWN, DYING }
var current_state = State.HUNTING
var locked_direction: Vector2i = Vector2i.ZERO
var target_tile_pos: Vector2 = Vector2.ZERO
var player: CharacterBody2D
var is_moving: bool = false
var death_countdown: int = 4

@onready var sprite:Sprite2D = $Sprite

func _ready():
	add_to_group("enemies")
	modulate = Color(0.1, 0.1, 0.1)
	position = (Vector2i(position / grid_size) * grid_size) + Vector2i(grid_size/2, grid_size/2)
	sprite.frame = 0
	
	player = get_tree().get_first_node_in_group("player")
	if player and player.has_signal("moved_one_tile"):
		player.moved_one_tile.connect(_on_player_turn_finished)

func _on_player_turn_finished():
	if not is_instance_valid(self) or is_moving: return
	
	await get_tree().create_timer(0.05).timeout 
	
	match current_state:
		State.DYING:
			sprite.frame = 0
			process_death_countdown()
		State.HUNTING:
			sprite.frame = 1
			process_queen_logic()
		State.WINDING:
			sprite.frame = 1
			execute_queen_dash()
		State.COOLDOWN:
			sprite.frame = 0
			current_state = State.HUNTING
			modulate = Color(0.1, 0.1, 0.1)

func process_death_countdown():
	death_countdown -= 1
	if death_countdown == 1:
		modulate = Color(10, 0, 0)
	elif death_countdown <= 0:
		execute_final_explosion()
#im bout to bust
func execute_final_explosion():
	if not is_inside_tree(): return
	is_moving = true
	modulate = Color(20, 20, 20)
	
	var my_grid_pos = Vector2i((position / grid_size).floor())
	
	for x in range(-2, 3):
		for y in range(-2, 3):
			var target_grid = my_grid_pos + Vector2i(x, y)
			var target_px = (Vector2(target_grid) * grid_size) + Vector2(grid_size/2, grid_size/2)
			
			if is_tile_blocked_by_wall(target_px):
				continue
				
			spawn_explosion_vfx(target_px)
			
			if target_px.distance_to(player.position) < 45:
				if player.has_method("take_damage"):
					player.take_damage(3) 

	visible = false 
	if is_inside_tree():
		await get_tree().create_timer(0.5).timeout
	
	queue_free()
#Bust vfs
func spawn_explosion_vfx(pos: Vector2):
	var vfx = ColorRect.new()
	vfx.color = Color(1, 0.2, 0, 0.8)
	vfx.size = Vector2(grid_size - 4, grid_size - 4)
	vfx.position = pos - Vector2((grid_size-4)/2, (grid_size-4)/2)
	get_parent().add_child(vfx)
	
	var t = create_tween().set_parallel(true)
	t.tween_property(vfx, "modulate:a", 0.0, 0.5)
	t.tween_property(vfx, "scale", Vector2(3, 3), 0.3)
	t.chain().tween_callback(vfx.queue_free)

func process_queen_logic():
	var my_grid = Vector2i((position / grid_size).floor())
	var p_grid = Vector2i((player.position / grid_size).floor())
	var diff = p_grid - my_grid
	
	var is_aligned = (diff.x == 0 or diff.y == 0 or abs(diff.x) == abs(diff.y))
	
	if is_aligned and diff != Vector2i.ZERO:
		locked_direction = Vector2i(sign(diff.x), sign(diff.y))
		current_state = State.WINDING
		#telegraph
		modulate = Color(5, 5, 0)
	else:
		var move_dir = Vector2i.ZERO
		if abs(diff.x) > abs(diff.y): move_dir.x = sign(diff.x)
		else: move_dir.y = sign(diff.y)
			
		var step_target = position + (Vector2(move_dir) * grid_size)
		if not is_tile_blocked(step_target):
			perform_simple_step(step_target)
#dashieeee
func execute_queen_dash():
	current_state = State.DASHING
	var my_grid = Vector2i((position / grid_size).floor())
	var p_grid = Vector2i((player.position / grid_size).floor())
	
	var final_grid = my_grid
	for i in range(1, 16):
		var check_grid = my_grid + (locked_direction * i)
		var check_px = (Vector2(check_grid) * grid_size) + Vector2(grid_size/2, grid_size/2)
		
		if is_tile_blocked_by_wall(check_px): break
		if check_grid == p_grid: break
		final_grid = check_grid

	var final_pos = (Vector2(final_grid) * grid_size) + Vector2(grid_size/2, grid_size/2)

	if final_pos.distance_to(position) > 5:
		is_moving = true
		var tween = create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "position", final_pos, move_speed)
		await tween.finished
		is_moving = false
	
	_apply_queen_damage(Vector2(locked_direction))
	_end_dash_cycle()
#just hit player type shi
func _apply_queen_damage(dir_vec: Vector2):
	if not is_inside_tree(): return
	var attack_target_px = position + (dir_vec.normalized() * grid_size)
	
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var box = RectangleShape2D.new()
	box.size = Vector2(grid_size * 0.8, grid_size * 0.8)
	query.shape = box
	query.transform = Transform2D(0, attack_target_px)
	query.collision_mask = 1
	
	var hits = space_state.intersect_shape(query)
	for hit in hits:
		if hit.collider == player:
			player.take_damage(2)
			var bump = create_tween()
			bump.tween_property(self, "position", position + (dir_vec * 25), 0.05)
			bump.tween_property(self, "position", position, 0.05)
#helper
func is_tile_blocked_by_wall(target_pos: Vector2) -> bool:
	if not is_inside_tree(): return false
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = RectangleShape2D.new()
	query.shape.size = Vector2(40, 40)
	query.transform = Transform2D(0, target_pos)
	query.collision_mask = 2
	return space_state.intersect_shape(query).size() > 0

func is_tile_blocked(target_pos: Vector2) -> bool:
	if is_tile_blocked_by_wall(target_pos): return true
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy != self:
			if enemy.position.distance_to(target_pos) < 5: return true
	return false
#its jsut 1 step
func perform_simple_step(target: Vector2):
	is_moving = true
	var tween = create_tween()
	tween.tween_property(self, "position", target, 0.15)
	await tween.finished
	is_moving = false

#take damage
func receive_knockback(_push_dir: Vector2):
	if current_state == State.DYING: return
	
	health -= 1
	flash_damage()
	
	if health <= 0:
		var p = get_tree().get_first_node_in_group("player")
		if is_instance_valid(p) and p.has_method("add_essence_to_queue"):
			p.add_essence_to_queue(enemy_type)
		
		current_state = State.DYING
		#she go booom boom
		modulate = Color(2, 0, 0)
#damage effects
func flash_damage():
	if not is_inside_tree(): return
	var old_mod = modulate
	modulate = Color(2, 2, 2)
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(self): modulate = old_mod

func _end_dash_cycle():
	current_state = State.COOLDOWN
	locked_direction = Vector2i.ZERO
	modulate = Color(0.2, 0.2, 0.2)
