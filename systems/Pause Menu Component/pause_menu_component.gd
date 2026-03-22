extends CanvasLayer

@onready var vol_master_slider: HSlider = %VolMasterSlider 
@onready var vol_music_slider: HSlider = %VolMusicSlider
@onready var vol_sfx_slider: HSlider = %VolSFXSlider

@onready var button_menu: Button = %MenuButton
@onready var button_back: Button = %BackButton

@onready var background : TextureRect = $Background
@onready var pause_menu : Control = $PauseMenu

@export_file("*.tscn") var menu_path : String = "res://game_scenes/menus/MainMenu/main_menu.tscn"

# --- AUDIO MUFFLE VARIABLES ---
var music_bus_idx : int
var low_pass_filter : AudioEffectLowPassFilter
var muffle_tween : Tween

func _ready() -> void:
	pause_menu.hide()
	vol_master_slider.value = SettingsManager.master_vol
	vol_music_slider.value = SettingsManager.music_vol
	vol_sfx_slider.value = SettingsManager.sfx_vol
	
	# Grab the exact bus and the filter effect (Index 0) so we can tween it!
	music_bus_idx = AudioServer.get_bus_index("Music")
	low_pass_filter = AudioServer.get_bus_effect(music_bus_idx, 0)

##TOGGLE MENU
func _unhandled_input(event: InputEvent) -> void:
	## In this commented out code, you can change it so that when something happens, pressing pause doesn't pause the game
	#if GameManager.CURRENT_WORLD_STATE == "SOMETHING":
		#return
	
	if event.is_action_pressed("ui_cancel"): 
		if get_tree().paused:
			hide_menu()
		else:
			show_menu()

func show_menu() -> void:
	
	get_tree().paused = true 
	
	# 1. Enable the filter and start it at the maximum "normal" frequency
	AudioServer.set_bus_effect_enabled(music_bus_idx, 0, true)
	low_pass_filter.cutoff_hz = 20500.0
	
	# 2. Smoothly sweep the frequency down to a muffled 1500 Hz
	if muffle_tween and muffle_tween.is_valid(): muffle_tween.kill()
	muffle_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	muffle_tween.tween_property(low_pass_filter, "cutoff_hz", 1500.0, 0.4)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
	pause_menu.show()
	trans_in(0.5)

func hide_menu() -> void:
	pause_menu.hide()
	trans_out(0.5)
	get_tree().paused = false 
	
	# 1. Smoothly sweep the frequency back up to 20500 Hz
	if muffle_tween and muffle_tween.is_valid(): muffle_tween.kill()
	muffle_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	muffle_tween.tween_property(low_pass_filter, "cutoff_hz", 20500.0, 0.3)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		
	# 2. When the sweep finishes, turn the effect completely off to save CPU
	muffle_tween.tween_callback(func(): AudioServer.set_bus_effect_enabled(music_bus_idx, 0, false))

##ADUIO SLIDERS
func _on_vol_master_slider_value_changed(value: float) -> void:
	SettingsManager.master_vol = value
	SettingsManager.save_settings()

func _on_vol_music_slider_value_changed(value: float) -> void:
	SettingsManager.music_vol = value
	SettingsManager.save_settings()

func _on_vol_sfx_slider_value_changed(value: float) -> void:
	SettingsManager.sfx_vol = value
	SettingsManager.save_settings()

##NAV BUTTONS AND SAVING
func _on_menu_button_pressed() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		GameManager.save_player_position(player.global_position)
	
	# THE FIX: Instantly snap the audio back to normal before the level gets deleted!
	if muffle_tween and muffle_tween.is_valid(): 
		muffle_tween.kill()
	low_pass_filter.cutoff_hz = 20500.0
	AudioServer.set_bus_effect_enabled(music_bus_idx, 0, false)
	
	get_tree().paused = false
	LoadingScreen.load_level(menu_path)

func _on_back_button_pressed() -> void:
	hide_menu()

func trans_in(trans_time : float = 1) -> Tween:
	var tween = get_tree().create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(background.material, "shader_parameter/progress", 0.5, trans_time).from(0.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return tween

func trans_out(trans_time : float = 1) -> Tween:
	var tween = get_tree().create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(background.material, "shader_parameter/progress", 1.0, trans_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return tween

func reset() -> void:
	background.material.set_shader_parameter("progress", 0.0)
