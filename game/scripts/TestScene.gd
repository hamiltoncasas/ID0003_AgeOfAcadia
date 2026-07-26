extends Node2D
## Root script for test_scene.tscn.
##
## Loads the arquero manifest on ready and wires it into UnitController
## so the animated sprite displays correctly.

@onready var unit_controller: UnitController = $UnitController

func _ready() -> void:
	var sprites := UnitSprites.load_from_manifest(
		"res://sprites/infanteria/arquero/arquero_manifest.json"
	)
	if sprites:
		unit_controller.unit_sprites = sprites
	else:
		push_error("TestScene: failed to load arquero manifest")
