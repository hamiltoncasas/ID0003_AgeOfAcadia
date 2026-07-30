extends Node2D

var _elev_map = []


func _ready():
	RenderingServer.set_default_clear_color(Color("#4a7c3f"))

	var ts = _build_tileset()
	if not ts:
		return

	var seed_val = randi()
	print("Seed: ", seed_val)

	var gen = load("res://map/ProceduralGeneration.gd").new()
	var result = gen.generate(seed_val, 500, 500, ts)
	if result is Array:
		if result.size() >= 1: add_child(result[0])
		if result.size() >= 2: add_child(result[1])
		if result.size() >= 3: _elev_map = result[2]
	
	# Mouse coord overlay at bottom
	_add_mouse_overlay()
	print("Ready")


func _add_mouse_overlay():
	var ui = CanvasLayer.new()
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.5)
	bg.size = Vector2(1, 22)
	bg.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
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
var _last_cell = Vector2i(-999, -999)


func _process(_delta):
	if not _coord_label:
		return
	if _elev_map.is_empty():
		return
	
	var mouse = get_global_mouse_position()
	var cx = int(round((mouse.x / 64.0 + mouse.y / 32.0) / 2.0)) - 100  
	var cy = int(round((mouse.y / 32.0 - mouse.x / 64.0) / 2.0)) - 100
	
	# Clamp to elev_map bounds
	var mx = cx + 100
	var my = cy + 100
	if mx >= 0 and mx < _elev_map[0].size() and my >= 0 and my < _elev_map.size():
		var elev = _elev_map[my][mx]
		_coord_label.text = "Cell (%d,%d)  Elevation: %d" % [cx, cy, elev]
