extends Node2D
## Glide example ground: a grid of one-art-pixel lines to hold the player still against.

const EXTENT := 2048
const SPACING := 16


func _draw() -> void:
	draw_rect(Rect2(-EXTENT, -EXTENT, EXTENT * 2, EXTENT * 2), Color("262b44"))
	for i in range(-EXTENT, EXTENT, SPACING):
		draw_rect(Rect2(i, -EXTENT, 1, EXTENT * 2), Color("3a4466"))
		draw_rect(Rect2(-EXTENT, i, EXTENT * 2, 1), Color("3a4466"))
