extends Node2D

## Minimal MapManager — terrain only, no objects or UI

const _ProceduralGeneration = preload("res://map/ProceduralGeneration.gd")

@export var map_seed: int = 12345
@export var map_width: int = 120
@export var map_height: int = 120


func _ready():
	RenderingServer.set_default_clear_color(Color("#4a7c3f"))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

	var tile_set := _build_tileset()
	if not tile_set:
		push_error("MapManager: Failed to build TileSet")
		return

	var gen = _ProceduralGeneration.new()
	var result = gen.generate(map_seed, map_width, map_height, tile_set)
	if not result.success:
		push_error("MapManager: Generation failed: ", result.error)
		return

	var layers = result.layers
	for layer in layers:
		add_child(layer)

	var camera := get_node_or_null("CameraController")
	if camera:
		camera.map_size = Vector2i(map_width, map_height)
	
	print("MapManager: Terrain ready — ", result.tile_count, " tiles")


func _build_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(128, 64)
	ts.tile_shape = 1
	ts.tile_layout = 1
	ts.tile_offset_axis = 0

	var textures := [
		"res://sprites/terrain/strips/grass.png",
		"res://sprites/terrain/strips/dirt.png",
		"res://sprites/terrain/strips/sand.png",
		"res://sprites/terrain/strips/path.png",
		"res://sprites/terrain/strips/forest_floor.png",
		"res://sprites/terrain/strips/shallow_water.png",
		"res://sprites/terrain/strips/deep_water.png",
	]

	for path in textures:
		var tex := load(path) as Texture2D
		if not tex:
			push_error("Cannot load: ", path)
			continue
		var src := TileSetAtlasSource.new()
		src.texture = tex
		src.texture_region_size = Vector2i(128, 64)
		for i in range(8):
			src.create_tile(Vector2i(i, 0), Vector2i(1, 1))
		ts.add_source(src)

	return ts
