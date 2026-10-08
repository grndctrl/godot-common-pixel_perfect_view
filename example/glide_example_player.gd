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


func _process(delta: float) -> void:
	var input := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = velocity.move_toward(input * max_speed, acceleration * delta)
	position += velocity * delta
	if input == Vector2.ZERO and velocity.length() < settle_below_speed:
		var pixel := position.round()
		position = position.lerp(pixel, 1.0 - exp(-settle_speed * delta))
		if position.distance_to(pixel) < 0.01:
			position = pixel


func _draw() -> void:
	draw_rect(Rect2(-5, -5, 11, 11), Color("181425"))
	draw_rect(Rect2(-4, -4, 9, 9), Color("feae34"))
	draw_rect(Rect2(0, 0, 1, 1), Color("181425"))
