extends Node2D

func _ready():
	y_sort_enabled = true
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	var tile_set := load("res://map/terrain.tres") as TileSet
	var gen := ProceduralGeneration.new()
	var map_seed := 12345
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed
	var result := gen.generate(map_seed, 120, 120, tile_set)
	if result.success:
		for layer in result.layers:
			add_child(layer)
		if result.cliff_node:
			add_child(result.cliff_node)

		var obj_container := Node2D.new()
		obj_container.name = "ObjectContainer"
		obj_container.y_sort_enabled = true
		add_child(obj_container)

		var placer := ObjectPlacer.new()
		var place_result := placer.place_objects(result.biome_map, result.elev_map, rng, obj_container)
		print("Objects placed: ", place_result.count)
		if not place_result.warnings.is_empty():
			for warn in place_result.warnings:
				push_warning("ObjectPlacer: ", warn)

		print("Map generated: ", result.tile_count, " tiles")
	else:
		push_error("Map generation failed: ", result.error)
