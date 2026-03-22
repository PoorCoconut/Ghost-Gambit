extends Label

func _ready():
	var tween = create_tween()
	
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 50, 1.0).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(self, "modulate:a", 0, 1.0)
	
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
