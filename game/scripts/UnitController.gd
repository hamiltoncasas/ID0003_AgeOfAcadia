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

## RTS selection state
var _selected: bool = false
var _selection_ring: Sprite2D = null
## Unique unit index for formation/group management
var unit_index: int = 0
## Right-click movement system — A* pathfinding for water avoidance
var _move_target: Vector2 = Vector2.INF
var _path_waypoints: Array = []
var _path_index: int = 0
var _nav: NavigationSystem = null
var _direct_move: bool = false
var _tilemap_layer: TileMapLayer = null  # set by Llanura1.gd for water checks
	var _water_map: Array = []  # explicit boolean water map
	var _water_map_checked: bool = false  # debug: first-time check
const MOVE_ARRIVAL_DIST: float = 24.0

## Health system
var health: int = 100
var max_health: int = 100
var _health_bar_fill: ColorRect = null

## Biome index map (set by Llanura1.gd for water/collision checks).
## biome[y][x] = 0(WATER) | 1(SAND) | 2(GRASS) | 3(DIRT) | 4(MOUNTAIN)
var biome_data: Array = []
## Elevation map — elev[y][x] = 0-7, set by Llanura1.gd
var elev_data: Array = []
var _cell_ox: int = -100
var _cell_oy: int = -100
## Base y-offset for elevation (set in _process to follow terrain height)
var _elev_base_y: float = 0.0


func _ready() -> void:
	# Connect animation loop signal for auto-transitions (ATTACK/HURT → IDLE)
	animated_sprite.animation_looped.connect(_on_animation_looped)
	# Try to build sprite frames now — will work if unit_sprites was already set
	_rebuild_sprite_frames()
	# Find health bar (created by Llanura1.gd)
	_health_bar_fill = get_node_or_null("HealthBar")
	# Selection ring (hidden by default)
	_selection_ring = Sprite2D.new()
	_selection_ring.name = "SelectionRing"
	_selection_ring.texture = _make_selection_ring()
	_selection_ring.centered = true
	_selection_ring.visible = false
	_selection_ring.z_index = -1  # behind the character
	add_child(_selection_ring)


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
	# Only handle keyboard actions here — mouse selection/move is in GameUI
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


## Right-click handler: A* pathfinding with water avoidance.
func _move_to(target: Vector2) -> void:
	# Debug: one-time water_map check
	if not _water_map_checked:
		_water_map_checked = true
		var wc = 0
		if not _water_map.is_empty():
			for yy in range(0, 300, 10):
				for xx in range(0, 300, 10):
					if yy < _water_map.size() and xx < _water_map[yy].size():
						if _water_map[yy][xx]:
							wc += 1
			print("WATER MAP unit ", unit_index, ": size=", _water_map.size(), "x", _water_map[0].size(), " sample water=", wc, "/900")
		else:
			print("WATER MAP unit ", unit_index, ": EMPTY!")
	
	# Build nav system once
	if _nav == null and not biome_data.is_empty():
		_nav = NavigationSystem.new()
		_nav.build(biome_data)
		print("Nav built for unit ", unit_index)
	
	# Find A* path avoiding water (target may be redirected to nearest land)
	var adjusted = target
	if _is_water_at(target):
		var land = _find_nearest_land(target)
		if land != Vector2.INF:
			adjusted = land
		else:
			print("Unit ", unit_index, ": target is water, no land nearby")
			return
	
	_path_waypoints = []
	_path_index = 0
	_direct_move = false
	if _nav != null:
		_path_waypoints = _nav.find_path(global_position, adjusted)
	
	if _path_waypoints.size() >= 2:
		_path_index = 1
		_move_target = _path_waypoints[_path_index]
	else:
		_move_target = adjusted
		_direct_move = true  # no A* path — check water during movement
	
	if _state in [State.IDLE, State.WALK]:
		_state = State.WALK
	_spawn_move_pointer(_move_target)
	print(">>> Unit ", unit_index, " -> ", _move_target, " direct=", _direct_move, " (", _path_waypoints.size(), " waypoints)")


