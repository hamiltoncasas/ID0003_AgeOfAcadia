extends Node2D

const ObjectPlacer = preload("res://map/ObjectPlacer.gd")
const UnitController = preload("res://scripts/UnitController.gd")

## Development seed. Set to 0 for random map on each load.
@export var dev_seed: int = 54321

var _elev_map = []
var _biome_map = []
var _water_map = []
var _tilemap_layer: TileMapLayer = null


func _ready():
	RenderingServer.set_default_clear_color(Color("#4a7c3f"))
	# Defer heavy generation so scene transition completes first
	call_deferred("_generate")


func _generate():
	var ts = _build_tileset()
	if not ts:
		return

	var seed_val = dev_seed if dev_seed != 0 else randi()
	print("Seed: ", seed_val)

	var gen = load("res://map/ProceduralGeneration.gd").new()
	var result = gen.generate(seed_val, 300, 300, ts)
	if result is Array:
		if result.size() >= 1:
			_tilemap_layer = result[0]  # terrain TileMapLayer
			add_child(_tilemap_layer)
		if result.size() >= 2: add_child(result[1])  # contours
		if result.size() >= 3: add_child(result[2])  # heights
		if result.size() >= 4: _elev_map = result[3]
		if result.size() >= 5: _biome_map = result[4]
		if result.size() >= 6: _water_map = result[5]
	
	# ── Environment Objects ────────────────────────────────────
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val
	
	var object_container = Node2D.new()
	object_container.name = "EnvironmentObjects"
	object_container.y_sort_enabled = true
	
	var placer = ObjectPlacer.new()
	placer.place_objects(_water_map, _elev_map, rng, object_container, _biome_map)
	add_child(object_container)
	
	# ── Create 6 Archer Units ────────────────────────────────────
	var units := []
	var manifest_path = "res://sprites/infanteria/arquero/arquero_manifest.json"
	var unit_sprites = UnitSprites.load_from_manifest(manifest_path)
	
	# Starting positions in a line formation (offset from center valley)
	var start_positions = [
		Vector2(-200, 2000),
		Vector2(0, 2000),
		Vector2(200, 2000),
		Vector2(-100, 2100),
		Vector2(100, 2100),
		Vector2(-300, 2050)
	]
	
	for i in range(6):
		var unit = UnitController.new()
		unit.position = start_positions[i]
		unit.name = "Archer_%d" % i
		unit.unit_index = i
		
		# Collision shape — layer 2 so units don't collide with each other
		var col_shape = CollisionShape2D.new()
		var rect = RectangleShape2D.new()
		rect.size = Vector2(24, 36)
		col_shape.shape = rect
		col_shape.name = "CollisionShape2D"
		unit.add_child(col_shape)
		unit.collision_layer = 2  # unit layer
		unit.collision_mask = 1   # collide with objects (layer 1), not other units
		
		# AnimatedSprite2D for arquero animations
		var anim_sprite = AnimatedSprite2D.new()
		anim_sprite.name = "AnimatedSprite2D"
		anim_sprite.sprite_frames = SpriteFrames.new()
		anim_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		unit.add_child(anim_sprite)
		
		# Disabled Camera2D (main camera is CameraController)
		var cam = Camera2D.new()
		cam.name = "Camera2D"
		cam.enabled = false
		unit.add_child(cam)
		
		# Health bar
		var hp_bg = ColorRect.new()
		hp_bg.name = "HealthBarBG"
		hp_bg.color = Color(0.2, 0.05, 0.05, 0.8)
		hp_bg.size = Vector2(36, 5)
		hp_bg.position = Vector2(-18, -74)
		hp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		unit.add_child(hp_bg)
		var hp_fill = ColorRect.new()
		hp_fill.name = "HealthBar"
		hp_fill.color = Color(0.2, 0.9, 0.2, 0.9)
		hp_fill.size = Vector2(36, 5)
		hp_fill.position = Vector2(-18, -74)
		hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		unit.add_child(hp_fill)
		
		# Load arquero sprites
		if unit_sprites:
			unit.set_unit_sprites(unit_sprites)
		
		# Biome data for water detection
		unit.biome_data = _biome_map
		unit._water_map = _water_map
		unit.elev_data = _elev_map
		unit._tilemap_layer = _tilemap_layer
		
		add_child(unit)
		units.append(unit)
	
	# Camera follows first unit by default
	var camera = get_node_or_null("../CameraController")
	if camera and units.size() > 0:
		camera.follow_target = units[0]
	
	# UI overlay
	var ui = load("res://map/GameUI.gd").new()
	ui.set_minimap_data(_biome_map, 300, 300)
	ui.set_units(units)
	if camera:
		ui.set_camera_ref(camera)
	add_child(ui)
	_add_mouse_overlay()
	print("Ready")


func _add_mouse_overlay():
	var ui = CanvasLayer.new()
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.5)
	bg.size = Vector2(1, 22)
	bg.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(bg)
	var lbl = Label.new()
	lbl.name = "InfoLabel"
	lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.position = Vector2(8, -16)
	bg.add_child(lbl)
	add_child(ui)
	_coord_label = lbl
	set_process(true)


var _coord_label = null


func _process(_delta):
	if not _coord_label or _elev_map.is_empty():
		return
	var mouse = get_global_mouse_position()
	var cx = int(round((mouse.x / 64.0 + mouse.y / 32.0) / 2.0)) - 100
	var cy = int(round((mouse.y / 32.0 - mouse.x / 64.0) / 2.0)) - 100
	var mx = cx + 100
	var my = cy + 100
	if mx >= 0 and mx < _elev_map[0].size() and my >= 0 and my < _elev_map.size():
		var elev = _elev_map[my][mx]
		_coord_label.text = "Cell (%d,%d)  Elevation: %d" % [cx, cy, elev]


func _cell_to_world(x, y):
	return Vector2((x - y) * 64, (x + y) * 32)





func _build_tileset():
	var ts = TileSet.new()
	ts.tile_size = Vector2i(128, 64)
	ts.tile_shape = 1
	ts.tile_layout = 1
	for path in [
		"res://sprites/terrain/strips/grass.png",
		"res://sprites/terrain/strips/dirt.png",
		"res://sprites/terrain/strips/sand.png",
		"res://sprites/terrain/strips/path.png",
		"res://sprites/terrain/strips/forest_floor.png",
		"res://sprites/terrain/strips/shallow_water.png",
		"res://sprites/terrain/strips/deep_water.png",
	]:
		var tex = load(path)
		if not tex:
			continue
		var src = TileSetAtlasSource.new()
		src.texture = tex
		src.texture_region_size = Vector2i(128, 64)
		# Create all 8 tile variants from the strip for visual variety
		for i in range(8):
			src.create_tile(Vector2i(i, 0), Vector2i(1, 1))
		ts.add_source(src)
	return ts
