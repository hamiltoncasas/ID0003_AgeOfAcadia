extends CanvasLayer

## Game UI: stone borders + minimap

func _ready():
	layer = 100
	_add_stone_borders()
	_add_minimap()


func _get_vp_size():
	return get_viewport().get_visible_rect().size


func _add_stone_borders():
	var top_tex = load("res://sprites/ui/border_top.png")
	if not top_tex:
		return
	
	var vp = _get_vp_size()
	
	# Top border
	var top = TextureRect.new()
	top.texture = top_tex
	top.stretch_mode = TextureRect.STRETCH_TILE
	top.size = Vector2(vp.x, 64)
	top.position = Vector2(0, 0)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	
	# Bottom border
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
	
	# Frame background
	var frame = ColorRect.new()
	frame.name = "MiniFrame"
	frame.color = Color(0.08, 0.06, 0.05, 0.85)
	frame.size = Vector2(172, 172)
	frame.position = Vector2(vp.x - 182, vp.y - 182)
	add_child(frame)
	
	# Minimap area
	var mm = ColorRect.new()
	mm.name = "Minimap"
	mm.color = Color(0.25, 0.4, 0.15, 1)
	mm.size = Vector2(160, 160)
	mm.position = Vector2(vp.x - 176, vp.y - 176)
	add_child(mm)


func _process(_delta):
	# Reposition on resize
	var vp = _get_vp_size()
	
	var frame = get_node_or_null("MiniFrame")
	if frame:
		frame.position = Vector2(vp.x - 182, vp.y - 182)
	
	var mm = get_node_or_null("Minimap")
	if mm:
		mm.position = Vector2(vp.x - 176, vp.y - 176)
	
	# Update border sizes (first child is top border, second is bottom)
	var children = get_children()
	if children.size() >= 2:
		var tb = children[0]
		var bb = children[1]
		if tb is TextureRect:
			tb.size.x = vp.x
			bb.size.x = vp.x
			bb.position.y = vp.y - 64
