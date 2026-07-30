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
	elev_noise.frequency = 0.025
	elev_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	elev_noise.fractal_octaves = 3
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
			# Elevation: 0, 1, 2, or 3 (smooth hills)
			if elev < -0.4:
				elev_map[y].append(0)
			elif elev < 0.0:
				elev_map[y].append(1)
			elif elev < 0.4:
				elev_map[y].append(2)
			else:
				elev_map[y].append(3)

	# Debug elevation counts
	var e0 = 0; var e1 = 0; var e2 = 0
	for y in range(h):
		for x in range(w):
			var e = elev_map[y][x]
			if e == 0: e0 += 1
			elif e == 1: e1 += 1
			else: e2 += 1
	print("Elev: 0=", e0, " 1=", e1, " 2=", e2)

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

	# Step 3: Create smooth height overlay (hills)
	var heights = Node2D.new()
	heights.name = "HeightOverlay"
	var height_count = 0

	# Pre-create overlay textures for each level
	var overlay_texs = []
	var colors = [
		Color(0.3, 0.4, 0.2, 0.15),  # level 0: dark green (low)
		Color(0.5, 0.6, 0.3, 0.0),   # level 1: transparent (base)
		Color(0.8, 0.7, 0.4, 0.1),   # level 2: warm gold
		Color(0.9, 0.6, 0.2, 0.2),   # level 3: bright orange (high)
	]
	for c in colors:
		overlay_texs.append(_make_smooth_overlay(128, 64, c))

	for y in range(h):
		for x in range(w):
			var elev = elev_map[y][x]
			# Skip level 1 (base ground, no overlay)
			if elev == 1:
				continue
			var tex = overlay_texs[elev]
			var world_pos = _cell_to_world(x + ox, y + oy)
			var sprite = Sprite2D.new()
			sprite.texture = tex
			sprite.centered = true
			sprite.position = world_pos
			heights.add_child(sprite)
			height_count += 1

	# Step 4: Contour lines ON TOP of everything
	var contours = Node2D.new()
	contours.name = "Contours"
	var contour_count = 0
	var ct = _make_contour_tex()

	for y in range(h):
		for x in range(w):
			var elev = elev_map[y][x]
			var world_pos = _cell_to_world(x + ox, y + oy)
			for c in [[x-1, y], [x+1, y], [x, y-1], [x, y+1]]:
				var nx = c[0]; var ny = c[1]
				if nx < 0 or nx >= w or ny < 0 or ny >= h:
					continue
				if elev_map[ny][nx] != elev:
					var sp = Sprite2D.new()
					sp.texture = ct
					sp.centered = true
					sp.position = world_pos + Vector2((nx-x) * 64, (ny-y) * 16)
					contours.add_child(sp)
					contour_count += 1

	print("Tiles: ", count, " river: ", river_cells.size(), " heights: ", height_count, " contours: ", contour_count)
	return [layer, contours, heights, elev_map, biome_map]


func _make_contour_tex():
	# Thin bright line visible on top of everything
	var img = Image.create(128, 8, false, Image.FORMAT_RGBA8)
	for y in range(8):
		var a = 0.6 if y >= 2 and y <= 5 else 0.0
		for x in range(128):
			img.set_pixel(x, y, Color(0.9, 0.7, 0.3, a))
	return ImageTexture.create_from_image(img)


func _make_smooth_overlay(w, h, color):
	## Creates a soft-gradient overlay that fades toward edges
	## so adjacent cells blend smoothly into hills
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		for x in range(w):
			# Distance from center (0 at center, 1 at edge)
			var dx = (x - w / 2.0) / (w / 2.0)
			var dy = (y - h / 2.0) / (h / 2.0)
			var dist = sqrt(dx * dx + dy * dy)
			# Alpha: full at center, fade to 0 at edges
			var alpha = max(0.0, 1.0 - dist * 1.5) * color.a
			img.set_pixel(x, y, Color(color.r, color.g, color.b, alpha))
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
