extends Node2D
## Example world: draws one-art-pixel stripes and outlines `target_size` in red, so you can
## check that the pixels are crisp and the target area is always fully visible.

@onready var _view := owner as PixelPerfectView
@onready var _camera: Camera2D = $Camera2D


func _ready() -> void:
	get_tree().root.size_changed.connect(queue_redraw)


func _draw() -> void:
	var world := get_viewport_rect().size / _camera.zoom
	for x in range(-int(world.x / 2), int(world.x / 2), 2):
		draw_rect(Rect2(x, -world.y / 2, 1, world.y), Color("3a4466"))
	var target := Vector2(_view.target_size)
	draw_rect(Rect2(-target / 2, target), Color.RED, false, 1.0)
	print("window %s  scale %d  zoom %s" % [get_tree().root.size, _view.pixel_scale, _camera.zoom])
