extends Node2D

var map_manager: Node = null


func _draw():
	var outer := 14.0
	var inner := 6.0
	var gap := 2.0

	draw_circle(Vector2.ZERO, outer, Color(1, 0, 0, 0.35))
	draw_circle(Vector2.ZERO, inner, Color(1, 1, 1, 0.5))
	draw_arc(Vector2.ZERO, outer + gap, 0, TAU, 32, Color(1, 1, 1, 0.6), 1.5)
	draw_arc(Vector2.ZERO, inner - gap, 0, TAU, 32, Color(0, 0, 0, 0.4), 1.0)

	var cl := 8.0
	draw_line(Vector2(-cl, 0), Vector2(cl, 0), Color(1, 0, 0, 0.7), 1.5)
	draw_line(Vector2(0, -cl), Vector2(0, cl), Color(1, 0, 0, 0.7), 1.5)


func _process(_delta):
	var mouse := get_global_mouse_position()
	if map_manager:
		var cell: Vector2i = map_manager.world_to_cell(mouse)
		position = map_manager.cell_to_world(cell)
