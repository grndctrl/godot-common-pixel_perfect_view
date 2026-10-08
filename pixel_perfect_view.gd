@tool
class_name PixelPerfectView
extends SubViewportContainer
## Shows the game at a whole-number pixel scale, so every art pixel is an exact square of
## screen pixels. Picks the largest scale that still shows all of `target_size`, then grows
## the game area to cover the window. The part that doesn't divide evenly falls off the
## screen edges.
## Give it one child: a SubViewport with the world inside. The view configures the
## SubViewport and the window itself.

## Visibility layer the glide target is moved to. Leave it free in your own scenes.
const GLIDE_LAYER := 20

## World area that is always visible, in art pixels. On wider or taller screens you see more.
@export var target_size := Vector2i(800, 600):
	set(value):
		target_size = value.max(Vector2i.ONE)
		_fit()
## On: render at art resolution and scale up the whole image, so everything sits on the
## art pixel grid. Off: scale with the camera's zoom and render at window resolution, so
## the camera and moving sprites glide one screen pixel at a time.
@export var snap_to_art_pixels := false:
	set(value):
		snap_to_art_pixels = value
		notify_property_list_changed()
		_fit()
		_update_glide()
## Draw the camera's target on a layer on top that glides between art pixels, so it doesn't
## wobble against the gliding world. Needs a `PixelPerfectCamera2D` with a `target`.
@export var glide_target := false:
	set(value):
		glide_target = value
		_update_glide()

## Screen pixels per art pixel. Read-only, updated when the window resizes.
var pixel_scale := 1

var _base_position := Vector2.ZERO
var _subpixel_offset := Vector2.ZERO ## camera's snapped minus true position, in art pixels
var _glide: SubViewportContainer
var _glide_root: Node2D ## node whose subtree is on the glide layer


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var game := _game()
	game.snap_2d_transforms_to_pixel = true
	game.snap_2d_vertices_to_pixel = true
	game.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	game.handle_input_locally = false
	game.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	stretch = true
	set_anchors_preset(PRESET_TOP_LEFT)
	# The view does the scaling. Engine stretching on top would scale the image twice.
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_viewport().size_changed.connect(_fit)
	_fit()
	_update_glide()


func _notification(what: int) -> void:
	if what == NOTIFICATION_CHILD_ORDER_CHANGED and Engine.is_editor_hint():
		update_configuration_warnings()


func _get_configuration_warnings() -> PackedStringArray:
	if get_child_count() != 1 or get_child(0) is not SubViewport:
		return ["Needs exactly one child: a SubViewport with the world inside it."]
	return []


func _validate_property(property: Dictionary) -> void:
	if property.name == "glide_target" and not snap_to_art_pixels:
		property.usage = PROPERTY_USAGE_NO_EDITOR


## Nearest whole pixel to `current_position` in the direction of `target_direction`; plain rounding on axes that aren't
## moving. Ease a stopped glide target onto this, so it never moves backwards to settle.
static func pixel_ahead(current_position: Vector2, target_direction: Vector2) -> Vector2:
	var pixel := current_position.round()
	if target_direction.x > 0.0:
		pixel.x = ceilf(current_position.x)
	elif target_direction.x < 0.0:
		pixel.x = floorf(current_position.x)
	if target_direction.y > 0.0:
		pixel.y = ceilf(current_position.y)
	elif target_direction.y < 0.0:
		pixel.y = floorf(current_position.y)
	return pixel


## Called by `PixelPerfectCamera2D` every frame after it snaps to the pixel grid.
func camera_snapped(camera: PixelPerfectCamera2D, true_position: Vector2) -> void:
	if not snap_to_art_pixels:
		return
	# Shift the scaled-up image to hide the camera's snapping.
	_subpixel_offset = (camera.global_position - true_position) * camera.zoom
	_place()
	if _glide and _glide.visible and camera.target:
		# Canvas transforms normally update after `_process`. Bring this one up to date.
		camera.force_update_scroll()
		(_glide.get_child(0) as SubViewport).canvas_transform = _game().canvas_transform
		# Add back what the engine's rounding took off the target. Assumes the target's
		# parent sits on a whole pixel.
		var p := camera.target.global_position
		_glide.position = (p - (p + Vector2(0.5, 0.5)).floor()) * stretch_shrink


