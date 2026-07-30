extends Node2D

const ObjectPlacer = preload("res://map/ObjectPlacer.gd")
const UnitController = preload("res://scripts/UnitController.gd")

## Development seed. Set to 0 for random map on each load.
@export var dev_seed: int = 54321

var _elev_map = []
var _biome_map = []


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
		if result.size() >= 1: add_child(result[0])  # terrain
		if result.size() >= 2: add_child(result[1])  # contours
		if result.size() >= 3: add_child(result[2])  # heights
		if result.size() >= 4: _elev_map = result[3]
		if result.size() >= 5: _biome_map = result[4]
	
	# ── Environment Objects ────────────────────────────────────
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val
	
	var object_container = Node2D.new()
	object_container.name = "EnvironmentObjects"
	object_container.y_sort_enabled = true
	
	var placer = ObjectPlacer.new()
	placer.place_objects(_biome_map, _elev_map, rng, object_container)
	add_child(object_container)
	
	# ── Player Unit ─────────────────────────────────────────────
	var player = UnitController.new()
	# Start at a visible central area
	player.position = Vector2(0, 3500)
	player.name = "PlayerUnit"
	# Collision shape for physics (objects, walls)
	var col_shape = CollisionShape2D.new()
	col_shape.name = "CollisionShape2D"
	var rect = RectangleShape2D.new()
	rect.size = Vector2(32, 48)
	col_shape.shape = rect
	player.add_child(col_shape)
	# UnitController expects child nodes for animation and camera
	var anim_sprite = AnimatedSprite2D.new()
	anim_sprite.name = "AnimatedSprite2D"
	anim_sprite.sprite_frames = SpriteFrames.new()
	anim_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	player.add_child(anim_sprite)
	var cam = Camera2D.new()
	cam.name = "Camera2D"
	cam.enabled = false  # main camera is CameraController
	player.add_child(cam)
	# Health bar above the character
	var health_bar_bg = ColorRect.new()
	health_bar_bg.name = "HealthBarBG"
	health_bar_bg.color = Color(0.2, 0.05, 0.05, 0.8)
	health_bar_bg.size = Vector2(36, 5)
	health_bar_bg.position = Vector2(-18, -74)
	health_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player.add_child(health_bar_bg)
	var health_bar_fill = ColorRect.new()
	health_bar_fill.name = "HealthBar"
	health_bar_fill.color = Color(0.2, 0.9, 0.2, 0.9)
	health_bar_fill.size = Vector2(36, 5)
	health_bar_fill.position = Vector2(-18, -74)
	health_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player.add_child(health_bar_fill)
	
	# Load arquero animations from manifest
	var manifest_path = "res://sprites/infanteria/arquero/arquero_manifest.json"
	var unit_sprites = UnitSprites.load_from_manifest(manifest_path)
	if unit_sprites:
		player.set_unit_sprites(unit_sprites)
	# Pass biome + elevation data for water detection
	player.biome_data = _biome_map
	player.elev_data = _elev_map
	add_child(player)
	
	var camera = get_node_or_null("../CameraController")
	if camera:
		camera.follow_target = player
	
	# UI overlay
	var ui = load("res://map/GameUI.gd").new()
	ui.set_minimap_data(_biome_map, 300, 300)
	ui.set_player_ref(player)
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
