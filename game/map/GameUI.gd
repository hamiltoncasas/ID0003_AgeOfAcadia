extends CanvasLayer

var _bm = []
var _bw = 300
var _bh = 300
var player_ref: Node2D = null
var camera_ref: Camera2D = null
var _player_marker: ColorRect = null
var _mm_click_area: ColorRect = null
var _action_panel: ColorRect = null

## Action panel state
var _panel_visible: bool = false
var _panel_buttons: Array = []


func set_minimap_data(biome_map, w, h):
	_bm = biome_map
	_bw = w
	_bh = h
	if is_inside_tree():
		_build()


## Set player reference so minimap can show a position dot.
func set_player_ref(node: Node2D):
	player_ref = node


## Set camera reference so minimap clicks can move the viewport.
func set_camera_ref(node: Camera2D):
	camera_ref = node


func _ready():
	layer = 100
	call_deferred("_build")


func _build():
	_add_borders()
	_add_minimap()
	_add_action_panel()


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
	
	# Frame + clickable area
	var frame = ColorRect.new()
	frame.name = "MiniFrame"
	frame.color = Color(0.08, 0.06, 0.05, 0.85)
	frame.size = Vector2(172, 172)
	frame.position = Vector2(vp.x - 182, vp.y - 182)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	
	# Clickable transparent overlay on the minimap area
	_mm_click_area = ColorRect.new()
	_mm_click_area.name = "MinimapClickArea"
	_mm_click_area.color = Color.TRANSPARENT
	_mm_click_area.size = Vector2(160, 160)
	_mm_click_area.position = Vector2(vp.x - 176, vp.y - 176)
	_mm_click_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_mm_click_area.gui_input.connect(_on_minimap_click)
	add_child(_mm_click_area)
	
	# Minimap image
	var mm = TextureRect.new()
	mm.name = "Minimap"
	mm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mm.size = Vector2(160, 160)
	mm.position = Vector2(vp.x - 176, vp.y - 176)
	mm.stretch_mode = TextureRect.STRETCH_KEEP
	add_child(mm)
	
	_generate_minimap(mm)
	
	# Player position marker dot
	var marker = ColorRect.new()
	marker.name = "PlayerMarker"
	marker.color = Color(1, 0.9, 0.2, 0.95)  # gold dot
	marker.size = Vector2(4, 4)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mm.add_child(marker)
	_player_marker = marker


func _update_player_marker():
	if not player_ref or not _player_marker:
		return
	# Convert player world position to cell coords
	var pw = player_ref.global_position
	var tile_x = (pw.x / 64.0 + pw.y / 32.0) / 2.0
	var tile_y = (pw.y / 32.0 - pw.x / 64.0) / 2.0
	# Convert tile coords to loop coords (ox=oy=-100)
	var loop_x = tile_x + 100.0
	var loop_y = tile_y + 100.0
	# Map to minimap pixel coords (160×160 texture)
	var mm_x = (loop_x / _bw) * 160.0
	var mm_y = (loop_y / _bh) * 160.0
	_player_marker.position = Vector2(mm_x - 2, mm_y - 2)


func _generate_minimap(mm):
	if _bm.size() == 0:
		return
	
	var img = Image.create(_bw, _bh, false, Image.FORMAT_RGBA8)
	for y in range(min(_bh, _bm.size())):
		for x in range(min(_bw, _bm[0].size())):
			var biome = _bm[y][x]
			var col = Color(0.25, 0.55, 0.15)  # default: green (plain)
			if biome == 0:
				col = Color(0.15, 0.3, 0.6)    # blue (water)
			elif biome == 1:
				col = Color(0.76, 0.7, 0.5)   # tan (desert)
			# 2 = plain (green, default)
			img.set_pixel(x, y, col)
	
	img.resize(160, 160, Image.INTERPOLATE_NEAREST)
	mm.texture = ImageTexture.create_from_image(img)


