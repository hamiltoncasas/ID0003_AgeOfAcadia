extends CanvasLayer

var _bm = []
var _bw = 300
var _bh = 300


func set_minimap_data(biome_map, w, h):
	_bm = biome_map
	_bw = w
	_bh = h


func _ready():
	layer = 100
	call_deferred("_build")


func _build():
	_add_stone_borders()
	_add_minimap()


func _get_vp_size():
	return get_viewport().get_visible_rect().size


func _add_stone_borders():
	var top_tex = load("res://sprites/ui/border_top.png")
	if not top_tex:
		return
	var vp = _get_vp_size()
	
	var top = TextureRect.new()
	top.texture = top_tex
	top.stretch_mode = TextureRect.STRETCH_TILE
	top.size = Vector2(vp.x, 64)
	top.position = Vector2(0, 0)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	
	var bot = TextureRect.new()
	bot.texture = top_tex
	bot.stretch_mode = TextureRect.STRETCH_TILE
	bot.size = Vector2(vp.x, 64)
	bot.position = Vector2(0, vp.y - 64)
	bot.scale = Vector2(1, -1)
	bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bot)


func _add_minimap():
	var vp = _get_vp_size()
	
	# Frame
	var frame = ColorRect.new()
	frame.name = "MiniFrame"
	frame.color = Color(0.08, 0.06, 0.05, 0.85)
	frame.size = Vector2(172, 172)
	frame.position = Vector2(vp.x - 182, vp.y - 182)
	add_child(frame)
	
	# Generate minimap texture
	var mm = TextureRect.new()
	mm.name = "Minimap"
	mm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mm.size = Vector2(160, 160)
	mm.position = Vector2(vp.x - 176, vp.y - 176)
	mm.stretch_mode = TextureRect.STRETCH_KEEP
	
	if _bm.size() > 0:
		var img = Image.create(_bw, _bh, false, Image.FORMAT_RGBA8)
		var colors = {
			0: Color(0.15, 0.3, 0.6),  # water
			1: Color(0.5, 0.4, 0.3),   # sand
			2: Color(0.25, 0.55, 0.15),# grass
			3: Color(0.4, 0.3, 0.2),   # dirt
			4: Color(0.15, 0.25, 0.1), # forest
			5: Color(0.3, 0.5, 0.6),   # shallow water
			6: Color(0.1, 0.2, 0.5),   # deep water
		}
		for y in range(min(_bh, _bm.size())):
			for x in range(min(_bw, _bm[0].size())):
				var hval = _bm[y][x]
				var col = colors[2]  # default grass
				if hval < -0.25:
					col = colors[0]  # water
				elif hval < -0.1:
					col = colors[5]  # shallow
				elif hval < 0.05:
					col = colors[1]  # sand
				elif hval < 0.35:
					col = colors[2]  # grass
				elif hval < 0.5:
					col = colors[3]  # dirt
				elif hval < 0.6:
					col = colors[4]  # forest
				else:
					col = colors[3]
				img.set_pixel(x, y, col)
		
		# Resize to minimap size
		img.resize(160, 160, Image.INTERPOLATE_NEAREST)
		mm.texture = ImageTexture.create_from_image(img)
	
	add_child(mm)


func _process(_delta):
	var vp = _get_vp_size()
	var frame = get_node_or_null("MiniFrame")
	var mm = get_node_or_null("Minimap")
	if frame:
		frame.position = Vector2(vp.x - 182, vp.y - 182)
	if mm:
		mm.position = Vector2(vp.x - 176, vp.y - 176)
	var children = get_children()
	for c in children:
		if c is TextureRect and c.name != "Minimap":
			c.size.x = vp.x
			c.position.y = vp.y - 64 if c.scale.y < 0 else 0
