extends Node2D
@export_file("*.tscn") var credits_level_path : String

func _ready() -> void:
	MusicManager.change_music("boss_theme")

func _on_credits_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		GameManager.load_next_level(credits_level_path)
