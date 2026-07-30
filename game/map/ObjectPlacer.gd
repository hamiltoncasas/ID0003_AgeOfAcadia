extends RefCounted
class_name ObjectPlacer

const _BIOME_SUBDIRS: Dictionary = {
	0: [],                                  # WATER — nothing
	1: ["cactus", "palmera", "rocas", "mina_oro", "mina_piedra", "mina_oro_pequena", "mina_piedra_pequena"],  # DESERT
	2: ["roble", "pino", "flores", "arbustos", "rocas", "mina_oro", "mina_piedra", "mina_oro_pequena", "mina_piedra_pequena"],  # PLAIN
}

const _WATER_EDGE_SUBDIRS: Array = ["lirios_acuaticos", "juncos"]

## Density thresholds per biome.
const _DENSITY_MIN: Dictionary = {
	0: 0.0,     # WATER — nothing
	1: 0.008,   # DESERT — occasional cactus/palm/rocks
	2: 0.025,   # PLAIN — trees, bushes, flowers
}

const _DENSITY_MAX: Dictionary = {
	0: 0.0,
	1: 0.015,
	2: 0.05,
}

const _JITTER_X: float = 8.0
const _JITTER_Y: float = 4.0


func place_objects(tilemap_layer: TileMapLayer, elev_map: Array, rng: RandomNumberGenerator, container: Node) -> Dictionary:
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
	var height: int = elev_map.size()
	if height == 0:
		return { "count": 0, "warnings": ["elev_map has no rows"] }
	var width: int = elev_map[0].size()
	if width == 0:
		return { "count": 0, "warnings": ["elev_map has no columns"] }

	for y in height:
		for x in width:
			# Check TileMapLayer directly: skip water cells
			var cell = Vector2i(x - 100, y - 100)  # tile coords (with offset)
			var sid = tilemap_layer.get_cell_source_id(cell)
			if sid == 5 or sid == 6:  # water tiles
				continue
			# Determine biome from source ID for density/pool selection
			var biome := 2  # default plain
			if sid == 2:
				biome = 1  # desert
			elif sid == 0:
				biome = 2  # plain

			if _is_cliff_cell(x, y, elev_map, width, height):
				continue

			# Minimum spacing: skip if any neighbor already has an object
			if _has_neighbor_object(x, y, placed):
				continue

			var key: String = "%d,%d" % [x, y]
			if placed.has(key):
				continue
			var pool: Array = pools.get(biome, [])

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
				scale_val = 2.0  # Rocks bigger
			elif tex_path.contains("/mina_") or tex_path.contains("/dorado/"):
				scale_val = 2.5  # Mines bigger
			elif tex_path.contains("/flores/") or tex_path.contains("/arbustos/") or tex_path.contains("/hongos/"):
				scale_val = 1.0
			elif tex_path.contains("/juncos/") or tex_path.contains("/lirios_acuaticos/"):
				scale_val = 0.8

			sprite.scale = Vector2(scale_val, scale_val)
			body.add_child(sprite)

			# Soft elliptical ground shadow — using cached textures per size
			var shadow := Sprite2D.new()
			shadow.name = "Shadow"
			shadow.texture = _get_shadow_tex(scale_val)
			shadow.centered = true
			shadow.z_index = -10
			body.add_child(shadow)

			var col_size: Vector2
			if scale_val >= 2.5:
				col_size = Vector2(64, 96)
			elif scale_val >= 1.8:
				col_size = Vector2(48, 80)
			elif scale_val >= 1.2:
				col_size = Vector2(40, 64)
			else:
				col_size = Vector2(24, 40)

			var collision := CollisionShape2D.new()
			var shape := RectangleShape2D.new()
			shape.size = col_size
			collision.shape = shape
			collision.position = Vector2(0, 0)
			body.add_child(collision)

			container.add_child(body)
			placed[key] = true
			total_count += 1

	# Second pass: scatter small ground-cover sprites (flowers, grass tufts)
	# on grass/dirt cells for natural terrain detail — no collision.
	var ground_cover_count := _place_ground_cover(tilemap_layer, elev_map, rng, container, placed, width, height)
	if ground_cover_count > 0:
		print("ObjectPlacer: ", ground_cover_count, " ground-cover sprites")

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


