extends Node
## Central texture cache singleton (autoload).
##
## All unit textures load through this cache to ensure each strip PNG
## is loaded only once regardless of how many unit instances share it.
##
## Usage:
##   var tex: Texture2D = SpriteCache.get_texture("res://sprites/arquero_idle_front.png")

var _cache: Dictionary = {}

func get_texture(path: String) -> Texture2D:
	## Return the cached texture at path, loading it on first access.
	if _cache.has(path):
		return _cache[path]

	var tex: Texture2D = load(path)
	if tex:
		_cache[path] = tex
	else:
		push_error("SpriteCache: failed to load texture: ", path)
	return tex

func has_texture(path: String) -> bool:
	## Return true if path has been cached.
	return _cache.has(path)

func clear() -> void:
	## Evict all cached textures. Use when reloading resources.
	_cache.clear()

func remove(path: String) -> void:
	## Evict a single texture from cache.
	if _cache.has(path):
		_cache.erase(path)
