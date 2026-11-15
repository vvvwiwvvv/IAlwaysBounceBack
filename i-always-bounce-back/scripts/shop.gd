# CODE FOR CAMERA, SOME 3D MODELS SUCH AS BAT, CAMERA CODE: GDquest
# 3D MODELS: SKETCHFAB
# BOUNCING BALL / CHARGING AND PARTICLES: Kenny.nl AND GodotAcademy.io

extends CanvasLayer

var _game: Node

@onready var points_label: Label = $Root/Points
@onready var panels: Control = $Root/Panels


func _ready() -> void:
	_game = get_parent()
	visible = false
	_game.shop_toggled.connect(_on_shop_toggled)
	_game.points_changed.connect(_on_points_changed)
	_game.stats_changed.connect(refresh)
	for panel: Node in panels.get_children():
		panel.setup(_game)


func _on_shop_toggled(open: bool) -> void:
	visible = open
	if open:
		refresh()


func _on_points_changed(_total: int) -> void:
	if visible:
		refresh()


func refresh() -> void:
	points_label.text = "POINTS  %d" % int(_game.points)
	for panel: Node in panels.get_children():
		panel.refresh()
