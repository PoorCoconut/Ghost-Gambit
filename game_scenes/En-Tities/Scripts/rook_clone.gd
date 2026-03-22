extends CharacterBody2D

@export var grid_size: int = 80
@export var health: int = 3

func _ready():
	add_to_group("enemies")
	
	modulate = Color(0.4, 0.4, 0.4)
	
	position = (Vector2i(position / grid_size) * grid_size) + Vector2i(grid_size/2, grid_size/2)

func receive_knockback(_push_dir: Vector2):
	health -= 1
	flash_damage()
	
	if health <= 0:
		queue_free()

func flash_damage():
	var old_mod = modulate
	modulate = Color(10, 10, 10)
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(self):
		modulate = old_mod

func get_grid_pos() -> Vector2i:
	return Vector2i(position / grid_size)
