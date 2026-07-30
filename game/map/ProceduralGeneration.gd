extends RefCounted
class_name ProceduralGeneration

## Procedural isometric terrain — all biomes unified to grass texture.
## Source 0 (grass) is the only FLUX.2 pro texture that rendered correctly.

enum Biome { WATER = 0, SAND = 1, GRASS = 2, DIRT = 3, MOUNTAIN = 4 }

# All biomas usan source 0 (grass) porque es la única textura
# que FLUX.2 pro generó correctamente. Las otras (shallow_water,
# sand, dirt) salieron con colores incorrectos.
const BIOME_SOURCE: Dictionary = {
	Biome.WATER: 0,     # all → grass
	Biome.SAND: 0,      # all → grass
	Biome.GRASS: 0,     # grass
	Biome.DIRT: 0,      # all → grass
	Biome.MOUNTAIN: 0,  # all → grass
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

	# 3 elevation layers — y_sort removed from parent, so offsets work now
	for elev in 3:
		var layer := TileMapLayer.new()
		layer.name = "Elevation" + str(elev)
		layer.position = Vector2(0, -elev * 32)
		if tile_set:
			layer.tile_set = tile_set

		var layer_count := 0
		for y in height:
			for x in width:
				if elev_map[y][x] != elev:
					continue
				# All biomes use source 0 (grass)
				layer.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))
				tile_count += 1
				layer_count += 1

		print("Elevation ", elev, ": ", layer_count, " tiles")
		layers.append(layer)

	return {
		"success": true,
		"biome_map": biome_map,
		"elev_map": elev_map,
		"layers": layers,
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
	# h ranges from ~-1 to ~1 for Perlin noise
	# Broader elevation 0 range for more base ground coverage
	if h < 0.0:
		return 0
	elif h < 0.5:
		return 1
	else:
		return 2


func _create_cliffs(biome_map: Array, elev_map: Array, width: int, height: int) -> Node2D:
	var node := Node2D.new()
	node.name = "Cliffs"
	node.y_sort_enabled = true
	for y in height:
		for x in width:
			var elev := elev_map[y][x] as int
			if elev == 0:
				continue
			var has_lower := false
			if x > 0 and (elev_map[y][x - 1] as int) < elev: has_lower = true
			if x + 1 < width and (elev_map[y][x + 1] as int) < elev: has_lower = true
			if y > 0 and (elev_map[y - 1][x] as int) < elev: has_lower = true
			if y + 1 < height and (elev_map[y + 1][x] as int) < elev: has_lower = true
			if has_lower:
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
