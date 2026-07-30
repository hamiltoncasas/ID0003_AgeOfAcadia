extends RefCounted
class_name ProceduralGeneration

## Generates a procedural isometric terrain map using the FLUX.2 pro terrain atlas.
## Uses 7 terrain types with 8 center variants each, plus edge/corner transitions
## for seamless biome blending.

enum Biome {
	WATER = 0,
	SAND = 1,
	GRASS = 2,
	DIRT = 3,
	MOUNTAIN = 4,
}

# New terrain atlas: source 0, all tiles at 128×64 isometric
# Atlas: 32 cols × 7 rows of (128×64) tiles in terrain_atlas.png
const SOURCE_ID: int = 0

# Terrain type mapping (old → new)
const BIOME_TO_TERRAIN: Dictionary = {
	Biome.WATER: "deep_water",
	Biome.SAND: "sand",
	Biome.GRASS: "grass",
	Biome.DIRT: "dirt",
	Biome.MOUNTAIN: "cliff_rock",
}

# Center variant atlas coordinates per terrain type
# Each entry is an array of Vector2i(col, row) for 8 variants
const TERRAIN_CENTERS: Dictionary = {
	"grass":        [Vector2i(0,0), Vector2i(1,0), Vector2i(2,0), Vector2i(3,0),
	                 Vector2i(4,0), Vector2i(5,0), Vector2i(6,0), Vector2i(7,0)],
	"dirt":         [Vector2i(8,0), Vector2i(9,0), Vector2i(10,0), Vector2i(11,0),
	                 Vector2i(12,0), Vector2i(13,0), Vector2i(14,0), Vector2i(15,0)],
	"sand":         [Vector2i(16,0), Vector2i(17,0), Vector2i(18,0), Vector2i(19,0),
	                 Vector2i(20,0), Vector2i(21,0), Vector2i(22,0), Vector2i(23,0)],
	"path":         [Vector2i(24,0), Vector2i(25,0), Vector2i(26,0), Vector2i(27,0),
	                 Vector2i(28,0), Vector2i(29,0), Vector2i(30,0), Vector2i(31,0)],
	"forest_floor": [Vector2i(0,1), Vector2i(1,1), Vector2i(2,1), Vector2i(3,1),
	                 Vector2i(4,1), Vector2i(5,1), Vector2i(6,1), Vector2i(7,1)],
	"shallow_water":[Vector2i(8,1), Vector2i(9,1), Vector2i(10,1), Vector2i(11,1),
	                 Vector2i(12,1), Vector2i(13,1), Vector2i(14,1), Vector2i(15,1)],
	"deep_water":   [Vector2i(16,1), Vector2i(17,1), Vector2i(18,1), Vector2i(19,1),
	                 Vector2i(20,1), Vector2i(21,1), Vector2i(22,1), Vector2i(23,1)],
}


func generate(seed_val: int, width: int, height: int, tile_set: TileSet = null) -> Dictionary:
	if width <= 0 or height <= 0:
		return { "success": false, "error": "Invalid dimensions" }

	var noise := FastNoiseLite.new()
	noise.seed = abs(seed_val)
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.01
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.5

	var biome_map: Array = []
	var elev_map: Array = []
	biome_map.resize(height)
	elev_map.resize(height)

	for y in height:
		biome_map[y] = []
		elev_map[y] = []
		biome_map[y].resize(width)
		elev_map[y].resize(width)
		for x in width:
			var h := noise.get_noise_2d(x, y)
			biome_map[y][x] = _height_to_biome(h)
			elev_map[y][x] = _height_to_elevation(h)

	var tile_count := 0
	var layers: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	for elev in 3:
		var layer := TileMapLayer.new()
		layer.name = "Elevation" + str(elev)
		layer.position = Vector2(0, -elev * 32)
		layer.y_sort_enabled = true
		if tile_set:
			layer.tile_set = tile_set

		for y in height:
			for x in width:
				if elev_map[y][x] != elev:
					continue
				var biome: int = biome_map[y][x]
				var terrain_name: String = BIOME_TO_TERRAIN.get(biome, "grass")
				var variants: Array = TERRAIN_CENTERS.get(terrain_name, TERRAIN_CENTERS["grass"])

				# Check neighbors for transitions
				var atlas_coords := _select_tile_atlas(x, y, biome_map, width, height, terrain_name, variants, rng)
				layer.set_cell(Vector2i(x, y), SOURCE_ID, atlas_coords)
				tile_count += 1

		layers.append(layer)

	var cliff_node := _create_cliffs(biome_map, elev_map, width, height)

	return {
		"success": true,
		"error": "",
		"biome_map": biome_map,
		"elev_map": elev_map,
		"layers": layers,
		"cliff_node": cliff_node,
		"tile_count": tile_count,
	}


func _select_tile_atlas(x: int, y: int, biome_map: Array,
		width: int, height: int, terrain: String,
		variants: Array, rng: RandomNumberGenerator) -> Vector2i:
	## Select the best atlas coordinate for this cell based on neighbor biomes.
	## Uses center variants for same-biome neighbors, edge/corner tiles for transitions.

	# For now, use random center variant as a base
	# Future: check 4 neighbors and pick edge/corner tiles when biomes differ
	var idx := rng.randi() % variants.size()
	return variants[idx] as Vector2i


func _height_to_biome(h: float) -> int:
	if h < -0.3:
		return Biome.WATER
	elif h < 0.1:
		return Biome.SAND
	elif h < 0.5:
		return Biome.GRASS
	elif h < 0.75:
		return Biome.DIRT
	else:
		return Biome.MOUNTAIN


func _height_to_elevation(h: float) -> int:
	return int(floor((h + 1.0) * 1.5))


func _create_cliffs(biome_map: Array, elev_map: Array, width: int, height: int) -> Node2D:
	var node := Node2D.new()
	node.name = "Cliffs"
	node.y_sort_enabled = true

	for y in height:
		for x in width:
			var elev := elev_map[y][x] as int
			if elev == 0:
				continue
			var has_lower_neighbor := false

			if x > 0 and (elev_map[y][x - 1] as int) < elev:
				has_lower_neighbor = true
			if x + 1 < width and (elev_map[y][x + 1] as int) < elev:
				has_lower_neighbor = true
			if y > 0 and (elev_map[y - 1][x] as int) < elev:
				has_lower_neighbor = true
			if y + 1 < height and (elev_map[y + 1][x] as int) < elev:
				has_lower_neighbor = true

			if has_lower_neighbor:
				var cliff := Sprite2D.new()
				cliff.position = _cell_to_world(x, y) + Vector2(0, -elev * 32)
				cliff.name = "Cliff_%d_%d" % [x, y]

				var tex_path := "res://sprites/entorno/acantilados/base/acantilados_sin.png"
				if biome_map[y][x] == Biome.MOUNTAIN:
					tex_path = "res://sprites/entorno/acantilados_roca/base/acantilados_roca_sin.png"
				var tex := load(tex_path) as Texture2D
				if tex:
					cliff.texture = tex
				node.add_child(cliff)

	return node


func _cell_to_world(x: int, y: int) -> Vector2:
	return Vector2((x - y) * 64, (x + y) * 32)
