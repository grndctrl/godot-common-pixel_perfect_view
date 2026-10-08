extends Control
## Glide example: Space toggles the glide layer so you can compare. With it off, the player
## is drawn in Game with the world and wobbles by up to an art pixel as the camera glides.

@onready var _view: PixelPerfectView = $View
@onready var _label: Label = $Label


func _ready() -> void:
	_apply()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_accept"):
		_view.glide_target = not _view.glide_target
		_apply()


func _apply() -> void:
	_label.text = "Glide %s (Space to toggle, arrows to move)" % ("on" if _view.glide_target else "off")
