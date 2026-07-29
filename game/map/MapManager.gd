extends Node2D

const _ProceduralGeneration = preload("res://map/ProceduralGeneration.gd")
const _ObjectPlacer = preload("res://map/ObjectPlacer.gd")
const _ArrowPointer = preload("res://map/ArrowPointer.gd")
const _CellSelector = preload("res://map/CellSelector.gd")

@export var map_seed: int = 12345
@export var map_width: int = 400
@export var map_height: int = 400

var biome_map: Array = []
var elev_map: Array = []
var object_container: Node2D = null


func _ready():
	y_sort_enabled = true
	RenderingServer.set_default_clear_color(Color("#4a7c3f"))

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

	var tile_set := load("res://map/terrain.tres") as TileSet
	if not tile_set:
		push_error("MapManager: Failed to load terrain.tres")
		return

	var gen = _ProceduralGeneration.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed
	var result = gen.generate(map_seed, map_width, map_height, tile_set)
	if not result.success:
		push_error("MapManager: Generation failed: ", result.error)
		return

	biome_map = result.biome_map
	elev_map = result.elev_map

	var base_layer := TileMapLayer.new()
	base_layer.name = "BaseTerrain"
	base_layer.tile_set = tile_set
	for y in map_height:
		for x in map_width:
			base_layer.set_cell(Vector2i(x, y), 0, Vector2i(x % 2, y % 4))
	add_child(base_layer)

	var layers = result.layers
	for layer in layers:
		add_child(layer)
	if result.cliff_node:
		add_child(result.cliff_node)

	object_container = Node2D.new()
	object_container.name = "ObjectContainer"
	object_container.y_sort_enabled = true
	add_child(object_container)

	var placer = _ObjectPlacer.new()
	var place_result = placer.place_objects(result.biome_map, result.elev_map, rng, object_container)
	print("MapManager: ", map_width, "x", map_height, " - ", result.tile_count, " tiles, ", place_result.count, " objects")
	if not place_result.warnings.is_empty():
		for warn in place_result.warnings:
			push_warning("MapManager: ", warn)

	# Player INSIDE ObjectContainer for proper isometric y-sort
	# No z_index override — y_sort determines depth naturally
	var player_scene := preload("res://map/units/PlayerUnit.tscn")
	var player := player_scene.instantiate()
	player.position = Vector2(0, 12800)
	player.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	object_container.add_child(player)



	var camera := get_node_or_null("CameraController")
	if camera:
		camera.map_size = Vector2i(map_width, map_height)
		camera.follow_target = player

	var selector := _CellSelector.new()
	selector.name = "CellSelector"
	selector.map_manager = self
	add_child(selector)

	var arrow := _ArrowPointer.new()
	arrow.name = "ArrowPointer"
	arrow.map_manager = self
	add_child(arrow)


func get_biome(cell: Vector2i) -> int:
	if biome_map.is_empty():
		return -1
	if cell.y < 0 or cell.y >= biome_map.size():
		return -1
	if cell.x < 0 or cell.x >= biome_map[cell.y].size():
		return -1
	return biome_map[cell.y][cell.x] as int


func get_elevation(cell: Vector2i) -> int:
	if elev_map.is_empty():
		return -1
	if cell.y < 0 or cell.y >= elev_map.size():
		return -1
	if cell.x < 0 or cell.x >= elev_map[cell.y].size():
		return -1
	return elev_map[cell.y][cell.x] as int


func world_to_cell(pos: Vector2) -> Vector2i:
	var x := int(round((pos.x / 64.0 + pos.y / 32.0) / 2.0))
	var y := int(round((pos.y / 32.0 - pos.x / 64.0) / 2.0))
	return Vector2i(x, y)


func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2((cell.x - cell.y) * 64, (cell.x + cell.y) * 32)



