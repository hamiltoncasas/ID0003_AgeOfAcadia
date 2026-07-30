extends Control

func _ready():
	# Load medieval font
	var font_path = "res://fonts/DejaVuSerif.ttf"
	var font = load(font_path) if ResourceLoader.exists(font_path) else null
	
	# Dark stone background
	RenderingServer.set_default_clear_color(Color(0.15, 0.12, 0.1, 1))
	
	# Title
	var title = Label.new()
	title.text = "AGE OF\nACADIA"
	if font:
		title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	title.position = Vector2(0, -100)
	add_child(title)
	
	# Start button
	var btn = Button.new()
	btn.text = "Start Game"
	if font:
		btn.add_theme_font_override("font", font)
	btn.add_theme_font_size_override("font_size", 24)
	btn.add_theme_color_override("font_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 0.9, 0.5))
	btn.add_theme_stylebox_override("normal", _make_style(Color(0.3, 0.2, 0.15)))
	btn.add_theme_stylebox_override("hover", _make_style(Color(0.4, 0.3, 0.2)))
	btn.add_theme_constant_override("outline_size", 2)
	btn.custom_minimum_size = Vector2(200, 50)
	btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	btn.position = Vector2(-100, 60)
	btn.pressed.connect(_on_start)
	add_child(btn)
	
	# Subtitle
	var sub = Label.new()
	sub.text = "A Mythic Age RTS"
	if font:
		sub.add_theme_font_override("font", font)
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(0.8, 0.7, 0.5, 0.7))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	sub.position = Vector2(0, -50)
	add_child(sub)
	
	# Stone border decoration
	var top_bar = ColorRect.new()
	top_bar.color = Color(0.3, 0.22, 0.15)
	top_bar.size = Vector2(1, 8)
	top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	add_child(top_bar)
	
	var bot_bar = ColorRect.new()
	bot_bar.color = Color(0.3, 0.22, 0.15)
	bot_bar.size = Vector2(1, 8)
	bot_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	add_child(bot_bar)


func _make_style(bg):
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.6, 0.5, 0.3)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style


func _on_start():
	get_tree().change_scene_to_file("res://terrain_only.tscn")
