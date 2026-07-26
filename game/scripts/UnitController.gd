class_name UnitController extends CharacterBody2D
## Basic movement controller with 5-direction animation switching.
##
## Reads input from ui_left/ui_right/ui_up/ui_down, maps the resulting
## velocity vector to one of 5 direction buckets via atan2, and calls
## play() on a child AnimatedSprite2D with the appropriate animation name.
##
## The LEFT profile animation reuses the RIGHT profile texture with
## flip_h = true, so no separate left-facing strip is needed.
##
## unit_sprites should be a UnitSprites Resource (typed as Resource here
## to avoid parse-time dependency on the class_name declaration).

@export var unit_sprites: Resource
@export var speed: float = 100.0
@export var default_animation: String = "idle"

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

## Tracks the current base animation ("idle" / "walk" / etc.)
var _base_anim: String = "idle"


func _ready() -> void:
	if unit_sprites:
		animated_sprite.sprite_frames = unit_sprites.build_sprite_frames()
	_update_animation(Vector2.DOWN)


func _physics_process(_delta: float) -> void:
	var input_dir := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down"),
	)

	if input_dir != Vector2.ZERO:
		velocity = input_dir * speed
		_base_anim = "walk"
		_update_animation(input_dir)
	else:
		velocity = Vector2.ZERO
		_base_anim = "idle"
		_update_animation(Vector2.DOWN)

	move_and_slide()


## Map velocity vector to one of 5 direction names using atan2 buckets.
##
## Angle ranges (degrees, 0 deg = right, positive = clockwise):
##   -22.5  to   22.5  -> profile       (right)
##    22.5  to   67.5  -> front_angle   (down-right)
##    67.5  to  112.5  -> front         (down)
##   112.5  to  157.5  -> front_angle   (down-left)
##   157.5  to +/-180  -> profile       (left, FLIP_H)
##  -157.5  to -112.5  -> back_angle    (up-left)
##  -112.5  to  -67.5  -> back          (up)
##   -67.5  to  -22.5  -> back_angle    (up-right)
static func angle_to_direction(angle: float) -> String:
	var deg := rad_to_deg(angle)

	if deg >= -22.5 and deg < 22.5:
		return "profile"
	elif deg >= 22.5 and deg < 67.5:
		return "front_angle"
	elif deg >= 67.5 and deg < 112.5:
		return "front"
	elif deg >= 112.5 and deg < 157.5:
		return "front_angle"
	elif deg >= 157.5 or deg < -157.5:
		return "profile"
	elif deg >= -157.5 and deg < -112.5:
		return "back_angle"
	elif deg >= -112.5 and deg < -67.5:
		return "back"
	elif deg >= -67.5 and deg < -22.5:
		return "back_angle"

	return "front"  # fallback


func _update_animation(direction: Vector2) -> void:
	var anim_dir := angle_to_direction(atan2(direction.y, direction.x))
	var anim_name := _base_anim + "_" + anim_dir

	var sf := animated_sprite.sprite_frames
	if sf == null:
		return

	if sf.has_animation(anim_name):
		animated_sprite.play(anim_name)
	else:
		# Fallback: try the first available animation
		var names := sf.get_animation_names()
		if names.size() > 0:
			animated_sprite.play(names[0])

	# Flip the sprite for left-profile movement
	if anim_dir == "profile" and direction.x < 0:
		animated_sprite.flip_h = true
	elif anim_dir == "profile":
		animated_sprite.flip_h = false


## Switch the base animation type (e.g. from "idle" to "attack").
func play_animation(anim: String, direction: Vector2 = Vector2.DOWN) -> void:
	_base_anim = anim
	_update_animation(direction)
