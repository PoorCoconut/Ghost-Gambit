extends CanvasLayer

@onready var WhiteBar = %WhiteBarTexture
@onready var BarChaser = %BarChaserTexture
@onready var AbilitySlot = %AbilitySlot
@onready var AbilityIcon = %AbilityIcon
var style 

func _ready():
	# Listen for the signal and connect it to a local function
	Events.player_hp_updated.connect(_on_player_hp_updated)

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
