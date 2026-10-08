extends Node2D
## Glide example player: a square moved with the arrow keys. Moves in `_process` and eases
## onto the nearest art pixel when it stops, as a glide target should.

@export var max_speed := 40.0
@export var acceleration := 160.0
## With no input and speed below this, ease onto the nearest whole art pixel.
@export var settle_below_speed := 8.0
## How quickly it eases onto the pixel. Higher is snappier.
@export var settle_speed := 6.0

var velocity := Vector2.ZERO

var _settling := false
var _settle_pixel := Vector2.ZERO


func _process(delta: float) -> void:
	var input := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if input != Vector2.ZERO:
		_settling = false
	elif not _settling and velocity.length() < settle_below_speed:
		# Latch the target pixel once, ahead of the direction of travel, so the
		# glide can never pull the player backwards.
		_settling = true
		_settle_pixel = Vector2(_pixel_ahead(position.x, velocity.x), _pixel_ahead(position.y, velocity.y))
		velocity = Vector2.ZERO

	if _settling:
		position = position.lerp(_settle_pixel, 1.0 - exp(-settle_speed * delta))
		if position.distance_to(_settle_pixel) < 0.01:
			position = _settle_pixel
		return

	velocity = velocity.move_toward(input * max_speed, acceleration * delta)
	position += velocity * delta


## Nearest whole pixel in the direction of `v`; plain rounding when not moving.
func _pixel_ahead(p: float, v: float) -> float:
	if v > 0.0:
		return ceilf(p)
	if v < 0.0:
		return floorf(p)
	return roundf(p)


func _draw() -> void:
	draw_rect(Rect2(-5, -5, 11, 11), Color("181425"))
	draw_rect(Rect2(-4, -4, 9, 9), Color("feae34"))
	draw_rect(Rect2(0, 0, 1, 1), Color("181425"))
