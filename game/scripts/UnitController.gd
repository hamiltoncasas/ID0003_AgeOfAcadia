class_name UnitController extends CharacterBody2D
## Basic movement controller with 5-direction animation switching.
##
## Reads input from ui_left/ui_right/ui_up/ui_down, maps the resulting
## velocity vector to one of 5 direction buckets via atan2, and calls
## play() on a child AnimatedSprite2D with the appropriate animation name.
##
## The LEFT profile animation reuses the RIGHT profile texture with
## flip_h = true, so no separate left-facing strip is needed.
## front_angle also flips when moving left, so a single front_angle strip
## covers both down-right and down-left movement.
##
## When a direction animation is missing (e.g. back/back_angle for units
## with only 3 strips), _resolve_fallback() tries alternative directions
## instead of falling back to the first available animation.
##
## unit_sprites should be a UnitSprites Resource (typed as Resource here
## to avoid parse-time dependency on the class_name declaration).

@export var speed: float = 100.0
@export var default_animation: String = "idle"

const ARROW_SCENE: PackedScene = preload("res://scenes/Arrow.tscn")
const ARROW_SPAWN_OFFSET: float = 20.0

const ZOOM_MIN: float = 0.3
const ZOOM_MAX: float = 3.0
const ZOOM_STEP: float = 0.1

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _camera: Camera2D = $Camera2D

## Animation state machine
enum State { IDLE, WALK, ATTACK, HURT, DEATH }

## Current state. Initial state is always IDLE.
var _state: State = State.IDLE
## Set true by die() — locks all movement input.
var _is_dead: bool = false
## Last movement direction, used by attack()/hurt()/die() to play facing-correct animation.
var _last_direction: Vector2 = Vector2.DOWN

var _unit_sprites: Resource = null


func _ready() -> void:
	# Connect animation loop signal for auto-transitions (ATTACK/HURT → IDLE)
	animated_sprite.animation_looped.connect(_on_animation_looped)
	# Try to build sprite frames now — will work if unit_sprites was already set
	_rebuild_sprite_frames()


## Adjust camera zoom by delta, clamped to [ZOOM_MIN, ZOOM_MAX].
func _zoom(delta: float) -> void:
	if _camera == null:
		return
	_camera.zoom = Vector2(
		clampf(_camera.zoom.x + delta, ZOOM_MIN, ZOOM_MAX),
		clampf(_camera.zoom.y + delta, ZOOM_MIN, ZOOM_MAX),
	)


func _rebuild_sprite_frames() -> void:
	if _unit_sprites == null or animated_sprite == null:
		return
	var sf = _unit_sprites.build_sprite_frames()
	if sf:
		animated_sprite.sprite_frames = sf
		_update_animation(Vector2.DOWN)


## Assign UnitSprites resource and rebuild animation frames.
## Safe to call anytime, even after _ready().
func set_unit_sprites(sprites: Resource) -> void:
	_unit_sprites = sprites
	_rebuild_sprite_frames()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("test_attack"):
		attack()
	elif event.is_action_pressed("test_hurt"):
		hurt()
	elif event.is_action_pressed("test_die"):
		die()
	elif event.is_action_pressed("test_revive"):
		_revive()
	elif event.is_action_pressed("zoom_in"):
		_zoom(ZOOM_STEP)
	elif event.is_action_pressed("zoom_out"):
		_zoom(-ZOOM_STEP)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Click izquierdo: dispara hacia la posición del mouse
			var target: Vector2 = get_global_mouse_position()
			_update_animation((target - global_position).normalized())
			attack(target)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(-ZOOM_STEP)


func _physics_process(_delta: float) -> void:
	# DEATH locks all movement input
	if _is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var input_dir := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down"),
	)

	if input_dir != Vector2.ZERO:
		velocity = input_dir * speed
		# Solo actualizar animación si no está en una acción (ATTACK/HURT/DEATH)
		if _state in [State.IDLE, State.WALK]:
			_state = State.WALK
			_update_animation(input_dir)
	else:
		velocity = Vector2.ZERO
		if _state in [State.IDLE, State.WALK]:
			_state = State.IDLE
			_update_animation(_last_direction)
	# Durante ATTACK/HURT/DEATH: animación controlada por la acción, no por input

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


## Map State enum value to its animation name prefix.
static func _state_to_anim(state: State) -> String:
	match state:
		State.WALK:   return "walk"
		State.ATTACK: return "attack"
		State.HURT:   return "hurt"
		State.DEATH:  return "death"
		_:            return "idle"


func _update_animation(direction: Vector2) -> void:
	_last_direction = direction
	var anim_dir := angle_to_direction(atan2(direction.y, direction.x))
	var anim_name: String = _state_to_anim(_state) + "_" + anim_dir

	var sf: SpriteFrames = animated_sprite.sprite_frames
	if sf == null:
		return

	# Resolve animation — try exact name, then direction fallbacks
	var base_anim: String = _state_to_anim(_state)
	var resolved: String = anim_name if sf.has_animation(anim_name) \
		else _resolve_fallback(base_anim, anim_dir, sf)

	if resolved != "":
		animated_sprite.play(resolved)

	# Flip profile and front_angle when moving left
	animated_sprite.flip_h = direction.x < 0 and anim_dir in ["profile", "front_angle"]


