extends Node

var _cache: Dictionary = {}

func get_texture(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var tex: Texture2D = load(path)
	if tex:
		_cache[path] = tex
	else:
		push_error("SpriteCache: failed to load texture: ", path)
	return tex

func has_texture(path: String) -> bool:
	return _cache.has(path)

func clear() -> void:
	_cache.clear()

func remove(path: String) -> void:
	if _cache.has(path):
		_cache.erase(path)

var _entorno_textures: Dictionary = {}
var _entorno_loaded: bool = false

func load_env_textures() -> void:
	_entorno_textures["water"] = []
	_entorno_textures["sand"] = []
	_entorno_textures["dirt"] = []
	_entorno_textures["grass"] = []
	_entorno_textures["cliff"] = []
	_entorno_textures["trees"] = []
	_entorno_textures["rocks"] = []
	_entorno_textures["decorations"] = []

	var dir := DirAccess.open("res://sprites/entorno/")
	if not dir:
		push_error("SpriteCache: Cannot open res://sprites/entorno/")
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry != "." and entry != ".." and dir.current_is_dir():
			var biome_key := _categorize_entorno_subdir(entry)
			if biome_key:
				var sin_path := "res://sprites/entorno/" + entry + "/base/" + entry + "_sin.png"
				var tex := load(sin_path) as Texture2D
				if tex:
					_entorno_textures[biome_key].append(tex)
				else:
					# Fallback: load any _sin.png from base/ directory
					var base_dir := DirAccess.open("res://sprites/entorno/" + entry + "/base")
					if base_dir:
						base_dir.list_dir_begin()
						var file := base_dir.get_next()
						while file != "":
							if file.ends_with("_sin.png") and not file.ends_with(".png.import"):
								tex = load("res://sprites/entorno/" + entry + "/base/" + file) as Texture2D
								if tex:
									_entorno_textures[biome_key].append(tex)
							file = base_dir.get_next()
		entry = dir.get_next()

	_entorno_loaded = true

func _categorize_entorno_subdir(name: String) -> String:
	match name:
		"agua_poca", "agua_profunda":
			return "water"
		"arena":
			return "sand"
		"caminos":
			return "dirt"
		"pasto":
			return "grass"
		"acantilados", "acantilados_roca":
			return "cliff"
		"roble", "pino", "arce", "abedul", "sauce", "cipres":
			return "trees"
		"rocas", "rocas_bloqueo", "mina_oro", "mina_oro_pequena", "mina_piedra", "mina_piedra_pequena":
			return "rocks"
		"flores", "juncos", "lirios_acuaticos", "arbustos", "hongos", "bambu", "cactus", "palmera":
			return "decorations"
	return ""

func get_entorno_textures() -> Dictionary:
	if not _entorno_loaded:
		load_env_textures()
	return _entorno_textures.duplicate()
