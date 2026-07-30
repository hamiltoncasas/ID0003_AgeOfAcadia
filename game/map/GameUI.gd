extends CanvasLayer

var _bm = []
var _bw = 300
var _bh = 300


func set_minimap_data(biome_map, w, h):
	_bm = biome_map
	_bw = w
	_bh = h
	if is_inside_tree():
		_build()


func _ready():
	layer = 100
	call_deferred("_build")


func _build():
	_add_borders()
	_add_minimap()


func _get_vp():
	return get_viewport().get_visible_rect().size


func _add_borders():
	var vp = _get_vp()
	var col = Color(0.2, 0.15, 0.1)
	
	# Top bar
	var t = ColorRect.new()
	t.color = col
	t.size = Vector2(vp.x, 48)
	t.position = Vector2(0, 0)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(t)
	
	# Bottom bar
	var b = ColorRect.new()
	b.color = col
	b.size = Vector2(vp.x, 48)
	b.position = Vector2(0, vp.y - 48)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(b)


func _add_minimap():
	var vp = _get_vp()
	
	# Frame
	var frame = ColorRect.new()
	frame.name = "MiniFrame"
	frame.color = Color(0.08, 0.06, 0.05, 0.85)
	frame.size = Vector2(172, 172)
	frame.position = Vector2(vp.x - 182, vp.y - 182)
	add_child(frame)
	
	# Minimap image
	var mm = TextureRect.new()
	mm.name = "Minimap"
	mm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mm.size = Vector2(160, 160)
	mm.position = Vector2(vp.x - 176, vp.y - 176)
	mm.stretch_mode = TextureRect.STRETCH_KEEP
	add_child(mm)
	
	_generate_minimap(mm)


func _generate_minimap(mm):
	if _bm.size() == 0:
		return
	
	var img = Image.create(_bw, _bh, false, Image.FORMAT_RGBA8)
	for y in range(min(_bh, _bm.size())):
		for x in range(min(_bw, _bm[0].size())):
			var hval = _bm[y][x]
			var col = Color(0.25, 0.55, 0.15)
			if hval < -0.25:
				col = Color(0.15, 0.3, 0.6)
			elif hval < -0.1:
				col = Color(0.3, 0.5, 0.6)
			elif hval < 0.05:
				col = Color(0.76, 0.7, 0.5)
			elif hval < 0.35:
				col = Color(0.25, 0.55, 0.15)
			elif hval < 0.5:
				col = Color(0.5, 0.4, 0.3)
			elif hval < 0.6:
				col = Color(0.15, 0.25, 0.1)
			else:
				col = Color(0.5, 0.4, 0.3)
			img.set_pixel(x, y, col)
	
	img.resize(160, 160, Image.INTERPOLATE_NEAREST)
	mm.texture = ImageTexture.create_from_image(img)


func _process(_delta):
	var vp = _get_vp()
	var children = get_children()
	# Resize borders (first 2 children)
	for i in range(min(2, children.size())):
		var c = children[i]
		if c is ColorRect:
			c.size.x = vp.x
			if i == 1:
				c.position.y = vp.y - 48
	
	# Reposition minimap
	var frame = get_node_or_null("MiniFrame")
	var mm = get_node_or_null("Minimap")
	if frame:
		frame.position = Vector2(vp.x - 182, vp.y - 182)
	if mm:
		mm.position = Vector2(vp.x - 176, vp.y - 176)
