class_name UnitSprites extends Resource
## Custom Resource that reads a JSON manifest and builds SpriteFrames
## for AnimatedSprite2D with per-animation×direction entries.
##
## Each strip PNG is a horizontal sequence of identically-sized frames.
## Frames are exposed as AtlasTextures sliced from the strip at
## (frame_width * index, 0) -> (frame_width, frame_height).

@export var character: String = ""
@export var frame_width: int = 128
@export var frame_height: int = 128

## anim_name -> direction_name -> { path, frames }
var animations: Dictionary = {}

## Cache singleton resolved at runtime (autoload not available at parse time).
var _cache: Node = null


static func load_from_manifest(path: String) -> UnitSprites:
	## Load manifest JSON, create UnitSprites, resolve strip paths.
	## The manifest lives alongside the strip PNGs, so strip paths are
	## resolved relative to the manifest's parent directory.
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("UnitSprites: cannot open manifest: ", path)
		return null

	var text := file.get_as_text()
	file.close()

	var parse_result = JSON.parse_string(text)
	if typeof(parse_result) != TYPE_DICTIONARY:
		push_error("UnitSprites: invalid manifest JSON: ", path)
		return null

	var data: Dictionary = parse_result

	var sprites := new()
	sprites.character = data.get("character", "")
	sprites.frame_width = data.get("frame_width", 128)
	sprites.frame_height = data.get("frame_height", 128)

	var base_dir := path.get_base_dir()

	for strip in data.get("strips", []):
		var anim: String = strip.get("animation", "")
		var dir: String = strip.get("direction", "")
		var frames: int = strip.get("frames", 1)
		var strip_path: String = base_dir.path_join(strip.get("file", ""))

		if not sprites.animations.has(anim):
			sprites.animations[anim] = {}
		sprites.animations[anim][dir] = {
			"path": strip_path,
			"frames": frames,
		}

	return sprites


func _get_cache() -> Node:
	"""Lazy-resolve the SpriteCache autoload singleton."""
	if _cache == null:
		_cache = Engine.get_singleton("SpriteCache")
	return _cache


func build_sprite_frames() -> SpriteFrames:
	## Build SpriteFrames with one animation per anim+direction combo.
	## Each animation is named "{anim}_{direction}" (e.g. "idle_front").
	## Frames are AtlasTexture slices from the strip PNG.
	var frames := SpriteFrames.new()
	var cache := _get_cache()

	for anim in animations:
		for dir in animations[anim]:
			var strip_data: Dictionary = animations[anim][dir]
			var tex: Texture2D = cache.get_texture(strip_data["path"])
			var frame_count: int = strip_data["frames"]
			var anim_name: String = get_animation_name(anim, dir)

			frames.add_animation(anim_name)
			# Default speed — can be tuned per-animation later
			frames.set_animation_speed(anim_name, 5.0)
			frames.set_animation_loop(anim_name, true)

			for i in range(frame_count):
				var atlas := AtlasTexture.new()
				atlas.atlas = tex
				atlas.region = Rect2(i * frame_width, 0, frame_width, frame_height)
				atlas.filter_clip = true
				frames.add_frame(anim_name, atlas)

	return frames


static func get_animation_name(anim: String, direction: String) -> String:
	"""Return the standard animation name for an anim+direction pair."""
	return anim + "_" + direction
