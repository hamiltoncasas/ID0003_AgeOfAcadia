extends CharacterBody2D

@export var speed: float = 100.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var ground_shadow: Sprite2D = $GroundShadow

var _last_direction: Vector2 = Vector2.DOWN
var _last_anim_name: String = ""


func _ready():
	var us := UnitSprites.load_from_manifest("res://sprites/infanteria/arquero/arquero_manifest.json")
	if us:
		var sf := us.build_sprite_frames()
		if sf:
			animated_sprite.sprite_frames = sf
			# Start with idle_front animation
			if sf.has_animation("idle_front"):
				animated_sprite.play("idle_front")
				_last_anim_name = "idle_front"

	# Generate a soft elliptical shadow texture procedurally
	_generate_shadow_texture()


func _generate_shadow_texture():
	## Creates a soft elliptical shadow at the character's feet.
	## The shadow is a radial gradient ellipse that fades to transparent at edges.
	var size := 80
	var half := size / 2
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			# Normalized distance from center (elliptical: wider in X)
			var dx := (x - half + 0.5) / (half * 0.75)
			var dy := (y - half + 0.5) / half
			var dist := sqrt(dx * dx + dy * dy)
			var alpha := 0.0
			if dist < 1.0:
				# Smooth falloff: full center, soft edges
				alpha = clampf(1.0 - dist * dist, 0.0, 1.0) * 0.4
			img.set_pixel(x, y, Color(0, 0, 0, alpha))

	var tex := ImageTexture.create_from_image(img)
	ground_shadow.texture = tex
	ground_shadow.centered = true


func _physics_process(_delta: float):
	var input_dir := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down"),
	)

	if input_dir != Vector2.ZERO:
		velocity = input_dir * speed
		_play_move_anim(input_dir)
	else:
		velocity = Vector2.ZERO
		_play_idle_anim()

	move_and_slide()
	# Shadow follows at ground level (y_sort will handle depth)
	ground_shadow.global_position = global_position


func _play_move_anim(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return
	_last_direction = direction
	var dir_name := _angle_to_direction(atan2(direction.y, direction.x))
	if animated_sprite.sprite_frames == null:
		return
	var walk_anim := "walk_" + dir_name
	if animated_sprite.sprite_frames.has_animation(walk_anim):
		if _last_anim_name != walk_anim:
			animated_sprite.play(walk_anim)
			_last_anim_name = walk_anim
	else:
		var idle_anim := "idle_" + dir_name
		if animated_sprite.sprite_frames.has_animation(idle_anim):
			if _last_anim_name != idle_anim:
				animated_sprite.play(idle_anim)
				_last_anim_name = idle_anim
	# Flip only profile/front_angle sprites when moving left.
	# Dedicated back_angle strips already show the correct orientation.
	animated_sprite.flip_h = direction.x < 0 and dir_name in ["profile", "front_angle"]


func _play_idle_anim() -> void:
	if animated_sprite.sprite_frames == null:
		return
	var dir_name := _angle_to_direction(atan2(_last_direction.y, _last_direction.x))
	var idle_anim := "idle_" + dir_name
	if animated_sprite.sprite_frames.has_animation(idle_anim):
		if _last_anim_name != idle_anim:
			animated_sprite.play(idle_anim)
			_last_anim_name = idle_anim


static func _angle_to_direction(angle: float) -> String:
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

	return "front"
