extends Control

@export_file("*.tscn") var main_menu_path : String
#GameManager.load_next_level(main_menu_path)

func _ready() -> void:
	MusicManager.change_music("mainmenu_theme", 0.5)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		GameManager.load_next_level(main_menu_path)

func _on_scroll_menu_animation_finished(_anim_name: StringName) -> void:
	GameManager.load_next_level(main_menu_path)
