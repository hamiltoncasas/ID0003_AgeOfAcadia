extends Node2D

const _ProceduralGeneration = preload("res://map/ProceduralGeneration.gd")
const _ObjectPlacer = preload("res://map/ObjectPlacer.gd")
const _ArrowPointer = preload("res://map/ArrowPointer.gd")
const _CellSelector = preload("res://map/CellSelector.gd")

@export var map_seed: int = 12345
@export var map_width: int = 120
@export var map_height: int = 120

var biome_map: Array = []
var elev_map: Array = []
var object_container: Node2D = null


func _ready():
	y_sort_enabled = true
	RenderingServer.set_default_clear_color(Color("#4a7c3f"))

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

	# Build TileSet programmatically from the terrain atlas
	# This avoids fragility in the .tres text format
	var tile_set := _build_terrain_tileset()
	if not tile_set:
		push_error("MapManager: Failed to build terrain TileSet")
		return

	var gen = _ProceduralGeneration.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed
	var result = gen.generate(map_seed, map_width, map_height, tile_set, source_id)
	if not result.success:
		push_error("MapManager: Generation failed: ", result.error)
		return

	biome_map = result.biome_map
	elev_map = result.elev_map

	# No flat base layer — elevation layers (0, 1, 2) already provide
	# proper per-biome terrain with correct y-offset for relief.
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

	# Clear objects around spawn so player starts in open field
	var spawn_cell := Vector2i(map_width / 2, map_height / 2)
	var clear_radius := 4
	for c in object_container.get_children():
		if c is StaticBody2D:
			var obj_cell := world_to_cell(c.position)
			if abs(obj_cell.x - spawn_cell.x) <= clear_radius and abs(obj_cell.y - spawn_cell.y) <= clear_radius:
				c.queue_free()

	# Player INSIDE ObjectContainer for proper isometric y-sort
	# No z_index override — y_sort determines depth naturally
	var player_scene := preload("res://map/units/PlayerUnit.tscn")
	var player := player_scene.instantiate()
	player.position = Vector2(0, 3840)
	player.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	object_container.add_child(player)



	var camera := get_node_or_null("CameraController")
	if camera:
		camera.map_size = Vector2i(map_width, map_height)
		camera.follow_target = player

	# Minimap must be in a CanvasLayer so its Control node positions
	# in screen space, not world space.
	var minimap_scene = preload("res://map/Minimap.tscn")
	var minimap = minimap_scene.instantiate()
	minimap.map_manager = self
	minimap.biome_map = result.biome_map
	minimap.map_width = map_width
	minimap.map_height = map_height
	minimap.player = player
	var ui_layer := CanvasLayer.new()
	ui_layer.name = "UILayer"
	ui_layer.layer = 10
	ui_layer.add_child(minimap)
	add_child(ui_layer)

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


func _build_terrain_tileset() -> TileSet:
	## Build TileSet programmatically from the terrain atlas.
	## Creates isometric 128x64 tiles from terrain_atlas.png.
	var atlas_tex := load("res://sprites/terrain/terrain_atlas.png") as Texture2D
	if not atlas_tex:
		push_error("MapManager: Cannot load terrain_atlas.png")
		return null

	var atlas_size := atlas_tex.get_size()
	var tile_w := 128
	var tile_h := 64
	var cols := int(atlas_size.x / tile_w)
	var rows := int(atlas_size.y / tile_h)

	var ts := TileSet.new()
	ts.tile_size = Vector2i(tile_w, tile_h)
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND

	var source := TileSetAtlasSource.new()
	source.texture = atlas_tex
	source.texture_region_size = Vector2i(tile_w, tile_h)

	# Add all non-empty tiles to the atlas source
	var added := 0
	for r in rows:
		for c in range(cols):
			# Check if this tile has any non-transparent pixels
			# by sampling the center pixel (avoids edge artifacts)
			var at_coords := Vector2i(c, r)
			source.create_tile(at_coords, Vector2i(1, 1))
			added += 1

	source_id = ts.add_source(source)
	print("MapManager: TileSet built with ", added, " tiles from ", cols, "x", rows, " atlas")

	return ts


var source_id: int = -1




