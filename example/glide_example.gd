extends Control
## Glide example: Space toggles the glide layer so you can compare. With it off, the player
## is drawn in Game with the world and wobbles by up to an art pixel as the camera glides.

@onready var _view: PixelPerfectView = $View
@onready var _label: Label = $Label


func _ready() -> void:
	_apply()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_accept"):
		_view.glide_view.visible = not _view.glide_view.visible
		_apply()


func _apply() -> void:
	var on := _view.glide_view.visible
	# Layer 2 is bit 1. Game draws the player itself while the glide layer is hidden.
	(_view.get_child(0) as SubViewport).set_canvas_cull_mask_bit(1, not on)
	_label.text = "Glide %s (Space to toggle, arrows to move)" % ("on" if on else "off")
