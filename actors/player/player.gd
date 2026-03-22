extends CharacterBody2D

signal moved_one_tile

@export var grid_size: int = 80
@export var move_speed: float = 0.15
@export var max_hp: int = 3

var health: int = max_hp
var is_moving: bool = false
var target_position: Vector2
var last_dir = Vector2.RIGHT

var essence_queue: Array = []
@export var max_queue_size: int = 5
var is_blitz_active: bool = false
var blitz_moves_left: int = 0
var is_shielded: bool = false

func _ready():
	essence_queue.push_back("Rook")
	essence_queue.push_back("Pawn")
	add_to_group("player")
	position = position.snapped(Vector2(grid_size, grid_size)) + Vector2(grid_size/2, grid_size/2)
	target_position = position
	health = max_hp

func _physics_process(_delta):
	if is_moving: return

	if Input.is_action_just_pressed("ui_accept") and essence_queue.size() > 0:
		var skill = essence_queue.pop_front()
		execute_stolen_skill(skill)
		return

	elif Input.is_action_just_pressed("ui_accept"): 
		_on_turn_end()
		return

	var input_dir = Vector2.ZERO
	if Input.is_action_just_pressed("move_right"): input_dir = Vector2.RIGHT
	elif Input.is_action_just_pressed("move_left"): input_dir = Vector2.LEFT
	elif Input.is_action_just_pressed("move_up"): input_dir = Vector2.UP
	elif Input.is_action_just_pressed("move_down"): input_dir = Vector2.DOWN

	if input_dir != Vector2.ZERO:
		last_dir = input_dir
		check_path_and_action(input_dir)

func add_essence_to_queue(type: String):
	if essence_queue.size() < max_queue_size:
		essence_queue.push_back(type)

func execute_stolen_skill(type: String):
	match type:
		"Pawn":
			is_shielded = true
			modulate = Color(2, 2, 2)
		"Knight":
			is_blitz_active = true
			blitz_moves_left = 5
			modulate = Color(0.5, 2, 0.5)
		"Rook":
			modulate = Color(0.5, 0.5, 2)
			execute_fortress_swap(last_dir)
		"Bishop":
			health = min(health + 2, max_hp)
			modulate = Color(0.5, 10, 0.5)
			get_tree().create_timer(0.4).timeout.connect(reset_visuals)
		"Queen":
			modulate = Color(10, 10, 10)
			execute_player_nuke()

func reset_visuals():
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1), 0.3)

func take_damage(amount: int):
	if is_shielded:
		is_shielded = false
		modulate = Color(1, 1, 1)
		return

	health -= amount
	modulate = Color(10, 0, 0)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1), 0.2)
	if health <= 0:
		get_tree().reload_current_scene()

func _on_turn_end():
	is_moving = false
	position = target_position 
	
	if is_blitz_active:
		blitz_moves_left -= 1
		if blitz_moves_left > 0:
			return
		else:
			is_blitz_active = false
			modulate = Color(1, 1, 1)
	
	moved_one_tile.emit()

func check_path_and_action(dir: Vector2):
	var next_tile_pos = position + (dir * grid_size)
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = next_tile_pos
	query.collision_mask = 4 
	var results = space_state.intersect_point(query)
	
	if results.size() > 0:
		var enemy = results[0].collider
		bump_attack(enemy, dir)
		return 

	if test_move(transform, dir * (grid_size - 5)):
		return 

	execute_slide(next_tile_pos)

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
				if is_instance_valid(enemy):
					if enemy.position.distance_to(target_px) < 10:
						if enemy.has_method("receive_knockback"):
							var push_dir = (enemy.position - position).normalized()
							enemy.receive_knockback(push_dir)
							enemy.receive_knockback(push_dir)
							enemy.receive_knockback(push_dir)
							enemy.receive_knockback(push_dir)
							enemy.receive_knockback(push_dir)

	await get_tree().create_timer(0.3).timeout
	is_moving = false
	reset_visuals()

func spawn_nuke_vfx(pos: Vector2):
	var vfx = ColorRect.new()
	vfx.color = Color(1, 1, 1, 0.8)
	vfx.size = Vector2(grid_size - 10, grid_size - 10)
	vfx.position = pos - Vector2((grid_size-10)/2, (grid_size-10)/2)
	get_parent().add_child(vfx)
	
	var t = create_tween().set_parallel(true)
	t.tween_property(vfx, "modulate", Color(1, 0, 0, 0), 0.4)
	t.tween_property(vfx, "scale", Vector2(2, 2), 0.4)
	t.set_trans(Tween.TRANS_QUART)
	t.chain().tween_callback(vfx.queue_free)
func execute_fortress_swap(dash_dir: Vector2):
	modulate = Color(0.5, 0.5, 2) 
	var start_pos = position
	var current_test_pos = position
	var can_move_further = true
	var hit_enemy = null # Track if we stopped because of a specific enemy

	while can_move_further:
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
			# Check if the thing we hit is on the Enemy Layer (Layer 3 / Mask 4)
			for res in results:
				if res.collider.collision_layer & 4:
					hit_enemy = res.collider
			
			can_move_further = false 
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
		
		# --- BUMP DAMAGE LOGIC ---
		if hit_enemy and is_instance_valid(hit_enemy):
			if hit_enemy.has_method("receive_knockback"):
				# Since the Rook is heavy, let's give it a strong knockback
				hit_enemy.receive_knockback(dash_dir)
				# If your enemies have a take_damage method, call it here too:
				# hit_enemy.take_damage(1) 
		
		_on_skill_finished()
		reset_visuals()
	else:
		reset_visuals()
		

func _on_skill_finished():
	is_moving = false
	position = target_position
