extends RefCounted

## Generates a 300×300 isometric terrain map with 3 biomes:
##   0 = water (lakes, rivers, sea)
##   1 = desert (sandy, arid)
##   2 = plain (grass, forests)
## Valley-oriented: water collects in low central areas, rivers flow,
## desert appears in dry zones, plains cover the rest.

func generate(seed, w, h, ts):
	var rng = RandomNumberGenerator.new()
	rng.seed = seed

	# ── Noise layers ────────────────────────────────────────
	var height_noise = FastNoiseLite.new()
	height_noise.seed = abs(seed * 7)
	height_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	height_noise.frequency = 0.025
	height_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	height_noise.fractal_octaves = 3
	height_noise.fractal_gain = 0.5

	var detail_noise = FastNoiseLite.new()
	detail_noise.seed = abs(seed * 13 + 7)
	detail_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	detail_noise.frequency = 0.06
	detail_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	detail_noise.fractal_octaves = 2
	detail_noise.fractal_gain = 0.4

	# Moisture noise — determines desert vs plain
	var moisture_noise = FastNoiseLite.new()
	moisture_noise.seed = abs(seed * 23 + 11)
	moisture_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	moisture_noise.frequency = 0.025
	moisture_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	moisture_noise.fractal_octaves = 2

	# River noise
	var river_noise = FastNoiseLite.new()
	river_noise.seed = abs(seed * 31)
	river_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	river_noise.frequency = 0.02

	var ox = -100
	var oy = -100

	# ── Step 1: Generate height + moisture values ────────────
	var elev_map = []
	var biome_map = []
	for y in range(h):
		elev_map.append([])
		biome_map.append([])
		for x in range(w):
			# Base height with valley bias (edges higher, center lower)
			var dx_center = (x - w / 2.0) / (w / 2.0)
			var dy_center = (y - h / 2.0) / (h / 2.0)
			var dist_center = sqrt(dx_center * dx_center + dy_center * dy_center)
			var valley_bias = dist_center * 0.3

			var raw_h = height_noise.get_noise_2d(x, y)
			var det = detail_noise.get_noise_2d(x, y) * 0.12
			var hval = raw_h + det + valley_bias
			biome_map[y].append(hval)

			# Elevation: 8 levels
			var elev_lvl = int((hval + 0.5) * 4.0)
			elev_lvl = clampi(elev_lvl, 0, 7)
			elev_map[y].append(elev_lvl)

	# ── Step 2: Generate rivers ──────────────────────────────
	var river_cells = _generate_river(w, h, rng, river_noise)

	# ── Step 3: Place terrain tiles (3 biomes) ──────────────
	# Also replaces biome_map values with proper biome indices.
	var layer = TileMapLayer.new()
	layer.tile_set = ts
	var count = 0
	for y in range(h):
		for x in range(w):
			var pos = Vector2i(x + ox, y + oy)
			var hval = biome_map[y][x]
			var moist = moisture_noise.get_noise_2d(x, y)
			var sid = 0  # default: plain (grass)

			# Water: rivers or very low areas (lakes/sea)
			if river_cells.has(Vector2i(x, y)):
				sid = 5  # shallow water for rivers
			elif hval < -0.15:
				sid = 6  # deep water (lakes, sea)
			elif hval < 0.0:
				sid = 5  # shallow water (shore/lake edge)
			# Shore transition zone between water and land — use plain tiles (no objects)
			elif hval < 0.06:
				sid = 0  # grass (shore, no desert objects)
			# Desert: dry areas above beach level
			elif moist < -0.2 and hval < 0.4:
				sid = 2  # sand (desert)
			# Plain: everything else
			else:
				sid = 0  # grass (plain)

			# Note: sid 1 (dirt) reserved for future elevation-based transitions

			# Convert sid to biome index: 0/1=plain, 2=desert, 5/6=water
			var biome_idx = sid
			if biome_idx >= 5:
				biome_idx = 0  # water
			elif biome_idx == 2:
				biome_idx = 1  # desert
			else:
				biome_idx = 2  # plain
			biome_map[y][x] = biome_idx

			var variant = (x * 7 + y * 13 + sid * 31) % 8
			layer.set_cell(pos, sid, Vector2i(variant, 0))
			count += 1

	# ── Step 4: Elevation overlay ────────────────────────────
	var heights = Node2D.new()
	heights.name = "HeightOverlay"
	var height_count = 0
	var overlay_count = 8
	var overlay_texs = []
	for i in range(overlay_count):
		var t = float(i) / (overlay_count - 1)
		var alpha_curve = 0.03 + abs(t - 0.5) * 0.22
		var c = Color(
			0.20 + t * 0.60,
			0.45 - t * 0.20,
			0.10 + t * 0.20,
			alpha_curve
		)
		overlay_texs.append(_make_smooth_overlay(128, 64, c))

	for y in range(h):
		for x in range(w):
			var elev = elev_map[y][x]
			var tex = overlay_texs[elev]
			var world_pos = _cell_to_world(x + ox, y + oy)
			var sprite = Sprite2D.new()
			sprite.texture = tex
			sprite.centered = true
			sprite.position = world_pos
			heights.add_child(sprite)
			height_count += 1

	# ── Step 5: Contour lines at major elevation changes ────
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
				if abs(elev_map[ny][nx] - elev) >= 3:
					var sp = Sprite2D.new()
					sp.texture = ct
					sp.centered = true
					sp.position = world_pos + Vector2((nx-x) * 64, (ny-y) * 16)
					contours.add_child(sp)
					contour_count += 1

	# Verify biome indices
	var wc = 0; var dc = 0; var pc = 0
	for yy in range(h):
		for xx in range(w):
			match biome_map[yy][xx]:
				0: wc += 1
				1: dc += 1
				2: pc += 1
	print("Tiles: ", count, " river: ", river_cells.size(), " heights: ", height_count, " contours: ", contour_count)
	print("Biomes: water=", wc, " desert=", dc, " plain=", pc)
	return [layer, contours, heights, elev_map, biome_map]


func _make_contour_tex():
	var img = Image.create(128, 3, false, Image.FORMAT_RGBA8)
	for y in range(3):
		var a = 0.15 if y == 1 else 0.0
		for x in range(128):
			img.set_pixel(x, y, Color(0.6, 0.5, 0.2, a))
	return ImageTexture.create_from_image(img)


func _make_smooth_overlay(w, h, color):
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		for x in range(w):
			var dx = (x - w / 2.0) / (w / 2.0)
			var dy = (y - h / 2.0) / (h / 2.0)
			var dist = sqrt(dx * dx + dy * dy)
			var alpha = max(0.0, 1.0 - dist * 1.5) * color.a
			img.set_pixel(x, y, Color(color.r, color.g, color.b, alpha))
	return ImageTexture.create_from_image(img)


func _generate_river(w, h, rng, noise):
	var cells = {}
	var start_x = rng.randi_range(int(w * 0.15), int(w * 0.85))
	var start_y = 0
	var end_x = rng.randi_range(int(w * 0.15), int(w * 0.85))
	var end_y = h - 1
	if rng.randf() > 0.5:
		start_x = 0
		start_y = rng.randi_range(int(h * 0.15), int(h * 0.85))
		end_x = w - 1
		end_y = rng.randi_range(int(h * 0.15), int(h * 0.85))
	var pos = Vector2i(start_x, start_y)
	var target = Vector2i(end_x, end_y)
	var max_steps = int(max(w, h) * 2)
	var step = 0
	while pos.distance_squared_to(target) > 9.0 and step < max_steps:
		var rw = rng.randi_range(1, 3)
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
