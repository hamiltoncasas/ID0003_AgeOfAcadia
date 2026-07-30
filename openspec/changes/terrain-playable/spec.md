# Spec: terrain-playable

## player-character (NEW)

### Purpose

Player entity with WASD movement, click-to-attack ballistic arrow, team color shader, and camera follow trigger.

### Requirements

#### RF1: Player Movement

The player MUST move via WASD using UnitController.gd's state machine (IDLE/WALK) with 5-direction isometric animation.

- GIVEN a UnitController instance on the map
- WHEN pressing W/A/S/D
- THEN the character moves in that direction
- AND the correct animation direction plays (front/front_angle/profile/back_angle/back)

- GIVEN the character moving
- WHEN no movement key is pressed
- THEN velocity returns to zero
- AND idle animation resumes in the last facing direction

#### RF2: Arrow Attack

Left-click SHALL fire a ballistic arrow from Arrow.tscn toward the mouse position with parabolic arc.

- GIVEN the player character
- WHEN left-clicking anywhere on the map
- THEN an Arrow (Area2D + CollisionShape2D + Sprite2D) spawns near the character
- AND the arrow travels with a parabolic visual arc toward the click target

#### RF3: Team Color

The player SHOULD apply the team-color shader (magenta-key replacement) via `set_team_color()`.

- GIVEN the player character
- WHEN `set_team_color(Color(0.8, 0.1, 0.1))` is called
- THEN magenta-marked pixels render as red

## procedural-map (MODIFIED)

### RF4: Terrain Generation

The system MUST generate a 300×300 isometric tile grid (128×64 diamond) with five biomes. (Previously: 120×120)

- GIVEN seed and dimensions 300×300
- WHEN `ProceduralGeneration.generate(seed, 300, 300)` runs
- THEN `biome_map` is exactly 300×300
- AND generation completes without errors

### RF5: Object Placement

After terrain generation, the system MUST call `ObjectPlacer.place_objects(biome_map, elev_map, rng, container)`. Objects SHALL be placed per biome density (grass 3-5.5%, dirt 1.5-3%, sand 1-2%, water edge 0.2-0.6%) with y-sorted rendering, elliptical shadows, and collision shapes.

- GIVEN biome_map and elev_map from generation
- WHEN `ObjectPlacer.place_objects()` is called with a y-sorted Node2D
- THEN trees appear on grass, rocks on dirt, cacti/palms on sand, reeds at water edge
- AND ground cover (flowers, mushrooms) scatters on grass/dirt cells without collision

### RF6: Camera Controller

The system MUST use CameraController with follow_target, middle-drag scroll, zoom range 0.08-3.0, initial zoom 0.13, and map bounds clamped to 300×300. (Previously: basic Camera2D, 120×120 bounds)

- GIVEN the scene loaded
- WHEN the player moves
- THEN the camera lerps to follow when the character exits the center 50% viewport
- WHEN middle-dragging
- THEN the camera pans within map bounds
- WHEN scrolling the mouse wheel
- THEN zoom changes between 0.08× and 3.0×

### RF7: Player Unit

The system MUST instantiate UnitController as a child of the map root after generation, positioned at center, with arquero sprites and camera follow_target set.

- GIVEN terrain generation complete
- WHEN the UnitController is instantiated at map center
- THEN its sprite frames are built from `arquero_manifest.json`
- AND `CameraController.follow_target` is set to the unit
- AND the unit is responsive to WASD input

## godot-project (MODIFIED)

### RF8: Input Split

`ui_left`/`ui_right`/`ui_up`/`ui_down` SHALL be bound to WASD + arrow keys. UnitController consumes them for movement. CameraController consumes them for scroll ONLY when `follow_target` is null. Test actions (`test_attack`, `test_hurt`, `test_die`, `zoom_in`, `zoom_out`) SHOULD be defined. (Previously: no split, no test actions)

- GIVEN the input map with ui_* actions bound
- WHEN pressing WASD with a player character
- THEN only the character moves
- WHEN pressing arrow keys with no follow_target
- THEN the camera scrolls
- WHEN pressing arrow keys while camera follows a target
- THEN arrow keys are ignored
