extends RefCounted


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
	river_noise.frequency = 0.004

	# Generate river path (goes across the entire grid)
	var river_cells = _generate_river(w, h, rng, river_noise)

	var layer = TileMapLayer.new()
	layer.tile_set = ts

	var count = 0
	for y in range(h):
		for x in range(w):
			var val = noise.get_noise_2d(x, y)
			var pos = Vector2i(x, y)
			var sid = 0

			if river_cells.has(pos):
				sid = 6  # deep water (blue)
			elif val < -0.3:
				sid = 6  # deep water (lakes/seas)
			elif val < -0.1:
				sid = 5  # shallow water → sand/beach
			elif val < 0.1:
				sid = 2  # sand
			elif val < 0.45:
				sid = 0  # grass
			elif val < 0.65:
				sid = 1  # dirt
			elif val < 0.8:
				sid = 2  # mountain → sand
			else:
				sid = 0  # high mountain → grass

			layer.set_cell(pos, sid, Vector2i(0, 0))
			count += 1

	print("Tiles: ", count, " river: ", river_cells.size())
	return layer


func _generate_river(w, h, rng, noise):
	var cells = {}
	
	# River starts from left or top edge, ends at right or bottom
	var start_x = 0
	var start_y = rng.randi_range(int(h * 0.2), int(h * 0.8))
	var end_x = w - 1
	var end_y = rng.randi_range(int(h * 0.2), int(h * 0.8))
	
	# Sometimes start from top
	if rng.randf() > 0.5:
		start_x = rng.randi_range(int(w * 0.2), int(w * 0.8))
		start_y = 0
		end_y = h - 1
		end_x = rng.randi_range(int(w * 0.2), int(w * 0.8))
	
	var pos = Vector2i(start_x, start_y)
	var target = Vector2i(end_x, end_y)
	var max_steps = int(w * 1.5)
	var step = 0
	
	while pos.distance_squared_to(target) > 4.0 and step < max_steps:
		# Mark cells around position (river width 1-2)
		var width = 1
		for dx in range(-width, width + 1):
			for dy in range(-width, width + 1):
				var np = Vector2i(pos.x + dx, pos.y + dy)
				if np.x >= 0 and np.x < w and np.y >= 0 and np.y < h:
					cells[np] = true
		
		step += 1
		
		# Direction toward target + meander
		var dx = sign(target.x - pos.x)
		var dy = sign(target.y - pos.y)
		var n = noise.get_noise_2d(pos.x * 0.5, pos.y * 0.5) * 2.0
		
		var mx = int(round(n))
		var my = int(round(n * 0.7))
		
		# Prefer moving toward target
		if rng.randf() < 0.7:
			pos.x += dx
		elif abs(mx) > 0:
			pos.x += mx
		
		if rng.randf() < 0.7:
			pos.y += dy
		elif abs(my) > 0:
			pos.y += my
		
		# Clamp
		pos.x = clampi(pos.x, 2, w - 3)
		pos.y = clampi(pos.y, 2, h - 3)
	
	return cells
