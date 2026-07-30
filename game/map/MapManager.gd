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
	RenderingServer.set_default_clear_color(Color("#4a7c3f"))

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)



	var tile_set := _build_tileset()
	if not tile_set:
		push_error("MapManager: Failed to build TileSet")
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

	# Coordinate overlay at bottom of screen
	_add_coord_overlay()

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


func _add_coord_overlay():
	## Add mouse coordinate display at bottom of screen
	var ui := CanvasLayer.new()
	ui.layer = 100
	ui.name = "CoordOverlay"
	
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.size = Vector2(1, 28)
	bg.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	ui.add_child(bg)
	
	var label := Label.new()
	label.name = "CoordLabel"
	label.text = "Move mouse over the map"
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_font_size_override("font_size", 14)
	label.position = Vector2(10, -22)
	bg.add_child(label)
	
	add_child(ui)
	
	# Store ref to label for _process updates
	_coord_label = label


var _coord_label: Label = null


func _process(_delta):
	if not _coord_label:
		return
	var mouse_pos := get_global_mouse_position()
	var cell := world_to_cell(mouse_pos)
	var biome_name := "?"
	if biome_map.size() > 0 and cell.y >= 0 and cell.y < biome_map.size() and cell.x >= 0 and cell.x < biome_map[cell.y].size():
		var b := biome_map[cell.y][cell.x] as int
		var names := ["WATER", "SAND", "GRASS", "DIRT", "MOUNTAIN"]
		if b >= 0 and b < names.size():
			biome_name = names[b]
	_coord_label.text = "Cell (%d,%d)  Biome: %s  World (%.0f,%.0f)" % [cell.x, cell.y, biome_name, mouse_pos.x, mouse_pos.y]


func _build_tileset() -> TileSet:
	## Build TileSet programmatically — bypass .tres file format issues
	var ts := TileSet.new()
	ts.tile_size = Vector2i(128, 64)
	ts.tile_shape = 1  # TILE_SHAPE_ISOMETRIC
	ts.tile_layout = 1  # TILE_LAYOUT_DIAMOND
	ts.tile_offset_axis = 0  # TILE_OFFSET_AXIS_HORIZONTAL

	# Load all terrain strips and create sources
	var terrain_textures := [
		{ "name": "grass",         "path": "res://sprites/terrain/strips/grass.png",         "source_id": 0 },
		{ "name": "dirt",          "path": "res://sprites/terrain/strips/dirt.png",          "source_id": 1 },
		{ "name": "sand",          "path": "res://sprites/terrain/strips/sand.png",          "source_id": 2 },
		{ "name": "path",          "path": "res://sprites/terrain/strips/path.png",          "source_id": 3 },
		{ "name": "forest_floor",  "path": "res://sprites/terrain/strips/forest_floor.png",  "source_id": 4 },
		{ "name": "shallow_water", "path": "res://sprites/terrain/strips/shallow_water.png", "source_id": 5 },
		{ "name": "deep_water",    "path": "res://sprites/terrain/strips/deep_water.png",    "source_id": 6 },
	]

	for t in terrain_textures:
		var tex := load(t.path) as Texture2D
		if not tex:
			push_error("Cannot load: ", t.path)
			continue
		var src := TileSetAtlasSource.new()
		src.texture = tex
		src.texture_region_size = Vector2i(128, 64)
		# Create 8 tiles in a row
		for i in range(8):
			src.create_tile(Vector2i(i, 0), Vector2i(1, 1))
		var sid := ts.add_source(src)
		print("  source ", sid, ": ", t.name)

	print("MapManager: TileSet built with ", len(terrain_textures), " sources")
	return ts







