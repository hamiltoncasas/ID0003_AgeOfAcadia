extends CanvasLayer

## Game UI: stone borders + minimap

func _ready():
	layer = 100  # On top of everything
	
	# Stone borders
	_add_stone_borders()
	
	# Minimap
	_add_minimap()


func _add_stone_borders():
	## Add decorative stone borders around the screen
	var top_tex = load("res://sprites/ui/border_top.png")
	var corner_tex = load("res://sprites/ui/border_corner.png")
	
	if not top_tex or not corner_tex:
		return
	
	var vp = get_viewport_rect()
	
	# Top border (tiled horizontally)
	var top = TextureRect.new()
	top.texture = top_tex
	top.stretch_mode = TextureRect.STRETCH_TILE
	top.size = Vector2(vp.size.x, 64)
	top.position = Vector2(0, 0)
	add_child(top)
	
	# Bottom border
	var bot = TextureRect.new()
	bot.texture = top_tex
	bot.stretch_mode = TextureRect.STRETCH_TILE
	bot.size = Vector2(vp.size.x, 64)
	bot.position = Vector2(0, vp.size.y - 64)
	bot.scale = Vector2(1, -1)  # Flip
	add_child(bot)


func _add_minimap():
	## Add minimap at bottom-right corner
	var vp = get_viewport_rect()
	
	# Background frame
	var frame = ColorRect.new()
	frame.color = Color(0.1, 0.1, 0.1, 0.7)
	frame.size = Vector2(180, 180)
	frame.position = Vector2(vp.size.x - 190, vp.size.y - 190)
	add_child(frame)
	
	# Minimap placeholder
	var mm = ColorRect.new()
	mm.name = "Minimap"
	mm.color = Color(0.3, 0.5, 0.2, 1)
	mm.size = Vector2(160, 160)
	mm.position = Vector2(vp.size.x - 180, vp.size.y - 180)
	add_child(mm)
	
	# Re-center on resize
	get_viewport().size_changed.connect(_reposition)


func _reposition():
	var vp = get_viewport_rect()
	var mm = get_node_or_null("Minimap")
	var frame = get_node_or_null("Background")
	if mm:
		mm.position = Vector2(vp.size.x - 180, vp.size.y - 180)
	if frame:
		frame.position = Vector2(vp.size.x - 190, vp.size.y - 190)
