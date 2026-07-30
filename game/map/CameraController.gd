extends Camera2D

@export var map_size: Vector2i = Vector2i(300, 300)
@export var follow_target: Node2D = null
@export var drag_button: int = MOUSE_BUTTON_MIDDLE

const ZOOM_MIN: float = 0.08
const ZOOM_MAX: float = 3.0
const ZOOM_STEP: float = 0.1
const FOLLOW_MARGIN_RATIO: float = 0.25
const FOLLOW_SPEED: float = 12.0
const SCROLL_SPEED: float = 600.0

const DRAG_THRESHOLD: float = 5.0  # pixels before drag starts

var _dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _cam_start: Vector2 = Vector2.ZERO


func _ready():
	position_smoothing_enabled = false
	zoom = Vector2(0.13, 0.13)


func _unhandled_input(event: InputEvent):
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_MIDDLE:
				if event.pressed:
					_dragging = true
					_drag_start = event.position
					_cam_start = position
				else:
					_dragging = false
			MOUSE_BUTTON_RIGHT:
				# Right-click is for unit movement — just ignore here
				pass
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					_zoom(ZOOM_STEP)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					_zoom(-ZOOM_STEP)
	if event is InputEventMouseMotion:
		if _dragging:
			var dist = event.position.distance_to(_drag_start)
			if dist > DRAG_THRESHOLD:
				var delta: Vector2 = (event.position - _drag_start) * zoom
				position = _cam_start - delta
				_clamp_position()


func _process(delta: float):
	# Scroll with arrow keys — works regardless of follow_target
	var scroll_dir := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down"),
	)
	var _scrolling := _dragging or (scroll_dir != Vector2.ZERO)

	if _scrolling:
		# Manual scroll overrides follow
		if scroll_dir != Vector2.ZERO:
			position += scroll_dir * SCROLL_SPEED * delta / zoom.x
			_clamp_position()
		# Don't apply follow when user is manually scrolling

	if Input.is_action_just_pressed("zoom_in"):
		_zoom(ZOOM_STEP)
	if Input.is_action_just_pressed("zoom_out"):
		_zoom(-ZOOM_STEP)

	if follow_target and not _scrolling:
		var view_size := get_viewport_rect().size / zoom
		var margin := view_size * FOLLOW_MARGIN_RATIO
		var offset := follow_target.global_position - global_position
		var target_pos := global_position

		if offset.x > margin.x:
			target_pos.x = follow_target.global_position.x - margin.x
		elif offset.x < -margin.x:
			target_pos.x = follow_target.global_position.x + margin.x

		if offset.y > margin.y:
			target_pos.y = follow_target.global_position.y - margin.y
		elif offset.y < -margin.y:
			target_pos.y = follow_target.global_position.y + margin.y

		global_position = global_position.lerp(target_pos, FOLLOW_SPEED * delta)
		_clamp_position()


func _zoom(delta: float):
	zoom = Vector2(
		clampf(zoom.x + delta, ZOOM_MIN, ZOOM_MAX),
		clampf(zoom.y + delta, ZOOM_MIN, ZOOM_MAX),
	)
	_clamp_position()


func _clamp_position():
	var half_w := map_size.x * 64.0
	var full_h := map_size.y * 64.0
	var view_size := get_viewport_rect().size / zoom
	var margin := view_size / 2.0

	var min_x := -half_w + margin.x
	var max_x := half_w - margin.x
	var center_x := 0.0

	var min_y := -32.0 + margin.y
	var max_y := full_h - 32.0 - margin.y
	var center_y := full_h / 2.0 - 32.0

	if min_x > max_x:
		position.x = center_x
	else:
		position.x = clampf(position.x, min_x, max_x)

	if min_y > max_y:
		position.y = center_y
	else:
		position.y = clampf(position.y, min_y, max_y)
