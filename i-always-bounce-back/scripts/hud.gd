# CODE FOR CAMERA, SOME 3D MODELS SUCH AS BAT, CAMERA CODE: GDquest
# 3D MODELS: SKETCHFAB
# BOUNCING BALL / CHARGING AND PARTICLES: Kenny.nl AND GodotAcademy.io

extends CanvasLayer

@export var hurt_fade := 2.5
@export var low_charge_color := Color(0.25, 0.6, 1.0)
@export var full_charge_color := Color(0.75, 0.95, 1.0)

var _game: Node
var _ability: Node
var _hurt := 0.0
var _fade := 0.0
var _fading := false

@onready var wave_label: Label = $Root/WaveLabel
@onready var enemies_label: Label = $Root/EnemiesLabel
@onready var notice: Label = $Root/Notice
@onready var hint: Label = $Root/Hint
@onready var health_bar: TextureProgressBar = $Root/BottomLeft/HealthBar
@onready var health_text: Label = $Root/BottomLeft/HealthText
@onready var charge_bar: ProgressBar = $Root/BottomLeft/ChargeBar
@onready var speed_label: Label = $Root/BottomLeft/StatSpeed/Value
@onready var force_label: Label = $Root/BottomLeft/StatForce/Value
@onready var damage_label: Label = $Root/BottomLeft/StatDamage/Value
@onready var kills_label: Label = $Root/BottomLeft/KillsLabel
@onready var points_label: Label = $Root/BottomLeft/PointsLabel
@onready var hurt_rect: ColorRect = $Root/Hurt
@onready var fade_rect: ColorRect = $Root/Fade


func _ready() -> void:
	_game = get_parent()
	_game.health_changed.connect(_on_health_changed)
	_game.wave_changed.connect(_on_wave_changed)
	_game.enemies_changed.connect(_on_enemies_changed)
	_game.points_changed.connect(_on_points_changed)
	_game.kills_changed.connect(_on_kills_changed)
	_game.stats_changed.connect(_on_stats_changed)
	_game.intermission_changed.connect(_on_intermission_changed)
	_game.player_hurt.connect(_on_player_hurt)
	_game.game_over_started.connect(_on_game_over)
	_game.shop_toggled.connect(_on_shop_toggled)
	wave_label.text = "GET READY"
	enemies_label.text = ""
	notice.text = ""
	hint.visible = false
	hurt_rect.color.a = 0.0
	fade_rect.color.a = 0.0


func _process(delta: float) -> void:
	var real := delta / maxf(Engine.time_scale, 0.05)
	if _ability == null:
		_ability = _game.ability()
	var level: float = _ability.level
	charge_bar.value = level * 100.0
	var fill := charge_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill:
		fill.bg_color = low_charge_color.lerp(full_charge_color, level)
	hint.visible = _ability.relaunch_ready and _ability.is_ball() and not _ability.is_charging()
	_hurt = maxf(_hurt - hurt_fade * real, 0.0)
	hurt_rect.color.a = _hurt * 0.45
	if _fading:
		_fade = minf(_fade + real / maxf(_game.fade_time, 0.1), 1.0)
		fade_rect.color.a = _fade


func _on_health_changed(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_text.text = "%d / %d" % [int(ceil(current)), int(maximum)]


func _on_wave_changed(number: int) -> void:
	if number > 0:
		wave_label.text = "WAVE %d" % number


func _on_enemies_changed(remaining: int) -> void:
	enemies_label.text = "Enemies left, %d" % remaining


func _on_points_changed(total: int) -> void:
	points_label.text = "PTS %d" % total


func _on_kills_changed(total: int) -> void:
	kills_label.text = str(total)


func _on_stats_changed() -> void:
	speed_label.text = "LV %d" % int(_game.levels[_game.Stat.SPEED])
	force_label.text = "LV %d" % int(_game.levels[_game.Stat.FORCE])
	damage_label.text = "LV %d" % int(_game.levels[_game.Stat.DAMAGE])


func _on_intermission_changed(seconds_left: float, active: bool) -> void:
	if not active:
		notice.text = "" if _game.wave > 0 else "First wave in %d" % int(ceil(seconds_left))
		return
	notice.text = "Next wave in %d  -  Press B for shop" % int(ceil(seconds_left))


func _on_shop_toggled(open: bool) -> void:
	$Root.visible = not open


func _on_player_hurt() -> void:
	_hurt = 1.0


func _on_game_over() -> void:
	_fading = true
	notice.text = "YOU DIED"
