extends RefCounted

func generate(seed, w, h, ts):
	var rng = RandomNumberGenerator.new()
	rng.seed = seed

	# Main biome noise — higher frequency for more variety
	var noise = FastNoiseLite.new()
	noise.seed = abs(seed * 7)
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.02
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	noise.fractal_gain = 0.5

	# Detail noise for micro-variation
	var detail = FastNoiseLite.new()
	detail.seed = abs(seed * 13 + 7)
	detail.noise_type = FastNoiseLite.TYPE_PERLIN
	detail.frequency = 0.05

	# River noise
	var river_noise = FastNoiseLite.new()
	river_noise.seed = abs(seed * 31)
	river_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	river_noise.frequency = 0.008

	# Generate river
	var river_cells = _generate_river(w, h, rng, river_noise)

	# Center grid on camera at (150, 150) instead of (0, 0)
	var ox = -100
	var oy = -100
	var layer = TileMapLayer.new()
	layer.tile_set = ts
	var count = 0

	for y in range(h):
		for x in range(w):
			var pos = Vector2i(x + ox, y + oy)
			var local_pos = Vector2i(x, y)
			var val = noise.get_noise_2d(local_pos.x, local_pos.y)
			var det = detail.get_noise_2d(local_pos.x, local_pos.y) * 0.15
			var hval = val + det
			var sid = 0

			# River primero (sobrescribe todo)
			if river_cells.has(local_pos):
				sid = 6
			# Agua
			elif hval < -0.25:
				sid = 6  # deep water
			# Costa / arena húmeda
			elif hval < -0.1:
				sid = 5  # shallow water
			# Arena
			elif hval < 0.05:
				sid = 2  # sand
			# Pasto (mayoría del mapa)
			elif hval < 0.35:
				sid = 0  # grass
			# Tierra / camino natural
			elif hval < 0.5:
				sid = 1  # dirt
			# Suelo de bosque
			elif hval < 0.6:
				sid = 4  # forest_floor
			# Camino de piedra
			elif hval < 0.7:
				sid = 3  # path
			# Montaña / roca
			else:
				sid = 1  # dirt for mountains

			# Pequeña variación aleatoria: 10% de chance de cambiar a pasto
			# para evitar bordes muy duros
			if sid != 6 and rng.randf() < 0.03:
				sid = 0

			layer.set_cell(pos, sid, Vector2i(0, 0))
			count += 1

	print("Tiles: ", count, " river: ", river_cells.size())
	return layer


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
