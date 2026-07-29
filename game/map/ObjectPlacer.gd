extends RefCounted
class_name ObjectPlacer

const _BIOME_SUBDIRS: Dictionary = {
	0: [],                                  # WATER
	1: ["cactus", "palmera", "rocas", "rocas_bloqueo"],             # SAND
	2: ["roble", "pino", "arce", "abedul", "sauce", "cipres", "palmera", "flores", "arbustos", "hongos", "bambu"],  # GRASS
	3: ["rocas", "rocas_bloqueo", "arbustos", "roble", "pino"],     # DIRT
	4: ["rocas", "rocas_bloqueo"],                                   # MOUNTAIN
}

const _WATER_EDGE_SUBDIRS: Array = ["lirios_acuaticos", "juncos"]

const _DENSITY_MIN: Dictionary = {
	0: 0.02,
	1: 0.04,
	2: 0.15,
	3: 0.08,
	4: 0.10,
}

const _DENSITY_MAX: Dictionary = {
	0: 0.05,
	1: 0.08,
	2: 0.25,
	3: 0.12,
	4: 0.18,
}

const _JITTER_X: float = 8.0
const _JITTER_Y: float = 4.0


func place_objects(biome_map: Array, elev_map: Array, rng: RandomNumberGenerator, container: Node) -> Dictionary:
	var textures: Dictionary = SpriteCache.get_entorno_textures()
	if textures.is_empty():
		push_warning("ObjectPlacer: get_entorno_textures() returned empty")
		return { "count": 0, "warnings": ["No entorno textures available"] }

	var pools: Dictionary = _build_pools(textures)
	if pools.is_empty():
		push_warning("ObjectPlacer: no textures available for any biome pool")
		return { "count": 0, "warnings": ["No textures available for any biome pool"] }

	var placed: Dictionary = {}
	var total_count: int = 0
	var warnings: Array = []
	var height: int = biome_map.size()
	if height == 0:
		return { "count": 0, "warnings": ["biome_map has no rows"] }
	var width: int = biome_map[0].size()
	if width == 0:
		return { "count": 0, "warnings": ["biome_map has no columns"] }

	for y in height:
		for x in width:
			var biome: int = biome_map[y][x] as int

			if _is_cliff_cell(x, y, elev_map, width, height):
				continue

			var key: String = "%d,%d" % [x, y]
			if placed.has(key):
				continue

			var pool: Array = []
			if biome == 0:
				if _is_water_edge(x, y, biome_map, width, height):
					pool = pools.get("water_edge", [])
			else:
				pool = pools.get(biome, [])

			if pool.is_empty():
				continue

			var density_min: float = _DENSITY_MIN.get(biome, 0.0)
			var density_max: float = _DENSITY_MAX.get(biome, 0.0)
			var threshold: float = rng.randf_range(density_min, density_max)
			if rng.randf() > threshold:
				continue

			var tex: Texture2D = pool[rng.randi() % pool.size()]
			var tex_size := tex.get_size()
			var cell_world: Vector2 = _cell_to_world(x, y)

			var body := StaticBody2D.new()
			body.name = "Object_%d_%d" % [x, y]
			body.position = cell_world + Vector2(
				rng.randf_range(-_JITTER_X, _JITTER_X),
				rng.randf_range(-_JITTER_Y, _JITTER_Y)
			)

			var sprite := Sprite2D.new()
			sprite.texture = tex
			sprite.offset = Vector2(0, -tex_size.y / 2.0)

			var tex_path := tex.resource_path
			var scale_val: float = 1.0
			if tex_path.contains("/roble/") or tex_path.contains("/pino/") or tex_path.contains("/arce/") or tex_path.contains("/abedul/") or tex_path.contains("/sauce/") or tex_path.contains("/cipres/") or tex_path.contains("/palmera/") or tex_path.contains("/bambu/"):
				scale_val = 2.5
			elif tex_path.contains("/rocas") or tex_path.contains("/cactus/"):
				scale_val = 1.5
			elif tex_path.contains("/flores/") or tex_path.contains("/arbustos/") or tex_path.contains("/hongos/"):
				scale_val = 1.0
			elif tex_path.contains("/juncos/") or tex_path.contains("/lirios_acuaticos/"):
				scale_val = 0.8

			sprite.scale = Vector2(scale_val, scale_val)
			body.add_child(sprite)

			# Base shadow — semi-transparent rectangle at ground level
			# Simulates 3D object footprint in isometric space
			var col_size: Vector2
			if scale_val >= 2.0:
				col_size = Vector2(48, 80)   # Trees: wide + TALL for isometric
			elif scale_val >= 1.2:
				col_size = Vector2(40, 64)   # Rocks: medium + tall
			else:
				col_size = Vector2(24, 40)   # Small decorations

			var shadow := Polygon2D.new()
			shadow.name = "Shadow"
			shadow.color = Color(0, 0, 0, 0.25)
			shadow.polygon = PackedVector2Array([
				Vector2(-col_size.x / 2.0, 0),
				Vector2(col_size.x / 2.0, 0),
				Vector2(col_size.x / 2.0, col_size.y),
				Vector2(-col_size.x / 2.0, col_size.y),
			])
			shadow.z_index = -1  # Behind everything on this body
			body.add_child(shadow)

			var collision := CollisionShape2D.new()
			var shape := RectangleShape2D.new()
			shape.size = col_size
			collision.shape = shape
			collision.position = Vector2(0, 0)
			body.add_child(collision)

			container.add_child(body)
			placed[key] = true
			total_count += 1

	return { "count": total_count, "warnings": warnings }


func _build_pools(textures: Dictionary) -> Dictionary:
	var flat: Array = []
	for category in textures.values():
		for tex in category:
			flat.append(tex)

	if flat.is_empty():
		return {}

	var pools: Dictionary = {}

	for biome in _BIOME_SUBDIRS:
		var subdirs: Array = _BIOME_SUBDIRS[biome]
		var pool: Array = []
		for tex in flat:
			var path: String = tex.resource_path
			for sd in subdirs:
				if path.contains("/%s/" % sd) or path.contains("/%s." % sd):
					pool.append(tex)
					break
		if not pool.is_empty():
			pools[biome] = pool

	var water_pool: Array = []
	for tex in flat:
		var path: String = tex.resource_path
		for sd in _WATER_EDGE_SUBDIRS:
			if path.contains("/%s/" % sd) or path.contains("/%s." % sd):
				water_pool.append(tex)
				break
	if not water_pool.is_empty():
		pools["water_edge"] = water_pool

	return pools


func _is_cliff_cell(x: int, y: int, elev_map: Array, width: int, height: int) -> bool:
	var elev: int = elev_map[y][x] as int
	if x > 0 and (elev_map[y][x - 1] as int) < elev:
		return true
	if x + 1 < width and (elev_map[y][x + 1] as int) < elev:
		return true
	if y > 0 and (elev_map[y - 1][x] as int) < elev:
		return true
	if y + 1 < height and (elev_map[y + 1][x] as int) < elev:
		return true
	return false


func _is_water_edge(x: int, y: int, biome_map: Array, width: int, height: int) -> bool:
	var neighbors: Array = [
		[x - 1, y],
		[x + 1, y],
		[x, y - 1],
		[x, y + 1],
	]
	for n in neighbors:
		var nx: int = n[0]
		var ny: int = n[1]
		if nx < 0 or nx >= width or ny < 0 or ny >= height:
			continue
		if (biome_map[ny][nx] as int) != 0:
			return true
	return false


func _cell_to_world(x: int, y: int) -> Vector2:
	return Vector2((x - y) * 64, (x + y) * 32)
