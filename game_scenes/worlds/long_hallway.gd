extends Node2D
@export_file("*.tscn") var next_level_path : String
@export_file("*.tscn") var boss_level_path : String
@onready var hint : RichTextLabel = $BossLockHint
func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		GameManager.load_next_level(next_level_path)

func _on_boss_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if GameManager.collected_keys.get("Attic_Key") == true:
			print("player has a key")
			MusicManager.change_music("boss_theme")
			GameManager.load_next_level(boss_level_path)
		else:
			print("player does not have a key")
			hint.show()

func _on_boss_area_2d_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		hint.hide()
