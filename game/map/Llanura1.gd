extends Node2D

func _ready():
	RenderingServer.set_default_clear_color(Color("#4a7c3f"))

	var ts = _build_tileset()
	if not ts:
		return

	var seed_val = randi()
	print("Seed: ", seed_val)

	# Generate 160x160 — fills the screen at zoom 0.12
	var gen = load("res://map/ProceduralGeneration.gd").new()
	var layer = gen.generate(seed_val, 160, 160, ts)
	if layer:
		add_child(layer)
	
	# Center camera on 160x160 grid
	var cam = get_node("Camera2D")
	if cam:
		cam.position = Vector2(0, 5120)
	
	print("Ready")


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
			continue
		var src = TileSetAtlasSource.new()
		src.texture = tex
		src.texture_region_size = Vector2i(128, 64)
		src.create_tile(Vector2i(0, 0), Vector2i(1, 1))
		ts.add_source(src)

	return ts
