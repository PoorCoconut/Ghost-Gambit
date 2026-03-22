extends CanvasLayer

@onready var WhiteBar = %WhiteBarTexture
@onready var BarChaser = %BarChaserTexture
@onready var AbilitySlot = %AbilitySlot
@onready var AbilityIcon = %AbilityIcon
var style 
var stolenabilities: Array = []

func _ready():
	# Listen for the signal and connect it to a local function
	Events.player_hp_updated.connect(_on_player_hp_updated)
	Events.ability_stolen.connect(_on_ability_stolen)
	Events.ability_used.connect(_on_ability_used)

# This runs automatically whenever the Player emits the signal
func _on_player_hp_updated(current_hp: float, max_hp: float):
	WhiteBar.max_value = max_hp
	WhiteBar.value = current_hp
	
	BarChaser.modulate = Color.GREEN.lerp(Color.RED, current_hp / max_hp)
	var tween = create_tween()
	tween.tween_property(BarChaser, "value", WhiteBar.value, 0.5).set_trans(Tween.TRANS_SINE)

	if BarChaser.value < 3:
		BarChaser.value = 0

	if WhiteBar.value < 25:
		var tween2 = create_tween()
		tween2.tween_property($BarContainer, "modulate:a", 0.5, 0.5)
	else:
		var tween3 = create_tween()
		tween3.tween_property($BarContainer, "modulate:a", 1, 0.5)
		
func _on_ability_stolen(ability_data):
	print("ability stolen: ", ability_data)
	stolenabilities.push_back(ability_data)
	_update_ability_display()
	
func _on_ability_used():
	if(stolenabilities.size() > 0):
		stolenabilities.pop_back()
	_update_ability_display()
	
func _update_ability_display():
	if stolenabilities.is_empty():
		AbilityIcon.texture = null
		AbilitySlot.visible = false
		return
	var top = stolenabilities.back()
	AbilityIcon.texture = top.get("icon", null)
	AbilitySlot.visible = true

func _animate_slot_pop():
	AbilitySlot.scale = Vector2(1.2, 1.2)
	var tween = create_tween()
	tween.tween_property(AbilitySlot, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BOUNCE)
