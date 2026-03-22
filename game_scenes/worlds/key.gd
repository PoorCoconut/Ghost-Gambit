extends Sprite2D

@export var key_id: String = ""

func _on_body_entered(body):
	if body.is_in_group("player"):
		GameManager.collect_key(key_id)
		queue_free()