func _physics_process(delta: float) -> void:
	# DEATH locks all movement input
	if _is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Movement: follow A* path waypoints (path avoids water)
	if _move_target != Vector2.INF:
		var dist := global_position.distance_to(_move_target)
		if dist > MOVE_ARRIVAL_DIST:
			var dir := (_move_target - global_position).normalized()
			# Water check — only for direct movement (A* path already avoids water)
			if _direct_move:
				var next_pos = global_position + dir * 8.0
				if _is_water_at(next_pos):
					var perp = Vector2(-dir.y, dir.x)
					if not _is_water_at(global_position + perp * 8.0):
						dir = perp
					elif not _is_water_at(global_position - perp * 8.0):
						dir = -perp
					else:
						dir = Vector2.ZERO
			velocity = dir * speed if dir != Vector2.ZERO else Vector2.ZERO
			_state = State.WALK
			_update_animation(dir)
		else:
			_direct_move = false
			# Reached waypoint — advance to next
			if _path_index < _path_waypoints.size() - 1:
				_path_index += 1
				_move_target = _path_waypoints[_path_index]
			else:
				velocity = Vector2.ZERO
				_state = State.IDLE
				_update_animation(_last_direction)
				_move_target = Vector2.INF
	else:
		if _state == State.WALK:
			_state = State.IDLE
			_update_animation(_last_direction)
		velocity = Vector2.ZERO

	# Gentle separation to avoid clumping
	var parent = get_parent()
	if parent:
		for child in parent.get_children():
			if child == self or not child is UnitController:
				continue
			var d = global_position.distance_to(child.global_position)
			if d > 0.01 and d < 40.0:
				var force = (40.0 - d) * 3.0
				velocity += (global_position - child.global_position).normalized() * force

	move_and_slide()
	
	# NOTE: elevation y-offset removed — was fighting move_and_slide()
	# causing vertical movement to be cancelled out. Visual overlays
	# still show elevation on the terrain tiles.


## Find nearest non-water cell by searching outward in expanding squares.
func _find_nearest_land(world: Vector2) -> Vector2:
	var px = (world.x / 64.0 + world.y / 32.0) / 2.0
	var py = (world.y / 32.0 - world.x / 64.0) / 2.0
	var cx = int(round(px)) - _cell_ox
	var cy = int(round(py)) - _cell_oy
	for r in range(1, 60):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var nx = cx + dx
				var ny = cy + dy
				if nx >= 0 and ny >= 0:
					# Check water_map first (boolean: true = water)
					if not _water_map.is_empty() and ny < _water_map.size() and nx < _water_map[ny].size():
						if not _water_map[ny][nx]:
							var tile_x = nx + _cell_ox
							var tile_y = ny + _cell_oy
							return Vector2((tile_x - tile_y) * 64, (tile_x + tile_y) * 32)
					# Fallback to biome_data (int: 0 = water)  
					if not biome_data.is_empty() and ny < biome_data.size() and nx < biome_data[ny].size():
						if biome_data[ny][nx] != 0:
							var tile_x = nx + _cell_ox
							var tile_y = ny + _cell_oy
							return Vector2((tile_x - tile_y) * 64, (tile_x + tile_y) * 32)
	return Vector2.INF  # signal: no land found


## Get elevation offset at a world position (in pixels).
## Higher elevation = more negative y (visually higher on isometric grid).
func _get_elevation_offset(pos: Vector2) -> float:
	if elev_data.is_empty():
		return 0.0
	var px = (pos.x / 64.0 + pos.y / 32.0) / 2.0
	var py = (pos.y / 32.0 - pos.x / 64.0) / 2.0
	var cx = int(round(px)) - _cell_ox
	var cy = int(round(py)) - _cell_oy
	if cx >= 0 and cy >= 0 and cy < elev_data.size() and cx < elev_data[cy].size():
		# Map 0-7 elevation to -6..+6 pixels offset
		return (elev_data[cy][cx] - 3.5) * 2.0
	return 0.0


