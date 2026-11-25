extends CanvasLayer

var _game: Node

@onready var points_label: Label = $Root/Points
@onready var panels: Control = $Root/Panels


func _ready() -> void:
	_game = get_parent()
	visible = false
	_game.chest_toggled.connect(_on_chest_toggled)
	_game.points_changed.connect(_on_points_changed)
	_game.stats_changed.connect(refresh)
	for panel: Node in panels.get_children():
		panel.setup(_game)


func _on_chest_toggled(open: bool) -> void:
	visible = open
	var x = panels.get_children()
	if open:
		x.shuffle()
		for i in x:
			i.play()
			await get_tree().create_timer(0.2).timeout

		refresh()
	else:
		for i in x:
			i.stop()
		


func _on_points_changed(_total: int) -> void:
	if visible:
		refresh()


func refresh() -> void:
	points_label.text = "POINTS  %d" % int(_game.points)
	for panel: Node in panels.get_children():
		panel.refresh()
