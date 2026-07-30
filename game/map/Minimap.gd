extends Control

## Compact minimap (160×160 px) with biome-colored terrain and player marker.
## Click to teleport the camera to that location.

var map_manager: Node = null
var biome_map: Array = []
var map_width: int = 120
var map_height: int = 120
var player: Node2D = null

var _texture_rect: TextureRect = null
var _player_marker: ColorRect = null

const MINIMAP_SIZE: float = 160.0
const PADDING: float = 6.0
const MAP_SIZE: float = MINIMAP_SIZE - PADDING * 2

const BIOME_COLORS: Dictionary = {
	0: Color(0.2, 0.3, 0.8, 1.0),    # WATER
	1: Color(0.76, 0.7, 0.5, 1.0),   # SAND
	2: Color(0.3, 0.6, 0.2, 1.0),    # GRASS
	3: Color(0.5, 0.4, 0.3, 1.0),    # DIRT
	4: Color(0.4, 0.35, 0.3, 1.0),   # MOUNTAIN
}


func _ready():
	_build_ui()
	_generate_minimap()
	_update_position()
	get_viewport().size_changed.connect(_update_position)


func _update_position():
	size = Vector2(MINIMAP_SIZE, MINIMAP_SIZE)
	position = Vector2(
		get_viewport_rect().size.x - size.x - 10,
		get_viewport_rect().size.y - size.y - 10
	)


func _build_ui():
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0, 0, 0, 0.45)
	bg.size = Vector2(MINIMAP_SIZE, MINIMAP_SIZE)
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bg)

	_texture_rect = TextureRect.new()
	_texture_rect.name = "MinimapTexture"
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP
	_texture_rect.position = Vector2(PADDING, PADDING)
	_texture_rect.size = Vector2(MAP_SIZE, MAP_SIZE)
	_texture_rect.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_texture_rect)

	_player_marker = ColorRect.new()
	_player_marker.name = "PlayerMarker"
	_player_marker.color = Color(1, 0.9, 0.2, 0.95)  # gold dot
	_player_marker.size = Vector2(3, 3)
	_player_marker.mouse_filter = MOUSE_FILTER_IGNORE
	_texture_rect.add_child(_player_marker)


func _generate_minimap():
	if biome_map.is_empty():
		return

	var tex_size := int(MAP_SIZE)
	var img := Image.create(map_width, map_height, false, Image.FORMAT_RGBA8)
	for y in map_height:
		for x in map_width:
			if y < biome_map.size() and x < biome_map[y].size():
				var biome = biome_map[y][x] as int
				var color = BIOME_COLORS.get(biome, Color.BLACK)
				img.set_pixel(x, y, color)

	# Resize the full biome map to fill the texture rect directly
	img.resize(tex_size, tex_size, Image.INTERPOLATE_NEAREST)

	var tex := ImageTexture.create_from_image(img)
	_texture_rect.texture = tex


func _process(_delta: float):
	if player and map_manager:
		var cell = map_manager.world_to_cell(player.position)
		var marker_x = float(cell.x) / map_width * _texture_rect.size.x
		var marker_y = float(cell.y) / map_height * _texture_rect.size.y
		_player_marker.position = Vector2(marker_x, marker_y) - _player_marker.size / 2.0


func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local_pos = (event.position - _texture_rect.position) / _texture_rect.size * Vector2(map_width, map_height)
		var tile_x := clampi(int(local_pos.x), 0, map_width - 1)
		var tile_y := clampi(int(local_pos.y), 0, map_height - 1)
		if map_manager:
			var world_pos = map_manager.cell_to_world(Vector2i(tile_x, tile_y))
			var camera = map_manager.get_node_or_null("CameraController")
			if camera:
				camera.position = world_pos
