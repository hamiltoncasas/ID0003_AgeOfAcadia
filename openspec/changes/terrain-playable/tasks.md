# Tasks: terrain-playable

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 150–250 |
| 800-line budget risk | Low |
| Work units | 1 (single block — all integrations are self-contained) |
| Delivery strategy | auto-forecast |
| PR boundary | Single PR |

## Phase 1: Arrow.tscn Scene Creation

- [x] 1.1 Create `scenes/Arrow.tscn` from existing `scripts/Arrow.gd`
      - Area2D root with Arrow.gd script attached
      - CollisionShape2D child (CircleShape2D, radius 4)
      - Sprite2D child (loads arrow texture from `sprites/entorno/flecha/base/flecha_sin.png`)
      - Verify UnitController can instantiate it via `preload("res://scenes/Arrow.tscn")`

## Phase 2: CameraController Updates

- [x] 2.1 Update `map/CameraController.gd` — change default `map_size` from 120×120 to 300×300
      - Already exported as `@export var map_size: Vector2i`
      - The terrain_only.tscn instance will override with 300×300
- [x] 2.2 Add input split logic in CameraController.gd:
      - In `_input()` or `_process()`, check if `follow_target != null`
      - If following a target, ignore `ui_left/right/up/down` input (don't scroll)
      - Only consume arrow-key scroll when `follow_target == null`
      - This prevents camera scroll from fighting with character movement

## Phase 3: terrain_only.tscn Rewire

- [x] 3.1 Replace basic Camera2D node with CameraController instance
      - Remove existing Camera2D node
      - Add CameraController (scene instance or scripted node)
      - Set properties: `map_size = Vector2i(300, 300)`, appropriate zoom (0.13)
- [x] 3.2 Verify `project.godot` input actions exist:
      - `ui_left/right/up/down` bound to WASD + arrow keys
      - `test_attack` → F key
      - `test_hurt` → H key
      - `test_die` → R key
      - `test_revive` → E key
      - `zoom_in` → =/+
      - `zoom_out` → -

## Phase 4: Llanura1.gd Integration (Main Change)

- [x] 4.1 Store `biome_map` and `elev_map` as instance variables in Llanura1.gd
      - Currently they're local to `_generate()`
      - Make them accessible for ObjectPlacer
- [x] 4.2 Create ObjectContainer and call ObjectPlacer after terrain generation:
      ```gdscript
      var object_container = Node2D.new()
      object_container.name = "EnvironmentObjects"
      object_container.y_sort_enabled = true
      
      var placer = ObjectPlacer.new()
      placer.place_objects(_biome_map, _elev_map, rng, object_container)
      add_child(object_container)
      ```
      - ObjectPlacer.gd extends RefCounted with `class_name ObjectPlacer`
      - Import with `const ObjectPlacer = preload("res://map/ObjectPlacer.gd")`
- [x] 4.3 Import and instantiate UnitController as player character:
      ```gdscript
      const UnitController = preload("res://scripts/UnitController.gd")
      
      var player = UnitController.new()
      player.position = Vector2(0, 0)  # map center
      player.name = "PlayerUnit"
      add_child(player)
      ```
- [x] 4.4 Connect CameraController to follow the player:
      ```gdscript
      var camera = get_node_or_null("../CameraController")  # CameraController is sibling in terrain_only.tscn
      if camera:
          camera.follow_target = player
      ```
      - Note: CameraController is parented to Root in terrain_only.tscn, UnitController is child of Terrain (which has Llanura1.gd). So `../CameraController` goes to Root → CameraController.

## Phase 5: Verify & Test

- [ ] 5.1 Load `terrain_only.tscn` in Godot editor — verify no script errors
- [ ] 5.2 Run scene — verify terrain generates with environment objects
- [ ] 5.3 Verify WASD moves character with correct animations (5 directions)
- [ ] 5.4 Verify click-to-shoot fires arrow with ballistic arc
- [ ] 5.5 Verify camera follows character; drag-scroll works; zoom 0.08-3.0
- [ ] 5.6 Verify arrow keys scroll map when no follow target
- [ ] 5.7 Verify GameUI minimap + coordinates still work
- [ ] 5.8 Check FPS: should be stable (no freezing)

## Summary

| Phase | Tasks | Files Changed |
|-------|-------|---------------|
| 1 — Arrow.tscn | 1 | `scenes/Arrow.tscn` (create) |
| 2 — CameraController | 2 | `map/CameraController.gd` (modify) |
| 3 — terrain_only.tscn | 2 | `terrain_only.tscn` (modify), `project.godot` (verify) |
| 4 — Llanura1.gd | 4 | `map/Llanura1.gd` (modify) |
| 5 — Verify | 8 | — |
| **Total** | **17 tasks** | **4 files** |