func _game() -> SubViewport:
	return get_child(0) as SubViewport


func _fit() -> void:
	if Engine.is_editor_hint() or not is_node_ready():
		return
	var window := Vector2i(get_viewport().get_visible_rect().size)
	@warning_ignore_start("integer_division")
	pixel_scale = maxi(1, mini(window.x / target_size.x, window.y / target_size.y))
	var shrink := pixel_scale if snap_to_art_pixels else 1
	# Round up so the game covers the window. Round up to even as well, so a centred
	# camera lands on a whole pixel.
	var game := (window + Vector2i.ONE * (shrink - 1)) / shrink
	@warning_ignore_restore("integer_division")
	if snap_to_art_pixels:
		# A spare art pixel each side, revealed when the sub-pixel offset shifts the image.
		game += Vector2i(2, 2)
	else:
		_subpixel_offset = Vector2.ZERO
	game += game % 2
	stretch_shrink = shrink
	size = game * shrink
	if _glide:
		_glide.stretch_shrink = shrink
		_glide.size = size
	_base_position = ((Vector2(window) - size) / 2).floor()
	_place()
	var camera := _game().get_camera_2d()
	if camera:
		camera.zoom = Vector2.ONE * (pixel_scale / shrink)


func _place() -> void:
	position = _base_position + _subpixel_offset * stretch_shrink


func _update_glide() -> void:
	if Engine.is_editor_hint() or not is_node_ready():
		return
	var on := glide_target and snap_to_art_pixels
	var camera := _game().get_camera_2d() as PixelPerfectCamera2D
	if on and not (camera and camera.target):
		push_warning("glide_target needs a current PixelPerfectCamera2D with a target.")
		on = false
	if on and not _glide:
		_create_glide()
	if on and _glide_root != camera.target:
		_move_to_glide_layer(camera.target)
	# Hidden glide layer: Game draws the target itself.
	_game().set_canvas_cull_mask_bit(GLIDE_LAYER - 1, not on)
	if _glide:
		_glide.visible = on


func _create_glide() -> void:
	var material := CanvasItemMaterial.new()
	# A transparent viewport stores premultiplied colour. Normal blending draws it too dark.
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	_glide = SubViewportContainer.new()
	_glide.material = material
	_glide.mouse_filter = MOUSE_FILTER_IGNORE
	_glide.stretch = true
	var glide := SubViewport.new()
	var game := _game()
	glide.world_2d = game.world_2d
	glide.transparent_bg = true
	glide.snap_2d_transforms_to_pixel = true
	glide.snap_2d_vertices_to_pixel = true
	glide.canvas_item_default_texture_filter = game.canvas_item_default_texture_filter
	glide.handle_input_locally = false
	glide.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	glide.canvas_cull_mask = 0
	glide.set_canvas_cull_mask_bit(GLIDE_LAYER - 1, true)
	_glide.add_child(glide)
	# Internal, so `get_child(0)` is still the game. Drawn on top of it, and moves with it.
	add_child(_glide, false, INTERNAL_MODE_FRONT)
	_fit()


## Puts `target` and everything under it on the glide layer only, and adds the layer to
## its ancestors so the cull mask doesn't skip it on the way down.
func _move_to_glide_layer(target: Node2D) -> void:
	# The shift needs the exact drawn position, which physics interpolation hides.
	target.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_glide_root = target
	_set_glide_layer(target)
	var bit := 1 << (GLIDE_LAYER - 1)
	var node := target.get_parent()
	while node and node != _game():
		if node is CanvasItem:
			node.visibility_layer |= bit
		node = node.get_parent()
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)


func _set_glide_layer(node: Node) -> void:
	if node is CanvasItem:
		node.visibility_layer = 1 << (GLIDE_LAYER - 1)
	for child in node.get_children(true):
		_set_glide_layer(child)


func _on_node_added(node: Node) -> void:
	if node is CanvasItem and is_instance_valid(_glide_root) and _glide_root.is_ancestor_of(node):
		node.visibility_layer = 1 << (GLIDE_LAYER - 1)