## When a direction animation is missing, try alternative directions
## before falling back to the first available animation.
## This allows characters with only 3 direction strips (profile, front_angle, front)
## to animate correctly when moving up (maps back → front, back_angle → front_angle).
static func _resolve_fallback(base_anim: String, dir: String, sf: SpriteFrames) -> String:
	var alternatives := {
		"back": ["front", "front_angle", "profile"],
		"back_angle": ["front_angle", "profile", "front"],
	}

	# First: try to stay in the same base animation
	if dir in alternatives:
		for alt_dir: String in alternatives[dir] as Array[String]:
			var alt_name: String = base_anim + "_" + alt_dir
			if sf.has_animation(alt_name):
				return alt_name
	
	# Second: try any direction of the same base animation
	var all_dirs := ["front", "front_angle", "profile", "back_angle", "back"]
	for check_dir in all_dirs:
		var check_name: String = base_anim + "_" + check_dir
		if sf.has_animation(check_name):
			return check_name

	# Last resort: fall back to first available animation of ANY type
	var names := sf.get_animation_names()
	return names[0] if names.size() > 0 else ""


## --- Public Activation API ---

## Start attack animation. Loops once then auto-returns to IDLE.
## Si se pasa [target_pos], la flecha apunta a esa posición con arco.
func attack(target_pos: Vector2 = Vector2.INF) -> void:
	if _is_dead:
		return
	_state = State.ATTACK
	_update_animation(_last_direction)
	# Spawn arrow — con o sin objetivo
	_spawn_arrow(target_pos)


## Spawn an arrow projectile with ballistic arc.
## Si [target_pos] no es INF, la flecha calcula la trayectoria para caer ahí.
func _spawn_arrow(target_pos: Vector2 = Vector2.INF) -> void:
	var arrow: Arrow = ARROW_SCENE.instantiate()
	
	if target_pos != Vector2.INF:
		# Disparo dirigido: la flecha calcula el arco por sí sola
		arrow.target_pos = target_pos
		var dir := (target_pos - global_position).normalized()
		var offset := dir * ARROW_SPAWN_OFFSET + Vector2(0, -6)
		arrow.global_position = global_position + offset
	else:
		# Disparo direccional: velocidad en el plano del suelo
		var dir := _last_direction.normalized()
		arrow.velocity = dir * arrow.speed
		var offset := dir * ARROW_SPAWN_OFFSET + Vector2(0, -6)
		arrow.global_position = global_position + offset
	
	get_parent().add_child(arrow)


## Start hurt animation. Loops once then auto-returns to IDLE.
## Shows a red flash for immediate visual feedback.
func hurt() -> void:
	if _is_dead:
		return
	_state = State.HURT
	_update_animation(_last_direction)
	# Flash rojo para que el hurt sea inmediatamente visible
	animated_sprite.modulate = Color(1.0, 0.4, 0.4)
	var tween := create_tween()
	tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.3)
	tween.set_trans(Tween.TRANS_SINE)


## Start death animation. Terminal — locks all movement input.
func die() -> void:
	_state = State.DEATH
	_is_dead = true
	_update_animation(_last_direction)


var _death_fade_tween: Tween = null


## Reset from DEATH back to IDLE (test helper).
func _revive() -> void:
	# Cancel fade-out si había empezado
	if _death_fade_tween and _death_fade_tween.is_valid():
		_death_fade_tween.kill()
		_death_fade_tween = null
	animated_sprite.modulate = Color.WHITE
	animated_sprite.visible = true
	_is_dead = false
	_state = State.IDLE
	animated_sprite.rotation = 0.0
	_update_animation(_last_direction)


## Called when the current animation completes a loop.
## ATTACK and HURT auto-transition to IDLE.
## DEATH stops on the last frame and fades out the corpse.
## El nodo NO se elimina — queda invisible para poder revivir con E.
func _on_animation_looped() -> void:
	match _state:
		State.ATTACK, State.HURT:
			_state = State.IDLE
			_update_animation(_last_direction)
		State.DEATH:
			animated_sprite.stop()
			# Fade out: el cuerpo se desvanece pero el nodo queda vivo
			_death_fade_tween = create_tween()
			_death_fade_tween.tween_property(animated_sprite, "modulate:a", 0.0, 1.2).set_delay(0.5)
			# No hay queue_free — se deja vivo para poder revivir siempre


## Switch the base animation type by string name (backwards-compat).
## Prefer typed API: attack(), hurt(), die()
func play_animation(anim: String, direction: Vector2 = Vector2.DOWN) -> void:
	match anim:
		"walk":   _state = State.WALK
		"attack": _state = State.ATTACK
		"hurt":   _state = State.HURT
		"death":  _state = State.DEATH
		_:        _state = State.IDLE
	_update_animation(direction)


## Apply team color via shader.  Pixels matching marker_color (magenta
## #FF00FF by default) are replaced by `color` at render time so skin,
## hair and weapons stay unchanged.
##
## Usage:
##   unit.set_team_color(Color(0.8, 0.1, 0.1))      # red team
##   unit.set_team_color(Color(0.1, 0.3, 0.8))      # blue team
##
## Pass custom marker_color and threshold when the sprite uses a
## different marker hue or a softer blend is needed:
##   unit.set_team_color(team_red, marker, 0.08)
func set_team_color(
	color: Color,
	marker: Color = Color(1.0, 0.0, 1.0),
	threshold: float = 0.05
) -> void:
	if animated_sprite == null:
		return

	var mat := animated_sprite.material as ShaderMaterial

	# Attach shader material on first call
	if mat == null or mat.shader == null:
		mat = ShaderMaterial.new()
		mat.shader = preload("res://shaders/team_color.gdshader")
		animated_sprite.material = mat

	mat.set_shader_parameter("team_color", color)
	mat.set_shader_parameter("marker_color", marker)
	mat.set_shader_parameter("threshold", threshold)
