
extends Label

func _process(_delta: float) -> void:
	text = "COST  %d" % int($"../..".price)