func _has_neighbor_object(x: int, y: int, placed: Dictionary) -> bool:
	var neighbors: Array = [
		[x - 1, y], [x + 1, y],
		[x, y - 1], [x, y + 1],
		[x - 1, y - 1], [x + 1, y - 1],
		[x - 1, y + 1], [x + 1, y + 1],
	]
	for n in neighbors:
		if placed.has("%d,%d" % [n[0], n[1]]):
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


# ── Ground cover (terrain detail) ────────────────────────────────

func _place_ground_cover(tlm: TileMapLayer, elev_map: Array, rng: RandomNumberGenerator,
		container: Node, placed: Dictionary, width: int, height: int) -> int:
	## Scatter small visual-only sprites (flowers, tiny bushes) on grass and
	## dirt cells to create natural-looking terrain detail like AoE-style
	## ground texture. These have NO collision and do NOT block movement.
	var textures: Dictionary = SpriteCache.get_entorno_textures()
	var decor_pool: Array = textures.get("decorations", [])
	if decor_pool.is_empty():
		return 0

	# Filter to only small ground-level textures (flowers, tiny bushes)
	var grounders: Array = []
	for tex in decor_pool:
		var path: String = tex.resource_path
		# Only use flowers for ground cover
		if path.contains("/flores/"):
			grounders.append(tex)
	if grounders.is_empty():
		return 0

	var count := 0
	var density: float = 0.03  # ~3% of plain cells

	for y in height:
		for x in width:
			# Check TileMapLayer: skip water and desert
			var cell = Vector2i(x - 100, y - 100)
			var sid = tlm.get_cell_source_id(cell)
			if sid == 5 or sid == 6 or sid == 2:  # water or desert — skip
				continue
			# Skip cells with existing objects
			if placed.has("%d,%d" % [x, y]):
				continue
			# Skip cliff cells
			if _is_cliff_cell(x, y, elev_map, width, height):
				continue
			# Density roll
			if rng.randf() > density:
				continue

			var tex: Texture2D = grounders[rng.randi() % grounders.size()]
			var sprite := Sprite2D.new()
			sprite.texture = tex
			sprite.name = "GroundCover_%d_%d" % [x, y]
			sprite.position = _cell_to_world(x, y) + Vector2(
				rng.randf_range(-8, 8), rng.randf_range(-4, 4)
			)
			sprite.scale = Vector2(0.8, 0.8)
			# Subtle random hue variation so ground cover doesn't look cloned
			sprite.self_modulate = Color(
				1.0,
				0.85 + rng.randf() * 0.15,
				0.85 + rng.randf() * 0.15,
				0.9
			)
			container.add_child(sprite)
			count += 1

	return count


# ── Shadow texture cache ──────────────────────────────────────────
var _shadow_cache: Dictionary = {}

func _get_shadow_tex(scale_val: float) -> Texture2D:
	## Return a cached soft elliptical shadow texture for the given scale.
	## Creates one on first use; reuses on subsequent calls.
	var key := int(scale_val * 10)
	if _shadow_cache.has(key):
		return _shadow_cache[key]

	var size := int(mini(scale_val * 32, 96))
	size = maxi(size, 16)
	var half := size / 2
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var dx := (x - half + 0.5) / (half * 0.8)
			var dy := (y - half + 0.5) / half
			var dist := sqrt(dx * dx + dy * dy)
			var alpha := 0.0
			if dist < 1.0:
				alpha = clampf(1.0 - dist * dist, 0.0, 1.0) * 0.35
			img.set_pixel(x, y, Color(0, 0, 0, alpha))

	var tex := ImageTexture.create_from_image(img)
	_shadow_cache[key] = tex
	return tex


func _cell_to_world(x: int, y: int) -> Vector2:
	return Vector2((x - y) * 64, (x + y) * 32)
