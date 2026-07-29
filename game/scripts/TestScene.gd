extends Node2D
## Escena de prueba con grid, personaje visible y movimiento WASD.
##
## Dibuja un piso cuadriculado para que se vea el movimiento,
## y carga el arquero desde el manifest.

@onready var unit_controller: UnitController = $UnitController

func _ready() -> void:
	var sprites := UnitSprites.load_from_manifest(
		"res://sprites/infanteria/arquero/_manifest.json"
	)
	if sprites:
		unit_controller.set_unit_sprites(sprites)
	else:
		push_error("TestScene: no se pudo cargar el manifest del arquero")
	
	queue_redraw()

func _draw() -> void:
	# Draw a grid floor so movement is visible
	var grid_color := Color(0.2, 0.35, 0.15, 0.6)   # green tint
	var line_color := Color(0.15, 0.25, 0.1, 0.4)    # darker grid lines
	var cell_size := 64
	
	var cam := unit_controller.get_node("Camera2D") as Camera2D
	if not cam or not cam.is_current():
		# No camera active — draw centered on origin
		var offset := Vector2(-960, -720)
		_draw_grid(offset, grid_color, line_color, cell_size)
		return
	
	# Draw a visible area around the camera
	var screen_center := get_viewport().get_camera_2d().get_screen_center_position()
	var top_left := screen_center - Vector2(960, 720) / 2
	_draw_grid(top_left, grid_color, line_color, cell_size)

func _draw_grid(offset: Vector2, grid_color: Color, line_color: Color, cell_size: int) -> void:
	var area := Vector2(1920, 1440)
	var cols := int(ceil(area.x / cell_size)) + 2
	var rows := int(ceil(area.y / cell_size)) + 2
	
	# Background fill
	draw_rect(Rect2(offset, area), grid_color)
	
	# Grid lines
	for x in range(cols):
		var xpos := offset.x + x * cell_size
		draw_line(Vector2(xpos, offset.y), Vector2(xpos, offset.y + area.y), line_color, 1.0)
	for y in range(rows):
		var ypos := offset.y + y * cell_size
		draw_line(Vector2(offset.x, ypos), Vector2(offset.x + area.x, ypos), line_color, 1.0)
