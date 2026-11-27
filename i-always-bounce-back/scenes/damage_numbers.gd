extends Label3D


func damage(amount:float)->void:
	text=str(amount)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self,"position:y",position.y + 1.0, 0.6)# how much to up by and how long
	tween.tween_property(self,"modulate:a",0,0.6)
	await tween.finished
	queue_free()
