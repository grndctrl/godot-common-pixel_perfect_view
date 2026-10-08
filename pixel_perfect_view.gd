class_name PixelPerfectView
extends SubViewportContainer
## Shows the game at a whole-number pixel scale, so every art pixel is an exact square of
## screen pixels. Picks the largest scale that still shows all of `target_size`, then grows
## the game area to cover the window. The part that doesn't divide evenly falls off the
## screen edges.
## Set the project's stretch mode to "disabled" and make a SubViewport the only child.

## World area that is always visible, in art pixels. On wider or taller screens you see more.
@export var target_size := Vector2i(800, 600)
## Scale with the current Camera2D's zoom and render at window resolution, so the camera
## and moving sprites glide one screen pixel at a time. Off: render at art resolution
## and scale up the whole image, so everything sits on the art pixel grid.
@export var zoom_camera := true
## Optional second view drawn on top that shows the camera target gliding between art
## pixels. Needs `zoom_camera` off. See "Gliding target" in the README.
@export var glide_view: PixelPerfectView

## Screen pixels per art pixel. Read-only, updated when the window resizes.
var pixel_scale := 1
## Camera's snapped minus true position, in game pixels. Set by `PixelPerfectCamera2D`
## when `zoom_camera` is off. Shifts the scaled-up image to hide the camera's snapping.
var subpixel_offset := Vector2.ZERO:
	set(value):
		subpixel_offset = value
		_place()

var _base_position := Vector2.ZERO


func _ready() -> void:
	stretch = true
	get_viewport().size_changed.connect(_fit)
	if glide_view:
		glide_view.target_size = target_size
		glide_view.zoom_camera = zoom_camera
		(glide_view.get_child(0) as SubViewport).world_2d = (get_child(0) as SubViewport).world_2d
	_fit()


func _fit() -> void:
	var window := Vector2i(get_viewport().get_visible_rect().size)
	@warning_ignore_start("integer_division")
	pixel_scale = maxi(1, mini(window.x / target_size.x, window.y / target_size.y))
	var shrink := 1 if zoom_camera else pixel_scale
	# Round up so the game covers the window. Round up to even as well, so a centred
	# camera lands on a whole pixel.
	var game := (window + Vector2i.ONE * (shrink - 1)) / shrink
	@warning_ignore_restore("integer_division")
	if not zoom_camera:
		# A spare art pixel each side, revealed when `subpixel_offset` shifts the image.
		game += Vector2i(2, 2)
	game += game % 2
	stretch_shrink = shrink
	size = game * shrink
	_base_position = ((Vector2(window) - size) / 2).floor()
	_place()
	var camera := (get_child(0) as SubViewport).get_camera_2d()
	if camera:
		camera.zoom = Vector2.ONE * (pixel_scale / shrink)


func _place() -> void:
	position = _base_position + subpixel_offset * stretch_shrink
