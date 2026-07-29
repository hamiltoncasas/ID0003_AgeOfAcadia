extends Node2D

var map_manager: Node = null


func _draw():
	var points := PackedVector2Array([
		Vector2(0, -32),
		Vector2(64, 0),
		Vector2(0, 32),
		Vector2(-64, 0),
	])
	draw_colored_polygon(points, Color(1, 1, 0, 0.25))
	draw_polyline(points, Color(1, 1, 0, 0.7), 2.0)
	draw_line(points[0], points[2], Color(1, 1, 0, 0.7), 2.0)


func _process(_delta):
	if not map_manager:
		return
	var mouse := get_global_mouse_position()
	var cell: Vector2i = map_manager.world_to_cell(mouse)
	position = map_manager.cell_to_world(cell)
