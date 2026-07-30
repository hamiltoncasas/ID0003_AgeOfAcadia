extends RefCounted
class_name NavigationSystem

## A* pathfinding on the isometric biome grid.
## Builds a graph from biome_map where water (0) = blocked, desert/plain (1,2) = walkable.
## Uses Godot's built-in AStar2D for pathfinding.

var _astar: AStar2D = null
var _width: int = 0
var _height: int = 0
var _cell_ox: int = -100
var _cell_oy: int = -100

## Build navigation graph from biome_map.
## Only walkable cells (biome != 0) are added as nodes.
func build(biome_map: Array) -> void:
	_astar = AStar2D.new()
	_height = biome_map.size()
	if _height == 0:
		return
	_width = biome_map[0].size()
	if _width == 0:
		return

	var id := 0
	# First pass: add all walkable cells
	for y in range(_height):
		for x in range(_width):
			var biome = biome_map[y][x] as int
			if biome != 0:  # not water
				_astar.add_point(id, Vector2(x, y))
			id += 1

	# Second pass: connect adjacent walkable cells (8-direction)
	id = 0
	var neighbors = [
		[-1, 0], [1, 0], [0, -1], [0, 1],
		[-1, -1], [1, -1], [-1, 1], [1, 1],
	]
	for y in range(_height):
		for x in range(_width):
			if biome_map[y][x] as int != 0:  # walkable
				for n in neighbors:
					var nx = x + n[0]
					var ny = y + n[1]
					if nx >= 0 and nx < _width and ny >= 0 and ny < _height:
						if biome_map[ny][nx] as int != 0:
							var nid = ny * _width + nx
							_astar.connect_points(id, nid, true)
			id += 1

## Find a path from world_pos to target_pos.
## Returns Array of Vector2 waypoints in world coordinates, or empty if no path.
func find_path(from_world: Vector2, to_world: Vector2) -> Array:
	if _astar == null:
		return []

	# Convert world to grid coords
	var from_id = _world_to_id(from_world)
	var to_id = _world_to_id(to_world)
	if from_id < 0 or to_id < 0:
		return []

	# If target is water or unreachable, find nearest walkable cell
	if not _astar.has_point(to_id):
		to_id = _find_nearest_walkable(to_world)
		if to_id < 0:
			return []

	if not _astar.has_point(from_id):
		from_id = _find_nearest_walkable(from_world)
		if from_id < 0:
			return []

	# Calculate path
	var path_ids = _astar.get_id_path(from_id, to_id)
	if path_ids.is_empty():
		return []

	# Convert to world coordinates
	var path := []
	for pid in path_ids:
		var grid_pos = _astar.get_point_position(pid)
		var tile_x = grid_pos.x + _cell_ox
		var tile_y = grid_pos.y + _cell_oy
		var world = Vector2(
			(tile_x - tile_y) * 64,
			(tile_x + tile_y) * 32
		)
		path.append(world)
	return path


## Convert world position to grid point ID.
func _world_to_id(world: Vector2) -> int:
	var px = (world.x / 64.0 + world.y / 32.0) / 2.0
	var py = (world.y / 32.0 - world.x / 64.0) / 2.0
	var cx = int(round(px)) - _cell_ox
	var cy = int(round(py)) - _cell_oy
	if cx >= 0 and cx < _width and cy >= 0 and cy < _height:
		return cy * _width + cx
	return -1


## Find nearest walkable cell to a world position.
func _find_nearest_walkable(world: Vector2) -> int:
	var cx = int(round((world.x / 64.0 + world.y / 32.0) / 2.0)) - _cell_ox
	var cy = int(round((world.y / 32.0 - world.x / 64.0) / 2.0)) - _cell_oy
	# Search outward in expanding square
	for r in range(1, 20):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var nx = cx + dx
				var ny = cy + dy
				if nx >= 0 and nx < _width and ny >= 0 and ny < _height:
					var nid = ny * _width + nx
					if _astar.has_point(nid):
						return nid
	return -1
