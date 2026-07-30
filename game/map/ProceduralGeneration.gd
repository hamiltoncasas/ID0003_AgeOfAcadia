extends RefCounted

## Generates terrain with biomes + rivers + lakes
## Sources: 0=grass, 1=dirt, 2=sand, 3=path, 4=forest_floor, 5=shallow_water, 6=deep_water


func generate(seed, w, h, ts):
	var rng = RandomNumberGenerator.new()
	rng.seed = seed
	
	var noise = FastNoiseLite.new()
	noise.seed = abs(seed * 7 + 13)
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.008
	
	var river_noise = FastNoiseLite.new()
	river_noise.seed = abs(seed * 31 + 7)
	river_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	river_noise.frequency = 0.005

	var height_noise = FastNoiseLite.new()
	height_noise.seed = abs(seed * 3)
	height_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	height_noise.frequency = 0.006
	height_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	height_noise.fractal_octaves = 3

	var layer = TileMapLayer.new()
	layer.tile_set = ts

	# Step 1: Generate base heightmap + biome
	var height_map = []
	var biome_map = []
	for y in range(h):
		height_map.append([])
		biome_map.append([])
		for x in range(w):
			var val = noise.get_noise_2d(x, y)
			var hval = height_noise.get_noise_2d(x, y)
			height_map[y].append(hval)
			var bm = 2  # default grass
			if val < -0.25:
				bm = 0  # water
			elif val < 0.1:
				bm = 1  # sand
			elif val < 0.5:
				bm = 2  # grass
			elif val < 0.7:
				bm = 3  # dirt
			else:
				bm = 4  # mountain
			biome_map[y].append(bm)

	# Step 2: Generate river path
	var river_cells = {}
	
	# Choose river start/end on random edges (0=left, 1=top, 2=right, 3=bottom)
	# Randomly pick start/end edges (no shuffle — RandomNumberGenerator has no shuffle)
	var edge_order = [0, 1, 2, 3]
	var e1 = rng.randi_range(0, 3)
	var e2 = rng.randi_range(0, 3)
	while e2 == e1:
		e2 = rng.randi_range(0, 3)
	var start_edge = edge_order[e1]
	var end_edge = edge_order[e2]
	
	var start_pos = _random_edge_pos(w, h, start_edge, rng)
	var end_pos = _random_edge_pos(w, h, end_edge, rng)
	
	# River width
	var river_width = rng.randi_range(1, 2)
	
	# Generate river as a path from start to end
	var river = _generate_river(start_pos, end_pos, w, h, river_noise, rng)
	for cell in river:
		river_cells[cell] = true
		# Add width
		for dw in range(-river_width, river_width + 1):
			for dh in range(-river_width, river_width + 1):
				if abs(dw) + abs(dh) <= river_width:
					var nc = Vector2i(cell.x + dw, cell.y + dh)
					if nc.x >= 0 and nc.x < w and nc.y >= 0 and nc.y < h:
						river_cells[nc] = true

	# Step 3: Create lakes in low areas (height < -0.4)
	var lake_cells = {}
	for y in range(h):
		for x in range(w):
			if height_map[y][x] < -0.4 and biome_map[y][x] == 0:
				lake_cells[Vector2i(x, y)] = true

	# Step 4: Place tiles
	var count = 0
	for y in range(h):
		for x in range(w):
			var pos = Vector2i(x, y)
			var sid = 0  # default grass
			
			if river_cells.has(pos):
				sid = 6  # deep_water for rivers
			elif lake_cells.has(pos):
				sid = 6  # deep_water for lakes
			else:
				var bm = biome_map[y][x]
				if bm == 0:
					sid = 6  # deep_water
				elif bm == 1:
					sid = 2  # sand
				elif bm == 3:
					sid = 1  # dirt
				elif bm == 4:
					sid = 2  # mountain → sand
				else:
					sid = 0  # grass
			
			layer.set_cell(pos, sid, Vector2i(0, 0))
			count += 1

	print("Tiles: ", count, " river: ", river_cells.size(), " lakes: ", lake_cells.size())
	return layer


func _random_edge_pos(w, h, edge, rng):
	match edge:
		0:  return Vector2i(0, rng.randi_range(10, h-10))
		1:  return Vector2i(rng.randi_range(10, w-10), 0)
		2:  return Vector2i(w-1, rng.randi_range(10, h-10))
		3:  return Vector2i(rng.randi_range(10, w-10), h-1)
	return Vector2i(0, 0)


func _generate_river(start, end, w, h, noise, rng):
	## Generate a river path using a simple directed random walk
	var cells = []
	var pos = start
	var target = end
	var max_steps = max(w, h) * 3
	var step = 0
	
	while pos.distance_to(target) > 2.0 and step < max_steps:
		cells.append(pos)
		step += 1
		
		# Direction toward target
		var dir = Vector2i(
			sign(target.x - pos.x),
			sign(target.y - pos.y)
		)
		
		# Add noise-based meandering
		var n = noise.get_noise_2d(pos.x, pos.y) * 3.0
		var meander = Vector2i(round(n), round(n * 0.7))
		
		# Try to move toward target with meander
		var candidates = []
		if dir.x != 0:
			candidates.append(Vector2i(dir.x, 0))
		if dir.y != 0:
			candidates.append(Vector2i(0, dir.y))
		candidates.append(meander)
		
		# Pick one
		var move = candidates[rng.randi() % candidates.size()]
		var new_pos = pos + move
		
		# Clamp to map bounds
		new_pos.x = clampi(new_pos.x, 1, w-2)
		new_pos.y = clampi(new_pos.y, 1, h-2)
		
		pos = new_pos
	
	cells.append(target)
	return cells
