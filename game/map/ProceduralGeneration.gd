extends RefCounted
class_name ProceduralGeneration

## Simplified procedural terrain — single layer, all grass.
enum Biome { WATER = 0, SAND = 1, GRASS = 2, DIRT = 3, MOUNTAIN = 4 }


func generate(seed_val: int, width: int, height: int, tile_set: TileSet = null) -> Dictionary:
	if width <= 0 or height <= 0:
		return { "success": false, "error": "Invalid dimensions" }

	var biome_map: Array = []
	var elev_map: Array = []
	biome_map.resize(height)
	elev_map.resize(height)

	var noise := FastNoiseLite.new()
	noise.seed = abs(seed_val)
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.01
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.5

	for y in height:
		biome_map[y] = []
		elev_map[y] = []
		biome_map[y].resize(width)
		elev_map[y].resize(width)
		for x in width:
			var h := noise.get_noise_2d(x, y)
			biome_map[y][x] = _height_to_biome(h)
			elev_map[y][x] = _height_to_elevation(h)

	# Single terrain layer — no elevation splits
	var layer := TileMapLayer.new()
	layer.name = "Terrain"
	layer.y_sort_enabled = true
	if tile_set:
		layer.tile_set = tile_set

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var tile_count := 0

	for y in height:
		for x in width:
			var variant := rng.randi() % 8
			layer.set_cell(Vector2i(x, y), 0, Vector2i(variant, 0))
			tile_count += 1

	return {
		"success": true,
		"biome_map": biome_map,
		"elev_map": elev_map,
		"layers": [layer],
		"cliff_node": null,
		"tile_count": tile_count,
	}


func _height_to_biome(h: float) -> int:
	if h < -0.3:    return Biome.WATER
	elif h < 0.1:   return Biome.SAND
	elif h < 0.5:   return Biome.GRASS
	elif h < 0.75:  return Biome.DIRT
	else:           return Biome.MOUNTAIN


func _height_to_elevation(h: float) -> int:
	return int(floor((h + 1.0) * 1.5))


func _cell_to_world(x: int, y: int) -> Vector2:
	return Vector2((x - y) * 64, (x + y) * 32)
