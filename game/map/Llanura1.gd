extends Node2D

func _ready():
	RenderingServer.set_default_clear_color(Color("#6b8f4e"))

	var tile_set = _build_tileset()
	if not tile_set:
		return

	var seed_val = randi()
	print("Map seed: ", seed_val)

	var gen = load("res://map/ProceduralGeneration.gd").new()
	# Generate at 240x240 with offset so the camera sees varied terrain
	var layer = gen.generate(seed_val, 160, 160, tile_set)
	if layer:
		add_child(layer)
		print("Ready")
	else:
		print("ERROR: generation failed")


func _build_tileset():
	var ts = TileSet.new()
	ts.tile_size = Vector2i(128, 64)
	ts.tile_shape = 1
	ts.tile_layout = 1

	for path in [
		"res://sprites/terrain/strips/grass.png",
		"res://sprites/terrain/strips/dirt.png",
		"res://sprites/terrain/strips/sand.png",
		"res://sprites/terrain/strips/path.png",
		"res://sprites/terrain/strips/forest_floor.png",
		"res://sprites/terrain/strips/shallow_water.png",
		"res://sprites/terrain/strips/deep_water.png",
	]:
		var tex = load(path)
		if not tex:
			push_error("Cannot load: ", path)
			continue
		var src = TileSetAtlasSource.new()
		src.texture = tex
		src.texture_region_size = Vector2i(128, 64)
		src.create_tile(Vector2i(0, 0), Vector2i(1, 1))
		ts.add_source(src)

	return ts
