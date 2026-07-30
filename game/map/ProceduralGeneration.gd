extends RefCounted

func generate(seed, w, h, ts):
	var rng = RandomNumberGenerator.new()
	rng.seed = seed

	# Noises
	var noise = FastNoiseLite.new()
	noise.seed = abs(seed * 7)
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.02
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	noise.fractal_gain = 0.5

	var detail = FastNoiseLite.new()
	detail.seed = abs(seed * 13 + 7)
	detail.noise_type = FastNoiseLite.TYPE_PERLIN
	detail.frequency = 0.05

	# Elevation noise (separate from biome)
	var elev_noise = FastNoiseLite.new()
	elev_noise.seed = abs(seed * 3 + 1)
	elev_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	elev_noise.frequency = 0.03
	elev_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	elev_noise.fractal_octaves = 2
	elev_noise.fractal_gain = 0.5

	var river_noise = FastNoiseLite.new()
	river_noise.seed = abs(seed * 31)
	river_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	river_noise.frequency = 0.008

	var river_cells = _generate_river(w, h, rng, river_noise)

	var ox = -100
	var oy = -100

	# Step 1: Generate biome + elevation maps
	var elev_map = []
	var biome_map = []
	for y in range(h):
		elev_map.append([])
		biome_map.append([])
		for x in range(w):
			var val = noise.get_noise_2d(x, y)
			var det = detail.get_noise_2d(x, y) * 0.15
			var hval = val + det
			var elev = elev_noise.get_noise_2d(x, y)
			biome_map[y].append(hval)
			# Elevation: 0, 1, or 2
			if elev < -0.3:
				elev_map[y].append(0)
			elif elev < 0.3:
				elev_map[y].append(1)
			else:
				elev_map[y].append(2)

	# Step 2: Place terrain tiles
	var layer = TileMapLayer.new()
	layer.tile_set = ts
	var count = 0
	for y in range(h):
		for x in range(w):
			var pos = Vector2i(x + ox, y + oy)
			var hval = biome_map[y][x]
			var sid = 0
			if river_cells.has(Vector2i(x, y)):
				sid = 6
			elif hval < -0.25:
				sid = 6
			elif hval < -0.1:
				sid = 5
			elif hval < 0.05:
				sid = 2
			elif hval < 0.35:
				sid = 0
			elif hval < 0.5:
				sid = 1
			elif hval < 0.6:
				sid = 4
			elif hval < 0.7:
				sid = 3
			else:
				sid = 1
			if sid != 6 and rng.randf() < 0.03:
				sid = 0
			layer.set_cell(pos, sid, Vector2i(0, 0))
			count += 1

	# Step 3: Create elevation edge markers
	var edges = Node2D.new()
	edges.name = "Edges"
	var edge_count = 0

	# Edge texture: semi-transparent brown strip
	var edge_tex = _make_edge_texture(128, 32, Color(0.4, 0.25, 0.15, 0.7))
	var deep_edge_tex = _make_edge_texture(128, 48, Color(0.3, 0.15, 0.08, 0.8))

	for y in range(h):
		for x in range(w):
			var elev = elev_map[y][x]
			var world_pos = _cell_to_world(x + ox, y + oy)

			# Check 4 neighbors for elevation changes
			var checks = [
				[x-1, y, -1, 0],  # West neighbor
				[x+1, y, 1, 0],   # East neighbor  
				[x, y-1, 0, -1],  # North neighbor
				[x, y+1, 0, 1],   # South neighbor
			]
			for c in checks:
				var nx = c[0]
				var ny = c[1]
				if nx < 0 or nx >= w or ny < 0 or ny >= h:
					continue
				var n_elev = elev_map[ny][nx]
				if n_elev == elev:
					continue

				# Different elevation — place edge marker
				var sprite = Sprite2D.new()
				sprite.texture = deep_edge_tex if abs(elev - n_elev) > 1 else edge_tex
				sprite.centered = true
				sprite.z_index = -1  # Behind terrain tiles

				# Position at boundary between cells
				var offset_x = c[2] * 64  # Half tile offset
				var offset_y = c[3] * 16
				sprite.position = world_pos + Vector2(offset_x, offset_y)
				edges.add_child(sprite)
				edge_count += 1

	print("Tiles: ", count, " river: ", river_cells.size(), " edges: ", edge_count)

	# Return array of nodes: [edges_node, terrain_layer]
	return [edges, layer]


func _make_edge_texture(w, h, color):
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		var alpha = color.a
		if y < 2:
			alpha = 0.0
		elif y < 6:
			alpha = color.a * 0.5
		# else: full alpha
		var c = Color(color.r, color.g, color.b, alpha)
		for x in range(w):
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


func _generate_river(w, h, rng, noise):
	var cells = {}
	var start_x = rng.randi_range(int(w * 0.1), int(w * 0.9))
	var start_y = 0
	var end_x = rng.randi_range(int(w * 0.1), int(w * 0.9))
	var end_y = h - 1
	if rng.randf() > 0.5:
		start_x = 0
		start_y = rng.randi_range(int(h * 0.1), int(h * 0.9))
		end_x = w - 1
		end_y = rng.randi_range(int(h * 0.1), int(h * 0.9))
	var pos = Vector2i(start_x, start_y)
	var target = Vector2i(end_x, end_y)
	var max_steps = int(max(w, h) * 2)
	var step = 0
	while pos.distance_squared_to(target) > 9.0 and step < max_steps:
		var rw = rng.randi_range(1, 2)
		for dx in range(-rw, rw + 1):
			for dy in range(-rw, rw + 1):
				var np = Vector2i(pos.x + dx, pos.y + dy)
				if np.x >= 0 and np.x < w and np.y >= 0 and np.y < h:
					cells[np] = true
		var dx = sign(target.x - pos.x)
		var dy = sign(target.y - pos.y)
		var n = noise.get_noise_2d(pos.x, pos.y) * 3.0
		if rng.randf() < 0.6:
			pos.x += dx
		else:
			pos.x += int(round(n))
		if rng.randf() < 0.6:
			pos.y += dy
		else:
			pos.y += int(round(n * 0.7))
		pos.x = clampi(pos.x, 3, w - 4)
		pos.y = clampi(pos.y, 3, h - 4)
		step += 1
	return cells


func _cell_to_world(x, y):
	return Vector2((x - y) * 64, (x + y) * 32)
