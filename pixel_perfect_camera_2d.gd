class_name PixelPerfectCamera2D
extends Camera2D
## Follows `target` smoothly inside a `PixelPerfectView`. Snaps to whole screen pixels, so
## the world never jitters against itself. With the view's `snap_to_art_pixels` on it snaps
## to whole art pixels instead, and the view shifts the image by the leftover sub-pixel, so
## motion stays smooth while art pixels stay on their grid.

@export var target: Node2D
## How quickly the camera catches up with the target. Higher is snappier.
@export var follow_speed := 5.0

var _true_position := Vector2.ZERO ## smooth, unsnapped camera position


func _init() -> void:
	# Placed by hand every frame. Set before entering the tree, where Camera2D picks its mode.
	physics_interpolation_mode = PHYSICS_INTERPOLATION_MODE_OFF
	process_callback = CAMERA2D_PROCESS_IDLE
	position_smoothing_enabled = false


func _ready() -> void:
	_true_position = target.global_position if target else global_position
	_snap()


func _process(delta: float) -> void:
	if target:
		_true_position = _true_position.lerp(target.global_position, 1.0 - exp(-follow_speed * delta))
	_snap()


func _snap() -> void:
	# One game pixel in world units: a screen pixel when zoomed, an art pixel at zoom 1.
	global_position = (_true_position * zoom).round() / zoom
	var view := get_viewport().get_parent() as PixelPerfectView
	if view:
		view.camera_snapped(self, _true_position)