## Check if a world position is on water (biome 0).
func _is_water_at(pos: Vector2) -> bool:
	var px = (pos.x / 64.0 + pos.y / 32.0) / 2.0
	var py = (pos.y / 32.0 - pos.x / 64.0) / 2.0
	var cx = int(round(px)) - _cell_ox
	var cy = int(round(py)) - _cell_oy
	
	# EXPLICIT water_map (most reliable — boolean from ProceduralGeneration)
	if not _water_map.is_empty() and cy >= 0 and cy < _water_map.size() and cx >= 0 and cx < _water_map[cy].size():
		return _water_map[cy][cx]
	
	# TileMapLayer fallback
	if _tilemap_layer != null:
		var sid = _tilemap_layer.get_cell_source_id(Vector2i(cx, cy))
		if sid == 5 or sid == 6:
			return true
	
	# biome_data last resort
	if not biome_data.is_empty() and cy >= 0 and cy < biome_data.size() and cx >= 0 and cx < biome_data[cy].size():
		return biome_data[cy][cx] == 0
	
	return false


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
		# Don't restart if the same animation is already playing — avoids
		# constant frame-reset when holding a movement key (60fps restart = levitation)
		if animated_sprite.animation != resolved or not animated_sprite.is_playing():
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
	# Stop movement when attacking
	_move_target = Vector2.INF
	velocity = Vector2.ZERO
	_state = State.ATTACK
	_update_animation(_last_direction)
	# Spawn arrow
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
func hurt(damage: int = 15) -> void:
	if _is_dead:
		return
	# Reduce health
	health = max(0, health - damage)
	_update_health_bar()
	_state = State.HURT
	_update_animation(_last_direction)
	# Flash rojo para que el hurt sea inmediatamente visible
	animated_sprite.modulate = Color(1.0, 0.4, 0.4)
	var tween := create_tween()
	tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.3)
	tween.set_trans(Tween.TRANS_SINE)
	if health <= 0:
		die()


func _update_health_bar():
	if not _health_bar_fill:
		return
	var ratio = float(health) / max_health
	_health_bar_fill.size.x = 36.0 * ratio
	# Color: green → yellow → red
	if ratio > 0.6:
		_health_bar_fill.color = Color(0.2, 0.9, 0.2, 0.9)
	elif ratio > 0.3:
		_health_bar_fill.color = Color(0.9, 0.8, 0.2, 0.9)
	else:
		_health_bar_fill.color = Color(0.9, 0.2, 0.2, 0.9)


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


## Spawn an AoE2-style movement pointer at the given world position.
## A ring that appears, shrinks, and fades out over ~0.8 seconds.
func _spawn_move_pointer(pos: Vector2) -> void:
	var ring = Sprite2D.new()
	ring.name = "MovePointer"
	ring.texture = _make_pointer_ring()
	ring.centered = true
	ring.position = pos
	ring.modulate = Color(1, 1, 1, 0.9)
	ring.z_index = 100
	get_parent().add_child(ring)
	
	# Animate: shrink and fade out
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(0.3, 0.3), 0.8)
	tween.tween_property(ring, "modulate:a", 0.0, 0.8)
	tween.chain().tween_callback(ring.queue_free)


## Create a simple ring texture for the movement pointer.
func _make_pointer_ring() -> Texture2D:
	var size := 48
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var dx := (x - size / 2.0) / (size / 2.0)
			var dy := (y - size / 2.0) / (size / 2.0)
			var dist := sqrt(dx * dx + dy * dy)
			var alpha := 0.0
			if dist >= 0.75 and dist <= 0.9:
				alpha = 1.0
			elif dist >= 0.72 and dist <= 0.75:
				alpha = 0.3  # soft inner edge
			img.set_pixel(x, y, Color(0.9, 0.9, 0.4, alpha))
	return ImageTexture.create_from_image(img)


## Health accessors for UI.
func get_health() -> int:
	return health

func get_max_health() -> int:
	return max_health

## Stop current movement immediately.
func stop_movement() -> void:
	_move_target = Vector2.INF
	velocity = Vector2.ZERO
	if _state in [State.IDLE, State.WALK]:
		_state = State.IDLE
		_update_animation(_last_direction)


## ── Selection ───────────────────────────────────────────

func is_selected() -> bool:
	return _selected

func set_selected(val: bool) -> void:
	_selected = val
	if _selection_ring:
		_selection_ring.visible = val


## Create a simple circular selection ring texture procedurally.
func _make_selection_ring() -> Texture2D:
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var dx := (x - size / 2.0) / (size / 2.0)
			var dy := (y - size / 2.0) / (size / 2.0)
			var dist := sqrt(dx * dx + dy * dy)
			var alpha := 0.0
			# Ring between dist 0.85 and 0.95
			if dist >= 0.85 and dist <= 0.95:
				alpha = 0.7
			# Green glow inside the ring (very subtle)
			elif dist < 0.85 and dist > 0.5:
				alpha = 0.08
			img.set_pixel(x, y, Color(0.2, 1.0, 0.3, alpha))
	return ImageTexture.create_from_image(img)


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
