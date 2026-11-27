extends Control
@onready var _game = $"../../.."
var popup = "placeholder"

@onready var style_label = $StyleLabel
@onready var popup_label = $PopupLbael
@onready var rank_label = $RankLabel
@onready var bounce_label = $BounceLabel
var bounces = 0

func _ready() -> void:
	_game.style_changed.connect(refresh)
	_game.style_popup.connect(update)
	$"../../../../Player/SpiritAbility/SpiritBall".finished.connect(end_combo)
	$"../../../../Player/SpiritAbility/SpiritBall".enemy_hit.connect(add_combo)
	style_label.text = "STYLE: "+_game.stat_text(3)

func add_combo(y,x)->void: #oh my god bruh theres already a variable named kills_this_bounce
	_game.style_mult+=_game.base_style_mult
	bounces += 1
	bounce_label.text = "(%d)" % bounces
	refresh()
	
func end_combo()->void:
	_game.style_mult = 0.0
	bounces = 0
	refresh()

func refresh()->void:
	style_label.text = "STYLE: "+_game.stat_text(3)
	rank_label.text = calculate()
	
func calculate()->String:
	if bounces >= 70:
		rank_label.label_settings.font_color = Color.RED
		return "SSS"
	if bounces >= 50:
		rank_label.label_settings.font_color = Color.FIREBRICK
		return "SS"
	if bounces >= 20:
		rank_label.label_settings.font_color = Color.WEB_MAROON
		return "S"
	if bounces >= 10:
		rank_label.label_settings.font_color = Color.ORANGE_RED
		return "A"
	if bounces >= 05:
		rank_label.label_settings.font_color = Color.ORANGE_RED
		return "B"
	if bounces >= 03:
		rank_label.label_settings.font_color = Color.YELLOW
		return "C"
	if bounces >= 02:
		rank_label.label_settings.font_color = Color.GREEN
		return "D"
	rank_label.label_settings.font_color = Color.BLUE
	return "F"
	
func update(text:String) -> void:
	popup_label.text = text
	popup_label.pivot_offset = popup_label.size/2
	var tween=create_tween().set_parallel(true)
	popup_label.scale = Vector2(1.105,1.105)
	popup_label.rotation = 0.18
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(popup_label, "scale", Vector2(0.824, 0.824),0.2)
	tween.tween_property(popup_label, "rotation", 0.0,0.2)
	
	