## Create the action panel (hidden by default).
func _add_action_panel():
	var vp = _get_vp()
	
	# Panel backdrop — embedded in bottom bar area
	_action_panel = ColorRect.new()
	_action_panel.name = "ActionPanel"
	_action_panel.color = Color(0.12, 0.08, 0.05, 0.9)
	_action_panel.size = Vector2(280, 46)
	_action_panel.position = Vector2(vp.x / 2.0 - 140, vp.y - 48)
	_action_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_action_panel.visible = false
	add_child(_action_panel)
	
	# Title + Health inline
	var title = Label.new()
	title.name = "PanelTitle"
	title.text = "ARCHER"
	title.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	title.add_theme_font_size_override("font_size", 12)
	title.position = Vector2(6, 3)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_action_panel.add_child(title)
	
	# Compact health bar
	var hp_bg = ColorRect.new()
	hp_bg.name = "PanelHPBG"
	hp_bg.color = Color(0.15, 0.05, 0.05, 0.8)
	hp_bg.size = Vector2(80, 7)
	hp_bg.position = Vector2(6, 20)
	hp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_action_panel.add_child(hp_bg)
	var hp_fill = ColorRect.new()
	hp_fill.name = "PanelHPFill"
	hp_fill.color = Color(0.2, 0.9, 0.2, 0.9)
	hp_fill.size = Vector2(80, 7)
	hp_fill.position = Vector2(6, 20)
	hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_action_panel.add_child(hp_fill)
	var hp_lbl = Label.new()
	hp_lbl.name = "PanelHPLabel"
	hp_lbl.text = "100"
	hp_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.8))
	hp_lbl.add_theme_font_size_override("font_size", 8)
	hp_lbl.position = Vector2(90, 19)
	hp_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_action_panel.add_child(hp_lbl)
	
	# Compact action buttons
	var actions = [
		{"label": "⚔ Atk", "action": "attack"},
		{"label": "✋ Stop", "action": "stop"},
		{"label": "🏹 Fire", "action": "fire"},
	]
	var bx = 120
	var by = 4
	for act in actions:
		var btn = ColorRect.new()
		btn.color = Color(0.25, 0.18, 0.12, 0.9)
		btn.size = Vector2(78, 26)
		btn.position = Vector2(bx, by)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.set_meta("action", act["action"])
		btn.gui_input.connect(_on_action_btn_click.bind(act["action"]))
		_action_panel.add_child(btn)
		
		var lbl = Label.new()
		lbl.text = act["label"]
		lbl.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.position = Vector2(6, 4)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(lbl)
		
		_panel_buttons.append(btn)
		bx += 84
	
	# Bottom border
	var bot_border = ColorRect.new()
	bot_border.color = Color(0.3, 0.22, 0.15, 1.0)
	bot_border.size = Vector2(260, 2)
	bot_border.position = Vector2(0, 88)
	bot_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_action_panel.add_child(bot_border)


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
	
	# Reposition minimap + click area
	var frame = get_node_or_null("MiniFrame")
	var mm = get_node_or_null("Minimap")
	if frame:
		frame.position = Vector2(vp.x - 182, vp.y - 182)
	if mm:
		mm.position = Vector2(vp.x - 176, vp.y - 176)
	if _mm_click_area:
		_mm_click_area.position = Vector2(vp.x - 176, vp.y - 176)
	# Update player marker on minimap
	_update_player_marker()
	
	# Show action panel when player is selected
	if player_ref and player_ref.has_method("is_selected"):
		var sel = player_ref.is_selected()
		if sel != _panel_visible:
			_panel_visible = sel
			if _action_panel:
				_action_panel.visible = sel
		# Update health display
		if sel and _action_panel and _action_panel.visible:
			var hp_fill = _action_panel.get_node_or_null("PanelHPFill")
			var hp_lbl = _action_panel.get_node_or_null("PanelHPLabel")
			if hp_fill and hp_lbl and player_ref.has_method("get_health"):
				var hp = player_ref.get_health()
				var max_hp = player_ref.get_max_health()
				var ratio = float(hp) / max_hp
				hp_fill.size.x = 100.0 * ratio
				if ratio > 0.6:
					hp_fill.color = Color(0.2, 0.9, 0.2, 0.9)
				elif ratio > 0.3:
					hp_fill.color = Color(0.9, 0.8, 0.2, 0.9)
				else:
					hp_fill.color = Color(0.9, 0.2, 0.2, 0.9)
				hp_lbl.text = str(hp) + "/" + str(max_hp)
	# Reposition action panel (bottom bar area)
	if _action_panel and _action_panel.visible:
		_action_panel.position = Vector2(vp.x / 2.0 - 140, vp.y - 48)


## Handle action panel button clicks.
func _on_action_btn_click(event: InputEvent, action: String):
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if not player_ref:
		return
	match action:
		"attack":
			if player_ref.has_method("attack"):
				player_ref.attack()  # fires toward last direction
		"stop":
			if player_ref.has_method("stop_movement"):
				player_ref.stop_movement()
		"fire":
			if player_ref.has_method("attack"):
				player_ref.attack()


## Handle minimap clicks — move camera to clicked location.
func _on_minimap_click(event: InputEvent):
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if not camera_ref:
		return
	# Consume event — prevent camera drag from starting on minimap click
	get_viewport().set_input_as_handled()
	
	# Convert minimap click position (relative to click area) to world coords
	var local = event.position  # relative to click area since gui_input
	var loop_x = (local.x / 160.0) * _bw
	var loop_y = (local.y / 160.0) * _bh
	
	# Loop coords → tile coords (ox=oy=-100)
	var tile_x = loop_x - 100.0
	var tile_y = loop_y - 100.0
	
	# Tile coords → world coords (isometric)
	var world_x = (tile_x - tile_y) * 64.0
	var world_y = (tile_x + tile_y) * 32.0
	
	# Move camera to clicked location and stop auto-follow
	camera_ref.position = Vector2(world_x, world_y)
	camera_ref.follow_target = null
